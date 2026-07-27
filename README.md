# Item Purchase Tool

A one-page Salesforce application for browsing catalogue items, managing a cart, creating purchases, updating inventory, and notifying inventory managers when an item goes out of stock.

The application is built with Lightning Web Components, Apex, Record-Triggered Flows, Custom Objects, Salesforce notifications, and the Unsplash API.

## Current Release

**Version:** 1.1
**Status:** Completed
**Package type:** First-generation unmanaged package

**GitHub repository:**
https://github.com/Temaaaaaa/item-purchase-tool-test

**Installation URL:**
https://login.salesforce.com/packaging/installPackage.apexp?p0=04tg7000000GSum

**Package Version ID:** `04tg7000000GSum`

---

## Release History

| Version | Status | Package Version ID | Description |
|---|---|---|---|
| 1.0 | Initial release | `04tg7000000GStB` | Base catalogue, checkout, inventory automation, manager item creation, and Unsplash integration |
| 1.1 | Current release | `04tg7000000GSum` | Full Account Quick Action workflow, Account context, item details modal, cart modal, automatic Unsplash search, and Purchase navigation |

### Version 1.0

Version 1.0 introduced the initial working application.

It included:

- the Item, Purchase, and Purchase Line data model;
- a searchable and filterable item catalogue;
- cart and checkout logic;
- secure stock validation;
- Purchase and Purchase Line creation;
- automatic inventory updates;
- Record-Triggered Flows for Purchase totals;
- out-of-stock Bell and email notifications;
- manager-only item creation;
- Unsplash image search;
- photo attribution;
- Apex Unit Tests;
- a Permission Set;
- a Lightning application and tab;
- the first unmanaged package.

In this version, the application was mainly opened through its standalone Lightning application. The cart was displayed directly on the main page, and the user selected the client manually.

### Version 1.1

Version 1.1 completes the Account-based workflow required by the task.

Changes in version 1.1:

- added an Account Lightning Quick Action;
- added the Quick Action to the Account layout;
- the application now opens in a modal from an Account record;
- the current Account is automatically used as the Purchase client;
- Account Name, Account Number, and Industry are displayed;
- added the number of currently listed catalogue items;
- added an Item Details modal;
- added a Cart button with the selected item count;
- moved the cart into a modal window;
- cart lines are displayed in table form;
- quantity can be changed directly in the cart modal;
- cart lines can be removed before checkout;
- successful checkout redirects the user to the standard Purchase record page;
- Unsplash search now automatically uses the Item Name;
- improved responsive styling for the Account Quick Action modal;
- added `cartModal` and `itemDetailsModal` Lightning Web Components.

Version 1.1 is the current recommended version.

---

## Main Features

### Account Quick Action

The application can be opened directly from an Account record through the `Item Purchase Tool` Quick Action.

When opened from Account, it automatically receives the Account ID and displays:

- Account Name;
- Account Number;
- Industry.

The current Account is automatically used as the client during checkout.

The application can also still be opened from its standalone Lightning tab. In that mode, the user can select an Account manually.

### Item Catalogue

Users can:

- view available catalogue items;
- search by item name and description;
- filter by Type;
- filter by Family;
- see the number of listed items;
- view item images;
- see prices and available quantities;
- open item details;
- add items to the cart.

Only items with `AvailableQuantity__c > 0` are returned by the catalogue.

### Item Details

Each item tile contains a `Details` button.

The Item Details modal displays:

- item image;
- name;
- description;
- price;
- Type;
- Family;
- available quantity;
- Unsplash attribution.

The record fields are displayed using Lightning Data Service and `lightning-record-view-form`.

### Cart

The `Cart` button displays the current total quantity:

```text
Cart (3)
```

The cart opens in a modal window and displays selected items in table form.

Users can:

- review item names;
- see unit prices;
- change quantities;
- see available stock;
- see line totals;
- remove cart lines;
- see Total Items;
- see Grand Total;
- complete checkout.

### Checkout

Checkout is handled by Apex as a single transaction.

