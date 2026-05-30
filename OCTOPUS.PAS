{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/physiq)
  @abstract(Target: Turbo Pascal 7 / Free Pascal 3.2 mode -Mtp)
  @description: Clone du langage d'entree Octopus (octopus-code.org).
                Interpreteur complet du parser d'entree Octopus :
                  - arithmetique complexe complete
                  - operateurs logiques et de comparaison
                  - toutes les fonctions mathematiques d'Octopus
                  - blocs %nom ... %  (matrices)
                  - directive "include"
                  - commentaires #
                  - variables predefinies (constantes physiques
                    en unites atomiques de Hartree)
                  - variables d'environnement $NOM ou via getenv("NOM")
                Usage : OCTOPUS [-q] [-e expr] [fichier.inp]
                        Sans argument : REPL interactif.
                Compilation :
                  fpc -Mtp OCTOPUS.PAS
                  ou Turbo Pascal 7 : TPC OCTOPUS.PAS
}

{$IFDEF FPC}
 {$MODE TP}
{$ENDIF}
{$R-}

Program OCTOPUS;

Uses Dos;

{ ============================================================
  CONSTANTES
  ============================================================ }

Const
 OCTOPUS_VERSION   = '1.00';
 OCTOPUS_DATE      = '2026';

 MAX_INCLUDE_DEPTH = 16;
 MAX_BLOCK_COLS    = 32;
 MAX_ARGS          = 16;
 MAX_LINE_LEN      = 255;

 OCT_PI            = 3.14159265358979;
 OCT_E             = 2.71828182845905;

{ ============================================================
  TYPES
  ============================================================ }

Type
 TFloat = Real;

 TComplex = Record
  re, im: TFloat;
 End;

 PBlockRow = ^TBlockRow;
 TBlockRow = Record
  ncols : Integer;
  cell  : Array[1..MAX_BLOCK_COLS] Of TComplex;
  next  : PBlockRow;
 End;

 TValueKind = (vkScalar, vkBlock);

 TValue = Record
  kind  : TValueKind;
  s     : TComplex;
  rows  : PBlockRow;
  nrows : Integer;
 End;

 PVarNode = ^TVarNode;
 TVarNode = Record
  name       : String;
  value      : TValue;
  predefined : Boolean;
  next       : PVarNode;
 End;

 PLineNode = ^TLineNode;
 TLineNode = Record
  txt  : String;
  num  : LongInt;
  next : PLineNode;
 End;

 TTokenKind = (
  tkEOF, tkEOL,
  tkNumber, tkIdent, tkString,
  tkPlus, tkMinus, tkStar, tkSlash, tkCaret,
  tkLParen, tkRParen, tkComma,
  tkLBrace, tkRBrace,
  tkAssign,
  tkLT, tkLE, tkGT, tkGE, tkEQ, tkNE,
  tkAnd, tkOr, tkNot,
  tkPercent, tkPipe
 );

 TToken = Record
  kind : TTokenKind;
  text : String;
  num  : TFloat;
  line : LongInt;
 End;

 TArgArray = Array[0..MAX_ARGS - 1] Of TComplex;

{ ============================================================
  ETAT GLOBAL
  ============================================================ }

