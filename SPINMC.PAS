{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/physiq)
  @abstract(Target: Turbo Pascal 7 / Free Pascal 3.2 mode -Mtp)
  @description: Clone de la commande "spinmc" de la bibliotheque ALPS
                (Algorithms and Libraries for Physics Simulations).
                Simulation Monte-Carlo classique de modeles de spin
                sur reseau carre 2D periodique :
                  - Ising (Z2, spin = +/- 1)
                  - Potts q-etats (q = 2..8)
                  - XY (spin = angle reel, vecteur unite 2D)
                Algorithmes de mise a jour :
                  - Metropolis local (tous les modeles)
                  - Wolff cluster (Ising et Potts)
                Observables mesurees avec estimation d'erreur par
                binning :  E, |M|, M^2, E^2, M^4, susceptibilite chi,
                chaleur specifique C, cumulant de Binder U.

                Lit fichiers de parametres .parm (KEY=VALUE) ou
                .in.xml (sous-ensemble minimal de l'XML ALPS).
                Ecrit job.out.txt et, si --write-xml, job.out.xml
                au format compatible spinmc_evaluate.

                Usage : SPINMC [options] fichier.in.xml
                Options :
                  --time-limit <s>      duree maxi totale (s)
                  --checkpoint-time <s> intervalle sauvegarde (s)
                  --Tmin <s>            poll mini (s)
                  --Tmax <s>            poll maxi (s)
                  --write-xml           ecrit aussi .out.xml
                  --help                affiche l'aide

                Compilation :
                  Turbo Pascal 7 : TPC SPINMC.PAS
                  Free Pascal    : fpc -Mtp SPINMC.PAS
}

{$IFDEF FPC}
 {$MODE TP}
{$ENDIF}
{$R-}

Program SPINMC;

Uses Dos;

{ ============================================================
  CONSTANTES
  ============================================================ }

Const
 SPINMC_VERSION = '1.00';
 SPINMC_DATE    = '2026';

 MAX_L          = 64;                 { reseau LxL <= 64x64 = 4096 sites }
 MAX_SITES      = MAX_L * MAX_L;
 MAX_Q          = 8;                  { Potts : 2..8 etats }
 MAX_BINS       = 32;                 { bins pour estim. erreur }
 MAX_LINE       = 255;

 SPMC_PI        = 3.14159265358979;
 SPMC_2PI       = 6.28318530717958;

{ ============================================================
  TYPES
  ============================================================ }

Type
 TModel  = (mdIsing, mdPotts, mdXY);
 TUpdate = (upLocal, upCluster);
 TStr80  = String[80];

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }

Var
 { Parametres physique }
 PrmModel        : TModel;
 PrmUpdate       : TUpdate;
 PrmL            : Integer;
 PrmQ            : Integer;                   { Potts }
 PrmT            : Real;                      { temperature }
 PrmJ            : Real;                      { couplage (ferro: J>0) }
 PrmH            : Real;                      { champ externe }
 PrmThermalize   : LongInt;
 PrmSweeps       : LongInt;
 PrmSeed         : LongInt;
 PrmLatticeName  : TStr80;
 PrmModelName    : TStr80;
 PrmUpdateName   : TStr80;

 { Options CLI }
 OptTimeLimit    : LongInt;
 OptCheckpoint   : LongInt;
 OptTmin         : LongInt;
 OptTmax         : LongInt;
 OptWriteXml     : Boolean;
 OptHelp         : Boolean;
 OptInFile       : TStr80;
 OptBaseName     : TStr80;             { nom sans extension }

 { Etat du reseau }
 NSites          : Integer;
 Beta            : Real;
 { Stockage des spins : un seul des deux est utilise selon le modele.
   ShortInt suffit pour Ising (-1/+1) et Potts (0..q-1). }
 SpinI           : Array[0..MAX_SITES - 1] Of ShortInt;
 SpinA           : Array[0..MAX_SITES - 1] Of Real;        { XY : angle }

 { Pile pour cluster Wolff }
 ClStack         : Array[0..MAX_SITES - 1] Of Integer;
 ClInCluster     : Array[0..MAX_SITES - 1] Of Boolean;
 ClTop           : Integer;

 { Accumulateurs courants (bin en construction) }
 AccE, AccE2     : Real;
 AccM, AccAbsM   : Real;
 AccM2, AccM4    : Real;
 AccN            : LongInt;
 BinSize         : LongInt;

 { Bins finaux }
 NBins           : Integer;
 BinE            : Array[0..MAX_BINS - 1] Of Real;
 BinAbsM         : Array[0..MAX_BINS - 1] Of Real;
 BinE2           : Array[0..MAX_BINS - 1] Of Real;
 BinM2           : Array[0..MAX_BINS - 1] Of Real;
 BinM4           : Array[0..MAX_BINS - 1] Of Real;

 { Resultats finaux (moyenne + erreur) }
 ResEnergy,    ErrEnergy    : Real;
 ResMagAbs,    ErrMagAbs    : Real;
 ResMag2,      ErrMag2      : Real;
 ResSpecHeat,  ErrSpecHeat  : Real;
 ResChi,       ErrChi       : Real;
 ResBinder,    ErrBinder    : Real;

 { Suivi temps }
 StartSec        : LongInt;
 LastCkptSec     : LongInt;

{ ============================================================
  UTILITAIRES STRING / IO
  ============================================================ }

Function IntToStr(N: LongInt): String;
Var S: String;
Begin Str(N, S); IntToStr := S; End;

Function FloatToStr(X: Real; Width, Decimals: Integer): String;
Var S: String;
Begin Str(X:Width:Decimals, S); FloatToStr := S; End;

Function FloatToSci(X: Real): String;
Var S: String;
Begin Str(X, S); FloatToSci := S; End;

