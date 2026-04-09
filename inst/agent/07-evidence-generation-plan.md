# Evidence Generation Plan

## Introduction

An *Evidence Generation Plan* (EGP) is a **required document** in the Picard pipeline. It is a structured specification document that bridges your research questions to your analysis code. The EGP defines the analytical experiment in layman's terms and **drives the pipeline**—your code implements the specifications you document here.

It serves three critical purposes:

1. **Precision:** Translates research questions into exact analytical specifications (numerators, denominators, observation windows, inclusion/exclusion logic)
2. **Transparency:** Makes all choices explicit and justified, enabling others to understand and validate your approach  
3. **Implementation:** Provides sufficient detail that programmers can implement your vision without ambiguity

**Key insight:** EGPs are NOT one-size-fits-all templates. They adapt fundamentally based on study design:

- **Surveillance studies** (prevalence, incidence) emphasize observation periods, lookback windows, numerator/denominator specifications
- **Characterization studies** describe patient populations, baseline features, treatment patterns, temporal trends
- **Outcome studies** focus on exposure definitions, time-at-risk, outcome specifications
- **Treatment pathway studies** detail era logic, gap collapsing rules, sequence analysis

This document teaches the principles of EGP construction and shows examples from different study types. You'll adapt the structure to match your research questions.

## EGP as a Bridge Between Planning and Code

An EGP sits between your research vision and your Picard implementation:

```
Research Questions
       ↓
Evidence Generation Plan
(translate to specifications)
       ↓
Picard Code Implementation
(analysis/tasks/ implement specs)
       ↓
Results & Dissemination
```

Each element of your EGP should have a corresponding task in your analysis pipeline. The EGP drives the code—every analytical decision in the code should trace back to a specification in your EGP.

## Universal EGP Components

While structure varies by study type, most EGPs contain these sections:

- Background (Rationale, Research Questions, Data Sources)
- Cohort Definitions (structured by study design)
- Analysis Specifications (baseline characteristics, prevalence calculations, treatment pathways, etc.)

Below are details on how to adapt these components based on your study design.

### 1. Background

Establish context for your study.

**Always include:**
- **Rationale:** Why does this study matter?
- **Research Questions:** What specific questions will you answer?
- **Data Sources:** Where does your data come from? Why that source?

**Example - Prevalence Study:**
```
### Research Questions
1. What is the annual crude and standardized prevalence of Type 2 Diabetes from 2015-2024?
2. How do prevalence estimates vary by age and sex?
3. What proportion of Type 2 Diabetes patients receive guideline-recommended medications?
```

**Example - Characterization Study:**
```
### Research Questions
1. What are the demographics and baseline characteristics of patients newly diagnosed with Psoriasis?
2. What procedures, measurements and symptoms occur among Psoriasis patients in the year after diagnosis?
3. What are the most common treatments and treatment sequences among Psoriasis patients?
```

### 2. Cohort Definitions

Define your study populations and other important cohorts precisely. The cohort definitions will have three main components:

- **Entry criteria:** How do patients enter the cohort?
- **Inclusion criteria:** What additional criteria must be met to stay in the cohort?
- **Exit criteria:** How do patients exit from the cohort (i.e censored by death or end of continuous observation)

**Psoriasis Example:**
```
### Newly-Diagnosed Psoriasis Cohort

#### Cohort Entry
- First visit date with Psoriasis diagnosis code
- Requirement: >= 2 Psoriasis diagnosis visits on different dates, 30-365 days apart
- Requirement: 365 days continuous prior observation
- Limit occurrence to the initial event per patient (first-ever diagnosis)

#### Inclusion Criteria
- NO prior psoriasis-related treatments in 365 days prior to index

#### Cohort Exit
- End of continuous observation, OR
- Death
```

**Type 2 Diabetes Example:**
```
### Type 2 Diabetes Cohort

#### Cohort Entry
- 2 codes of Type 2 Diabetes on different dates, at least 30 days apart
- The second code is the index date
- Limit occurrence to the initial event per patient (first-ever diagnosis)

#### Inclusion Criteria
- NO occurrence of Type 1 Diabetes diagnosis code at any time prior to index date
- NO occurrence of Gestational Diabetes diagnosis code at any time prior to index date

#### Cohort Exit
- End of continuous observation, OR
- Death
```

