public class ItemCatalogueFilterOptions {

    @AuraEnabled
    public List<String> types { get; set; }

    @AuraEnabled
    public List<String> families { get; set; }

    public ItemCatalogueFilterOptions() {
        types = new List<String>();
        families = new List<String>();
    }
}