The controller:

1. validates the selected Account;
2. validates that the cart is not empty;
3. validates all quantities;
4. aggregates duplicate item lines;
5. queries the required Items;
6. locks Item records with `FOR UPDATE`;
7. validates prices and available stock;
8. creates the Purchase;
9. creates Purchase Line records;
10. decreases Item stock;
11. saves Purchase totals;
12. rolls back all changes if any step fails.

After successful checkout, the application navigates to the standard page of the newly created Purchase record.

### Manager Item Creation

Users with:

```text
User.IsManager__c = true
```

can see the `New Item` button.

A manager can:

- enter an item name;
- enter a description;
- select Type and Family;
- enter a price;
- enter an available quantity;
- search Unsplash using the Item Name;
- select an image;
- create the Item;
- immediately see it in the catalogue.

Manager access is checked both in the LWC and in Apex.

### Unsplash Integration

Item images are loaded through the Unsplash API.

The integration uses:

- Named Credential `Unsplash_API`;
- External Credential `Unsplash_API_External_Credential`;
- Named Principal `UnsplashPrincipal`;
- Trusted URL `Unsplash_Images`;
- Trusted URL `Unsplash_Plus_Images`.

The Unsplash Access Key is not stored in Apex, JavaScript, or GitHub.

Apex callouts use:

```text
callout:Unsplash_API
```

When a photo is selected, the application stores:

- image URL;
- photographer name;
- photographer profile URL;
- original photo URL.

The catalogue displays attribution in this form:

```text
Photo by [Photographer] on Unsplash
```

### Purchase Total Automation

Purchase totals are recalculated by Record-Triggered Flows.

The following fields are updated:

```text
Purchase__c.TotalItems__c
Purchase__c.GrandTotal__c
```

Flows:

```text
Recalculate_Purchase_Totals_On_Line_Change
Recalculate_Purchase_Totals_On_Line_Delete
```

The totals remain correct when Purchase Line records are created, updated, or deleted.

### Out-of-Stock Notifications

The `Item_Out_of_Stock_Notification` Flow runs after an Item update when:

```text
AvailableQuantity__c = 0
```

and the field value has changed.

The Flow sends:

- a Salesforce Bell Notification;
- an email notification.

Notification configuration is stored in the Hierarchy Custom Setting:

```text
InventoryNotificationSettings__c
```

Fields:

```text
Recipient_User__c
Recipient_Email__c
```

`Recipient_User__c` stores a Salesforce User ID in a Text field because Hierarchy Custom Settings do not support Lookup relationships.

---

## Architecture

| Layer | Implementation |
|---|---|
| User interface | Lightning Web Components |
| Business logic | Apex |
| Data model | Custom Objects and Custom Fields |
| Automation | Record-Triggered Flows |
| Security | Permission Set, sharing, user-mode access |
| Integration | Named Credential and External Credential |
| Notifications | Custom Notification, Email Alert, Email Template |
| Distribution | Unmanaged Package |

---

## Lightning Web Components

| Component | Purpose |
|---|---|
| `itemPurchaseTool` | Main catalogue and purchase application |
| `itemCreateModal` | Manager-only Item creation and Unsplash search |
| `itemDetailsModal` | Item details modal |
| `cartModal` | Cart table, quantity management, and checkout |

---

## Apex Classes

### Catalogue

| Class | Purpose |
|---|---|
| `ItemCatalogueController` | Loads catalogue items, filters, and manager status |
| `ItemCatalogueFilterOptions` | Filter options DTO |
| `ItemCatalogueControllerTest` | Catalogue Unit Tests |

### Checkout

| Class | Purpose |
|---|---|
| `PurchaseCheckoutController` | Creates Purchases and updates stock |
| `PurchaseCheckoutLineRequest` | Checkout request DTO |
| `PurchaseCheckoutResult` | Checkout result DTO |
| `PurchaseCheckoutControllerTest` | Checkout Unit Tests |

### Item Management

