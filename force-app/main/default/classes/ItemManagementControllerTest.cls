@IsTest
private class ItemManagementControllerTest {

    private static final String MANAGER_LAST_NAME =
        'Item Manager';

    private static final String STANDARD_USER_LAST_NAME =
        'Standard Item User';

    @TestSetup
    static void createTestUsers() {
        Profile currentProfile = [
            SELECT Id
            FROM Profile
            WHERE Id = :UserInfo.getProfileId()
            LIMIT 1
        ];

        String uniqueValue =
            String.valueOf(DateTime.now().getTime());

        User manager = new User(
            Alias = 'itmmgr',
            Email = 'item.manager@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = MANAGER_LAST_NAME,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = currentProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username =
                'item.manager.' +
                uniqueValue +
                '@example.com',
            IsManager__c = true
        );

        User standardUser = new User(
            Alias = 'itmuser',
            Email = 'item.user@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = STANDARD_USER_LAST_NAME,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = currentProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username =
                'item.user.' +
                uniqueValue +
                '@example.com',
            IsManager__c = false
        );

        insert new List<User>{
            manager,
            standardUser
        };

        List<PermissionSet> permissionSets = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = 'Item_Purchase_Tool_User'
            LIMIT 1
        ];

        if (!permissionSets.isEmpty()) {
            insert new List<PermissionSetAssignment>{
                new PermissionSetAssignment(
                    AssigneeId = manager.Id,
                    PermissionSetId = permissionSets[0].Id
                ),
                new PermissionSetAssignment(
                    AssigneeId = standardUser.Id,
                    PermissionSetId = permissionSets[0].Id
                )
            };
        }
    }

    @IsTest
    static void searchPhotosReturnsMappedResults() {
        User manager = getUser(MANAGER_LAST_NAME);

        Test.setMock(
            HttpCalloutMock.class,
            new UnsplashSearchMock()
        );

        List<UnsplashPhotoOption> results;

        System.runAs(manager) {
            Test.startTest();

            results =
                ItemManagementController.searchPhotos(
                    'laptop'
                );

            Test.stopTest();
        }

        System.assertEquals(
            1,
            results.size(),
            'One mapped photo must be returned.'
        );

        UnsplashPhotoOption photo = results[0];

        System.assertEquals(
            'photo-1',
            photo.id
        );

        System.assertEquals(
            'https://images.unsplash.com/photo-test?ixid=test',
            photo.imageUrl
        );

        System.assertEquals(
            'Test Photographer',
            photo.photographerName
        );

        System.assert(
            photo.photographerUrl.contains(
                'utm_source=item_purchase_tool'
            ),
            'The photographer URL must contain attribution parameters.'
        );

        System.assert(
            photo.photoUrl.contains(
                'utm_medium=referral'
            ),
            'The photo URL must contain attribution parameters.'
        );
    }

    @IsTest
    static void searchPhotosRejectsBlankSearchTerm() {
        User manager = getUser(MANAGER_LAST_NAME);
        Boolean exceptionThrown = false;

        System.runAs(manager) {
            Test.startTest();

            try {
                ItemManagementController.searchPhotos(' ');
            } catch (AuraHandledException error) {
                exceptionThrown = true;
            }

            Test.stopTest();
        }

        System.assertEquals(
            true,
            exceptionThrown,
            'A blank search term must be rejected.'
        );
    }

    @IsTest
    static void searchPhotosRejectsNonManager() {
        User standardUser = getUser(
            STANDARD_USER_LAST_NAME
        );

        Boolean exceptionThrown = false;

        System.runAs(standardUser) {
            Test.startTest();

            try {
                ItemManagementController.searchPhotos(
                    'laptop'
                );
            } catch (AuraHandledException error) {
                exceptionThrown = true;
            }

            Test.stopTest();
        }

        System.assertEquals(
            true,
            exceptionThrown,
            'A non-manager must not be allowed to search photos.'
        );
    }

    @IsTest
    static void createItemCreatesRecordWithAttribution() {
        User manager = getUser(MANAGER_LAST_NAME);

        Test.setMock(
            HttpCalloutMock.class,
            new UnsplashSelectedPhotoMock()
        );

        Id itemId;

        System.runAs(manager) {
            Test.startTest();

            itemId =
                ItemManagementController.createItem(
                    createValidRequest()
                );

            Test.stopTest();
        }

        Item__c savedItem = [
            SELECT
                Name,
                Description__c,
                Type__c,
                Family__c,
                Price__c,
                AvailableQuantity__c,
                Image__c,
                ImagePhotographer__c,
                ImagePhotographerUrl__c,
                ImageSourceUrl__c
            FROM Item__c
            WHERE Id = :itemId
        ];

        System.assertEquals(
            'New Test Laptop',
            savedItem.Name
        );

        System.assertEquals(
            'Laptop created by the item management API.',
            savedItem.Description__c
        );

        System.assertEquals(
            'Digital',
            savedItem.Type__c
        );

        System.assertEquals(
            'Electronics',
            savedItem.Family__c
        );

        System.assertEquals(
            Decimal.valueOf('1200'),
            savedItem.Price__c
        );

        System.assertEquals(
            Decimal.valueOf('7'),
            savedItem.AvailableQuantity__c
        );

        System.assertEquals(
            'https://images.unsplash.com/photo-test?ixid=test',
            savedItem.Image__c
        );

        System.assertEquals(
            'Test Photographer',
            savedItem.ImagePhotographer__c
        );

        System.assert(
            savedItem.ImagePhotographerUrl__c.contains(
                'utm_source=item_purchase_tool'
            )
        );

        System.assert(
            savedItem.ImageSourceUrl__c.contains(
                'utm_medium=referral'
            )
        );
    }

    @IsTest
    static void createItemWithoutPhotoCreatesRecord() {
        User manager = getUser(MANAGER_LAST_NAME);

        ItemCreateRequest request =
            createValidRequest();

        request.unsplashPhotoId = null;

        Id itemId;

        System.runAs(manager) {
            Test.startTest();

            itemId =
                ItemManagementController.createItem(
                    request
                );

            Test.stopTest();
        }

        Item__c savedItem = [
            SELECT
                Name,
                Image__c,
                ImagePhotographer__c,
                ImagePhotographerUrl__c,
                ImageSourceUrl__c
            FROM Item__c
            WHERE Id = :itemId
        ];

        System.assertEquals(
            'New Test Laptop',
            savedItem.Name
        );

        System.assertEquals(
            null,
            savedItem.Image__c
        );

        System.assertEquals(
            null,
            savedItem.ImagePhotographer__c
        );
    }

    @IsTest
    static void createItemRejectsInvalidRequest() {
        User manager = getUser(MANAGER_LAST_NAME);

        ItemCreateRequest request =
            createValidRequest();

        request.price = 0;

        Boolean exceptionThrown = false;

        System.runAs(manager) {
            Test.startTest();

            try {
                ItemManagementController.createItem(
                    request
                );
            } catch (AuraHandledException error) {
                exceptionThrown = true;
            }

            Test.stopTest();
        }

        System.assertEquals(
            true,
            exceptionThrown,
            'A non-positive price must be rejected.'
        );

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Item__c
                WHERE Name = 'New Test Laptop'
            ]
        );
    }

    @IsTest
    static void createItemRejectsNonManager() {
        User standardUser = getUser(
            STANDARD_USER_LAST_NAME
        );

        Boolean exceptionThrown = false;

        System.runAs(standardUser) {
            Test.startTest();

            try {
                ItemManagementController.createItem(
                    createValidRequest()
                );
            } catch (AuraHandledException error) {
                exceptionThrown = true;
            }

            Test.stopTest();
        }

        System.assertEquals(
            true,
            exceptionThrown,
            'A non-manager must not be allowed to create items.'
        );

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Item__c
                WHERE Name = 'New Test Laptop'
            ]
        );
    }

    private static User getUser(String lastName) {
        return [
            SELECT Id, IsManager__c
            FROM User
            WHERE LastName = :lastName
            LIMIT 1
        ];
    }

    private static ItemCreateRequest createValidRequest() {
        ItemCreateRequest request =
            new ItemCreateRequest();

        request.name = 'New Test Laptop';

        request.description =
            'Laptop created by the item management API.';

        request.itemType = 'Digital';
        request.family = 'Electronics';
        request.price = 1200;
        request.availableQuantity = 7;
        request.unsplashPhotoId = 'photo-1';

        return request;
    }

    private class UnsplashSearchMock
        implements HttpCalloutMock {

        public HttpResponse respond(
            HttpRequest request
        ) {
            System.assertEquals(
                'GET',
                request.getMethod()
            );

            System.assert(
                request.getEndpoint().contains(
                    '/search/photos'
                )
            );

            HttpResponse response =
                new HttpResponse();

            response.setStatusCode(200);
            response.setBody(photoSearchResponse());

            return response;
        }
    }

    private class UnsplashSelectedPhotoMock
        implements HttpCalloutMock {

        public HttpResponse respond(
            HttpRequest request
        ) {
            HttpResponse response =
                new HttpResponse();

            response.setStatusCode(200);

            if (
                request.getEndpoint().contains(
                    '/download'
                )
            ) {
                response.setBody(
                    '{' +
                        '"url":' +
                        '"https://images.unsplash.com/photo-test"' +
                    '}'
                );

                return response;
            }

            System.assert(
                request.getEndpoint().contains(
                    '/photos/photo-1'
                )
            );

            response.setBody(photoDetailResponse());

            return response;
        }
    }

    private static String photoSearchResponse() {
        return (
            '{' +
                '"results":[' +
                    photoDetailResponse() +
                ']' +
            '}'
        );
    }

    private static String photoDetailResponse() {
        return (
            '{' +
                '"id":"photo-1",' +
                '"alt_description":"Laptop on a desk",' +
                '"urls":{' +
                    '"small":' +
                        '"https://images.unsplash.com/' +
                        'photo-test?ixid=test",' +
                    '"thumb":' +
                        '"https://images.unsplash.com/' +
                        'photo-test?ixid=thumb"' +
                '},' +
                '"links":{' +
                    '"html":' +
                        '"https://unsplash.com/photos/photo-1",' +
                    '"download_location":' +
                        '"https://api.unsplash.com/' +
                        'photos/photo-1/download?ixid=test"' +
                '},' +
                '"user":{' +
                    '"name":"Test Photographer",' +
                    '"links":{' +
                        '"html":' +
                            '"https://unsplash.com/@test"' +
                    '}' +
                '}' +
            '}'
        );
    }
}
