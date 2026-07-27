public class ItemCreateRequest {

    @AuraEnabled
    public String name { get; set; }

    @AuraEnabled
    public String description { get; set; }

    @AuraEnabled
    public String itemType { get; set; }

    @AuraEnabled
    public String family { get; set; }

    @AuraEnabled
    public Decimal price { get; set; }

    @AuraEnabled
    public Integer availableQuantity { get; set; }

    @AuraEnabled
    public String unsplashPhotoId { get; set; }
}