Function UpStr(S: String): String;
Var I: Integer;
Begin
 For I := 1 To Length(S) Do
  If (S[I] >= 'a') And (S[I] <= 'z') Then
   S[I] := Chr(Ord(S[I]) - 32);
 UpStr := S;
End;

Function TrimStr(S: String): String;
Var I, J: Integer;
Begin
 I := 1;
 While (I <= Length(S)) And ((S[I] = ' ') Or (S[I] = #9)) Do Inc(I);
 J := Length(S);
 While (J >= I) And ((S[J] = ' ') Or (S[J] = #9) Or
                     (S[J] = #13) Or (S[J] = #10)) Do Dec(J);
 If J < I Then TrimStr := '' Else TrimStr := Copy(S, I, J - I + 1);
End;

Function StripQuotes(S: String): String;
Begin
 S := TrimStr(S);
 If (Length(S) >= 2) And (S[1] = '"') And (S[Length(S)] = '"') Then
  S := Copy(S, 2, Length(S) - 2);
 StripQuotes := TrimStr(S);
End;

Function StrToRealDef(S: String; Def: Real): Real;
Var X: Real; Code: Integer;
Begin
 S := TrimStr(S);
 Val(S, X, Code);
 If Code = 0 Then StrToRealDef := X Else StrToRealDef := Def;
End;

Function StrToIntDef(S: String; Def: LongInt): LongInt;
Var N: LongInt; Code: Integer;
Begin
 S := TrimStr(S);
 Val(S, N, Code);
 If Code = 0 Then StrToIntDef := N Else StrToIntDef := Def;
End;

Function BaseName(FName: String): String;
Var I, P: Integer;
Begin
 { Retire chemin }
 P := 0;
 For I := Length(FName) DownTo 1 Do
  If (FName[I] = '/') Or (FName[I] = '\') Or (FName[I] = ':') Then Begin
   P := I; Break;
  End;
 If P > 0 Then FName := Copy(FName, P + 1, Length(FName) - P);
 { Retire .in.xml ou derniere extension }
 P := Pos('.in.xml', FName);
 If P > 0 Then BaseName := Copy(FName, 1, P - 1)
 Else Begin
  P := 0;
  For I := Length(FName) DownTo 1 Do
   If FName[I] = '.' Then Begin P := I; Break; End;
  If P > 0 Then BaseName := Copy(FName, 1, P - 1) Else BaseName := FName;
 End;
End;

Function NowSeconds: LongInt;
Var H, M, S, S100: Word;
Begin
 GetTime(H, M, S, S100);
 NowSeconds := LongInt(H) * 3600 + LongInt(M) * 60 + S;
End;

{ ============================================================
  GENERATEUR ALEATOIRE
  ============================================================
  Park-Miller (minimal standard) : portable, reproductible
  entre TP7 et FPC, contrairement a Random qui differe. }

Var RngState: LongInt;

Procedure RngSeed(S: LongInt);
Begin
 If S <= 0 Then S := 1;
 RngState := S;
End;

Function RngU: Real;
Const A = 16807; M = 2147483647; Q = 127773; R = 2836;
Var Lo, Hi, T: LongInt;
Begin
 Hi := RngState Div Q;
 Lo := RngState Mod Q;
 T  := A * Lo - R * Hi;
 If T > 0 Then RngState := T Else RngState := T + M;
 RngU := RngState * 4.6566128752E-10;     { 1/M }
End;

Function RngInt(N: Integer): Integer;
Begin
 RngInt := Trunc(RngU * N);
End;

{ ============================================================
  ENCODAGE INDEX RESEAU 2D PERIODIQUE
  ============================================================ }

Function SiteIdx(X, Y: Integer): Integer;
Begin SiteIdx := Y * PrmL + X; End;

{ Voisins avec conditions periodiques (sans Mod, plus rapide). }
Function SiteRight(S: Integer): Integer;
Var X: Integer;
Begin
 X := S Mod PrmL;
 If X = PrmL - 1 Then SiteRight := S - (PrmL - 1)
                 Else SiteRight := S + 1;
End;

Function SiteLeft(S: Integer): Integer;
Var X: Integer;
Begin
 X := S Mod PrmL;
 If X = 0 Then SiteLeft := S + (PrmL - 1)
          Else SiteLeft := S - 1;
End;

Function SiteUp(S: Integer): Integer;
Var Y: Integer;
Begin
 Y := S Div PrmL;
 If Y = PrmL - 1 Then SiteUp := S - (PrmL - 1) * PrmL
                 Else SiteUp := S + PrmL;
End;

Function SiteDown(S: Integer): Integer;
Var Y: Integer;
Begin
 Y := S Div PrmL;
 If Y = 0 Then SiteDown := S + (PrmL - 1) * PrmL
          Else SiteDown := S - PrmL;
End;

{ ============================================================
  PARSEUR DE PARAMETRES
  ============================================================
  Accepte deux formats :
   - .parm : lignes "KEY=VALEUR"  (commentaires #...)
   - .in.xml : lignes "<PARAMETER name=\"KEY\">VAL</PARAMETER>"
  Detecte le format par presence de '<' au debut de ligne non vide. }

Procedure ApplyParameter(Key, Val: String);
Var K, V: String;
Begin
 K := UpStr(TrimStr(Key));
 V := StripQuotes(Val);
 If K = 'LATTICE'       Then PrmLatticeName := V Else
 If K = 'MODEL'         Then PrmModelName   := V Else
 If K = 'UPDATE'        Then PrmUpdateName  := V Else
 If K = 'L'             Then PrmL           := StrToIntDef(V, PrmL) Else
 If K = 'Q'             Then PrmQ           := StrToIntDef(V, PrmQ) Else
 If K = 'T'             Then PrmT           := StrToRealDef(V, PrmT) Else
 If K = 'TEMPERATURE'   Then PrmT           := StrToRealDef(V, PrmT) Else
 If K = 'J'             Then PrmJ           := StrToRealDef(V, PrmJ) Else
 If K = 'H'             Then PrmH           := StrToRealDef(V, PrmH) Else
 If K = 'THERMALIZATION'Then PrmThermalize  := StrToIntDef(V, PrmThermalize) Else
 If K = 'SWEEPS'        Then PrmSweeps      := StrToIntDef(V, PrmSweeps) Else
 If K = 'SEED'          Then PrmSeed        := StrToIntDef(V, PrmSeed);
End;

Procedure ParseParmLine(S: String);
Var P: Integer; K, V: String;
Begin
 S := TrimStr(S);
 If S = '' Then Exit;
 If S[1] = '#' Then Exit;
 P := Pos('=', S);
 If P = 0 Then Exit;
 K := Copy(S, 1, P - 1);
 V := Copy(S, P + 1, Length(S) - P);
 { Retire commentaire de fin '#...' }
 P := Pos('#', V);
 If P > 0 Then V := Copy(V, 1, P - 1);
 ApplyParameter(K, V);
End;

Procedure ParseXmlLine(S: String);
Var P, Q, R, Stop: Integer; K, V: String;
Begin
 S := TrimStr(S);
 P := Pos('<PARAMETER', UpStr(S));
 If P = 0 Then Exit;
 { Trouver name="..." }
 Q := Pos('NAME=', UpStr(S));
 If Q = 0 Then Exit;
 Q := Q + 5;
 If S[Q] = '"' Then Begin
  Inc(Q);
  R := Q;
  While (R <= Length(S)) And (S[R] <> '"') Do Inc(R);
  K := Copy(S, Q, R - Q);
 End Else Begin
  R := Q;
  While (R <= Length(S)) And (S[R] <> ' ') And (S[R] <> '>') Do Inc(R);
  K := Copy(S, Q, R - Q);
 End;
 { Valeur entre > et </ }
 P := Pos('>', S);
 If P = 0 Then Exit;
 Stop := Pos('</', S);
 If Stop = 0 Then Stop := Length(S) + 1;
 V := Copy(S, P + 1, Stop - P - 1);
 ApplyParameter(K, V);
End;

Procedure ReadParameterFile(FName: String);
Var
 F: Text;
 Line: String;
 IsXml: Boolean;
 GotFirst: Boolean;
 T: String;
Begin
 Assign(F, FName);
 {$I-} Reset(F); {$I+}
 If IOResult <> 0 Then Begin
  Writeln('SPINMC: erreur lecture ', FName);
  Halt(1);
 End;
 IsXml := False;
 GotFirst := False;
 While Not Eof(F) Do Begin
  Readln(F, Line);
  If Not GotFirst Then Begin
   T := TrimStr(Line);
   If T <> '' Then Begin
    GotFirst := True;
    If T[1] = '<' Then IsXml := True;
   End;
  End;
  If IsXml Then ParseXmlLine(Line) Else ParseParmLine(Line);
 End;
 Close(F);
End;

{ ============================================================
  INITIALISATION DU RESEAU ET DES SPINS
  ============================================================ }

Procedure ResolveModel;
Var M: String;
Begin
 M := UpStr(PrmModelName);
 If (M = 'ISING') Then PrmModel := mdIsing Else
 If (M = 'POTTS') Then PrmModel := mdPotts Else
 If (M = 'XY')    Then PrmModel := mdXY Else
 Begin
  Writeln('SPINMC: modele inconnu "', PrmModelName, '" -> Ising');
  PrmModel := mdIsing;
 End;
 M := UpStr(PrmUpdateName);
 If (M = 'CLUSTER') Or (M = 'WOLFF') Then PrmUpdate := upCluster
 Else                                     PrmUpdate := upLocal;
 If (PrmUpdate = upCluster) And (PrmModel = mdXY) Then Begin
  Writeln('SPINMC: cluster non implemente pour XY, repli Metropolis');
  PrmUpdate := upLocal;
 End;
End;

Procedure InitSpins;
Var I: Integer; R: Real;
Begin
 NSites := PrmL * PrmL;
 Case PrmModel Of
  mdIsing: Begin
   For I := 0 To NSites - 1 Do
    If RngU < 0.5 Then SpinI[I] := -1 Else SpinI[I] := 1;
  End;
  mdPotts: Begin
   For I := 0 To NSites - 1 Do
    SpinI[I] := RngInt(PrmQ);
  End;
  mdXY: Begin
   For I := 0 To NSites - 1 Do Begin
    R := RngU * SPMC_2PI;
    SpinA[I] := R;
   End;
  End;
 End;
End;

{ ============================================================
  ENERGIE ET AIMANTATION
  ============================================================ }

Function TotalEnergy: Real;
Var I: Integer; E, Sum: Real;
Begin
 E := 0;
 Case PrmModel Of
  mdIsing: Begin
   { H = -J * Somme<i,j> s_i s_j - H Somme_i s_i.
     Boucle sur droit + bas pour ne compter chaque lien qu une fois. }
   Sum := 0;
   For I := 0 To NSites - 1 Do Begin
    Sum := Sum + SpinI[I] * SpinI[SiteRight(I)];
    Sum := Sum + SpinI[I] * SpinI[SiteUp(I)];
   End;
   E := -PrmJ * Sum;
   Sum := 0;
   For I := 0 To NSites - 1 Do Sum := Sum + SpinI[I];
   E := E - PrmH * Sum;
  End;
  mdPotts: Begin
   { H = -J * Somme<i,j> delta(s_i, s_j) }
   Sum := 0;
   For I := 0 To NSites - 1 Do Begin
    If SpinI[I] = SpinI[SiteRight(I)] Then Sum := Sum + 1;
    If SpinI[I] = SpinI[SiteUp(I)]    Then Sum := Sum + 1;
   End;
   E := -PrmJ * Sum;
  End;
  mdXY: Begin
   { H = -J * Somme<i,j> cos(theta_i - theta_j) }
   Sum := 0;
   For I := 0 To NSites - 1 Do Begin
    Sum := Sum + Cos(SpinA[I] - SpinA[SiteRight(I)]);
    Sum := Sum + Cos(SpinA[I] - SpinA[SiteUp(I)]);
   End;
   E := -PrmJ * Sum;
  End;
 End;
 TotalEnergy := E;
End;

Function TotalMag: Real;
{ Aimantation scalaire (Ising/Potts) ou module pour XY.
  Pour Potts q-etat : ordre de Wu m = (q*n_max/N - 1)/(q-1)
                      ou n_max = max sur les etats du nombre de spins
                      dans cet etat. Donne 1 ordonne, ~0 desordonne. }
Var
 I, Best, Cnt: Integer;
 Counts: Array[0..MAX_Q - 1] Of LongInt;
 SX, SY, Sum: Real;
Begin
 Case PrmModel Of
  mdIsing: Begin
   Sum := 0;
   For I := 0 To NSites - 1 Do Sum := Sum + SpinI[I];
   TotalMag := Sum;
  End;
  mdPotts: Begin
   For I := 0 To PrmQ - 1 Do Counts[I] := 0;
   For I := 0 To NSites - 1 Do Inc(Counts[SpinI[I]]);
   Best := 0; Cnt := Counts[0];
   For I := 1 To PrmQ - 1 Do
    If Counts[I] > Cnt Then Begin Cnt := Counts[I]; Best := I; End;
   TotalMag := (PrmQ * Cnt / NSites - 1.0) / (PrmQ - 1) * NSites;
  End;
  mdXY: Begin
   SX := 0; SY := 0;
   For I := 0 To NSites - 1 Do Begin
    SX := SX + Cos(SpinA[I]);
    SY := SY + Sin(SpinA[I]);
   End;
   TotalMag := Sqrt(SX * SX + SY * SY);
  End;
  Else TotalMag := 0;
 End;
End;

{ ============================================================
  MISE A JOUR METROPOLIS
  ============================================================ }

Procedure MetropolisSweepIsing;
Var
 K, S, NSum: Integer;
 DE: Real;
Begin
 For K := 0 To NSites - 1 Do Begin
  S := RngInt(NSites);
  NSum := SpinI[SiteRight(S)] + SpinI[SiteLeft(S)] +
          SpinI[SiteUp(S)]    + SpinI[SiteDown(S)];
  { dE pour un flip s -> -s : dE = 2*J*s*sum + 2*H*s }
  DE := 2.0 * PrmJ * SpinI[S] * NSum + 2.0 * PrmH * SpinI[S];
  If (DE <= 0) Or (RngU < Exp(-Beta * DE)) Then
   SpinI[S] := -SpinI[S];
 End;
End;

Procedure MetropolisSweepPotts;
Var
 K, S, Old, Nw: Integer;
 OldE, NewE: Integer;
 DE: Real;
Begin
 For K := 0 To NSites - 1 Do Begin
  S := RngInt(NSites);
  Old := SpinI[S];
  Nw := RngInt(PrmQ);
  If Nw = Old Then Continue;
  { Nombre de voisins egaux avant et apres }
  OldE := 0; NewE := 0;
  If SpinI[SiteRight(S)] = Old Then Inc(OldE);
  If SpinI[SiteLeft(S)]  = Old Then Inc(OldE);
  If SpinI[SiteUp(S)]    = Old Then Inc(OldE);
  If SpinI[SiteDown(S)]  = Old Then Inc(OldE);
  If SpinI[SiteRight(S)] = Nw  Then Inc(NewE);
  If SpinI[SiteLeft(S)]  = Nw  Then Inc(NewE);
  If SpinI[SiteUp(S)]    = Nw  Then Inc(NewE);
  If SpinI[SiteDown(S)]  = Nw  Then Inc(NewE);
  DE := PrmJ * (OldE - NewE);   { H = -J*delta donc dE = -J*(NewE-OldE) }
  If (DE <= 0) Or (RngU < Exp(-Beta * DE)) Then
   SpinI[S] := Nw;
 End;
End;

Procedure MetropolisSweepXY;
Var
 K, S: Integer;
 Old, Nw, DTheta: Real;
 OldE, NewE: Real;
Begin
 For K := 0 To NSites - 1 Do Begin
  S := RngInt(NSites);
  Old := SpinA[S];
  { Petit deplacement aleatoire : amplitude pi pour eviter blocage }
  DTheta := (RngU - 0.5) * SPMC_PI;
  Nw := Old + DTheta;
  OldE := -PrmJ * (Cos(Old - SpinA[SiteRight(S)]) +
                   Cos(Old - SpinA[SiteLeft(S)])  +
                   Cos(Old - SpinA[SiteUp(S)])    +
                   Cos(Old - SpinA[SiteDown(S)]));
  NewE := -PrmJ * (Cos(Nw  - SpinA[SiteRight(S)]) +
                   Cos(Nw  - SpinA[SiteLeft(S)])  +
                   Cos(Nw  - SpinA[SiteUp(S)])    +
                   Cos(Nw  - SpinA[SiteDown(S)]));
  If (NewE <= OldE) Or (RngU < Exp(-Beta * (NewE - OldE))) Then
   SpinA[S] := Nw;
 End;
End;

Procedure MetropolisSweep;
Begin
 Case PrmModel Of
  mdIsing: MetropolisSweepIsing;
  mdPotts: MetropolisSweepPotts;
  mdXY:    MetropolisSweepXY;
 End;
End;

{ ============================================================
  MISE A JOUR CLUSTER WOLFF (Ising / Potts)
  ============================================================ }

Procedure WolffTryAdd(S, OldVal: Integer; PAdd: Real);
Begin
 If ClInCluster[S] Then Exit;
 If SpinI[S] <> OldVal Then Exit;
 If RngU >= PAdd Then Exit;
 ClInCluster[S] := True;
 ClStack[ClTop] := S;
 Inc(ClTop);
End;

Procedure WolffStepIsing;
Var
 Seed, S, OldVal: Integer;
 PAdd: Real;
 I: Integer;
Begin
 { P_add = 1 - exp(-2*beta*J) pour Ising ferro (s = +/- 1) }
 PAdd := 1.0 - Exp(-2.0 * Beta * PrmJ);
 For I := 0 To NSites - 1 Do ClInCluster[I] := False;
 Seed := RngInt(NSites);
 OldVal := SpinI[Seed];
 ClInCluster[Seed] := True;
 ClStack[0] := Seed;
 ClTop := 1;
 While ClTop > 0 Do Begin
  Dec(ClTop);
  S := ClStack[ClTop];
  WolffTryAdd(SiteRight(S), OldVal, PAdd);
  WolffTryAdd(SiteLeft(S),  OldVal, PAdd);
  WolffTryAdd(SiteUp(S),    OldVal, PAdd);
  WolffTryAdd(SiteDown(S),  OldVal, PAdd);
 End;
 { Flip tout le cluster }
 For I := 0 To NSites - 1 Do
  If ClInCluster[I] Then SpinI[I] := -SpinI[I];
End;

Procedure WolffStepPotts;
Var
 Seed, S, OldVal, NewVal: Integer;
 PAdd: Real;
 I: Integer;
Begin
 { P_add = 1 - exp(-beta*J) pour Potts }
 PAdd := 1.0 - Exp(-Beta * PrmJ);
 For I := 0 To NSites - 1 Do ClInCluster[I] := False;
 Seed := RngInt(NSites);
 OldVal := SpinI[Seed];
 Repeat NewVal := RngInt(PrmQ); Until NewVal <> OldVal;
 ClInCluster[Seed] := True;
 ClStack[0] := Seed;
 ClTop := 1;
 While ClTop > 0 Do Begin
  Dec(ClTop);
  S := ClStack[ClTop];
  WolffTryAdd(SiteRight(S), OldVal, PAdd);
  WolffTryAdd(SiteLeft(S),  OldVal, PAdd);
  WolffTryAdd(SiteUp(S),    OldVal, PAdd);
  WolffTryAdd(SiteDown(S),  OldVal, PAdd);
 End;
 For I := 0 To NSites - 1 Do
  If ClInCluster[I] Then SpinI[I] := NewVal;
End;

Procedure ClusterSweep;
{ Un "sweep" cluster = enchaine plusieurs flips Wolff jusqu a
  approximativement NSites spins touches (decorelation grossiere). }
Var Done: LongInt;
Begin
 Done := 0;
 While Done < NSites Do Begin
  Case PrmModel Of
   mdIsing: WolffStepIsing;
   mdPotts: WolffStepPotts;
   Else Exit;
  End;
  Inc(Done, ClTop);
  { ClTop a ete decremente jusqu a 0 ; on l'a re-utilise mais la
    taille reelle du cluster n est plus dispo. Compteur approximatif :
    on ajoute au moins 1 pour eviter boucle infinie. }
  If ClTop = 0 Then Inc(Done);
 End;
End;

Procedure OneSweep;
Begin
 If PrmUpdate = upCluster Then ClusterSweep Else MetropolisSweep;
End;

{ ============================================================
  MESURE ET BINNING
  ============================================================ }

Procedure ResetAccumulators;
Begin
 AccE := 0; AccE2 := 0;
 AccM := 0; AccAbsM := 0;
 AccM2 := 0; AccM4 := 0;
 AccN := 0;
End;

Procedure DoMeasurement;
Var E, M, AM, M2: Real;
Begin
 E  := TotalEnergy;
 M  := TotalMag;
 AM := Abs(M);
 M2 := M * M;
 AccE    := AccE    + E;
 AccE2   := AccE2   + E * E;
 AccM    := AccM    + M;
 AccAbsM := AccAbsM + AM;
 AccM2   := AccM2   + M2;
 AccM4   := AccM4   + M2 * M2;
 Inc(AccN);
End;

Procedure FlushBin;
Var Inv: Real;
Begin
 If AccN = 0 Then Exit;
 If NBins >= MAX_BINS Then Exit;
 Inv := 1.0 / AccN;
 BinE[NBins]    := AccE    * Inv;
 BinE2[NBins]   := AccE2   * Inv;
 BinAbsM[NBins] := AccAbsM * Inv;
 BinM2[NBins]   := AccM2   * Inv;
 BinM4[NBins]   := AccM4   * Inv;
 Inc(NBins);
 ResetAccumulators;
End;

Procedure StatsOf(Var Arr: Array Of Real; N: Integer;
                  Var Mean, Err: Real);
Var I: Integer; S, S2, M, V: Real;
Begin
 If N <= 0 Then Begin Mean := 0; Err := 0; Exit; End;
 S := 0;
 For I := 0 To N - 1 Do S := S + Arr[I];
 M := S / N;
 If N = 1 Then Begin Mean := M; Err := 0; Exit; End;
 S2 := 0;
 For I := 0 To N - 1 Do Begin
  V := Arr[I] - M;
  S2 := S2 + V * V;
 End;
 { Erreur de la moyenne = sqrt(var / (N-1)) avec var = S2/N }
 Mean := M;
 Err  := Sqrt(S2 / (N * LongInt(N - 1)));
End;

Procedure ComputeStats;
Var
 I: Integer;
 BinC, BinChi, BinBinder: Array[0..MAX_BINS - 1] Of Real;
 N: Real;
 Tmp, Tmp2: Real;
Begin
 N := NSites;
 { Energie par site et erreur }
 For I := 0 To NBins - 1 Do BinE[I] := BinE[I] / N;
 StatsOf(BinE, NBins, ResEnergy, ErrEnergy);
 { |M| par site }
 For I := 0 To NBins - 1 Do BinAbsM[I] := BinAbsM[I] / N;
 StatsOf(BinAbsM, NBins, ResMagAbs, ErrMagAbs);
 { M^2 par site }
 For I := 0 To NBins - 1 Do BinM2[I] := BinM2[I] / N;
 StatsOf(BinM2, NBins, ResMag2, Tmp);
 ErrMag2 := Tmp;
 { Chaleur specifique : C = beta^2 * (<E^2> - <E>^2) / N
   On utilise par-bin pour propager l'erreur. }
 For I := 0 To NBins - 1 Do Begin
  Tmp  := BinE[I] * N;             { remettre E total dans le bin }
  Tmp2 := BinE2[I] - Tmp * Tmp;
  BinC[I] := Beta * Beta * Tmp2 / N;
 End;
 StatsOf(BinC, NBins, ResSpecHeat, ErrSpecHeat);
 { Susceptibilite : chi = beta * (<M^2> - <|M|>^2) / N }
 For I := 0 To NBins - 1 Do Begin
  Tmp  := BinAbsM[I] * N;
  Tmp2 := (BinM2[I] * N) - Tmp * Tmp;
  BinChi[I] := Beta * Tmp2 / N;
 End;
 StatsOf(BinChi, NBins, ResChi, ErrChi);
 { Cumulant de Binder : U = 1 - <M^4>/(3 <M^2>^2) }
 For I := 0 To NBins - 1 Do Begin
  Tmp := BinM2[I] * N;
  If Tmp <= 0 Then BinBinder[I] := 0
  Else BinBinder[I] := 1.0 - BinM4[I] / (3.0 * Tmp * Tmp);
 End;
 StatsOf(BinBinder, NBins, ResBinder, ErrBinder);
End;

{ ============================================================
  CHECKPOINT / TIME LIMIT
  ============================================================ }

Function TimeLimitReached: Boolean;
Var Now: LongInt;
Begin
 If OptTimeLimit <= 0 Then Begin TimeLimitReached := False; Exit; End;
 Now := NowSeconds;
 { Gestion changement de jour (modulo 86400) }
 If Now < StartSec Then Now := Now + 86400;
 TimeLimitReached := (Now - StartSec) >= OptTimeLimit;
End;

Function CheckpointDue: Boolean;
Var Now: LongInt;
Begin
 If OptCheckpoint <= 0 Then Begin CheckpointDue := False; Exit; End;
 Now := NowSeconds;
 If Now < LastCkptSec Then Now := Now + 86400;
 CheckpointDue := (Now - LastCkptSec) >= OptCheckpoint;
End;

{ ============================================================
  SORTIES
  ============================================================ }

Procedure WriteOutputTxt;
Var F: Text; FName: String;
Begin
 FName := OptBaseName + '.out.txt';
 Assign(F, FName);
 Rewrite(F);
 Writeln(F, '# SPINMC v', SPINMC_VERSION, ' - resultats');
 Writeln(F, '# date : ', SPINMC_DATE);
 Writeln(F, '# input: ', OptInFile);
 Writeln(F);
 Writeln(F, '[Parameters]');
 Writeln(F, 'LATTICE        = "', PrmLatticeName, '"');
 Writeln(F, 'MODEL          = "', PrmModelName, '"');
 Writeln(F, 'UPDATE         = "', PrmUpdateName, '"');
 Writeln(F, 'L              = ', PrmL);
 If PrmModel = mdPotts Then
  Writeln(F, 'Q              = ', PrmQ);
 Writeln(F, 'T              = ', FloatToStr(PrmT, 1, 6));
 Writeln(F, 'J              = ', FloatToStr(PrmJ, 1, 6));
 Writeln(F, 'H              = ', FloatToStr(PrmH, 1, 6));
 Writeln(F, 'THERMALIZATION = ', PrmThermalize);
 Writeln(F, 'SWEEPS         = ', PrmSweeps);
 Writeln(F, 'SEED           = ', PrmSeed);
 Writeln(F, 'NBins          = ', NBins);
 Writeln(F);
 Writeln(F, '[Observables]');
 Writeln(F, '# nom            valeur               erreur');
 Writeln(F, 'Energy        = ', FloatToStr(ResEnergy,  14, 8),
                  ' +/- ',     FloatToStr(ErrEnergy,  10, 8));
 Writeln(F, '|Magnetization|= ', FloatToStr(ResMagAbs, 14, 8),
                  ' +/- ',     FloatToStr(ErrMagAbs, 10, 8));
 Writeln(F, 'Magnetization^2= ', FloatToStr(ResMag2,   14, 8),
                  ' +/- ',     FloatToStr(ErrMag2,   10, 8));
 Writeln(F, 'SpecificHeat  = ', FloatToStr(ResSpecHeat,14, 8),
                  ' +/- ',     FloatToStr(ErrSpecHeat,10, 8));
 Writeln(F, 'Susceptibility= ', FloatToStr(ResChi,    14, 8),
                  ' +/- ',     FloatToStr(ErrChi,    10, 8));
 Writeln(F, 'BinderCumulant= ', FloatToStr(ResBinder, 14, 8),
                  ' +/- ',     FloatToStr(ErrBinder, 10, 8));
 Close(F);
 Writeln('  ecrit : ', FName);
End;

Procedure WriteScalarAvg(Var F: Text; Name: String; Mean, Err: Real);
Begin
 Writeln(F, '  <SCALAR_AVERAGE name="', Name, '">');
 Writeln(F, '   <COUNT>', NBins, '</COUNT>');
 Writeln(F, '   <MEAN method="simple">', FloatToSci(Mean), '</MEAN>');
 Writeln(F, '   <ERROR method="binning">', FloatToSci(Err), '</ERROR>');
 Writeln(F, '  </SCALAR_AVERAGE>');
End;

Procedure WriteOutputXml;
Var F: Text; FName: String;
Begin
 FName := OptBaseName + '.out.xml';
 Assign(F, FName);
 Rewrite(F);
 Writeln(F, '<?xml version="1.0" encoding="UTF-8"?>');
 Writeln(F, '<SIMULATION>');
 Writeln(F, ' <PARAMETERS>');
 Writeln(F, '  <PARAMETER name="LATTICE">"', PrmLatticeName, '"</PARAMETER>');
 Writeln(F, '  <PARAMETER name="MODEL">"',   PrmModelName,   '"</PARAMETER>');
 Writeln(F, '  <PARAMETER name="UPDATE">"',  PrmUpdateName,  '"</PARAMETER>');
 Writeln(F, '  <PARAMETER name="L">', PrmL, '</PARAMETER>');
 If PrmModel = mdPotts Then
  Writeln(F, '  <PARAMETER name="Q">', PrmQ, '</PARAMETER>');
 Writeln(F, '  <PARAMETER name="T">', FloatToSci(PrmT), '</PARAMETER>');
 Writeln(F, '  <PARAMETER name="J">', FloatToSci(PrmJ), '</PARAMETER>');
 Writeln(F, '  <PARAMETER name="H">', FloatToSci(PrmH), '</PARAMETER>');
 Writeln(F, '  <PARAMETER name="THERMALIZATION">', PrmThermalize,
            '</PARAMETER>');
 Writeln(F, '  <PARAMETER name="SWEEPS">', PrmSweeps, '</PARAMETER>');
 Writeln(F, '  <PARAMETER name="SEED">',   PrmSeed,   '</PARAMETER>');
 Writeln(F, ' </PARAMETERS>');
 Writeln(F, ' <AVERAGES>');
 WriteScalarAvg(F, 'Energy',          ResEnergy,   ErrEnergy);
 WriteScalarAvg(F, '|Magnetization|', ResMagAbs,   ErrMagAbs);
 WriteScalarAvg(F, 'Magnetization^2', ResMag2,     ErrMag2);
 WriteScalarAvg(F, 'Specific Heat',   ResSpecHeat, ErrSpecHeat);
 WriteScalarAvg(F, 'Susceptibility',  ResChi,      ErrChi);
 WriteScalarAvg(F, 'Binder Cumulant', ResBinder,   ErrBinder);
 Writeln(F, ' </AVERAGES>');
 Writeln(F, '</SIMULATION>');
 Close(F);
 Writeln('  ecrit : ', FName);
End;

Procedure Checkpoint;
Begin
 LastCkptSec := NowSeconds;
 { Sortie partielle des bins courants }
 If NBins > 0 Then Begin
  ComputeStats;
  WriteOutputTxt;
  If OptWriteXml Then WriteOutputXml;
 End;
End;

{ ============================================================
  CLI
  ============================================================ }

Procedure ShowUsage;
Begin
 Writeln('SPINMC - Cette commande permet d''ex'+#130+'cuter une ',
        'simulation Monte-Carlo de syst'+#138+'mes de spins (tels ',
        'que les mod'+#138+'les d''Ising, XY ou Heisenberg) '+#133,
        ' partir d''un fichier de param'+#138+'tres, afin de calculer ',
        'diverses propri'+#130+'t'+#130+'s physiques comme l'''+#130,'nergie, ',
        'l''aimantation et la susceptibilit‚ magn‚tique.');
 WriteLn;
 Writeln('Syntaxe : SPINMC [options] fichier.in.xml');
 WriteLn;
 Writeln('Options :');
 Writeln('  --time-limit <s>      duree maxi (s)');
 Writeln('  --checkpoint-time <s> intervalle sauvegarde (s)');
 Writeln('  --Tmin <s>            poll mini (s)');
 Writeln('  --Tmax <s>            poll maxi (s)');
 Writeln('  --write-xml           ecrit aussi .out.xml');
 Writeln('  --help                affiche cette aide');
 Writeln;
 Writeln('Le fichier peut etre au format .parm (KEY=VALUE) ou .in.xml.');
 Writeln('Clefs : LATTICE, MODEL (Ising/Potts/XY), UPDATE (local/cluster),');
 Writeln('        L, Q, T, J, H, THERMALIZATION, SWEEPS, SEED.');
End;

Procedure SetDefaults;
Begin
 PrmModel        := mdIsing;
 PrmUpdate       := upLocal;
 PrmL            := 16;
 PrmQ            := 3;
 PrmT            := 2.269;     { ~ T_c Ising 2D }
 PrmJ            := 1.0;
 PrmH            := 0.0;
 PrmThermalize   := 1000;
 PrmSweeps       := 10000;
 PrmSeed         := 12345;
 PrmLatticeName  := 'square lattice';
 PrmModelName    := 'Ising';
 PrmUpdateName   := 'local';

 OptTimeLimit    := 0;          { illimite }
 OptCheckpoint   := 0;
 OptTmin         := 60;
 OptTmax         := 900;
 OptWriteXml     := False;
 OptHelp         := False;
 OptInFile       := '';
End;

Procedure ParseCLI;
Var
 I: Integer;
 A, V: String;
Begin
 I := 1;
 While I <= ParamCount Do Begin
  A := ParamStr(I);
  If (A = '--help') Or (A = '-h') Or (A = '/?') Then
   OptHelp := True
  Else If A = '--write-xml' Then
   OptWriteXml := True
  Else If (A = '--time-limit') Or (A = '--checkpoint-time') Or
          (A = '--Tmin')       Or (A = '--Tmax') Or
          (A = '--Nmin')       Or (A = '--Nmax') Then Begin
   Inc(I);
   If I > ParamCount Then Begin
    Writeln('SPINMC: valeur manquante pour ', A); Halt(1);
   End;
   V := ParamStr(I);
   If A = '--time-limit'      Then OptTimeLimit  := StrToIntDef(V, 0)
   Else If A = '--checkpoint-time' Then OptCheckpoint := StrToIntDef(V, 0)
   Else If A = '--Tmin'       Then OptTmin       := StrToIntDef(V, 60)
   Else If A = '--Tmax'       Then OptTmax       := StrToIntDef(V, 900);
   { --Nmin/--Nmax acceptes mais ignores (mono-processus) }
  End
  Else If A = '--mpi' Then
   { MPI non supporte, ignore silencieusement }
  Else If (Length(A) >= 2) And (A[1] = '-') And (A[2] = '-') Then Begin
   Writeln('SPINMC: option inconnue ', A);
   Halt(1);
  End
  Else
   OptInFile := A;
  Inc(I);
 End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }

Var
 ISweep, IThermo: LongInt;
 PrintEvery: LongInt;
 NextPrint: LongInt;

BEGIN
 SetDefaults;
 ParseCLI;

 If OptHelp Then Begin ShowUsage; Halt(0); End;

 If OptInFile = '' Then Begin
  Writeln('SPINMC: fichier d entree manquant.');
  Writeln('Essayez : SPINMC --help');
  Halt(1);
 End;

 Writeln('SPINMC v', SPINMC_VERSION, ' - lecture ', OptInFile);
 ReadParameterFile(OptInFile);
 OptBaseName := BaseName(OptInFile);

 ResolveModel;
 If PrmL < 2 Then PrmL := 2;
 If PrmL > MAX_L Then Begin
  Writeln('SPINMC: L=', PrmL, ' > MAX_L=', MAX_L, ', reduit a ', MAX_L);
  PrmL := MAX_L;
 End;
 If PrmQ < 2 Then PrmQ := 2;
 If PrmQ > MAX_Q Then PrmQ := MAX_Q;
 If PrmT <= 0 Then PrmT := 0.001;
 Beta := 1.0 / PrmT;

 RngSeed(PrmSeed);
 StartSec    := NowSeconds;
 LastCkptSec := StartSec;

 Writeln('  modele  = ', PrmModelName, '  (update : ',
         PrmUpdateName, ')');
 Writeln('  reseau  = ', PrmLatticeName, '  L=', PrmL,
         '  (', PrmL * PrmL, ' sites)');
 If PrmModel = mdPotts Then
  Writeln('  q       = ', PrmQ);
 Writeln('  T       = ', FloatToStr(PrmT, 1, 6),
         '  J=', FloatToStr(PrmJ, 1, 6),
         '  H=', FloatToStr(PrmH, 1, 6));
 Writeln('  THERM   = ', PrmThermalize, '   SWEEPS = ', PrmSweeps);
 Writeln('  SEED    = ', PrmSeed);
 Writeln;

 InitSpins;

 { Thermalisation }
 Writeln('Thermalisation...');
 For IThermo := 1 To PrmThermalize Do Begin
  OneSweep;
  If TimeLimitReached Then Begin
   Writeln('  arret : time-limit atteint en thermalisation.');
   Halt(0);
  End;
 End;
 Writeln('  thermalisation terminee.');

 { Mesures }
 NBins := 0;
 ResetAccumulators;
 BinSize := PrmSweeps Div MAX_BINS;
 If BinSize < 1 Then BinSize := 1;
 PrintEvery := PrmSweeps Div 20;
 If PrintEvery < 1 Then PrintEvery := 1;
 NextPrint := PrintEvery;

 Writeln('Mesures (', MAX_BINS, ' bins de ~', BinSize, ' sweeps)...');
 For ISweep := 1 To PrmSweeps Do Begin
  OneSweep;
  DoMeasurement;
  If (AccN >= BinSize) And (NBins < MAX_BINS) Then FlushBin;
  If ISweep >= NextPrint Then Begin
   Write('  ', (ISweep * 100) Div PrmSweeps:3, '% (sweep ',
         ISweep, '/', PrmSweeps, ')'#13);
   NextPrint := NextPrint + PrintEvery;
  End;
  If CheckpointDue Then Checkpoint;
  If TimeLimitReached Then Begin
   Writeln;
   Writeln('  arret : time-limit atteint a sweep ', ISweep);
   Break;
  End;
 End;
 Writeln;
 If AccN > 0 Then FlushBin;
 Writeln('  mesures terminees : ', NBins, ' bins.');

 ComputeStats;

 Writeln;
 Writeln('Resultats :');
 Writeln('  Energy/site     = ', FloatToStr(ResEnergy, 10, 6),
         ' +/- ', FloatToStr(ErrEnergy, 8, 6));
 Writeln('  |M|/site        = ', FloatToStr(ResMagAbs, 10, 6),
         ' +/- ', FloatToStr(ErrMagAbs, 8, 6));
 Writeln('  C (chaleur sp.) = ', FloatToStr(ResSpecHeat, 10, 6),
         ' +/- ', FloatToStr(ErrSpecHeat, 8, 6));
 Writeln('  chi (suscept.)  = ', FloatToStr(ResChi, 10, 6),
         ' +/- ', FloatToStr(ErrChi, 8, 6));
 Writeln('  U (Binder)      = ', FloatToStr(ResBinder, 10, 6),
         ' +/- ', FloatToStr(ErrBinder, 8, 6));
 Writeln;

 WriteOutputTxt;
 If OptWriteXml Then WriteOutputXml;
END.
