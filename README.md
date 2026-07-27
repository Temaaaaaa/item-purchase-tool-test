# Item Purchase Tool

Item Purchase Tool is a one-page Salesforce application for browsing catalogue items, creating purchases, managing inventory, and sending notifications when an item goes out of stock.

The application is built with Lightning Web Components, Apex, record-triggered flows, custom objects, a hierarchy custom setting, Salesforce notifications, and an Unsplash integration.

## Features

- Search and filter catalogue items by type and family.
- Display item images, descriptions, prices, and available quantities.
- Add items to a cart and change their quantities.
- Select an Account as the purchase client.
- Create a Purchase with related Purchase Line records.
- Validate stock and prevent overselling.
- Update item inventory inside a secure Apex transaction.
- Recalculate purchase totals when purchase lines are created, updated, or deleted.
- Send an email and a Salesforce custom notification when stock reaches zero.
- Allow managers to create catalogue items from the application.
- Search and select item photos through the Unsplash API.
- Store and display the required Unsplash photo attribution.

## User Stories

### Catalogue and filtering

As a user, I want to search and filter available items so that I can quickly find a product.

The catalogue:

- returns only items with available stock;
- supports text search;
- supports Type and Family filters;
- displays the current price and available quantity.

Implementation:

- `itemPurchaseTool`
- `ItemCatalogueController`
- `ItemCatalogueFilterOptions`

### Purchase creation

As a user, I want to add items to a cart and create a purchase for a selected client.

The checkout process:

- requires an Account;
- requires at least one cart line;
- validates quantities;
- prevents quantities greater than available stock;
- aggregates duplicate item lines;
- creates one Purchase and its Purchase Line records;
- decreases stock;
- returns the created purchase name and totals.

Implementation:

- `itemPurchaseTool`
- `PurchaseCheckoutController`
- `PurchaseCheckoutLineRequest`
- `PurchaseCheckoutResult`

### Manager item creation

As a manager, I want to create catalogue items without leaving the application.

The manager can:

- enter item information;
- select Type and Family values;
- enter price and available quantity;
- search Unsplash for a photo;
- select a photo;
- create the item;
- immediately see the item in the catalogue.

The `New Item` button is shown only when the current user has `User.IsManager__c = true`. The same permission is validated again in Apex.

Implementation:

- `itemCreateModal`
- `ItemManagementController`
- `ItemCreateRequest`
- `UnsplashPhotoOption`

### Inventory automation

As an inventory manager, I want to receive a notification when an item becomes unavailable.

When `Item__c.AvailableQuantity__c` changes to zero, Salesforce:

- sends a custom notification;
- sends an email alert;
- uses configurable notification recipients.

Implementation:

- `Item_Out_of_Stock_Notification`
- `Item_Out_of_Stock`
- `Out_of_Stock_Item_Alert`
- `Out_of_Stock_Item_Notification`
- `InventoryNotificationSettings__c`

### Purchase total calculation

As a user, I want purchase totals to remain correct when purchase lines change.

The flows recalculate:

- total item quantity;
- grand total.

Implementation:

- `Recalculate_Purchase_Totals_On_Line_Change`
- `Recalculate_Purchase_Totals_On_Line_Delete`

## Application Architecture

| Layer | Components |
|---|---|
| User interface | Lightning Web Components |
| Business logic | Apex controllers |
| Data model | Custom objects and fields |
| Automation | Record-triggered flows |
| Security | Permission Set, user-mode Apex, manager validation |
| Integration | Named Credential and External Credential |
| Notifications | Custom notification, email alert, email template |
| Distribution | First-generation unmanaged package |

## Lightning Web Components

### `itemPurchaseTool`

Main application component.

Responsibilities:

- load catalogue items;
- load filter options;
- search and filter items;
- manage the cart;
- select a client Account;
- create purchases;
- open the item creation modal;
- refresh the catalogue after changes.

### `itemCreateModal`

Manager-only item creation modal.

Responsibilities:

- collect item information;
- validate form fields;
- search Unsplash photos;
- display photo attribution;
- select a photo;
- call Apex to create the item.

## Apex Classes

### Catalogue

| Class | Purpose |
|---|---|
| `ItemCatalogueController` | Loads catalogue items, filter options, and manager status |
| `ItemCatalogueFilterOptions` | DTO for Type and Family options |
| `ItemCatalogueControllerTest` | Unit tests for catalogue logic |

### Checkout

| Class | Purpose |
|---|---|
| `PurchaseCheckoutController` | Creates purchases and updates inventory |
| `PurchaseCheckoutLineRequest` | Checkout line request DTO |
| `PurchaseCheckoutResult` | Checkout result DTO |
| `PurchaseCheckoutControllerTest` | Unit tests for checkout logic |

### Item management

| Class | Purpose |
|---|---|
| `ItemManagementController` | Searches Unsplash and creates items |
| `ItemCreateRequest` | Item creation request DTO |
| `UnsplashPhotoOption` | Unsplash search result DTO |
| `ItemManagementControllerTest` | Unit tests for item management and callouts |

## Data Model

### Item

API name: `Item__c`

| Field | API name | Type |
|---|---|---|
| Item Name | `Name` | Text |
| Description | `Description__c` | Long Text Area |
| Type | `Type__c` | Picklist |
| Family | `Family__c` | Picklist |
| Image | `Image__c` | URL |
| Price | `Price__c` | Currency |
| Available Quantity | `AvailableQuantity__c` | Number |
| Notification Recipient Email | `NotificationRecipientEmail__c` | Email |
| Image Photographer | `ImagePhotographer__c` | Text |
| Image Photographer URL | `ImagePhotographerUrl__c` | URL |
| Image Source URL | `ImageSourceUrl__c` | URL |

### Purchase

API name: `Purchase__c`

| Field | API name | Type |
|---|---|---|
| Purchase Number | `Name` | Auto Number |
| Client | `ClientId__c` | Lookup to Account |
| Total Items | `TotalItems__c` | Number |
| Grand Total | `GrandTotal__c` | Currency |

### Purchase Line

API name: `PurchaseLine__c`

| Field | API name | Type |
|---|---|---|
| Purchase Line Number | `Name` | Auto Number |
| Purchase | `PurchaseId__c` | Master-Detail to Purchase |
| Item | `ItemId__c` | Master-Detail to Item |
| Amount | `Amount__c` | Number |
| Unit Cost | `UnitCost__c` | Currency |

### Inventory Notification Settings

API name: `InventoryNotificationSettings__c`

Type: Hierarchy Custom Setting

| Field | API name |
|---|---|
| Recipient User | `Recipient_User__c` |
| Recipient Email | `Recipient_Email__c` |

### User manager field

| Field | API name | Type |
|---|---|---|
| Is Manager | `User.IsManager__c` | Checkbox |

## Checkout Transaction

Purchase creation is executed inside Apex as one transaction.

The controller:

1. validates the selected Account;
2. validates the cart;
3. aggregates duplicate item lines;
4. queries the required items;
5. locks item records with `FOR UPDATE`;
6. checks prices and available quantities;
7. creates the Purchase;
8. creates Purchase Line records;
9. decreases item stock;
10. saves the purchase totals;
11. rolls back all changes when any step fails.

This prevents partial purchases and reduces the risk of multiple users purchasing the same remaining stock at the same time.

## Security

The application uses several security layers.

### Sharing

Apex controllers use:

```apex
with sharing
```

This respects Salesforce record-sharing rules.

### User-mode database access

Catalogue queries use user-mode database access.

The application also uses user-mode DML where appropriate:

```apex
insert as user
update as user
```

This enforces the current user's object and field permissions.

### Manager validation

Manager functionality is protected in two places:

- the `New Item` button is displayed only to managers;
- Apex independently verifies `User.IsManager__c`.

A user cannot bypass the server-side check by modifying JavaScript in the browser.

### Permission Set

