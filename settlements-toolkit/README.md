# Energy Settlements Reconciliation Toolkit

Working tooling that operationalizes the **Energy Settlements Delivery Workflow**
prompt for physical natural-gas pipeline reconciliation. It implements the
Appendix A worked example — *a pipeline delivery cut creates a settlement break* —
end to end across **VBA (Excel)**, **Alteryx**, and **Power BI**, so the same
control runs wherever the analyst lives.

> **The single fact it turns on:** the pipeline's *final scheduled and allocated*
> delivered quantity is the truth for delivered volume — not the Timely-cycle
> nomination the trading book stored. A cut by itself does not create an imbalance;
> *failing to capture it* creates a settlement break.

## What's here

| Path | Platform | Role in the workflow |
|---|---|---|
| `vba/SettlementReconciliation.bas` | Excel VBA | Stage 4 build + Stage 5 validate: the reconciliation engine |
| `vba/UnitsAndSignControls.bas` | Excel VBA | Principle-1 guards: unit normalization + sign-inversion detector |
| `vba/DocumentTermExtraction.bas` | Excel VBA | Section 4 protocol: contract/confirmation term extraction + lake cross-check |
| `alteryx/SettlementReconciliation.yxmd` | Alteryx | Stage 4 build: repeatable batch reconciliation pipeline |
| `powerbi/measures.dax` + `powerbi/README.md` | Power BI | Stage 3 UX + Stage 6 monitoring: exception queue + drill-through |
| `sample-data/*.csv` | — | Tier-1 extracts (book, pipeline, counterparty, index) |

## The reconciliation logic (identical on all three platforms)

Keyed on `(gas_day, contract, point)`:

```
cut_dth         = sched_timely_dth - sched_final_dth     -- nomination cut
alloc_var_dth   = sched_final_dth  - allocated_dth       -- scheduled vs allocated
total_break_dth = delivered_dth    - allocated_dth        -- book truth-gap
cp_var_dth      = allocated_dth    - confirmed_dth        -- vs counterparty stmt
net_imbalance   = receipt_allocated_dth - allocated_dth   -- receipts vs deliveries
cash_delta_usd  = total_break_dth  * (index_price + basis)
```

Status is `TIE` when book = allocation = counterparty, else `BREAK`, with a
**ranked root cause** (cut vs allocation vs counterparty) and the single
confirming check for each (Operating Principle 6).

## Expected result on the sample data

| Gas Day | Contract | Point | Book | Allocated | Cut | Alloc Var | Total Break | Imbalance | Status |
|---|---|---|---|---|---|---|---|---|---|
| 2025-12-12 | FT-Transco | Y Citygate | 10,000 | 8,150 | 1,800 | 50 | **1,850** | 0 | BREAK: cut not captured |
| 2025-12-13 | FT-Transco | Y Citygate | 10,000 | 10,000 | 0 | 0 | 0 | 0 | TIE |
| 2025-12-14 | FT-Transco | Y Citygate | 7,500 | 7,500 | 0 | 0 | 0 | 100 | TIE delivery / receipt imbalance |
| 2025-12-15 | FT-REX | Z Pool | 20,000 | 19,950 | 0 | 50 | 50 | 50 | BREAK: allocation variance |
| 2025-12-16 | FT-Transco | Y Citygate | 100,000 | 10,000 | — | — | 90,000* | — | REVIEW DATA QUALITY: unit mismatch ~10:1 |
| 2025-12-17 | FT-REX | Z Pool | (20,000) | 20,000 | — | — | (40,000)* | — | REVIEW DATA QUALITY: sign inversion |

\* Not a real economic break — an artifact the guards catch *before* it is settled (see below).

Cash delta on the headline break: 1,850 Dth × (3.42 + 0.15) = **$6,604.50** owed back to the LDC.

## Unit & directional-sign controls (Principle 1: anchor the fact first)

Most "breaks" are a unit or timing mismatch, not real economics — so before any
difference is called a break, the engine rules out two artifacts. Both run on all
three platforms (`UnitsAndSignControls.bas`, the `Unit Sign Flag` DAX measure, and
the `unit_sign_flag` Alteryx field) and a flag sets status to **REVIEW DATA
QUALITY**, which outranks the economic verdict.

