Attribute VB_Name = "SettlementReconciliation"
'==============================================================================
' SettlementReconciliation
'------------------------------------------------------------------------------
' Physical-gas pipeline delivery reconciliation engine.
' Implements the worked example in Appendix A of the Energy Settlements
' Delivery Workflow: reconcile book / pipeline-allocation / counterparty
' volumes on a (gas_day, contract, point) key, attribute any break to a
' scheduling cut vs an allocation variance, test for a pipeline imbalance,
' and restate the cash impact at Gas Daily + basis.
'
' Authoritative-source hierarchy (Section 3):
'   Tier 1 facts : pipeline allocation = truth for delivered volume
'   Tier 1 rules : citygate sale settles on ALLOCATED qty, not nominated qty
'
' Design choices that match the prompt's operating principles:
'   1. Anchor the concrete fact first -> AnchorAndValidate() enforces a single
'      unit (Dth) and a consistent gas-day key before any math runs.
'   5. Show the calculation        -> every variance column is stored, not just
'      the headline break.
'   6. Rank break hypotheses       -> ClassifyBreak() returns an ordered root
'      cause + the single confirming check.
'
' Usage:
'   1. Import this .bas into the VBA editor (Alt+F11 > File > Import File).
'   2. Tools > References > tick "Microsoft Scripting Runtime" (or rely on the
'      late-bound CreateObject calls below - no reference needed).
'   3. Put the three Tier-1 extracts on sheets named exactly:
'        "book"         book.csv         (delivered_dth, invoiced_dth)
'        "pipeline"     pipeline.csv     (sched_timely/final, allocated, receipt)
'        "counterparty" counterparty.csv (confirmed_dth)
'        "index"        index_prices.csv (index_price, basis, is_final)  [optional]
'      Each sheet: row 1 = headers exactly as in the CSVs in /sample-data.
'   4. Run RunReconciliation. Output lands on a fresh "Reconciliation" sheet.
'==============================================================================
Option Explicit

' ---- Tunable controls -------------------------------------------------------
Private Const EXPECTED_UNIT As String = "Dth"   ' Principle 1: one unit, stated
Private Const MATERIALITY_DTH As Double = 0      ' daily volume: any break shown
Private Const KEY_SEP As String = "|"

' ---- Per-source unit-of-record + sign convention (Principle 1 & 4) ----------
' DECLARED_UNIT_* is used ONLY when a source has no per-row "units" column.
' Leave blank to force a UNIT_UNKNOWN flag rather than assume a unit.
' SIGN_* canonicalizes a feed whose stored values run opposite to "delivered
' volume is positive" (e.g. an invoice that stores absolute magnitudes, or a
' ledger that signs a sale negative). Set to -1 to flip a known-inverted feed.
Private Const DECLARED_UNIT_BOOK As String = "Dth"
Private Const DECLARED_UNIT_PIPE As String = "Dth"
Private Const DECLARED_UNIT_CP   As String = "Dth"
Private Const SIGN_BOOK As Double = 1#
Private Const SIGN_PIPE As Double = 1#
Private Const SIGN_CP   As Double = 1#

' ---- Sheet names ------------------------------------------------------------
Private Const SH_BOOK As String = "book"
Private Const SH_PIPE As String = "pipeline"
Private Const SH_CP As String = "counterparty"
Private Const SH_IDX As String = "index"
Private Const SH_OUT As String = "Reconciliation"

'==============================================================================
' Entry point
'==============================================================================
Public Sub RunReconciliation()
    Dim t0 As Double: t0 = Timer
    On Error GoTo Fail

    ' --- Stage 1 anchor: load + validate units and key before any reasoning ---
    Dim book As Object, pipe As Object, cp As Object, idx As Object
    Set book = LoadSheet(SH_BOOK)
    Set pipe = LoadSheet(SH_PIPE)
    Set cp = LoadSheet(SH_CP)
    Set idx = LoadSheetOptional(SH_IDX)

    AnchorAndValidate book, SH_BOOK
    AnchorAndValidate pipe, SH_PIPE
    AnchorAndValidate cp, SH_CP

    ' --- Build the union of keys across all three Tier-1 sources -------------
    Dim keys As Object: Set keys = CreateObject("Scripting.Dictionary")
    CollectKeys book, keys
    CollectKeys pipe, keys
    CollectKeys cp, keys

    ' --- Prepare output sheet ------------------------------------------------
    Dim ws As Worksheet: Set ws = FreshSheet(SH_OUT)
    WriteHeader ws

    Dim r As Long: r = 2
    Dim k As Variant
    For Each k In keys.keys
        WriteReconRow ws, r, CStr(k), book, pipe, cp, idx
        r = r + 1
    Next k

    FormatOutput ws, r - 1
    ws.Activate
    MsgBox "Reconciliation complete: " & (r - 2) & " keys in " & _
           Format(Timer - t0, "0.00") & "s." & vbCrLf & _
           "Truth for delivered volume = pipeline ALLOCATED qty.", _
           vbInformation, "Energy Settlements Toolkit"
    Exit Sub