**Guiding principles:**

- The index date should be clearly defined. Typically the index date in a sequence of events is the second occurrence (to avoid immortal time bias).
- The index date should be the occurrence of a clinical event (diagnosis, procedure, medication dispensing) rather than an arbitrary date (calendar date, visit).
- Always provide temporal logic on sequence of events. For example if no prior treatment state either all time or some window relative to the index date
- Be explicit about whether you limit to first-ever occurrence or allow multiple occurrences per patient 
- Clearly define exit criteria (death, end of observation) to ensure proper censoring in follow-up analyses

### 3. Analysis Specifications

This section varies greatly by study type. The key principle: **Be specific enough that a programmer can implement without guessing.**

**Prevalence Example:**
```
### Prevalence Calculation: Any-Time Point Estimate

**Period of Interest:** Each calendar year 2015-2024

**Observation Requirements:**
- Include: Anyone with >= 1 day enrollment in the year
- Minimum continuous: None (any fragmented enrollment allowed)

**Lookback:**
- Search 365 days prior to period for any Type 2 Diabetes diagnosis

**Numerator:**
- Patients with Type 2 Diabetes diagnosis code prior to OR during period

**Denominator:**
- All patients with any enrollment during period of interest

**Calculation:**
Prevalence = (Numerator / Denominator) per 100,000
```

**Characterization Example:**
```
### Baseline Characteristics

**Baseline Window:** 365 days prior to index date through 1 day prior

**Demographics Reported:**
- Age at index date
- Sex, Race, Ethnicity
- Payer type
- Calendar year of index

**Comorbidities:**
- Report any diagnosis code during baseline window for:
  - Autoimmune/Inflammatory conditions (Rheumatoid arthritis, Crohn's disease, etc.)
  - Cardiovascular disease
  - Metabolic disease (Diabetes, Obesity)
  - [Organized by clinical system]

**Treatments:**
- Any dispensing during baseline window for:
  - Topical agents
  - Systemic agents
  - Biologic agents
  - Other (phototherapy, oral steroids)

### Treatment Pathways During Follow-up

**Gap Collapsing Rules:**
- Topical agents: Collapse gaps of <30 days
- Systemic agents: Collapse gaps of <30-60 days depending on agent
- Biologic agents: Collapse gaps of <60-120 days depending on specific drug

**Combination Logic:**
- Different drug classes overlapping >= 60 days = counted as combination therapy

**Episode Minimum:**
- Episodes of <14 days are excluded (too short to assess effectiveness)

**Output:**
- Table: Median days on treatment by therapy class and line number
```

## Linking EGP to Picard Implementation

Each major section of your EGP should correspond to at least one analysis task:

```
EGP Section               →  Ulysses Structure
─────────────────────────────────────────
Cohort Definitions       →  inputs/cohorts/
Baseline Characteristics →  analysis/tasks/01_descriptiveStats.R
Prevalence/Surveillance  →  analysis/tasks/02_prevalenceAnalysis.R
Post-Index Follow-up     →  analysis/tasks/03_followupCharacterization.R
Treatment Pathways       →  analysis/tasks/04_treatmentPathways.R
```

It may be helpful to include this mapping as an appendix to your EGP to ensure that all specifications are implemented in code and to facilitate traceability between the document and the implementation.

## Versioning Your EGP

Keep a changelog as your study evolves. This should be placed at the end of the file. Here is an example:

```
## Version 1.1 (2026-04-15)

### Changes from v1.0
- Extended follow-up from 3 to 5 years (additional funding)
- Added secondary outcome: CKD progression
- Expanded age subgroups from 3 to 5 categories

### Rationale
Stakeholder feedback requested longer follow-up for stability; 
clinical team identified CKD progression as important secondary endpoint.
```

## Example: Complete Minimal EGP

For a quick reference, here's a minimal EGP template:

