# Agent Instructions: Stakeholder Cohort Documents

Use these instructions whenever the user asks for a cohort definition document, stakeholder document, or summary of cohort logic.

---

## QC Workflow

To run a QC review on a study, follow the instructions in `AgentQC.md`.

---

## Overview: Two-Step Pipeline

1. **Step 1 — Run the R script** to generate print-friendly `.Rmd` files from the JSON cohort definitions into `AI_translation/printFriendly/`.
2. **Step 2 — You (the agent) read those files** and write a stakeholder `.Rmd` draft into `AI_translation/drafts/` and the final `.docx` into `AI_translation/output/`.

---

## Step 1: Generate Print-Friendly Files

Run this from the repo root. The script defaults to the Ulysses standard path `inputs/cohorts` — pass a different path if the repo uses a different structure:

```bash
Rscript makePrintFriendlyFile.R                        # uses inputs/cohorts by default
Rscript makePrintFriendlyFile.R path/to/cohorts        # override if needed
```

This creates `AI_translation/printFriendly/` if it does not exist, and writes one file per cohort:
```
AI_translation/printFriendly/<cohort_basename> - cohort_print_friendly.Rmd
```

**Dependency:** R package `CirceR` — install with `remotes::install_github('ohdsi/CirceR')` if missing.

Do not proceed to Step 2 until Step 1 completes without errors.

---

## Step 2: Generate Stakeholder Word Documents

For each `.Rmd` file in `AI_translation/printFriendly/`:

1. Read the `.Rmd` file.
2. Also read the corresponding `.json` file from `inputs/cohorts/json/` (same basename) to extract concept sets. JSON files may be nested inside category subfolders (e.g. `inputs/cohorts/json/target/`) — search recursively. Standalone concept set JSONs live in `inputs/conceptSets/json/`.
3. Use the content and the Document Quality Rules below to write a stakeholder `.Rmd`. The file **must begin with a YAML header** using the derived human-readable title (see Cohort Title Naming below):

```yaml
---
title: "<Disease/Condition> Cohort Definition"
date: "`r format(Sys.Date(), '%B %d, %Y')`"
output:
  word_document:
    toc: true
    number_sections: false
---
```

4. Determine the category subfolder from the print-friendly file's location (e.g. `AI_translation/printFriendly/target/` → category is `target`). Create mirrored subfolders for drafts and output:

```bash
mkdir -p AI_translation/drafts/<category> AI_translation/output/<category>
```

5. Write the stakeholder `.Rmd` to `AI_translation/drafts/<category>/<Disease Condition> Cohort Definition.Rmd`.
6. Render it to `.docx` in the mirrored output subfolder:

```bash
Rscript -e "rmarkdown::render('AI_translation/drafts/<category>/<Disease Condition> Cohort Definition.Rmd', output_file='AI_translation/output/<category>/<Disease Condition> Cohort Definition.docx')"
```

If there is no category subfolder (files sit directly in `AI_translation/printFriendly/`), write directly into `AI_translation/drafts/` and `AI_translation/output/`.

Report the full output path for every file written.

---

## Document Quality Rules

### Required Section Order

Use `##` headings. No numeric prefixes in headings:

- `Executive Summary`
- `Cohort Definition Overview`
- `Cohort Entry Index Event Timing Requirements`
- `Selection Rule`
- `Inclusion Criteria` (only if present in source)
- `Exclusion Criteria` (only if explicit exclusion logic exists — omit entirely if not)
- `Cohort Exit` (only if present in source)
- `Cohort Era` (only if present in source)
- `Key Concept Sets Used in This JSON File`

### Readability

- Audience is business and clinical stakeholders, not data engineers.
- Use plain language and short sentences.
- Use `-` bullets and small tables — avoid long paragraphs.
- Add a short preface to each section explaining what it means in practice.

### No Ordered Lists (Word-friendly)

- Never use ordered lists (`1.`, `2.`, `1)`, etc.) anywhere in the document.
- Never use numeric prefixes in headings.
- Convert any numbered subrules from the source into `-` bullets with plain-language descriptions.

### Executive Summary

4–6 bullets covering:
- who is included
- key exclusion logic (or note if none)
- index event definition
- follow-up start/end
- one-line interpretation of strictness (narrow vs broad)

### Logic Integrity

- Do not invent criteria not present in the source.
- If exclusion logic is embedded inside inclusion logic, call it out explicitly under `Exclusion Criteria`.
- If a section has no content in the source, write `Not found in source definition.`

### Index Event Clarity

State the exact occurrence threshold from the source:
- `at least 1` → "one qualifying claim/diagnosis"
- `at least 2` → "two or more qualifying claims/diagnoses"

Do not paraphrase away the count.

### Preserve Source Semantics for Subrules

For any numbered subrules (e.g. `0.2`) reproduce exactly:
- claim/event count thresholds
- time windows (e.g. 1 day to 365 days)
- concept names (do not substitute generic categories)

### Concept Set Table

Under `Key Concept Sets Used in This JSON File`, include a two-column table:

| Concept Set Name | Concept Names Used |
|---|---|

- Parse concept sets from the `.json` file.
- Prioritize sets referenced in `Cohort Entry Events` and `Inclusion Criteria`.
- Prefer disease/exposure sets over generic support sets.
- **Do not list all concepts.** Read all concept names and use judgment to select 5–8 that best represent what the set captures — favour meaningfully different types (e.g. one procedure, one diagnosis, one status code) over many near-identical variants.
- Always end with `(+N more)` showing how many additional concepts exist in the full set.

### Cohort Title Naming

- Do not include numeric IDs (e.g. `1779`, `3817`) in the title or filename.
- Derive a human-readable title from the print-friendly text: `"<Disease/Condition> Cohort Definition"`.
- Use the same derived title for both the YAML `title:` field and the output `.docx` filename.
- Example: `Lung Transplant Cohort Definition.docx`, `Pulmonary Fibrosis Cohort Definition.docx`.

---

## Folder Layout

```
<repo_root>/                       ← any Ulysses-structured repo
├── inputs/                        ← Ulysses-managed, do not modify
│   └── cohorts/
│       └── json/
│           ├── target/            ← input JSON files by category
│           ├── comparator/
│           └── outcome/
├── AI_translation/                ← agent-generated outputs, mirrors json/ structure
│   ├── printFriendly/
│   │   ├── target/
│   │   ├── comparator/
│   │   └── outcome/
│   ├── drafts/
│   │   ├── target/
│   │   ├── comparator/
│   │   └── outcome/
│   └── output/
│       ├── target/
│       ├── comparator/
│       └── outcome/
├── makePrintFriendlyFile.R        ← Step 1 script (run this)
└── AGENTS.md                      ← this file
```
