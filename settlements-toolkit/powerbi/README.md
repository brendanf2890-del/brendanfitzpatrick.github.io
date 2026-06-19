# Power BI — Settlements Exception Dashboard

The reporting and exception-queue layer (Stage 3 UX + Stage 6 monitoring) of the
Energy Settlements Delivery Workflow. Power BI is the *thin* layer here: the math
lives in `measures.dax` (mirrored from the VBA and Alteryx engines), and the
report is the human-interaction surface — an exception queue that drills from a
headline break into its parts and reads on a phone.

## Build steps

1. **Get data** → Text/CSV → load the four files from `../sample-data/`:
   `book.csv`, `pipeline.csv`, `counterparty.csv`, `index_prices.csv`.
   (In production, point these at the lake tables instead.)
2. In Power Query, set numeric columns (`*_dth`, `index_price`, `basis`) to
   Decimal Number and `gas_day` to Date. **This is the Principle-1 anchor** —
   do it before anything else so a unit/timing mismatch can't masquerade as a
   real break.
3. Add a `Key` column to Book, Pipeline, Counterparty:
   `Key = [gas_day] & "|" & [contract] & "|" & [point]`.
   Add `Key = [gas_day] & "|" & [point]` to Index.
4. Model view → relate Book ↔ Pipeline ↔ Counterparty 1:1 on `Key`; relate Index
   on its `Key`. Mark the relationships single-direction from Pipeline.
5. Create a measures table `_Recon` and paste everything from `measures.dax`.

## Report pages (Stage-3 UX)

**Page 1 — Exception queue (desktop + phone layout):**
- A table visual, one record per `(gas_day, contract, point)`, columns:
  `Book Delivered Dth`, `Allocated Dth`, `CP Confirmed Dth`, `Total Break Dth`,
  `Cut Dth`, `Alloc Var Dth`, `Net Imbalance Dth`, `Cash Delta USD`,
  `Break Status`, `Root Cause`.
- Conditional formatting: red background where `Break Status = "BREAK"`.
- Cards across the top: `Break Count`, `Break $ Exposure`, `Invoice Hold`,
  `Preliminary Price Count`.
- Filter to `Break Status = "BREAK"` by default so the page *is* the work queue.
- Configure the **phone layout** (View → Mobile layout): stack the four cards
  then the table, so a reviewer can clear breaks from their phone.

**Page 2 — Break drill-through:**
- Set up drill-through on `contract` + `gas_day`.
- Show the full decomposition (`Sched Timely → Sched Final → Allocated`) as a
  waterfall, plus the `Root Cause`, `Imbalance Flag`, `All-in Price`,
  `Price Status` text cards with the cut reason.

## Cross-platform control

`measures.dax` is intentionally identical in logic to
`vba/SettlementReconciliation.bas` and the Alteryx Formula tool. Running the same
`sample-data` through all three must yield the same `Total Break Dth` and
`Cash Delta USD` for `2025-12-12 / FT-Transco / Y Citygate` (break **1,850 Dth**,
cut **1,800** + alloc var **50**, nil imbalance). If they ever diverge, that is a
control failure to investigate — not a number to pick from.
