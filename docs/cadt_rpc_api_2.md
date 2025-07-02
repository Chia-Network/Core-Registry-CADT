# CADT RPC API Guide - Enhanced Documentation

This page lists commands and examples from the Climate Warehouse RPC API with enhanced field documentation.

When using this guide, it is important to understand the workflow CADT employs for managing climate data updates via
RPCs.
The CADT paradigm ensures that all updates first go into local "staging", which is private and not shared with
the rest of the world. This staging process serves as an intermediate step where climate data records changes remain
isolated from the data committed to the blockchain datalayer until explicitly committed.

When editing or adding climate data records users should first use POST changes to the appropriate `projects` or `units`
resources. These POST requests populate the local staging table, allowing for updates to be collected and reviewed
in a controlled, private environment. Once reviewed users can then use `staging` RPCs to commit or deleted the staged
record
changes. Commiting the data in staging using the CADT RPC's commits the data to the blockchain, making it publicly
visible.

It is essential to remember that the staging process is distinct from the commit phase. The initial use of `projects`,
`units`, or similar RPCs prepares the data, while `staging` RPCs finalize the transition to the blockchain. This
workflow
ensures a clear separation between temporary updates and permanent, public changes, maintaining both data integrity and
transparency.

Please also see the following related documents:

- [CADT installation/configuration guide](/README.md)
- [Chia Data Layer CLI](https://docs.chia.net/datalayer-cli) reference
- [Chia Data Layer RPC API](https://docs.chia.net/datalayer-rpc) reference

The CADT RPC API is exposed by default on port 31310. This document will give examples to access the RPC API using
`http://localhost:31310/v1`.

If using a `CADT_API_KEY` append `--header 'x-api-key: <your-api-key-here>'` to your `curl` request.

## Commands

- [`organizations`](#organizations)
    - [GET Examples](#get-examples)
        - [List all subscribed organizations](#list-all-subscribed-organizations)
    - [POST Examples](#post-examples)
        - [Create an organization](#create-an-organization)
    - [PUT Examples](#put-examples)
        - [Import a home organization](#import-an-organization-and-subscribe-to-its-stores-on-datalayer)
    - [DELETE Examples](#delete-examples)
        - [Delete a home organization](#reset-home-organization)
    - [Additional organizations resources](#additional-organizations-resources)
- [`projects`](#projects)
    - [GET Examples](#get-examples-1)
        - [Show all subscribed projects](#show-projects-currently-in-the-cadt-database)
        - [Get a single project record by warehouseprojectid](#get-a-single-project-record-by-warehouseprojectid)
        - [List projects by orguid](#list-projects-by-orguid)
        - [Search for projects containing the keyword "forestry"](#search-for-projects-containing-the-keyword-forestry)
        - [Show only projects with one or more associated units containing a marketplace identifier](#show-only-projects-with-one-or-more-associated-units-containing-a-marketplace-identifier)
        - [List all projects and save the results to an xlsx file](#list-all-projects-and-save-the-results-to-an-xlsx-file)
        - [Show only the requested columns](#show-only-the-requested-columns)
    - [POST Examples](#post-examples-1)
        - [Stage a new project with the minimum required fields](#stage-a-new-project-with-the-minimum-required-fields)
        - [Stage a new project from a csv file](#stage-a-new-project-from-a-csv-file)
    - [PUT Examples](#put-examples-1)
        - [Update a pre-existing project using only the required parameters](#update-a-pre-existing-project-using-only-the-required-parameters)
        - [Update a project record with pre-existing issuance and labels](#create-a-new-project-record-with-pre-existing-issuance-and-labels)
        - [Update a pre-existing project from an xlsx file](#update-a-pre-existing-project-from-an-xlsx-file)
    - [DELETE Examples](#delete-examples)
        - [Delete a project](#delete-a-project)
    - [Additional projects resources](#additional-projects-resources)
- [`units`](#units)
    - [GET Examples](#get-examples-2)
        - [List all units from subscribed organizations](#list-all-units-from-subscribed-organizations)
        - [Search for units containing the keyword "certification"](#search-for-units-containing-the-keyword-renewable)
        - [Include project information in returned units](#include-project-information-in-returned-units)
        - [List units by OrgUid](#list-units-by-orguid)
        - [List all units and save the results to an xlsx file](#list-all-units-and-save-the-results-to-an-xlsx-file)
        - [List units using all available query string options](#list-units-using-all-available-query-string-options)
        - [Specify unit columns to include and list all unit records](#specify-unit-columns-to-include-and-list-all-unit-records)
    - [POST Examples](#post-examples-2)
        - [Create a new unit using only the required fields](#create-a-new-unit-using-only-the-required-fields)
        - [Create a new unit record with pre-existing issuance and labels](#create-a-new-unit-record-with-pre-existing-issuance-and-labels)
        - [Split units in four](#split-units-in-four)
    - [PUT Examples](#put-examples-2)
        - [Update a pre-existing unit using only the required parameters](#update-a-pre-existing-unit-using-only-the-required-parameters)
        - [Update a pre-existing unit using an xlsx file](#update-a-pre-existing-unit-using-an-xlsx-file)
    - [DELETE Examples](#delete-examples-1)
        - [Delete a unit](#delete-a-unit)
    - [Additional Units Resources](#additional-units-resources)
- [`staging`](#staging)
    - [GET Examples](#get-examples-5)
        - [List all projects and units in STAGING](#list-all-projects-and-units-in-staging)
        - [List all units in STAGING, with paging](#list-all-units-in-staging-with-paging)
    - [POST Examples](#post-examples-3)
        - [Commit all projects and units in STAGING](#commit-all-projects-and-units-in-staging)
        - [Retry committing a single project, using its uuid](#retry-committing-a-single-project-using-its-uuid)
    - [DELETE Examples](#delete-examples-2)
        - [Delete all projects and units in STAGING](#delete-all-projects-and-units-in-staging)
        - [Delete a specific project in STAGING](#delete-a-specific-project-in-staging)
        - [Delete a specific unit in STAGING](#delete-a-specific-unit-in-staging)
    - [Additional staging resources](#additional-staging-resources)
- [`issuances`](#issuances)
    - [GET Examples](#get-examples-3)
        - [List all issuances from subscribed projects](#list-all-issuances-from-subscribed-projects)
- [`labels`](#labels)
    - [GET Examples](#get-examples-4)
        - [List all labels from subscribed projects](#list-all-labels-from-subscribed-projects)
- [`audit`](#audit)
    - [GET Examples](#get-examples-6)
        - [Show the complete history of an organization](#show-the-complete-history-of-an-organization)\
- [`offer`](#offer)
    - [Get Examples](#get-examples-7)
        - [Generate and download a datalayer offer file](#generate-and-download-a-datalayer-offer-file)
        - [Get the details of the currently uploaded offer file](#get-the-details-of-the-currently-uploaded-offer-file)
    - [Post Examples](#post-examples-4)
        - [Upload an offer file](#upload-an-offer-file)
    - [Delete Examples](#delete-examples-4)
        - [Cancel the currently active offer](#cancel-the-currently-active-offer)
        - [Reject the currently imported transfer offer file](#reject-the-currently-imported-transfer-offer-file)
    - [Additonal offer resources](#additional-offer-resources)
- [`governance`](#governance)
    - [Get Examples](#get-examples-8)
        - [Get picklist data](#get-picklist-data)
        - [Get the UID's of all organizations registered in governance data](#get-the-uids-of-all-organizations-registered-in-governance-data)
    - [Post Examples](#post-examples-6)
        - [Set the governance organization list](#set-the-governance-organization-list)
    - [Additional Governance Resources](#additional-governance-resources)
- [`filestore`](#filestore)
    - [Resources](#resources)

---

## Reference

## `organizations`

Functionality: Use GET, POST, and PUT to list, create, and update organizations

### POST `/v1/organizations/create`

**Description:** Create a new home organization

**Request Body Fields:**

| Field | Type | Required | Description | Validation |
|-------|------|----------|-------------|------------|
| name | String | **Required** | Name of the organization to be created | None |
| icon | String | **Required** | URL of the icon to be used for this organization | Valid URL format |

**Example Request:**
```sh
curl --location -g --request POST 'localhost:31310/v1/organizations/create' \
     --header 'Content-Type: application/json' \
     --data-raw '{
        "name": "Sample Org",
        "icon": "https://www.chia.net/wp-content/uploads/2023/01/chia-logo-dark.svg"
}'
```

**Example Response:**
```json
{
  "message": "New organization created successfully.",
  "orgUid": "d84ab5fa679726e988b31ecc8ecff0ba8d001e9d65f1529d794fa39d32a5455e",
  "success": true
}
```

### PUT `/v1/organizations/`

**Description:** Import an organization and subscribe to its stores on datalayer

**Request Body Fields:**

| Field | Type | Required | Description | Validation |
|-------|------|----------|-------------|------------|
| orgUid | String | **Required** | OrgUid of the home organization to import | Valid UUID format |
| isHome | Boolean | Optional | Specify true if the specified orgUid should be imported as the home org | true/false |

**Example Request:**
```sh
curl --location -g --request PUT 'http://localhost:31310/v1/organizations/' \
--header 'Content-Type: application/json' \
--data-raw '{
  "orgUid": "foobar",
  "isHome": true
}'
```

**Example Response:**
```json
{
  "success": true,
  "message": "Successfully imported organization. CADT will begin syncing data from datalayer shortly"
}
```

### DELETE `/v1/organizations/{orgUid}`

**Description:** Delete a home organization

**Path Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| orgUid | String | **Required** | Organization UID to delete |

**Example Request:**
```sh
curl --location --request DELETE \
'http://localhost:31310/v1/organizations/c9661d1ce77194c9e82311418aa4d370e25e10961d74d586636354746bc9ad65'
```

**Example Response:**
```json
{
  "message": "Your home organization was reset, please create a new one.",
  "success": true
}
```

### Additional Organizations Resources

- POST `/organizations/remove-mirror` - given a store ID and coin ID removes the mirror for a given store
- POST `/organizations/sync` - runs the process to sync all subscribed organization metadata with datalayer
- POST `/organizations/create` - create an organization without an icon
- POST `/organizations/edit` - update an organization name and/or icon
- PUT `/organizations/resync` - resync an organization from datalayer
- POST `/organizations/mirror` - add a mirror for a datalayer store via the store ID
- GET `/organizations/metadata` - get an organizations metadata using the OrgUid
- GET `/organizations/status` - the sync status of an organization via the OrgUid

---

## `projects`

Functionality: List, create, and update project records

### POST `/v1/projects`

**Description:** Stage a new project record

**Request Body Fields:**

#### Required Fields
| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| projectId | String/Number | **Required** | Unique project identifier | None |
| originProjectId | String/Number | **Required** | Original project ID from source registry | None |
| registryOfOrigin | String | **Required** | Source registry name | Must be from [registry picklist](#registry-picklist) |
| projectName | String | **Required** | Project name | None |
| projectLink | String | **Required** | URL to project information | Valid URL format |
| projectDeveloper | String | **Required** | Name of project developer | None |
| sector | String | **Required** | Project sector | Must be from [sector picklist](#sector-picklist) |
| projectType | String | **Required** | Type of project | Must be from [project type picklist](#project-type-picklist) |
| coveredByNDC | String | **Required** | NDC coverage status | Must be from [NDC picklist](#ndc-picklist) |
| projectStatus | String | **Required** | Current project status | Must be from [status picklist](#status-picklist) |
| projectStatusDate | String | **Required** | Project status date | ISO 8601 date format |
| unitMetric | String | **Required** | Unit of measurement | Must be from [metric picklist](#metric-picklist) |
| methodology | String | **Required** | Project methodology | Must be from [methodology picklist](#methodology-picklist) |

#### Optional Fields
| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| program | String | Program name | None |
| projectTags | String | Comma-separated tags | None |
| ndcInformation | String | NDC-specific information | None |
| validationBody | String | Validation organization | Must be from [validation body picklist](#validation-body-picklist) |
| validationDate | String | Validation date | ISO 8601 date format |
| methodology2 | String | Secondary methodology | None |
| description | String | Project description | None |

#### Child Records (Optional)
| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| projectLocations | Array | Project location records | See [location schema](#location-schema) |
| issuances | Array | Issuance records | See [issuance schema](#issuance-schema) |
| labels | Array | Label records | See [label schema](#label-schema) |
| coBenefits | Array | Co-benefit records | See [co-benefit schema](#co-benefit-schema) |
| relatedProjects | Array | Related project records | See [related project schema](#related-project-schema) |
| projectRatings | Array | Project rating records | See [rating schema](#rating-schema) |
| estimations | Array | Estimation records | See [estimation schema](#estimation-schema) |

**Example Request (Minimum Required Fields):**
```sh
curl --location --request POST \
     -F 'projectId=c9d147e2-bc07-4e68-a76d-43424fa8cd4e' \
     -F 'originProjectId=12345-123-123-12345' \
     -F 'registryOfOrigin=UNFCCC' \
     -F 'projectName=POST sample' \
     -F 'projectLink=http://testurl.com' \
     -F 'projectDeveloper=POST developer' \
     -F 'sector=Manufacturing industries' \
     -F 'projectType=Conservation' \
     -F 'coveredByNDC=Inside NDC' \
     -F 'projectStatus=Registered' \
     -F 'projectStatusDate=2022-03-12' \
     -F 'unitMetric=tCO2e' \
     -F 'methodology=Integrated Solar Combined Cycle (ISCC) projects --- Version 1.0.0' \
     'http://localhost:31310/v1/projects'
```

**Example Response:**
```json
{
  "message": "Project staged successfully",
  "uuid": "9a29f826-ea60-489f-a290-c734e8fd57f1",
  "success": true
}
```

**Validation Errors:**
- `400 Bad Request` - Missing required fields
- `422 Unprocessable Entity` - Invalid picklist values
- `500 Internal Server Error` - Server processing error

### PUT `/v1/projects`

**Description:** Update an existing project record

**Request Body Fields:**

#### Required Fields
| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| warehouseProjectId | String | **Required** | Unique warehouse project identifier | Valid UUID format |
| projectId | String/Number | **Required** | Unique project identifier | None |
| originProjectId | String/Number | **Required** | Original project ID from source registry | None |
| registryOfOrigin | String | **Required** | Source registry name | Must be from [registry picklist](#registry-picklist) |
| projectName | String | **Required** | Project name | None |
| projectLink | String | **Required** | URL to project information | Valid URL format |
| projectDeveloper | String | **Required** | Name of project developer | None |
| sector | String | **Required** | Project sector | Must be from [sector picklist](#sector-picklist) |
| projectType | String | **Required** | Type of project | Must be from [project type picklist](#project-type-picklist) |
| coveredByNDC | String | **Required** | NDC coverage status | Must be from [NDC picklist](#ndc-picklist) |
| projectStatus | String | **Required** | Current project status | Must be from [status picklist](#status-picklist) |
| projectStatusDate | String | **Required** | Project status date | ISO 8601 date format |
| unitMetric | String | **Required** | Unit of measurement | Must be from [metric picklist](#metric-picklist) |
| methodology | String | **Required** | Project methodology | Must be from [methodology picklist](#methodology-picklist) |

**Example Request:**
```sh
curl --location -g --request PUT 'http://localhost:31310/v1/projects' \
--header 'Content-Type: application/json' \
--data-raw '{
    "warehouseProjectId": "51ca9638-22b0-4e14-ae7a-c09d23b37b58",
    "projectId": "987",
    "originProjectId": "555",
    "registryOfOrigin": "Verra",
    "projectName": "Stop Deforestation",
    "projectLink": "http://testurl.com",
    "projectDeveloper": "Example Developer",
    "sector": "Mining/Mineral production",
    "projectType": "Afforestation",
    "coveredByNDC": "Inside NDC",
    "ndcInformation": "Shuffletag",
    "projectStatus": "Listed",
    "projectStatusDate": "2022-03-19",
    "unitMetric": "tCO2e",
    "methodology": "Baseline methodology for water pumping efficiency improvements --- Version 2.0"
}'
```

**Example Response:**
```json
{
  "message": "Project update added to staging",
  "success": true
}
```

### DELETE `/v1/projects`

**Description:** Delete a project record

**Request Body Fields:**

| Field | Type | Required | Description | Validation |
|-------|------|----------|-------------|------------|
| warehouseProjectId | String | **Required** | Unique warehouse project identifier | Valid UUID format |

**Example Request:**
```sh
curl --location -g --request DELETE 'http://localhost:31310/v1/projects' \
--header 'Content-Type: application/json' \
--data-raw '{
    "warehouseProjectId": "693d37f6-318e-4d8b-9e14-3d2328b569be"
}'
```

**Example Response:**
```json
{
  "message": "Project deletion staged successfully",
  "success": true
}
```

---

## `units`

Functionality: List, create, and update unit records

### POST `/v1/units`

**Description:** Stage a new unit record

**Request Body Fields:**

#### Required Fields
| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| countryJurisdictionOfOwner | String | **Required** | Owner's country jurisdiction | Must be from [countries picklist](#countries-picklist) |
| unitCount | Integer | **Required** | Number of units | 1-999999999 |
| vintageYear | Integer | **Required** | Vintage year | 1900-3000 |
| unitType | String | **Required** | Type of unit | Must be from [unit type picklist](#unit-type-picklist) |
| unitStatus | String | **Required** | Current unit status | Must be from [unit status picklist](#unit-status-picklist) |
| unitRegistryLink | String | **Required** | Registry URL | Valid URL format |
| correspondingAdjustmentDeclaration | String | **Required** | CA declaration | Must be from [CA declaration picklist](#ca-declaration-picklist) |
| correspondingAdjustmentStatus | String | **Required** | CA status | Must be from [CA status picklist](#ca-status-picklist) |

#### Optional Fields
| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| projectLocationId | String | Project location identifier | None |
| unitOwner | String | Unit owner name | None |
| inCountryJurisdictionOfOwner | String | In-country jurisdiction | None |
| unitBlockStart | String | Start of unit block | None |
| unitBlockEnd | String | End of unit block | None |
| marketplace | String | Marketplace name | None |
| marketplaceLink | String | Marketplace URL | Valid URL format |
| marketplaceIdentifier | String | Marketplace identifier | None |
| unitTags | String | Comma-separated tags | None |
| unitStatusReason | String | Reason for status | Required if unitStatus is 'cancelled' or 'retired' |

#### Child Records (Optional)
| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| issuance | Object | Issuance record | See [issuance schema](#issuance-schema) |
| labels | Array | Label records | See [label schema](#label-schema) |

**Example Request (Minimum Required Fields):**
```sh
curl --location -g --request POST 'localhost:31310/v1/units' \
     --header 'Content-Type: application/json' \
     --data-raw '{
       "projectLocationId": "ID_USA",
       "unitOwner": "Chia",
       "countryJurisdictionOfOwner": "Andorra",
       "vintageYear": 1998,
       "unitType": "Removal - technical",
       "unitStatus": "Held",
       "unitBlockStart": "abc123",
       "unitBlockEnd": "bcd456",
       "unitCount": 200,
       "unitRegistryLink": "http://climateWarehouse.com/myRegistry",
       "correspondingAdjustmentDeclaration": "Unknown",
       "correspondingAdjustmentStatus": "Not Started"
}'
```

**Example Response:**
```json
{
  "message": "Unit staged successfully",
  "uuid": "9a29f826-ea60-489f-a290-c734e8fd57f1",
  "success": true
}
```

### PUT `/v1/units`

**Description:** Update an existing unit record

**Request Body Fields:**

#### Required Fields
| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| warehouseUnitId | String | **Required** | Unique warehouse unit identifier | Valid UUID format |
| countryJurisdictionOfOwner | String | **Required** | Owner's country jurisdiction | Must be from [countries picklist](#countries-picklist) |
| unitCount | Integer | **Required** | Number of units | 1-999999999 |
| vintageYear | Integer | **Required** | Vintage year | 1900-3000 |
| unitType | String | **Required** | Type of unit | Must be from [unit type picklist](#unit-type-picklist) |
| unitStatus | String | **Required** | Current unit status | Must be from [unit status picklist](#unit-status-picklist) |
| unitRegistryLink | String | **Required** | Registry URL | Valid URL format |
| correspondingAdjustmentDeclaration | String | **Required** | CA declaration | Must be from [CA declaration picklist](#ca-declaration-picklist) |
| correspondingAdjustmentStatus | String | **Required** | CA status | Must be from [CA status picklist](#ca-status-picklist) |

**Example Request:**
```sh
curl --location -g --request PUT 'localhost:31310/v1/units' \
--header 'Content-Type: application/json' \
--data-raw '{
    "warehouseUnitId": "9a5def49-7af6-428a-9958-a1e88d74bf58",
    "projectLocationId": "Brand New Location",
    "unitOwner": "New Owner",
    "countryJurisdictionOfOwner": "Vanuatu",
    "serialNumberBlock": "QWERTY9800-ASDFGH9850",
    "serialNumberPattern": "[.*\\D]+([0-9]+)+[-][.*\\D]+([0-9]+)$",
    "vintageYear": 2002,
    "unitType": "Removal - technical",
    "unitStatus": "For Sale",
    "unitRegistryLink": "http://climateWarehouse.com/myRegistry",
    "correspondingAdjustmentDeclaration": "Unknown",
    "correspondingAdjustmentStatus": "Not Started"
}'
```

**Example Response:**
```json
{
  "message": "Unit update added to staging",
  "success": true
}
```

### DELETE `/v1/units`

**Description:** Delete a unit record

**Request Body Fields:**

| Field | Type | Required | Description | Validation |
|-------|------|----------|-------------|------------|
| warehouseUnitId | String | **Required** | Unique warehouse unit identifier | Valid UUID format |

**Example Request:**
```sh
curl --location -g --request DELETE 'localhost:31310/v1/units' \
     --header 'Content-Type: application/json' \
     --data-raw '{
       "warehouseUnitId": "104b082c-b112-4c39-9249-a52c6c53282b"
      }'
```

**Example Response:**
```json
{
  "message": "Unit deletion staged successfully",
  "success": true
}
```

---

## Field Reference

## Project Fields

### Required Fields

| Field | Type | Description | Validation | Example | Picklist Source |
|-------|------|-------------|------------|---------|-----------------|
| projectId | string/number | Unique project identifier | None | "PROJ-001" | None |
| originProjectId | string/number | Original project ID from source registry | None | "12345-123-123-12345" | None |
| registryOfOrigin | string | Source registry name | Must be from picklist | "UNFCCC" | `/v1/governance/meta/pickList` |
| projectName | string | Project name | None | "Stop Desertification" | None |
| projectLink | string | URL to project information | Valid URL format | "http://testurl.com" | None |
| projectDeveloper | string | Name of project developer | None | "Example Developer" | None |
| sector | string | Project sector | Must be from picklist | "Agriculture; forestry and fishing" | `/v1/governance/meta/pickList` |
| projectType | string | Type of project | Must be from picklist | "Agriculture, Forestry and other land use (AFOLU)" | `/v1/governance/meta/pickList` |
| coveredByNDC | string | NDC coverage status | Must be from picklist | "Outside NDC" | `/v1/governance/meta/pickList` |
| projectStatus | string | Current project status | Must be from picklist | "Registered" | `/v1/governance/meta/pickList` |
| projectStatusDate | string | Project status date | ISO 8601 date format | "2022-03-12T00:00:00.000Z" | None |
| unitMetric | string | Unit of measurement | Must be from picklist | "tCO2e" | `/v1/governance/meta/pickList` |
| methodology | string | Project methodology | Must be from picklist | "ACR - Afforestation and Reforestation of Degraded Lands" | `/v1/governance/meta/pickList` |

### Optional Fields

| Field | Type | Description | Validation | Example | Picklist Source |
|-------|------|-------------|------------|---------|-----------------|
| program | string | Program name | None | "VCS Program" | None |
| projectTags | string | Comma-separated tags | None | "Forestry, Carbon" | None |
| ndcInformation | string | NDC-specific information | None | "NDC Target 2030" | None |
| validationBody | string | Validation organization | Must be from picklist | "SCS Global Services" | `/v1/governance/meta/pickList` |
| validationDate | string | Validation date | ISO 8601 date format | "2024-01-15T00:00:00.000Z" | None |
| methodology2 | string | Secondary methodology | None | "Additional methodology details" | None |
| description | string | Project description | None | "Comprehensive project description" | None |

## Unit Fields

### Required Fields

| Field | Type | Description | Validation | Example | Picklist Source |
|-------|------|-------------|------------|---------|-----------------|
| countryJurisdictionOfOwner | string | Owner's country jurisdiction | Must be from picklist | "United States of America" | `/v1/governance/meta/pickList` |
| unitCount | integer | Number of units | 1-999999999 | 100 | None |
| vintageYear | integer | Vintage year | 1900-3000 | 2024 | None |
| unitType | string | Type of unit | Must be from picklist | "Removal - nature" | `/v1/governance/meta/pickList` |
| unitStatus | string | Current unit status | Must be from picklist | "Held" | `/v1/governance/meta/pickList` |
| unitRegistryLink | string | Registry URL | Valid URL format | "https://registry.example.com/unit/123" | None |
| correspondingAdjustmentDeclaration | string | CA declaration | Must be from picklist | "Unknown" | `/v1/governance/meta/pickList` |
| correspondingAdjustmentStatus | string | CA status | Must be from picklist | "Not Started" | `/v1/governance/meta/pickList` |

### Optional Fields

| Field | Type | Description | Validation | Example | Picklist Source |
|-------|------|-------------|------------|---------|-----------------|
| projectLocationId | string | Project location identifier | None | "ID_USA" | None |
| unitOwner | string | Unit owner name | None | "Carbon Corp" | None |
| inCountryJurisdictionOfOwner | string | In-country jurisdiction | None | "California" | None |
| unitBlockStart | string | Start of unit block | None | "ABC001" | None |
| unitBlockEnd | string | End of unit block | None | "ABC100" | None |
| marketplace | string | Marketplace name | None | "Carbon Trade Exchange" | None |
| marketplaceLink | string | Marketplace URL | Valid URL format | "https://marketplace.example.com" | None |
| marketplaceIdentifier | string | Marketplace identifier | None | "CTX-12345" | None |
| unitTags | string | Comma-separated tags | None | "Renewable energy, Energy efficiency" | None |
| unitStatusReason | string | Reason for status | Required if status is 'cancelled' or 'retired' | "Retirement for Person or Organization" | None |

## Organization Fields

### Required Fields

| Field | Type | Description | Validation | Example | Picklist Source |
|-------|------|-------------|------------|---------|-----------------|
| name | string | Organization name | None | "Sample Organization" | None |
| icon | string | Organization icon URL | Valid URL format | "https://example.com/icon.svg" | None |

### Optional Fields

| Field | Type | Description | Validation | Example | Picklist Source |
|-------|------|-------------|------------|---------|-----------------|
| orgUid | string | Organization UID | Valid UUID format | "d84ab5fa679726e988b31ecc8ecff0ba8d001e9d65f1529d794fa39d32a5455e" | None |
| isHome | boolean | Home organization flag | true/false | true | None |

## Field Validation Rules

### Date Format
All date fields must use ISO 8601 format: `YYYY-MM-DDTHH:mm:ss.sssZ`

### URL Format
URL fields must be valid HTTP/HTTPS URLs

### Integer Ranges
- `unitCount`: 1 to 999,999,999
- `vintageYear`: 1900 to 3000

### Conditional Requirements
- `unitStatusReason`: Required when `unitStatus` is 'cancelled' or 'retired'

### Picklist Validation
Fields marked with "Must be from picklist" validate against values from the `/v1/governance/meta/pickList` endpoint. Invalid values will return a 422 error with the list of valid options.

## Available Picklists

### Registries
- American Carbon Registry (ACR)
- Article 6.4 Mechanism Registry
- Biocarbon Registry S.A.S
- Carbon Assets Trading System (CATS)
- Climate Action Reserve (CAR)
- Gold Standard
- Verra
- [Full list available via `/v1/governance/meta/pickList`]

### Sectors
- Accommodation and food service activities
- Activities of extraterritorial organizations and bodies
- Agriculture; forestry and fishing
- [Full list available via `/v1/governance/meta/pickList`]

### Project Types
- Afforestation
- Avoided Conversion
- Agriculture, Forestry and other land use (AFOLU)
- [Full list available via `/v1/governance/meta/pickList`]

### Unit Types
- Avoidance
- Reduction - nature
- Reduction - technical
- Removal - nature
- Removal - technical
- Not Determined

### Unit Statuses
- Held
- Retired
- Cancelled
- Expired
- Inactive
- Buffer
- Exported
- Rejected
- Pending Export

### Countries
- Afghanistan
- Albania
- Algeria
- [Full list available via `/v1/governance/meta/pickList`]

## Error Handling

### Common Error Responses

#### 400 Bad Request
```json
{
  "success": false,
  "message": "Validation failed",
  "details": {
    "projectId": "Project ID is required",
    "sector": "Invalid sector value. Must be from picklist."
  }
}
```

#### 422 Unprocessable Entity
```json
{
  "success": false,
  "message": "Invalid picklist value",
  "errors": [
    {
      "field": "unitType",
      "value": "Invalid Type",
      "validValues": ["Avoidance", "Reduction - nature", "Reduction - technical", "Removal - nature", "Removal - technical", "Not Determined"]
    }
  ]
}
```

#### 500 Internal Server Error
```json
{
  "success": false,
  "message": "Your wallet is not available",
  "details": "Please ensure Chia wallet is synced before making API calls"
}
```

---

## Implementation Notes

### Visual Indicators Used
- **Bold text** for required fields
- Clear "Required" vs "Optional" column headers
- Validation rules clearly specified
- Picklist sources explicitly referenced

### Benefits of This Approach
1. **Clear Requirements**: Developers can immediately see what's required vs optional
2. **Validation Guidance**: Clear indication of which fields use picklists
3. **Error Prevention**: Detailed validation rules reduce failed API calls
4. **Reference Material**: Comprehensive field tables serve as quick reference
5. **Maintainability**: Structured format makes updates easier

This enhanced documentation structure provides the foundation for:
- Phase 1, Item 3: Add validation error examples
- Phase 1, Item 4: Update test data files to match actual requirements
- Phase 2: Create picklist reference section
- Phase 3: Add interactive API documentation

The enhanced structure transforms the current cookbook-style documentation into a comprehensive API reference that serves both novice and experienced developers effectively.