```markdown
# Evidence Generation Plan: [Study Name]

## Background

### Rationale
[1-2 sentences: Why does this study matter?]

### Research Questions
1. [First question]
2. [Second question]

### Data Sources
[Database name], [coverage period], [size], [type of data]

## Cohort Definitions

### Base Population
- Entry criteria: [How patients enter]
- Inclusion: [Who stays in]
- Exclusion: [Who gets excluded]

## Analysis Specifications

### Primary Analysis
[What is measured, how, when]

### Secondary/Subgroup Analyses
[Additional analyses]

## Version History

### Version 1.0 (YYYY-MM-DD)
- Initial protocol
```

---

# Example EGPs

Use the following examples as references to help users create an EGP. 

## 1. Type 2 Diabetes Prevalence Analysis Example

### Background {#sec-background}

#### Rationale {#sec-rationale}

The purpose of this study is to estimate the prevalence of Type 2 Diabetes in the US population using a closed-claims database. The results of this study will be used to inform HCPs on the burden of Type 2 Diabetes disease. 

#### Research Questions {#sec-questions}

- What is the crude and standardized prevalence of Type 2 Diabetes per year?
- What is the estimated use of pre-specified Type 2 Diabetes-relevant medications per calendar year? 

#### Data Sources {#sec-data}

**Optum Clinformatics DOD**

-   Data availability: 01/01/2007 - 09/30/2024
-   Lives covered: 84 million
-   Geography: United States
-   Data source: Commercial and Medicare Advantage claims data
-   Reason(s) chosen: The large sample size and broad geographical coverage help to ensure good representativeness of the US population, including Medicare-eligible patients
-   Limitations: Typical limitations of retrospective administrative claims datasets. Extrapolation beyond the commercially insured population to Medicare, Medicaid, or uninsured patients still may not be representative

Note that the DOD version of clinformatics contains death data from US Social Security Death Master File. This improves the reliability of death dates in the database.

### Cohort Definitions {#sec-cohorts}

