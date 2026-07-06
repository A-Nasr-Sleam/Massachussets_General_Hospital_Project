# Data Catalog: Gold Layer (Massachussets General Hospital)

## 📌 Document Overview

* **Layer:** Gold (Business & Analytics Ready)
* **Domain:** Clinical Operations & Payments
* **Refresh Frequency:** Daily (04:00 AM EEST)
* **Data Steward:** Clinical Data Analytics Team

---

## 🏛️ Dimensional Models Reference

### 🔷 dim_patients

* **Description:** Conformed dimension containing mastered patient demographic profiles.
* **Granularity:** One row per unique patient key (`patient_key`).
* **SCD Type:** Type 1 (New data overwrites existing data. No history of the old data ).

#### Schema Definition: gold.dim_patients

| Column Name | Data Type | Primary/Foreign Key | Allow Nulls? | Description | Example / Allowed Values |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `patient_key` | INT | **PK** | No | Unique  primary key (Surrogate) for the patient dimension in the Gold layer. | `1002948` |
| `birth_date` | DATE | - | Yes | Patient's date of birth. | `1985-06-12` |
| `death_date` | DATE | - | Yes | Patient's date of death (null if the patient is currently alive). | `2024-11-05`, `NULL` |
| `patient_name` | VARCHAR(255) | - | Yes | Full legal name of the patient (prefix First Middle Last). | `Ms. Jane Doe` |
| `suffix` | VARCHAR(10) | - | Yes | Name suffix indicating generation or honors. | `PhD.`, `JD`, `Unknown` |
| `maiden` | BIT | - | Yes | Binary flag indicating if the recorded name is a maiden name. | `1` (True), `0` (False) |
| `marital_status` | CHAR(10) | - | Yes | Marital status category. | `Married`   , `Single`,`unknown` |
| `race` | VARCHAR(50) | - | Yes | Patient's primary racial identity. | `White`, `Black`, `Asian` |
| `ethnicity` | VARCHAR(50) | - | Yes | Patient's ethnic background identity. | `Hispanic`, `Non-Hispanic` |
| `gender` | CHAR(10) | - | Yes | Patient's recorded legal or biological gender. | `Male`, `Female`,`Unknown` |
| `patient_city` | VARCHAR(100) | - | Yes | City of the patient's primary residence. | `Boston`, `Worcester` |
| `patient_state` | VARCHAR(100) | - | Yes | State of the patient's primary address. | `Massachusetts`, `MA` |
| `patient_county` | VARCHAR(100) | - | Yes | Massachusetts county of the patient's primary address. | `Suffolk`, `Middlesex` |

#### Data Lineage & Logic dim_patients

* **Source Table:** `silver.patients`
* **Business Logic:**
  * Numeric serial patient_key instead of the   long textual Id column  in the source.
  * Combined prefix, First name, Middle name, Last name in patient_name column
  * Normalize marital_status, and gender columns.

---

### 🔷 dim_payers

* **Description:** Information regarding health insurance providers, government payers, and self-pay categories.
* **Granularity:** One row per payer organization plan.

#### Schema Definition: gold.dim_payers

| Column Name | Data Type | Primary/Foreign Key | Allow Nulls? | Description | Example / Allowed Values |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `payer_key` | INT | **PK** | No | Unique primary key (Surrogate) identifying the health insurance provider or payer. | `3`,`0` for no payer |
| `payer_name` | VARCHAR(100) | - | Yes | Full legal name of the insurance company or government program. | `Blue Cross Blue Shield (MA)`, `Medicare` |
| `payer_city` | VARCHAR(100) | - | Yes | City where the payer's regional headquarters or processing office is located. | `Boston`, `Worcester` |
| `payer_state` | VARCHAR(50) | - | Yes | State where the payer is registered or operating. | `Massachusetts`, `MA` |

#### Data Lineage & Logic dim_payers

* **Source Tables:** `silver.payers`

---

### 🔷 dim_encounter_date

* **Description:** Standardized role-playing date dimension dedicated to filtering, aggregating, and tracking patient encounter timelines.
* **Granularity:** One row per calendar day.

#### Schema Definition: gold.dim_encounter_date

