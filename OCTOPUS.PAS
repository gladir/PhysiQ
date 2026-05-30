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
                  Turbo Pascal 7 : TPC OCTOPUS.PAS
                  Free Pascal    : fpc -Mtp OCTOPUS.PAS

                NOTE : en Turbo Pascal 7, une fonction ne peut PAS retourner
                un type Record. Toutes les operations sur TComplex et TToken
                sont donc declarees comme Procedure avec un parametre Var
                de sortie.
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
 VarsHead     : PVarNode;
 NVars        : Integer;

 SrcHead      : PLineNode;
 CurLine      : PLineNode;
 CurFile      : String;
 IncludeDepth : Integer;

 LexBuf       : String;
 LexPos       : Integer;
 LexLineNo    : LongInt;

 HavePeek     : Boolean;
 PeekTok      : TToken;

 Quiet        : Boolean;
 ParseError   : Boolean;
 ParseErrMsg  : String;

{ ============================================================
  HELPERS STRING
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
  HELPERS MATH
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
  Toutes les operations sont des Procedures (TP7 ne permet pas
  un Record comme type de retour de fonction).
  Toutes sont sures face a l'aliasing (Z peut = A ou B).
  ============================================================ }

Procedure CSet(Var Z: TComplex; Re, Im: TFloat);
Begin
 Z.re := Re;
 Z.im := Im;
End;

Procedure CSetReal(Var Z: TComplex; X: TFloat);
Begin
 Z.re := X;
 Z.im := 0;
End;

Function CIsReal(Const A: TComplex): Boolean;
Begin
 CIsReal := Abs(A.im) < 1E-12 * (1 + Abs(A.re));
End;

Procedure CAdd(Const A, B: TComplex; Var Z: TComplex);
Begin
 Z.re := A.re + B.re;
 Z.im := A.im + B.im;
End;

Procedure CSub(Const A, B: TComplex; Var Z: TComplex);
Var Re, Im: TFloat;
Begin
 Re := A.re - B.re;
 Im := A.im - B.im;
 Z.re := Re; Z.im := Im;
End;

Procedure CNeg(Const A: TComplex; Var Z: TComplex);
Begin
 Z.re := -A.re;
 Z.im := -A.im;
End;

Procedure CMul(Const A, B: TComplex; Var Z: TComplex);
Var Re, Im: TFloat;
Begin
 Re := A.re * B.re - A.im * B.im;
 Im := A.re * B.im + A.im * B.re;
 Z.re := Re; Z.im := Im;
End;

Function CAbs(Const A: TComplex): TFloat;
Var X, Y, T: TFloat;
Begin
 X := Abs(A.re);
 Y := Abs(A.im);
 If (X = 0) And (Y = 0) Then Begin CAbs := 0; Exit; End;
 If X < Y Then Begin T := X; X := Y; Y := T; End;
 T := Y / X;
 CAbs := X * Sqrt(1 + T*T);
End;

Function CAbs2(Const A: TComplex): TFloat;
Begin
 CAbs2 := A.re*A.re + A.im*A.im;
End;

Procedure CDiv(Const A, B: TComplex; Var Z: TComplex);
Var R, D, Re, Im: TFloat;
Begin
 If Abs(B.re) >= Abs(B.im) Then Begin
  R := B.im / B.re;
  D := B.re + R * B.im;
  Re := (A.re + R * A.im) / D;
  Im := (A.im - R * A.re) / D;
 End
 Else Begin
  R := B.re / B.im;
  D := B.im + R * B.re;
  Re := (A.re * R + A.im) / D;
  Im := (A.im * R - A.re) / D;
 End;
 Z.re := Re; Z.im := Im;
End;

Procedure CConj(Const A: TComplex; Var Z: TComplex);
Begin
 Z.re := A.re;
 Z.im := -A.im;
End;

Function CArg(Const A: TComplex): TFloat;
Begin
 If (A.re = 0) And (A.im = 0) Then CArg := 0
 Else CArg := ArcTan2(A.im, A.re);
End;

Procedure CInv(Const A: TComplex; Var Z: TComplex);
Var D, Re, Im: TFloat;
Begin
 D := A.re*A.re + A.im*A.im;
 Re :=  A.re / D;
 Im := -A.im / D;
 Z.re := Re; Z.im := Im;
End;

Procedure CExp(Const A: TComplex; Var Z: TComplex);
Var E, Re, Im: TFloat;
Begin
 E := Exp(A.re);
 Re := E * Cos(A.im);
 Im := E * Sin(A.im);
 Z.re := Re; Z.im := Im;
