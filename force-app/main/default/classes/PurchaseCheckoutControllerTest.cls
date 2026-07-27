@IsTest
private class PurchaseCheckoutControllerTest {

    private static final String CLIENT_NAME =
        'Checkout Test Client';

    @TestSetup
    static void createTestData() {
        insert new Account(
            Name = CLIENT_NAME
        );

        insert new List<Item__c>{
            new Item__c(
                Name = 'Checkout Laptop',
                Description__c = 'Laptop used in checkout tests',
                Type__c = 'Digital',
                Family__c = 'Electronics',
                Price__c = 100,
                AvailableQuantity__c = 5
            ),
            new Item__c(
                Name = 'Checkout Tablet',
                Description__c = 'Tablet used in checkout tests',
                Type__c = 'Digital',
                Family__c = 'Electronics',
                Price__c = 150,
                AvailableQuantity__c = 4
            )
        };
    }

    @IsTest
    static void createPurchaseCreatesRecordsAndUpdatesStock() {
        Account client = getClient();
        Map<String, Item__c> items = getItemsByName();

        List<PurchaseCheckoutLineRequest> requestLines =
            new List<PurchaseCheckoutLineRequest>{
                createRequestLine(
                    items.get('Checkout Laptop').Id,
                    1
                ),
                createRequestLine(
                    items.get('Checkout Tablet').Id,
                    2
                )
            };

        Test.startTest();

        PurchaseCheckoutResult result =
            PurchaseCheckoutController.createPurchase(
                client.Id,
                requestLines
            );

        Test.stopTest();

        System.assertNotEquals(
            null,
            result.purchaseId,
            'The purchase ID must be returned.'
        );

        System.assertEquals(
            3,
            result.totalItems,
            'The result must contain the total quantity.'
        );

        System.assertEquals(
            Decimal.valueOf('400'),
            result.grandTotal,
            'The result must contain the calculated total.'
        );

        Purchase__c purchase = [
            SELECT
                ClientId__c,
                TotalItems__c,
                GrandTotal__c
            FROM Purchase__c
            WHERE Id = :result.purchaseId
        ];

        System.assertEquals(
            client.Id,
            purchase.ClientId__c,
            'The purchase must reference the selected client.'
        );

        System.assertEquals(
            Decimal.valueOf('3'),
            purchase.TotalItems__c,
            'The purchase must store the total quantity.'
        );

        System.assertEquals(
            Decimal.valueOf('400'),
            purchase.GrandTotal__c,
            'The purchase must store the grand total.'
        );

        List<PurchaseLine__c> savedLines = [
            SELECT
                ItemId__c,
                Amount__c,
                UnitCost__c
            FROM PurchaseLine__c
            WHERE PurchaseId__c = :purchase.Id
        ];

        System.assertEquals(
            2,
            savedLines.size(),
            'Two purchase lines must be created.'
        );

        Map<Id, PurchaseLine__c> linesByItemId =
            new Map<Id, PurchaseLine__c>();

        for (PurchaseLine__c savedLine : savedLines) {
            linesByItemId.put(
                savedLine.ItemId__c,
                savedLine
            );
        }

        System.assertEquals(
            Decimal.valueOf('1'),
            linesByItemId
                .get(items.get('Checkout Laptop').Id)
                .Amount__c
        );

        System.assertEquals(
            Decimal.valueOf('100'),
            linesByItemId
                .get(items.get('Checkout Laptop').Id)
                .UnitCost__c
        );

        System.assertEquals(
            Decimal.valueOf('2'),
            linesByItemId
                .get(items.get('Checkout Tablet').Id)
                .Amount__c
        );

        System.assertEquals(
            Decimal.valueOf('150'),
            linesByItemId
                .get(items.get('Checkout Tablet').Id)
                .UnitCost__c
        );

        Map<String, Item__c> updatedItems =
            getItemsByName();

        System.assertEquals(
            Decimal.valueOf('4'),
            updatedItems
                .get('Checkout Laptop')
                .AvailableQuantity__c,
            'Laptop stock must decrease by one.'
        );

        System.assertEquals(
            Decimal.valueOf('2'),
            updatedItems
                .get('Checkout Tablet')
                .AvailableQuantity__c,
            'Tablet stock must decrease by two.'
        );
    }

