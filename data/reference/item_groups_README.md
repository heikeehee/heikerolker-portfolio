# item_groups.csv — Item Classification Reference

Used by: Project 01 (MFA), Project 03 (clustering). Projects 02 and 04 may use different groupings.

## Column definitions

| Column | Description |
|--------|-------------|
| category | Plant or Animal |
| product_type | Broad product class (Food crops, Animal product, etc.) |
| type | Sub-class — THIS is the MFA grouping level (maps to mfa_group) |
| subtype | Further detail |
| item | Specific item name — must match item names in households.rds exactly |
| mfa_group | Integer group number for MFA(groups = ...) call |
| mfa_group_label | Human-readable group label |
| classified | TRUE if item has a non-NA product_type, FALSE if unclassified |

## MFA group numbering

| mfa_group | mfa_group_label | Notes |
|-----------|-----------------|-------|
| 1 | Large ruminants | Cattle meat, offal, milk |
| 2 | Small ruminants | Goats, sheep meat, offal, milk |
| 3 | Poultry | Chickens, ducks, other poultry |
| 4 | Pigs | Pigs meat and offal |
| 5 | Other animals | Rabbits, donkeys, dogs, hare |
| 6 | Eggs | All egg products |
| 7 | Cereals | Maize, paddy, sorghum, millets, wheat, processed cereal products |
| 8 | Pulses | Beans, cowpeas, bambara nuts |
| 9 | Oilcrops | Sunflower, palm oil, sesame, and processed oil products |
| 10 | Roots and tubers | Cassava, sweet potatoes, Irish potatoes, yams, processed root products |
| 11 | Fruits and vegetables | Avocado, banana, mango, onions, tomatoes, etc. |
| 12 | Cashcrops | Coffee, cotton, tobacco, sisal, cocoa, vanilla, tea, sugar cane |
| NA | Unclassified | Items without a type assignment — see below |

## Unclassified items (classified = FALSE)

These items appear in the raw data but have not been assigned to a product_type or MFA group.
Before running MFA, confirm whether these items appear in your households.rds.
If they do appear, assign a group or explicitly exclude them with documentation.
See FLAGS_REVIEW.md for the full list.

## Notes on `classified` vs `mfa_group`

An item may have `classified = TRUE` but `mfa_group = NA`. This occurs when `product_type`
is assigned (e.g. "Processed crop") but `type` is NA. Examples: Groundnut flour, Cashew nut
seed, Groundnut seed. These are partially classified but require a type assignment before they
can be included in MFA. Profile these in 05_exclusions_audit.R.

## Reuse across projects

When using this file in Project 02 or 03, copy to that project's data/reference/ folder
and adjust mfa_group assignments as needed for that project's grouping structure.
Do NOT modify this file for project-specific needs — create a project-specific version.

## Known limitation

~59 items are unclassified (classified = FALSE). These include minor fruits, spices,
and items rarely reported in the Tanzania NPS. Grouping decisions for these items
are backlogged — see backlog.md B06.

## Better structure for future

A long-term improvement would add:
- project_id column to allow one master file across all projects
- inclusion flag per project (included_p01, included_p02, etc.)
- source column (which survey instrument this item appears in)
This would replace project-specific copies with one managed reference file.
Backlogged — see backlog.md B07.
