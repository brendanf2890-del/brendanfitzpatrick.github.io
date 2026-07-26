Attribute VB_Name = "InventoryModel"
'======================================================================
' INVENTORY MONETIZATION MODEL  -  self-building VBA module
'
' HOW TO USE
'   1. Alt+F11 (open the VBE) > Insert > Module > paste this whole file.
'   2. Run  BuildModel   to construct the workbook from scratch.
'   3. Each new flow date, run  RollNewDay  : it freezes the current _
'      live row to values (settled history) and opens a fresh live row
'      that pulls the refreshed Latest Inventory Report and live prices.
'
' THEME  blue = input, black = calc, green = link, navy/yellow = headers.
' DATES  Delivered = WORKDAY(Flow,1), Invoiced = WORKDAY(Flow,2),
'        Paid = WORKDAY(Flow,3), holiday-aware. Fri/Sat/Sun all batch
'        to Tuesday invoice / Wednesday payment automatically.
'======================================================================
Option Explicit

' ---------- theme ----------
Private Function cNavy() As Long: cNavy = RGB(31, 56, 100): End Function
Private Function cYellow() As Long: cYellow = RGB(255, 242, 204): End Function
Private Function cLive() As Long: cLive = RGB(226, 239, 218): End Function
Private Function cBlue() As Long: cBlue = RGB(0, 112, 192): End Function
Private Function cGreen() As Long: cGreen = RGB(0, 176, 80): End Function
Private Function cGrey() As Long: cGrey = RGB(128, 128, 128): End Function
Private Const FBBL As String = "#,##0;(#,##0);""-"""
Private Const FUSD2 As String = "$#,##0.00;($#,##0.00);""-"""
Private Const FUSD0 As String = "$#,##0;($#,##0);""-"""
Private Const FPCT As String = "0.0%"
Private Const FNUM2 As String = "#,##0.00"
Private Const FVCF As String = "0.00000"
Private Const FDT As String = "ddd dd-mmm-yy"
Private Const NG As Long = 12       ' number of product groups
Private Const HROWS As Long = 30    ' hard-coded history rows
Private Const DR As Long = 6        ' first data row

' ---------- config (filled by Cfg) ----------
Private gName, gCount, gBase, gCapLo, gCapHi, gFillLo, gFillHi
Private gTempLo, gTempHi, gApiLo, gApiHi, gCoef, gBswLo, gBswHi
Private gGrades, gFamily, gUnit, gConv, gAdv, gDiff, gTHB, gNative

' ---------- roster (filled by BuildRoster) ----------
Private rTank() As String, rGroup() As String, rGrade() As String
Private rCap() As Double, rGov() As Double, rTemp() As Double
Private rApi() As Double, rCoef() As Double, rBsw() As Double
Private nTanks As Long