**1. Missing / absent unit identifiers.** Nothing is ever assumed to be Dth.
- Each source declares its unit-of-record (`DECLARED_UNIT_*`); a feed with no
  `units` column inherits that, never a global default.
- Volumes are converted to one energy basis (**1 Dth = 1 MMBtu = 10 therms =
  1,000,000 Btu**) before differencing. `GJ` converts; **Mcf / MWh / MBtu convert
  only with heat content**, so they are flagged `UNIT_UNCONVERTIBLE` — caught by
  their *label*, never guessed from a ratio.
- If no unit can be resolved at all → `UNIT_UNKNOWN`, confidence drops, and a
  **ratio fingerprint** is emitted: a ~10:1 or ~0.1:1 gap is therms↔Dth, a ~1000:1
  gap is Btu↔MMBtu — not millions of Dth of missing gas. (12-16 demonstrates this.)

**2. Directional sign inversion.** When an invoice stores absolute magnitudes and a
ledger signs a sale the other way, naive `a − b` doubles into a phantom break and
`Abs()` can hide a real one.
- Each source declares a sign convention (`SIGN_*`); a known-inverted feed is set
  to `-1` and canonicalized at load.
- When the convention is *undeclared*, the detector tests `sign(a) ≠ sign(b)` with
  near-equal magnitude → **SIGN INVERSION** (artifact); opposite sign, unequal
  magnitude → **SIGN DISAGREEMENT** (a real directional break). `Abs()` is used
  only at the materiality gate — never to net a directional disagreement away.
  (12-17 demonstrates this.)

> **Alteryx note:** the `.yxmd` guard fingerprints magnitude/sign artifacts on
> values already on the Dth basis (the sample feeds declare Dth). Put a Select/
> Formula unit-normalization step ahead of the join if a feed arrives in another
> unit, mirroring `CanonDth` in the VBA.

## How it maps to the six-stage delivery workflow

1. **Frame** — the 1,850 Dth gap; outcome = corrected delivered qty, root cause,
   restated invoice, imbalance check.
2. **Discovery (BA)** — data dictionary = the `sample-data` column headers; tiers
   noted in each file; materiality = any daily volume break shown.
3. **Design (Tech Lead + UX)** — three Tier-1 inputs → join on the key → variance
   decomposition; exception-queue UX in `powerbi/`.
4. **Build (Dev)** — `vba/` engine and `alteryx/` workflow; both decompose the
   break and rank the cause.
5. **Test (QA)** — cross-platform tie-out is the control: all three must return
   the same numbers (verified above). Edge cases seeded in the sample data
   (imbalance without a delivery break; allocation-variance break; preliminary
   index on 12-14).
6. **Handoff (Tech Lead)** — fix the feed to store *final scheduled + allocated*,
   not Timely nominations; daily control: **block invoicing when book delivered ≠
   pipeline allocated** (`Invoice Hold` measure / VBA status column).

## Quick start

**Excel/VBA:** open a workbook, import both `.bas` files (Alt+F11 → File → Import),
add four sheets named `book`, `pipeline`, `counterparty`, `index` and paste the
matching CSVs (headers in row 1), then run `RunReconciliation`. Output lands on a
formatted `Reconciliation` sheet.

**Alteryx:** open `alteryx/SettlementReconciliation.yxmd`. Inputs resolve via
`%engine.workflowdirectory%` to `../sample-data/`. Run → writes
`sample-data/reconciliation_output.csv`.

**Power BI:** follow `powerbi/README.md` to load the CSVs and paste `measures.dax`.

## Guardrails honored (Section 7)

- No fabricated terms, indices, prices, or volumes — everything traces to a
  `sample-data` file or a cited clause cell in the term-extraction sheet.
- Unit/timing is anchored first: `AnchorAndValidate` hard-stops on a non-date gas
  day (timing), while units are normalized to Dth and any unknown/unconvertible or
  sign-inverted volume is flagged rather than assumed (see Unit & sign controls).
- When the lake (allocation) and the book/counterparty disagree, that is surfaced
  as a flagged break — never silently resolved.
- Decision-support only: this supports the analyst's judgment; it does not give
  legal, accounting, or regulatory sign-off.
