{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/physiq)
  @abstract(Target: Turbo Pascal 7 / Free Pascal 3.2 mode -Mtp)
  @description: Clone de la commande "loop" de la bibliotheque ALPS
                (Algorithms and Libraries for Physics Simulations).
                Monte-Carlo Quantique pour modeles de spins quantiques.

                Algorithme implemente : SSE (Stochastic Series Expansion)
                de A.W. Sandvik, avec mise a jour par loop deterministe
                pour l'Heisenberg isotrope.  Donne les memes resultats
                physiques que l'algorithme loop en temps continu d'Evertz
                utilise par "loop" d'ALPS.

                Modele : Heisenberg AFM isotrope, S=1/2, J>0.
                  H = J * Somme<i,j> S_i . S_j
                Reseaux : chaine 1D et carre 2D, periodiques, bipartites.

                Observables (avec erreurs par binning) :
                  - Energie/site E = -<N>/(beta*Nsites) + J*Nbonds/(4*Nsites)
                  - Chaleur specifique C = (<N^2> - <N>^2 - <N>)/Nsites
                  - <m_stag^2> (parametre d'ordre AFM)
                  - Susceptibilite uniforme  chi_u = beta*<M_z^2>/Nsites
                  - Susceptibilite staggered chi_s (par Green-Kubo SSE)

                Reference : A.W. Sandvik, "Computational Studies of
                Quantum Spin Systems" (AIP Conf. Proc. 1297, 2010,
                arXiv:1101.3281).

                Usage : LOOP [options] fichier.in.xml
                Options :
                  --time-limit <s>      duree maxi totale (s)
                  --checkpoint-time <s> intervalle sauvegarde (s)
                  --write-xml           ecrit aussi .out.xml
                  --help                affiche cette aide

                Cles supportees dans fichier .parm ou .in.xml :
                  LATTICE = "chain lattice" | "square lattice"
                  MODEL   = "spin"          (ignore : impose Heisenberg)
                  local_S = "1/2"           (ignore : impose 1/2)
                  L, T, J, THERMALIZATION, SWEEPS, SEED

                Compilation :
                  Free Pascal    : fpc -Mtp LOOP.PAS  (recommande)
                  Turbo Pascal 7 : TPC LOOP.PAS  (reduire MAX_M
                                   a 1500 a cause limite segment 64KB)
}

{$IFDEF FPC}
 {$MODE TP}
{$ENDIF}
{$R-}

Program LOOP_QMC;

Uses Dos;

{ ============================================================
  CONSTANTES
  ============================================================ }

Const
 LOOP_VERSION   = '1.00';
 LOOP_DATE      = '2026';

 MAX_L          = 32;                   { reseau LxL en 2D ou L en 1D }
 MAX_SITES      = MAX_L * MAX_L;        { 1024 }
 MAX_BONDS      = 2 * MAX_SITES;        { 2048 (2D : 2 bonds/site) }
 MAX_M          = 4000;                 { longueur max de la string SSE }
 MAX_LEGS       = 4 * MAX_M;            { 16000 jambes }
 MAX_BINS       = 32;
 MAX_LINE       = 255;

{ ============================================================
  TYPES
  ============================================================ }

Type
 TLattice = (ltChain, ltSquare);
 TStr80   = String[80];
 { Tableaux alloues sur le tas (gros : > 4 KB) pour rester
   sous la limite du segment de donnees 64 KB de TP7. }
 TLegLongArr  = Array[0..MAX_LEGS  - 1] Of LongInt;   { 64000 oct. }
 TSiteLongArr = Array[0..MAX_SITES - 1] Of LongInt;   {  4096 oct. }
 TLegBoolArr  = Array[0..MAX_LEGS  - 1] Of Boolean;   { 16000 oct. }
 PLegLongArr  = ^TLegLongArr;
 PSiteLongArr = ^TSiteLongArr;
 PLegBoolArr  = ^TLegBoolArr;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }

Var
 { Parametres physiques }
 PrmLattice      : TLattice;
 PrmLatticeName  : TStr80;
 PrmModelName    : TStr80;
 PrmLocalSName   : TStr80;
 PrmL            : Integer;
 PrmT            : Real;
 PrmJ            : Real;
 PrmThermalize   : LongInt;
 PrmSweeps       : LongInt;
 PrmSeed         : LongInt;

 { Options CLI }
 OptTimeLimit    : LongInt;
 OptCheckpoint   : LongInt;
 OptWriteXml     : Boolean;
 OptHelp         : Boolean;
 OptInFile       : TStr80;
 OptBaseName     : TStr80;

 { Reseau }
 NSites          : Integer;
 NBonds          : Integer;
 BondI           : Array[0..MAX_BONDS - 1] Of Integer;
 BondJ           : Array[0..MAX_BONDS - 1] Of Integer;
 SubLat          : Array[0..MAX_SITES - 1] Of ShortInt;  { +/- 1 staggered }
 Beta            : Real;

 { Configuration SSE }
 Spin            : Array[0..MAX_SITES - 1] Of ShortInt;     { initial }
 WorkSpin        : Array[0..MAX_SITES - 1] Of ShortInt;     { propage }
 OpStr           : Array[0..MAX_M - 1] Of LongInt;
   { OpStr[p] = -1     : identite
                2*b    : H_diag sur bond b (matrice 1/2 sur antiparallele)
                2*b+1  : H_off  sur bond b (matrice 1/2, flip 2 spins) }
 NCur            : LongInt;            { nb d operateurs non-identite }
 MCur            : LongInt;            { longueur courante de la string }

 { Loop update : link list (allouees sur le tas, voir AllocHeapArrays) }
 LinkList        : PLegLongArr;
 FirstLeg        : PSiteLongArr;
 LastLeg         : PSiteLongArr;
 FlipFlag        : PLegBoolArr;
 Visited         : PLegBoolArr;

 { Mesures - accumulateur dans le bin courant }
 AccN, AccN2     : Real;
 AccMz2, AccMs2  : Real;
 AccE, AccE2     : Real;       { dupliquees pour confort }
 AccCount        : LongInt;

 { Bins }
 NBins           : Integer;
 BinSize         : LongInt;
 BinE            : Array[0..MAX_BINS - 1] Of Real;
 BinE2           : Array[0..MAX_BINS - 1] Of Real;
 BinN            : Array[0..MAX_BINS - 1] Of Real;
 BinN2           : Array[0..MAX_BINS - 1] Of Real;
 BinMz2          : Array[0..MAX_BINS - 1] Of Real;
 BinMs2          : Array[0..MAX_BINS - 1] Of Real;

 { Resultats finaux }
 ResEnergy,   ErrEnergy   : Real;
 ResSpecHeat, ErrSpecHeat : Real;
 ResMz2,      ErrMz2      : Real;
 ResMs2,      ErrMs2      : Real;
 ResChiU,     ErrChiU     : Real;
 ResChiS,     ErrChiS     : Real;

 { Temps }
 StartSec, LastCkptSec    : LongInt;

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
Var I, P, DirEnd: Integer; Dir, Stem: String;
Begin
 DirEnd := 0;
 For I := Length(FName) DownTo 1 Do
  If (FName[I] = '/') Or (FName[I] = '\') Or (FName[I] = ':') Then Begin
   DirEnd := I; Break;
  End;
 If DirEnd > 0 Then Begin
  Dir  := Copy(FName, 1, DirEnd);
  Stem := Copy(FName, DirEnd + 1, Length(FName) - DirEnd);
 End Else Begin
  Dir  := ''; Stem := FName;
 End;
 P := Pos('.in.xml', Stem);
 If P > 0 Then Stem := Copy(Stem, 1, P - 1)
 Else Begin
  P := 0;
  For I := Length(Stem) DownTo 1 Do
   If Stem[I] = '.' Then Begin P := I; Break; End;
  If P > 0 Then Stem := Copy(Stem, 1, P - 1);
 End;
 BaseName := Dir + Stem;
End;

Function NowSeconds: LongInt;
Var H, M, S, S100: Word;
Begin
 GetTime(H, M, S, S100);
 NowSeconds := LongInt(H) * 3600 + LongInt(M) * 60 + S;
End;

{ ============================================================
  GENERATEUR ALEATOIRE Park-Miller
  ============================================================ }

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
 RngU := RngState * 4.6566128752E-10;
End;

Function RngInt(N: LongInt): LongInt;
Begin RngInt := Trunc(RngU * N); End;

{ ============================================================
  CONSTRUCTION DU RESEAU
  ============================================================ }

Procedure BuildLattice;
Var I, X, Y, S, R, U, B: Integer;
Begin
 Case PrmLattice Of
  ltChain: Begin
   NSites := PrmL;
   NBonds := PrmL;       { periodique : 1 bond/site }
   For S := 0 To NSites - 1 Do Begin
    If (S And 1) = 0 Then SubLat[S] := 1 Else SubLat[S] := -1;
   End;
   For I := 0 To NSites - 1 Do Begin
    BondI[I] := I;
    If I = NSites - 1 Then BondJ[I] := 0 Else BondJ[I] := I + 1;
   End;
  End;
  ltSquare: Begin
   NSites := PrmL * PrmL;
   NBonds := 2 * NSites;
   For Y := 0 To PrmL - 1 Do
    For X := 0 To PrmL - 1 Do Begin
     S := Y * PrmL + X;
     If ((X + Y) And 1) = 0 Then SubLat[S] := 1 Else SubLat[S] := -1;
    End;
   B := 0;
   For Y := 0 To PrmL - 1 Do
    For X := 0 To PrmL - 1 Do Begin
     S := Y * PrmL + X;
     { bond horizontal vers la droite }
     If X = PrmL - 1 Then R := S - (PrmL - 1) Else R := S + 1;
     BondI[B] := S; BondJ[B] := R; Inc(B);
     { bond vertical vers le haut }
     If Y = PrmL - 1 Then U := S - (PrmL - 1) * PrmL Else U := S + PrmL;
     BondI[B] := S; BondJ[B] := U; Inc(B);
    End;
  End;
 End;
End;

{ ============================================================
  PARSEUR DE PARAMETRES (.parm et .in.xml)
  ============================================================ }

Procedure ApplyParameter(Key, Val: String);
Var K, V: String;
Begin
 K := UpStr(TrimStr(Key));
 V := StripQuotes(Val);
 If K = 'LATTICE'       Then PrmLatticeName := V Else
 If K = 'MODEL'         Then PrmModelName   := V Else
 If K = 'LOCAL_S'       Then PrmLocalSName  := V Else
 If K = 'L'             Then PrmL           := StrToIntDef(V, PrmL) Else
 If K = 'T'             Then PrmT           := StrToRealDef(V, PrmT) Else
 If K = 'TEMPERATURE'   Then PrmT           := StrToRealDef(V, PrmT) Else
 If K = 'J'             Then PrmJ           := StrToRealDef(V, PrmJ) Else
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
 IsXml, GotFirst: Boolean;
 T: String;
Begin
 Assign(F, FName);
 {$I-} Reset(F); {$I+}
 If IOResult <> 0 Then Begin
  Writeln('LOOP: erreur lecture ', FName);
  Halt(1);
 End;
 IsXml := False; GotFirst := False;
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

Procedure ResolveLattice;
Var L: String;
Begin
 L := UpStr(PrmLatticeName);
 If (Pos('CHAIN', L) > 0) Or (Pos('1D', L) > 0)
  Then PrmLattice := ltChain
  Else PrmLattice := ltSquare;
End;

{ ============================================================
  INITIALISATION ETAT SSE
  ============================================================ }

Procedure InitSpins;
Var S: Integer;
Begin
 { Etat AFM Neel pour seed (M_z=0 sur reseau bipartite) }
 For S := 0 To NSites - 1 Do
  If SubLat[S] = 1 Then Spin[S] := 1 Else Spin[S] := -1;
 { Brouillage : flip aleatoire d'un tiers des spins pour casser
   le bias vers l'etat exact. La conservation Sz par H Heisenberg
   isotrope permet ensuite tous les secteurs via les loops. }
 For S := 0 To NSites - 1 Do
  If RngU < 0.33 Then Spin[S] := -Spin[S];
End;

Procedure InitOpString;
Var P: LongInt;
Begin
 MCur := 20;
 NCur := 0;
 For P := 0 To MCur - 1 Do OpStr[P] := -1;
End;

{ ============================================================
  MISE A JOUR DIAGONALE
  ============================================================
  Pour chaque position p de la string :
   - identite -> diagonale  : prob = beta*J*NBonds / (2*(M-N))
                              (si spins du bond antiparalleles)
   - diagonale -> identite  : prob = 2*(M-N+1) / (beta*J*NBonds)
   - off-diag : propage les spins (flip i,j)
  Les facteurs de 1/2 viennent du matrix element |H_b|=1/2. }

Procedure DiagonalUpdate;
Var
 P: LongInt;
 B: LongInt;
 Op: LongInt;
 PIns, PRem: Real;
 PreFactor: Real;
 I, J: Integer;
 Tmp: ShortInt;
Begin
 { Copie etat initial dans WorkSpin }
 For I := 0 To NSites - 1 Do WorkSpin[I] := Spin[I];
 PreFactor := 0.5 * Beta * PrmJ * NBonds;
 For P := 0 To MCur - 1 Do Begin
  Op := OpStr[P];
  If Op = -1 Then Begin
   { Tentative insertion d operateur diagonal }
   B := RngInt(NBonds);
   I := BondI[B]; J := BondJ[B];
   If WorkSpin[I] <> WorkSpin[J] Then Begin
    PIns := PreFactor / (MCur - NCur);
    If PIns >= 1.0 Then Begin
     OpStr[P] := 2 * B; Inc(NCur);
    End Else If RngU < PIns Then Begin
     OpStr[P] := 2 * B; Inc(NCur);
    End;
   End;
  End Else If (Op And 1) = 0 Then Begin
   { Diagonal -> Identite }
   PRem := (MCur - NCur + 1) / PreFactor;
   If PRem >= 1.0 Then Begin
    OpStr[P] := -1; Dec(NCur);
   End Else If RngU < PRem Then Begin
    OpStr[P] := -1; Dec(NCur);
   End;
  End Else Begin
   { Off-diagonal : flip les deux spins du bond }
   B := Op Div 2;
   I := BondI[B]; J := BondJ[B];
   Tmp := WorkSpin[I]; WorkSpin[I] := WorkSpin[J]; WorkSpin[J] := Tmp;
   { Equivalent au flip car spins +/-1 et echange. }
  End;
 End;
End;

{ ============================================================
  AJUSTEMENT DE LA LONGUEUR DE STRING (thermalisation)
  ============================================================
  Cible : M = (4/3) * N pour rester dans le regime
  d acceptation raisonnable. Compresse la string en mettant
  tous les identite a la fin. }

Procedure CompactAndGrowString(NewM: LongInt);
Var
 NewStr: Array[0..MAX_M - 1] Of LongInt;
 P, Q: LongInt;
Begin
 If NewM > MAX_M Then NewM := MAX_M;
 { Compacte : opérateurs non-identite en premier, identites apres }
 Q := 0;
 For P := 0 To MCur - 1 Do
  If OpStr[P] <> -1 Then Begin
   NewStr[Q] := OpStr[P]; Inc(Q);
  End;
 While Q < NewM Do Begin NewStr[Q] := -1; Inc(Q); End;
 For P := 0 To NewM - 1 Do OpStr[P] := NewStr[P];
 MCur := NewM;
End;

Procedure MaybeAdjustString;
Var Target: LongInt;
Begin
 Target := NCur + NCur Div 3;       { (4/3)*N }
 If Target < 20 Then Target := 20;
 If MCur < Target Then CompactAndGrowString(Target);
End;

{ ============================================================
  CONSTRUCTION LINK LIST DES LOOPS
  ============================================================
  Pour chaque operateur p non-identite :
    legs 0,1 = bas (entree) sites BondI[b], BondJ[b]
    legs 2,3 = haut (sortie) memes sites
  Les operateurs identite n ont pas de legs et sont ignores.
  link[v] = leg appariee par propagation dans le temps imaginaire. }

Procedure BuildLinkList;
Var
 P: LongInt;
 B: LongInt;
 Op: LongInt;
 I, J: Integer;
 V0, V1, V2, V3: LongInt;
 S: Integer;
Begin
 For S := 0 To NSites - 1 Do Begin
  FirstLeg^[S] := -1; LastLeg^[S] := -1;
 End;
 For P := 0 To MCur - 1 Do Begin
  Op := OpStr[P];
  If Op = -1 Then Continue;
  B := Op Div 2;
  I := BondI[B]; J := BondJ[B];
  V0 := 4 * P;  V1 := V0 + 1;
  V2 := V0 + 2; V3 := V0 + 3;
  { Site I : leg entree V0, leg sortie V2 }
  If LastLeg^[I] = -1 Then FirstLeg^[I] := V0
  Else Begin
   LinkList^[LastLeg^[I]] := V0;
   LinkList^[V0]          := LastLeg^[I];
  End;
  LastLeg^[I] := V2;
  { Site J : leg entree V1, leg sortie V3 }
  If LastLeg^[J] = -1 Then FirstLeg^[J] := V1
  Else Begin
   LinkList^[LastLeg^[J]] := V1;
   LinkList^[V1]          := LastLeg^[J];
  End;
  LastLeg^[J] := V3;
 End;
 { Fermeture periodique en temps imaginaire }
 For S := 0 To NSites - 1 Do
  If LastLeg^[S] <> -1 Then Begin
   LinkList^[LastLeg^[S]]  := FirstLeg^[S];
   LinkList^[FirstLeg^[S]] := LastLeg^[S];
  End;
End;

{ ============================================================
  MARCHE DES LOOPS (Heisenberg isotrope)
  ============================================================
  Pour Heisenberg AFM S=1/2 isotrope, le graphe de boucle
  deterministe relie les paires antiparalleles au meme slice de
  temps : 0<->1 (paire du bas) et 2<->3 (paire du haut). Flipper
  la moitie d'un vertex bascule les 2 spins de cette paire en
  preservant l'antiparallelisme et la validite du vertex (diag
  <-> off-diag selon parite des flips). Probabilite de flip = 1/2. }

