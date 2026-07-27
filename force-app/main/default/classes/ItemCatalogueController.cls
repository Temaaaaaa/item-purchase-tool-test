public with sharing class ItemCatalogueController {

    @AuraEnabled(cacheable=true)
    public static List<Item__c> getItems(
        String searchTerm,
        String itemType,
        String itemFamily
    ) {
        String queryText =
    'SELECT ' +
    'Id, ' +
    'Name, ' +
    'Description__c, ' +
    'Type__c, ' +
    'Family__c, ' +
    'Image__c, ' +
    'ImagePhotographer__c, ' +
    'ImagePhotographerUrl__c, ' +
    'ImageSourceUrl__c, ' +
    'Price__c, ' +
    'AvailableQuantity__c ' +
    'FROM Item__c ' +
    'WHERE AvailableQuantity__c > 0';

        Map<String, Object> bindValues = new Map<String, Object>();

        if (!String.isBlank(searchTerm)) {
            bindValues.put(
                'namePattern',
                '%' + searchTerm.trim() + '%'
            );

            queryText += ' AND Name LIKE :namePattern';
        }

        if (!String.isBlank(itemType)) {
            bindValues.put(
                'itemType',
                itemType.trim()
            );

            queryText += ' AND Type__c = :itemType';
        }

        if (!String.isBlank(itemFamily)) {
            bindValues.put(
                'itemFamily',
                itemFamily.trim()
            );

            queryText += ' AND Family__c = :itemFamily';
        }

        queryText += ' ORDER BY Name ASC';

        return (List<Item__c>) Database.queryWithBinds(
            queryText,
            bindValues,
            AccessLevel.USER_MODE
        );
    }

    @AuraEnabled(cacheable=true)
    public static ItemCatalogueFilterOptions getFilterOptions() {
        ItemCatalogueFilterOptions options =
        new ItemCatalogueFilterOptions();

        Schema.DescribeFieldResult typeField =
            Item__c.Type__c.getDescribe();

        for (Schema.PicklistEntry entry : typeField.getPicklistValues()) {
            if (entry.isActive()) {
                options.types.add(entry.getValue());
            }
        }

        Schema.DescribeFieldResult familyField =
            Item__c.Family__c.getDescribe();

        for (Schema.PicklistEntry entry : familyField.getPicklistValues()) {
            if (entry.isActive()) {
                options.families.add(entry.getValue());
            }
        }

        return options;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isCurrentUserManager() {
        User currentUser = [
            SELECT IsManager__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH USER_MODE
            LIMIT 1
        ];

        return currentUser.IsManager__c;
    }
}
