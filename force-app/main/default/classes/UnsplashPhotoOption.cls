public class UnsplashPhotoOption {

    @AuraEnabled
    public String id { get; set; }

    @AuraEnabled
    public String imageUrl { get; set; }

    @AuraEnabled
    public String thumbnailUrl { get; set; }

    @AuraEnabled
    public String altDescription { get; set; }

    @AuraEnabled
    public String photographerName { get; set; }

    @AuraEnabled
    public String photographerUrl { get; set; }

    @AuraEnabled
    public String photoUrl { get; set; }
}