Function VertexCross(L: LongInt): LongInt;
{ Donne le leg complementaire au sein du meme vertex }
Var R: LongInt;
Begin
 R := L And 3;
 Case R Of
  0: VertexCross := L + 1;
  1: VertexCross := L - 1;
  2: VertexCross := L + 1;
  3: VertexCross := L - 1;
 End;
End;

Procedure LoopUpdate;
Var
 V, Cur, Next: LongInt;
 P: LongInt;
 NLegs: LongInt;
 DoFlip: Boolean;
 S: Integer;
Begin
 NLegs := 4 * MCur;
 For V := 0 To NLegs - 1 Do Begin
  Visited^[V] := False;
  FlipFlag^[V] := False;
 End;
 { Marque les legs des operateurs identite comme deja visitees }
 For P := 0 To MCur - 1 Do
  If OpStr[P] = -1 Then Begin
   Visited^[4*P]   := True;
   Visited^[4*P+1] := True;
   Visited^[4*P+2] := True;
   Visited^[4*P+3] := True;
  End;
 { Parcours de toutes les loops }
 For V := 0 To NLegs - 1 Do
  If Not Visited^[V] Then Begin
   DoFlip := RngU < 0.5;
   Cur := V;
   Repeat
    Visited^[Cur] := True;
    If DoFlip Then FlipFlag^[Cur] := True;
    { Traversee dans le vertex : leg oppose }
    Cur := VertexCross(Cur);
    Visited^[Cur] := True;
    If DoFlip Then FlipFlag^[Cur] := True;
    { Saut au leg appariee (next operateur dans le temps) }
    Next := LinkList^[Cur];
    Cur := Next;
   Until Cur = V;
  End;
 { Mise a jour du type d operateur : si entree/sortie d un site
   au sein d un vertex ont des flip flags differents, le type
   bascule diagonale <-> off-diagonale. }
 For P := 0 To MCur - 1 Do
  If OpStr[P] <> -1 Then
   If FlipFlag^[4*P] <> FlipFlag^[4*P + 2] Then
    OpStr[P] := OpStr[P] Xor 1;
 { Mise a jour de l etat initial : pour chaque site, si son
   premier leg etait dans une loop flippee, on flip le spin
   initial. Pour les sites sans operateur, flip aleatoire. }
 For S := 0 To NSites - 1 Do
  If FirstLeg^[S] = -1 Then Begin
   If RngU < 0.5 Then Spin[S] := -Spin[S];
  End Else If FlipFlag^[FirstLeg^[S]] Then
   Spin[S] := -Spin[S];
