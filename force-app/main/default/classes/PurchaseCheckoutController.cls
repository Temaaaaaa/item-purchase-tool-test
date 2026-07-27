public with sharing class PurchaseCheckoutController {

    @AuraEnabled
    public static PurchaseCheckoutResult createPurchase(
        Id accountId,
        List<PurchaseCheckoutLineRequest> lines
    ) {
        Savepoint savepoint = Database.setSavepoint();

        try {
            validateRequest(accountId, lines);

            List<Account> clients = [
                SELECT Id
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];

            if (clients.isEmpty()) {
                throw new AuraHandledException(
                    'The selected client was not found or is not accessible.'
                );
            }

            Map<Id, Integer> quantitiesByItemId =
                collectRequestedQuantities(lines);

            Set<Id> requestedItemIds =
                quantitiesByItemId.keySet();

            List<Item__c> lockedItems = [
                SELECT
                    Id,
                    Name,
                    Price__c,
                    AvailableQuantity__c
                FROM Item__c
                WHERE Id IN :requestedItemIds
                FOR UPDATE
            ];

            Map<Id, Item__c> itemsById =
                new Map<Id, Item__c>(lockedItems);

            if (itemsById.size() != requestedItemIds.size()) {
                throw new AuraHandledException(
                    'One or more items were not found or are not accessible.'
                );
            }

            Purchase__c purchase = new Purchase__c(
                ClientId__c = accountId,
                TotalItems__c = 0,
                GrandTotal__c = 0
            );

            insert as user purchase;

            List<PurchaseLine__c> purchaseLines =
                new List<PurchaseLine__c>();

            List<Item__c> itemsToUpdate =
                new List<Item__c>();

            Integer totalItems = 0;
            Decimal grandTotal = 0;

            for (Id itemId : requestedItemIds) {
                Item__c item = itemsById.get(itemId);

                Integer requestedQuantity =
                    quantitiesByItemId.get(itemId);

                Decimal availableQuantity =
                    item.AvailableQuantity__c == null
                        ? 0
                        : item.AvailableQuantity__c;

                if (item.Price__c == null) {
                    throw new AuraHandledException(
                        'The price is not specified for item "' +
                        item.Name +
                        '".'
                    );
                }

                if (availableQuantity < requestedQuantity) {
                    throw new AuraHandledException(
                        'Insufficient stock for item "' +
                        item.Name +
                        '". Available: ' +
                        String.valueOf(availableQuantity) +
                        ', requested: ' +
                        String.valueOf(requestedQuantity) +
                        '.'
                    );
                }

                purchaseLines.add(
                    new PurchaseLine__c(
                        PurchaseId__c = purchase.Id,
                        ItemId__c = item.Id,
                        Amount__c = requestedQuantity,
                        UnitCost__c = item.Price__c
                    )
                );

                item.AvailableQuantity__c =
                    availableQuantity - requestedQuantity;

                itemsToUpdate.add(item);

                totalItems += requestedQuantity;
                grandTotal += item.Price__c * requestedQuantity;
            }

            insert as user purchaseLines;
            update as user itemsToUpdate;

            purchase.TotalItems__c = totalItems;
            purchase.GrandTotal__c = grandTotal;

            update as user purchase;

            Purchase__c savedPurchase = [
                SELECT Id, Name
                FROM Purchase__c
                WHERE Id = :purchase.Id
                LIMIT 1
            ];

            PurchaseCheckoutResult result =
                new PurchaseCheckoutResult();

            result.purchaseId = savedPurchase.Id;
            result.purchaseName = savedPurchase.Name;
            result.totalItems = totalItems;
            result.grandTotal = grandTotal;

            return result;
        } catch (AuraHandledException error) {
            Database.rollback(savepoint);
            throw error;
        } catch (Exception error) {
            Database.rollback(savepoint);

            throw new AuraHandledException(
                'Unable to create the purchase: ' +
                error.getMessage()
            );
        }
    }

    private static void validateRequest(
        Id accountId,
        List<PurchaseCheckoutLineRequest> lines
    ) {
        if (accountId == null) {
            throw new AuraHandledException(
                'Select a client.'
            );
        }

        if (lines == null || lines.isEmpty()) {
            throw new AuraHandledException(
                'The cart is empty.'
            );
        }
    }

    private static Map<Id, Integer> collectRequestedQuantities(
        List<PurchaseCheckoutLineRequest> lines
    ) {
        Map<Id, Integer> quantitiesByItemId =
            new Map<Id, Integer>();

        for (PurchaseCheckoutLineRequest line : lines) {
            if (line == null || line.itemId == null) {
                throw new AuraHandledException(
                    'The cart contains a line without an item.'
                );
            }

            if (line.quantity == null || line.quantity <= 0) {
                throw new AuraHandledException(
                    'Item quantity must be greater than zero.'
                );
            }

            Integer currentQuantity =
                quantitiesByItemId.containsKey(line.itemId)
                    ? quantitiesByItemId.get(line.itemId)
                    : 0;

            quantitiesByItemId.put(
                line.itemId,
                currentQuantity + line.quantity
            );
        }

        return quantitiesByItemId;
    }
}
