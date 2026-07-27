import { api, LightningElement, wire } from "lwc";
import CURRENCY from "@salesforce/i18n/currency";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import { getFieldValue, getRecord } from "lightning/uiRecordApi";
import { NavigationMixin } from "lightning/navigation";
import { CloseActionScreenEvent } from "lightning/actions";

import ACCOUNT_NAME_FIELD from "@salesforce/schema/Account.Name";
import ACCOUNT_NUMBER_FIELD from "@salesforce/schema/Account.AccountNumber";
import ACCOUNT_INDUSTRY_FIELD from "@salesforce/schema/Account.Industry";

import getItems from "@salesforce/apex/ItemCatalogueController.getItems";
import getFilterOptions from "@salesforce/apex/ItemCatalogueController.getFilterOptions";
import isCurrentUserManager from "@salesforce/apex/ItemCatalogueController.isCurrentUserManager";
import createPurchase from "@salesforce/apex/PurchaseCheckoutController.createPurchase";

import ItemCreateModal from "c/itemCreateModal";
import ItemDetailsModal from "c/itemDetailsModal";
import CartModal from "c/cartModal";

const ACCOUNT_FIELDS = [
    ACCOUNT_NAME_FIELD,
    ACCOUNT_NUMBER_FIELD,
    ACCOUNT_INDUSTRY_FIELD
];

export default class ItemPurchaseTool extends NavigationMixin(
    LightningElement
) {
    currencyCode = CURRENCY;

    _recordId;
    accountRecord;

    searchTerm = "";
    selectedType = "";
    selectedFamily = "";
    selectedAccountId = null;

    items = [];
    cartItems = [];

    typeOptions = [{ label: "All Types", value: "" }];
    familyOptions = [{ label: "All Families", value: "" }];

    isManager = false;
    isLoading = true;
    isCheckingOut = false;

    wiredItemsResult;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;

        if (value) {
            this.selectedAccountId = value;
        }
    }

    @wire(getRecord, {
        recordId: "$recordId",
        fields: ACCOUNT_FIELDS
    })
    wiredAccount({ data, error }) {
        if (data) {
            this.accountRecord = data;
            this.selectedAccountId = this.recordId;
        } else if (error) {
            this.accountRecord = null;
            this.showError("Unable to load account", error);
        }
    }

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

    get hasAccountContext() {
        return Boolean(this.recordId);
    }

    get accountName() {
        return (
            getFieldValue(
                this.accountRecord,
                ACCOUNT_NAME_FIELD
            ) || "Not specified"
        );
    }

    get accountNumber() {
        return (
            getFieldValue(
                this.accountRecord,
                ACCOUNT_NUMBER_FIELD
            ) || "Not specified"
        );
    }

    get accountIndustry() {
        return (
            getFieldValue(
                this.accountRecord,
                ACCOUNT_INDUSTRY_FIELD
            ) || "Not specified"
        );
    }

    get listedItemCount() {
        return this.items.length;
    }

    get hasItems() {
        return this.items.length > 0;
    }

    get totalItems() {
        return this.cartItems.reduce(
            (total, line) => total + line.quantity,
            0
        );
    }

    get cartButtonLabel() {
        return `Cart (${this.totalItems})`;
    }

    get cartButtonDisabled() {
        return this.isCheckingOut;
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
        this.selectedAccountId =
            event.detail.recordId || null;
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
            if (
                existingLine.quantity >=
                item.AvailableQuantity__c
            ) {
                this.showToast(
                    "Insufficient Stock",
                    `Available quantity: ${item.AvailableQuantity__c}`,
                    "warning"
                );

                return;
            }

            this.cartItems = this.cartItems.map((line) =>
                line.itemId === itemId
                    ? this.createCartLine(
                          item,
                          line.quantity + 1
                      )
                    : line
            );
        } else {
            this.cartItems = [
                ...this.cartItems,
                this.createCartLine(item, 1)
            ];
        }

        this.showToast(
            "Item Added",
            `${item.Name} was added to the cart.`,
            "success"
        );
    }

    async handleOpenCart() {
        const result = await CartModal.open({
            size: "large",
            description:
                "Review the selected items and complete checkout.",
            cartItems: this.cartItems,
            currencyCode: this.currencyCode
        });

        if (!result) {
            return;
        }

        this.cartItems = result.lines || [];

        if (result.action === "checkout") {
            await this.checkoutCart();
        }
    }

    async checkoutCart() {
        if (!this.selectedAccountId) {
            this.showToast(
                "Client Required",
                "Select a client before checkout.",
                "error"
            );

            return;
        }

        if (this.cartItems.length === 0) {
            this.showToast(
                "Empty Cart",
                "Add at least one item to the cart.",
                "warning"
            );

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

            const formattedTotal = new Intl.NumberFormat(
                undefined,
                {
                    style: "currency",
                    currency: this.currencyCode
                }
            ).format(result.grandTotal);

            this.showToast(
                "Purchase Created",
                `${result.purchaseName}: ${result.totalItems} item(s), total ${formattedTotal}.`,
                "success"
            );

            if (this.hasAccountContext) {
                this.dispatchEvent(
                    new CloseActionScreenEvent()
                );

                setTimeout(() => {
                    this.navigateToPurchase(
                        result.purchaseId
                    );
                }, 0);
            } else {
                this.navigateToPurchase(
                    result.purchaseId
                );
            }
        } catch (error) {
            this.showError(
                "Unable to create purchase",
                error
            );
        } finally {
            this.isCheckingOut = false;
        }
    }

    navigateToPurchase(purchaseId) {
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: purchaseId,
                objectApiName: "Purchase__c",
                actionName: "view"
            }
        });
    }

    async handleViewDetails(event) {
        const itemId = event.currentTarget.dataset.id;

        const selectedItem = this.items.find(
            (item) => item.Id === itemId
        );

        if (!selectedItem) {
            this.showToast(
                "Item Not Found",
                "The selected item could not be loaded.",
                "error"
            );

            return;
        }

        await ItemDetailsModal.open({
            size: "medium",
            description: `Details for ${selectedItem.Name}`,
            item: selectedItem
        });
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
            availableQuantity:
                item.AvailableQuantity__c,
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