Permission Set:

```text
Item_Purchase_Tool_User
```

It grants access to:

- project custom objects;
- required custom fields;
- Apex controllers;
- the application tab;
- custom notification permissions;
- the Unsplash External Credential principal.

## Unsplash Integration

The application uses Unsplash to search for item photos.

### Components

| Component | API name |
|---|---|
| Named Credential | `Unsplash_API` |
| External Credential | `Unsplash_API_External_Credential` |
| Principal | `UnsplashPrincipal` |
| Trusted URL | `Unsplash_Images` |
| Trusted URL | `Unsplash_Plus_Images` |

The API base URL is:

```text
https://api.unsplash.com
```

The Access Key is stored in the External Credential and is not hardcoded in Apex or JavaScript.

Apex performs callouts through:

```text
callout:Unsplash_API
```

When a manager selects a photo, the application:

1. loads the selected photo from Unsplash by ID;
2. validates the returned URLs;
3. registers the photo download through `download_location`;
4. stores the image URL;
5. stores the photographer name;
6. stores the photographer profile URL;
7. stores the original photo URL.

The application displays attribution in the catalogue:

```text
Photo by [Photographer] on Unsplash
```

## Record-Triggered Flows

### Item Out of Stock Notification

API name:

```text
Item_Out_of_Stock_Notification
```

Runs after an Item update when:

```text
AvailableQuantity__c = 0
```

and the value has changed.

Actions:

- send the `Item_Out_of_Stock` custom notification;
- send the `Out_of_Stock_Item_Alert` email alert.

### Recalculate Purchase Totals on Line Change

API name:

```text
Recalculate_Purchase_Totals_On_Line_Change
```

Runs after a Purchase Line is created or updated.

It recalculates:

```text
Purchase.TotalItems__c
Purchase.GrandTotal__c
```

### Recalculate Purchase Totals on Line Delete

API name:

```text
Recalculate_Purchase_Totals_On_Line_Delete
```

Runs before a Purchase Line is deleted.

It recalculates the parent Purchase using the remaining Purchase Line records.

## Notifications

### Custom Notification Type

```text
Item_Out_of_Stock
```

### Email Alert

```text
Out_of_Stock_Item_Alert
```

### Classic Email Template

```text
Item_Purchase_Tool_Templates/Out_of_Stock_Item_Notification
```

The template is stored in a public Classic Email Template folder so it can be included in the unmanaged package.

## Project Structure

```text
force-app/main/default/
├── applications/
├── classes/
├── cspTrustedSites/
├── customNotificationTypes/
├── email/
├── externalCredentials/
├── flows/
├── lwc/
│   ├── itemCreateModal/
│   └── itemPurchaseTool/
├── namedCredentials/
├── objects/
│   ├── InventoryNotificationSettings__c/
│   ├── Item__c/
│   ├── Purchase__c/
│   ├── PurchaseLine__c/
│   └── User/
├── permissionsets/
├── tabs/
└── workflows/
```

## Prerequisites

Install:

- Salesforce CLI;
- Git;
- Node.js and npm;
- Visual Studio Code;
- Salesforce Extension Pack;
- Java 21 for the Apex language server.

A Salesforce Developer Edition, sandbox, or scratch org is also required.

## Source Installation

Clone the repository:

```bash
git clone <repository-url>
cd saleforce_project
```

Authorize a Salesforce org:

```bash
sf org login web --alias item-purchase-org --set-default
```

Deploy the metadata:

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

## Post-Deployment Configuration

### Configure the Unsplash External Credential

Open:

```text
Setup
→ Named Credentials
→ External Credentials
→ Unsplash API External Credential
```

Create or configure the named principal:

```text
Principal Name: UnsplashPrincipal
Identity Type: Named Principal
Authentication Parameter: AccessKey
```

Enter the Unsplash Access Key as the value of `AccessKey`.

The authorization header must produce:

```text
Authorization: Client-ID YOUR_ACCESS_KEY
```

Do not commit the Access Key to Git.