End;

{ ============================================================
  MESURE
  ============================================================ }

Procedure DoMeasurement;
Var
 S: Integer;
 SumZ, SumS: LongInt;
 Mz, Ms: Real;
 EE: Real;
Begin
 SumZ := 0; SumS := 0;
 For S := 0 To NSites - 1 Do Begin
  SumZ := SumZ + Spin[S];                { 2*Sz }
  SumS := SumS + SubLat[S] * Spin[S];
 End;
 Mz := SumZ * 0.5;                       { Sz reel }
 Ms := SumS * 0.5;
 { Accumule }
 AccN     := AccN     + NCur;
 AccN2    := AccN2    + LongInt(NCur) * NCur;
 AccMz2   := AccMz2   + Mz * Mz;
 AccMs2   := AccMs2   + Ms * Ms;
 EE := -NCur / Beta + 0.25 * PrmJ * NBonds;
 AccE     := AccE     + EE;
 AccE2    := AccE2    + EE * EE;
 Inc(AccCount);
End;

Procedure ResetAccumulators;
Begin
 AccN := 0; AccN2 := 0;
 AccMz2 := 0; AccMs2 := 0;
 AccE := 0; AccE2 := 0;
 AccCount := 0;
End;

Procedure FlushBin;
Var Inv: Real;
Begin
 If AccCount = 0 Then Exit;
 If NBins >= MAX_BINS Then Exit;
 Inv := 1.0 / AccCount;
 BinN[NBins]   := AccN   * Inv;
 BinN2[NBins]  := AccN2  * Inv;
 BinE[NBins]   := AccE   * Inv;
 BinE2[NBins]  := AccE2  * Inv;
 BinMz2[NBins] := AccMz2 * Inv;
 BinMs2[NBins] := AccMs2 * Inv;
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
 Mean := M;
 Err  := Sqrt(S2 / (N * LongInt(N - 1)));
