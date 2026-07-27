public class PurchaseCheckoutLineRequest {

    @AuraEnabled
    public Id itemId { get; set; }

    @AuraEnabled
    public Integer quantity { get; set; }
}
