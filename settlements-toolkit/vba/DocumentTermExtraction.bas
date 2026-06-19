Attribute VB_Name = "DocumentTermExtraction"
'==============================================================================
' DocumentTermExtraction
'------------------------------------------------------------------------------
' Builds the Section-4 document-analysis artifact for a contract, confirmation,
' statement, invoice, or tariff:
'   - a term table (commodity, qty/units, price/index+basis, point, tenor,
'     title/risk, payment, fuel/loss/shrinkage/quality, special provisions,
'     termination/FM, regulatory refs)
'   - a settlement-impact column (what each term changes in the calc)
'   - a clause-citation column (quote briefly, Principle 4: cite, don't fabricate)
'   - a cross-check block producing three lists: matches / mismatches / gaps
'
' This module DOES NOT parse the PDF/.docx itself - extraction is the analyst's
' read of the source. It generates the structured, Excel-transferable scaffold
' so every extracted value is forced to carry a citation and a lake cross-check,
' which is the control the prompt requires.
'
' Usage: run BuildTermSheet. Fill the yellow cells from the document; the
'        Status column auto-flags Match / Mismatch / Gap against the lake value.
'==============================================================================
Option Explicit

Private Const SH As String = "Term Extraction"

Public Sub BuildTermSheet()
    Dim ws As Worksheet
    On Error Resume Next
    Application.DisplayAlerts = False
    ThisWorkbook.Worksheets(SH).Delete
    Application.DisplayAlerts = True
    On Error GoTo 0
    Set ws = ThisWorkbook.Worksheets.Add
    ws.Name = SH

    ' --- Document identification block (Section 4 step 1) --------------------
    ws.Range("A1").Value = "DOCUMENT IDENTIFICATION"
    Dim ident As Variant
    ident = Array("Document type", "Parties", "Effective date", "Governing master")
    Dim i As Long
    For i = 0 To UBound(ident)
        ws.Cells(2 + i, 1).Value = ident(i)
        ws.Cells(2 + i, 2).Interior.Color = RGB(255, 242, 204)   ' fill me
    Next i

    ' --- Term table header (Section 4 step 2-5) -----------------------------
    Dim hdrRow As Long: hdrRow = 8
    Dim h As Variant
    h = Array("Term", "Extracted value", "Units", "Settlement impact (what it changes)", _
              "Clause / section", "Brief quote", "Lake value (Tier 1)", "Status")
    For i = 0 To UBound(h)
        ws.Cells(hdrRow, i + 1).Value = h(i)
    Next i

    ' --- Standard term rows -------------------------------------------------
    Dim terms As Variant
    terms = Array( _
      Array("Commodity", "Defines product; gas/power/oil settlement path"), _
      Array("Quantity / volume", "Drives the settlement quantity; check MDQ/MDWQ"), _
      Array("Price / index + basis", "Sets unit value; Gas Daily vs first-of-month"), _
      Array("Delivery point / pipeline / meter", "Determines applicable index + tariff"), _
      Array("Term / tenor", "Bounds the settlement period; proration at edges"), _
      Array("Title & risk transfer", "Who bears loss; where the sale settles"), _
      Array("Payment terms & timing", "Invoice/due dates; provisional vs final true-up"), _
      Array("Fuel retention", "Gross vs net of fuel; reduces delivered qty"), _
      Array("Loss / shrinkage", "Adjusts deliverable volume on the path"), _
      Array("Quality adjustment", "Btu/heat-content or quality bank impact"), _
      Array("Imbalance / OBA terms", "Cash-out vs in-kind; trading ranges"), _
      Array("Special provisions", "Optionality, swing, banking, AMA carve-outs"), _
      Array("Termination & force majeure", "Suspends/ends performance; FM relief"), _
      Array("Regulatory references", "FERC order/tariff, NAESB WGQ, ISO charge codes") _
    )
    Dim r As Long: r = hdrRow + 1
    For i = 0 To UBound(terms)
        ws.Cells(r, 1).Value = terms(i)(0)
        ws.Cells(r, 4).Value = terms(i)(1)
        ' analyst-fill cells
        ws.Range(ws.Cells(r, 2), ws.Cells(r, 3)).Interior.Color = RGB(255, 242, 204)
        ws.Range(ws.Cells(r, 5), ws.Cells(r, 7)).Interior.Color = RGB(255, 242, 204)
        ' Status: Match / Mismatch / Gap vs the lake value (Section 4 step 4)
        ws.Cells(r, 8).Formula = _
            "=IF($G" & r & "="""",""GAP - not in lake""," & _
            "IF($B" & r & "="""",""GAP - not extracted""," & _
            "IF(TRIM($B" & r & ")=TRIM($G" & r & "),""MATCH"",""MISMATCH"")))"
        r = r + 1
    Next i

    ' --- Cross-check summary (three lists: matches / mismatches / gaps) ------
    Dim sRow As Long: sRow = r + 2
    ws.Cells(sRow, 1).Value = "CROSS-CHECK SUMMARY (Tier-1 lake/regulation)"
    ws.Cells(sRow + 1, 1).Value = "Matches"
    ws.Cells(sRow + 1, 2).Formula = "=COUNTIF($H$" & (hdrRow + 1) & ":$H$" & (r - 1) & ",""MATCH"")"
    ws.Cells(sRow + 2, 1).Value = "Mismatches (breaks to surface)"
    ws.Cells(sRow + 2, 2).Formula = "=COUNTIF($H$" & (hdrRow + 1) & ":$H$" & (r - 1) & ",""MISMATCH"")"
    ws.Cells(sRow + 3, 1).Value = "Gaps (missing info)"
    ws.Cells(sRow + 3, 2).Formula = "=COUNTIF($H$" & (hdrRow + 1) & ":$H$" & (r - 1) & ",""GAP*"")"
    ws.Cells(sRow + 5, 1).Value = "Open questions / ambiguities:"
    ws.Cells(sRow + 6, 1).Interior.Color = RGB(255, 242, 204)
    ws.Cells(sRow + 8, 1).Value = "Confidence (High / Med / Low) + why:"
    ws.Cells(sRow + 9, 1).Interior.Color = RGB(255, 242, 204)

    Format ws, 1, hdrRow, sRow
    ws.Activate
    MsgBox "Term-extraction scaffold built. Fill the yellow cells from the document." & vbCrLf & _
           "Yellow = analyst input; Status auto-flags Match/Mismatch/Gap vs the lake.", _
           vbInformation, "Document Analysis"
End Sub

Private Sub Format(ws As Worksheet, ByVal identRow As Long, ByVal hdrRow As Long, ByVal sumRow As Long)
    ws.Cells(identRow, 1).Font.Bold = True
    ws.Cells(identRow, 1).Font.Size = 12
    With ws.Range(ws.Cells(hdrRow, 1), ws.Cells(hdrRow, 8))
        .Font.Bold = True
        .Interior.Color = RGB(31, 78, 121)
        .Font.Color = RGB(255, 255, 255)
    End With
    ws.Cells(sumRow, 1).Font.Bold = True
    ws.Cells(sumRow, 1).Font.Size = 12
    ws.Columns("A").ColumnWidth = 34
    ws.Columns("B").ColumnWidth = 22
    ws.Columns("C").ColumnWidth = 8
    ws.Columns("D").ColumnWidth = 42
    ws.Columns("E:F").ColumnWidth = 26
    ws.Columns("G").ColumnWidth = 18
    ws.Columns("H").ColumnWidth = 16
End Sub