    @IsTest
    static void createPurchaseAggregatesDuplicateItems() {
        Account client = getClient();
        Item__c laptop =
            getItemsByName().get('Checkout Laptop');

        List<PurchaseCheckoutLineRequest> requestLines =
            new List<PurchaseCheckoutLineRequest>{
                createRequestLine(laptop.Id, 1),
                createRequestLine(laptop.Id, 2)
            };

        Test.startTest();

        PurchaseCheckoutResult result =
            PurchaseCheckoutController.createPurchase(
                client.Id,
                requestLines
            );

        Test.stopTest();

        System.assertEquals(
            3,
            result.totalItems,
            'Duplicate item quantities must be added together.'
        );

        System.assertEquals(
            Decimal.valueOf('300'),
            result.grandTotal,
            'The total must use the aggregated quantity.'
        );

        List<PurchaseLine__c> savedLines = [
            SELECT Amount__c, UnitCost__c
            FROM PurchaseLine__c
            WHERE PurchaseId__c = :result.purchaseId
        ];

        System.assertEquals(
            1,
            savedLines.size(),
            'Duplicate items must create one purchase line.'
        );

        System.assertEquals(
            Decimal.valueOf('3'),
            savedLines[0].Amount__c
        );

        Item__c updatedLaptop = [
            SELECT AvailableQuantity__c
            FROM Item__c
            WHERE Id = :laptop.Id
        ];

        System.assertEquals(
            Decimal.valueOf('2'),
            updatedLaptop.AvailableQuantity__c,
            'The aggregated quantity must be removed from stock.'
        );
    }

    @IsTest
    static void createPurchaseRejectsInsufficientStock() {
        Account client = getClient();
        Item__c tablet =
            getItemsByName().get('Checkout Tablet');

        List<PurchaseCheckoutLineRequest> requestLines =
            new List<PurchaseCheckoutLineRequest>{
                createRequestLine(tablet.Id, 10)
            };

        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            PurchaseCheckoutController.createPurchase(
                client.Id,
                requestLines
            );
        } catch (AuraHandledException error) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'Insufficient stock must cause an exception.'
        );

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Purchase__c],
            'No purchase must remain after rollback.'
        );

        System.assertEquals(
            0,
            [SELECT COUNT() FROM PurchaseLine__c],
            'No purchase lines must remain after rollback.'
        );

        Item__c unchangedTablet = [
            SELECT AvailableQuantity__c
            FROM Item__c
            WHERE Id = :tablet.Id
        ];

        System.assertEquals(
            Decimal.valueOf('4'),
            unchangedTablet.AvailableQuantity__c,
            'Stock must remain unchanged after rollback.'
        );
    }

    @IsTest
    static void createPurchaseRejectsEmptyCart() {
        Account client = getClient();
        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            PurchaseCheckoutController.createPurchase(
                client.Id,
                new List<PurchaseCheckoutLineRequest>()
            );
        } catch (AuraHandledException error) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'An empty cart must cause an exception.'
        );

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Purchase__c],
            'An empty cart must not create a purchase.'
        );
    }

    private static Account getClient() {
        return [
            SELECT Id
            FROM Account
            WHERE Name = :CLIENT_NAME
            LIMIT 1
        ];
    }

    private static Map<String, Item__c> getItemsByName() {
        Map<String, Item__c> result =
            new Map<String, Item__c>();

        for (Item__c item : [
            SELECT
                Id,
                Name,
                Price__c,
                AvailableQuantity__c
            FROM Item__c
            WHERE Name IN (
                'Checkout Laptop',
                'Checkout Tablet'
            )
        ]) {
            result.put(item.Name, item);
        }

        return result;
    }

    private static PurchaseCheckoutLineRequest createRequestLine(
        Id itemId,
        Integer quantity
    ) {
        PurchaseCheckoutLineRequest line =
            new PurchaseCheckoutLineRequest();

        line.itemId = itemId;
        line.quantity = quantity;

        return line;
    }
}