Private Sub Cfg()
    gName = Array("Crude", "Fuel Intermediates", "Finished Diesel", "Finished Jet", _
        "Finished Gasoline", "Finished Asphalt", "Finished Light Lubes", "Finished Medium Lubes", _
        "Finished Heavy Lubes", "Finished Wax", "Lube Intermediates", "Wax Intermediate")
    gCount = Array(10, 8, 7, 4, 7, 4, 4, 3, 3, 2, 5, 3)
    gBase = Array(101, 201, 301, 331, 351, 401, 501, 521, 541, 601, 701, 721)
    gCapLo = Array(250000#, 80000#, 90000#, 70000#, 80000#, 40000#, 30000#, 30000#, 25000#, 15000#, 40000#, 15000#)
    gCapHi = Array(450000#, 180000#, 160000#, 120000#, 150000#, 90000#, 70000#, 60000#, 55000#, 40000#, 90000#, 40000#)
    gFillLo = Array(0.45, 0.4, 0.45, 0.5, 0.45, 0.4, 0.45, 0.45, 0.45, 0.4, 0.45, 0.4)
    gFillHi = Array(0.85, 0.8, 0.85, 0.85, 0.85, 0.8, 0.8, 0.8, 0.8, 0.75, 0.8, 0.75)
    gTempLo = Array(80, 90, 65, 64, 60, 300, 100, 110, 120, 150, 100, 150)
    gTempHi = Array(95, 120, 82, 78, 75, 345, 130, 140, 150, 180, 130, 180)
    gApiLo = Array(25, 30, 33, 40, 55, 6, 28, 25, 20, 36, 28, 35)
    gApiHi = Array(38, 46, 37, 44, 62, 12, 32, 28, 24, 40, 34, 40)
    gCoef = Array(0.0004, 0.00055, 0.0005, 0.00058, 0.0007, 0.00025, 0.00036, 0.00035, 0.00034, 0.00035, 0.0004, 0.0004)
    gBswLo = Array(0.3, 0.1, 0.02, 0.01, 0#, 0#, 0#, 0#, 0#, 0#, 0.02, 0.01)
    gBswHi = Array(0.75, 0.3, 0.08, 0.05, 0.03, 0.02, 0.04, 0.04, 0.04, 0.03, 0.06, 0.05)
    gGrades = Array( _
        "Domestic Sweet|WTI Cushing|WTS Sour|Mars Sour|WCS Heavy|Bakken|LLS Sweet|Eagle Ford|Maya Heavy|Bonny Light", _
        "Light Cat Naphtha|Heavy Cat Naphtha|Light Cycle Oil|Heavy Cycle Oil|Vacuum Gasoil|Atmos Gasoil|FCC Slurry|Reformate", _
        "ULSD No.2|ULSD Premium|Off-Road Dyed|ULSD Winter|Renewable Diesel|ULSD Export|ULSD Cold Flow", _
        "Jet A|Jet A-1|JP-8|Jet A Export", _
        "RBOB Regular|RBOB Premium|CBOB Regular|Conv. Regular|Conv. Premium|RBOB Winter|Sub-octane", _
        "PG 64-22|PG 67-22|PG 76-22|Roofing Flux", _
        "SN-100|SN-150|Group II 100N|Group II 150N", _
        "SN-350|Group II 220N|Group II 350N", _
        "SN-500|Brightstock 150|Group II 600N", _
        "Slack Wax|Refined Paraffin", _
        "Light Raffinate|Medium Raffinate|Heavy Raffinate|Dewaxed Oil|Hydrofinished Base", _
        "Foots Oil|Crude Scale Wax|Soft Wax")
    gFamily = Array("NYMEX WTI Swap", "NYMEX WTI Swap", "NYMEX ULSD", "NYMEX ULSD", "NYMEX RBOB", _
        "NYMEX WTI Swap", "NYMEX WTI Swap", "NYMEX WTI Swap", "NYMEX WTI Swap", "NYMEX WTI Swap", _
        "50% WTI + 50% ULSD", "50% WTI + 50% ULSD")
    gUnit = Array("$/bbl", "$/bbl", "cents/gal", "cents/gal", "cents/gal", "$/bbl", "$/bbl", _
        "$/bbl", "$/bbl", "$/bbl", "$/bbl", "$/bbl")
    gConv = Array(1#, 1#, 0.42, 0.42, 0.42, 1#, 1#, 1#, 1#, 1#, 1#, 1#)   ' native -> $/bbl
    gAdv = Array(0.98, 0.97, 0.98, 0.98, 0.98, 0.97, 0.9, 0.9, 0.9, 0.9, 0.97, 0.97)
    gDiff = Array(-1.5, -8#, 2#, 6#, 1#, -25#, 35#, 50#, 58#, 85#, -6#, -6#)
    gTHB = Array(-7.5, -9#, -9.5, -10.25, -7.5, -8.5, -25.25, -28#, -35.5, -35.5, -9#, -9#)
    gNative = Array(73#, 73#, 262#, 262#, 219#, 73#, 73#, 73#, 73#, 73#, 91.52, 91.52)
End Sub

'======================================================================
Public Sub BuildModel()
    Dim wb As Workbook: Set wb = ActiveWorkbook
    Application.ScreenUpdating = False
    Cfg
    Rnd -1: Randomize 7
    BuildRoster
    KillSheets wb
    BuildLatestReport wb
    BuildLedger wb
    BuildPricing wb
    BuildExposure wb
    BuildNotes wb
    wb.Worksheets("Latest Inventory Report").Activate
    Application.ScreenUpdating = True
    MsgBox "Model built. Run RollNewDay each new flow date to advance the live row.", vbInformation
End Sub

Private Sub KillSheets(wb As Workbook)
    Dim nm, ws As Worksheet
    Application.DisplayAlerts = False
    For Each nm In Array("Latest Inventory Report", "Daily Ledger", "Daily Pricing", "Exposure", "Notes & Key")
        On Error Resume Next: wb.Worksheets(nm).Delete: On Error GoTo 0
    Next
    ' ensure at least one sheet remains during rebuild
    If wb.Worksheets.Count = 0 Then wb.Worksheets.Add
    Application.DisplayAlerts = True
End Sub

Private Sub BuildRoster()
    Dim i As Long, k As Long, gi As Long, parts, fill As Double
    nTanks = 0
    For gi = 0 To NG - 1: nTanks = nTanks + gCount(gi): Next
    ReDim rTank(1 To nTanks): ReDim rGroup(1 To nTanks): ReDim rGrade(1 To nTanks)
    ReDim rCap(1 To nTanks): ReDim rGov(1 To nTanks): ReDim rTemp(1 To nTanks)
    ReDim rApi(1 To nTanks): ReDim rCoef(1 To nTanks): ReDim rBsw(1 To nTanks)
    k = 0
    For gi = 0 To NG - 1
        parts = Split(gGrades(gi), "|")
        For i = 0 To gCount(gi) - 1
            k = k + 1
            rTank(k) = "TK-" & (gBase(gi) + i)
            rGroup(k) = gName(gi)
            rGrade(k) = parts(i Mod (UBound(parts) + 1))
            rCap(k) = WorksheetFunction.Round(RandR(gCapLo(gi), gCapHi(gi)), -2)
            fill = RandR(gFillLo(gi), gFillHi(gi))
            rGov(k) = WorksheetFunction.Round(rCap(k) * fill, -1)
            rTemp(k) = WorksheetFunction.Round(RandR(gTempLo(gi), gTempHi(gi)), 1)
            rApi(k) = WorksheetFunction.Round(RandR(gApiLo(gi), gApiHi(gi)), 1)
            rCoef(k) = gCoef(gi)
            rBsw(k) = WorksheetFunction.Round(RandR(gBswLo(gi), gBswHi(gi)), 2)
        Next
    Next
End Sub

'====================== TAB 1: Latest Inventory Report =================
Private Sub BuildLatestReport(wb As Workbook)
    Dim ws As Worksheet, r As Long, k As Long, g As String, r1 As Long
    Set ws = wb.Worksheets.Add(After:=wb.Worksheets(wb.Worksheets.Count))
    ws.Name = "Latest Inventory Report": ws.Tab.Color = cNavy
    Title ws, 1, "LATEST INVENTORY REPORT  -  Live Flow Date  (source for the live ledger row)", 14
    SubT ws, 2, "Barrels, corrected to 60 deg F. NSV feeds the live ledger row by Product Group (SUMIF on Grp Key)."
    Dim H: H = Array("Tank No.", "Product Group", "Grade", "Shell Cap. (bbl)", "GOV (bbl)", "Temp (F)", _
        "API", "Therm. Coef", "VCF", "GSV (bbl)", "BS&W (%)", "NSV (bbl)", "Ullage (bbl)", "Grp Key (calc)")
    BandRow ws, 4, 1, 14, "DAILY TANK GAUGE  &  NET STANDARD VOLUME"
    HdrRow ws, 5, H
    r = DR
    For k = 1 To nTanks
        Lbl ws, r, 1, rTank(k), True, xlCenter
        ' col 2 product group written at block start, then merged
        Lbl ws, r, 3, rGrade(k), False, xlLeft
        Inp ws, r, 4, rCap(k), FBBL: Inp ws, r, 5, rGov(k), FBBL
        Inp ws, r, 6, rTemp(k), FNUM2: Inp ws, r, 7, rApi(k), FNUM2
        Inp ws, r, 8, rCoef(k), FVCF
        Calc ws, r, 9, "=1-H" & r & "*(F" & r & "-60)", FVCF
        Calc ws, r, 10, "=E" & r & "*I" & r, FBBL
        Inp ws, r, 11, rBsw(k), FNUM2
        Calc ws, r, 12, "=J" & r & "*(1-K" & r & "/100)", FBBL
        Calc ws, r, 13, "=D" & r & "-E" & r, FBBL
        Lbl ws, r, 14, rGroup(k), False, xlCenter: ws.Cells(r, 14).Font.Color = cGrey
        r = r + 1
    Next
    ' merge product-group display column per block
    r1 = DR
    For k = 1 To nTanks
        If k = nTanks Then
            MergeGroup ws, r1, DR + k - 1
        ElseIf rGroup(k + 1) <> rGroup(k) Then
            MergeGroup ws, r1, DR + k - 1: r1 = DR + k
        End If
    Next
    SetWidths ws, Array(10, 22, 18, 11, 11, 8, 7, 8, 9, 11, 8, 11, 11, 12)
    Borders ws, DR, 1, DR + nTanks - 1, 14
    ws.Cells.RowHeight = 15
    Finish ws, "D6", "$4:$5"
End Sub

Private Sub MergeGroup(ws As Worksheet, r1 As Long, r2 As Long)
    Dim grp As String: grp = rGroup(r1 - DR + 1)
    With ws.Range(ws.Cells(r1, 2), ws.Cells(r2, 2))
        .Merge: .Value = grp: .Font.Name = "Arial": .Font.Size = 10: .Font.Bold = True
        .HorizontalAlignment = xlCenter: .VerticalAlignment = xlCenter: .WrapText = True
        .Borders.LineStyle = xlContinuous: .Borders.Color = RGB(191, 191, 191)
    End With
End Sub

'====================== TAB 2: Daily Ledger ===========================
Private Sub BuildLedger(wb As Workbook)
    Dim ws As Worksheet, d As Long, r As Long, gi As Long, c As Long, ec As String
    Dim lastRow As Long, liveDate As Date, totCol As Long
    Dim beginV() As Double, endV() As Double
    GenChains beginV, endV       ' history begin/end per group
    Set ws = wb.Worksheets.Add(After:=wb.Worksheets(wb.Worksheets.Count))
    ws.Name = "Daily Ledger": ws.Tab.Color = cNavy
    Title ws, 1, "DAILY INVENTORY LEDGER  -  one row per flow date (30 settled rows hard-coded, live row formulaic)", 12
    SubT ws, 2, "Begin/End NSV per Product Group. Delivered=WORKDAY(Flow,1), Invoiced=WORKDAY(Flow,2) [Fri/Sat/Sun batch to Tue], Paid=WORKDAY(Flow,3)."
    Lbl ws, 3, 1, "Valuation Date:", True, xlRight
    liveDate = Date                       ' today as the live flow date
    Inp ws, 3, 2, CDbl(liveDate), FDT
    wb.Names.Add "ValDate", "='Daily Ledger'!$B$3"
    Dim tl: tl = Array("Flow Date", "DOW", "Delivered", "Invoiced", "Paid", "Status")
    BandRow ws, 4, 1, 6, "DATE & SETTLEMENT TIMELINE"
    HdrRow ws, 5, tl
    c = 7
    For gi = 0 To NG - 1
        BandRow ws, 4, c, c + 1, gName(gi)
        HdrCell ws, 5, c, "Begin NSV": HdrCell ws, 5, c + 1, "End NSV"
        c = c + 2
    Next
    totCol = c
    BandRow ws, 4, totCol, totCol, "TOTAL": HdrCell ws, 5, totCol, "End NSV (bbl)"
    ' rows: 30 history + 1 live
    For d = 0 To HROWS
        r = DR + d
        Dim dt As Date, isLive As Boolean
        dt = liveDate - (HROWS - d)
        isLive = (d = HROWS)
        WriteTimeline ws, r, dt, isLive
        For gi = 0 To NG - 1
            c = 7 + gi * 2: ec = ColL(c + 1)
            If isLive Then
                LnkF ws, r, c, "=" & ec & (r - 1), FBBL, isLive          ' begin = prior end
                LnkF ws, r, c + 1, "=SUMIF('Latest Inventory Report'!$N$" & DR & ":$N$" & (DR + nTanks - 1) & _
                    ",""" & gName(gi) & """,'Latest Inventory Report'!$L$" & DR & ":$L$" & (DR + nTanks - 1) & ")", FBBL, isLive
                ws.Cells(r, c + 1).Font.Bold = True
            Else
                InpF ws, r, c, beginV(d, gi), FBBL
                InpF ws, r, c + 1, endV(d, gi), FBBL
            End If
        Next
        ' total end
        Dim s As String: s = ""
        For gi = 0 To NG - 1: s = s & IIf(gi > 0, "+", "") & ColL(7 + gi * 2 + 1) & r: Next
        CalcF ws, r, totCol, "=" & s, FBBL, isLive
        If isLive Then HiliteRow ws, r, totCol
        ws.Rows(r).RowHeight = 14
    Next
    SetWidths ws, Array(12, 6, 12, 12, 12, 9)
    Dim j As Long
    For j = 7 To totCol: ws.Columns(j).ColumnWidth = 11: Next
    ws.Columns(totCol).ColumnWidth = 13
    Borders ws, DR, 1, DR + HROWS, totCol
    Finish ws, "G6", "$4:$5"
End Sub

'====================== TAB 3: Daily Pricing ==========================
Private Sub BuildPricing(wb As Workbook)
    Dim ws As Worksheet, d As Long, r As Long, gi As Long, c As Long
    Dim liveDate As Date, base As Double, p As Double
    Set ws = wb.Worksheets.Add(After:=wb.Worksheets(wb.Worksheets.Count))
    ws.Name = "Daily Pricing": ws.Tab.Color = RGB(46, 117, 182)
    Title ws, 1, "DAILY PRICING  -  Net Settlement ($/bbl) per Product Group (history hard-coded, live row pulls the build-up)", 12
    SubT ws, 2, "Pricing stays LIVE regardless of the 2-day invoice lag. Net = (Index*Conv + Diff) x Adv Rate + Total HB."
    HdrCell ws, 4, 1, "Flow Date": ws.Range("A4:A5").Merge
    For gi = 0 To NG - 1
        BandRow ws, 4, 2 + gi, 2 + gi, gName(gi): HdrCell ws, 5, 2 + gi, "Net $/bbl"
    Next
    liveDate = Date
    For d = 0 To HROWS
        r = DR + d
        Dim dt As Date, isLive As Boolean
        dt = liveDate - (HROWS - d): isLive = (d = HROWS)
        If isLive Then CalcF ws, r, 1, "", FDT, True: ws.Cells(r, 1).Value = CDbl(dt) Else Inp ws, r, 1, CDbl(dt), FDT
        ws.Cells(r, 1).NumberFormat = FDT
        For gi = 0 To NG - 1
            c = 2 + gi
            If isLive Then
                LnkF ws, r, c, "=$I$" & (41 + gi), FUSD2, True: ws.Cells(r, c).Font.Bold = True
            Else
                base = NetLevel(gi)
                If d = 0 Then p = base * RandR(0.97, 1.03)
                p = p + 0.1 * (base - p) + base * RandR(-0.012, 0.012)
                Inp ws, r, c, WorksheetFunction.Round(p, 2), FUSD2
            End If
        Next
        ws.Rows(r).RowHeight = 14
    Next
    ' Live Price Build-Up (rows 40 header, 41.. groups)
    BandRow ws, 39, 1, 9, "LIVE PRICE BUILD-UP  (drives the live ledger row)"
    Dim bh: bh = Array("Product Group", "Index Family", "Native Unit", "Native Index", _
        "Conv (x)", "Adv. Rate", "Diff ($/bbl)", "Total HB ($/bbl)", "Net Settle ($/bbl)")
    HdrRow ws, 40, bh
    For gi = 0 To NG - 1
        r = 41 + gi
        Lbl ws, r, 1, gName(gi), True, xlLeft
        Lbl ws, r, 2, gFamily(gi), False, xlLeft
        Lbl ws, r, 3, gUnit(gi), False, xlCenter
        Inp ws, r, 4, gNative(gi), FNUM2
        Inp ws, r, 5, gConv(gi), "0.00"
        Inp ws, r, 6, gAdv(gi), FPCT
        Inp ws, r, 7, gDiff(gi), FUSD2
        Inp ws, r, 8, gTHB(gi), FUSD2
        Calc ws, r, 9, "=(D" & r & "*E" & r & "+G" & r & ")*F" & r & "+H" & r, FUSD2
        ws.Cells(r, 9).Font.Bold = True
        ws.Rows(r).RowHeight = 14
    Next
    ws.Columns(1).ColumnWidth = 22
    Dim j As Long: For j = 2 To 13: ws.Columns(j).ColumnWidth = 11: Next
    Borders ws, DR, 1, DR + HROWS, 1 + NG
    Borders ws, 40, 1, 40 + NG, 9
    Finish ws, "B6", "$4:$5"
End Sub

'====================== TAB 4: Exposure ===============================
Private Sub BuildExposure(wb As Workbook)
    Dim ws As Worksheet, d As Long, r As Long, gi As Long, ec As Long
    Dim liveDate As Date, ledEnd As String, prCol As String
    Set ws = wb.Worksheets.Add(After:=wb.Worksheets(wb.Worksheets.Count))
    ws.Name = "Exposure": ws.Tab.Color = RGB(192, 0, 0)
    Title ws, 1, "EXPOSURE  -  Up-to-the-Minute Monetized Value (End NSV x Net Settlement, marked at LIVE prices)", 12
    SubT ws, 2, "Total Exposure = standing position today. Daily Settlement = day-over-day change in exposure = the true-up. Live row flagged."
    Dim hh: hh = Array("Flow Date", "Total Exposure ($)", "Daily Settlement ($)", "Invoiced", "Paid", "Status")
    BandRow ws, 4, 1, 6, "PORTFOLIO EXPOSURE & SETTLEMENT TIMELINE"
    HdrRow ws, 5, hh
    ec = 7
    For gi = 0 To NG - 1
        BandRow ws, 4, ec, ec, gName(gi): HdrCell ws, 5, ec, "Exposure ($)": ec = ec + 1
    Next
    liveDate = Date
    For d = 0 To HROWS
        r = DR + d
        Dim dt As Date, isLive As Boolean
        dt = liveDate - (HROWS - d): isLive = (d = HROWS)
        Inp ws, r, 1, CDbl(dt), FDT: If isLive Then HiliteRow ws, r, ec - 1
        For gi = 0 To NG - 1
            ledEnd = ColL(7 + gi * 2 + 1): prCol = ColL(2 + gi)
            Calc ws, r, 7 + gi, "='Daily Ledger'!" & ledEnd & r & "*'Daily Pricing'!" & prCol & r, FUSD0
        Next
        Calc ws, r, 2, "=SUM(" & ColL(7) & r & ":" & ColL(ec - 1) & r & ")", FUSD0
        ws.Cells(r, 2).Font.Bold = True
        If d = 0 Then Calc ws, r, 3, "=0", FUSD0 Else Calc ws, r, 3, "=B" & r & "-B" & (r - 1), FUSD0
        Lnk ws, r, 4, "='Daily Ledger'!D" & r, FDT
        Lnk ws, r, 5, "='Daily Ledger'!E" & r, FDT
        Lnk ws, r, 6, "='Daily Ledger'!F" & r, ""
        ws.Rows(r).RowHeight = 14
    Next
    SetWidths ws, Array(12, 15, 15, 12, 12, 10)
    Dim j As Long: For j = 7 To ec - 1: ws.Columns(j).ColumnWidth = 11: Next
    Borders ws, DR, 1, DR + HROWS, ec - 1
    ' conditional format on Daily Settlement (green positive, red negative)
    Dim rng As Range: Set rng = ws.Range("C" & DR & ":C" & (DR + HROWS))
    rng.FormatConditions.Delete
    With rng.FormatConditions.Add(xlCellValue, xlGreater, "0"): .Font.Color = RGB(0, 128, 0): End With
    With rng.FormatConditions.Add(xlCellValue, xlLess, "0"): .Font.Color = RGB(255, 0, 0): End With
    Finish ws, "G6", "$4:$5"
End Sub

'====================== TAB 5: Notes & Key ============================
Private Sub BuildNotes(wb As Workbook)
    Dim ws As Worksheet, r As Long, i As Long
    Set ws = wb.Worksheets.Add(After:=wb.Worksheets(wb.Worksheets.Count))
    ws.Name = "Notes & Key": ws.Tab.Color = cGrey
    Title ws, 1, "NOTES, SETTLEMENT TIMING & KEY", 14
    Dim notes
    notes = Array( _
      "Running file|One row per flow date, scales to ~2 years. 30 settled rows are hard-coded; the live row is formulaic and marks current inventory at live prices.", _
      "Begin / End per product|Each row carries Begin and End NSV for all 12 groups. History: begin = prior end. Live row: begin links to yesterday's end; end = SUMIF of the Latest Inventory Report.", _
      "Settlement timing|Delivered=WORKDAY(Flow,1), Invoiced=WORKDAY(Flow,2), Paid=WORKDAY(Flow,3). WORKDAY skips weekends and the holiday list, so Fri/Sat/Sun all invoice Tue and pay Wed; holidays shift the week forward.", _
      "Pricing stays live|The 2-day invoice lag is a cash item only. Exposure is always marked at the latest prices via the Live Price Build-Up.", _
      "Exposure|Total Exposure = sum of End NSV x Net Settlement. Daily Settlement = day-over-day change = the true-up. Status shows pipeline position; live row flagged.", _
      "Daily roll|Run RollNewDay each flow date: it freezes the live row to values (settled history) and opens a fresh live row pointing at the refreshed report and build-up.", _
      "Merge note|Product Group is merged for display on the report; an unmerged Grp Key drives the SUMIF. Lookups never run off the merged column.", _
      "Color key|Blue = input, Black = calc, Green = link to another sheet.")
    r = 3
    For i = 0 To UBound(notes)
        Dim p: p = Split(notes(i), "|")
        With ws.Cells(r, 1): .Value = p(0): .Fill.Color = cYellow: .Font.Bold = True
            .Font.Name = "Arial": .Font.Size = 10: .VerticalAlignment = xlTop: .Borders.LineStyle = xlContinuous: End With
        With ws.Cells(r, 2): .Value = p(1): .Font.Name = "Arial": .Font.Size = 10
            .WrapText = True: .VerticalAlignment = xlTop: .Borders.LineStyle = xlContinuous: End With
        ws.Rows(r).RowHeight = 56: r = r + 1
    Next
    ' Holidays named range
    Dim hr As Long: hr = r + 1
    With ws.Cells(hr, 1): .Value = "NYMEX / US HOLIDAYS (used by WORKDAY)": .Fill.Color = cYellow: .Font.Bold = True: End With
    Dim hol, h
    hol = Array("1/1/2025", "1/20/2025", "2/17/2025", "4/18/2025", "5/26/2025", "6/19/2025", "7/4/2025", _
        "9/1/2025", "11/27/2025", "12/25/2025", "1/1/2026", "1/19/2026", "2/16/2026", "4/3/2026", _
        "5/25/2026", "6/19/2026", "7/3/2026", "9/7/2026", "11/26/2026", "12/25/2026", "1/1/2027", _
        "1/18/2027", "2/15/2027", "3/26/2027", "5/31/2027", "6/18/2027", "7/5/2027", "9/6/2027", "11/25/2027", "12/24/2027")
    For i = 0 To UBound(hol)
        With ws.Cells(hr + 1 + i, 1): .Value = CDate(hol(i)): .NumberFormat = FDT
            .Font.Color = cBlue: .Font.Name = "Arial": .Font.Size = 10: .HorizontalAlignment = xlCenter: End With
    Next
    wb.Names.Add "Holidays", "='Notes & Key'!$A$" & (hr + 1) & ":$A$" & (hr + UBound(hol) + 1)
    ws.Columns(1).ColumnWidth = 26: ws.Columns(2).ColumnWidth = 120
    ws.Activate: ActiveWindow.DisplayGridlines = False
End Sub

'====================== DAILY ROLL ====================================
Public Sub RollNewDay()
    Dim wb As Workbook: Set wb = ActiveWorkbook
    Dim L As Worksheet, P As Worksheet, E As Worksheet
    Set L = wb.Worksheets("Daily Ledger"): Set P = wb.Worksheets("Daily Pricing"): Set E = wb.Worksheets("Exposure")
    Dim liveRow As Long, totCol As Long, gi As Long, c As Long, newRow As Long, newDate As Date
    liveRow = L.Cells(L.Rows.Count, 1).End(xlUp).Row
    totCol = 7 + NG * 2
    Application.ScreenUpdating = False
    ' 1) freeze current live row to values (settled): Ledger begin/end/total + Pricing net
    L.Range(L.Cells(liveRow, 7), L.Cells(liveRow, totCol)).Value = _
        L.Range(L.Cells(liveRow, 7), L.Cells(liveRow, totCol)).Value
    L.Range(L.Cells(liveRow, 7), L.Cells(liveRow, totCol - 1)).Font.Color = cBlue   ' now inputs
    P.Range(P.Cells(liveRow, 2), P.Cells(liveRow, 1 + NG)).Value = _
        P.Range(P.Cells(liveRow, 2), P.Cells(liveRow, 1 + NG)).Value
    P.Range(P.Cells(liveRow, 2), P.Cells(liveRow, 1 + NG)).Font.Color = cBlue
    ClearHilite L, liveRow, totCol: ClearHilite E, liveRow, 6 + NG
    ' 2) open a new live row
    newRow = liveRow + 1
    newDate = L.Cells(liveRow, 1).Value + 1
    WriteTimeline L, newRow, newDate, True
    For gi = 0 To NG - 1
        c = 7 + gi * 2
        LnkF L, newRow, c, "=" & ColL(c + 1) & liveRow, FBBL, True   ' begin = prior end
    Next
    ' rebuild SUMIF (uses current report extent) and total
    Dim lrLast As Long: lrLast = wb.Worksheets("Latest Inventory Report").Cells(wb.Worksheets("Latest Inventory Report").Rows.Count, 1).End(xlUp).Row
    Dim s As String: s = ""
    For gi = 0 To NG - 1
        c = 7 + gi * 2
        L.Cells(newRow, c + 1).Formula = "=SUMIF('Latest Inventory Report'!$N$" & DR & ":$N$" & lrLast & _
            ",""" & gName(gi) & """,'Latest Inventory Report'!$L$" & DR & ":$L$" & lrLast & ")"
        L.Cells(newRow, c + 1).Font.Color = cGreen: L.Cells(newRow, c + 1).Font.Bold = True
        s = s & IIf(gi > 0, "+", "") & ColL(c + 1) & newRow
    Next
    CalcF L, newRow, totCol, "=" & s, FBBL, True
    HiliteRow L, newRow, totCol
    L.Rows(newRow).RowHeight = 14
    Borders L, newRow, 1, newRow, totCol
    ' Pricing new live row
    Inp P, newRow, 1, CDbl(newDate), FDT: P.Cells(newRow, 1).NumberFormat = FDT
    For gi = 0 To NG - 1
        LnkF P, newRow, 2 + gi, "=$I$" & (41 + gi), FUSD2, True: P.Cells(newRow, 2 + gi).Font.Bold = True
    Next
    P.Rows(newRow).RowHeight = 14: Borders P, newRow, 1, newRow, 1 + NG
    ' Exposure new live row
    Dim ledEnd As String, prCol As String
    Inp E, newRow, 1, CDbl(newDate), FDT
    For gi = 0 To NG - 1
        ledEnd = ColL(7 + gi * 2 + 1): prCol = ColL(2 + gi)
        Calc E, newRow, 7 + gi, "='Daily Ledger'!" & ledEnd & newRow & "*'Daily Pricing'!" & prCol & newRow, FUSD0
    Next
    Calc E, newRow, 2, "=SUM(" & ColL(7) & newRow & ":" & ColL(6 + NG) & newRow & ")", FUSD0
    E.Cells(newRow, 2).Font.Bold = True
    Calc E, newRow, 3, "=B" & newRow & "-B" & liveRow, FUSD0
    Lnk E, newRow, 4, "='Daily Ledger'!D" & newRow, FDT
    Lnk E, newRow, 5, "='Daily Ledger'!E" & newRow, FDT
    Lnk E, newRow, 6, "='Daily Ledger'!F" & newRow, ""
    HiliteRow E, newRow, 6 + NG
    E.Rows(newRow).RowHeight = 14: Borders E, newRow, 1, newRow, 6 + NG
    ' extend exposure conditional format
    Dim rng As Range: Set rng = E.Range("C" & DR & ":C" & newRow)
    rng.FormatConditions.Delete
    With rng.FormatConditions.Add(xlCellValue, xlGreater, "0"): .Font.Color = RGB(0, 128, 0): End With
    With rng.FormatConditions.Add(xlCellValue, xlLess, "0"): .Font.Color = RGB(255, 0, 0): End With
    ' 3) advance the valuation date
    L.Range("B3").Value = newDate
    Application.Calculate: Application.ScreenUpdating = True
    MsgBox "Rolled to " & Format(newDate, "ddd dd-mmm-yyyy") & ". Prior row frozen as settled history.", vbInformation
End Sub

'====================== shared helpers ================================
Private Sub WriteTimeline(ws As Worksheet, r As Long, dt As Date, isLive As Boolean)
    If isLive Then
        ws.Cells(r, 1).Value = CDbl(dt): ws.Cells(r, 1).Font.Color = vbBlack: ws.Cells(r, 1).Font.Bold = True
    Else
        ws.Cells(r, 1).Value = CDbl(dt): ws.Cells(r, 1).Font.Color = cBlue
    End If
    ws.Cells(r, 1).NumberFormat = FDT: ws.Cells(r, 1).HorizontalAlignment = xlLeft
    Lbl ws, r, 2, Format(dt, "ddd"), False, xlCenter
    Calc ws, r, 3, "=WORKDAY(A" & r & ",1,Holidays)", FDT
    Calc ws, r, 4, "=WORKDAY(A" & r & ",2,Holidays)", FDT
    Calc ws, r, 5, "=WORKDAY(A" & r & ",3,Holidays)", FDT
    Calc ws, r, 6, "=IF(A" & r & ">=ValDate,""LIVE"",IF(E" & r & "<=ValDate,""Paid""," & _
        "IF(D" & r & "<=ValDate,""Invoiced"",IF(C" & r & "<=ValDate,""Delivered"",""Pending""))))", ""
    ws.Cells(r, 6).HorizontalAlignment = xlCenter
End Sub

Private Sub GenChains(ByRef beginV() As Double, ByRef endV() As Double)
    ReDim beginV(0 To HROWS - 1, 0 To NG - 1)
    ReDim endV(0 To HROWS - 1, 0 To NG - 1)
    Dim gi As Long, d As Long, target As Double, prevEnd As Double, nz As Double, mv As Double, k As Long
    For gi = 0 To NG - 1
        ' group target = sum of that group's tank NSV (numeric)
        target = 0
        For k = 1 To nTanks
            If rGroup(k) = gName(gi) Then
                Dim vcf As Double, nsv As Double
                vcf = 1 - rCoef(k) * (rTemp(k) - 60)
                nsv = (rGov(k) * vcf) * (1 - rBsw(k) / 100)
                target = target + nsv
            End If
        Next
        nz = IIf(InStr(gName(gi), "Crude") > 0 Or InStr(gName(gi), "Intermediate") > 0, 0.04, 0.03)
        prevEnd = target * RandR(0.9, 1.05)
        For d = 0 To HROWS - 1
            beginV(d, gi) = WorksheetFunction.Round(prevEnd, 0)
            mv = 0.12 * (target - prevEnd) + target * RandR(-nz, nz)
            prevEnd = WorksheetFunction.Max(target * 0.4, prevEnd + mv)
            endV(d, gi) = WorksheetFunction.Round(prevEnd, 0)
        Next
    Next
End Sub

Private Function NetLevel(gi As Long) As Double
    NetLevel = (gNative(gi) * gConv(gi) + gDiff(gi)) * gAdv(gi) + gTHB(gi)
End Function

Private Function RandR(lo As Double, hi As Double) As Double
    RandR = lo + (hi - lo) * Rnd
End Function

Private Function ColL(c As Long) As String
    ColL = Split(Cells(1, c).Address(True, False), "$")(0)
End Function

' ---- styling primitives ----
Private Sub Title(ws As Worksheet, r As Long, t As String, sz As Long)
    With ws.Cells(r, 1): .Value = t: .Font.Name = "Arial": .Font.Size = sz: .Font.Bold = True: End With
End Sub
Private Sub SubT(ws As Worksheet, r As Long, t As String)
    With ws.Cells(r, 1): .Value = t: .Font.Name = "Arial": .Font.Size = 9: .Font.Color = cGrey: End With
End Sub
Private Sub BandRow(ws As Worksheet, r As Long, c1 As Long, c2 As Long, t As String)
    With ws.Range(ws.Cells(r, c1), ws.Cells(r, c2))
        .Merge: .Value = t: .Fill.Color = cNavy: .Font.Color = vbWhite: .Font.Bold = True
        .Font.Name = "Arial": .Font.Size = 10: .HorizontalAlignment = xlCenter
        .VerticalAlignment = xlCenter: .WrapText = True: .Borders.LineStyle = xlContinuous
    End With
End Sub
Private Sub HdrRow(ws As Worksheet, r As Long, arr)
    Dim j As Long
    For j = 0 To UBound(arr): HdrCell ws, r, j + 1, CStr(arr(j)): Next
End Sub
Private Sub HdrCell(ws As Worksheet, r As Long, c As Long, t As String)
    With ws.Cells(r, c): .Value = t: .Fill.Color = cYellow: .Font.Bold = True: .Font.Name = "Arial"
        .Font.Size = 10: .HorizontalAlignment = xlCenter: .VerticalAlignment = xlCenter
        .WrapText = True: .Borders.LineStyle = xlContinuous: End With
End Sub
Private Sub Lbl(ws As Worksheet, r As Long, c As Long, v, bold As Boolean, ha As Long)
    With ws.Cells(r, c): .Value = v: .Font.Name = "Arial": .Font.Size = 10: .Font.Bold = bold
        .HorizontalAlignment = ha: .VerticalAlignment = xlCenter: End With
End Sub
Private Sub Inp(ws As Worksheet, r As Long, c As Long, v, nf As String)
    With ws.Cells(r, c): .Value = v: .Font.Color = cBlue: .Font.Name = "Arial": .Font.Size = 10
        If Len(nf) Then .NumberFormat = nf
        .HorizontalAlignment = xlRight: End With
End Sub
Private Sub InpF(ws As Worksheet, r As Long, c As Long, v, nf As String): Inp ws, r, c, v, nf: End Sub
Private Sub Calc(ws As Worksheet, r As Long, c As Long, f As String, nf As String)
    With ws.Cells(r, c): If Len(f) Then .Formula = f
        .Font.Color = vbBlack: .Font.Name = "Arial": .Font.Size = 10
        If Len(nf) Then .NumberFormat = nf
        .HorizontalAlignment = xlRight: End With
End Sub
Private Sub CalcF(ws As Worksheet, r As Long, c As Long, f As String, nf As String, isLive As Boolean)
    Calc ws, r, c, f, nf: If isLive Then ws.Cells(r, c).Fill.Color = cLive
End Sub
Private Sub Lnk(ws As Worksheet, r As Long, c As Long, f As String, nf As String)
    With ws.Cells(r, c): .Formula = f: .Font.Color = cGreen: .Font.Name = "Arial": .Font.Size = 10
        If Len(nf) Then .NumberFormat = nf
        .HorizontalAlignment = IIf(nf = FDT, xlCenter, xlRight): End With
End Sub
Private Sub LnkF(ws As Worksheet, r As Long, c As Long, f As String, nf As String, isLive As Boolean)
    Lnk ws, r, c, f, nf: If isLive Then ws.Cells(r, c).Fill.Color = cLive
End Sub
Private Sub HiliteRow(ws As Worksheet, r As Long, lastCol As Long)
    On Error Resume Next
    ws.Range(ws.Cells(r, 1), ws.Cells(r, lastCol)).Interior.Color = cLive
End Sub
Private Sub ClearHilite(ws As Worksheet, r As Long, lastCol As Long)
    On Error Resume Next
    ws.Range(ws.Cells(r, 1), ws.Cells(r, lastCol)).Interior.ColorIndex = xlNone
End Sub
Private Sub Borders(ws As Worksheet, r1 As Long, c1 As Long, r2 As Long, c2 As Long)
    With ws.Range(ws.Cells(r1, c1), ws.Cells(r2, c2)).Borders
        .LineStyle = xlContinuous: .Color = RGB(191, 191, 191): .Weight = xlThin
    End With
End Sub
Private Sub SetWidths(ws As Worksheet, arr)
    Dim j As Long
    For j = 0 To UBound(arr): ws.Columns(j + 1).ColumnWidth = arr(j): Next
End Sub
Private Sub Finish(ws As Worksheet, freezeCell As String, titleRows As String)
    ws.Activate: ActiveWindow.DisplayGridlines = False
    ws.Range(freezeCell).Select: ActiveWindow.FreezePanes = True
    On Error Resume Next: ws.PageSetup.PrintTitleRows = "'" & ws.Name & "'!" & titleRows: On Error GoTo 0
    ws.PageSetup.Orientation = xlLandscape: ws.PageSetup.Zoom = False
    ws.PageSetup.FitToPagesWide = 1: ws.PageSetup.FitToPagesTall = False
End Sub