| Column Name | Data Type | Primary/Foreign Key | Allow Nulls? | Description | Example / Allowed Values |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `date_key` | INT | **PK** | No | Unique surrogate key formatted as YYYYMMDD for efficient joining. | `20260315` |
| `full_date` | DATE | - | No | The standard calendar date for the encounter record. | `2026-03-15` |
| `calendar_year` | INT | - | No | The 4-digit calendar year. | `2026` |
| `calendar_quarter` | INT | - | No | The calendar quarter of the year. | `1`, `2`, `3`, `4` |
| `calendar_month` | INT | - | No | The numerical calendar month of the year. | `1` to `12` |
| `calendar_day` | INT | - | No | The day of the month. | `1` to `31` |
| `day_of_week` | INT | - | No | Numerical day index of the week. | `1` (Sunday) to `7` (Saturday) |
| `day_name` | VARCHAR(10) | - | No | The full textual name of the day of the week. | `Sunday`, `Monday` |
| `is_weekend` | BIT | - | No | Binary flag indicating if the encounter date falls on a weekend. | `1` (True), `0` (False) |
| `fiscal_year` | INT | - | No | The organizational or state-defined fiscal budget year. | `2026` |
| `fiscal_quarter` | INT | - | No | The specific fiscal quarter of the budget tracking cycle. | `1`, `2`, `3`, `4` |
| `fiscal_month` | INT | - | No | The relative month index within the defined fiscal cycle. | `1` to `12` |

#### Data Lineage & Logic dim_encounter_date

* **Source Tables:** Static dimension generated via enterprise calendar configuration scripts with dynamic date range.

---

### 🟥 fact_encounters

* **Description:** Central transactional fact table containing clinical operational metrics, lengths of stay, and core admission details.
* **Granularity:** One row per individual patient encounter instance.

#### Schema Definition

| Column Name | Data Type | Primary/Foreign Key | Allow Nulls? | Description | Example / Allowed Values |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `encounter_key` | INT | **PK** | No | Unique primary key (Surrogate) for each hospital encounter record. | `5001294` |
| `encounter_start` | DATETIME | - | No | The date and timestamp when the hospital encounter began. | `2026-03-15 08:30:00` |
| `encounter_stop` | DATETIME | - | No | The date and timestamp when the hospital encounter ended. | `2026-03-15 11:45:00` |
| `date_key` | INT | **FK** | No | Links to `gold.dim_encounter_date` for advanced date dimensions. | `20260315` |
| `encounter_duration_MIN` | INT | - | No | Total duration of the hospital encounter measured in minutes (Capped based on IQR rules). | `26` |
| `patient_key` | INT | **FK** | No | Links to `gold.dim_patients` to identify the patient. | `1002948` |
| `patient_age_ED` | INT | - | Yes | The age of the patient at the time of the encounter. | `41` |
| `payer_key` | INT | **FK** | No | Links to `gold.dim_payers` to identify the insurance or payer. | `30045` |
| `encounterclass` | VARCHAR(50) | - | Yes | The setting of the medical visit. | `Ambulatory`, `Outpatient`, `Wellness`, `Urgentcare` |
| `encounter_code` | VARCHAR(20) | - | Yes | Standard medical procedure/billing code. | `185345009` |
| `encounter_description` | VARCHAR(255) | - | Yes | Text description matching the encounter code. | `Emergency Encounter` |
| `base_encounter_cost` | DECIMAL(10,2) | - | Yes | The base operational cost of the hospital encounter. | `129.16` |
| `total_claim_cost` | DECIMAL(10,2) | - | Yes | Total cost billed to the insurance/payer for this visit. | `200.00` |
| `payer_coverage` | DECIMAL(10,2) | - | Yes | The total amount covered and paid by the insurance provider. | `160.00` |
| `reason_code` | VARCHAR(20) | - | Yes | Standard diagnosis or clinical reason code for the visit. | `44054006`,`Unknown` |
| `reason_description` | VARCHAR(255) | - | Yes | Text description detailing the reason for the hospital visit. | `Malignant neoplasm of breast (disorder)`,`Unknown` |

#### Data Lineage & Logic fact_encounters

* **Source Table:** `silver.encounters`
* **Business Logic:**
  * Numeric serial encounter_key instead of the   long textual Id column  in the source.
  * encounter_duration_MIN is the difference between encounter_end and encounter_start in minutes.
  * encounter_code and encounter_description have been standardized so every code have one description.

---

### 🔷 dim_procedure_date