Fail:
    MsgBox "Reconciliation failed: " & Err.Description, vbCritical, "Error " & Err.Number
End Sub

'==============================================================================
' Per-key reconciliation -> one Excel-transferable record per row
'==============================================================================
Private Sub WriteReconRow(ws As Worksheet, ByVal r As Long, ByVal key As String, _
                          book As Object, pipe As Object, cp As Object, idx As Object)
    Dim parts() As String: parts = Split(key, KEY_SEP)
    Dim gasDay As String, contract As String, point As String
    gasDay = parts(0): contract = parts(1): point = parts(2)

    ' --- Pull values: sign-canonicalized + converted to canonical Dth --------
    ' (Principle 1) Each volume is normalized BEFORE differencing so a unit or
    ' sign mismatch cannot masquerade as an economic break.
    Dim bookDel As Double, bookInv As Double
    Dim schedTimely As Double, schedFinal As Double, alloc As Double
    Dim recvFinal As Double, recvAlloc As Double, cpConf As Double
    Dim cutReason As String, allocMethod As String
    Dim dq As String                              ' data-quality flag accumulator

    bookDel = CanonDth(book, key, "delivered_dth", DECLARED_UNIT_BOOK, SIGN_BOOK, dq, "book")
    bookInv = CanonDth(book, key, "invoiced_dth", DECLARED_UNIT_BOOK, SIGN_BOOK, dq, "book.invoiced")
    schedTimely = CanonDth(pipe, key, "sched_timely_dth", DECLARED_UNIT_PIPE, SIGN_PIPE, dq, "pipe")
    schedFinal = CanonDth(pipe, key, "sched_final_dth", DECLARED_UNIT_PIPE, SIGN_PIPE, dq, "pipe")
    alloc = CanonDth(pipe, key, "allocated_dth", DECLARED_UNIT_PIPE, SIGN_PIPE, dq, "pipe")
    recvFinal = CanonDth(pipe, key, "receipt_sched_final_dth", DECLARED_UNIT_PIPE, SIGN_PIPE, dq, "pipe")
    recvAlloc = CanonDth(pipe, key, "receipt_allocated_dth", DECLARED_UNIT_PIPE, SIGN_PIPE, dq, "pipe")
    cpConf = CanonDth(cp, key, "confirmed_dth", DECLARED_UNIT_CP, SIGN_CP, dq, "cp")
    cutReason = Txt(pipe, key, "cut_reason")
    allocMethod = Txt(pipe, key, "alloc_method")

    ' --- Artifact guards: rule out a unit or sign error before economics ------
    ' Run on the CANONICALIZED book vs allocation (the values that feed the
    ' break). A correctly labeled therms->Dth conversion that ties will NOT fire;
    ' an unknown/mis-declared unit that leaves a ~10:1 gap WILL. Guards never
    ' auto-correct -- they flag for the analyst to resolve first.
    AppendFlag dq, DetectSignInversion(bookDel, alloc)
    AppendFlag dq, DetectUnitMismatch(bookDel, alloc)

    ' --- Stage 4 logic: decompose the break (Principle 5: show the math) -----
    Dim cutDth As Double, allocVar As Double, totalBreak As Double
    Dim cpVar As Double, netImbalance As Double
    cutDth = schedTimely - schedFinal          ' nomination cut, Timely -> Final
    allocVar = schedFinal - alloc              ' scheduled vs allocated at point
    totalBreak = bookDel - alloc               ' book truth-gap vs allocation
    cpVar = alloc - cpConf                     ' allocation vs counterparty stmt
    netImbalance = recvAlloc - alloc           ' receipts vs deliveries (path)

    ' --- Classify + cash impact ---------------------------------------------
    Dim status As String, rootCause As String, confirmCheck As String
    ClassifyBreak totalBreak, cutDth, allocVar, cpVar, netImbalance, _
                  cutReason, status, rootCause, confirmCheck

    ' A data-quality flag outranks an economic verdict: a "break" that is really
    ' a unit/sign artifact must not be settled as economics (Principle 1).
    If dq <> "" Then
        status = "REVIEW DATA QUALITY"
        confirmCheck = "Resolve unit/sign flag first; the volume break may be an artifact"
    End If
    If dq = "" Then dq = "clean (Dth, sign canonical)"

    Dim priceFinal As Boolean, allInPrice As Double, cashDelta As Double
    allInPrice = Num(idx, gasDay & KEY_SEP & point, "index_price") _
                 + Num(idx, gasDay & KEY_SEP & point, "basis")
    priceFinal = (UCase(Txt(idx, gasDay & KEY_SEP & point, "is_final")) = "Y")
    cashDelta = totalBreak * allInPrice        ' +ve = over-invoiced, owed back

    ' --- Emit (column order matches /powerbi + /alteryx output schema) -------
    With ws
        .Cells(r, 1) = gasDay
        .Cells(r, 2) = contract
        .Cells(r, 3) = point
        .Cells(r, 4) = bookDel
        .Cells(r, 5) = schedTimely
        .Cells(r, 6) = schedFinal
        .Cells(r, 7) = alloc
        .Cells(r, 8) = cpConf
        .Cells(r, 9) = cutDth
        .Cells(r, 10) = allocVar
        .Cells(r, 11) = totalBreak
        .Cells(r, 12) = netImbalance
        .Cells(r, 13) = EXPECTED_UNIT
        .Cells(r, 14) = status
        .Cells(r, 15) = rootCause
        .Cells(r, 16) = confirmCheck
        .Cells(r, 17) = IIf(priceFinal, allInPrice, allInPrice)
        .Cells(r, 18) = IIf(priceFinal, "Final", "PRELIMINARY")
        .Cells(r, 19) = cashDelta
        .Cells(r, 20) = IIf(allocMethod = "", "n/a", allocMethod)
        .Cells(r, 21) = dq
    End With