End;

Procedure CLog(Const A: TComplex; Var Z: TComplex);
Var Re, Im: TFloat;
Begin
 Re := Ln(CAbs(A));
 Im := CArg(A);
 Z.re := Re; Z.im := Im;
End;

Function CLogAbs(Const A: TComplex): TFloat;
Var X, Y, T: TFloat;
Begin
 X := Abs(A.re);
 Y := Abs(A.im);
 If X = 0 Then Begin CLogAbs := Ln(Y); Exit; End;
 If Y = 0 Then Begin CLogAbs := Ln(X); Exit; End;
 T := X*X + Y*Y;
 CLogAbs := 0.5 * Ln(T);
End;

Procedure CSqrt(Const A: TComplex; Var Z: TComplex);
Var R, W, Re, Im: TFloat;
Begin
 If (A.re = 0) And (A.im = 0) Then Begin
  Z.re := 0; Z.im := 0; Exit;
 End;
 R := CAbs(A);
 W := Sqrt((R + A.re) * 0.5);
 If W = 0 Then Begin
  Re := 0;
  If A.im >= 0 Then Im := Sqrt(R)
  Else Im := -Sqrt(R);
 End
 Else Begin
  Re := W;
  Im := A.im / (2 * W);
 End;
 Z.re := Re; Z.im := Im;
End;

Procedure CPow(Const A, B: TComplex; Var Z: TComplex);
Var L, R, ZZ, Acc, BB: TComplex;
    IntE: LongInt;
    Neg: Boolean;
    N: LongInt;
Begin
 If (A.re = 0) And (A.im = 0) Then Begin
  If (B.re = 0) And (B.im = 0) Then CSetReal(Z, 1)
  Else CSetReal(Z, 0);
  Exit;
 End;
 BB := B;  { copie locale (B est Const) }
 If CIsReal(BB) Then Begin
  IntE := Round(BB.re);
  If (Abs(BB.re - IntE) < 1E-9) And (Abs(IntE) <= 64) Then Begin
   Neg := IntE < 0;
   If Neg Then N := -IntE Else N := IntE;
   CSetReal(Acc, 1);
   ZZ := A;
   While N > 0 Do Begin
    If (N And 1) = 1 Then CMul(Acc, ZZ, Acc);
    CMul(ZZ, ZZ, ZZ);
    N := N Shr 1;
   End;
   If Neg Then CInv(Acc, Acc);
   Z := Acc;
   Exit;
  End;
 End;
 CLog(A, L);
 CMul(BB, L, R);
 CExp(R, Z);
End;

Procedure CSin(Const A: TComplex; Var Z: TComplex);
Var Re, Im: TFloat;
Begin
 Re := Sin(A.re) * Cosh(A.im);
 Im := Cos(A.re) * Sinh(A.im);
 Z.re := Re; Z.im := Im;
End;

Procedure CCos(Const A: TComplex; Var Z: TComplex);
Var Re, Im: TFloat;
Begin
 Re :=  Cos(A.re) * Cosh(A.im);
 Im := -Sin(A.re) * Sinh(A.im);
 Z.re := Re; Z.im := Im;
End;

Procedure CTan(Const A: TComplex; Var Z: TComplex);
Var S, C: TComplex;
Begin
 CSin(A, S);
 CCos(A, C);
 CDiv(S, C, Z);
End;

Procedure CCot(Const A: TComplex; Var Z: TComplex);
Var S, C: TComplex;
Begin
 CSin(A, S);
 CCos(A, C);
 CDiv(C, S, Z);
End;

Procedure CSec(Const A: TComplex; Var Z: TComplex);
Var C: TComplex;
Begin
 CCos(A, C);
 CInv(C, Z);
End;

Procedure CCsc(Const A: TComplex; Var Z: TComplex);
Var S: TComplex;
Begin
 CSin(A, S);
 CInv(S, Z);
End;

Procedure CSinh(Const A: TComplex; Var Z: TComplex);
Var Re, Im: TFloat;
Begin
 Re := Sinh(A.re) * Cos(A.im);
 Im := Cosh(A.re) * Sin(A.im);
 Z.re := Re; Z.im := Im;
End;

Procedure CCosh(Const A: TComplex; Var Z: TComplex);
Var Re, Im: TFloat;
Begin
 Re := Cosh(A.re) * Cos(A.im);
 Im := Sinh(A.re) * Sin(A.im);
 Z.re := Re; Z.im := Im;
End;

Procedure CTanh(Const A: TComplex; Var Z: TComplex);
Var S, C: TComplex;
Begin
 CSinh(A, S);
 CCosh(A, C);
 CDiv(S, C, Z);
