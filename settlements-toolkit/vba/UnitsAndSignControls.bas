Attribute VB_Name = "UnitsAndSignControls"
'==============================================================================
' UnitsAndSignControls
'------------------------------------------------------------------------------
' Two pre-reconciliation guards that stop the most common false breaks BEFORE
' any economic difference is declared (Operating Principle 1: anchor the
' concrete fact first; most breaks are a unit or timing mismatch).
'
'   A. Unit normalization  -- convert every volume to one energy basis (Dth).
'      Never assume a unit. A source with no unit identifier uses its DECLARED
'      unit; if that is blank too, the row is flagged UNIT_UNKNOWN and a ratio
'      diagnostic is emitted instead of a fabricated Dth assumption (Principle 4).
'
'   B. Sign canonicalization + inversion detector -- correct a known opposite
'      convention at load; when the convention is undeclared, detect the
'      "equal magnitude, opposite sign" signature so an inverted absolute value
'      is never netted into a phantom break and Abs() never hides a real one.
'
' Canonical energy basis: 1 Dth = 1 MMBtu = 10 therms = 1,000,000 Btu.
'==============================================================================
Option Explicit

Public Const CANON_UNIT As String = "Dth"
Private Const REL_TOL As Double = 0.01      ' 1% tolerance for ratio / magnitude tests

'------------------------------------------------------------------------------
' A. Unit conversion to canonical Dth.
' Returns the multiplier to Dth, or -1 if the unit is unknown / unconvertible
' (Mcf, MWh, MBtu, etc. need heat content or are out of scope -> never guessed).
'------------------------------------------------------------------------------
Public Function UnitFactorToDth(ByVal rawUnit As String) As Double
    Dim u As String: u = UCase(Trim(rawUnit))
    u = Replace(Replace(u, ".", ""), "/", "")
    Select Case u
        Case "DTH", "DEKATHERM", "DEKATHERMS", "MMBTU", "MMBTUS"
            UnitFactorToDth = 1#
        Case "THERM", "THERMS", "THM"
            UnitFactorToDth = 0.1
        Case "BTU", "BTUS"
            UnitFactorToDth = 0.000001
        Case "GJ", "GIGAJOULE", "GIGAJOULES"
            UnitFactorToDth = 0.947817          ' 1 GJ = 0.947817 MMBtu
        Case Else
            ' MBTU (thousand vs million ambiguity), MCF / MMCF (need Btu content),
            ' MWH (power), blank, or anything unrecognized -> UNKNOWN, do not guess.
            UnitFactorToDth = -1#
    End Select
End Function

' Resolve the effective unit for a value: prefer the row's units column,
' fall back to the source's declared unit, else blank (=unknown).
Public Function ResolveUnit(ByVal rowUnit As String, ByVal declaredUnit As String) As String
    If Trim(rowUnit) <> "" Then
        ResolveUnit = Trim(rowUnit)
    Else
        ResolveUnit = Trim(declaredUnit)
    End If
End Function

' Convert a value to Dth. ok=False when the unit is unknown/unconvertible;
' the caller then flags rather than trusting the (unconverted) number.
Public Function ToDth(ByVal value As Double, ByVal effUnit As String, ByRef ok As Boolean) As Double
    Dim f As Double: f = UnitFactorToDth(effUnit)
    If f < 0 Then
        ok = False
        ToDth = value            ' pass through unconverted; row will be flagged
    Else
        ok = True
        ToDth = value * f
    End If
End Function

'------------------------------------------------------------------------------
' Unit-mismatch fingerprint: when two volumes that should tie differ, test
' whether their raw ratio matches a known unit conversion. A ~10x or ~0.1x gap
' is therms<->Dth, not missing gas. Returns a diagnostic, or "" if no fingerprint.
'------------------------------------------------------------------------------
Public Function DetectUnitMismatch(ByVal a As Double, ByVal b As Double) As String
    If a = 0 Or b = 0 Then Exit Function
    Dim r As Double: r = a / b
    DetectUnitMismatch = RatioFingerprint(r)
End Function

Private Function RatioFingerprint(ByVal r As Double) As String
    Dim ar As Double: ar = Abs(r)
    If Near(ar, 10#) Then
        RatioFingerprint = "SUSPECTED UNIT MISMATCH: ratio ~10:1 (therms reported as Dth?)"
    ElseIf Near(ar, 0.1) Then
        RatioFingerprint = "SUSPECTED UNIT MISMATCH: ratio ~1:10 (Dth reported as therms?)"
    ElseIf Near(ar, 1000#) Then
        RatioFingerprint = "SUSPECTED UNIT MISMATCH: ratio ~1000:1 (MMBtu vs Btu, or Dth vs MBtu?)"
    ElseIf Near(ar, 0.001) Then
        RatioFingerprint = "SUSPECTED UNIT MISMATCH: ratio ~1:1000 (Btu vs MMBtu?)"
    Else
        ' Deliberately no ~1.0-1.04 "Mcf" band: a small volumetric/heat-content
        ' gap is indistinguishable by ratio from a normal allocation variance, so
        ' claiming it would false-flag real breaks. Mcf is caught by its UNIT
        ' LABEL instead (UnitFactorToDth returns -1 -> UNIT_UNCONVERTIBLE).
        RatioFingerprint = ""
    End If
End Function

'------------------------------------------------------------------------------
' B. Sign-inversion detector. Two volumes that should be equal but carry
' opposite signs of near-equal magnitude => one system inverted its convention.
' This is the signature that a naive a-b turns into a doubled phantom break and
' that Abs() would silently swallow.
'------------------------------------------------------------------------------
Public Function DetectSignInversion(ByVal a As Double, ByVal b As Double) As String
    If a = 0 Or b = 0 Then Exit Function
    If Sgn(a) = Sgn(b) Then Exit Function          ' same direction, not inverted
    ' opposite signs: is it equal-and-opposite (inversion) or genuinely different?
    If Near(Abs(a), Abs(b)) Then
        DetectSignInversion = "SUSPECTED SIGN INVERSION: equal magnitude, opposite sign " & _
            "(" & Format(a, "#,##0") & " vs " & Format(b, "#,##0") & ") - " & _
            "canonicalize sign before differencing; do NOT Abs() it away"
    Else
        DetectSignInversion = "SIGN DISAGREEMENT: opposite signs, unequal magnitude " & _
            "(" & Format(a, "#,##0") & " vs " & Format(b, "#,##0") & ") - real directional break"
    End If
End Function

Private Function Near(ByVal x As Double, ByVal target As Double) As Boolean
    If target = 0 Then
        Near = (Abs(x) <= REL_TOL)
    Else
        Near = (Abs(x - target) / Abs(target) <= REL_TOL)
    End If
End Function