End Sub

'==============================================================================
' Sign-canonicalize + convert a volume to canonical Dth, accumulating any
' data-quality flag. Unknown unit -> value passed through and source flagged.
'==============================================================================
Private Function CanonDth(data As Object, ByVal key As String, ByVal col As String, _
                          ByVal declaredUnit As String, ByVal signConv As Double, _
                          ByRef dq As String, ByVal srcTag As String) As Double
    Dim raw As Double: raw = Num(data, key, col) * signConv
    Dim effUnit As String
    effUnit = ResolveUnit(Txt(data, key, "units"), declaredUnit)
    If effUnit = "" Then
        AppendFlag dq, "UNIT_UNKNOWN (" & srcTag & "." & col & "): no row unit and no declared unit"
        CanonDth = raw
        Exit Function
    End If
    Dim ok As Boolean
    CanonDth = ToDth(raw, effUnit, ok)
    If Not ok Then
        AppendFlag dq, "UNIT_UNCONVERTIBLE (" & srcTag & ": '" & effUnit & _
                       "' needs heat content / out of scope)"
    End If
End Function

Private Sub AppendFlag(ByRef dq As String, ByVal flag As String)
    If flag = "" Then Exit Sub
    If InStr(1, dq, flag) > 0 Then Exit Sub        ' de-dupe repeated source flags
    If dq <> "" Then dq = dq & "  ||  "
    dq = dq & flag
End Sub

'==============================================================================
' Break classification (Principle 6: ranked cause + single confirming check)
'==============================================================================
Private Sub ClassifyBreak(ByVal totalBreak As Double, ByVal cutDth As Double, _
                          ByVal allocVar As Double, ByVal cpVar As Double, _
                          ByVal netImbalance As Double, ByVal cutReason As String, _
                          ByRef status As String, ByRef rootCause As String, _
                          ByRef confirmCheck As String)
    If Abs(totalBreak) <= MATERIALITY_DTH And Abs(cpVar) <= MATERIALITY_DTH Then
        status = "TIE"
        rootCause = "Book = allocation = counterparty"
        confirmCheck = "None - settle as invoiced"
        Exit Sub
    End If

    status = "BREAK"
    ' Rank the components by magnitude and name the dominant driver first.
    If Abs(cutDth) >= Abs(allocVar) And cutDth <> 0 Then
        rootCause = "Uncaptured scheduling cut " & Format(cutDth, "#,##0") & _
                    " Dth (book stored Timely nomination, not final scheduled)"
        If cutReason <> "" Then rootCause = rootCause & " [" & cutReason & "]"
        confirmCheck = "Confirm cut hit BOTH receipt+delivery legs (else imbalance); " & _
                       "confirm 1,800 is daily-equivalent, not an hourly partial-day rate"
    ElseIf allocVar <> 0 Then
        rootCause = "Allocation variance " & Format(allocVar, "#,##0") & _
                    " Dth (final scheduled vs pool allocation)"
        confirmCheck = "Confirm pool allocation method (ranked vs pro-rata) and OBA"
    ElseIf cpVar <> 0 Then
        rootCause = "Counterparty statement disagrees with pipeline allocation " & _
                    Format(cpVar, "#,##0") & " Dth"
        confirmCheck = "Pipeline allocation is Tier-1 truth; dispute CP statement"
    Else
        rootCause = "Book vs allocation gap with no scheduled-cycle attribution"
        confirmCheck = "Pull scheduled-by-cycle detail to locate the cut cycle"
    End If

    If Abs(netImbalance) > MATERIALITY_DTH Then
        rootCause = rootCause & "  ||  NET IMBALANCE " & Format(netImbalance, "#,##0") & _
                    " Dth (cut did NOT hit both legs evenly)"
    End If