End;

Procedure CCoth(Const A: TComplex; Var Z: TComplex);
Var S, C: TComplex;
Begin
 CSinh(A, S);
 CCosh(A, C);
 CDiv(C, S, Z);
End;

Procedure CSech(Const A: TComplex; Var Z: TComplex);
Var C: TComplex;
Begin
 CCosh(A, C);
 CInv(C, Z);
End;

Procedure CCsch(Const A: TComplex; Var Z: TComplex);
Var S: TComplex;
Begin
 CSinh(A, S);
 CInv(S, Z);
End;

Procedure CASin(Const A: TComplex; Var Z: TComplex);
Var One, Z2, S, IZ, Sum, Lg, Iu, NegI: TComplex;
Begin
 CSetReal(One, 1);
 CMul(A, A, Z2);
 CSub(One, Z2, S);
 CSqrt(S, S);
 CSet(Iu, 0, 1);
 CMul(Iu, A, IZ);
 CAdd(IZ, S, Sum);
 CLog(Sum, Lg);
 CSet(NegI, 0, -1);
 CMul(NegI, Lg, Z);
End;

Procedure CACos(Const A: TComplex; Var Z: TComplex);
Var Pi2, As1: TComplex;
Begin
 CSetReal(Pi2, OCT_PI * 0.5);
 CASin(A, As1);
 CSub(Pi2, As1, Z);
End;

Procedure CATan(Const A: TComplex; Var Z: TComplex);
Var Iu, IZ, U, V, Q, L, HalfI, One: TComplex;
Begin
 CSet(Iu, 0, 1);
 CMul(Iu, A, IZ);
 CSetReal(One, 1);
 CSub(One, IZ, U);
 CAdd(One, IZ, V);
 CDiv(U, V, Q);
 CLog(Q, L);
 CSet(HalfI, 0, 0.5);
 CMul(HalfI, L, Z);
End;

Procedure CACot(Const A: TComplex; Var Z: TComplex);
Var T: TComplex;
Begin
 If (A.re = 0) And (A.im = 0) Then Begin
  CSetReal(Z, OCT_PI * 0.5);
  Exit;
 End;
 CInv(A, T);
 CATan(T, Z);
End;

Procedure CASec(Const A: TComplex; Var Z: TComplex);
Var T: TComplex;
Begin
 CInv(A, T);
 CACos(T, Z);
End;

Procedure CACsc(Const A: TComplex; Var Z: TComplex);
Var T: TComplex;
Begin
 CInv(A, T);
 CASin(T, Z);
End;

Procedure CASinh(Const A: TComplex; Var Z: TComplex);
Var Z2, S, Sum, One: TComplex;
Begin
 CMul(A, A, Z2);
 CSetReal(One, 1);
 CAdd(Z2, One, S);
 CSqrt(S, S);
 CAdd(A, S, Sum);
 CLog(Sum, Z);
End;

Procedure CACosh(Const A: TComplex; Var Z: TComplex);
Var Z2, S, Sum, One: TComplex;
Begin
 CMul(A, A, Z2);
 CSetReal(One, 1);
 CSub(Z2, One, S);
 CSqrt(S, S);
 CAdd(A, S, Sum);
 CLog(Sum, Z);
End;

Procedure CATanh(Const A: TComplex; Var Z: TComplex);
Var U, V, Q, L, Half, One: TComplex;
Begin
 CSetReal(One, 1);
 CAdd(One, A, U);
 CSub(One, A, V);
 CDiv(U, V, Q);
 CLog(Q, L);
 CSetReal(Half, 0.5);
 CMul(Half, L, Z);
End;

Procedure CACoth(Const A: TComplex; Var Z: TComplex);
Var T: TComplex;
Begin
 CInv(A, T);
 CATanh(T, Z);
End;

Procedure CASech(Const A: TComplex; Var Z: TComplex);
Var T: TComplex;
Begin
 CInv(A, T);
 CACosh(T, Z);
End;

Procedure CACsch(Const A: TComplex; Var Z: TComplex);
Var T: TComplex;
Begin
 CInv(A, T);
 CASinh(T, Z);
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
Var T, Y, Sgn, AX: TFloat;
Begin
 AX := X;
 If AX < 0 Then Begin Sgn := -1; AX := -AX; End Else Sgn := 1;
 T := 1.0 / (1.0 + P5 * AX);
 Y := 1.0 - (((((A5*T + A4)*T) + A3)*T + A2)*T + A1)*T*Exp(-AX*AX);
 REerf := Sgn * Y;