| Class | Purpose |
|---|---|
| `ItemManagementController` | Searches Unsplash and creates Items |
| `ItemCreateRequest` | Item creation request DTO |
| `UnsplashPhotoOption` | Unsplash photo response DTO |
| `ItemManagementControllerTest` | Item management and callout Unit Tests |

---

## Data Model

### Item

API name:

```text
Item__c
```

| Field | API Name |
|---|---|
| Name | `Name` |
| Description | `Description__c` |
| Type | `Type__c` |
| Family | `Family__c` |
| Image | `Image__c` |
| Price | `Price__c` |
| Available Quantity | `AvailableQuantity__c` |
| Notification Recipient Email | `NotificationRecipientEmail__c` |
| Image Photographer | `ImagePhotographer__c` |
| Image Photographer URL | `ImagePhotographerUrl__c` |
| Image Source URL | `ImageSourceUrl__c` |

### Purchase

API name:

```text
Purchase__c
```

| Field | API Name |
|---|---|
| Purchase Number | `Name` |
| Client | `ClientId__c` |
| Total Items | `TotalItems__c` |
| Grand Total | `GrandTotal__c` |

### Purchase Line

API name:

```text
PurchaseLine__c
```

| Field | API Name |
|---|---|
| Purchase Line Number | `Name` |
| Purchase | `PurchaseId__c` |
| Item | `ItemId__c` |
| Amount | `Amount__c` |
| Unit Cost | `UnitCost__c` |

### User

| Field | API Name |
|---|---|
| Is Manager | `User.IsManager__c` |

---

## Security

The project uses:

- `with sharing`;
- user-mode SOQL;
- user-mode DML;
- server-side manager validation;
- a dedicated Permission Set;
- External Credential Principal Access;
- Named Credential callouts;
- no API keys in source control;
- `FOR UPDATE` inventory locking.

Permission Set:

```text
Item_Purchase_Tool_User
```

---

## Installation

### Recommended: Install Version 1.1

Open:

```text
https://login.salesforce.com/packaging/installPackage.apexp?p0=04tg7000000GSum
```

Package information:

```text
Package Name: Item Purchase Tool
Version: 1.1
Package Version ID: 04tg7000000GSum
```

The package is unmanaged, so installed metadata can be viewed and modified in the target Salesforce Org.

### Install from Source

Clone the repository:

```bash
git clone https://github.com/Temaaaaaa/item-purchase-tool-test.git
cd item-purchase-tool-test
```

Authorize an org:

```bash
sf org login web --alias item-purchase-org --set-default
```

Deploy the project:

```bash
sf project deploy start \
  --source-dir force-app \
  --target-org item-purchase-org \
  --wait 30
```

Assign the Permission Set:

```bash
sf org assign permset \
  --name Item_Purchase_Tool_User \
  --target-org item-purchase-org
```

---

## Post-Installation Configuration

### Unsplash External Credential

Open:

```text
Setup
→ Named Credentials
→ External Credentials
→ Unsplash API External Credential
```

Configure the principal:

```text
Principal Name: UnsplashPrincipal
Identity Type: Named Principal
Authentication Parameter: AccessKey
```

Enter the Unsplash Access Key as the `AccessKey` value.

The authorization header must produce:

```text
Authorization: Client-ID YOUR_ACCESS_KEY
```

Do not store the key in Git.

### External Credential Access

Open:

```text
Setup
→ Permission Sets
→ Item Purchase Tool User
→ External Credential Principal Access
```

Grant access to:

```text
Unsplash API External Credential - UnsplashPrincipal
```

### Notification Settings

Open:

```text
Setup
→ Custom Settings
→ Inventory Notification Settings
→ Manage
```

Set:

```text
Recipient User
Recipient Email
```

Custom Setting records are data and are not included in the package.

### Manager Access

For users who need to create Items:

1. assign `Item_Purchase_Tool_User`;
2. enable `User.IsManager__c`.

### Account Quick Action

The package contains the Account Quick Action and Account layout configuration.