End Sub

'==============================================================================
' Stage-1 anchor: enforce a single unit and a real gas-day key.
' Most breaks are a unit or timing mismatch, not real economics (Principle 1).
'==============================================================================
Private Sub AnchorAndValidate(data As Object, ByVal sheetName As String)
    ' Hard stop on the TIMING anchor (an unparseable gas day is unambiguous and
    ' poisons the key). Units are handled downstream by CanonDth, which converts
    ' what it can and FLAGS what it can't -- it never assumes Dth (Principle 4).
    Dim hasUnits As Boolean: hasUnits = data("__cols").Exists("units")
    If Not hasUnits Then
        Debug.Print "ANCHOR WARNING: sheet '" & sheetName & "' has no 'units' column; " & _
            "rows will use the source's DECLARED_UNIT_* or be flagged UNIT_UNKNOWN."
    End If
    Dim k As Variant
    For Each k In data.keys
        If Left(k, 2) <> "__" Then
            Dim gd As String: gd = Split(CStr(k), KEY_SEP)(0)
            If Not IsDate(gd) Then
                Err.Raise vbObjectError + 1, , "Sheet '" & sheetName & _
                    "': gas_day '" & gd & "' is not a valid date. Anchor the gas-day " & _
                    "boundary (09:00-09:00 CT) before reconciling."
            End If
        End If
    Next k
End Sub

'==============================================================================
' Loaders -- build dict: key "gasday|contract|point" -> dict colname -> value
' Special entry "__cols" holds the set of column names present.
'==============================================================================
Private Function LoadSheet(ByVal sheetName As String) As Object
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets(sheetName)
    On Error GoTo 0
    If ws Is Nothing Then Err.Raise vbObjectError + 3, , _
        "Required sheet '" & sheetName & "' not found."
    Set LoadSheet = LoadFromWs(ws)
End Function

Private Function LoadSheetOptional(ByVal sheetName As String) As Object
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Worksheets(sheetName)
    On Error GoTo 0
    If ws Is Nothing Then
        Set LoadSheetOptional = CreateObject("Scripting.Dictionary")
        LoadSheetOptional.Add "__cols", CreateObject("Scripting.Dictionary")
    Else
        Set LoadSheetOptional = LoadFromWs(ws)
    End If
End Function

Private Function LoadFromWs(ws As Worksheet) As Object
    Dim d As Object: Set d = CreateObject("Scripting.Dictionary")
    Dim cols As Object: Set cols = CreateObject("Scripting.Dictionary")
    Dim lastRow As Long, lastCol As Long, i As Long, j As Long
    lastRow = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row
    lastCol = ws.Cells(1, ws.Columns.Count).End(xlToLeft).Column

    Dim header() As String: ReDim header(1 To lastCol)
    For j = 1 To lastCol
        header(j) = Trim(LCase(CStr(ws.Cells(1, j).Value)))
        cols(header(j)) = True
    Next j

    Dim cG As Long, cC As Long, cP As Long
    cG = ColOf(header, "gas_day"): cC = ColOf(header, "contract"): cP = ColOf(header, "point")

    For i = 2 To lastRow
        If Len(Trim(CStr(ws.Cells(i, 1).Value))) > 0 Then
            Dim key As String
            key = NormDate(ws.Cells(i, cG).Value) & KEY_SEP & _
                  Trim(CStr(ws.Cells(i, cC).Value)) & KEY_SEP & _
                  Trim(CStr(ws.Cells(i, cP).Value))
            Dim rowD As Object: Set rowD = CreateObject("Scripting.Dictionary")
            For j = 1 To lastCol
                rowD(header(j)) = ws.Cells(i, j).Value
            Next j
            d(key) = rowD
        End If
    Next i
    d.Add "__cols", cols
    Set LoadFromWs = d
