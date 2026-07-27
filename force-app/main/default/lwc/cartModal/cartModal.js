import { api } from "lwc";
import LightningModal from "lightning/modal";

export default class CartModal extends LightningModal {
    @api cartItems = [];
    @api currencyCode;

    lines = [];

    connectedCallback() {
        this.lines = (this.cartItems || []).map((line) => ({
            ...line
        }));
    }

    get hasLines() {
        return this.lines.length > 0;
    }

    get totalItems() {
        return this.lines.reduce(
            (total, line) => total + line.quantity,
            0
        );
    }

    get grandTotal() {
        return this.lines.reduce(
            (total, line) => total + line.lineTotal,
            0
        );
    }

    get checkoutDisabled() {
        return !this.hasLines;
    }

    handleQuantityChange(event) {
        const itemId = event.target.dataset.id;
        const quantity = Number(event.target.value);

        const currentLine = this.lines.find(
            (line) => line.itemId === itemId
        );

        if (!currentLine) {
            return;
        }

        event.target.setCustomValidity("");

        if (!Number.isInteger(quantity) || quantity < 1) {
            event.target.setCustomValidity(
                "Quantity must be a whole number greater than zero."
            );

            event.target.reportValidity();
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

        this.lines = this.lines.map((line) =>
            line.itemId === itemId
                ? {
                      ...line,
                      quantity,
                      lineTotal: line.price * quantity
                  }
                : line
        );
    }

    handleRemove(event) {
        const itemId = event.currentTarget.dataset.id;

        this.lines = this.lines.filter(
            (line) => line.itemId !== itemId
        );
    }

    handleClose() {
        this.close({
            action: "update",
            lines: this.lines
        });
    }

    handleCheckout() {
        const quantityInputs = [
            ...this.template.querySelectorAll(
                "[data-quantity-input]"
            )
        ];

        const isValid = quantityInputs.reduce(
            (valid, input) => {
                input.reportValidity();

                return input.checkValidity() && valid;
            },
            true
        );

        if (!isValid) {
            return;
        }

        this.close({
            action: "checkout",
            lines: this.lines
        });
    }
}
