@IsTest
private class ItemCatalogueControllerTest {

    @TestSetup
    static void createTestItems() {
        List<Item__c> items = new List<Item__c>{
            new Item__c(
                Name = 'Laptop Pro',
                Description__c = 'Lightweight office laptop',
                Type__c = 'Digital',
                Family__c = 'Electronics',
                Image__c = 'https://example.com/laptop.jpg',
                Price__c = 850,
                AvailableQuantity__c = 5
            ),
            new Item__c(
                Name = 'Tablet Mini',
                Description__c = 'Portable tablet',
                Type__c = 'Digital',
                Family__c = 'Electronics',
                Image__c = 'https://example.com/tablet.jpg',
                Price__c = 450,
                AvailableQuantity__c = 3
            ),
            new Item__c(
                Name = 'Old Monitor',
                Description__c = 'Out-of-stock monitor',
                Type__c = 'Digital',
                Family__c = 'Electronics',
                Image__c = 'https://example.com/monitor.jpg',
                Price__c = 200,
                AvailableQuantity__c = 0
            )
        };

        insert items;
    }

    @IsTest
    static void getItemsReturnsOnlyAvailableItems() {
        Test.startTest();

        List<Item__c> result = ItemCatalogueController.getItems(
            null,
            null,
            null
        );

        Test.stopTest();

        System.assertEquals(
            2,
            result.size(),
            'Only available items must be returned.'
        );

        Set<String> returnedNames = new Set<String>();

        for (Item__c item : result) {
            returnedNames.add(item.Name);

            System.assert(
                item.AvailableQuantity__c > 0,
                'Every returned item must have available stock.'
            );
        }

        System.assert(
            returnedNames.contains('Laptop Pro'),
            'Laptop Pro must be returned.'
        );

        System.assert(
            returnedNames.contains('Tablet Mini'),
            'Tablet Mini must be returned.'
        );

        System.assert(
            !returnedNames.contains('Old Monitor'),
            'An out-of-stock item must not be returned.'
        );
    }

    @IsTest
    static void getItemsFiltersByNameTypeAndFamily() {
        Test.startTest();

        List<Item__c> result = ItemCatalogueController.getItems(
            'Laptop',
            'Digital',
            'Electronics'
        );

        Test.stopTest();

        System.assertEquals(
            1,
            result.size(),
            'Exactly one item must match all filters.'
        );

        System.assertEquals(
            'Laptop Pro',
            result[0].Name,
            'Laptop Pro must match the name search.'
        );

        System.assertEquals(
            'Digital',
            result[0].Type__c,
            'The type filter must be applied.'
        );

        System.assertEquals(
            'Electronics',
            result[0].Family__c,
            'The family filter must be applied.'
        );
    }

    @IsTest
    static void getItemsReturnsEmptyListForUnknownName() {
        Test.startTest();

        List<Item__c> result = ItemCatalogueController.getItems(
            'Unknown Product',
            null,
            null
        );

        Test.stopTest();

        System.assertEquals(
            0,
            result.size(),
            'An unknown product name must return an empty list.'
        );
    }

    @IsTest
    static void getItemsReturnsEmptyListForUnknownFilters() {
        Test.startTest();

        List<Item__c> result = ItemCatalogueController.getItems(
            null,
            'Unknown Type',
            'Unknown Family'
        );

        Test.stopTest();

        System.assertEquals(
            0,
            result.size(),
            'Unknown filter values must return an empty list.'
        );
    }

    @IsTest
    static void getFilterOptionsReturnsPicklistValues() {
        Test.startTest();

        ItemCatalogueFilterOptions options = ItemCatalogueController.getFilterOptions();

        Test.stopTest();

        System.assertNotEquals(
            null,
            options,
            'Filter options must be returned.'
        );

        System.assertNotEquals(
            null,
            options.types,
            'The types collection must be initialized.'
        );

        System.assertNotEquals(
            null,
            options.families,
            'The families collection must be initialized.'
        );

        System.assert(
            options.types.contains('Digital'),
            'The Type picklist must contain Digital.'
        );

        System.assert(
            options.families.contains('Electronics'),
            'The Family picklist must contain Electronics.'
        );
    }

    @IsTest
    static void isCurrentUserManagerReturnsCurrentValue() {
        Boolean expectedValue = [
            SELECT IsManager__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ].IsManager__c;

        Test.startTest();

        Boolean actualValue =
            ItemCatalogueController.isCurrentUserManager();

        Test.stopTest();

        System.assertEquals(
            expectedValue,
            actualValue,
            'The method must return the current user manager value.'
        );
    }
}