Var
 { Liste chainee des variables }
 VarsHead     : PVarNode;
 NVars        : Integer;

 { Source courante : liste chainee de lignes, pointeur courant }
 SrcHead      : PLineNode;
 CurLine      : PLineNode;
 CurFile      : String;
 IncludeDepth : Integer;

 { Lexer : ligne courante en cours d'analyse }
 LexBuf       : String;
 LexPos       : Integer;
 LexLineNo    : LongInt;

 { Lookahead un token }
 HavePeek     : Boolean;
 PeekTok      : TToken;

 Quiet        : Boolean;
 ParseError   : Boolean;
 ParseErrMsg  : String;

{ ============================================================
  HELPERS STRING (TP n'a ni SysUtils ni AnsiString)
  ============================================================ }

Function LowerStr(Const S: String): String;
Var T: String;
    I: Integer;
Begin
 T := S;
 For I := 1 To Length(T) Do
  If (T[I] >= 'A') And (T[I] <= 'Z') Then
   T[I] := Chr(Ord(T[I]) + 32);
 LowerStr := T;
End;

Function TrimStr(Const S: String): String;
Var L, R: Integer;
Begin
 L := 1;
 R := Length(S);
 While (L <= R) And ((S[L] = ' ') Or (S[L] = #9)) Do Inc(L);
 While (R >= L) And ((S[R] = ' ') Or (S[R] = #9)) Do Dec(R);
 TrimStr := Copy(S, L, R - L + 1);
End;

Function IntStr(N: LongInt): String;
Var S: String;
Begin
 Str(N, S);
 IntStr := S;
End;

Function StrEqI(Const A, B: String): Boolean;
Begin
 StrEqI := LowerStr(A) = LowerStr(B);
End;

{ ============================================================
  HELPERS MATH (TP n'a pas Math)
  ============================================================ }

Function Sinh(X: TFloat): TFloat;
Var EP, EM: TFloat;
Begin
 EP := Exp(X);
 EM := Exp(-X);
 Sinh := (EP - EM) * 0.5;
End;

Function Cosh(X: TFloat): TFloat;
Var EP, EM: TFloat;
Begin
 EP := Exp(X);
 EM := Exp(-X);
 Cosh := (EP + EM) * 0.5;
End;

Function ArcTan2(Y, X: TFloat): TFloat;
Begin
 If X > 0 Then ArcTan2 := ArcTan(Y / X)
 Else If X < 0 Then Begin
  If Y >= 0 Then ArcTan2 := ArcTan(Y / X) + OCT_PI
  Else ArcTan2 := ArcTan(Y / X) - OCT_PI;
 End
 Else Begin
  If Y > 0 Then ArcTan2 := OCT_PI * 0.5
  Else If Y < 0 Then ArcTan2 := -OCT_PI * 0.5
  Else ArcTan2 := 0;
 End;
End;

Function FloorF(X: TFloat): TFloat;
Var IX: TFloat;
Begin
 IX := Int(X);
 If X >= 0 Then FloorF := IX
 Else Begin
  If IX = X Then FloorF := X
  Else FloorF := IX - 1;
 End;
End;

Function CeilF(X: TFloat): TFloat;
Var IX: TFloat;
Begin
 IX := Int(X);
 If X <= 0 Then CeilF := IX
 Else Begin
  If IX = X Then CeilF := X
  Else CeilF := IX + 1;
 End;
End;

{ ============================================================
  COMPLEX : OPERATIONS DE BASE
  ============================================================ }

Function CMake(R, I: TFloat): TComplex;
Begin
 CMake.re := R;
 CMake.im := I;
End;

Function CFromReal(R: TFloat): TComplex;
Begin
 CFromReal.re := R;
 CFromReal.im := 0;
End;

Function CIsReal(Z: TComplex): Boolean;
Begin
 CIsReal := Abs(Z.im) < 1E-12 * (1 + Abs(Z.re));
End;

Function CAdd(A, B: TComplex): TComplex;
Begin
 CAdd.re := A.re + B.re;
 CAdd.im := A.im + B.im;
End;

Function CSub(A, B: TComplex): TComplex;
Begin
 CSub.re := A.re - B.re;
 CSub.im := A.im - B.im;
End;

Function CNeg(A: TComplex): TComplex;
Begin
 CNeg.re := -A.re;
 CNeg.im := -A.im;
End;

Function CMul(A, B: TComplex): TComplex;
Begin
 CMul.re := A.re * B.re - A.im * B.im;
 CMul.im := A.re * B.im + A.im * B.re;
End;

Function CAbs(A: TComplex): TFloat;
Var X, Y, T: TFloat;
Begin
 X := Abs(A.re);
 Y := Abs(A.im);
 If (X = 0) And (Y = 0) Then Begin CAbs := 0; Exit; End;
 If X < Y Then Begin T := X; X := Y; Y := T; End;
 T := Y / X;
 CAbs := X * Sqrt(1 + T*T);
End;

Function CAbs2(A: TComplex): TFloat;
Begin
 CAbs2 := A.re*A.re + A.im*A.im;
End;

Function CDiv(A, B: TComplex): TComplex;
Var R, D: TFloat;
Begin
 If Abs(B.re) >= Abs(B.im) Then Begin
  R := B.im / B.re;
  D := B.re + R * B.im;
  CDiv.re := (A.re + R * A.im) / D;
  CDiv.im := (A.im - R * A.re) / D;
 End
 Else Begin
  R := B.re / B.im;
  D := B.im + R * B.re;
  CDiv.re := (A.re * R + A.im) / D;
  CDiv.im := (A.im * R - A.re) / D;
 End;
End;

Function CConj(A: TComplex): TComplex;
Begin
 CConj.re := A.re;
 CConj.im := -A.im;
End;

Function CArg(A: TComplex): TFloat;
Begin
 If (A.re = 0) And (A.im = 0) Then CArg := 0
 Else CArg := ArcTan2(A.im, A.re);
End;

Function CInv(A: TComplex): TComplex;
Var D: TFloat;
Begin
 D := A.re*A.re + A.im*A.im;
 CInv.re :=  A.re / D;
 CInv.im := -A.im / D;
End;

Function CExp(A: TComplex): TComplex;
Var E: TFloat;
Begin
 E := Exp(A.re);
 CExp.re := E * Cos(A.im);
 CExp.im := E * Sin(A.im);
End;

Function CLog(A: TComplex): TComplex;
Begin
 CLog.re := Ln(CAbs(A));
 CLog.im := CArg(A);
End;

Function CLogAbs(A: TComplex): TFloat;
Var X, Y, T: TFloat;
Begin
 X := Abs(A.re);
 Y := Abs(A.im);
 If X = 0 Then Begin CLogAbs := Ln(Y); Exit; End;
 If Y = 0 Then Begin CLogAbs := Ln(X); Exit; End;
 T := X*X + Y*Y;
 CLogAbs := 0.5 * Ln(T);
End;

Function CPow(A, B: TComplex): TComplex;
Var L, R: TComplex;
    IntE: LongInt;
    Z, Acc: TComplex;
    Neg: Boolean;
    N: LongInt;
Begin
 If (A.re = 0) And (A.im = 0) Then Begin
  If (B.re = 0) And (B.im = 0) Then CPow := CFromReal(1)
  Else CPow := CFromReal(0);
  Exit;
 End;
 { Exposant entier reel : exponentiation par carre }
 If CIsReal(B) Then Begin
  IntE := Round(B.re);
  If (Abs(B.re - IntE) < 1E-9) And (Abs(IntE) <= 64) Then Begin
   Neg := IntE < 0;
   If Neg Then N := -IntE Else N := IntE;
   Acc := CFromReal(1);
   Z := A;
   While N > 0 Do Begin
    If (N And 1) = 1 Then Acc := CMul(Acc, Z);
    Z := CMul(Z, Z);
    N := N Shr 1;
   End;
   If Neg Then Acc := CInv(Acc);
   CPow := Acc;
   Exit;
  End;
 End;
 { Cas general : exp(b * log(a)) }
 L := CLog(A);
 R := CMul(B, L);
 CPow := CExp(R);
End;

Function CSqrt(A: TComplex): TComplex;
Var R, W: TFloat;
Begin
 If (A.re = 0) And (A.im = 0) Then Begin
  CSqrt.re := 0; CSqrt.im := 0; Exit;
 End;
 R := CAbs(A);
 W := Sqrt((R + A.re) * 0.5);
 If W = 0 Then Begin
  CSqrt.re := 0;
  If A.im >= 0 Then CSqrt.im := Sqrt(R)
  Else CSqrt.im := -Sqrt(R);
 End
 Else Begin
  CSqrt.re := W;
  CSqrt.im := A.im / (2 * W);
 End;
End;

Function CSin(A: TComplex): TComplex;
Begin
 CSin.re := Sin(A.re) * Cosh(A.im);
 CSin.im := Cos(A.re) * Sinh(A.im);
End;

Function CCos(A: TComplex): TComplex;
Begin
 CCos.re :=  Cos(A.re) * Cosh(A.im);
 CCos.im := -Sin(A.re) * Sinh(A.im);
End;

Function CTan(A: TComplex): TComplex;
Var S, C: TComplex;
Begin
 S := CSin(A);
 C := CCos(A);
 CTan := CDiv(S, C);
End;

Function CCot(A: TComplex): TComplex;
Var S, C: TComplex;
Begin
 S := CSin(A);
 C := CCos(A);
 CCot := CDiv(C, S);
End;

Function CSec(A: TComplex): TComplex;
Var C: TComplex;
Begin
 C := CCos(A);
 CSec := CInv(C);
End;

Function CCsc(A: TComplex): TComplex;
Var S: TComplex;
Begin
 S := CSin(A);
 CCsc := CInv(S);
End;

Function CSinh(A: TComplex): TComplex;
Begin
 CSinh.re := Sinh(A.re) * Cos(A.im);
 CSinh.im := Cosh(A.re) * Sin(A.im);
End;

Function CCosh(A: TComplex): TComplex;
Begin
 CCosh.re := Cosh(A.re) * Cos(A.im);
 CCosh.im := Sinh(A.re) * Sin(A.im);
End;

Function CTanh(A: TComplex): TComplex;
Var S, C: TComplex;
Begin
 S := CSinh(A);
 C := CCosh(A);
 CTanh := CDiv(S, C);
End;

Function CCoth(A: TComplex): TComplex;
Var S, C: TComplex;
Begin
 S := CSinh(A);
 C := CCosh(A);
 CCoth := CDiv(C, S);
End;

Function CSech(A: TComplex): TComplex;
Var C: TComplex;
Begin
 C := CCosh(A);
 CSech := CInv(C);
End;

Function CCsch(A: TComplex): TComplex;
Var S: TComplex;
Begin
 S := CSinh(A);
 CCsch := CInv(S);
End;

Function CASin(A: TComplex): TComplex;
Var One, Z2, S, IZ, Sum, Lg, Iu: TComplex;
Begin
 One := CFromReal(1);
 Z2 := CMul(A, A);
 S := CSqrt(CSub(One, Z2));
 Iu := CMake(0, 1);
 IZ := CMul(Iu, A);
 Sum := CAdd(IZ, S);
 Lg := CLog(Sum);
 CASin := CMul(CMake(0, -1), Lg);
End;

Function CACos(A: TComplex): TComplex;
Var Pi2: TComplex;
Begin
 Pi2 := CFromReal(OCT_PI * 0.5);
 CACos := CSub(Pi2, CASin(A));
End;

Function CATan(A: TComplex): TComplex;
Var Iu, IZ, U, V, L: TComplex;
Begin
 Iu := CMake(0, 1);
 IZ := CMul(Iu, A);
 U := CSub(CFromReal(1), IZ);
 V := CAdd(CFromReal(1), IZ);
 L := CLog(CDiv(U, V));
 CATan := CMul(CMake(0, 0.5), L);
End;

Function CACot(A: TComplex): TComplex;
Var T: TComplex;
Begin
 If (A.re = 0) And (A.im = 0) Then Begin
  CACot := CFromReal(OCT_PI * 0.5);
  Exit;
 End;
 T := CInv(A);
 CACot := CATan(T);
End;

Function CASec(A: TComplex): TComplex;
Var T: TComplex;
Begin
 T := CInv(A);
 CASec := CACos(T);
End;

Function CACsc(A: TComplex): TComplex;
Var T: TComplex;
Begin
 T := CInv(A);
 CACsc := CASin(T);
End;

Function CASinh(A: TComplex): TComplex;
Var Z2, S: TComplex;
Begin
 Z2 := CMul(A, A);
 S := CSqrt(CAdd(Z2, CFromReal(1)));
 CASinh := CLog(CAdd(A, S));
End;

Function CACosh(A: TComplex): TComplex;
Var Z2, S: TComplex;
Begin
 Z2 := CMul(A, A);
 S := CSqrt(CSub(Z2, CFromReal(1)));
 CACosh := CLog(CAdd(A, S));
End;

Function CATanh(A: TComplex): TComplex;
Var U, V, Q, L, Half: TComplex;
Begin
 U := CAdd(CFromReal(1), A);
 V := CSub(CFromReal(1), A);
 Q := CDiv(U, V);
 L := CLog(Q);
 Half := CFromReal(0.5);
 CATanh := CMul(Half, L);
End;

Function CACoth(A: TComplex): TComplex;
Var T: TComplex;
Begin
 T := CInv(A);
 CACoth := CATanh(T);
End;

Function CASech(A: TComplex): TComplex;
Var T: TComplex;
Begin
 T := CInv(A);
 CASech := CACosh(T);
End;

Function CACsch(A: TComplex): TComplex;
Var T: TComplex;
Begin
 T := CInv(A);
 CACsch := CASinh(T);
End;

{ Fonction erreur reelle : Abramowitz & Stegun 7.1.26 (~1.5e-7) }
Function REerf(X: TFloat): TFloat;
Const
 A1 =  0.254829592;
 A2 = -0.284496736;
 A3 =  1.421413741;
 A4 = -1.453152027;
 A5 =  1.061405429;
 P5 =  0.3275911;
Var T, Y, Sgn: TFloat;
Begin
 If X < 0 Then Begin Sgn := -1; X := -X; End Else Sgn := 1;
 T := 1.0 / (1.0 + P5 * X);
 Y := 1.0 - (((((A5*T + A4)*T) + A3)*T + A2)*T + A1)*T*Exp(-X*X);
 REerf := Sgn * Y;
End;

Function CErf(A: TComplex): TComplex;
Var Z2, Term, Sum, Z: TComplex;
    K: LongInt;
    Fact, Coef: TFloat;
Begin
 If CIsReal(A) Then Begin
  CErf.re := REerf(A.re);
  CErf.im := 0;
  Exit;
 End;
 Z := A;
 Z2 := CMul(Z, Z);
 Sum := Z;
 Term := Z;
 Fact := 1;
 For K := 1 To 40 Do Begin
  Term := CMul(Term, Z2);
  Term := CMake(-Term.re, -Term.im);
  Fact := Fact * K;
  Coef := 1 / (Fact * (2*K + 1));
  Sum := CAdd(Sum, CMake(Term.re * Coef, Term.im * Coef));
  If (Abs(Term.re) + Abs(Term.im)) < 1E-14 Then Break;
 End;
 Coef := 2 / Sqrt(OCT_PI);
 CErf.re := Coef * Sum.re;
 CErf.im := Coef * Sum.im;
End;

{ ============================================================
  ERREURS
  ============================================================ }

Procedure RaiseErr(Const Msg: String);
Begin
 ParseError := True;
 ParseErrMsg := Msg;
 WriteLn('Erreur [', CurFile, ':', LexLineNo, '] : ', Msg);
End;

{ ============================================================
  TABLE DES VARIABLES (liste chainee)
  ============================================================ }

Function FindVar(Const Name: String): PVarNode;
Var P: PVarNode;
    Lo: String;
Begin
 Lo := LowerStr(Name);
 P := VarsHead;
 While P <> Nil Do Begin
  If LowerStr(P^.name) = Lo Then Begin
   FindVar := P;
   Exit;
  End;
  P := P^.next;
 End;
 FindVar := Nil;
End;

Procedure FreeBlockRows(R: PBlockRow);
Var N: PBlockRow;
Begin
 While R <> Nil Do Begin
  N := R^.next;
  Dispose(R);
  R := N;
 End;
End;

Procedure ClearValue(Var V: TValue);
Begin
 If V.kind = vkBlock Then FreeBlockRows(V.rows);
 V.kind := vkScalar;
 V.s := CFromReal(0);
 V.rows := Nil;
 V.nrows := 0;
End;

Function NewVar(Const Name: String): PVarNode;
Var P: PVarNode;
Begin
 New(P);
 P^.name := Name;
 P^.value.kind := vkScalar;
 P^.value.s := CFromReal(0);
 P^.value.rows := Nil;
 P^.value.nrows := 0;
 P^.predefined := False;
 P^.next := VarsHead;
 VarsHead := P;
 Inc(NVars);
 NewVar := P;
End;

Procedure SetScalar(Const Name: String; Z: TComplex; Pre: Boolean);
Var P: PVarNode;
Begin
 P := FindVar(Name);
 If P = Nil Then P := NewVar(Name);
 ClearValue(P^.value);
 P^.value.kind := vkScalar;
 P^.value.s := Z;
 P^.predefined := Pre;
End;

Procedure SetReal(Const Name: String; X: TFloat; Pre: Boolean);
Begin
 SetScalar(Name, CFromReal(X), Pre);
End;

{ ============================================================
  CONSTANTES PREDEFINIES (unites atomiques de Hartree)
  ============================================================ }

Procedure InitPredefined;
Var Iu: TComplex;
Begin
 SetReal('pi',          OCT_PI,                True);
 SetReal('e',           OCT_E,                 True);
 Iu := CMake(0, 1);
 SetScalar('i',         Iu,                    True);
 SetReal('false',       0,                     True);
 SetReal('no',          0,                     True);
 SetReal('true',        1,                     True);
 SetReal('yes',         1,                     True);

 SetReal('angstrom',    1.8897261328856432,    True);
 SetReal('pm',          0.018897261328856432,  True);
 SetReal('picometer',   0.018897261328856432,  True);
 SetReal('nm',          18.897261328856432,    True);
 SetReal('nanometer',   18.897261328856432,    True);

 SetReal('ry',          0.5,                   True);
 SetReal('rydberg',     0.5,                   True);
 SetReal('ev',          0.03674932539796232,   True);
 SetReal('electronvolt',0.03674932539796232,   True);
 SetReal('invcm',       4.5563353E-06,         True);
 SetReal('kelvin',      3.1668105E-06,         True);
 SetReal('kjoule_mol',  0.00038087988,         True);
 SetReal('kcal_mol',    0.0015936014,          True);

 SetReal('as',          0.0413413737896,       True);
 SetReal('attosecond',  0.0413413737896,       True);
 SetReal('fs',          41.3413737896,         True);
 SetReal('femtosecond', 41.3413737896,         True);
 SetReal('ps',          41341.3737896,         True);
 SetReal('picosecond',  41341.3737896,         True);

 SetReal('c',           137.035999139,         True);
End;

{ ============================================================
  LEXER
  ============================================================ }

Function IsAlphaC(C: Char): Boolean;
Begin
 IsAlphaC := ((C >= 'A') And (C <= 'Z')) Or
             ((C >= 'a') And (C <= 'z')) Or (C = '_');
End;

Function IsDigitC(C: Char): Boolean;
Begin
 IsDigitC := (C >= '0') And (C <= '9');
End;

Function IsAlNumC(C: Char): Boolean;
Begin
 IsAlNumC := IsAlphaC(C) Or IsDigitC(C);
End;

Procedure SkipSpaces;
Begin
 While (LexPos <= Length(LexBuf)) And
       ((LexBuf[LexPos] = ' ') Or (LexBuf[LexPos] = #9)) Do
  Inc(LexPos);
End;

Function PeekCh: Char;
Begin
 If LexPos > Length(LexBuf) Then PeekCh := #0
 Else PeekCh := LexBuf[LexPos];
End;

Function PeekCh2: Char;
Begin
 If LexPos + 1 > Length(LexBuf) Then PeekCh2 := #0
 Else PeekCh2 := LexBuf[LexPos + 1];
End;

Procedure MakeTok(Var T: TToken; K: TTokenKind; Const S: String);
Begin
 T.kind := K;
 T.text := S;
 T.num  := 0;
 T.line := LexLineNo;
End;

Function LexNext: TToken;
Var Start: Integer;
    S: String;
    Code: Integer;
    C: Char;
    T: TToken;
Begin
 SkipSpaces;
 T.line := LexLineNo;
 T.kind := tkEOL;
 T.text := '';
 T.num  := 0;
 If LexPos > Length(LexBuf) Then Begin
  LexNext := T;
  Exit;
 End;
 C := LexBuf[LexPos];

 { Commentaire # : avale jusqu'a fin de ligne }
 If C = '#' Then Begin
  LexPos := Length(LexBuf) + 1;
  LexNext := T;
  Exit;
 End;

 { Nombres }
 If IsDigitC(C) Or ((C = '.') And IsDigitC(PeekCh2)) Then Begin
  Start := LexPos;
  While (LexPos <= Length(LexBuf)) And IsDigitC(LexBuf[LexPos]) Do
   Inc(LexPos);
  If (LexPos <= Length(LexBuf)) And (LexBuf[LexPos] = '.') Then Begin
   Inc(LexPos);
   While (LexPos <= Length(LexBuf)) And IsDigitC(LexBuf[LexPos]) Do
    Inc(LexPos);
  End;
  If (LexPos <= Length(LexBuf)) And
     ((LexBuf[LexPos] = 'e') Or (LexBuf[LexPos] = 'E')) Then Begin
   Inc(LexPos);
   If (LexPos <= Length(LexBuf)) And
      ((LexBuf[LexPos] = '+') Or (LexBuf[LexPos] = '-')) Then
    Inc(LexPos);
   While (LexPos <= Length(LexBuf)) And IsDigitC(LexBuf[LexPos]) Do
    Inc(LexPos);
  End;
  S := Copy(LexBuf, Start, LexPos - Start);
  MakeTok(T, tkNumber, S);
  Val(S, T.num, Code);
  If Code <> 0 Then RaiseErr('Nombre invalide : ' + S);
  LexNext := T;
  Exit;
 End;

 { Identifiants }
 If IsAlphaC(C) Then Begin
  Start := LexPos;
  While (LexPos <= Length(LexBuf)) And IsAlNumC(LexBuf[LexPos]) Do
   Inc(LexPos);
  S := Copy(LexBuf, Start, LexPos - Start);
  MakeTok(T, tkIdent, S);
  LexNext := T;
  Exit;
 End;

 { Variable d'environnement $NOM }
 If C = '$' Then Begin
  Inc(LexPos);
  Start := LexPos;
  While (LexPos <= Length(LexBuf)) And IsAlNumC(LexBuf[LexPos]) Do
   Inc(LexPos);
  S := Copy(LexBuf, Start, LexPos - Start);
  MakeTok(T, tkIdent, '$' + S);
  LexNext := T;
  Exit;
 End;

 { Chaine "..." ou '...' }
 If (C = '"') Or (C = '''') Then Begin
  Inc(LexPos);
  Start := LexPos;
  While (LexPos <= Length(LexBuf)) And (LexBuf[LexPos] <> C) Do
   Inc(LexPos);
  S := Copy(LexBuf, Start, LexPos - Start);
  If (LexPos <= Length(LexBuf)) And (LexBuf[LexPos] = C) Then
   Inc(LexPos);
  MakeTok(T, tkString, S);
  LexNext := T;
  Exit;
 End;

 Case C Of
  '+': Begin Inc(LexPos); MakeTok(T, tkPlus, '+'); LexNext := T; Exit; End;
  '-': Begin Inc(LexPos); MakeTok(T, tkMinus, '-'); LexNext := T; Exit; End;
  '*': Begin Inc(LexPos); MakeTok(T, tkStar, '*'); LexNext := T; Exit; End;
  '/': Begin Inc(LexPos); MakeTok(T, tkSlash, '/'); LexNext := T; Exit; End;
  '^': Begin Inc(LexPos); MakeTok(T, tkCaret, '^'); LexNext := T; Exit; End;
  '(': Begin Inc(LexPos); MakeTok(T, tkLParen, '('); LexNext := T; Exit; End;
  ')': Begin Inc(LexPos); MakeTok(T, tkRParen, ')'); LexNext := T; Exit; End;
  ',': Begin Inc(LexPos); MakeTok(T, tkComma, ','); LexNext := T; Exit; End;
  '{': Begin Inc(LexPos); MakeTok(T, tkLBrace, '{'); LexNext := T; Exit; End;
  '}': Begin Inc(LexPos); MakeTok(T, tkRBrace, '}'); LexNext := T; Exit; End;
  '|': Begin
   Inc(LexPos);
   If PeekCh = '|' Then Begin
    Inc(LexPos); MakeTok(T, tkOr, '||');
   End Else MakeTok(T, tkPipe, '|');
   LexNext := T; Exit;
  End;
  '&': Begin
   Inc(LexPos);
   If PeekCh = '&' Then Begin
    Inc(LexPos); MakeTok(T, tkAnd, '&&');
   End Else Begin
    RaiseErr('Operateur ''&'' isole (utiliser ''&&'')');
    MakeTok(T, tkEOL, '');
   End;
   LexNext := T; Exit;
  End;
  '=': Begin
   Inc(LexPos);
   If PeekCh = '=' Then Begin
    Inc(LexPos); MakeTok(T, tkEQ, '==');
   End Else MakeTok(T, tkAssign, '=');
   LexNext := T; Exit;
  End;
  '!': Begin
   Inc(LexPos);
   If PeekCh = '=' Then Begin
    Inc(LexPos); MakeTok(T, tkNE, '!=');
   End Else MakeTok(T, tkNot, '!');
   LexNext := T; Exit;
  End;
  '<': Begin
   Inc(LexPos);
   If PeekCh = '=' Then Begin
    Inc(LexPos); MakeTok(T, tkLE, '<=');
   End Else MakeTok(T, tkLT, '<');
   LexNext := T; Exit;
  End;
  '>': Begin
   Inc(LexPos);
   If PeekCh = '=' Then Begin
    Inc(LexPos); MakeTok(T, tkGE, '>=');
   End Else MakeTok(T, tkGT, '>');
   LexNext := T; Exit;
  End;
  '%': Begin Inc(LexPos); MakeTok(T, tkPercent, '%'); LexNext := T; Exit; End;
 End;

 RaiseErr('Caractere invalide : ''' + C + '''');
 Inc(LexPos);
 MakeTok(T, tkEOL, '');
 LexNext := T;
End;

Procedure LexInitLine(Const S: String; LN: LongInt);
Begin
 LexBuf := S;
 LexPos := 1;
 LexLineNo := LN;
 HavePeek := False;
End;

Function NextTok: TToken;
Begin
 If HavePeek Then Begin
  NextTok := PeekTok;
  HavePeek := False;
 End
 Else NextTok := LexNext;
End;

Function PeekTokF: TToken;
Begin
 If Not HavePeek Then Begin
  PeekTok := LexNext;
  HavePeek := True;
 End;
 PeekTokF := PeekTok;
End;

{ ============================================================
  PARSER D'EXPRESSIONS
  Grammaire (precedence basse -> haute, EBNF simplifie) :
    expr     -> orexpr
    orexpr   -> andexpr   then ( OR andexpr ) repete
    andexpr  -> cmpexpr   then ( AND cmpexpr ) repete
    cmpexpr  -> addexpr   then ( CMPOP addexpr ) optionnel
    addexpr  -> mulexpr   then ( ADDOP mulexpr ) repete
    mulexpr  -> powexpr   then ( MULOP powexpr ) repete
    powexpr  -> unary     then ( CARET powexpr ) optionnel
    unary    -> ( MINUS | PLUS | NOT ) unary | primary
    primary  -> number | LPAREN expr RPAREN
              | LBRACE expr COMMA expr RBRACE
              | ident | ident LPAREN args RPAREN
  ============================================================ }

Function ParseExpr: TComplex; Forward;
Function ParseUnary: TComplex; Forward;

Function CmpEq(A, B: TComplex): Boolean;
Begin
 CmpEq := (Abs(A.re - B.re) < 1E-9) And (Abs(A.im - B.im) < 1E-9);
End;

Function ToBool(A: TComplex): Boolean;
Begin
 ToBool := (Abs(A.re) > 1E-12) Or (Abs(A.im) > 1E-12);
End;

Function FromBool(B: Boolean): TComplex;
Begin
 If B Then FromBool := CFromReal(1) Else FromBool := CFromReal(0);
End;

Function GetEnvVarStr(Const Name: String): String;
Begin
 GetEnvVarStr := GetEnv(Name);
End;

Function ParseArgs(Var Args: TArgArray; MaxN: Integer): Integer;
Var N: Integer;
    T: TToken;
Begin
 N := 0;
 T := PeekTokF;
 If T.kind = tkRParen Then Begin
  ParseArgs := 0;
  Exit;
 End;
 Repeat
  If N >= MaxN Then Begin
   RaiseErr('Trop d''arguments');
   ParseArgs := N;
   Exit;
  End;
  Args[N] := ParseExpr;
  Inc(N);
  T := PeekTokF;
  If T.kind = tkComma Then T := NextTok
  Else Break;
 Until False;
 ParseArgs := N;
End;

Function CallBuiltin(Const Name: String;
                     Var Args: TArgArray;
                     N: Integer;
                     Var Found: Boolean): TComplex;
Var Lo: String;
    A, U, V: TComplex;
Begin
 Lo := LowerStr(Name);
 Found := True;
 CallBuiltin := CFromReal(0);

 If N = 1 Then Begin
  A := Args[0];
  If Lo = 'sqrt'     Then Begin CallBuiltin := CSqrt(A); Exit; End;
  If Lo = 'exp'      Then Begin CallBuiltin := CExp(A); Exit; End;
  If (Lo = 'log') Or (Lo = 'ln') Then Begin CallBuiltin := CLog(A); Exit; End;
  If Lo = 'log10' Then Begin
   U := CLog(A);
   V := CFromReal(1/Ln(10));
   CallBuiltin := CMul(U, V); Exit;
  End;
  If Lo = 'arg'      Then Begin CallBuiltin := CFromReal(CArg(A)); Exit; End;
  If Lo = 'abs'      Then Begin CallBuiltin := CFromReal(CAbs(A)); Exit; End;
  If Lo = 'abs2'     Then Begin CallBuiltin := CFromReal(CAbs2(A)); Exit; End;
  If Lo = 'logabs'   Then Begin CallBuiltin := CFromReal(CLogAbs(A)); Exit; End;
  If Lo = 'conjg'    Then Begin CallBuiltin := CConj(A); Exit; End;
  If Lo = 'inv'      Then Begin CallBuiltin := CInv(A); Exit; End;
  If Lo = 'sin'      Then Begin CallBuiltin := CSin(A); Exit; End;
  If Lo = 'cos'      Then Begin CallBuiltin := CCos(A); Exit; End;
  If Lo = 'tan'      Then Begin CallBuiltin := CTan(A); Exit; End;
  If Lo = 'cot'      Then Begin CallBuiltin := CCot(A); Exit; End;
  If Lo = 'sec'      Then Begin CallBuiltin := CSec(A); Exit; End;
  If Lo = 'csc'      Then Begin CallBuiltin := CCsc(A); Exit; End;
  If Lo = 'asin'     Then Begin CallBuiltin := CASin(A); Exit; End;
  If Lo = 'acos'     Then Begin CallBuiltin := CACos(A); Exit; End;
  If Lo = 'atan'     Then Begin CallBuiltin := CATan(A); Exit; End;
  If Lo = 'acot'     Then Begin CallBuiltin := CACot(A); Exit; End;
  If Lo = 'asec'     Then Begin CallBuiltin := CASec(A); Exit; End;
  If Lo = 'acsc'     Then Begin CallBuiltin := CACsc(A); Exit; End;
  If Lo = 'sinh'     Then Begin CallBuiltin := CSinh(A); Exit; End;
  If Lo = 'cosh'     Then Begin CallBuiltin := CCosh(A); Exit; End;
  If Lo = 'tanh'     Then Begin CallBuiltin := CTanh(A); Exit; End;
  If Lo = 'coth'     Then Begin CallBuiltin := CCoth(A); Exit; End;
  If Lo = 'sech'     Then Begin CallBuiltin := CSech(A); Exit; End;
  If Lo = 'csch'     Then Begin CallBuiltin := CCsch(A); Exit; End;
  If Lo = 'asinh'    Then Begin CallBuiltin := CASinh(A); Exit; End;
  If Lo = 'acosh'    Then Begin CallBuiltin := CACosh(A); Exit; End;
  If Lo = 'atanh'    Then Begin CallBuiltin := CATanh(A); Exit; End;
  If Lo = 'acoth'    Then Begin CallBuiltin := CACoth(A); Exit; End;
  If Lo = 'asech'    Then Begin CallBuiltin := CASech(A); Exit; End;
  If Lo = 'acsch'    Then Begin CallBuiltin := CACsch(A); Exit; End;
  If Lo = 'step' Then Begin
   If A.re > 0 Then CallBuiltin := CFromReal(1)
   Else If A.re < 0 Then CallBuiltin := CFromReal(0)
   Else CallBuiltin := CFromReal(0.5);
   Exit;
  End;
  If Lo = 'erf'      Then Begin CallBuiltin := CErf(A); Exit; End;
  If Lo = 'realpart' Then Begin CallBuiltin := CFromReal(A.re); Exit; End;
  If Lo = 'imagpart' Then Begin CallBuiltin := CFromReal(A.im); Exit; End;
  If Lo = 'floor'    Then Begin CallBuiltin := CFromReal(FloorF(A.re)); Exit; End;
  If Lo = 'ceiling'  Then Begin CallBuiltin := CFromReal(CeilF(A.re)); Exit; End;
 End;

 If N = 2 Then Begin
  If Lo = 'logb' Then Begin
   U := CLog(Args[0]);
   V := CLog(Args[1]);
   CallBuiltin := CDiv(U, V); Exit;
  End;
  If Lo = 'atan2' Then Begin
   CallBuiltin := CFromReal(ArcTan2(Args[1].re, Args[0].re)); Exit;
  End;
  If Lo = 'min' Then Begin
   If Args[0].re <= Args[1].re Then CallBuiltin := Args[0]
   Else CallBuiltin := Args[1];
   Exit;
  End;
  If Lo = 'max' Then Begin
   If Args[0].re >= Args[1].re Then CallBuiltin := Args[0]
   Else CallBuiltin := Args[1];
   Exit;
  End;
 End;

 Found := False;
End;

Function GetVarScalar(Const Name: String; Var OK: Boolean): TComplex;
Var P: PVarNode;
Begin
 OK := False;
 GetVarScalar := CFromReal(0);
 P := FindVar(Name);
 If P = Nil Then Exit;
 If P^.value.kind <> vkScalar Then Exit;
 GetVarScalar := P^.value.s;
 OK := True;
End;

Function ParseStringTok: String;
Var T: TToken;
Begin
 T := NextTok;
 If T.kind <> tkString Then Begin
  RaiseErr('Chaine attendue');
  ParseStringTok := '';
  Exit;
 End;
 ParseStringTok := T.text;
End;

Function ParsePrimary: TComplex;
Var T, T2: TToken;
    Re, Im: TComplex;
    Args: TArgArray;
    N: Integer;
    Found, OK: Boolean;
    Name, EnvName, EnvVal: String;
    R: TFloat;
    Code: Integer;
Begin
 T := NextTok;
 ParsePrimary := CFromReal(0);
 Case T.kind Of
  tkNumber: Begin
   ParsePrimary := CFromReal(T.num);
   Exit;
  End;
  tkLParen: Begin
   ParsePrimary := ParseExpr;
   T := NextTok;
   If T.kind <> tkRParen Then RaiseErr('")" attendu');
   Exit;
  End;
  tkLBrace: Begin
   Re := ParseExpr;
   T := NextTok;
   If T.kind <> tkComma Then RaiseErr('"," attendu dans {x,y}');
   Im := ParseExpr;
   T := NextTok;
   If T.kind <> tkRBrace Then RaiseErr('"}" attendu');
   ParsePrimary := CMake(Re.re, Im.re);
   Exit;
  End;
  tkIdent: Begin
   Name := T.text;
   If (Length(Name) > 0) And (Name[1] = '$') Then Begin
    EnvName := Copy(Name, 2, Length(Name) - 1);
    EnvVal := GetEnvVarStr(EnvName);
    Val(EnvVal, R, Code);
    If Code = 0 Then ParsePrimary := CFromReal(R)
    Else ParsePrimary := CFromReal(0);
    Exit;
   End;
   T2 := PeekTokF;
   If T2.kind = tkLParen Then Begin
    T2 := NextTok;
    If LowerStr(Name) = 'getenv' Then Begin
     EnvName := ParseStringTok;
     T2 := NextTok;
     If T2.kind <> tkRParen Then RaiseErr('")" attendu apres getenv');
     EnvVal := GetEnvVarStr(EnvName);
     Val(EnvVal, R, Code);
     If Code = 0 Then ParsePrimary := CFromReal(R)
     Else ParsePrimary := CFromReal(0);
     Exit;
    End;
    N := ParseArgs(Args, MAX_ARGS);
    T2 := NextTok;
    If T2.kind <> tkRParen Then RaiseErr('")" attendu apres arguments');
    ParsePrimary := CallBuiltin(Name, Args, N, Found);
    If Not Found Then
     RaiseErr('Fonction inconnue ou mauvais nombre d''arguments : ' + Name);
    Exit;
   End;
   ParsePrimary := GetVarScalar(Name, OK);
   If Not OK Then RaiseErr('Variable non definie : ' + Name);
   Exit;
  End;
 End;
 RaiseErr('Expression attendue (token : ' + T.text + ')');
End;

Function ParseUnary: TComplex;
Var T: TToken;
    V: TComplex;
Begin
 T := PeekTokF;
 If T.kind = tkMinus Then Begin
  T := NextTok;
  V := ParseUnary;
  ParseUnary := CNeg(V);
  Exit;
 End;
 If T.kind = tkPlus Then Begin
  T := NextTok;
  V := ParseUnary;
  ParseUnary := V;
  Exit;
 End;
 If T.kind = tkNot Then Begin
  T := NextTok;
  V := ParseUnary;
  ParseUnary := FromBool(Not ToBool(V));
  Exit;
 End;
 ParseUnary := ParsePrimary;
End;

Function ParsePow: TComplex;
Var L, R: TComplex;
    T: TToken;
Begin
 L := ParseUnary;
 T := PeekTokF;
 If T.kind = tkCaret Then Begin
  T := NextTok;
  R := ParsePow;
  ParsePow := CPow(L, R);
  Exit;
 End;
 ParsePow := L;
End;

Function ParseMul: TComplex;
Var L, R: TComplex;
    T: TToken;
Begin
 L := ParsePow;
 Repeat
  T := PeekTokF;
  If T.kind = tkStar Then Begin
   T := NextTok;
   R := ParsePow;
   L := CMul(L, R);
  End
  Else If T.kind = tkSlash Then Begin
   T := NextTok;
   R := ParsePow;
   L := CDiv(L, R);
  End
  Else Break;
 Until False;
 ParseMul := L;
End;

Function ParseAdd: TComplex;
Var L, R: TComplex;
    T: TToken;
Begin
 L := ParseMul;
 Repeat
  T := PeekTokF;
  If T.kind = tkPlus Then Begin
   T := NextTok;
   R := ParseMul;
   L := CAdd(L, R);
  End
  Else If T.kind = tkMinus Then Begin
   T := NextTok;
   R := ParseMul;
   L := CSub(L, R);
  End
  Else Break;
 Until False;
 ParseAdd := L;
End;

Function ParseCmp: TComplex;
Var L, R: TComplex;
    T: TToken;
    K: TTokenKind;
Begin
 L := ParseAdd;
 T := PeekTokF;
 If (T.kind = tkLT) Or (T.kind = tkLE) Or (T.kind = tkGT) Or
    (T.kind = tkGE) Or (T.kind = tkEQ) Or (T.kind = tkNE) Then Begin
  K := T.kind;
  T := NextTok;
  R := ParseAdd;
  Case K Of
   tkLT: ParseCmp := FromBool(L.re <  R.re);
   tkLE: ParseCmp := FromBool(L.re <= R.re);
   tkGT: ParseCmp := FromBool(L.re >  R.re);
   tkGE: ParseCmp := FromBool(L.re >= R.re);
   tkEQ: ParseCmp := FromBool(CmpEq(L, R));
   tkNE: ParseCmp := FromBool(Not CmpEq(L, R));
  End;
  Exit;
 End;
 ParseCmp := L;
End;

Function ParseAnd: TComplex;
Var L, R: TComplex;
    T: TToken;
Begin
 L := ParseCmp;
 Repeat
  T := PeekTokF;
  If T.kind = tkAnd Then Begin
   T := NextTok;
   R := ParseCmp;
   L := FromBool(ToBool(L) And ToBool(R));
  End
  Else Break;
 Until False;
 ParseAnd := L;
End;

Function ParseOr: TComplex;
Var L, R: TComplex;
    T: TToken;
Begin
 L := ParseAnd;
 Repeat
  T := PeekTokF;
  If T.kind = tkOr Then Begin
   T := NextTok;
   R := ParseAnd;
   L := FromBool(ToBool(L) Or ToBool(R));
  End
  Else Break;
 Until False;
 ParseOr := L;
End;

Function ParseExpr: TComplex;
Begin
 ParseExpr := ParseOr;
End;

{ ============================================================
  AFFICHAGE
  ============================================================ }

Function FormatFloat10(X: TFloat): String;
Var S: String;
Begin
 Str(X:0:10, S);
 FormatFloat10 := S;
End;

Function FormatComplex(Z: TComplex): String;
Var Re, AbsIm, Im: String;
Begin
 If CIsReal(Z) Then FormatComplex := FormatFloat10(Z.re)
 Else Begin
  Re := FormatFloat10(Z.re);
  AbsIm := FormatFloat10(Abs(Z.im));
  If Z.im >= 0 Then Im := ' + ' + AbsIm + 'i'
  Else Im := ' - ' + AbsIm + 'i';
  FormatComplex := '{' + Re + ',' + Im + '}';
 End;
End;

Procedure PrintValue(Const Name: String; Const V: TValue);
Var R: PBlockRow;
    I, J: Integer;
Begin
 If V.kind = vkScalar Then
  WriteLn(Name, ' = ', FormatComplex(V.s))
 Else Begin
  WriteLn('Bloc ', Name, ' (', V.nrows, ' lignes) :');
  R := V.rows;
  I := 0;
  While R <> Nil Do Begin
   Inc(I);
   Write('  [', I, '] ');
   For J := 1 To R^.ncols Do Begin
    If J > 1 Then Write(' | ');
    Write(FormatComplex(R^.cell[J]));
   End;
   WriteLn;
   R := R^.next;
  End;
 End;
End;

{ ============================================================
  LECTURE DE FICHIER : liste chainee
  ============================================================ }

Function LoadFileList(Const Fn: String; Var Head: PLineNode): Boolean;
Var F: Text;
    L: String;
    LineNo: LongInt;
    N, Tail: PLineNode;
Begin
 Head := Nil;
 Tail := Nil;
 LineNo := 0;
 Assign(F, Fn);
 {$I-} Reset(F); {$I+}
 If IOResult <> 0 Then Begin
  WriteLn('Erreur : impossible d''ouvrir ', Fn);
  LoadFileList := False;
  Exit;
 End;
 While Not Eof(F) Do Begin
  ReadLn(F, L);
  Inc(LineNo);
  New(N);
  N^.txt := L;
  N^.num := LineNo;
  N^.next := Nil;
  If Head = Nil Then Head := N Else Tail^.next := N;
  Tail := N;
 End;
 Close(F);
 LoadFileList := True;
End;

Procedure FreeLineList(Var Head: PLineNode);
Var N: PLineNode;
Begin
 While Head <> Nil Do Begin
  N := Head^.next;
  Dispose(Head);
  Head := N;
 End;
End;

{ ============================================================
  EVALUATION DE STATEMENTS
  ============================================================ }

Procedure EvalCurrentList; Forward;

Procedure DoInclude(Const Fn: String);
Var SavedHead, SavedCur: PLineNode;
    SavedFile: String;
    NewHead: PLineNode;
Begin
 If IncludeDepth >= MAX_INCLUDE_DEPTH Then Begin
  RaiseErr('Profondeur d''inclusion maximale atteinte');
  Exit;
 End;
 If Not LoadFileList(Fn, NewHead) Then Exit;
 SavedHead := SrcHead;
 SavedCur := CurLine;
 SavedFile := CurFile;

 SrcHead := NewHead;
 CurLine := NewHead;
 CurFile := Fn;
 Inc(IncludeDepth);
 EvalCurrentList;
 Dec(IncludeDepth);

 FreeLineList(NewHead);
 SrcHead := SavedHead;
 CurLine := SavedCur;
 CurFile := SavedFile;
End;

{ Parse une ligne de bloc : expr | expr | expr ...
  Retourne le nombre de cellules lues dans Row^. }
Function ParseBlockRowLine(Row: PBlockRow): Integer;
Var N: Integer;
    T: TToken;
    V: TComplex;
Begin
 N := 0;
 Repeat
  T := PeekTokF;
  If T.kind = tkEOL Then Break;
  If T.kind = tkString Then Begin
   T := NextTok;
   V := CFromReal(0);
  End
  Else Begin
   V := ParseExpr;
   If ParseError Then Break;
  End;
  If N >= MAX_BLOCK_COLS Then Begin
   RaiseErr('Trop de colonnes dans bloc (max ' + IntStr(MAX_BLOCK_COLS) + ')');
   Break;
  End;
  Inc(N);
  Row^.cell[N] := V;
  T := PeekTokF;
  If T.kind = tkPipe Then T := NextTok
  Else Break;
 Until False;
 Row^.ncols := N;
 ParseBlockRowLine := N;
End;

{ Lit le contenu d'un bloc et l'assigne. Avance CurLine. }
Procedure EvalBlock(Const BlockName: String);
Var Head, Tail, Row: PBlockRow;
    NRows: Integer;
    T: TToken;
    EndFound: Boolean;
    P: PVarNode;
Begin
 Head := Nil;
 Tail := Nil;
 NRows := 0;
 EndFound := False;

 While (Not EndFound) And (CurLine <> Nil) Do Begin
  LexInitLine(CurLine^.txt, CurLine^.num);
  CurLine := CurLine^.next;

  T := PeekTokF;
  If T.kind = tkEOL Then Continue;

  { Fin de bloc : '%' isole ou '%' suivi du nom }
  If T.kind = tkPercent Then Begin
   T := NextTok;
   EndFound := True;
   Continue;
  End;

  New(Row);
  Row^.ncols := 0;
  Row^.next := Nil;
  If ParseBlockRowLine(Row) > 0 Then Begin
   If Head = Nil Then Head := Row Else Tail^.next := Row;
   Tail := Row;
   Inc(NRows);
  End
  Else Dispose(Row);

  If ParseError Then Exit;
 End;

 { Stockage }
 P := FindVar(BlockName);
 If P = Nil Then P := NewVar(BlockName);
 ClearValue(P^.value);
 P^.value.kind := vkBlock;
 P^.value.rows := Head;
 P^.value.nrows := NRows;
 P^.predefined := False;

 If Not Quiet Then
  WriteLn('Bloc ', BlockName, ' : ', NRows, ' ligne(s)');
End;

Procedure EvalStatement;
Var T, T2: TToken;
    Name, Fn: String;
    V: TComplex;
    P: PVarNode;
Begin
 T := PeekTokF;
 If T.kind = tkEOL Then Exit;

 { Bloc : %nom ... % }
 If T.kind = tkPercent Then Begin
  T := NextTok;
  T := NextTok;
  If T.kind <> tkIdent Then Begin
   RaiseErr('Nom de bloc attendu apres ''%''');
   Exit;
  End;
  Name := T.text;
  EvalBlock(Name);
  Exit;
 End;

 If T.kind <> tkIdent Then Begin
  RaiseErr('Identifiant ou ''%'' attendu');
  Exit;
 End;

 If StrEqI(T.text, 'include') Then Begin
  T := NextTok;
  T := NextTok;
  If T.kind <> tkString Then Begin
   RaiseErr('Chaine attendue apres include');
   Exit;
  End;
  Fn := T.text;
  DoInclude(Fn);
  Exit;
 End;

 If StrEqI(T.text, 'print') Then Begin
  T := NextTok;
  V := ParseExpr;
  If Not ParseError Then WriteLn(FormatComplex(V));
  Exit;
 End;

 If StrEqI(T.text, 'show') Then Begin
  T := NextTok;
  T := NextTok;
  If T.kind <> tkIdent Then Begin
   RaiseErr('Nom de variable attendu apres show');
   Exit;
  End;
  P := FindVar(T.text);
  If P = Nil Then WriteLn('(non defini) ', T.text)
  Else PrintValue(P^.name, P^.value);
  Exit;
 End;

 If StrEqI(T.text, 'quit') Or StrEqI(T.text, 'exit') Then Begin
  T := NextTok;
  Halt(0);
 End;

 If StrEqI(T.text, 'list') Then Begin
  T := NextTok;
  P := VarsHead;
  While P <> Nil Do Begin
   If Not P^.predefined Then PrintValue(P^.name, P^.value);
   P := P^.next;
  End;
  Exit;
 End;

 { Affectation : ident = expr }
 T := NextTok;
 Name := T.text;
 T2 := NextTok;
 If T2.kind <> tkAssign Then Begin
  RaiseErr('"=" attendu apres ' + Name);
  Exit;
 End;
 V := ParseExpr;
 If ParseError Then Exit;
 SetScalar(Name, V, False);
 If Not Quiet Then
  WriteLn(Name, ' = ', FormatComplex(V));
End;

Procedure EvalCurrentList;
Begin
 While (CurLine <> Nil) And (Not ParseError) Do Begin
  LexInitLine(CurLine^.txt, CurLine^.num);
  CurLine := CurLine^.next;
  EvalStatement;
 End;
End;

Procedure EvalFile(Const Fn: String);
Var Head: PLineNode;
Begin
 If Not LoadFileList(Fn, Head) Then Exit;
 SrcHead := Head;
 CurLine := Head;
 CurFile := Fn;
 EvalCurrentList;
 FreeLineList(Head);
 SrcHead := Nil;
 CurLine := Nil;
End;

Procedure EvalSingleLine(Const L: String);
Var N: PLineNode;
Begin
 New(N);
 N^.txt := L;
 N^.num := 1;
 N^.next := Nil;
 SrcHead := N;
 CurLine := N;
 CurFile := '<stdin>';
 EvalCurrentList;
 Dispose(N);
 SrcHead := Nil;
 CurLine := Nil;
End;

{ ============================================================
  REPL
  ============================================================ }

Procedure Repl;
Var Line: String;
Begin
 WriteLn('Octopus parser ', OCTOPUS_VERSION, ' (', OCTOPUS_DATE, ')');
 WriteLn('Tapez ''quit'' pour sortir, ''list'' pour les variables.');
 WriteLn('''show NOM'' affiche, ''print EXPR'' evalue.');
 WriteLn;
 While True Do Begin
  Write('octopus> ');
  ReadLn(Line);
  If Eof Then Begin WriteLn; Halt(0); End;
  ParseError := False;
  EvalSingleLine(Line);
 End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }

Procedure ShowUsage;
Begin
 WriteLn('OCTOPUS : Cette commande permet de l''analyseur d''entr‚e Octopus.');
 WriteLn;
 WriteLn('Syntaxe : OCTOPUS [-q] [-e "expr"] [fichier.inp ...]');
 WriteLn;
 WriteLn('  -q             mode silencieux');
 WriteLn('  -e "expr"      evalue une expression et affiche');
 WriteLn('  fichier.inp    execute un script Octopus');
 WriteLn('  (sans arg)     REPL interactif');
End;

Var
 I       : Integer;
 Arg     : String;
 GotFile : Boolean;

BEGIN
 VarsHead := Nil;
 NVars := 0;
 SrcHead := Nil;
 CurLine := Nil;
 CurFile := '<init>';
 IncludeDepth := 0;
 Quiet := False;
 ParseError := False;
 HavePeek := False;

 InitPredefined;

 GotFile := False;
 I := 1;
 While I <= ParamCount Do Begin
  Arg := ParamStr(I);
  If (Arg = '-q') Or (Arg = '--quiet') Then Quiet := True
  Else If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Then Begin
   ShowUsage;
   Halt(0);
  End
  Else If Arg = '-e' Then Begin
   Inc(I);
   If I > ParamCount Then Begin
    WriteLn('Erreur : -e attend une expression');
    Halt(1);
   End;
   ParseError := False;
   EvalSingleLine('print ' + ParamStr(I));
   GotFile := True;
  End
  Else Begin
   EvalFile(Arg);
   GotFile := True;
  End;
  Inc(I);
 End;

 If Not GotFile Then Repl;

 If ParseError Then Halt(1);
END.