After installation, verify that `Item Purchase Tool` is visible in:

```text
Object Manager
→ Account
→ Page Layouts
→ Salesforce Mobile and Lightning Experience Actions
```

---

## Apex Tests

Test classes:

```text
ItemCatalogueControllerTest
PurchaseCheckoutControllerTest
ItemManagementControllerTest
```

Run all project tests:

```bash
sf apex run test \
  --tests ItemCatalogueControllerTest \
  --tests PurchaseCheckoutControllerTest \
  --tests ItemManagementControllerTest \
  --target-org item-purchase-org \
  --result-format human \
  --code-coverage \
  --wait 30
```

The tests cover:

- catalogue loading;
- text search;
- Type and Family filters;
- manager access;
- successful checkout;
- duplicate line aggregation;
- insufficient stock;
- transaction rollback;
- empty cart validation;
- Item creation;
- Item creation without a photo;
- invalid Item requests;
- non-manager access;
- Unsplash response mapping;
- mocked HTTP callouts.

---

## Manual Verification

### Account Quick Action

1. Open an Account.
2. Click `Item Purchase Tool`.
3. Confirm that the application opens in a modal.
4. Confirm that Account Name, Account Number, and Industry are displayed.
5. Confirm that the current Account is used as the client.

### Catalogue

1. Search by name or description.
2. Filter by Type.
3. Filter by Family.
4. Confirm that `Listed Items` changes.
5. Open an Item through `Details`.

### Cart and Checkout

1. Click `Add` on an Item.
2. Confirm that the Cart count changes.
3. Open the Cart.
4. Change the quantity.
5. Remove and add lines.
6. Click `Checkout`.
7. Confirm that the Purchase is created.
8. Confirm that Salesforce opens the created Purchase record.
9. Confirm that Item stock decreases.

### Manager Item Creation

1. Log in as a manager.
2. Click `New Item`.
3. Enter an Item Name.
4. Confirm that the Unsplash search query uses the Item Name.
5. Search for photos.
6. Select a photo.
7. Create the Item.
8. Confirm that it appears in the catalogue.

### Out-of-Stock Automation

1. Purchase the complete remaining quantity of an Item.
2. Confirm that its quantity becomes zero.
3. Confirm that the Bell Notification is received.
4. Confirm that the email notification is received.
5. Confirm that the Item is removed from the catalogue.

---

## Package Data Limitations

The unmanaged package does not include:

- Unsplash Access Key;
- Hierarchy Custom Setting records;
- Accounts;
- Item records;
- Purchase records;
- Purchase Line records;
- Salesforce users;
- Permission Set assignments.

These values must be created or configured in the target Org.

---

## Known Limitations

- LWC Jest tests are not included. Apex business logic is covered by Apex Unit Tests.
- The application supports Item creation but does not provide a separate Item edit or delete interface.
- Items with zero available quantity are intentionally hidden from the catalogue.
- External Credential secrets must be configured after installation.
- Hierarchy Custom Setting records must be configured after installation.
- Unsplash search depends on the availability and limits of the configured Unsplash application.
- Unmanaged packages do not provide an automatic upgrade path.

---

## Repository Structure

```text
force-app/main/default/
├── applications/
├── classes/
├── cspTrustedSites/
├── customNotificationTypes/
├── email/
├── externalCredentials/
├── flows/
├── layouts/
├── lwc/
│   ├── cartModal/
│   ├── itemCreateModal/
│   ├── itemDetailsModal/
│   └── itemPurchaseTool/
├── namedCredentials/
├── objects/
├── permissionsets/
├── quickActions/
├── tabs/
└── workflows/
```

---

## Links

**GitHub:**
https://github.com/Temaaaaaa/item-purchase-tool-test

**Current unmanaged package — Version 1.1:**
https://login.salesforce.com/packaging/installPackage.apexp?p0=04tg7000000GSum

**Previous unmanaged package — Version 1.0:**
https://login.salesforce.com/packaging/installPackage.apexp?p0=04tg7000000GStB