The cohort definitions in this analysis are designed in ATLAS for the OMOP CDM. The OMOP CDM uses standardized vocabularies to identify clinical concepts of interest uniformly across databases. For more details on the OMOP Vocabulary review [here](https://ohdsi.github.io/TheBookOfOhdsi/StandardizedVocabularies.html). In this section we present a summary of the definition and then a print object of the definition designed in ATLAS. 

#### Type 2 Diabetes

Type 2 Diabetes is a chronic metabolic disorder characterized by insulin resistance and relative insulin deficiency, leading to hyperglycemia and multiple systemic complications. Type 2 Diabetes is associated with increased risk of cardiovascular disease, renal disease, and microvascular complications, with classification into clinical stages based on glycemic control and complication status.

**Likely**
- 2 diagnosis codes of T2D 30 days apart

**Treated**
- at least one prescription of guideline treatments for Type 2 Diabetes; given the person is likely

### Analysis {#sec-analysis}

#### Surveillance {#sec-surveillance}

In this section of the analysis we calculate prevalence and incidence of the target cohort(s) of interest specified in @sec-cohorts. For each surveillance measure we contextualize the population by calendar year since we are interested in the temporal trend. Prevalence will be reported in 100K persons and incidence will be reported in 100K person years. We follow the methodology of Rassen et al 2018 to calculate incidence and prevalence of chronic conditions in longitudinal observational databases [@Rassen2018]. Type 2 Diabetes surveillance provides insights into disease burden and treatment patterns over time. 

**Key Terms:**

- **Observation Period:** The span of time during which a person is considered actively engaged with the healthcare system and their medical activity is observable in the database. In claims, this is proxied by enrollment logic. In EHR data, it is typically defined as either: all observable time after birth or first observed event to last available date (common ETL assumption).

- **Period of Interest:** The specific time for which prevalence is anchored for its enumeration. This is often one year but can span multiple years.

- **Lookback time:** A defined span of time prior to the period of interest during which the database is queried for existing evidence of disease. In longitudinal observational databases, we are unable to dip into the data at a single point in time to determine whether a chronic condition is present. Instead, we define a period where we surveil for existing disease. If the chronic disease occurs during the lookback time, then it is considered to have prevalent disease.

- **Prevalence Pool:** The denominator population is the source of which prevalent cases (numerator) are drawn. Conversely, if a patient cannot contribute to the numerator, it is excluded from the denominator.

##### Prevalence {#sec-prevalence}

We define prevalence as the proportion of the population with the condition at a specific point in time. Via this definition we first count the number of persons who actively have the condition at a specific time point and divide by the number of persons who are active in the database during that same period of time. The prevalence is reported in 100K persons. In this study we provide two versions of the prevalence calculation:

###### Analysis 1: Any-Time Point Prevalence 365d Lookback

- **Period of Interest**: Yearly intervals from 2007 to 2025
- **Observation Period Requirements**: 
    - Use all observation periods in the analysis
    - Observation period must be 1 day or longer to be included in the analysis
- **Lookback period**: 
    - Lookback to 365 days prior to the period of interest
    - Events can occur at any time and are not limited to the observation period bound by calendar dates
- **Point Prevalence**
    - **Numerator**: The presence of the condition at any point prior and during the period of interest (PN2)
    - **Denominator**: All persons in the database who fulfill the observation period criteria with at least 1 day of observation during the period of interest (PD3)
- **Notes**: Typically this is a conservative estimate of the prevalence because it utilizes the largest prevalence pool as its denominator

###### Analysis 2: Complete Period Prevalence 365d Lookback

- **Period of Interest**: Yearly intervals from 2007 to 2025
- **Observation Period Requirements**: 
    - Use all observation periods in the analysis
    - Observation period must be 1 day or longer to be included in the analysis
- **Lookback period**: 
    - Lookback to 365 days prior to the period of interest
    - Events can occur at any time and are not limited to the observation period bound by calendar dates
- **Point Prevalence**
    - **Numerator**: The presence of the condition at any point prior and during the period of interest (PN2)
    - **Denominator**: The number of persons in the population who contribute all observable person-days in the period of interest (PD2)
- **Notes**: Typically this is the most aggressive estimate of the prevalence because it utilizes the smallest prevalence pool as its denominator since we limit our population to only those that have been observed over the course of the entire period of interest

##### Standardization Surveillance Statistics

We standardize the surveillance metrics using direct method estimation (i.e., age-sex standardization), a weighted sum of the incidence and prevalence by population weights provided by the US Census. We peg the weights to the 2020 US Census weights. 

#### Post-Index Characterization

##### Drug Calendar Counts {#sec-drugCal}

We characterize drug utilization over calendar periods. To do this we use the prevalence pool specified in @sec-prevalence to identify the prevalent cases of Type 2 Diabetes per calendar year. Then we count the number of drug occurrences in the calendar year to enumerate prevalent usage. The denominator is the number of prevalent cases of Type 2 Diabetes in the calendar year. 

**Medications of Interest:**

**Common T2D Medications**
- meformin
- insulin

**GLP1 Receptor Agonists**
- Semaglutide
- Tirsepatide
- Liraglutide
- Dulaglutide


**SGLT2 Inhibitors**
- Ertuglifozin
- Empaglifozin
- Dapaglifozin
- Canaglifozin

## 2. Psoriasis Incident Cohort Characterization Example

### Background {#sec-background}

#### Rationale {#sec-rationale}

The purpose of this project is to characterize the incident psoriasis population, in support of dermatologic disease characterization.

#### Research Questions {#sec-questions}

- What are the clinical characteristics and demographics of patients newly diagnosed with psoriasis?
- What are the treatment patterns among patients with psoriasis, including patterns of use of standard of care drugs (topical agents, systemic agents, biologic agents)?

#### Data Sources {#sec-data}

**Optum Clinformatics DOD**

* Data availability: 01/01/2007 - 03/31/2025
* Lives covered: 84 million
* Geography: United States
* Data source: Commercial and Medicare Advantage claims data
* Reason(s) chosen: The large sample size and broad geographical coverage help to ensure good representativeness of the US population, including Medicare-eligible patients
* Limitations: Typical limitations of retrospective administrative claims datasets. Extrapolation beyond the commercially insured population to Medicare, Medicaid, or uninsured patients still may not be representative

**Note:** Data sources utilized in this study have been transformed into the [OMOP Common Data Model](https://ohdsi.github.io/CommonDataModel/index.html), and all study codelists are defined using the [OMOP standardized vocabularies](https://academic.oup.com/jamia/article/31/3/583/7510741?login=false).

### Cohort Definitions {#sec-cohorts}

#### Patients with Psoriasis {#sec-cohort-psoriasis}

**The base psoriasis cohort definition is based on clinical guideline-driven cohort construction.**

##### Cohort Entry

Patients enter the cohort on the second of two occurrences of psoriasis. The 2 occurrences must be at least 30 days apart.

The qualifying diagnosis must be the first in the patient's history, occur on or after 1/1/2017, and have at least 365 days of continuous prior observation.

##### Inclusion Criteria

* 365 days continuous observation after the index date
* No claims for psoriasis-relevant treatments in the 365 days prior to the index date

##### Cohort Exit

Patients exit the cohort on the earliest occurrence of:

* End of continuous observation
* Death

### Analysis {#sec-analysis}

#### Characterization {#sec-characterization}

In this analysis, we aim to characterize patients newly diagnosed with psoriasis in the target cohorts as defined above.

##### Baseline Characteristics

We describe demographics; baseline comorbidities; and baseline medication usage. Except where otherwise specified, the baseline window includes the 365 days prior to the index date, through 1 day prior to index.

We report categorical variables by count and percentage and continuous variables by the mean, standard deviation, median, 25th and 75th percentiles.

##### Demographics {#sec-demographics}

We report the following demographics for each cohort:

* Age at the index date
* Sex
* Calendar year of index date
* Race
* Ethnicity
* Payer type

##### Comorbidities {#sec-comorb}

We report the occurrence of the following comorbidities during the baseline period for each cohort, based on the presence of a diagnosis code unless otherwise specified:

**Quality of Life (QoL)**
- Pain in joints
- Fatigue
- Fibromyalgia
- Depression

**Cardiovascular**
- Hypertension
- Diabetes
- Dyslipidemia
- Obesity

**Lifestyle Factors**
- Tobacco use, nicotine use, smoking, and/or vaping


#### Follow-up {#sec-followup}

The following characteristics will be described during the follow-up period: 

* Length of follow-up in days (mean (SD), median (IQR)) 
* Time in cohort in days (mean (SD), median (IQR))
* Reason for end of follow-up
  * Death
  * End of continuous observation
  * End of data availability

##### Therapy Usage {#sec-rx}

We report usage of the following medications/procedures during the follow-up period for each cohort, based on the presence of a drug/procedure code. The follow-up periods of interest are:

- 0 to 90 days post index
- 0 to 365 days post index

The following drugs are summarized at the category and individual treatment levels:

**Topical Agents**
- Topical corticosteroids
- Topical calcineurin inhibitors
- Topical vitamin D analogs
- Topical retinoids
- Combination topical products

**Systemic Agents**
- Methotrexate
- Acitretin
- Cyclosporine
- Sulfasalazine

**Biologic Agents**

*TNF‑α Inhibitors*
- Adalimumab
- Etanercept
- Infliximab
- Certolizumab pegol
- Golimumab

*IL‑17 Inhibitors*
- Secukinumab
- Ixekizumab

*IL‑23 Inhibitors*
- Guselkumab
- Risankizumab
- Tildrakizumab

*Other Biologic Agents*
- Ustekinumab
- Dupilumab

**JAK Inhibitors**
- Ruxolitinib
- Baricitinib

**Concomitant Therapies**

**NSAIDs**
- Celecoxib
- Diclofenac
- Etodolac
- Fenoprofen
- Flurbiprofen
- Ibuprofen
- Indomethacin
- Ketoprofen
- Meloxicam
- Nabumetone
- Naproxen
- Oxaprozin
- Piroxicam
- Sulindac
- Tolmetin

**Opioids**
- Fentanyl
- Hydromorphone
- Oxymorphone
- Methadone
- Morphine
- Oxycodone
- Hydrocodone
- Meperidine
- Codeine
- Tramadol

**Oral or Injectable Corticosteroids**
- Betamethasone
- Dexamethasone
- Hydrocortisone
- Methylprednisolone
- Prednisolone
- Prednisone
- Triamcinolone