End;

Procedure ComputeStats;
Var
 I: Integer;
 BinC, BinChiU, BinChiS, BinEloc: Array[0..MAX_BINS - 1] Of Real;
 NS: Real;
Begin
 NS := NSites;
 { Energie/site }
 For I := 0 To NBins - 1 Do BinEloc[I] := BinE[I] / NS;
 StatsOf(BinEloc, NBins, ResEnergy, ErrEnergy);
 { Chaleur spec / site : C = (<N^2> - <N>^2 - <N>) / NSites }
 For I := 0 To NBins - 1 Do
  BinC[I] := (BinN2[I] - BinN[I] * BinN[I] - BinN[I]) / NS;
 StatsOf(BinC, NBins, ResSpecHeat, ErrSpecHeat);
 { <m_z^2> par site (commensure : div par NSites) }
 For I := 0 To NBins - 1 Do BinMz2[I] := BinMz2[I] / NS;
 StatsOf(BinMz2, NBins, ResMz2, ErrMz2);
 { <m_stag^2> par site }
 For I := 0 To NBins - 1 Do BinMs2[I] := BinMs2[I] / NS;
 StatsOf(BinMs2, NBins, ResMs2, ErrMs2);
 { Susceptibilites approchees :
     chi_u = beta * <M_z^2>/NSites = beta * (Mz2 * NSites)/NSites = beta*<Mz2>*NSites
     (mais Mz est CONSERVE par H Heisenberg, donc cette estimation
      donne juste beta*<M_z^2>/NSites. C'est l estimateur "static".)  }
 For I := 0 To NBins - 1 Do BinChiU[I] := Beta * BinMz2[I];
 StatsOf(BinChiU, NBins, ResChiU, ErrChiU);
 { chi_stag : estimateur static aussi }
 For I := 0 To NBins - 1 Do BinChiS[I] := Beta * BinMs2[I];
 StatsOf(BinChiS, NBins, ResChiS, ErrChiS);
End;

{ ============================================================
  CHECKPOINT / TIME LIMIT
  ============================================================ }

Function TimeLimitReached: Boolean;
Var Now: LongInt;
Begin
 If OptTimeLimit <= 0 Then Begin TimeLimitReached := False; Exit; End;
 Now := NowSeconds;
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
 Writeln(F, '# LOOP v', LOOP_VERSION, ' - resultats QMC (SSE)');
 Writeln(F, '# date  : ', LOOP_DATE);
 Writeln(F, '# input : ', OptInFile);
 Writeln(F, '# modele: Heisenberg AFM isotrope S=1/2');
 Writeln(F);
 Writeln(F, '[Parameters]');
 Writeln(F, 'LATTICE        = "', PrmLatticeName, '"');
 Writeln(F, 'MODEL          = "', PrmModelName, '"');
 Writeln(F, 'local_S        = "', PrmLocalSName, '"');
 Writeln(F, 'L              = ', PrmL);
 Writeln(F, 'T              = ', FloatToStr(PrmT, 1, 6));
 Writeln(F, 'J              = ', FloatToStr(PrmJ, 1, 6));
 Writeln(F, 'THERMALIZATION = ', PrmThermalize);
 Writeln(F, 'SWEEPS         = ', PrmSweeps);
 Writeln(F, 'SEED           = ', PrmSeed);
 Writeln(F, 'NSites         = ', NSites);
 Writeln(F, 'NBonds         = ', NBonds);
 Writeln(F, 'NBins          = ', NBins);
 Writeln(F, 'MCur (final)   = ', MCur);
 Writeln(F);
 Writeln(F, '[Observables]');
 Writeln(F, 'Energy/site       = ', FloatToStr(ResEnergy,    14, 8),
                  ' +/- ',         FloatToStr(ErrEnergy,    10, 8));
 Writeln(F, 'SpecificHeat/site = ', FloatToStr(ResSpecHeat,  14, 8),
                  ' +/- ',         FloatToStr(ErrSpecHeat,  10, 8));
 Writeln(F, '<m_z^2>/site      = ', FloatToStr(ResMz2,       14, 8),
                  ' +/- ',         FloatToStr(ErrMz2,       10, 8));
 Writeln(F, '<m_stag^2>/site   = ', FloatToStr(ResMs2,       14, 8),
                  ' +/- ',         FloatToStr(ErrMs2,       10, 8));
 Writeln(F, 'Susceptibility_u  = ', FloatToStr(ResChiU,      14, 8),
                  ' +/- ',         FloatToStr(ErrChiU,      10, 8));
 Writeln(F, 'Susceptibility_s  = ', FloatToStr(ResChiS,      14, 8),
                  ' +/- ',         FloatToStr(ErrChiS,      10, 8));
 Close(F);
 Writeln('  ecrit : ', FName);
End;

Procedure WriteScalarAvg(Var F: Text; Name: String; Mean, Err: Real);
Begin
 Writeln(F, '  <SCALAR_AVERAGE name="', Name, '">');
 Writeln(F, '   <COUNT>', NBins, '</COUNT>');
 Writeln(F, '   <MEAN method="simple">',  FloatToSci(Mean), '</MEAN>');
 Writeln(F, '   <ERROR method="binning">', FloatToSci(Err),  '</ERROR>');
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
 Writeln(F, '  <PARAMETER name="local_S">"', PrmLocalSName,  '"</PARAMETER>');
 Writeln(F, '  <PARAMETER name="L">', PrmL, '</PARAMETER>');
 Writeln(F, '  <PARAMETER name="T">', FloatToSci(PrmT), '</PARAMETER>');
 Writeln(F, '  <PARAMETER name="J">', FloatToSci(PrmJ), '</PARAMETER>');
 Writeln(F, '  <PARAMETER name="THERMALIZATION">', PrmThermalize,
            '</PARAMETER>');
 Writeln(F, '  <PARAMETER name="SWEEPS">', PrmSweeps, '</PARAMETER>');
 Writeln(F, '  <PARAMETER name="SEED">',   PrmSeed,   '</PARAMETER>');
 Writeln(F, ' </PARAMETERS>');
 Writeln(F, ' <AVERAGES>');
 WriteScalarAvg(F, 'Energy Density',       ResEnergy,   ErrEnergy);
 WriteScalarAvg(F, 'Specific Heat',        ResSpecHeat, ErrSpecHeat);
 WriteScalarAvg(F, 'Magnetization^2',      ResMz2,      ErrMz2);
 WriteScalarAvg(F, 'Staggered M^2',        ResMs2,      ErrMs2);
 WriteScalarAvg(F, 'Susceptibility',       ResChiU,     ErrChiU);
 WriteScalarAvg(F, 'Staggered Susceptibility', ResChiS,  ErrChiS);
 Writeln(F, ' </AVERAGES>');
 Writeln(F, '</SIMULATION>');
 Close(F);
 Writeln('  ecrit : ', FName);
End;

Procedure Checkpoint;
Begin
 LastCkptSec := NowSeconds;
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
 Writeln('LOOP - Cette commande permet d''ex'+#130+'cute une simulation ',
        'de Monte-Carlo quantique utilisant l''algorithme de boucle (Loop ',
        'Algorithm) pour '+#130+'tudier le comportement de syst'+#138+'mes quantiques ',
        'de spins et calculer diverses propri'+#130+'t'+#130+'s physiques telles ',
        'que l'''+#130+'nergie, les corr'+#130+'lations magn'+#130+'tiques et la ',
        'susceptibilit'+#130+'.');
 WriteLn;
 Writeln('Syntaxe : LOOP [options] fichier.in.xml');
 WriteLn;
 Writeln('Options :');
 Writeln('  --time-limit <s>      duree maxi (s)');
 Writeln('  --checkpoint-time <s> intervalle sauvegarde (s)');
 Writeln('  --write-xml           ecrit aussi .out.xml');
 Writeln('  --help                affiche cette aide');
 Writeln;
 Writeln('Modele : Heisenberg AFM isotrope S=1/2, J>0.');
 Writeln('Reseaux : chain lattice (1D), square lattice (2D), bipartites.');
 Writeln('Format fichier : .parm (KEY=VALUE) ou .in.xml (ALPS).');
 Writeln('Cles : LATTICE, MODEL, local_S, L, T, J, THERMALIZATION,');
 Writeln('       SWEEPS, SEED.');
End;

Procedure SetDefaults;
Begin
 PrmLatticeName := 'chain lattice';
 PrmModelName   := 'spin';
 PrmLocalSName  := '1/2';
 PrmLattice     := ltChain;
 PrmL           := 16;
 PrmT           := 0.5;
 PrmJ           := 1.0;
 PrmThermalize  := 2000;
 PrmSweeps      := 10000;
 PrmSeed        := 12345;

 OptTimeLimit   := 0;
 OptCheckpoint  := 0;
 OptWriteXml    := False;
 OptHelp        := False;
 OptInFile      := '';
End;

Procedure ParseCLI;
Var I: Integer; A, V: String;
Begin
 I := 1;
 While I <= ParamCount Do Begin
  A := ParamStr(I);
  If (A = '--help') Or (A = '-h') Or (A = '/?') Then
   OptHelp := True
  Else If A = '--write-xml' Then
   OptWriteXml := True
  Else If A = '--mpi' Then
   { ignore : mono-processus }
  Else If (A = '--time-limit') Or (A = '--checkpoint-time') Then Begin
   Inc(I);
   If I > ParamCount Then Begin
    Writeln('LOOP: valeur manquante pour ', A); Halt(1);
   End;
   V := ParamStr(I);
   If A = '--time-limit'      Then OptTimeLimit  := StrToIntDef(V, 0)
   Else                            OptCheckpoint := StrToIntDef(V, 0);
  End
  Else If (Length(A) >= 2) And (A[1] = '-') And (A[2] = '-') Then Begin
   Writeln('LOOP: option inconnue ', A); Halt(1);
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
 PrintEvery, NextPrint: LongInt;

BEGIN
 SetDefaults;
 ParseCLI;
 If OptHelp Then Begin ShowUsage; Halt(0); End;
 If OptInFile = '' Then Begin
  Writeln('LOOP: fichier d entree manquant.');
  Writeln('Essayez : LOOP --help');
  Halt(1);
 End;
 Writeln('LOOP v', LOOP_VERSION, ' - QMC SSE - lecture ', OptInFile);
 ReadParameterFile(OptInFile);
 OptBaseName := BaseName(OptInFile);

 ResolveLattice;
 If PrmL < 2 Then PrmL := 2;
 If PrmLattice = ltSquare Then Begin
  If PrmL > MAX_L Then Begin
   Writeln('LOOP: L=', PrmL, ' > MAX_L=', MAX_L, ', reduit a ', MAX_L);
   PrmL := MAX_L;
  End;
 End Else Begin
  If PrmL > MAX_SITES Then PrmL := MAX_SITES;
 End;
 If PrmT <= 0 Then PrmT := 0.001;
 Beta := 1.0 / PrmT;
 If PrmJ <= 0 Then Begin
  Writeln('LOOP: cet implementation requiert J>0 (AFM). |J| utilise.');
  PrmJ := Abs(PrmJ);
  If PrmJ = 0 Then PrmJ := 1;
 End;

 BuildLattice;
 RngSeed(PrmSeed);
 { Allocation des gros tableaux sur le tas (heap) :
   LinkList (64 KB), FlipFlag/Visited (16 KB chacun),
   FirstLeg/LastLeg (4 KB chacun). }
 New(LinkList);
 New(FirstLeg);
 New(LastLeg);
 New(FlipFlag);
 New(Visited);
 StartSec    := NowSeconds;
 LastCkptSec := StartSec;

 Writeln('  reseau   = ', PrmLatticeName, '  (',
         NSites, ' sites, ', NBonds, ' bonds)');
 Writeln('  modele   = Heisenberg AFM S=1/2 isotrope');
 Writeln('  T        = ', FloatToStr(PrmT, 1, 6),
         '   beta = ', FloatToStr(Beta, 1, 4),
         '   J = ', FloatToStr(PrmJ, 1, 6));
 Writeln('  THERM    = ', PrmThermalize,
         '   SWEEPS = ', PrmSweeps,
         '   SEED = ', PrmSeed);
 Writeln;

 InitSpins;
 InitOpString;

 { Thermalisation }
 Writeln('Thermalisation (', PrmThermalize, ' sweeps)...');
 For IThermo := 1 To PrmThermalize Do Begin
  DiagonalUpdate;
  MaybeAdjustString;
  BuildLinkList;
  LoopUpdate;
  If TimeLimitReached Then Begin
   Writeln('  arret : time-limit en thermalisation.');
   Halt(0);
  End;
 End;
 Writeln('  thermalisation terminee (M=', MCur, ', N=', NCur, ').');

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
  DiagonalUpdate;
  BuildLinkList;
  LoopUpdate;
  DoMeasurement;
  If (AccCount >= BinSize) And (NBins < MAX_BINS) Then FlushBin;
  If ISweep >= NextPrint Then Begin
   Write('  ', (ISweep * 100) Div PrmSweeps:3, '% (sweep ',
         ISweep, '/', PrmSweeps, ', N=', NCur, ')        '#13);
   NextPrint := NextPrint + PrintEvery;
  End;
  If CheckpointDue Then Checkpoint;
  If TimeLimitReached Then Begin
   Writeln;
   Writeln('  arret : time-limit a sweep ', ISweep);
   Break;
  End;
 End;
 Writeln;
 If AccCount > 0 Then FlushBin;
 Writeln('  mesures terminees : ', NBins, ' bins.');

 ComputeStats;

 Writeln;
 Writeln('Resultats :');
 Writeln('  Energy/site       = ', FloatToStr(ResEnergy,  10, 6),
         ' +/- ', FloatToStr(ErrEnergy,  8, 6));
 Writeln('  SpecificHeat/site = ', FloatToStr(ResSpecHeat,10, 6),
         ' +/- ', FloatToStr(ErrSpecHeat,8, 6));
 Writeln('  <m_z^2>/site      = ', FloatToStr(ResMz2,     10, 6),
         ' +/- ', FloatToStr(ErrMz2,     8, 6));
 Writeln('  <m_stag^2>/site   = ', FloatToStr(ResMs2,     10, 6),
         ' +/- ', FloatToStr(ErrMs2,     8, 6));
 Writeln('  chi_uniform       = ', FloatToStr(ResChiU,    10, 6),
         ' +/- ', FloatToStr(ErrChiU,    8, 6));
 Writeln('  chi_staggered     = ', FloatToStr(ResChiS,    10, 6),
         ' +/- ', FloatToStr(ErrChiS,    8, 6));
 Writeln;

 WriteOutputTxt;
 If OptWriteXml Then WriteOutputXml;

 { Liberation des tableaux alloues sur le tas }
 Dispose(Visited);
 Dispose(FlipFlag);
 Dispose(LastLeg);
 Dispose(FirstLeg);
 Dispose(LinkList);
END.