* **Description:** Standardized role-playing date dimension dedicated to filtering, aggregating, and tracking procedure timelines.
* **Granularity:** One row per calendar day.

#### Schema Definition: gold.dim_procedure_date

| Column Name | Data Type | Primary/Foreign Key | Allow Nulls? | Description | Example / Allowed Values |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `date_key` | INT | **PK** | No | Unique surrogate key formatted as YYYYMMDD for efficient joining. | `20260315` |
| `full_date` | DATE | - | No | The standard calendar date for the encounter record. | `2026-03-15` |
| `calendar_year` | INT | - | No | The 4-digit calendar year. | `2026` |
| `calendar_quarter` | INT | - | No | The calendar quarter of the year. | `1`, `2`, `3`, `4` |
| `calendar_month` | INT | - | No | The numerical calendar month of the year. | `1` to `12` |
| `calendar_day` | INT | - | No | The day of the month. | `1` to `31` |
| `day_of_week` | INT | - | No | Numerical day index of the week. | `1` (Sunday) to `7` (Saturday) |
| `day_name` | VARCHAR(10) | - | No | The full textual name of the day of the week. | `Sunday`, `Monday` |
| `is_weekend` | BIT | - | No | Binary flag indicating if the encounter date falls on a weekend. | `1` (True), `0` (False) |
| `fiscal_year` | INT | - | No | The organizational or state-defined fiscal budget year. | `2026` |
| `fiscal_quarter` | INT | - | No | The specific fiscal quarter of the budget tracking cycle. | `1`, `2`, `3`, `4` |
| `fiscal_month` | INT | - | No | The relative month index within the defined fiscal cycle. | `1` to `12` |

#### Data Lineage & Logic dim_procedure_date

* **Source Tables:** Static dimension generated via enterprise calendar configuration scripts with dynamic date range.

---

### 🟥 fact_procedures

* **Description:** Transactional fact table tracking all operational medical procedures performed during patient visits.
* **Granularity:** One row per individual procedure execution event.

#### Schema Definition: gold.fact_procedures

| Column Name | Data Type | Primary/Foreign Key | Allow Nulls? | Description | Example / Allowed Values |
| :--- | :--- | :---: | :---: | :--- | :--- |
| `procedure_key` | INT | **PK** | No | Unique primary key (Surrogate) for each recorded medical procedure. | `7001432` |
| `procedure_start` | DATETIME | - | Yes | The date and timestamp when the medical procedure began. | `2026-03-15 09:15:00` |
| `procedure_stop` | DATETIME | - | Yes | The date and timestamp when the medical procedure was completed. | `2026-03-15 10:00:00` |
| `date_key` | INT | **FK** | Yes | Links to `gold.dim_encounter_date` to identify the date of the procedure. | `20260315` |
| `procedure_duration_MIN` | INT | - | Yes | Total elapsed time of the procedure measured in minutes. | `45` |
| `patient_key` | INT | **FK** | No | Links to `gold.dim_patients` to identify the patient receiving the procedure. | `1002948` |
| `patient_age_PD` | INT | - | Yes | The age of the patient at the time this specific procedure was performed. | `41` |
| `encounter_key` | INT | **FK** | No | Links to `gold.fact_encounters` to tie the procedure to a specific hospital visit. | `5001294` |
| `procedure_code` | VARCHAR(20) | - | Yes | Standardized medical procedure code (e.g., CPT, HCPCS, or SNOMED-CT). | `43075005` |
| `procedure_description` | VARCHAR(255) | - | Yes | Human-readable textual description matching the procedure code. | `Incision and drainage of abscess` |
| `base_procedure_cost` | INT | - | Yes | The standard base operational or facility cost for this procedure. | `450` |
| `reason_code` | VARCHAR(20) | - | Yes | Standard diagnosis or clinical reason code justifying the procedure. | `28452007` |
| `reason_description` | VARCHAR(255) | - | Yes | Text description detailing the medical reason why the procedure was performed. | `Laceration of hand` |

#### Data Lineage & Logic fact_procedures

* **Source Tables:** `silver.procedures`

* **Business Logic:**

  * Numeric serial procedure_key instead of the   long textual Id column  in the source.
  * procedure_duration_MIN is the difference between procedure_end and procedure_start in minutes.
  * procedur_code and procedure_description have been standardized so every code have one description.
