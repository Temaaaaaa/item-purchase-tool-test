public class PurchaseCheckoutResult {

    @AuraEnabled
    public Id purchaseId { get; set; }

    @AuraEnabled
    public String purchaseName { get; set; }

    @AuraEnabled
    public Integer totalItems { get; set; }

    @AuraEnabled
    public Decimal grandTotal { get; set; }
}