### Grant principal access

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

### Configure notification recipients

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

Custom Setting records are org data and are not deployed with metadata.

### Assign manager access

For users who need to create catalogue items, enable:

```text
User.IsManager__c
```

Also assign the `Item_Purchase_Tool_User` Permission Set.

## Unmanaged Package

Package name:

```text
Item Purchase Tool
```

Version:

```text
1.0
```

Package Version ID:

```text
04tg7000000GStB
```

Installation URL:

```text
https://login.salesforce.com/packaging/installPackage.apexp?p0=04tg7000000GStB
```

The package is unmanaged. Installed components can be viewed and modified in the target organization.

### Package post-installation steps

After installing the package:

1. enter the Unsplash Access Key in the External Credential;
2. verify the `UnsplashPrincipal`;
3. grant External Credential Principal Access;
4. assign the `Item_Purchase_Tool_User` Permission Set;
5. populate `Inventory Notification Settings`;
6. enable `User.IsManager__c` for manager users;
7. verify that the Item Purchase Tool application and tab are visible;
8. create test Accounts and catalogue Items if required.

The following values are not included in the package:

- Unsplash Access Key;
- hierarchy custom setting records;
- Accounts;
- Item records;
- Purchase records;
- Purchase Line records;
- Salesforce users;
- Permission Set assignments.

## Apex Tests

The project contains the following Apex test classes:

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

The test suite covers:

- catalogue search and filtering;
- manager status;
- successful checkout;
- duplicate cart line aggregation;
- insufficient stock;
- transaction rollback;
- empty cart validation;
- Unsplash response mapping;
- mocked HTTP callouts;
- manager-only item creation;
- invalid item requests;
- item creation with and without a photo.

## Manual Verification

### Catalogue

1. Open the Item Purchase Tool application.
2. Confirm that available items are shown.
3. Test text search.
4. Test Type and Family filters.

### Checkout

1. Select an Account.
2. Add an item to the cart.
3. Change the quantity.
4. Create a purchase.
5. Confirm that Purchase and Purchase Line records were created.
6. Confirm that item stock decreased.

### Out-of-stock automation

1. Set an item quantity to a value greater than zero.
2. Purchase the complete remaining quantity.
3. Confirm that the quantity becomes zero.
4. Confirm that the custom notification is received.
5. Confirm that the email notification is received.

### Manager item creation

1. Open the application as a manager.
2. Click `New Item`.
3. Enter item information.
4. Search for an Unsplash photo.
5. Select a photo.
6. Create the item.
7. Confirm that the new item appears in the catalogue.
8. Confirm that photo attribution is displayed.

## Important Implementation Decisions

### Separate DTO classes

Request and response DTOs are implemented as top-level Apex classes because they are passed between Apex and Lightning Web Components.

### Server-side validation

All critical validation is performed in Apex. Client-side validation improves the user experience but is not treated as a security boundary.

### Inventory locking

Items are queried with `FOR UPDATE` during checkout to reduce race conditions and prevent overselling.

### Named Credential

The Unsplash key is stored in Salesforce configuration instead of source code.

### Flow-based totals

Purchase totals are recalculated through record-triggered flows so they remain correct when Purchase Line records are edited outside the custom checkout interface.

## Known Limitations

- The unmanaged package does not provide an automatic upgrade path.
- Org data is not included in the package.
- External Credential secrets must be configured manually.
- Hierarchy Custom Setting values must be configured manually.
- Unsplash availability and API limits depend on the configured Unsplash application.
- The catalogue displays only items with available quantity greater than zero.
- LWC Jest tests are not included. Apex business logic is covered by Apex unit tests.

## Useful Links

- Salesforce Developer Documentation: https://developer.salesforce.com/docs
- Salesforce Help: https://help.salesforce.com
- Unsplash API Documentation: https://unsplash.com/documentation
- Unmanaged Package Installation: https://login.salesforce.com/packaging/installPackage.apexp?p0=04tg7000000GStB
