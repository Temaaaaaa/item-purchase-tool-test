import { LightningElement, wire } from "lwc";
import CURRENCY from "@salesforce/i18n/currency";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import isCurrentUserManager from "@salesforce/apex/ItemCatalogueController.isCurrentUserManager";
import ItemCreateModal from "c/itemCreateModal";

import getItems from "@salesforce/apex/ItemCatalogueController.getItems";
import getFilterOptions from "@salesforce/apex/ItemCatalogueController.getFilterOptions";
import createPurchase from "@salesforce/apex/PurchaseCheckoutController.createPurchase";

export default class ItemPurchaseTool extends LightningElement {
    currencyCode = CURRENCY;
    isManager = false;

    searchTerm = "";
    selectedType = "";
    selectedFamily = "";
    selectedAccountId = null;

    items = [];
    cartItems = [];

    typeOptions = [{ label: "All Types", value: "" }];
    familyOptions = [{ label: "All Families", value: "" }];

    isLoading = true;
    isCheckingOut = false;

    wiredItemsResult;

    @wire(getFilterOptions)
    wiredFilterOptions({ data, error }) {
        if (data) {
            this.typeOptions = [
                { label: "All Types", value: "" },
                ...(data.types || []).map((value) => ({
                    label: value,
                    value
                }))
            ];

            this.familyOptions = [
                { label: "All Families", value: "" },
                ...(data.families || []).map((value) => ({
                    label: value,
                    value
                }))
            ];
        } else if (error) {
            this.showError("Unable to load filters", error);
        }
    }

    @wire(isCurrentUserManager)
    wiredManagerStatus({ data, error }) {
    if (data !== undefined) {
        this.isManager = data;
    } else if (error) {
        this.showError(
            "Unable to determine manager access",
            error
        );
    }
}

    @wire(getItems, {
        searchTerm: "$searchTerm",
        itemType: "$selectedType",
        itemFamily: "$selectedFamily"
    })
    wiredItems(result) {
        this.wiredItemsResult = result;

        const { data, error } = result;

        if (data) {
            this.items = data;
            this.isLoading = false;
        } else if (error) {
            this.items = [];
            this.isLoading = false;
            this.showError("Unable to load items", error);
        }
    }

    get hasItems() {
        return this.items.length > 0;
    }

    get hasCartItems() {
        return this.cartItems.length > 0;
    }

    get totalItems() {
        return this.cartItems.reduce(
            (total, line) => total + line.quantity,
            0
        );
    }

    get grandTotal() {
        return this.cartItems.reduce(
            (total, line) => total + line.lineTotal,
            0
        );
    }

    get checkoutDisabled() {
        return (
            !this.selectedAccountId ||
            !this.hasCartItems ||
            this.isCheckingOut
        );
    }

    handleSearchChange(event) {
        this.isLoading = true;
        this.searchTerm = event.target.value?.trim() || "";
    }

    handleTypeChange(event) {
        this.isLoading = true;
        this.selectedType = event.detail.value;
    }

    handleFamilyChange(event) {
        this.isLoading = true;
        this.selectedFamily = event.detail.value;
    }

    handleAccountChange(event) {
        this.selectedAccountId = event.detail.recordId || null;
    }

    handleAddToCart(event) {
        const itemId = event.currentTarget.dataset.id;

        const item = this.items.find(
            (currentItem) => currentItem.Id === itemId
        );

        if (!item) {
            return;
        }

        const existingLine = this.cartItems.find(
            (line) => line.itemId === itemId
        );

        if (existingLine) {
            if (existingLine.quantity >= item.AvailableQuantity__c) {
                this.showToast(
                    "Insufficient Stock",
                    `Available quantity: ${item.AvailableQuantity__c}`,
                    "warning"
                );

                return;
            }

            this.cartItems = this.cartItems.map((line) =>
                line.itemId === itemId
                    ? this.createCartLine(item, line.quantity + 1)
                    : line
            );

            return;
        }

        this.cartItems = [
            ...this.cartItems,
            this.createCartLine(item, 1)
        ];
    }

    handleQuantityChange(event) {
        const itemId = event.target.dataset.id;
        const quantity = Number(event.target.value);

        event.target.setCustomValidity("");

        if (!Number.isInteger(quantity) || quantity < 1) {
            event.target.setCustomValidity(
                "Quantity must be a whole number greater than zero."
            );

            event.target.reportValidity();
            return;
        }

        const currentLine = this.cartItems.find(
            (line) => line.itemId === itemId
        );

        if (!currentLine) {
            return;
        }

        if (quantity > currentLine.availableQuantity) {
            event.target.setCustomValidity(
                `Maximum available quantity is ${currentLine.availableQuantity}.`
            );

            event.target.reportValidity();
            return;
        }

        event.target.reportValidity();

        this.cartItems = this.cartItems.map((line) =>
            line.itemId === itemId
                ? {
                      ...line,
                      quantity,
                      lineTotal: line.price * quantity
                  }
                : line
        );
    }

    handleRemoveFromCart(event) {
        const itemId = event.currentTarget.dataset.id;

        this.cartItems = this.cartItems.filter(
            (line) => line.itemId !== itemId
        );
    }

    async handleCheckout() {
        if (this.checkoutDisabled) {
            return;
        }

        this.isCheckingOut = true;

        const lines = this.cartItems.map((line) => ({
            itemId: line.itemId,
            quantity: line.quantity
        }));

        try {
            const result = await createPurchase({
                accountId: this.selectedAccountId,
                lines
            });

            this.cartItems = [];

            await refreshApex(this.wiredItemsResult);

            const formattedTotal = new Intl.NumberFormat(undefined, {
                style: "currency",
                currency: this.currencyCode
            }).format(result.grandTotal);

            this.showToast(
                "Purchase Created",
                `${result.purchaseName}: ${result.totalItems} item(s), total ${formattedTotal}.`,
                "success"
            );
        } catch (error) {
            this.showError("Unable to create purchase", error);
        } finally {
            this.isCheckingOut = false;
        }
    }

    async handleNewItem() {
      const result = await ItemCreateModal.open({
          size: "large",
          description: "Create a catalogue item",
          typeOptions: this.typeOptions.filter(
              (option) => option.value
          ),
          familyOptions: this.familyOptions.filter(
              (option) => option.value
          )
      });

      if (!result?.created) {
          return;
      }

      await refreshApex(this.wiredItemsResult);

      this.showToast(
          "Item Created",
          "The item was created successfully.",
          "success"
      );
  }

    createCartLine(item, quantity) {
        return {
            itemId: item.Id,
            name: item.Name,
            price: item.Price__c,
            availableQuantity: item.AvailableQuantity__c,
            quantity,
            lineTotal: item.Price__c * quantity
        };
    }

    showError(title, error) {
        const message =
            error?.body?.message ||
            error?.message ||
            "An unexpected error occurred.";

        this.showToast(title, message, "error");
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}