End;

Procedure CErf(Const A: TComplex; Var Z: TComplex);
Var Z2, Term, Sum, ZZ: TComplex;
    K: LongInt;
    Fact, Coef: TFloat;
    Done: Boolean;
Begin
 If CIsReal(A) Then Begin
  Z.re := REerf(A.re);
  Z.im := 0;
  Exit;
 End;
 ZZ := A;
 CMul(ZZ, ZZ, Z2);
 Sum := ZZ;
 Term := ZZ;
 Fact := 1;
 Done := False;
 K := 1;
 While (K <= 40) And (Not Done) Do Begin
  CMul(Term, Z2, Term);
  Term.re := -Term.re;
  Term.im := -Term.im;
  Fact := Fact * K;
  Coef := 1 / (Fact * (2*K + 1));
  Sum.re := Sum.re + Term.re * Coef;
  Sum.im := Sum.im + Term.im * Coef;
  If (Abs(Term.re) + Abs(Term.im)) < 1E-14 Then Done := True;
  Inc(K);
 End;
 Coef := 2 / Sqrt(OCT_PI);
 Z.re := Coef * Sum.re;
 Z.im := Coef * Sum.im;
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
 CSetReal(V.s, 0);
 V.rows := Nil;
 V.nrows := 0;
End;

Function NewVar(Const Name: String): PVarNode;
Var P: PVarNode;
Begin
 New(P);
 P^.name := Name;
 P^.value.kind := vkScalar;
 CSetReal(P^.value.s, 0);
 P^.value.rows := Nil;
 P^.value.nrows := 0;
 P^.predefined := False;
 P^.next := VarsHead;
 VarsHead := P;
 Inc(NVars);
 NewVar := P;
End;

Procedure SetScalar(Const Name: String; Const Z: TComplex; Pre: Boolean);
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
Var Z: TComplex;
Begin
 CSetReal(Z, X);
 SetScalar(Name, Z, Pre);
End;

{ ============================================================
  CONSTANTES PREDEFINIES (unites atomiques de Hartree)
  ============================================================ }

Procedure InitPredefined;
Var Iu: TComplex;
Begin
 SetReal('pi',          OCT_PI,                True);
 SetReal('e',           OCT_E,                 True);
 CSet(Iu, 0, 1);
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

Procedure LexNext(Var T: TToken);
Var Start: Integer;
    S: String;
    Code: Integer;
    C: Char;
