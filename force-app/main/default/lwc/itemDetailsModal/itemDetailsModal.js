import { api } from "lwc";
import LightningModal from "lightning/modal";

export default class ItemDetailsModal extends LightningModal {
    @api item;

    handleClose() {
        this.close();
    }
}
