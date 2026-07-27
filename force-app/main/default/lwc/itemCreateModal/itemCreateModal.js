import { api } from "lwc";
import LightningModal from "lightning/modal";

import searchPhotos from "@salesforce/apex/ItemManagementController.searchPhotos";
import createItem from "@salesforce/apex/ItemManagementController.createItem";

export default class ItemCreateModal extends LightningModal {
    @api typeOptions = [];
    @api familyOptions = [];

    itemDraft = {
        name: "",
        description: "",
        itemType: "",
        family: "",
        price: null,
        availableQuantity: null
    };

    photos = [];
    selectedPhotoId = null;

    errorMessage = "";
    isSearchingPhotos = false;
    isSaving = false;

    get hasPhotos() {
        return this.photos.length > 0;
    }

    get photoSearchQuery() {
        return (
            this.itemDraft.name?.trim() ||
            "Enter an item name first."
        );
    }

    get searchDisabled() {
        return (
            this.isSearchingPhotos ||
            !this.itemDraft.name?.trim()
        );
    }

    get saveDisabled() {
        return this.isSaving;
    }

    handleFieldChange(event) {
        const fieldName = event.target.name;

        let value =
            event.detail?.value ?? event.target.value;

        if (event.target.type === "number") {
            value =
                value === "" || value === null
                    ? null
                    : Number(value);
        }

        const itemNameChanged =
            fieldName === "name" &&
            value !== this.itemDraft.name;

        this.itemDraft = {
            ...this.itemDraft,
            [fieldName]: value
        };

        if (itemNameChanged) {
            this.photos = [];
            this.selectedPhotoId = null;
        }
    }

    async handlePhotoSearch() {
        const searchTerm =
            this.itemDraft.name?.trim();

        if (!searchTerm) {
            this.errorMessage =
                "Enter an item name before searching for a photo.";
            return;
        }

        this.errorMessage = "";
        this.isSearchingPhotos = true;
        this.selectedPhotoId = null;

        try {
            const result = await searchPhotos({
                searchTerm
            });

            this.photos = (result || []).map((photo) =>
                this.decoratePhoto(photo)
            );

            if (this.photos.length === 0) {
                this.errorMessage =
                    "No matching Unsplash photos were found.";
            }
        } catch (error) {
            this.photos = [];
            this.errorMessage =
                this.getErrorMessage(error);
        } finally {
            this.isSearchingPhotos = false;
        }
    }

    handlePhotoSelect(event) {
        const photoId =
            event.currentTarget.dataset.id;

        this.selectedPhotoId =
            this.selectedPhotoId === photoId
                ? null
                : photoId;

        this.photos = this.photos.map((photo) =>
            this.decoratePhoto(photo)
        );
    }

    async handleSave() {
        this.errorMessage = "";

        if (!this.validateForm()) {
            return;
        }

        this.isSaving = true;

        try {
            const itemId = await createItem({
                request: {
                    ...this.itemDraft,
                    unsplashPhotoId:
                        this.selectedPhotoId
                }
            });

            this.close({
                created: true,
                itemId
            });
        } catch (error) {
            this.errorMessage =
                this.getErrorMessage(error);
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        this.close({
            created: false
        });
    }

    validateForm() {
        const fields = [
            ...this.template.querySelectorAll(
                "[data-form-field]"
            )
        ];

        return fields.reduce((isValid, field) => {
            field.reportValidity();

            return (
                field.checkValidity() && isValid
            );
        }, true);
    }

    decoratePhoto(photo) {
        const isSelected =
            photo.id === this.selectedPhotoId;

        return {
            ...photo,
            isSelected,
            cardClass: isSelected
                ? "photo-card photo-card_selected"
                : "photo-card"
        };
    }

    getErrorMessage(error) {
        return (
            error?.body?.message ||
            error?.message ||
            "An unexpected error occurred."
        );
    }
}