Begin
 SkipSpaces;
 T.line := LexLineNo;
 T.kind := tkEOL;
 T.text := '';
 T.num  := 0;
 If LexPos > Length(LexBuf) Then Exit;
 C := LexBuf[LexPos];

 { Commentaire # }
 If C = '#' Then Begin
  LexPos := Length(LexBuf) + 1;
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
  Exit;
 End;

 { Identifiants }
 If IsAlphaC(C) Then Begin
  Start := LexPos;
  While (LexPos <= Length(LexBuf)) And IsAlNumC(LexBuf[LexPos]) Do
   Inc(LexPos);
  S := Copy(LexBuf, Start, LexPos - Start);
  MakeTok(T, tkIdent, S);
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
  Exit;
 End;

 Case C Of
  '+': Begin Inc(LexPos); MakeTok(T, tkPlus, '+'); Exit; End;
  '-': Begin Inc(LexPos); MakeTok(T, tkMinus, '-'); Exit; End;
  '*': Begin Inc(LexPos); MakeTok(T, tkStar, '*'); Exit; End;
  '/': Begin Inc(LexPos); MakeTok(T, tkSlash, '/'); Exit; End;
  '^': Begin Inc(LexPos); MakeTok(T, tkCaret, '^'); Exit; End;
  '(': Begin Inc(LexPos); MakeTok(T, tkLParen, '('); Exit; End;
  ')': Begin Inc(LexPos); MakeTok(T, tkRParen, ')'); Exit; End;
  ',': Begin Inc(LexPos); MakeTok(T, tkComma, ','); Exit; End;
  '{': Begin Inc(LexPos); MakeTok(T, tkLBrace, '{'); Exit; End;
  '}': Begin Inc(LexPos); MakeTok(T, tkRBrace, '}'); Exit; End;
  '|': Begin
   Inc(LexPos);
   If PeekCh = '|' Then Begin
    Inc(LexPos); MakeTok(T, tkOr, '||');
   End Else MakeTok(T, tkPipe, '|');
   Exit;
  End;
  '&': Begin
   Inc(LexPos);
   If PeekCh = '&' Then Begin
    Inc(LexPos); MakeTok(T, tkAnd, '&&');
   End Else Begin
    RaiseErr('Operateur ''&'' isole (utiliser ''&&'')');
    MakeTok(T, tkEOL, '');
   End;
   Exit;
  End;
  '=': Begin
   Inc(LexPos);
   If PeekCh = '=' Then Begin
    Inc(LexPos); MakeTok(T, tkEQ, '==');
   End Else MakeTok(T, tkAssign, '=');
   Exit;
  End;
  '!': Begin
   Inc(LexPos);
   If PeekCh = '=' Then Begin
    Inc(LexPos); MakeTok(T, tkNE, '!=');
   End Else MakeTok(T, tkNot, '!');
   Exit;
  End;
  '<': Begin
   Inc(LexPos);
   If PeekCh = '=' Then Begin
    Inc(LexPos); MakeTok(T, tkLE, '<=');
   End Else MakeTok(T, tkLT, '<');
   Exit;
  End;
  '>': Begin
   Inc(LexPos);
   If PeekCh = '=' Then Begin
    Inc(LexPos); MakeTok(T, tkGE, '>=');
   End Else MakeTok(T, tkGT, '>');
   Exit;
  End;
  '%': Begin Inc(LexPos); MakeTok(T, tkPercent, '%'); Exit; End;
 End;

 RaiseErr('Caractere invalide : ''' + C + '''');
 Inc(LexPos);
 MakeTok(T, tkEOL, '');
End;

Procedure LexInitLine(Const S: String; LNo: LongInt);
Begin
 LexBuf := S;
 LexPos := 1;
 LexLineNo := LNo;
 HavePeek := False;
End;

Procedure NextTok(Var T: TToken);
Begin
 If HavePeek Then Begin
  T := PeekTok;
  HavePeek := False;
 End
 Else LexNext(T);
End;

Procedure PeekTokF(Var T: TToken);
Begin
 If Not HavePeek Then Begin
  LexNext(PeekTok);
  HavePeek := True;
 End;
 T := PeekTok;
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

Procedure ParseExpr(Var R: TComplex); Forward;
Procedure ParseUnary(Var R: TComplex); Forward;

Function CmpEq(Const A, B: TComplex): Boolean;
Begin
 CmpEq := (Abs(A.re - B.re) < 1E-9) And (Abs(A.im - B.im) < 1E-9);
End;

Function ToBool(Const A: TComplex): Boolean;
Begin
 ToBool := (Abs(A.re) > 1E-12) Or (Abs(A.im) > 1E-12);
End;

Procedure FromBool(B: Boolean; Var Z: TComplex);
Begin
 If B Then CSetReal(Z, 1) Else CSetReal(Z, 0);
End;

Function GetEnvVarStr(Const Name: String): String;
Begin
 GetEnvVarStr := GetEnv(Name);
End;

Procedure ParseArgs(Var Args: TArgArray; MaxN: Integer; Var Cnt: Integer);
Var T: TToken;
Begin
 Cnt := 0;
 PeekTokF(T);
 If T.kind = tkRParen Then Exit;
 Repeat
  If Cnt >= MaxN Then Begin
   RaiseErr('Trop d''arguments');
   Exit;
  End;
  ParseExpr(Args[Cnt]);
  Inc(Cnt);
  PeekTokF(T);
  If T.kind = tkComma Then NextTok(T)
  Else Break;
 Until False;
End;

Procedure CallBuiltin(Const Name: String;
                      Var Args: TArgArray;
                      N: Integer;
                      Var Found: Boolean;
                      Var R: TComplex);
Var Lo: String;
    A, U, V: TComplex;
Begin
 Lo := LowerStr(Name);
 Found := True;
 CSetReal(R, 0);

 If N = 1 Then Begin
  A := Args[0];
  If Lo = 'sqrt'     Then Begin CSqrt(A, R); Exit; End;
  If Lo = 'exp'      Then Begin CExp(A, R); Exit; End;
  If (Lo = 'log') Or (Lo = 'ln') Then Begin CLog(A, R); Exit; End;
  If Lo = 'log10' Then Begin
   CLog(A, U);
   CSetReal(V, 1/Ln(10));
   CMul(U, V, R); Exit;
  End;
  If Lo = 'arg'      Then Begin CSetReal(R, CArg(A)); Exit; End;
  If Lo = 'abs'      Then Begin CSetReal(R, CAbs(A)); Exit; End;
  If Lo = 'abs2'     Then Begin CSetReal(R, CAbs2(A)); Exit; End;
  If Lo = 'logabs'   Then Begin CSetReal(R, CLogAbs(A)); Exit; End;
  If Lo = 'conjg'    Then Begin CConj(A, R); Exit; End;
  If Lo = 'inv'      Then Begin CInv(A, R); Exit; End;
  If Lo = 'sin'      Then Begin CSin(A, R); Exit; End;
  If Lo = 'cos'      Then Begin CCos(A, R); Exit; End;
  If Lo = 'tan'      Then Begin CTan(A, R); Exit; End;
  If Lo = 'cot'      Then Begin CCot(A, R); Exit; End;
  If Lo = 'sec'      Then Begin CSec(A, R); Exit; End;
  If Lo = 'csc'      Then Begin CCsc(A, R); Exit; End;
  If Lo = 'asin'     Then Begin CASin(A, R); Exit; End;
  If Lo = 'acos'     Then Begin CACos(A, R); Exit; End;
  If Lo = 'atan'     Then Begin CATan(A, R); Exit; End;
  If Lo = 'acot'     Then Begin CACot(A, R); Exit; End;
  If Lo = 'asec'     Then Begin CASec(A, R); Exit; End;
  If Lo = 'acsc'     Then Begin CACsc(A, R); Exit; End;
  If Lo = 'sinh'     Then Begin CSinh(A, R); Exit; End;
  If Lo = 'cosh'     Then Begin CCosh(A, R); Exit; End;
  If Lo = 'tanh'     Then Begin CTanh(A, R); Exit; End;
  If Lo = 'coth'     Then Begin CCoth(A, R); Exit; End;
  If Lo = 'sech'     Then Begin CSech(A, R); Exit; End;
  If Lo = 'csch'     Then Begin CCsch(A, R); Exit; End;
  If Lo = 'asinh'    Then Begin CASinh(A, R); Exit; End;
  If Lo = 'acosh'    Then Begin CACosh(A, R); Exit; End;
  If Lo = 'atanh'    Then Begin CATanh(A, R); Exit; End;
  If Lo = 'acoth'    Then Begin CACoth(A, R); Exit; End;
  If Lo = 'asech'    Then Begin CASech(A, R); Exit; End;
  If Lo = 'acsch'    Then Begin CACsch(A, R); Exit; End;
  If Lo = 'step' Then Begin
   If A.re > 0 Then CSetReal(R, 1)
   Else If A.re < 0 Then CSetReal(R, 0)
   Else CSetReal(R, 0.5);
   Exit;
  End;
  If Lo = 'erf'      Then Begin CErf(A, R); Exit; End;
  If Lo = 'realpart' Then Begin CSetReal(R, A.re); Exit; End;
  If Lo = 'imagpart' Then Begin CSetReal(R, A.im); Exit; End;
  If Lo = 'floor'    Then Begin CSetReal(R, FloorF(A.re)); Exit; End;
  If Lo = 'ceiling'  Then Begin CSetReal(R, CeilF(A.re)); Exit; End;
 End;

 If N = 2 Then Begin
  If Lo = 'logb' Then Begin
   CLog(Args[0], U);
   CLog(Args[1], V);
   CDiv(U, V, R); Exit;
  End;
  If Lo = 'atan2' Then Begin
   CSetReal(R, ArcTan2(Args[1].re, Args[0].re)); Exit;
  End;
  If Lo = 'min' Then Begin
   If Args[0].re <= Args[1].re Then R := Args[0]
   Else R := Args[1];
   Exit;
  End;
  If Lo = 'max' Then Begin
   If Args[0].re >= Args[1].re Then R := Args[0]
   Else R := Args[1];
   Exit;
  End;
 End;

 Found := False;
End;

Procedure GetVarScalar(Const Name: String; Var R: TComplex; Var OK: Boolean);
Var P: PVarNode;
Begin
 OK := False;
 CSetReal(R, 0);
 P := FindVar(Name);
 If P = Nil Then Exit;
 If P^.value.kind <> vkScalar Then Exit;
 R := P^.value.s;
 OK := True;
End;

Function ParseStringTok: String;
Var T: TToken;
Begin
 NextTok(T);
 If T.kind <> tkString Then Begin
  RaiseErr('Chaine attendue');
  ParseStringTok := '';
  Exit;
 End;
 ParseStringTok := T.text;
End;

Procedure ParsePrimary(Var R: TComplex);
Var T, T2: TToken;
    Re, Im: TComplex;
    Args: TArgArray;
    N: Integer;
    Found, OK: Boolean;
    Name, EnvName, EnvVal: String;
    Rl: TFloat;
    Code: Integer;
Begin
 NextTok(T);
 CSetReal(R, 0);
 Case T.kind Of
  tkNumber: Begin
   CSetReal(R, T.num);
   Exit;
  End;
  tkLParen: Begin
   ParseExpr(R);
   NextTok(T);
   If T.kind <> tkRParen Then RaiseErr('")" attendu');
   Exit;
  End;
  tkLBrace: Begin
   ParseExpr(Re);
   NextTok(T);
   If T.kind <> tkComma Then RaiseErr('"," attendu dans {x,y}');
   ParseExpr(Im);
   NextTok(T);
   If T.kind <> tkRBrace Then RaiseErr('"}" attendu');
   CSet(R, Re.re, Im.re);
   Exit;
  End;
  tkIdent: Begin
   Name := T.text;
   If (Length(Name) > 0) And (Name[1] = '$') Then Begin
    EnvName := Copy(Name, 2, Length(Name) - 1);
    EnvVal := GetEnvVarStr(EnvName);
    Val(EnvVal, Rl, Code);
    If Code = 0 Then CSetReal(R, Rl);
    Exit;
   End;
   PeekTokF(T2);
   If T2.kind = tkLParen Then Begin
    NextTok(T2);
    If LowerStr(Name) = 'getenv' Then Begin
     EnvName := ParseStringTok;
     NextTok(T2);
     If T2.kind <> tkRParen Then RaiseErr('")" attendu apres getenv');
     EnvVal := GetEnvVarStr(EnvName);
     Val(EnvVal, Rl, Code);
     If Code = 0 Then CSetReal(R, Rl);
     Exit;
    End;
    ParseArgs(Args, MAX_ARGS, N);
    NextTok(T2);
    If T2.kind <> tkRParen Then RaiseErr('")" attendu apres arguments');
    CallBuiltin(Name, Args, N, Found, R);
    If Not Found Then
     RaiseErr('Fonction inconnue ou mauvais nombre d''arguments : ' + Name);
    Exit;
   End;
   GetVarScalar(Name, R, OK);
   If Not OK Then RaiseErr('Variable non definie : ' + Name);
   Exit;
  End;
 End;
 RaiseErr('Expression attendue (token : ' + T.text + ')');
End;

Procedure ParseUnary(Var R: TComplex);
Var T: TToken;
    V: TComplex;
Begin
 PeekTokF(T);
 If T.kind = tkMinus Then Begin
  NextTok(T);
  ParseUnary(V);
  CNeg(V, R);
  Exit;
 End;
 If T.kind = tkPlus Then Begin
  NextTok(T);
  ParseUnary(R);
  Exit;
 End;
 If T.kind = tkNot Then Begin
  NextTok(T);
  ParseUnary(V);
  FromBool(Not ToBool(V), R);
  Exit;
 End;
 ParsePrimary(R);
End;

Procedure ParsePow(Var Z: TComplex);
Var L, R: TComplex;
    T: TToken;
Begin
 ParseUnary(L);
 PeekTokF(T);
 If T.kind = tkCaret Then Begin
  NextTok(T);
  ParsePow(R);
  CPow(L, R, Z);
  Exit;
 End;
 Z := L;
End;

Procedure ParseMul(Var Z: TComplex);
Var L, R: TComplex;
    T: TToken;
    Loop: Boolean;
Begin
 ParsePow(L);
 Loop := True;
 While Loop Do Begin
  PeekTokF(T);
  If T.kind = tkStar Then Begin
   NextTok(T);
   ParsePow(R);
   CMul(L, R, L);
  End
  Else If T.kind = tkSlash Then Begin
   NextTok(T);
   ParsePow(R);
   CDiv(L, R, L);
  End
  Else Loop := False;
 End;
 Z := L;
End;

Procedure ParseAdd(Var Z: TComplex);
Var L, R: TComplex;
    T: TToken;
    Loop: Boolean;
Begin
 ParseMul(L);
 Loop := True;
 While Loop Do Begin
  PeekTokF(T);
  If T.kind = tkPlus Then Begin
   NextTok(T);
   ParseMul(R);
   CAdd(L, R, L);
  End
  Else If T.kind = tkMinus Then Begin
   NextTok(T);
   ParseMul(R);
   CSub(L, R, L);
  End
  Else Loop := False;
 End;
 Z := L;
End;

Procedure ParseCmp(Var Z: TComplex);
Var L, R: TComplex;
    T: TToken;
    K: TTokenKind;
Begin
 ParseAdd(L);
 PeekTokF(T);
 If (T.kind = tkLT) Or (T.kind = tkLE) Or (T.kind = tkGT) Or
    (T.kind = tkGE) Or (T.kind = tkEQ) Or (T.kind = tkNE) Then Begin
  K := T.kind;
  NextTok(T);
  ParseAdd(R);
  Case K Of
   tkLT: FromBool(L.re <  R.re, Z);
   tkLE: FromBool(L.re <= R.re, Z);
   tkGT: FromBool(L.re >  R.re, Z);
   tkGE: FromBool(L.re >= R.re, Z);
   tkEQ: FromBool(CmpEq(L, R), Z);
   tkNE: FromBool(Not CmpEq(L, R), Z);
  End;
  Exit;
 End;
 Z := L;
End;

Procedure ParseAnd(Var Z: TComplex);
Var L, R: TComplex;
    T: TToken;
    Loop: Boolean;
Begin
 ParseCmp(L);
 Loop := True;
 While Loop Do Begin
  PeekTokF(T);
  If T.kind = tkAnd Then Begin
   NextTok(T);
   ParseCmp(R);
   FromBool(ToBool(L) And ToBool(R), L);
  End
  Else Loop := False;
 End;
 Z := L;
End;

Procedure ParseOr(Var Z: TComplex);
Var L, R: TComplex;
    T: TToken;
    Loop: Boolean;
Begin
 ParseAnd(L);
 Loop := True;
 While Loop Do Begin
  PeekTokF(T);
  If T.kind = tkOr Then Begin
   NextTok(T);
   ParseAnd(R);
   FromBool(ToBool(L) Or ToBool(R), L);
  End
  Else Loop := False;
 End;
 Z := L;
End;

Procedure ParseExpr(Var R: TComplex);
Begin
 ParseOr(R);
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

Function FormatComplex(Const Z: TComplex): String;
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
  LECTURE DE FICHIER
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

{ Parse une ligne de bloc. Retourne le nb de cellules lues. }
Function ParseBlockRowLine(Row: PBlockRow): Integer;
Var N: Integer;
    T: TToken;
    V: TComplex;
    Done: Boolean;
Begin
 N := 0;
 Done := False;
 While Not Done Do Begin
  PeekTokF(T);
  If T.kind = tkEOL Then Begin Done := True; Continue; End;
  If T.kind = tkString Then Begin
   NextTok(T);
   CSetReal(V, 0);
  End
  Else Begin
   ParseExpr(V);
   If ParseError Then Begin Done := True; Continue; End;
  End;
  If N >= MAX_BLOCK_COLS Then Begin
   RaiseErr('Trop de colonnes dans bloc (max ' + IntStr(MAX_BLOCK_COLS) + ')');
   Done := True; Continue;
  End;
  Inc(N);
  Row^.cell[N] := V;
  PeekTokF(T);
  If T.kind = tkPipe Then NextTok(T)
  Else Done := True;
 End;
 Row^.ncols := N;
 ParseBlockRowLine := N;
End;

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

  PeekTokF(T);
  If T.kind = tkEOL Then Continue;

  If T.kind = tkPercent Then Begin
   NextTok(T);
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
 PeekTokF(T);
 If T.kind = tkEOL Then Exit;

 { Bloc : %nom ... % }
 If T.kind = tkPercent Then Begin
  NextTok(T);
  NextTok(T);
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
  NextTok(T);
  NextTok(T);
  If T.kind <> tkString Then Begin
   RaiseErr('Chaine attendue apres include');
   Exit;
  End;
  Fn := T.text;
  DoInclude(Fn);
  Exit;
 End;

 If StrEqI(T.text, 'print') Then Begin
  NextTok(T);
  ParseExpr(V);
  If Not ParseError Then WriteLn(FormatComplex(V));
  Exit;
 End;

 If StrEqI(T.text, 'show') Then Begin
  NextTok(T);
  NextTok(T);
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
  NextTok(T);
  Halt(0);
 End;

 If StrEqI(T.text, 'list') Then Begin
  NextTok(T);
  P := VarsHead;
  While P <> Nil Do Begin
   If Not P^.predefined Then PrintValue(P^.name, P^.value);
   P := P^.next;
  End;
  Exit;
 End;

 { Affectation : ident = expr }
 NextTok(T);
 Name := T.text;
 NextTok(T2);
 If T2.kind <> tkAssign Then Begin
  RaiseErr('"=" attendu apres ' + Name);
  Exit;
 End;
 ParseExpr(V);
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
 WriteLn('OCTOPUS : Cette commande permet de lancer l''analyseur d''entr'+#130+'e Octopus.');
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