End Function

'==============================================================================
' Helpers
'==============================================================================
Private Sub CollectKeys(data As Object, keys As Object)
    Dim k As Variant
    For Each k In data.keys
        If Left(k, 2) <> "__" Then keys(k) = True
    Next k
End Sub

Private Function Num(data As Object, ByVal key As String, ByVal col As String) As Double
    Num = 0
    If data Is Nothing Then Exit Function
    If Not data.Exists(key) Then Exit Function
    Dim row As Object: Set row = data(key)
    If row.Exists(col) Then
        If IsNumeric(row(col)) Then Num = CDbl(row(col))
    End If
End Function

Private Function Txt(data As Object, ByVal key As String, ByVal col As String) As String
    Txt = ""
    If data Is Nothing Then Exit Function
    If Not data.Exists(key) Then Exit Function
    Dim row As Object: Set row = data(key)
    If row.Exists(col) Then Txt = Trim(CStr(row(col)))
End Function

Private Function ColOf(header() As String, ByVal name As String) As Long
    Dim j As Long
    For j = LBound(header) To UBound(header)
        If header(j) = name Then ColOf = j: Exit Function
    Next j
    Err.Raise vbObjectError + 4, , "Required column '" & name & "' missing."
End Function

Private Function NormDate(ByVal v As Variant) As String
    If IsDate(v) Then
        NormDate = Format(CDate(v), "yyyy-mm-dd")
    Else
        NormDate = Trim(CStr(v))
    End If
End Function

Private Function FreshSheet(ByVal nm As String) As Worksheet
    Dim ws As Worksheet
    On Error Resume Next
    Application.DisplayAlerts = False
    ThisWorkbook.Worksheets(nm).Delete
    Application.DisplayAlerts = True
    On Error GoTo 0
    Set ws = ThisWorkbook.Worksheets.Add(After:=ThisWorkbook.Worksheets(ThisWorkbook.Worksheets.Count))
    ws.Name = nm
    Set FreshSheet = ws
End Function

Private Sub WriteHeader(ws As Worksheet)
    Dim h As Variant
    h = Array("Gas Day", "Contract", "Point", "Book Dth", "Sched Timely", _
              "Sched Final", "Allocated", "CP Confirmed", "Cut Dth", "Alloc Var", _
              "Total Break", "Net Imbalance", "Units", "Status", "Root Cause", _
              "Confirming Check", "All-in Price", "Price Status", "Cash Delta USD", _
              "Alloc Method", "Data Quality Flag")
    Dim j As Long
    For j = 0 To UBound(h)
        ws.Cells(1, j + 1) = h(j)
    Next j
End Sub

Private Sub FormatOutput(ws As Worksheet, ByVal lastRow As Long)
    With ws.Range(ws.Cells(1, 1), ws.Cells(1, 21))
        .Font.Bold = True
        .Interior.Color = RGB(31, 78, 121)
        .Font.Color = RGB(255, 255, 255)
    End With
    ws.Range("D2:L" & lastRow).NumberFormat = "#,##0"
    ws.Range("Q2:Q" & lastRow).NumberFormat = "0.0000"
    ws.Range("S2:S" & lastRow).NumberFormat = "#,##0.00;[Red](#,##0.00)"
    ws.Columns.AutoFit

    ' Conditional shading: BREAK rows red, TIE rows green (Stage-5 reviewability)
    Dim i As Long
    For i = 2 To lastRow
        Dim c As Long
        If InStr(1, ws.Cells(i, 14).Value, "REVIEW DATA QUALITY") > 0 Then
            ' amber: a unit/sign artifact outranks the economic verdict
            For c = 1 To 21: ws.Cells(i, c).Interior.Color = RGB(255, 235, 156): Next c
        ElseIf InStr(1, ws.Cells(i, 14).Value, "BREAK") > 0 Then
            For c = 1 To 21: ws.Cells(i, c).Interior.Color = RGB(252, 228, 214): Next c
        ElseIf ws.Cells(i, 14).Value = "TIE" Then
            ws.Cells(i, 14).Interior.Color = RGB(226, 239, 218)
        End If
    Next i
    ws.Rows(1).RowHeight = 28
    ws.Range("A1").Select
    ActiveWindow.FreezePanes = False
    ws.Activate
    ActiveWindow.SplitRow = 1
    ActiveWindow.FreezePanes = True
End Sub
