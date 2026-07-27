public with sharing class ItemManagementController {

    private static final String UNSPLASH_API_ROOT =
        'https://api.unsplash.com';

    private static final String UNSPLASH_IMAGE_ROOT =
        'https://images.unsplash.com/';

    private static final String UNSPLASH_SITE_ROOT =
        'https://unsplash.com/';

    private static final String ATTRIBUTION_PARAMETERS =
        'utm_source=item_purchase_tool&utm_medium=referral';

    @AuraEnabled
    public static List<UnsplashPhotoOption> searchPhotos(
        String searchTerm
    ) {
        assertCurrentUserManager();

        if (String.isBlank(searchTerm)) {
            throw new AuraHandledException(
                'Enter a photo search term.'
            );
        }

        String encodedSearchTerm = EncodingUtil.urlEncode(
            searchTerm.trim(),
            'UTF-8'
        );

        String endpoint =
            'callout:Unsplash_API/search/photos' +
            '?query=' + encodedSearchTerm +
            '&per_page=8' +
            '&orientation=landscape' +
            '&content_filter=high';

        HttpResponse response = sendGetRequest(endpoint);

        Map<String, Object> responseBody =
            (Map<String, Object>) JSON.deserializeUntyped(
                response.getBody()
            );

        List<Object> rawResults =
            (List<Object>) responseBody.get('results');

        List<UnsplashPhotoOption> results =
            new List<UnsplashPhotoOption>();

        if (rawResults == null) {
            return results;
        }

        for (Object rawResult : rawResults) {
            UnsplashPhotoData photo = parsePhoto(
                (Map<String, Object>) rawResult
            );

            if (photo == null) {
                continue;
            }

            UnsplashPhotoOption option =
                new UnsplashPhotoOption();

            option.id = photo.id;
            option.imageUrl = photo.imageUrl;
            option.thumbnailUrl = photo.thumbnailUrl;
            option.altDescription = photo.altDescription;
            option.photographerName = photo.photographerName;
            option.photographerUrl = photo.photographerUrl;
            option.photoUrl = photo.photoUrl;

            results.add(option);
        }

        return results;
    }

    @AuraEnabled
    public static Id createItem(ItemCreateRequest request) {
        assertCurrentUserManager();
        validateItemRequest(request);

        UnsplashPhotoData selectedPhoto;

        if (!String.isBlank(request.unsplashPhotoId)) {
            selectedPhoto = getPhotoById(
                request.unsplashPhotoId.trim()
            );

            validatePhotoForStorage(selectedPhoto);

            trackPhotoDownload(
                selectedPhoto.downloadLocation
            );
        }

        Item__c item = new Item__c(
            Name = request.name.trim(),
            Description__c = normalizeOptionalText(
                request.description
            ),
            Type__c = request.itemType.trim(),
            Family__c = request.family.trim(),
            Price__c = request.price,
            AvailableQuantity__c = request.availableQuantity
        );

        if (selectedPhoto != null) {
            item.Image__c =
                selectedPhoto.imageUrl;

            item.ImagePhotographer__c =
                selectedPhoto.photographerName;

            item.ImagePhotographerUrl__c =
                selectedPhoto.photographerUrl;

            item.ImageSourceUrl__c =
                selectedPhoto.photoUrl;
        }

        insert as user item;

        return item.Id;
    }

    private static UnsplashPhotoData getPhotoById(
        String photoId
    ) {
        String encodedPhotoId = EncodingUtil.urlEncode(
            photoId,
            'UTF-8'
        );

        HttpResponse response = sendGetRequest(
            'callout:Unsplash_API/photos/' +
            encodedPhotoId
        );

        Map<String, Object> responseBody =
            (Map<String, Object>) JSON.deserializeUntyped(
                response.getBody()
            );

        UnsplashPhotoData photo =
            parsePhoto(responseBody);

        if (photo == null) {
            throw new AuraHandledException(
                'The selected photo could not be loaded.'
            );
        }

        return photo;
    }

    private static UnsplashPhotoData parsePhoto(
        Map<String, Object> photo
    ) {
        if (photo == null) {
            return null;
        }

        Map<String, Object> urls =
            (Map<String, Object>) photo.get('urls');

        Map<String, Object> links =
            (Map<String, Object>) photo.get('links');

        Map<String, Object> user =
            (Map<String, Object>) photo.get('user');

        Map<String, Object> userLinks =
            user == null
                ? null
                : (Map<String, Object>) user.get('links');

        if (
            urls == null ||
            links == null ||
            user == null ||
            userLinks == null
        ) {
            return null;
        }

        String id =
            (String) photo.get('id');

        String imageUrl =
            (String) urls.get('small');

        String thumbnailUrl =
            (String) urls.get('thumb');

        String photographerName =
            (String) user.get('name');

        String photographerUrl =
            (String) userLinks.get('html');

        String photoUrl =
            (String) links.get('html');

        String downloadLocation =
            (String) links.get('download_location');

        if (
            String.isBlank(id) ||
            String.isBlank(imageUrl) ||
            String.isBlank(photographerName) ||
            String.isBlank(photographerUrl) ||
            String.isBlank(photoUrl) ||
            String.isBlank(downloadLocation)
        ) {
            return null;
        }

        UnsplashPhotoData result =
            new UnsplashPhotoData();

        result.id = id;
        result.imageUrl = imageUrl;
        result.thumbnailUrl = String.isBlank(thumbnailUrl)
            ? imageUrl
            : thumbnailUrl;

        result.altDescription =
            (String) photo.get('alt_description');

        result.photographerName =
            photographerName;

        result.photographerUrl =
            addAttributionParameters(
                photographerUrl
            );

        result.photoUrl =
            addAttributionParameters(
                photoUrl
            );

        result.downloadLocation =
            downloadLocation;

        return result;
    }

    private static void trackPhotoDownload(
        String downloadLocation
    ) {
        if (
            String.isBlank(downloadLocation) ||
            !downloadLocation.startsWith(
                UNSPLASH_API_ROOT + '/photos/'
            )
        ) {
            throw new AuraHandledException(
                'The selected photo download URL is invalid.'
            );
        }

        String relativeEndpoint =
            downloadLocation.substring(
                UNSPLASH_API_ROOT.length()
            );

        sendGetRequest(
            'callout:Unsplash_API' +
            relativeEndpoint
        );
    }

    private static HttpResponse sendGetRequest(
        String endpoint
    ) {
        HttpRequest request = new HttpRequest();

        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setTimeout(15000);

        HttpResponse response =
            new Http().send(request);

        Integer statusCode =
            response.getStatusCode();

        if (
            statusCode < 200 ||
            statusCode >= 300
        ) {
            throw new AuraHandledException(
                'The Unsplash request failed with HTTP status ' +
                statusCode +
                '.'
            );
        }

        return response;
    }

    private static void assertCurrentUserManager() {
        User currentUser = [
            SELECT IsManager__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH USER_MODE
            LIMIT 1
        ];

        if (currentUser.IsManager__c != true) {
            throw new AuraHandledException(
                'Only managers can manage items.'
            );
        }
    }

    private static void validateItemRequest(
        ItemCreateRequest request
    ) {
        if (request == null) {
            throw new AuraHandledException(
                'Item information is required.'
            );
        }

        if (String.isBlank(request.name)) {
            throw new AuraHandledException(
                'Item name is required.'
            );
        }

        if (request.name.trim().length() > 80) {
            throw new AuraHandledException(
                'Item name cannot exceed 80 characters.'
            );
        }

        if (String.isBlank(request.itemType)) {
            throw new AuraHandledException(
                'Item type is required.'
            );
        }

        if (
            !isActivePicklistValue(
                Item__c.Type__c,
                request.itemType.trim()
            )
        ) {
            throw new AuraHandledException(
                'Select a valid item type.'
            );
        }

        if (String.isBlank(request.family)) {
            throw new AuraHandledException(
                'Item family is required.'
            );
        }

        if (
            !isActivePicklistValue(
                Item__c.Family__c,
                request.family.trim()
            )
        ) {
            throw new AuraHandledException(
                'Select a valid item family.'
            );
        }

        if (
            request.price == null ||
            request.price <= 0
        ) {
            throw new AuraHandledException(
                'Price must be greater than zero.'
            );
        }

        if (
            request.availableQuantity == null ||
            request.availableQuantity < 0
        ) {
            throw new AuraHandledException(
                'Available quantity cannot be negative.'
            );
        }
    }

    private static void validatePhotoForStorage(
        UnsplashPhotoData photo
    ) {
        if (
            photo == null ||
            !photo.imageUrl.startsWith(
                UNSPLASH_IMAGE_ROOT
            )
        ) {
            throw new AuraHandledException(
                'The selected image URL is invalid.'
            );
        }

        if (
            !photo.photographerUrl.startsWith(
                UNSPLASH_SITE_ROOT
            ) ||
            !photo.photoUrl.startsWith(
                UNSPLASH_SITE_ROOT
            )
        ) {
            throw new AuraHandledException(
                'The selected photo attribution is invalid.'
            );
        }

        if (photo.imageUrl.length() > 255) {
            throw new AuraHandledException(
                'The selected image URL is too long.'
            );
        }

        if (photo.photographerName.length() > 80) {
            throw new AuraHandledException(
                'The photographer name is too long.'
            );
        }

        if (
            photo.photographerUrl.length() > 255 ||
            photo.photoUrl.length() > 255
        ) {
            throw new AuraHandledException(
                'The selected attribution URL is too long.'
            );
        }
    }

    private static Boolean isActivePicklistValue(
        Schema.SObjectField fieldToken,
        String requestedValue
    ) {
        for (
            Schema.PicklistEntry entry :
            fieldToken.getDescribe().getPicklistValues()
        ) {
            if (
                entry.isActive() &&
                entry.getValue() == requestedValue
            ) {
                return true;
            }
        }

        return false;
    }

    private static String normalizeOptionalText(
        String value
    ) {
        return String.isBlank(value)
            ? null
            : value.trim();
    }

    private static String addAttributionParameters(
        String url
    ) {
        return url +
            (url.contains('?') ? '&' : '?') +
            ATTRIBUTION_PARAMETERS;
    }

    private class UnsplashPhotoData {
        private String id;
        private String imageUrl;
        private String thumbnailUrl;
        private String altDescription;
        private String photographerName;
        private String photographerUrl;
        private String photoUrl;
        private String downloadLocation;
    }
}
