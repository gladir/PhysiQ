{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.00
  @website(https://www.gladir.com/physiq)
  @abstract(Target: Free Pascal 3.2
  @description: Clone de l'application GEANT4
}

Program GEANT4;

Uses {$IFDEF FPC}
      Crt,Dos,PtcGraph,PtcCrt,PtcMouse
     {$ELSE}
      Crt,Dos,Graph
     {$ENDIF};

Procedure InitializeGraphics;
Var
 Driver, Mode: Integer;
 ErrCode: Integer;
Begin
 {$IFDEF FPC}
  Driver:=VGA;
  Mode:=VGAHi;
 {$ELSE}
  Driver:=Detect;
  Mode:=VGAHi;
 {$ENDIF}
 InitGraph(Driver,Mode,'');
 ErrCode:=GraphResult;
 If ErrCode=grOk Then Begin
  SetColor(White);
  SetLineStyle(0,0,1);
 End
  Else
 Begin
  WriteLn('Erreur graphique : ',GraphErrorMsg(ErrCode));
  Halt;
 End;
End;

{ ============================================================
  CONSTANTES GLOBALES
  ============================================================ }

Const
 GEANT4_VERSION       = '1.00';
 GEANT4_DATE          = '2026-05-29';

 SCREEN_W             = 640;
 SCREEN_H             = 480;

 MENUBAR_HEIGHT       = 20;
 STATUSBAR_HEIGHT     = 16;
 MAX_MENUS            = 12;
 MAX_MENU_ITEMS       = 24;

 MAX_PARTICLES        = 512;
 MAX_TRACK_POINTS     = 256;
 MAX_MATERIALS        = 8;
 MAX_FORMULAS         = 96;
 MAX_FORM_VARS        = 6;

 { Palette VGA 16 couleurs : utilisation des constantes Graph }
 CLR_BACKGROUND       = LightGray;    {  7 }
 CLR_TITLEBAR         = DarkGray;     {  8 }
 CLR_TITLEBAR_ACTIVE  = Blue;         {  1 }
 CLR_MENUBAR          = LightGray;    {  7 }
 CLR_MENU_HIGHLIGHT   = Blue;         {  1 }
 CLR_MENU_TEXT        = Black;        {  0 }
 CLR_EDITOR_BG        = White;        { 15 }
 CLR_BORDER           = DarkGray;     {  8 }
 CLR_DETECTOR         = LightGray;
 CLR_VIEWPORT         = Black;
 CLR_AXIS             = DarkGray;
 CLR_GRID             = DarkGray;

 { Couleurs par particule }
 CLR_ELECTRON         = Yellow;
 CLR_PHOTON           = LightGreen;
 CLR_PROTON           = LightRed;
 CLR_ALPHA            = LightMagenta;
 CLR_ION              = LightCyan;

 { Constantes physiques }
 PHY_C                = 2.99792458E10;   { vitesse lumiere (cm/s) }
 PHY_E                = 1.602176634E-19; { charge e (C) }
 PHY_H                = 6.62607015E-34;  { Planck (J.s) }
 PHY_HBAR             = 1.054571817E-34; { hbar (J.s) }
 PHY_KB               = 1.380649E-23;    { Boltzmann (J/K) }
 PHY_NA               = 6.02214076E23;   { Avogadro }
 PHY_G                = 6.67430E-11;     { gravitation (N.m2/kg2) }
 PHY_ME_MEV           = 0.510998950;     { masse electron (MeV) }
 PHY_MP_MEV           = 938.272088;      { masse proton (MeV) }
 PHY_MN_MEV           = 939.565421;      { masse neutron (MeV) }
 PHY_MA_MEV           = 3727.379;        { masse alpha (MeV) }
 PHY_K_BB             = 0.307075;        { Bethe-Bloch K (MeV.cm2/g) }
 PHY_RE_CM            = 2.8179403262E-13;{ rayon classique electron (cm) }
 PHY_PI               = 3.14159265358979;
 PHY_EPS0             = 8.8541878128E-12;
 PHY_MU0              = 1.25663706212E-6;
 PHY_K_COULOMB        = 8.9875517873681E9;
 PHY_R_GAS            = 8.314462618;
 PHY_SIGMA_SB         = 5.670374419E-8;
 PHY_WIEN_B           = 2.897771955E-3;

 { Identifiants des evenements de menu (tags) }
 TAG_FILE_NEW         = 110;
 TAG_FILE_LOADCFG     = 111;
 TAG_FILE_SAVERES     = 112;
 TAG_FILE_EXPORT      = 113;
 TAG_FILE_QUIT        = 199;

 TAG_SIM_START        = 210;
 TAG_SIM_PAUSE        = 211;
 TAG_SIM_RESET        = 212;
 TAG_SIM_STEP         = 213;
 TAG_SIM_FASTER       = 214;
 TAG_SIM_SLOWER       = 215;

 TAG_PART_ELECTRON    = 310;
 TAG_PART_PHOTON      = 311;
 TAG_PART_PROTON      = 312;
 TAG_PART_ALPHA       = 313;
 TAG_PART_ENERGY      = 320;
 TAG_PART_COUNT       = 321;
 TAG_PART_DIR         = 322;

 TAG_GEO_BOX          = 410;
 TAG_GEO_CYL          = 411;
 TAG_GEO_SPHERE       = 412;
 TAG_GEO_SIZE         = 420;
 TAG_GEO_MAT          = 421;

 TAG_VIEW_2D          = 510;
 TAG_VIEW_3D          = 511;
 TAG_VIEW_HIST        = 512;
 TAG_VIEW_GRID        = 513;
 TAG_VIEW_RESET       = 514;

 TAG_FORM_BASE        = 600;       { 600..699 : formules }
 TAG_FORM_PLOT        = 700;

 TAG_HELP_ABOUT       = 900;
 TAG_HELP_KEYS        = 901;
 TAG_HELP_DOC         = 902;

{ ============================================================
  TYPES
  ============================================================ }

Type
 TStr15  = String[15];
 TStr31  = String[31];
 TStr63  = String[63];

 { Evenements (porte depuis DEVENV.PAS) }
 TEventKind = (
  EV_NONE, EV_MOUSE_MOVE, EV_MOUSE_DOWN, EV_MOUSE_UP,
  EV_MOUSE_DBLCLICK, EV_KEY_DOWN, EV_KEY_CHAR,
  EV_TIMER, EV_RESIZE, EV_CLOSE
 );

 TMouseButton = (MB_NONE, MB_LEFT, MB_RIGHT, MB_MIDDLE);

 TEvent = Record
  Kind       : TEventKind;
  MouseX     : Integer;
  MouseY     : Integer;
  MouseBtn   : TMouseButton;
  KeyCode    : Word;
  KeyChar    : Char;
  ShiftState : Word;
  Timestamp  : LongInt;
 End;

 { Menu (porte depuis DEVENV.PAS) }
 TMenuItem = Record
  Caption    : String[63];
  ShortCut   : String[15];
  Enabled    : Boolean;
  Checked    : Boolean;
  Separator  : Boolean;
  Tag        : LongInt;
 End;

 TMenu = Record
  Title      : String[31];
  Items      : Array[0..MAX_MENU_ITEMS - 1] Of TMenuItem;
  ItemCount  : Integer;
  X          : Integer;
  Width      : Integer;
 End;

 TMenuBar = Record
  Menus      : Array[0..MAX_MENUS - 1] Of TMenu;
  MenuCount  : Integer;
  Y          : Integer;
  Height     : Integer;
 End;

 { Particules }
 TParticleKind = (pkElectron, pkPhoton, pkProton, pkAlpha);

 PParticle = ^TParticle;
 TParticle = Record
  Kind       : TParticleKind;
  X, Y, Z    : Real;          { position (cm) }
  VX, VY, VZ : Real;          { direction normalisee }
  Energy     : Real;          { MeV }
  Mass       : Real;          { MeV/c^2 }
  Charge     : Integer;
  Alive      : Boolean;
  TrackLen   : Integer;
  TrackX     : Array[0..MAX_TRACK_POINTS - 1] Of Real;
  TrackY     : Array[0..MAX_TRACK_POINTS - 1] Of Real;
  TrackZ     : Array[0..MAX_TRACK_POINTS - 1] Of Real;
  Next       : PParticle;
 End;

 { Materiaux }
 TMaterial = Record
  Name       : String[15];
  Z          : Real;          { numero atomique moyen }
  A          : Real;          { masse atomique (g/mol) }
  Density    : Real;          { g/cm3 }
  IEv        : Real;          { potentiel d ionisation (eV) }
  X0         : Real;          { longueur de radiation (g/cm2 -> cm) }
 End;

 { Geometrie }
 TGeoShape = (gsBox, gsCylinder, gsSphere);
 TGeometry = Record
  Shape      : TGeoShape;
  CX, CY, CZ : Real;          { centre }
  SX, SY, SZ : Real;          { demi-cotes (box) ou rayon/h (cyl/sphere) }
  MatIdx     : Integer;
 End;

 { Formule de physique }
 TFormulaCat = (fcCinematique, fcDynamique, fcEnergie, fcGravitation,
                fcOscillations, fcOndes, fcOptique, fcElectroMag,
                fcThermo, fcRelativite, fcQuantique);

 TFormulaVar = Record
  Name       : String[12];
  Symbol     : String[6];
  Unite      : String[10];
  Value      : Real;
  Known      : Boolean;
 End;

 TFormula = Record
  Name       : String[40];
  Category   : TFormulaCat;
  Expr       : String[60];     { description LaTeX-like }
  NVars      : Integer;
  Vars       : Array[0..MAX_FORM_VARS - 1] Of TFormulaVar;
  SolveProc  : Integer;        { index dispatcher }
  PlotXIdx   : Integer;        { variable X pour grapheur }
  PlotYIdx   : Integer;        { variable Y pour grapheur }
 End;

 { Vue 3D }
 TCamera = Record
  AngleX     : Real;
  AngleY     : Real;
  Dist       : Real;
  Zoom       : Real;
 End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }

Var
 { Barre de menus }
 MainMenuBar    : TMenuBar;
 OpenMenuIdx    : Integer;
 SelItemIdx     : Integer;
 MenuActive     : Boolean;
 MenuBgBuf      : Pointer;
 MenuBgX1, MenuBgY1, MenuBgX2, MenuBgY2 : Integer;
 MenuBgSaved    : Boolean;

 { Souris }
 PrevMouseX     : Integer;
 PrevMouseY     : Integer;
 PrevMouseBtn   : LongInt;
 LastClickX     : Integer;
 LastClickY     : Integer;
 LastClickTime  : LongInt;
 LastClickBtn   : TMouseButton;

 { Simulation : liste chainee des particules }
 ParticlesHead  : PParticle;
 ParticlesTail  : PParticle;
 NParticles     : Integer;
 BeamKind       : TParticleKind;
 BeamEnergy     : Real;      { MeV }
 BeamCount      : Integer;
 BeamAngleDeg   : Real;      { degre, 0 = +X }
 SimRunning     : Boolean;
 SimStep        : Integer;   { compteur }
 SimSpeed       : Integer;   { 1..10 }
 FullRepaint    : Boolean;
 NeedRedrawView : Boolean;

 { Materiaux et geometrie }
 Materials      : Array[0..MAX_MATERIALS - 1] Of TMaterial;
 NMaterials     : Integer;
 Geom           : TGeometry;

 { Histogramme dE/dx }
 Hist           : Array[0..63] Of Real;
 HistMax        : Real;
 NHistBins      : Integer;

 { Vue }
 ViewMode3D     : Boolean;
 ShowGrid       : Boolean;
 ShowHist       : Boolean;
 Cam            : TCamera;

 { Formules }
 Formulas       : Array[0..MAX_FORMULAS - 1] Of TFormula;
 NFormulas      : Integer;

 { Etat global }
 QuitRequested  : Boolean;

{ ============================================================
  COUCHE SOURIS PORTABLE
  ============================================================ }

{$IFNDEF FPC}
 Function MouseDriverFound: Boolean;
 Var
  Regs: Registers;
 Begin
  Regs.AX := 0;
  Intr($33, Regs);
  MouseDriverFound := Regs.AX = $FFFF;
 End;

 Procedure ShowMouseCursor;
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0001;
  Intr($33, Regs);
 End;

 Procedure HideMouseCursor;
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0002;
  Intr($33, Regs);
 End;

 Procedure GetMouseState(Var X, Y, Button: LongInt);
 Var
  Regs: Registers;
 Begin
  Regs.AX := $0003;
  Intr($33, Regs);
  Button := Regs.BX;
  X := Regs.CX;
  Y := Regs.DX;
 End;
{$ELSE}
 Function MouseDriverFound: Boolean;
 Begin
  MouseDriverFound := True;
 End;

 Procedure ShowMouseCursor;
 Begin
  PtcMouse.ShowMouse;
 End;

 Procedure HideMouseCursor;
 Begin
  PtcMouse.HideMouse;
 End;

 Procedure GetMouseState(Var X, Y, Button: LongInt);
 Begin
  PtcMouse.GetMouseState(X, Y, Button);
 End;
{$ENDIF}

{ ============================================================
  HELPERS UTILITAIRES
  ============================================================ }

Function GetScreenWidth: Integer;
Begin
 GetScreenWidth := GetMaxX + 1;
End;

Function GetScreenHeight: Integer;
Begin
 GetScreenHeight := GetMaxY + 1;
End;

Function IntToStr(N: LongInt): String;
Var
 S: String;
Begin
 Str(N, S);
 IntToStr := S;
End;

Function RealToStr(R: Real; Width, Prec: Integer): String;
Var
 S: String;
Begin
 Str(R:Width:Prec, S);
 While (Length(S) > 0) And (S[1] = ' ') Do Delete(S, 1, 1);
 RealToStr := S;
End;

Function RealToStrG(R: Real): String;
Var
 S: String;
 AR: Real;
Begin
 AR := R;
 If AR < 0 Then AR := -AR;
 If (AR = 0) Or ((AR >= 0.01) And (AR < 100000)) Then Begin
  RealToStrG := RealToStr(R, 1, 4);
  Exit;
 End;
 Str(R, S);
 While (Length(S) > 0) And (S[1] = ' ') Do Delete(S, 1, 1);
 RealToStrG := S;
End;

Function Min(A, B: Integer): Integer;
Begin If A < B Then Min := A Else Min := B; End;

Function Max(A, B: Integer): Integer;
Begin If A > B Then Max := A Else Max := B; End;

Function ClampI(V, Lo, Hi: Integer): Integer;
Begin
 If V < Lo Then ClampI := Lo
 Else If V > Hi Then ClampI := Hi
 Else ClampI := V;
End;

Function RMin(A, B: Real): Real;
Begin If A < B Then RMin := A Else RMin := B; End;

Function RMax(A, B: Real): Real;
Begin If A > B Then RMax := A Else RMax := B; End;

Function Sgn(R: Real): Integer;
Begin
 If R > 0 Then Sgn := 1
 Else If R < 0 Then Sgn := -1
 Else Sgn := 0;
End;

Function UpCaseStr(S: String): String;
Var I: Integer;
Begin
 For I := 1 To Length(S) Do S[I] := UpCase(S[I]);
 UpCaseStr := S;
End;

Function StrToRealDef(S: String; Def: Real): Real;
Var
 R: Real;
 Code: Integer;
Begin
 While (Length(S) > 0) And (S[1] = ' ') Do Delete(S, 1, 1);
 While (Length(S) > 0) And (S[Length(S)] = ' ') Do
  Delete(S, Length(S), 1);
 If S = '' Then Begin StrToRealDef := Def; Exit; End;
 Val(S, R, Code);
 If Code = 0 Then StrToRealDef := R
 Else StrToRealDef := Def;
End;

Function StrToIntDef(S: String; Def: LongInt): LongInt;
Var
 N: LongInt;
 Code: Integer;
Begin
 While (Length(S) > 0) And (S[1] = ' ') Do Delete(S, 1, 1);
 While (Length(S) > 0) And (S[Length(S)] = ' ') Do
  Delete(S, Length(S), 1);
 If S = '' Then Begin StrToIntDef := Def; Exit; End;
 Val(S, N, Code);
 If Code = 0 Then StrToIntDef := N
 Else StrToIntDef := Def;
End;

Function GetTimestamp: LongInt;
Var H, M, S, S100: Word;
Begin
 GetTime(H, M, S, S100);
 GetTimestamp := (LongInt(H) * 3600000) +
                 (LongInt(M) * 60000) +
                 (LongInt(S) * 1000) +
                 (LongInt(S100) * 10);
End;

{ Generateur gaussien Box-Muller : N(0,1) }
Var
 RGHaveSpare : Boolean;
 RGSpare     : Real;

Function RandG: Real;
Var
 U1, U2, R, T: Real;
Begin
 If RGHaveSpare Then Begin
  RGHaveSpare := False;
  RandG := RGSpare;
  Exit;
 End;
 Repeat
  U1 := 2.0 * Random - 1.0;
  U2 := 2.0 * Random - 1.0;
  R := U1 * U1 + U2 * U2;
 Until (R > 0) And (R < 1);
 T := Sqrt(-2.0 * Ln(R) / R);
 RGSpare := U2 * T;
 RGHaveSpare := True;
 RandG := U1 * T;
End;

{ Puissance reelle : x^y = exp(y*ln(x)) }
Function RPower(X, Y: Real): Real;
Begin
 If X <= 0 Then RPower := 0
 Else RPower := Exp(Y * Ln(X));
End;

{ ArcSin polyfill (FPC -Mtp/TP7 ne le fournit pas) }
Function ArcSin(X: Real): Real;
Begin
 If X >= 1 Then ArcSin := PHY_PI / 2
 Else If X <= -1 Then ArcSin := -PHY_PI / 2
 Else ArcSin := ArcTan(X / Sqrt(1 - X * X));
End;

Function ArcCos(X: Real): Real;
Begin
 ArcCos := PHY_PI / 2 - ArcSin(X);
End;

{ ============================================================
  SYSTEME D EVENEMENTS
  ============================================================ }

Procedure ClearEvent(Var Ev: TEvent);
Begin
 Ev.Kind := EV_NONE;
 Ev.MouseX := 0;
 Ev.MouseY := 0;
 Ev.MouseBtn := MB_NONE;
 Ev.KeyCode := 0;
 Ev.KeyChar := #0;
 Ev.ShiftState := 0;
 Ev.Timestamp := 0;
End;

Function BtnFromMask(Mask: LongInt): TMouseButton;
Begin
 If (Mask And 1) <> 0 Then BtnFromMask := MB_LEFT
 Else If (Mask And 2) <> 0 Then BtnFromMask := MB_RIGHT
 Else If (Mask And 4) <> 0 Then BtnFromMask := MB_MIDDLE
 Else BtnFromMask := MB_NONE;
End;

Function IsDoubleClick(X, Y: Integer; Btn: TMouseButton;
                       Now: LongInt): Boolean;
Var DX, DY: Integer;
Begin
 IsDoubleClick := False;
 If (Btn = LastClickBtn) And (LastClickBtn <> MB_NONE) Then Begin
  DX := X - LastClickX;
  DY := Y - LastClickY;
  If DX < 0 Then DX := -DX;
  If DY < 0 Then DY := -DY;
  If (DX <= 5) And (DY <= 5) And ((Now - LastClickTime) <= 300) Then
   IsDoubleClick := True;
 End;
End;

Procedure PollEvents(Var Ev: TEvent);
Var
 MX, MY, MBtn: LongInt;
 Now: LongInt;
 Ch: Char;
 Btn: TMouseButton;
Begin
 ClearEvent(Ev);
 Now := GetTimestamp;
 Ev.Timestamp := Now;

 If KeyPressed Then Begin
  Ch := ReadKey;
  If Ch = #0 Then Begin
   Ev.Kind := EV_KEY_DOWN;
   If KeyPressed Then Begin
    Ch := ReadKey;
    Ev.KeyCode := Ord(Ch);
   End;
   Ev.KeyChar := #0;
  End Else Begin
   Ev.Kind := EV_KEY_CHAR;
   Ev.KeyChar := Ch;
   Ev.KeyCode := Ord(Ch);
  End;
  Exit;
 End;

 MX := 0; MY := 0; MBtn := 0;
 GetMouseState(MX, MY, MBtn);
 Btn := BtnFromMask(MBtn);

 If (MBtn <> 0) And (PrevMouseBtn = 0) Then Begin
  If IsDoubleClick(Integer(MX), Integer(MY), Btn, Now) Then Begin
   Ev.Kind := EV_MOUSE_DBLCLICK;
   LastClickBtn := MB_NONE;
  End Else Begin
   Ev.Kind := EV_MOUSE_DOWN;
   LastClickX := Integer(MX);
   LastClickY := Integer(MY);
   LastClickTime := Now;
   LastClickBtn := Btn;
  End;
  Ev.MouseX := Integer(MX);
  Ev.MouseY := Integer(MY);
  Ev.MouseBtn := Btn;
 End
 Else If (MBtn = 0) And (PrevMouseBtn <> 0) Then Begin
  Ev.Kind := EV_MOUSE_UP;
  Ev.MouseX := Integer(MX);
  Ev.MouseY := Integer(MY);
  Ev.MouseBtn := BtnFromMask(PrevMouseBtn);
 End
 Else If (Integer(MX) <> PrevMouseX) Or
         (Integer(MY) <> PrevMouseY) Then Begin
  Ev.Kind := EV_MOUSE_MOVE;
  Ev.MouseX := Integer(MX);
  Ev.MouseY := Integer(MY);
  Ev.MouseBtn := Btn;
 End;

 PrevMouseX := Integer(MX);
 PrevMouseY := Integer(MY);
 PrevMouseBtn := MBtn;
End;

{ ============================================================
  MENUS DEROULANTS (porte depuis DEV-COOLS/DEVENV.PAS)
  ============================================================ }

Procedure InitMenuItem(Var MI: TMenuItem; ACaption: String;
                       AShortCut: String; ATag: LongInt;
                       ASep: Boolean);
Begin
 MI.Caption := ACaption;
 MI.ShortCut := AShortCut;
 MI.Enabled := True;
 MI.Checked := False;
 MI.Separator := ASep;
 MI.Tag := ATag;
End;

Procedure AddMenuItem(Var M: TMenu; ACaption: String;
                      AShortCut: String; ATag: LongInt);
Begin
 If M.ItemCount < MAX_MENU_ITEMS Then Begin
  InitMenuItem(M.Items[M.ItemCount], ACaption, AShortCut, ATag, False);
  Inc(M.ItemCount);
 End;
End;

Procedure AddMenuSeparator(Var M: TMenu);
Begin
 If M.ItemCount < MAX_MENU_ITEMS Then Begin
  InitMenuItem(M.Items[M.ItemCount], '', '', 0, True);
  Inc(M.ItemCount);
 End;
End;

Procedure InitMenu(Var M: TMenu; ATitle: String);
Begin
 M.Title := ATitle;
 M.ItemCount := 0;
 M.X := 0;
 M.Width := 0;
End;

Function MenuItemWidth(Var M: TMenu): Integer;
Var I, W, MaxW: Integer;
Begin
 MaxW := 0;
 For I := 0 To M.ItemCount - 1 Do Begin
  If Not M.Items[I].Separator Then Begin
   W := Length(M.Items[I].Caption) + Length(M.Items[I].ShortCut) + 4;
   If W > MaxW Then MaxW := W;
  End;
 End;
 MenuItemWidth := MaxW * 8 + 16;
End;

Procedure GetMenuRect(Idx: Integer; Var X1, Y1, X2, Y2: Integer);
Var M: TMenu; MW, MH, I, SW: Integer;
Begin
 M := MainMenuBar.Menus[Idx];
 X1 := M.X;
 Y1 := MainMenuBar.Height;
 MW := M.Width;
 If MW < 160 Then MW := 160;
 MH := 4;
 For I := 0 To M.ItemCount - 1 Do
  If M.Items[I].Separator Then MH := MH + 8 Else MH := MH + 16;
 SW := GetScreenWidth;
 If X1 + MW + 2 > SW - 1 Then X1 := SW - 1 - MW - 2;
 If X1 < 0 Then X1 := 0;
 X2 := X1 + MW + 2;
 Y2 := Y1 + MH + 2;
End;

Procedure SaveMenuBackground(Idx: Integer);
Var BufSize: LongInt;
Begin
 GetMenuRect(Idx, MenuBgX1, MenuBgY1, MenuBgX2, MenuBgY2);
 BufSize := ImageSize(MenuBgX1, MenuBgY1, MenuBgX2, MenuBgY2);
 GetMem(MenuBgBuf, BufSize);
 GetImage(MenuBgX1, MenuBgY1, MenuBgX2, MenuBgY2, MenuBgBuf^);
 MenuBgSaved := True;
End;

Procedure RestoreMenuBackground;
Var BufSize: LongInt;
Begin
 If Not MenuBgSaved Then Exit;
 PutImage(MenuBgX1, MenuBgY1, MenuBgBuf^, NormalPut);
 BufSize := ImageSize(MenuBgX1, MenuBgY1, MenuBgX2, MenuBgY2);
 FreeMem(MenuBgBuf, BufSize);
 MenuBgBuf := Nil;
 MenuBgSaved := False;
End;

Procedure DrawMenuBar;
Var I, TX: Integer;
Begin
 SetColor(CLR_MENUBAR);
 SetFillStyle(SolidFill, CLR_MENUBAR);
 Bar(0, MainMenuBar.Y, GetScreenWidth - 1,
     MainMenuBar.Y + MainMenuBar.Height - 1);
 SetColor(CLR_BORDER);
 Line(0, MainMenuBar.Y + MainMenuBar.Height - 1,
      GetScreenWidth - 1, MainMenuBar.Y + MainMenuBar.Height - 1);
 TX := 4;
 For I := 0 To MainMenuBar.MenuCount - 1 Do Begin
  If I = OpenMenuIdx Then Begin
   SetFillStyle(SolidFill, CLR_MENU_HIGHLIGHT);
   Bar(TX - 4, MainMenuBar.Y,
       TX + Length(MainMenuBar.Menus[I].Title) * 8 + 12,
       MainMenuBar.Y + MainMenuBar.Height - 2);
   SetColor(CLR_EDITOR_BG);
  End Else
   SetColor(CLR_MENU_TEXT);
  OutTextXY(TX, MainMenuBar.Y + 4, MainMenuBar.Menus[I].Title);
  TX := TX + Length(MainMenuBar.Menus[I].Title) * 8 + 16;
 End;
End;

Procedure DrawOpenMenu;
Var
 I, YPos, MX, MW, MH, SW: Integer;
 M: TMenu;
Begin
 If OpenMenuIdx < 0 Then Exit;
 M := MainMenuBar.Menus[OpenMenuIdx];
 MX := M.X;
 MW := M.Width;
 If MW < 160 Then MW := 160;
 MH := 4;
 For I := 0 To M.ItemCount - 1 Do
  If M.Items[I].Separator Then MH := MH + 8 Else MH := MH + 16;
 SW := GetScreenWidth;
 If MX + MW + 2 > SW - 1 Then MX := SW - 1 - MW - 2;
 If MX < 0 Then MX := 0;
 { Ombre }
 SetFillStyle(SolidFill, CLR_TITLEBAR);
 Bar(MX + 2, MainMenuBar.Height + 2, MX + MW + 2,
     MainMenuBar.Height + MH + 2);
 { Fond }
 SetFillStyle(SolidFill, CLR_EDITOR_BG);
 Bar(MX, MainMenuBar.Height, MX + MW, MainMenuBar.Height + MH);
 { Bordure }
 SetColor(CLR_BORDER);
 Rectangle(MX, MainMenuBar.Height, MX + MW, MainMenuBar.Height + MH);
 YPos := MainMenuBar.Height + 2;
 For I := 0 To M.ItemCount - 1 Do Begin
  If M.Items[I].Separator Then Begin
   SetColor(CLR_BORDER);
   Line(MX + 2, YPos + 3, MX + MW - 2, YPos + 3);
   YPos := YPos + 8;
  End Else Begin
   If I = SelItemIdx Then Begin
    SetFillStyle(SolidFill, CLR_MENU_HIGHLIGHT);
    Bar(MX + 1, YPos, MX + MW - 1, YPos + 15);
    SetColor(CLR_EDITOR_BG);
   End Else Begin
    If Not M.Items[I].Enabled Then SetColor(CLR_BORDER)
    Else SetColor(CLR_MENU_TEXT);
   End;
   If M.Items[I].Checked Then
    OutTextXY(MX + 4, YPos + 2, #251);
   OutTextXY(MX + 16, YPos + 2, M.Items[I].Caption);
   If Length(M.Items[I].ShortCut) > 0 Then Begin
    If I = SelItemIdx Then SetColor(CLR_EDITOR_BG)
    Else SetColor(CLR_BORDER);
    OutTextXY(MX + MW - Length(M.Items[I].ShortCut) * 8 - 8,
              YPos + 2, M.Items[I].ShortCut);
   End;
   YPos := YPos + 16;
  End;
 End;
End;

Procedure OpenMenuByIdx(Index: Integer);
Begin
 If (Index >= 0) And (Index < MainMenuBar.MenuCount) Then Begin
  If MenuActive Then RestoreMenuBackground;
  OpenMenuIdx := Index;
  SelItemIdx := -1;
  MenuActive := True;
  DrawMenuBar;
  SaveMenuBackground(Index);
  DrawOpenMenu;
 End;
End;

Procedure CloseMenuBar;
Begin
 RestoreMenuBackground;
 OpenMenuIdx := -1;
 SelItemIdx := -1;
 MenuActive := False;
 DrawMenuBar;
End;

Function MenuBarHitTest(MX, MY: Integer): Integer;
Var I, TX, TW: Integer;
Begin
 MenuBarHitTest := -1;
 If (MY < MainMenuBar.Y) Or
    (MY >= MainMenuBar.Y + MainMenuBar.Height) Then Exit;
 TX := 0;
 For I := 0 To MainMenuBar.MenuCount - 1 Do Begin
  TW := Length(MainMenuBar.Menus[I].Title) * 8 + 16;
  If (MX >= TX) And (MX < TX + TW) Then Begin
   MenuBarHitTest := I;
   Exit;
  End;
  TX := TX + TW;
 End;
End;

Function MenuItemHitTest(MX, MY: Integer): Integer;
Var
 I, YPos, MW, MXOrig, SW: Integer;
 M: TMenu;
Begin
 MenuItemHitTest := -1;
 If OpenMenuIdx < 0 Then Exit;
 M := MainMenuBar.Menus[OpenMenuIdx];
 MW := M.Width;
 If MW < 160 Then MW := 160;
 MXOrig := M.X;
 SW := GetScreenWidth;
 If MXOrig + MW + 2 > SW - 1 Then MXOrig := SW - 1 - MW - 2;
 If MXOrig < 0 Then MXOrig := 0;
 If (MX < MXOrig) Or (MX > MXOrig + MW) Then Exit;
 YPos := MainMenuBar.Height + 2;
 For I := 0 To M.ItemCount - 1 Do Begin
  If M.Items[I].Separator Then YPos := YPos + 8
  Else Begin
   If (MY >= YPos) And (MY < YPos + 16) Then Begin
    If M.Items[I].Enabled Then MenuItemHitTest := I;
    Exit;
   End;
   YPos := YPos + 16;
  End;
 End;
End;

{ Declarations anticipees pour le dispatcher des elements de menu }
Procedure ExecuteMenuItem(Var Item: TMenuItem); Forward;
Procedure RedrawAll; Forward;

Procedure HandleMenuEvent(Var Ev: TEvent);
Var Hit, ItemHit: Integer;
Begin
 If Ev.Kind = EV_MOUSE_DOWN Then Begin
  Hit := MenuBarHitTest(Ev.MouseX, Ev.MouseY);
  If Hit >= 0 Then Begin
   If (OpenMenuIdx = Hit) And MenuActive Then CloseMenuBar
   Else OpenMenuByIdx(Hit);
   Exit;
  End;
  If MenuActive And (OpenMenuIdx >= 0) Then Begin
   ItemHit := MenuItemHitTest(Ev.MouseX, Ev.MouseY);
   If ItemHit >= 0 Then Begin
    ExecuteMenuItem(MainMenuBar.Menus[OpenMenuIdx].Items[ItemHit]);
    Exit;
   End;
   CloseMenuBar;
  End;
 End
 Else If Ev.Kind = EV_MOUSE_MOVE Then Begin
  If MenuActive And (OpenMenuIdx >= 0) Then Begin
   Hit := MenuBarHitTest(Ev.MouseX, Ev.MouseY);
   If (Hit >= 0) And (Hit <> OpenMenuIdx) Then OpenMenuByIdx(Hit);
   ItemHit := MenuItemHitTest(Ev.MouseX, Ev.MouseY);
   If ItemHit <> SelItemIdx Then Begin
    SelItemIdx := ItemHit;
    DrawOpenMenu;
   End;
  End;
 End
 Else If Ev.Kind = EV_KEY_DOWN Then Begin
  If MenuActive Then Begin
   Case Ev.KeyCode Of
    72: Begin { Up }
     If OpenMenuIdx >= 0 Then Begin
      If SelItemIdx > 0 Then Dec(SelItemIdx)
      Else SelItemIdx := MainMenuBar.Menus[OpenMenuIdx].ItemCount - 1;
      While (SelItemIdx >= 0) And
       MainMenuBar.Menus[OpenMenuIdx].Items[SelItemIdx].Separator Do
       Dec(SelItemIdx);
      DrawOpenMenu;
     End;
    End;
    80: Begin { Down }
     If OpenMenuIdx >= 0 Then Begin
      If SelItemIdx < MainMenuBar.Menus[OpenMenuIdx].ItemCount - 1 Then
       Inc(SelItemIdx)
      Else SelItemIdx := 0;
      While (SelItemIdx < MainMenuBar.Menus[OpenMenuIdx].ItemCount) And
       MainMenuBar.Menus[OpenMenuIdx].Items[SelItemIdx].Separator Do
       Inc(SelItemIdx);
      DrawOpenMenu;
     End;
    End;
    75: Begin { Left }
     If OpenMenuIdx > 0 Then OpenMenuByIdx(OpenMenuIdx - 1)
     Else OpenMenuByIdx(MainMenuBar.MenuCount - 1);
    End;
    77: Begin { Right }
     If OpenMenuIdx < MainMenuBar.MenuCount - 1 Then
      OpenMenuByIdx(OpenMenuIdx + 1)
     Else OpenMenuByIdx(0);
    End;
    28: Begin { Enter }
     If (SelItemIdx >= 0) And (OpenMenuIdx >= 0) Then
      ExecuteMenuItem(MainMenuBar.Menus[OpenMenuIdx].Items[SelItemIdx]);
    End;
    1: CloseMenuBar; { Esc }
   End;
  End Else Begin
   { Alt+lettre : ouvrir un menu (codes scan BIOS) }
   Case Ev.KeyCode Of
    $21: OpenMenuByIdx(0); { Alt+F : Fichier }
    $1F: OpenMenuByIdx(1); { Alt+S : Simulation }
    $19: OpenMenuByIdx(2); { Alt+P : Particules }
    $22: OpenMenuByIdx(3); { Alt+G : Geometrie }
    $2F: OpenMenuByIdx(4); { Alt+V : Vue }
    $20: OpenMenuByIdx(5); { Alt+D : formuleS (D non standard, mais)}
    $23: OpenMenuByIdx(5); { Alt+H ? -> Formules via H }
    $17: OpenMenuByIdx(6); { Alt+I : aIde }
    $2D: QuitRequested := True; { Alt+X : Quitter }
   End;
  End;
 End
 Else If Ev.Kind = EV_KEY_CHAR Then Begin
  If MenuActive Then Begin
   Case Ev.KeyChar Of
    #13: Begin
     If (SelItemIdx >= 0) And (OpenMenuIdx >= 0) Then
      ExecuteMenuItem(MainMenuBar.Menus[OpenMenuIdx].Items[SelItemIdx]);
    End;
    #27: CloseMenuBar;
   End;
  End;
 End;
End;

{ ============================================================
  MATERIAUX ET GEOMETRIE
  ============================================================ }

Procedure InitMaterials;
Begin
 NMaterials := 0;
 { 0: Eau }
 Materials[0].Name := 'Eau (H2O)';
 Materials[0].Z := 7.42; Materials[0].A := 18.015;
 Materials[0].Density := 1.000; Materials[0].IEv := 75.0;
 Materials[0].X0 := 36.08;
 { 1: Plomb }
 Materials[1].Name := 'Plomb (Pb)';
 Materials[1].Z := 82; Materials[1].A := 207.2;
 Materials[1].Density := 11.35; Materials[1].IEv := 823.0;
 Materials[1].X0 := 0.5612;
 { 2: Aluminium }
 Materials[2].Name := 'Aluminium';
 Materials[2].Z := 13; Materials[2].A := 26.98;
 Materials[2].Density := 2.699; Materials[2].IEv := 166.0;
 Materials[2].X0 := 8.897;
 { 3: Air }
 Materials[3].Name := 'Air';
 Materials[3].Z := 7.32; Materials[3].A := 14.66;
 Materials[3].Density := 1.205E-3; Materials[3].IEv := 85.7;
 Materials[3].X0 := 30420;
 { 4: Silicium }
 Materials[4].Name := 'Silicium';
 Materials[4].Z := 14; Materials[4].A := 28.09;
 Materials[4].Density := 2.329; Materials[4].IEv := 173.0;
 Materials[4].X0 := 9.37;
 { 5: NaI }
 Materials[5].Name := 'NaI (Tl)';
 Materials[5].Z := 32; Materials[5].A := 74.94;
 Materials[5].Density := 3.667; Materials[5].IEv := 452.0;
 Materials[5].X0 := 2.59;
 NMaterials := 6;
End;

Procedure InitGeometry;
Begin
 Geom.Shape := gsBox;
 Geom.CX := 10; Geom.CY := 0; Geom.CZ := 0;
 Geom.SX := 10; Geom.SY := 5; Geom.SZ := 5;
 Geom.MatIdx := 0;  { eau par defaut }
End;

Function PointInGeom(X, Y, Z: Real): Boolean;
Var DX, DY, DZ, R: Real;
Begin
 PointInGeom := False;
 Case Geom.Shape Of
  gsBox: PointInGeom :=
   (X >= Geom.CX - Geom.SX) And (X <= Geom.CX + Geom.SX) And
   (Y >= Geom.CY - Geom.SY) And (Y <= Geom.CY + Geom.SY) And
   (Z >= Geom.CZ - Geom.SZ) And (Z <= Geom.CZ + Geom.SZ);
  gsCylinder: Begin
   DY := Y - Geom.CY; DZ := Z - Geom.CZ;
   R := Sqrt(DY * DY + DZ * DZ);
   PointInGeom := (R <= Geom.SY) And
    (X >= Geom.CX - Geom.SX) And (X <= Geom.CX + Geom.SX);
  End;
  gsSphere: Begin
   DX := X - Geom.CX; DY := Y - Geom.CY; DZ := Z - Geom.CZ;
   PointInGeom := (DX * DX + DY * DY + DZ * DZ) <= Geom.SX * Geom.SX;
  End;
 End;
End;

{ ============================================================
  MOTEUR PHYSIQUE
  ============================================================ }

{ Beta et gamma relativistes d une particule }
Procedure GetBetaGamma(Var P: TParticle; Var Beta, Gamma: Real);
Var Etot: Real;
Begin
 If P.Mass <= 0 Then Begin
  Beta := 1.0;
  Gamma := 1E9;
  Exit;
 End;
 Etot := P.Energy + P.Mass;
 Gamma := Etot / P.Mass;
 If Gamma < 1 Then Gamma := 1;
 Beta := Sqrt(1.0 - 1.0 / (Gamma * Gamma));
 If Beta < 1E-6 Then Beta := 1E-6;
End;

{ Bethe-Bloch : dE/dx en MeV/cm pour particule chargee }
Function BetheBloch(Var P: TParticle; Var Mat: TMaterial): Real;
Var
 Beta, Gamma, Beta2, Tmax, LnArg, Term: Real;
 Z: Real;
Begin
 If P.Charge = 0 Then Begin BetheBloch := 0; Exit; End;
 GetBetaGamma(P, Beta, Gamma);
 Beta2 := Beta * Beta;
 If Beta2 < 1E-8 Then Begin BetheBloch := 0; Exit; End;
 Z := P.Charge;
 Tmax := 2 * PHY_ME_MEV * Beta2 * Gamma * Gamma;
 LnArg := 2 * PHY_ME_MEV * 1E6 * Beta2 * Gamma * Gamma / Mat.IEv;
 If LnArg < 1.001 Then LnArg := 1.001;
 Term := Ln(LnArg) - Beta2;
 If Term < 0.1 Then Term := 0.1;
 { dE/dx en MeV/(g/cm2) * densite = MeV/cm }
 BetheBloch := PHY_K_BB * Z * Z * Mat.Z / Mat.A / Beta2 * Term *
               Mat.Density;
End;

{ Diffusion multi-coulombienne : angle gaussien (Highland) }
Procedure MultipleScattering(Var P: TParticle; Var Mat: TMaterial;
 DS: Real);
Var
 Beta, Gamma, BetaCP, Theta0, Phi, CosT, SinT: Real;
 NX, NY, NZ, T1X, T1Y, T1Z, T2X, T2Y, T2Z, Norm: Real;
Begin
 If P.Charge = 0 Then Exit;
 GetBetaGamma(P, Beta, Gamma);
 BetaCP := Beta * (P.Energy + P.Mass);   { ~ p*c en MeV }
 If BetaCP < 1E-3 Then BetaCP := 1E-3;
 If Mat.X0 < 1E-6 Then Exit;
 Theta0 := (13.6 / BetaCP) * Abs(P.Charge) *
           Sqrt(DS / Mat.X0) *
           (1 + 0.038 * Ln(DS / Mat.X0 + 1E-6));
 If Theta0 < 0 Then Theta0 := 0;
 If Theta0 > 0.5 Then Theta0 := 0.5;

 { Construire deux vecteurs perpendiculaires au mouvement }
 NX := P.VX; NY := P.VY; NZ := P.VZ;
 If Abs(NX) < 0.9 Then Begin
  T1X := 0; T1Y := -NZ; T1Z := NY;
 End Else Begin
  T1X := -NZ; T1Y := 0; T1Z := NX;
 End;
 Norm := Sqrt(T1X * T1X + T1Y * T1Y + T1Z * T1Z);
 If Norm < 1E-9 Then Exit;
 T1X := T1X / Norm; T1Y := T1Y / Norm; T1Z := T1Z / Norm;
 T2X := NY * T1Z - NZ * T1Y;
 T2Y := NZ * T1X - NX * T1Z;
 T2Z := NX * T1Y - NY * T1X;

 Phi := 2 * PHY_PI * Random;
 CosT := Cos(Theta0 * RandG);
 SinT := Sqrt(1 - CosT * CosT);
 If Random < 0.5 Then SinT := -SinT;

 P.VX := CosT * NX + SinT * (Cos(Phi) * T1X + Sin(Phi) * T2X);
 P.VY := CosT * NY + SinT * (Cos(Phi) * T1Y + Sin(Phi) * T2Y);
 P.VZ := CosT * NZ + SinT * (Cos(Phi) * T1Z + Sin(Phi) * T2Z);
 Norm := Sqrt(P.VX * P.VX + P.VY * P.VY + P.VZ * P.VZ);
 If Norm > 1E-9 Then Begin
  P.VX := P.VX / Norm; P.VY := P.VY / Norm; P.VZ := P.VZ / Norm;
 End;
End;

{ Section efficace totale gamma (cm^-1) : PE + Compton + Paire approx }
Function PhotonMu(E: Real; Var Mat: TMaterial): Real;
Var
 SigPE, SigComp, SigPair, MuMass, Z3, E2, ECut: Real;
Begin
 If E <= 0 Then Begin PhotonMu := 1E9; Exit; End;
 Z3 := RPower(Mat.Z, 4.5);
 E2 := RPower(E, 3.5);
 SigPE := 1.0E-24 * Z3 / E2;                { cm2/atom approx }
 SigComp := 6.65E-25 * Mat.Z / (1 + 2 * E);  { Klein-Nishina simplifie }
 If E > 1.022 Then Begin
  ECut := E - 1.022;
  SigPair := 5.8E-28 * Mat.Z * Mat.Z * Ln(ECut + 1.0);
 End Else
  SigPair := 0;
 MuMass := (SigPE + SigComp + SigPair) * PHY_NA / Mat.A;
 PhotonMu := MuMass * Mat.Density;
End;

Procedure AddTrackPoint(Var P: TParticle);
Begin
 If P.TrackLen < MAX_TRACK_POINTS Then Begin
  P.TrackX[P.TrackLen] := P.X;
  P.TrackY[P.TrackLen] := P.Y;
  P.TrackZ[P.TrackLen] := P.Z;
  Inc(P.TrackLen);
 End;
End;

Procedure AddHistDep(Energy, XPos: Real);
Var Bin: Integer; XMin, XMax, F: Real;
Begin
 XMin := Geom.CX - Geom.SX;
 XMax := Geom.CX + Geom.SX;
 If XMax <= XMin Then Exit;
 F := (XPos - XMin) / (XMax - XMin);
 If (F < 0) Or (F >= 1) Then Exit;
 Bin := Trunc(F * NHistBins);
 If (Bin >= 0) And (Bin < NHistBins) Then Begin
  Hist[Bin] := Hist[Bin] + Energy;
  If Hist[Bin] > HistMax Then HistMax := Hist[Bin];
 End;
End;

Procedure StepParticle(Var P: TParticle);
Var
 Mat: TMaterial;
 DS, DE, Mu, ProbInt: Real;
 InGeom: Boolean;
Begin
 If Not P.Alive Then Exit;
 InGeom := PointInGeom(P.X, P.Y, P.Z);
 If InGeom Then
  Mat := Materials[Geom.MatIdx]
 Else
  Mat := Materials[3]; { air }

 { Pas adaptatif : plus petit dans matiere dense }
 If InGeom Then DS := 0.1 + 0.05 * Random
 Else DS := 0.5 + 0.2 * Random;

 If P.Kind = pkPhoton Then Begin
  Mu := PhotonMu(P.Energy, Mat);
  ProbInt := 1 - Exp(-Mu * DS);
  If Random < ProbInt Then Begin
   { Interaction : depose toute l energie ici (simplification) }
   If InGeom Then AddHistDep(P.Energy, P.X);
   P.Energy := 0;
   P.Alive := False;
  End;
 End Else Begin
  DE := BetheBloch(P, Mat) * DS;
  If DE < 0 Then DE := 0;
  If DE > P.Energy Then DE := P.Energy;
  P.Energy := P.Energy - DE;
  If InGeom Then AddHistDep(DE, P.X);
  If InGeom And (P.Energy > 0.01) Then
   MultipleScattering(P, Mat, DS);
  If P.Energy < 0.01 Then P.Alive := False;
 End;

 { Avance }
 P.X := P.X + P.VX * DS;
 P.Y := P.Y + P.VY * DS;
 P.Z := P.Z + P.VZ * DS;
 AddTrackPoint(P);

 { Hors zone : tuer }
 If (Abs(P.X - Geom.CX) > Geom.SX * 3) Or
    (Abs(P.Y - Geom.CY) > Geom.SY * 3) Or
    (Abs(P.Z - Geom.CZ) > Geom.SZ * 3) Then
  P.Alive := False;
End;

Procedure ClearParticles;
Var P, N: PParticle;
Begin
 P := ParticlesHead;
 While P <> Nil Do Begin
  N := P^.Next;
  Dispose(P);
  P := N;
 End;
 ParticlesHead := Nil;
 ParticlesTail := Nil;
 NParticles := 0;
End;

Function AddParticle: PParticle;
Var P: PParticle;
Begin
 New(P);
 FillChar(P^, SizeOf(P^), 0);
 P^.Next := Nil;
 If ParticlesTail = Nil Then ParticlesHead := P
 Else ParticlesTail^.Next := P;
 ParticlesTail := P;
 Inc(NParticles);
 AddParticle := P;
End;

Procedure ResetSimulation;
Var I: Integer;
Begin
 ClearParticles;
 For I := 0 To NHistBins - 1 Do Hist[I] := 0;
 HistMax := 0;
 SimStep := 0;
 SimRunning := False;
End;

Procedure SpawnBeam;
Var
 I: Integer;
 Theta, M: Real;
 Charge: Integer;
 P: PParticle;
Begin
 ResetSimulation;
 Case BeamKind Of
  pkElectron: Begin M := PHY_ME_MEV; Charge := -1; End;
  pkPhoton:   Begin M := 0; Charge := 0; End;
  pkProton:   Begin M := PHY_MP_MEV; Charge := 1; End;
  pkAlpha:    Begin M := PHY_MA_MEV; Charge := 2; End;
 End;
 Theta := BeamAngleDeg * PHY_PI / 180.0;
 For I := 1 To BeamCount Do Begin
  If NParticles >= MAX_PARTICLES Then Break;
  P := AddParticle;
  With P^ Do Begin
   Kind := BeamKind;
   X := -5; Y := 0; Z := 0;
   VX := Cos(Theta); VY := Sin(Theta); VZ := 0;
   { Petite divergence pour rendu visuel }
   VY := VY + 0.02 * RandG;
   VZ := VZ + 0.02 * RandG;
   Energy := BeamEnergy;
   Mass := M;
   Charge := Charge;
   Alive := True;
   TrackLen := 0;
   AddTrackPoint(P^);
  End;
 End;
End;

{ ============================================================
  RENDU 2D ET 3D
  ============================================================ }

{ Convertit coord physique (cm) en pixel viewport 2D.
  Viewport : (VPX1,VPY1)-(VPX2,VPY2), centre = origine geo }
Var
 VPX1, VPY1, VPX2, VPY2 : Integer;
 ViewScale              : Real;   { pixels par cm }

Procedure InitViewport;
Var W, H: Integer;
Begin
 VPX1 := 0;
 VPY1 := MENUBAR_HEIGHT;
 VPX2 := SCREEN_W - 1;
 VPY2 := SCREEN_H - STATUSBAR_HEIGHT - 1;
 W := VPX2 - VPX1;
 H := VPY2 - VPY1;
 ViewScale := RMin(W / 50.0, H / 30.0);
End;

Procedure WorldToScreen2D(WX, WY: Real; Var SX, SY: Integer);
Var CX, CY: Integer;
Begin
 CX := (VPX1 + VPX2) Div 2 - Round(Geom.CX * ViewScale * 0.3);
 CY := (VPY1 + VPY2) Div 2;
 SX := CX + Round(WX * ViewScale);
 SY := CY - Round(WY * ViewScale);
End;

Procedure Project3D(WX, WY, WZ: Real; Var SX, SY: Integer);
Var
 X1, Y1, Z1, X2, Y2, Z2, F: Real;
 CX_, CY_: Integer;
 CA, SA, CB, SB: Real;
Begin
 CX_ := (VPX1 + VPX2) Div 2;
 CY_ := (VPY1 + VPY2) Div 2;
 X1 := WX - Geom.CX;
 Y1 := WY - Geom.CY;
 Z1 := WZ - Geom.CZ;
 { Rotation Y (AngleY) }
 CA := Cos(Cam.AngleY); SA := Sin(Cam.AngleY);
 X2 := CA * X1 + SA * Z1;
 Z2 := -SA * X1 + CA * Z1;
 Y2 := Y1;
 { Rotation X (AngleX) }
 CB := Cos(Cam.AngleX); SB := Sin(Cam.AngleX);
 Y1 := CB * Y2 - SB * Z2;
 Z1 := SB * Y2 + CB * Z2;
 X1 := X2;
 { Projection perspective }
 F := Cam.Dist / (Z1 + Cam.Dist + 0.001);
 If F < 0 Then F := 0.01;
 SX := CX_ + Round(X1 * ViewScale * Cam.Zoom * F);
 SY := CY_ - Round(Y1 * ViewScale * Cam.Zoom * F);
End;

Procedure ClearViewport;
Begin
 SetFillStyle(SolidFill, CLR_VIEWPORT);
 Bar(VPX1, VPY1, VPX2, VPY2);
End;

Procedure DrawGrid2D;
Var I, SX1, SY1, SX2, SY2, GridStep: Integer; Wcm: Real;
Begin
 If Not ShowGrid Then Exit;
 SetColor(CLR_GRID);
 SetLineStyle(DottedLn, 0, NormWidth);
 GridStep := 5;  { cm }
 Wcm := -25;
 While Wcm <= 25 Do Begin
  WorldToScreen2D(Wcm, -15, SX1, SY1);
  WorldToScreen2D(Wcm, 15, SX2, SY2);
  If (SX1 >= VPX1) And (SX1 <= VPX2) Then
   Line(SX1, VPY1, SX1, VPY2);
  Wcm := Wcm + GridStep;
 End;
 Wcm := -15;
 While Wcm <= 15 Do Begin
  WorldToScreen2D(-25, Wcm, SX1, SY1);
  WorldToScreen2D(25, Wcm, SX2, SY2);
  If (SY1 >= VPY1) And (SY1 <= VPY2) Then
   Line(VPX1, SY1, VPX2, SY1);
  Wcm := Wcm + GridStep;
 End;
 SetLineStyle(SolidLn, 0, NormWidth);
End;

Procedure DrawAxes2D;
Var SX0, SY0, SXA, SYA: Integer;
Begin
 SetColor(CLR_AXIS);
 WorldToScreen2D(0, 0, SX0, SY0);
 WorldToScreen2D(5, 0, SXA, SYA);
 Line(SX0, SY0, SXA, SY0);
 OutTextXY(SXA + 2, SY0 - 4, 'X');
 WorldToScreen2D(0, 5, SXA, SYA);
 Line(SX0, SY0, SX0, SYA);
 OutTextXY(SX0 + 2, SYA - 10, 'Y');
End;

Procedure DrawGeometry2D;
Var
 X1S, Y1S, X2S, Y2S, CXS, CYS, RS: Integer;
 MatName: String;
Begin
 SetColor(CLR_DETECTOR);
 SetLineStyle(SolidLn, 0, NormWidth);
 Case Geom.Shape Of
  gsBox: Begin
   WorldToScreen2D(Geom.CX - Geom.SX, Geom.CY + Geom.SY, X1S, Y1S);
   WorldToScreen2D(Geom.CX + Geom.SX, Geom.CY - Geom.SY, X2S, Y2S);
   Rectangle(X1S, Y1S, X2S, Y2S);
  End;
  gsCylinder: Begin
   WorldToScreen2D(Geom.CX - Geom.SX, Geom.CY + Geom.SY, X1S, Y1S);
   WorldToScreen2D(Geom.CX + Geom.SX, Geom.CY - Geom.SY, X2S, Y2S);
   Rectangle(X1S, Y1S, X2S, Y2S);
   { vue de cote }
  End;
  gsSphere: Begin
   WorldToScreen2D(Geom.CX, Geom.CY, CXS, CYS);
   RS := Round(Geom.SX * ViewScale);
   Circle(CXS, CYS, RS);
  End;
 End;
 If Geom.MatIdx < NMaterials Then Begin
  MatName := 'Materiau: ' + Materials[Geom.MatIdx].Name;
  SetColor(CLR_DETECTOR);
  OutTextXY(VPX1 + 4, VPY1 + 4, MatName);
 End;
End;

Procedure DrawGeometry3D;
Var
 X1, Y1, X2, Y2: Integer;
 Vx: Array[0..7] Of Record SX, SY: Integer; End;
 I: Integer;
Begin
 SetColor(CLR_DETECTOR);
 Case Geom.Shape Of
  gsBox: Begin
   Project3D(Geom.CX - Geom.SX, Geom.CY - Geom.SY, Geom.CZ - Geom.SZ, Vx[0].SX, Vx[0].SY);
   Project3D(Geom.CX + Geom.SX, Geom.CY - Geom.SY, Geom.CZ - Geom.SZ, Vx[1].SX, Vx[1].SY);
   Project3D(Geom.CX + Geom.SX, Geom.CY + Geom.SY, Geom.CZ - Geom.SZ, Vx[2].SX, Vx[2].SY);
   Project3D(Geom.CX - Geom.SX, Geom.CY + Geom.SY, Geom.CZ - Geom.SZ, Vx[3].SX, Vx[3].SY);
   Project3D(Geom.CX - Geom.SX, Geom.CY - Geom.SY, Geom.CZ + Geom.SZ, Vx[4].SX, Vx[4].SY);
   Project3D(Geom.CX + Geom.SX, Geom.CY - Geom.SY, Geom.CZ + Geom.SZ, Vx[5].SX, Vx[5].SY);
   Project3D(Geom.CX + Geom.SX, Geom.CY + Geom.SY, Geom.CZ + Geom.SZ, Vx[6].SX, Vx[6].SY);
   Project3D(Geom.CX - Geom.SX, Geom.CY + Geom.SY, Geom.CZ + Geom.SZ, Vx[7].SX, Vx[7].SY);
   For I := 0 To 3 Do
    Line(Vx[I].SX, Vx[I].SY, Vx[(I+1) Mod 4].SX, Vx[(I+1) Mod 4].SY);
   For I := 0 To 3 Do
    Line(Vx[4+I].SX, Vx[4+I].SY,
         Vx[4+((I+1) Mod 4)].SX, Vx[4+((I+1) Mod 4)].SY);
   For I := 0 To 3 Do
    Line(Vx[I].SX, Vx[I].SY, Vx[4+I].SX, Vx[4+I].SY);
  End;
  gsCylinder: Begin
   Project3D(Geom.CX - Geom.SX, Geom.CY, Geom.CZ, X1, Y1);
   Project3D(Geom.CX + Geom.SX, Geom.CY, Geom.CZ, X2, Y2);
   Line(X1, Y1, X2, Y2);
   For I := 0 To 11 Do Begin
    Project3D(Geom.CX - Geom.SX,
              Geom.CY + Geom.SY * Cos(I * PHY_PI / 6),
              Geom.CZ + Geom.SY * Sin(I * PHY_PI / 6),
              Vx[I Mod 8].SX, Vx[I Mod 8].SY);
    If I > 0 Then
     Line(Vx[(I-1) Mod 8].SX, Vx[(I-1) Mod 8].SY,
          Vx[I Mod 8].SX, Vx[I Mod 8].SY);
   End;
  End;
  gsSphere: Begin
   For I := 0 To 35 Do Begin
    Project3D(Geom.CX + Geom.SX * Cos(I * PHY_PI / 18),
              Geom.CY + Geom.SX * Sin(I * PHY_PI / 18),
              Geom.CZ, Vx[I Mod 8].SX, Vx[I Mod 8].SY);
    If I > 0 Then
     Line(Vx[(I-1) Mod 8].SX, Vx[(I-1) Mod 8].SY,
          Vx[I Mod 8].SX, Vx[I Mod 8].SY);
   End;
   For I := 0 To 35 Do Begin
    Project3D(Geom.CX + Geom.SX * Cos(I * PHY_PI / 18),
              Geom.CY,
              Geom.CZ + Geom.SX * Sin(I * PHY_PI / 18),
              Vx[I Mod 8].SX, Vx[I Mod 8].SY);
    If I > 0 Then
     Line(Vx[(I-1) Mod 8].SX, Vx[(I-1) Mod 8].SY,
          Vx[I Mod 8].SX, Vx[I Mod 8].SY);
   End;
  End;
 End;
End;

Function ParticleColor(K: TParticleKind): Integer;
Begin
 Case K Of
  pkElectron: ParticleColor := CLR_ELECTRON;
  pkPhoton:   ParticleColor := CLR_PHOTON;
  pkProton:   ParticleColor := CLR_PROTON;
  pkAlpha:    ParticleColor := CLR_ALPHA;
 End;
End;

Procedure DrawTracks;
Var
 J, SX1, SY1, SX2, SY2: Integer;
 P: PParticle;
Begin
 P := ParticlesHead;
 While P <> Nil Do Begin
  If P^.TrackLen >= 2 Then Begin
   SetColor(ParticleColor(P^.Kind));
   For J := 1 To P^.TrackLen - 1 Do Begin
    If ViewMode3D Then Begin
     Project3D(P^.TrackX[J-1], P^.TrackY[J-1],
               P^.TrackZ[J-1], SX1, SY1);
     Project3D(P^.TrackX[J], P^.TrackY[J],
               P^.TrackZ[J], SX2, SY2);
    End Else Begin
     WorldToScreen2D(P^.TrackX[J-1],
                     P^.TrackY[J-1], SX1, SY1);
     WorldToScreen2D(P^.TrackX[J],
                     P^.TrackY[J], SX2, SY2);
    End;
    If (SX1 >= VPX1) And (SX1 <= VPX2) And
       (SX2 >= VPX1) And (SX2 <= VPX2) And
       (SY1 >= VPY1) And (SY1 <= VPY2) And
       (SY2 >= VPY1) And (SY2 <= VPY2) Then
     Line(SX1, SY1, SX2, SY2);
   End;
  End;
  P := P^.Next;
 End;
End;

Procedure DrawHistogram;
Var
 HX1, HY1, HX2, HY2, I, BarH, BarW: Integer;
 Title: String;
Begin
 If Not ShowHist Then Exit;
 HX1 := VPX2 - 200;
 HY1 := VPY1 + 20;
 HX2 := VPX2 - 8;
 HY2 := HY1 + 100;
 SetFillStyle(SolidFill, Black);
 Bar(HX1, HY1, HX2, HY2);
 SetColor(LightGray);
 Rectangle(HX1, HY1, HX2, HY2);
 Title := 'dE/dx (MeV)';
 OutTextXY(HX1 + 4, HY1 + 2, Title);
 If HistMax > 0 Then Begin
  BarW := (HX2 - HX1 - 4) Div NHistBins;
  If BarW < 1 Then BarW := 1;
  SetColor(LightCyan);
  For I := 0 To NHistBins - 1 Do Begin
   BarH := Round(Hist[I] / HistMax * (HY2 - HY1 - 20));
   If BarH > 0 Then
    Line(HX1 + 2 + I * BarW, HY2 - 2,
         HX1 + 2 + I * BarW, HY2 - 2 - BarH);
  End;
 End;
End;

Procedure DrawStatusBar;
Var S: String; Y: Integer; Nalive: Integer; P: PParticle;
Begin
 Y := SCREEN_H - STATUSBAR_HEIGHT;
 SetFillStyle(SolidFill, CLR_BACKGROUND);
 Bar(0, Y, SCREEN_W - 1, SCREEN_H - 1);
 SetColor(CLR_BORDER);
 Line(0, Y, SCREEN_W - 1, Y);
 SetColor(Black);
 Nalive := 0;
 P := ParticlesHead;
 While P <> Nil Do Begin
  If P^.Alive Then Inc(Nalive);
  P := P^.Next;
 End;
 If SimRunning Then S := 'EN COURS' Else S := 'ARRET';
 S := S + '  | Step:' + IntToStr(SimStep) +
   '  N:' + IntToStr(NParticles) +
   '  Actives:' + IntToStr(Nalive) +
   '  E:' + RealToStr(BeamEnergy, 1, 1) + ' MeV';
 OutTextXY(4, Y + 4, S);
 If ViewMode3D Then S := 'Vue: 3D'
 Else S := 'Vue: 2D';
 OutTextXY(SCREEN_W - 80, Y + 4, S);
End;

Procedure DrawViewport;
Begin
 ClearViewport;
 DrawGrid2D;
 If ViewMode3D Then DrawGeometry3D
 Else Begin
  DrawAxes2D;
  DrawGeometry2D;
 End;
 DrawTracks;
 DrawHistogram;
End;

Procedure RedrawAll;
Begin
 DrawViewport;
 DrawStatusBar;
 DrawMenuBar;
 If MenuActive And (OpenMenuIdx >= 0) Then Begin
  SaveMenuBackground(OpenMenuIdx);
  DrawOpenMenu;
 End;
End;

{ ============================================================
  BOITES DE DIALOGUE
  ============================================================ }

Procedure DialogBox(X1, Y1, X2, Y2: Integer; Title: String);
Var BufSize: LongInt; Buf: Pointer;
Begin
 { Le caller gere la sauvegarde/restore - ici juste dessine }
 SetFillStyle(SolidFill, CLR_TITLEBAR);
 Bar(X1 + 4, Y1 + 4, X2 + 4, Y2 + 4); { ombre }
 SetFillStyle(SolidFill, CLR_BACKGROUND);
 Bar(X1, Y1, X2, Y2);
 SetColor(CLR_BORDER);
 Rectangle(X1, Y1, X2, Y2);
 SetFillStyle(SolidFill, CLR_TITLEBAR_ACTIVE);
 Bar(X1 + 1, Y1 + 1, X2 - 1, Y1 + 16);
 SetColor(White);
 OutTextXY(X1 + 6, Y1 + 4, Title);
End;

{ ----------------------------------------------------------
  Widget BOUTON pour les boites de dialogue.
  - Hotkey marque avec '&' dans la legende (ex: '&Calculer').
  - IsDefault : active par [Entree].
  - IsCancel  : active par [Esc].
  - Souris : clic dans le rectangle -> active.
  ---------------------------------------------------------- }

Const
 DLG_BTN_H     = 22;
 DLG_BTN_W_MIN = 72;

Type
 TDlgButton = Record
  X1, Y1, X2, Y2 : Integer;
  Caption        : String[24];
  HotChar        : Char;     { lower-case, #0 si aucun }
  HotPos         : Integer;  { 1-based dans Caption epuree, 0 si aucun }
  IsDefault      : Boolean;
  IsCancel       : Boolean;
  Pressed        : Boolean;
 End;

 TDlgButtons = Array[0..7] Of TDlgButton;

Procedure InitDlgButton(Var B: TDlgButton; ACap: String;
                        ADef, ACancel: Boolean);
Var P: Integer;
Begin
 B.HotChar := #0;
 B.HotPos := 0;
 P := Pos('&', ACap);
 If (P > 0) And (P < Length(ACap)) Then Begin
  B.HotPos := P;
  B.HotChar := ACap[P + 1];
  If (B.HotChar >= 'A') And (B.HotChar <= 'Z') Then
   B.HotChar := Chr(Ord(B.HotChar) + 32);
  Delete(ACap, P, 1);
 End;
 B.Caption := ACap;
 B.IsDefault := ADef;
 B.IsCancel := ACancel;
 B.Pressed := False;
 B.X1 := 0; B.Y1 := 0; B.X2 := 0; B.Y2 := 0;
End;

Procedure LayoutDlgButtons(Var Btns: TDlgButtons; N: Integer;
                           DX1, DX2, Y: Integer);
Var I, W, TotW, Gap, X: Integer; Widths: Array[0..7] Of Integer;
Begin
 TotW := 0; Gap := 12;
 For I := 0 To N - 1 Do Begin
  W := Length(Btns[I].Caption) * 8 + 24;
  If W < DLG_BTN_W_MIN Then W := DLG_BTN_W_MIN;
  Widths[I] := W;
  TotW := TotW + W;
 End;
 X := ((DX1 + DX2) - (TotW + (N - 1) * Gap)) Div 2;
 For I := 0 To N - 1 Do Begin
  Btns[I].X1 := X;
  Btns[I].Y1 := Y;
  Btns[I].X2 := X + Widths[I];
  Btns[I].Y2 := Y + DLG_BTN_H;
  X := X + Widths[I] + Gap;
 End;
End;

Procedure DrawDlgButton(Var B: TDlgButton);
Var TX, TY, HX, UY: Integer;
Begin
 { Ombre }
 SetFillStyle(SolidFill, CLR_TITLEBAR);
 Bar(B.X1 + 2, B.Y1 + 2, B.X2 + 2, B.Y2 + 2);
 { Corps }
 SetFillStyle(SolidFill, CLR_BACKGROUND);
 Bar(B.X1, B.Y1, B.X2, B.Y2);
 { Relief 3D inverse si enfonce }
 If B.Pressed Then Begin
  SetColor(Black);
  Line(B.X1, B.Y1, B.X2, B.Y1);
  Line(B.X1, B.Y1, B.X1, B.Y2);
  SetColor(White);
  Line(B.X1, B.Y2, B.X2, B.Y2);
  Line(B.X2, B.Y1, B.X2, B.Y2);
 End Else Begin
  SetColor(White);
  Line(B.X1, B.Y1, B.X2, B.Y1);
  Line(B.X1, B.Y1, B.X1, B.Y2);
  SetColor(Black);
  Line(B.X1, B.Y2, B.X2, B.Y2);
  Line(B.X2, B.Y1, B.X2, B.Y2);
 End;
 { Cadre exterieur pour le bouton par defaut }
 If B.IsDefault Then Begin
  SetColor(Black);
  Rectangle(B.X1 - 2, B.Y1 - 2, B.X2 + 2, B.Y2 + 2);
 End;
 { Legende centree }
 TX := B.X1 + ((B.X2 - B.X1) - Length(B.Caption) * 8) Div 2;
 TY := B.Y1 + ((B.Y2 - B.Y1) - 8) Div 2;
 If B.Pressed Then Begin
  Inc(TX); Inc(TY);
 End;
 SetColor(Black);
 OutTextXY(TX, TY, B.Caption);
 If B.HotPos > 0 Then Begin
  HX := TX + (B.HotPos - 1) * 8;
  UY := TY + 9;
  Line(HX, UY, HX + 7, UY);
 End;
End;

Procedure DrawDlgButtons(Var Btns: TDlgButtons; N: Integer);
Var I: Integer;
Begin
 For I := 0 To N - 1 Do DrawDlgButton(Btns[I]);
End;

Function HitDlgButton(Var B: TDlgButton; MX, MY: Integer): Boolean;
Begin
 HitDlgButton := (MX >= B.X1) And (MX <= B.X2) And
                 (MY >= B.Y1) And (MY <= B.Y2);
End;

Procedure FlashDlgButton(Var B: TDlgButton);
Var T0, T: LongInt;
Begin
 B.Pressed := True;  DrawDlgButton(B);
 T0 := GetTimestamp;
 Repeat T := GetTimestamp Until (T - T0) >= 70;
 B.Pressed := False; DrawDlgButton(B);
End;

{ Verifie si l evenement active un bouton.
  Renvoie l index 0..N-1 active, ou -1 si aucun. }
Function HandleDlgButtonEvent(Var Btns: TDlgButtons; N: Integer;
                              Var Ev: TEvent): Integer;
Var I: Integer; LCh: Char;
Begin
 HandleDlgButtonEvent := -1;
 If Ev.Kind = EV_MOUSE_DOWN Then Begin
  For I := 0 To N - 1 Do
   If HitDlgButton(Btns[I], Ev.MouseX, Ev.MouseY) Then Begin
    FlashDlgButton(Btns[I]);
    HandleDlgButtonEvent := I;
    Exit;
   End;
 End
 Else If Ev.Kind = EV_KEY_CHAR Then Begin
  LCh := Ev.KeyChar;
  If LCh = #13 Then Begin
   For I := 0 To N - 1 Do
    If Btns[I].IsDefault Then Begin
     FlashDlgButton(Btns[I]); HandleDlgButtonEvent := I; Exit;
    End;
   Exit;
  End;
  If LCh = #27 Then Begin
   For I := 0 To N - 1 Do
    If Btns[I].IsCancel Then Begin
     FlashDlgButton(Btns[I]); HandleDlgButtonEvent := I; Exit;
    End;
   Exit;
  End;
  If (LCh >= 'A') And (LCh <= 'Z') Then LCh := Chr(Ord(LCh) + 32);
  For I := 0 To N - 1 Do
   If (Btns[I].HotChar <> #0) And (Btns[I].HotChar = LCh) Then Begin
    FlashDlgButton(Btns[I]);
    HandleDlgButtonEvent := I;
    Exit;
   End;
 End;
End;

Function ReadKeyChar(Var IsExt: Boolean): Char;
Var Ch: Char;
Begin
 While Not KeyPressed Do ;
 Ch := ReadKey;
 IsExt := False;
 If Ch = #0 Then Begin
  IsExt := True;
  If KeyPressed Then Ch := ReadKey;
 End;
 ReadKeyChar := Ch;
End;

{ Boite de saisie texte : boutons OK / Annuler.
  Retourne True si OK (mouse ou Entree), False si Annuler/Esc. }
Function InputBoxStr(Title, Prompt: String; Var Value: String;
 MaxLen: Integer): Boolean;
Var
 X1, Y1, X2, Y2, BX, BY: Integer;
 Ev: TEvent;
 Buf: String;
 BufSize: LongInt;
 BgBuf: Pointer;
 Btns: TDlgButtons;
 Hit: Integer;
 Done: Boolean;
 Caret: Boolean;
 LastBlink, Now: LongInt;

 Procedure DrawField;
 Begin
  SetFillStyle(SolidFill, White);
  Bar(BX, BY, X2 - 12, BY + 18);
  SetColor(CLR_BORDER);
  Rectangle(BX - 1, BY - 1, X2 - 11, BY + 19);
  SetColor(Black);
  OutTextXY(BX + 2, BY + 4, Buf);
  If Caret Then Begin
   SetColor(Black);
   Line(BX + 2 + Length(Buf) * 8, BY + 3,
        BX + 2 + Length(Buf) * 8, BY + 14);
  End;
 End;

Begin
 X1 := 100; Y1 := 170; X2 := 540; Y2 := 310;
 BufSize := ImageSize(X1, Y1, X2 + 4, Y2 + 4);
 GetMem(BgBuf, BufSize);
 GetImage(X1, Y1, X2 + 4, Y2 + 4, BgBuf^);
 DialogBox(X1, Y1, X2, Y2, Title);
 SetColor(Black);
 OutTextXY(X1 + 12, Y1 + 30, Prompt);
 BX := X1 + 12; BY := Y1 + 60;
 Buf := Value;
 Caret := True; LastBlink := GetTimestamp;
 DrawField;
 InitDlgButton(Btns[0], 'OK',      True,  False);
 InitDlgButton(Btns[1], 'Annuler', False, True);
 LayoutDlgButtons(Btns, 2, X1, X2, Y2 - DLG_BTN_H - 10);
 DrawDlgButtons(Btns, 2);
 InputBoxStr := False;
 Done := False;
 Repeat
  PollEvents(Ev);
  Now := GetTimestamp;
  If (Now - LastBlink) > 400 Then Begin
   Caret := Not Caret; LastBlink := Now; DrawField;
  End;
  If Ev.Kind = EV_NONE Then Begin
   Delay(15); Continue;
  End;
  Hit := HandleDlgButtonEvent(Btns, 2, Ev);
  If Hit = 0 Then Begin Value := Buf; InputBoxStr := True; Done := True; End
  Else If Hit = 1 Then Done := True
  Else If Ev.Kind = EV_KEY_CHAR Then Begin
   If Ev.KeyChar = #8 Then Begin
    If Length(Buf) > 0 Then Delete(Buf, Length(Buf), 1);
    Caret := True; DrawField;
   End
   Else If (Ev.KeyChar >= ' ') And (Length(Buf) < MaxLen) Then Begin
    Buf := Buf + Ev.KeyChar;
    Caret := True; DrawField;
   End;
  End;
 Until Done;
 PutImage(X1, Y1, BgBuf^, NormalPut);
 FreeMem(BgBuf, BufSize);
End;

Function InputBoxReal(Title, Prompt: String; Var V: Real): Boolean;
Var S: String;
Begin
 S := RealToStr(V, 1, 4);
 If InputBoxStr(Title, Prompt, S, 20) Then Begin
  V := StrToRealDef(S, V);
  InputBoxReal := True;
 End Else
  InputBoxReal := False;
End;

Function InputBoxInt(Title, Prompt: String; Var V: Integer): Boolean;
Var S: String; N: LongInt;
Begin
 S := IntToStr(V);
 If InputBoxStr(Title, Prompt, S, 12) Then Begin
  N := StrToIntDef(S, V);
  V := N;
  InputBoxInt := True;
 End Else
  InputBoxInt := False;
End;

Procedure MessageBox(Title: String; Lines: Array Of String);
Var
 X1, Y1, X2, Y2, I, MaxL: Integer;
 BufSize: LongInt;
 BgBuf: Pointer;
 Ev: TEvent;
 Btns: TDlgButtons;
 Done: Boolean;
Begin
 MaxL := 0;
 For I := 0 To High(Lines) Do
  If Length(Lines[I]) > MaxL Then MaxL := Length(Lines[I]);
 If MaxL < Length(Title) Then MaxL := Length(Title);
 If MaxL < 24 Then MaxL := 24;
 X1 := (SCREEN_W - (MaxL * 8 + 32)) Div 2;
 Y1 := 110;
 X2 := X1 + MaxL * 8 + 32;
 Y2 := Y1 + 36 + (High(Lines) + 1) * 14 + DLG_BTN_H + 18;
 BufSize := ImageSize(X1, Y1, X2 + 4, Y2 + 4);
 GetMem(BgBuf, BufSize);
 GetImage(X1, Y1, X2 + 4, Y2 + 4, BgBuf^);
 DialogBox(X1, Y1, X2, Y2, Title);
 SetColor(Black);
 For I := 0 To High(Lines) Do
  OutTextXY(X1 + 12, Y1 + 28 + I * 14, Lines[I]);
 InitDlgButton(Btns[0], 'OK', True, True);
 LayoutDlgButtons(Btns, 1, X1, X2, Y2 - DLG_BTN_H - 8);
 DrawDlgButtons(Btns, 1);
 Done := False;
 Repeat
  PollEvents(Ev);
  If Ev.Kind = EV_NONE Then Begin Delay(15); Continue; End;
  If HandleDlgButtonEvent(Btns, 1, Ev) >= 0 Then Done := True;
 Until Done;
 PutImage(X1, Y1, BgBuf^, NormalPut);
 FreeMem(BgBuf, BufSize);
End;

{ Choix d un element dans une liste : boutons OK / Annuler,
  navigation clavier (Up/Dn/Home/End) ou souris (clic = select,
  double-clic = valider). }
Function ChoiceBox(Title: String; Items: Array Of String;
 NItems: Integer; Var Idx: Integer): Boolean;
Var
 X1, Y1, X2, Y2, I, MaxL, N, Cur: Integer;
 LstX1, LstY1, LstX2, LstY2: Integer;
 BufSize: LongInt;
 BgBuf: Pointer;
 Ev: TEvent;
 Btns: TDlgButtons;
 Hit: Integer;
 Done: Boolean;

 Procedure RedrawList;
 Var J, YY: Integer;
 Begin
  SetFillStyle(SolidFill, CLR_BACKGROUND);
  Bar(LstX1, LstY1, LstX2, LstY2);
  For J := 0 To N - 1 Do Begin
   YY := LstY1 + 2 + J * 14;
   If J = Cur Then Begin
    SetFillStyle(SolidFill, CLR_MENU_HIGHLIGHT);
    Bar(LstX1 + 2, YY - 2, LstX2 - 2, YY + 11);
    SetColor(White);
   End Else
    SetColor(Black);
   OutTextXY(LstX1 + 6, YY, Items[J]);
  End;
  SetColor(CLR_BORDER);
  Rectangle(LstX1, LstY1, LstX2, LstY2);
 End;

Begin
 N := NItems;
 If N = 0 Then Begin ChoiceBox := False; Exit; End;
 MaxL := Length(Title);
 For I := 0 To N - 1 Do
  If Length(Items[I]) > MaxL Then MaxL := Length(Items[I]);
 X1 := (SCREEN_W - (MaxL * 8 + 40)) Div 2;
 Y1 := 70;
 X2 := X1 + MaxL * 8 + 40;
 Y2 := Y1 + 28 + N * 14 + 12 + DLG_BTN_H + 16;
 Cur := Idx;
 If (Cur < 0) Or (Cur >= N) Then Cur := 0;
 BufSize := ImageSize(X1, Y1, X2 + 4, Y2 + 4);
 GetMem(BgBuf, BufSize);
 GetImage(X1, Y1, X2 + 4, Y2 + 4, BgBuf^);
 DialogBox(X1, Y1, X2, Y2, Title);
 LstX1 := X1 + 8;   LstY1 := Y1 + 24;
 LstX2 := X2 - 8;   LstY2 := LstY1 + N * 14 + 4;
 RedrawList;
 InitDlgButton(Btns[0], 'OK',      True,  False);
 InitDlgButton(Btns[1], 'Annuler', False, True);
 LayoutDlgButtons(Btns, 2, X1, X2, Y2 - DLG_BTN_H - 8);
 DrawDlgButtons(Btns, 2);
 ChoiceBox := False;
 Done := False;
 Repeat
  PollEvents(Ev);
  If Ev.Kind = EV_NONE Then Begin Delay(15); Continue; End;
  { Selection souris sur la liste }
  If (Ev.Kind = EV_MOUSE_DOWN) Or (Ev.Kind = EV_MOUSE_DBLCLICK) Then
   If (Ev.MouseX >= LstX1) And (Ev.MouseX <= LstX2) And
      (Ev.MouseY >= LstY1) And (Ev.MouseY <= LstY2) Then Begin
    I := (Ev.MouseY - LstY1 - 2) Div 14;
    If (I >= 0) And (I < N) Then Begin
     Cur := I; RedrawList;
     If Ev.Kind = EV_MOUSE_DBLCLICK Then Begin
      Idx := Cur; ChoiceBox := True; Done := True; Continue;
     End;
    End;
    Continue;
   End;
  Hit := HandleDlgButtonEvent(Btns, 2, Ev);
  If Hit = 0 Then Begin
   Idx := Cur; ChoiceBox := True; Done := True;
  End
  Else If Hit = 1 Then Done := True
  Else If Ev.Kind = EV_KEY_DOWN Then Begin
   Case Ev.KeyCode Of
    72: If Cur > 0       Then Begin Dec(Cur); RedrawList; End;
    80: If Cur < N - 1   Then Begin Inc(Cur); RedrawList; End;
    71: Begin Cur := 0;     RedrawList; End;     { Home }
    79: Begin Cur := N - 1; RedrawList; End;     { End  }
   End;
  End;
 Until Done;
 PutImage(X1, Y1, BgBuf^, NormalPut);
 FreeMem(BgBuf, BufSize);
End;

{ ============================================================
  CATALOGUE DE FORMULES PHYSIQUES
  ============================================================ }

Procedure AddFormulaVar(Var F: TFormula; AName, ASymb, AUnit: String);
Begin
 If F.NVars < MAX_FORM_VARS Then Begin
  F.Vars[F.NVars].Name := AName;
  F.Vars[F.NVars].Symbol := ASymb;
  F.Vars[F.NVars].Unite := AUnit;
  F.Vars[F.NVars].Value := 0;
  F.Vars[F.NVars].Known := False;
  Inc(F.NVars);
 End;
End;

Procedure AddFormula(AName, AExpr: String; ACat: TFormulaCat;
 ASolveProc: Integer);
Begin
 If NFormulas < MAX_FORMULAS Then Begin
  Formulas[NFormulas].Name := AName;
  Formulas[NFormulas].Expr := AExpr;
  Formulas[NFormulas].Category := ACat;
  Formulas[NFormulas].NVars := 0;
  Formulas[NFormulas].SolveProc := ASolveProc;
  Formulas[NFormulas].PlotXIdx := -1;
  Formulas[NFormulas].PlotYIdx := -1;
  Inc(NFormulas);
 End;
End;

{ Solveur generique : F.Vars[Unknown] est l inconnue.
  L index ASolveProc choisit l expression.
  Convention : retourne True si solution trouvee.

  Tables : voir InitFormulas pour la liste des formules.
  Chaque entree solveur connait sa formule. }

Function SolveFormula(Var F: TFormula; Unk: Integer): Boolean;
Var
 V: Array[0..5] Of Real;
 I: Integer;
 R: Real;
 Ok: Boolean;
Begin
 For I := 0 To F.NVars - 1 Do V[I] := F.Vars[I].Value;
 Ok := True;
 R := 0;
 Case F.SolveProc Of
  { ===== CINEMATIQUE ===== }
  1: Begin { v = v0 + a*t : vars [v, v0, a, t] }
   Case Unk Of
    0: R := V[1] + V[2] * V[3];
    1: R := V[0] - V[2] * V[3];
    2: If V[3] <> 0 Then R := (V[0] - V[1]) / V[3] Else Ok := False;
    3: If V[2] <> 0 Then R := (V[0] - V[1]) / V[2] Else Ok := False;
   End;
  End;
  2: Begin { x = x0 + v0*t + 1/2 a t^2 : [x, x0, v0, a, t] }
   Case Unk Of
    0: R := V[1] + V[2] * V[4] + 0.5 * V[3] * V[4] * V[4];
    1: R := V[0] - V[2] * V[4] - 0.5 * V[3] * V[4] * V[4];
    2: If V[4] <> 0 Then R := (V[0] - V[1] - 0.5 * V[3] * V[4] * V[4]) / V[4]
       Else Ok := False;
    3: If V[4] <> 0 Then R := 2 * (V[0] - V[1] - V[2] * V[4]) / (V[4] * V[4])
       Else Ok := False;
   Else Ok := False;
   End;
  End;
  3: Begin { v^2 = v0^2 + 2 a (x - x0) : [v, v0, a, x, x0] }
   Case Unk Of
    0: R := Sqrt(V[1] * V[1] + 2 * V[2] * (V[3] - V[4]));
    1: R := Sqrt(V[0] * V[0] - 2 * V[2] * (V[3] - V[4]));
    2: If V[3] - V[4] <> 0 Then R := (V[0] * V[0] - V[1] * V[1]) / (2 * (V[3] - V[4]))
       Else Ok := False;
   Else Ok := False;
   End;
  End;
  4: Begin { ac = v^2/r (MCU) : [ac, v, r] }
   Case Unk Of
    0: If V[2] <> 0 Then R := V[1] * V[1] / V[2] Else Ok := False;
    1: If V[2] <> 0 Then R := Sqrt(V[0] * V[2]) Else Ok := False;
    2: If V[0] <> 0 Then R := V[1] * V[1] / V[0] Else Ok := False;
   End;
  End;
  5: Begin { omega = 2 pi / T = 2 pi f : [omega, T, f] }
   Case Unk Of
    0: If V[1] <> 0 Then R := 2 * PHY_PI / V[1] Else R := 2 * PHY_PI * V[2];
    1: If V[0] <> 0 Then R := 2 * PHY_PI / V[0] Else Ok := False;
    2: R := V[0] / (2 * PHY_PI);
   End;
  End;
  { ===== DYNAMIQUE ===== }
  10: Begin { F = m a : [F, m, a] }
   Case Unk Of
    0: R := V[1] * V[2];
    1: If V[2] <> 0 Then R := V[0] / V[2] Else Ok := False;
    2: If V[1] <> 0 Then R := V[0] / V[1] Else Ok := False;
   End;
  End;
  11: Begin { p = m v : [p, m, v] }
   Case Unk Of
    0: R := V[1] * V[2];
    1: If V[2] <> 0 Then R := V[0] / V[2] Else Ok := False;
    2: If V[1] <> 0 Then R := V[0] / V[1] Else Ok := False;
   End;
  End;
  12: Begin { F = G m1 m2 / r^2 : [F, m1, m2, r] }
   Case Unk Of
    0: If V[3] <> 0 Then R := PHY_G * V[1] * V[2] / (V[3] * V[3]) Else Ok := False;
    3: If V[0] <> 0 Then R := Sqrt(PHY_G * V[1] * V[2] / V[0]) Else Ok := False;
   Else Ok := False;
   End;
  End;
  13: Begin { F = -k x (ressort, valeur absolue) : [F, k, x] }
   Case Unk Of
    0: R := V[1] * V[2];
    1: If V[2] <> 0 Then R := V[0] / V[2] Else Ok := False;
    2: If V[1] <> 0 Then R := V[0] / V[1] Else Ok := False;
   End;
  End;
  { ===== ENERGIE ===== }
  20: Begin { Ec = 1/2 m v^2 : [Ec, m, v] }
   Case Unk Of
    0: R := 0.5 * V[1] * V[2] * V[2];
    1: If V[2] <> 0 Then R := 2 * V[0] / (V[2] * V[2]) Else Ok := False;
    2: If V[1] <> 0 Then R := Sqrt(2 * V[0] / V[1]) Else Ok := False;
   End;
  End;
  21: Begin { Ep = m g h : [Ep, m, g, h] }
   Case Unk Of
    0: R := V[1] * V[2] * V[3];
    1: If V[2] * V[3] <> 0 Then R := V[0] / (V[2] * V[3]) Else Ok := False;
    2: If V[1] * V[3] <> 0 Then R := V[0] / (V[1] * V[3]) Else Ok := False;
    3: If V[1] * V[2] <> 0 Then R := V[0] / (V[1] * V[2]) Else Ok := False;
   End;
  End;
  22: Begin { W = F d cos(theta) : [W, F, d, theta_rad] }
   Case Unk Of
    0: R := V[1] * V[2] * Cos(V[3]);
    1: If V[2] * Cos(V[3]) <> 0 Then R := V[0] / (V[2] * Cos(V[3])) Else Ok := False;
    2: If V[1] * Cos(V[3]) <> 0 Then R := V[0] / (V[1] * Cos(V[3])) Else Ok := False;
   Else Ok := False;
   End;
  End;
  23: Begin { P = W / t : [P, W, t] }
   Case Unk Of
    0: If V[2] <> 0 Then R := V[1] / V[2] Else Ok := False;
    1: R := V[0] * V[2];
    2: If V[0] <> 0 Then R := V[1] / V[0] Else Ok := False;
   End;
  End;
  24: Begin { Eressort = 1/2 k x^2 : [E, k, x] }
   Case Unk Of
    0: R := 0.5 * V[1] * V[2] * V[2];
    1: If V[2] <> 0 Then R := 2 * V[0] / (V[2] * V[2]) Else Ok := False;
    2: If V[1] <> 0 Then R := Sqrt(2 * V[0] / V[1]) Else Ok := False;
   End;
  End;
  { ===== GRAVITATION ===== }
  30: Begin { g = G M / r^2 : [g, M, r] }
   Case Unk Of
    0: If V[2] <> 0 Then R := PHY_G * V[1] / (V[2] * V[2]) Else Ok := False;
    1: If V[2] <> 0 Then R := V[0] * V[2] * V[2] / PHY_G Else Ok := False;
    2: If V[0] <> 0 Then R := Sqrt(PHY_G * V[1] / V[0]) Else Ok := False;
   End;
  End;
  31: Begin { v_orbite = sqrt(G M / r) : [v, M, r] }
   Case Unk Of
    0: If V[2] <> 0 Then R := Sqrt(PHY_G * V[1] / V[2]) Else Ok := False;
    1: If V[2] <> 0 Then R := V[0] * V[0] * V[2] / PHY_G Else Ok := False;
    2: If V[0] <> 0 Then R := PHY_G * V[1] / (V[0] * V[0]) Else Ok := False;
   End;
  End;
  32: Begin { T^2 = 4 pi^2 r^3 / (G M) (Kepler) : [T, r, M] }
   Case Unk Of
    0: R := Sqrt(4 * PHY_PI * PHY_PI * V[1] * V[1] * V[1] / (PHY_G * V[2]));
   Else Ok := False;
   End;
  End;
  { ===== OSCILLATIONS ===== }
  40: Begin { omega = sqrt(k/m) : [omega, k, m] }
   Case Unk Of
    0: If V[2] <> 0 Then R := Sqrt(V[1] / V[2]) Else Ok := False;
    1: R := V[0] * V[0] * V[2];
    2: If V[0] <> 0 Then R := V[1] / (V[0] * V[0]) Else Ok := False;
   End;
  End;
  41: Begin { omega = sqrt(g/L) : [omega, g, L] }
   Case Unk Of
    0: If V[2] <> 0 Then R := Sqrt(V[1] / V[2]) Else Ok := False;
    1: R := V[0] * V[0] * V[2];
    2: If V[0] <> 0 Then R := V[1] / (V[0] * V[0]) Else Ok := False;
   End;
  End;
  { ===== ONDES ===== }
  50: Begin { v = lambda f : [v, lambda, f] }
   Case Unk Of
    0: R := V[1] * V[2];
    1: If V[2] <> 0 Then R := V[0] / V[2] Else Ok := False;
    2: If V[1] <> 0 Then R := V[0] / V[1] Else Ok := False;
   End;
  End;
  51: Begin { I = P / (4 pi r^2) : [I, P, r] }
   Case Unk Of
    0: If V[2] <> 0 Then R := V[1] / (4 * PHY_PI * V[2] * V[2]) Else Ok := False;
    1: R := V[0] * 4 * PHY_PI * V[2] * V[2];
    2: If V[0] <> 0 Then R := Sqrt(V[1] / (4 * PHY_PI * V[0])) Else Ok := False;
   End;
  End;
  { ===== OPTIQUE ===== }
  60: Begin { Snell : n1 sin(t1) = n2 sin(t2) : [n1, t1_rad, n2, t2_rad] }
   Case Unk Of
    0: If Sin(V[1]) <> 0 Then R := V[2] * Sin(V[3]) / Sin(V[1]) Else Ok := False;
    1: If V[0] <> 0 Then R := ArcSin(V[2] * Sin(V[3]) / V[0]) Else Ok := False;
    2: If Sin(V[3]) <> 0 Then R := V[0] * Sin(V[1]) / Sin(V[3]) Else Ok := False;
    3: If V[2] <> 0 Then R := ArcSin(V[0] * Sin(V[1]) / V[2]) Else Ok := False;
   End;
  End;
  61: Begin { 1/f = 1/p + 1/q : [f, p, q] }
   Case Unk Of
    0: If (V[1] + V[2]) <> 0 Then R := V[1] * V[2] / (V[1] + V[2]) Else Ok := False;
    1: If (V[2] - V[0]) <> 0 Then R := V[0] * V[2] / (V[2] - V[0]) Else Ok := False;
    2: If (V[1] - V[0]) <> 0 Then R := V[0] * V[1] / (V[1] - V[0]) Else Ok := False;
   End;
  End;
  { ===== ELECTROMAGNETISME ===== }
  70: Begin { F = k q1 q2 / r^2 : [F, q1, q2, r] }
   Case Unk Of
    0: If V[3] <> 0 Then R := PHY_K_COULOMB * V[1] * V[2] / (V[3] * V[3]) Else Ok := False;
    3: If V[0] <> 0 Then R := Sqrt(PHY_K_COULOMB * V[1] * V[2] / V[0]) Else Ok := False;
   Else Ok := False;
   End;
  End;
  71: Begin { E = k q / r^2 : [E, q, r] }
   Case Unk Of
    0: If V[2] <> 0 Then R := PHY_K_COULOMB * V[1] / (V[2] * V[2]) Else Ok := False;
    1: If V[2] <> 0 Then R := V[0] * V[2] * V[2] / PHY_K_COULOMB Else Ok := False;
    2: If V[0] <> 0 Then R := Sqrt(PHY_K_COULOMB * V[1] / V[0]) Else Ok := False;
   End;
  End;
  72: Begin { U = R I (loi d Ohm) : [U, R, I] }
   Case Unk Of
    0: R := V[1] * V[2];
    1: If V[2] <> 0 Then R := V[0] / V[2] Else Ok := False;
    2: If V[1] <> 0 Then R := V[0] / V[1] Else Ok := False;
   End;
  End;
  73: Begin { P = U I : [P, U, I] }
   Case Unk Of
    0: R := V[1] * V[2];
    1: If V[2] <> 0 Then R := V[0] / V[2] Else Ok := False;
    2: If V[1] <> 0 Then R := V[0] / V[1] Else Ok := False;
   End;
  End;
  74: Begin { B = mu0 I / (2 pi r) (fil infini) : [B, I, r] }
   Case Unk Of
    0: If V[2] <> 0 Then R := PHY_MU0 * V[1] / (2 * PHY_PI * V[2]) Else Ok := False;
    1: R := V[0] * 2 * PHY_PI * V[2] / PHY_MU0;
    2: If V[0] <> 0 Then R := PHY_MU0 * V[1] / (2 * PHY_PI * V[0]) Else Ok := False;
   End;
  End;
  75: Begin { F = B I L (Laplace) : [F, B, I, L] }
   Case Unk Of
    0: R := V[1] * V[2] * V[3];
    1: If V[2] * V[3] <> 0 Then R := V[0] / (V[2] * V[3]) Else Ok := False;
    2: If V[1] * V[3] <> 0 Then R := V[0] / (V[1] * V[3]) Else Ok := False;
    3: If V[1] * V[2] <> 0 Then R := V[0] / (V[1] * V[2]) Else Ok := False;
   End;
  End;
  76: Begin { Q = C U : [Q, C, U] }
   Case Unk Of
    0: R := V[1] * V[2];
    1: If V[2] <> 0 Then R := V[0] / V[2] Else Ok := False;
    2: If V[1] <> 0 Then R := V[0] / V[1] Else Ok := False;
   End;
  End;
  { ===== THERMODYNAMIQUE ===== }
  80: Begin { Q = m c DT : [Q, m, c, DT] }
   Case Unk Of
    0: R := V[1] * V[2] * V[3];
    1: If V[2] * V[3] <> 0 Then R := V[0] / (V[2] * V[3]) Else Ok := False;
    2: If V[1] * V[3] <> 0 Then R := V[0] / (V[1] * V[3]) Else Ok := False;
    3: If V[1] * V[2] <> 0 Then R := V[0] / (V[1] * V[2]) Else Ok := False;
   End;
  End;
  81: Begin { PV = nRT : [P, V, n, T] }
   Case Unk Of
    0: If V[1] <> 0 Then R := V[2] * PHY_R_GAS * V[3] / V[1] Else Ok := False;
    1: If V[0] <> 0 Then R := V[2] * PHY_R_GAS * V[3] / V[0] Else Ok := False;
    2: If V[3] <> 0 Then R := V[0] * V[1] / (PHY_R_GAS * V[3]) Else Ok := False;
    3: If V[2] <> 0 Then R := V[0] * V[1] / (V[2] * PHY_R_GAS) Else Ok := False;
   End;
  End;
  82: Begin { eta_Carnot = 1 - Tc/Tf : [eta, Tc, Tf] }
   Case Unk Of
    0: If V[2] <> 0 Then R := 1 - V[1] / V[2] Else Ok := False;
    1: R := V[2] * (1 - V[0]);
    2: If (1 - V[0]) <> 0 Then R := V[1] / (1 - V[0]) Else Ok := False;
   End;
  End;
  83: Begin { Stefan : P = sigma T^4 A : [P, T, A] }
   Case Unk Of
    0: R := PHY_SIGMA_SB * V[1] * V[1] * V[1] * V[1] * V[2];
    1: If V[2] <> 0 Then R := RPower(V[0] / (PHY_SIGMA_SB * V[2]), 0.25) Else Ok := False;
    2: If V[1] <> 0 Then R := V[0] / (PHY_SIGMA_SB * V[1] * V[1] * V[1] * V[1]) Else Ok := False;
   End;
  End;
  { ===== RELATIVITE RESTREINTE ===== }
  90: Begin { gamma = 1/sqrt(1-beta^2) : [gamma, beta] }
   Case Unk Of
    0: If 1 - V[1] * V[1] > 0 Then R := 1 / Sqrt(1 - V[1] * V[1]) Else Ok := False;
    1: If V[0] > 0 Then R := Sqrt(1 - 1 / (V[0] * V[0])) Else Ok := False;
   End;
  End;
  91: Begin { E = gamma m c^2 (en MeV avec m en MeV) : [E, gamma, m] }
   Case Unk Of
    0: R := V[1] * V[2];
    1: If V[2] <> 0 Then R := V[0] / V[2] Else Ok := False;
    2: If V[1] <> 0 Then R := V[0] / V[1] Else Ok := False;
   End;
  End;
  92: Begin { E^2 = (pc)^2 + (mc^2)^2 : [E, p, m] (MeV) }
   Case Unk Of
    0: R := Sqrt(V[1] * V[1] + V[2] * V[2]);
    1: If V[0] * V[0] - V[2] * V[2] >= 0 Then R := Sqrt(V[0] * V[0] - V[2] * V[2]) Else Ok := False;
    2: If V[0] * V[0] - V[1] * V[1] >= 0 Then R := Sqrt(V[0] * V[0] - V[1] * V[1]) Else Ok := False;
   End;
  End;
  { ===== QUANTIQUE ===== }
  100: Begin { E = h f : [E, f] (E en J, f en Hz) }
   Case Unk Of
    0: R := PHY_H * V[1];
    1: R := V[0] / PHY_H;
   End;
  End;
  101: Begin { lambda = h / p (de Broglie) : [lambda, p] (SI) }
   Case Unk Of
    0: If V[1] <> 0 Then R := PHY_H / V[1] Else Ok := False;
    1: If V[0] <> 0 Then R := PHY_H / V[0] Else Ok := False;
   End;
  End;
  102: Begin { E_photoel = h f - W : [Ec, f, W] (J) }
   Case Unk Of
    0: R := PHY_H * V[1] - V[2];
    1: R := (V[0] + V[2]) / PHY_H;
    2: R := PHY_H * V[1] - V[0];
   End;
  End;
  103: Begin { E_n = -13.6/n^2 eV (Bohr) : [E_eV, n] }
   Case Unk Of
    0: If V[1] <> 0 Then R := -13.6 / (V[1] * V[1]) Else Ok := False;
    1: If V[0] < 0 Then R := Sqrt(-13.6 / V[0]) Else Ok := False;
   End;
  End;
  Else Ok := False;
 End;
 If Ok Then Begin
  F.Vars[Unk].Value := R;
  F.Vars[Unk].Known := True;
 End;
 SolveFormula := Ok;
End;

Procedure InitFormulas;
Begin
 NFormulas := 0;

 { Cinematique }
 AddFormula('v = v0 + a*t', 'v = v0 + a*t', fcCinematique, 1);
 AddFormulaVar(Formulas[NFormulas-1], 'vitesse', 'v', 'm/s');
 AddFormulaVar(Formulas[NFormulas-1], 'v initiale', 'v0', 'm/s');
 AddFormulaVar(Formulas[NFormulas-1], 'acceleration', 'a', 'm/s2');
 AddFormulaVar(Formulas[NFormulas-1], 'temps', 't', 's');

 AddFormula('x = x0 + v0*t + 1/2 a*t2', 'x = x0+v0t+1/2at2',
            fcCinematique, 2);
 AddFormulaVar(Formulas[NFormulas-1], 'position', 'x', 'm');
 AddFormulaVar(Formulas[NFormulas-1], 'pos init', 'x0', 'm');
 AddFormulaVar(Formulas[NFormulas-1], 'v init', 'v0', 'm/s');
 AddFormulaVar(Formulas[NFormulas-1], 'acceleration', 'a', 'm/s2');
 AddFormulaVar(Formulas[NFormulas-1], 'temps', 't', 's');

 AddFormula('v2 = v02 + 2a*Dx', 'v2 = v02 + 2a(x-x0)',
            fcCinematique, 3);
 AddFormulaVar(Formulas[NFormulas-1], 'vitesse', 'v', 'm/s');
 AddFormulaVar(Formulas[NFormulas-1], 'v initiale', 'v0', 'm/s');
 AddFormulaVar(Formulas[NFormulas-1], 'acceleration', 'a', 'm/s2');
 AddFormulaVar(Formulas[NFormulas-1], 'position', 'x', 'm');
 AddFormulaVar(Formulas[NFormulas-1], 'pos init', 'x0', 'm');

 AddFormula('ac = v2 / r (MCU)', 'ac = v2/r', fcCinematique, 4);
 AddFormulaVar(Formulas[NFormulas-1], 'acc. centripete', 'ac', 'm/s2');
 AddFormulaVar(Formulas[NFormulas-1], 'vitesse', 'v', 'm/s');
 AddFormulaVar(Formulas[NFormulas-1], 'rayon', 'r', 'm');

 AddFormula('omega = 2 pi / T = 2 pi f',
            'w = 2pi/T = 2pi f', fcCinematique, 5);
 AddFormulaVar(Formulas[NFormulas-1], 'pulsation', 'w', 'rad/s');
 AddFormulaVar(Formulas[NFormulas-1], 'periode', 'T', 's');
 AddFormulaVar(Formulas[NFormulas-1], 'frequence', 'f', 'Hz');

 { Dynamique }
 AddFormula('F = m*a (2e loi Newton)', 'F = m*a', fcDynamique, 10);
 AddFormulaVar(Formulas[NFormulas-1], 'force', 'F', 'N');
 AddFormulaVar(Formulas[NFormulas-1], 'masse', 'm', 'kg');
 AddFormulaVar(Formulas[NFormulas-1], 'acceleration', 'a', 'm/s2');

 AddFormula('p = m*v (quantite mouvement)',
            'p = m*v', fcDynamique, 11);
 AddFormulaVar(Formulas[NFormulas-1], 'imp.', 'p', 'kg.m/s');
 AddFormulaVar(Formulas[NFormulas-1], 'masse', 'm', 'kg');
 AddFormulaVar(Formulas[NFormulas-1], 'vitesse', 'v', 'm/s');

 AddFormula('F = G m1 m2 / r2 (gravit.)',
            'F = Gm1m2/r2', fcDynamique, 12);
 AddFormulaVar(Formulas[NFormulas-1], 'force', 'F', 'N');
 AddFormulaVar(Formulas[NFormulas-1], 'masse 1', 'm1', 'kg');
 AddFormulaVar(Formulas[NFormulas-1], 'masse 2', 'm2', 'kg');
 AddFormulaVar(Formulas[NFormulas-1], 'distance', 'r', 'm');

 AddFormula('F = k x (ressort)', 'F = k*x', fcDynamique, 13);
 AddFormulaVar(Formulas[NFormulas-1], 'force', 'F', 'N');
 AddFormulaVar(Formulas[NFormulas-1], 'raideur', 'k', 'N/m');
 AddFormulaVar(Formulas[NFormulas-1], 'allongement', 'x', 'm');

 { Energie }
 AddFormula('Ec = 1/2 m v2', 'Ec = 1/2 mv2', fcEnergie, 20);
 AddFormulaVar(Formulas[NFormulas-1], 'energie cin.', 'Ec', 'J');
 AddFormulaVar(Formulas[NFormulas-1], 'masse', 'm', 'kg');
 AddFormulaVar(Formulas[NFormulas-1], 'vitesse', 'v', 'm/s');

 AddFormula('Ep = m g h', 'Ep = mgh', fcEnergie, 21);
 AddFormulaVar(Formulas[NFormulas-1], 'energie pot.', 'Ep', 'J');
 AddFormulaVar(Formulas[NFormulas-1], 'masse', 'm', 'kg');
 AddFormulaVar(Formulas[NFormulas-1], 'gravite', 'g', 'm/s2');
 AddFormulaVar(Formulas[NFormulas-1], 'hauteur', 'h', 'm');

 AddFormula('W = F d cos(theta)', 'W = F.d.cos(th)', fcEnergie, 22);
 AddFormulaVar(Formulas[NFormulas-1], 'travail', 'W', 'J');
 AddFormulaVar(Formulas[NFormulas-1], 'force', 'F', 'N');
 AddFormulaVar(Formulas[NFormulas-1], 'distance', 'd', 'm');
 AddFormulaVar(Formulas[NFormulas-1], 'angle (rad)', 'th', 'rad');

 AddFormula('P = W / t (puissance)', 'P = W/t', fcEnergie, 23);
 AddFormulaVar(Formulas[NFormulas-1], 'puissance', 'P', 'W');
 AddFormulaVar(Formulas[NFormulas-1], 'travail', 'W', 'J');
 AddFormulaVar(Formulas[NFormulas-1], 'temps', 't', 's');

 AddFormula('E = 1/2 k x2 (ressort)', 'E = 1/2 kx2', fcEnergie, 24);
 AddFormulaVar(Formulas[NFormulas-1], 'energie', 'E', 'J');
 AddFormulaVar(Formulas[NFormulas-1], 'raideur', 'k', 'N/m');
 AddFormulaVar(Formulas[NFormulas-1], 'allongement', 'x', 'm');

 { Gravitation }
 AddFormula('g = G M / r2', 'g = GM/r2', fcGravitation, 30);
 AddFormulaVar(Formulas[NFormulas-1], 'gravite', 'g', 'm/s2');
 AddFormulaVar(Formulas[NFormulas-1], 'masse astre', 'M', 'kg');
 AddFormulaVar(Formulas[NFormulas-1], 'distance', 'r', 'm');

 AddFormula('v_orbite = sqrt(GM/r)', 'v = sqrt(GM/r)',
            fcGravitation, 31);
 AddFormulaVar(Formulas[NFormulas-1], 'v orbitale', 'v', 'm/s');
 AddFormulaVar(Formulas[NFormulas-1], 'masse astre', 'M', 'kg');
 AddFormulaVar(Formulas[NFormulas-1], 'rayon', 'r', 'm');

 AddFormula('T = 2pi sqrt(r3/(GM)) (Kepler)',
            'T2 = 4pi2 r3/GM', fcGravitation, 32);
 AddFormulaVar(Formulas[NFormulas-1], 'periode', 'T', 's');
 AddFormulaVar(Formulas[NFormulas-1], 'rayon', 'r', 'm');
 AddFormulaVar(Formulas[NFormulas-1], 'masse astre', 'M', 'kg');

 { Oscillations }
 AddFormula('omega = sqrt(k/m) ressort', 'w = sqrt(k/m)',
            fcOscillations, 40);
 AddFormulaVar(Formulas[NFormulas-1], 'pulsation', 'w', 'rad/s');
 AddFormulaVar(Formulas[NFormulas-1], 'raideur', 'k', 'N/m');
 AddFormulaVar(Formulas[NFormulas-1], 'masse', 'm', 'kg');

 AddFormula('omega = sqrt(g/L) pendule',
            'w = sqrt(g/L)', fcOscillations, 41);
 AddFormulaVar(Formulas[NFormulas-1], 'pulsation', 'w', 'rad/s');
 AddFormulaVar(Formulas[NFormulas-1], 'gravite', 'g', 'm/s2');
 AddFormulaVar(Formulas[NFormulas-1], 'longueur', 'L', 'm');

 { Ondes }
 AddFormula('v = lambda * f', 'v = L*f', fcOndes, 50);
 AddFormulaVar(Formulas[NFormulas-1], 'vitesse', 'v', 'm/s');
 AddFormulaVar(Formulas[NFormulas-1], 'longueur o.', 'L', 'm');
 AddFormulaVar(Formulas[NFormulas-1], 'frequence', 'f', 'Hz');

 AddFormula('I = P / (4pi r2) intensite',
            'I = P/(4pi r2)', fcOndes, 51);
 AddFormulaVar(Formulas[NFormulas-1], 'intensite', 'I', 'W/m2');
 AddFormulaVar(Formulas[NFormulas-1], 'puissance', 'P', 'W');
 AddFormulaVar(Formulas[NFormulas-1], 'distance', 'r', 'm');

 { Optique }
 AddFormula('Snell : n1 sin(t1) = n2 sin(t2)',
            'n1.sin(t1)=n2.sin(t2)', fcOptique, 60);
 AddFormulaVar(Formulas[NFormulas-1], 'indice 1', 'n1', '-');
 AddFormulaVar(Formulas[NFormulas-1], 'angle 1', 't1', 'rad');
 AddFormulaVar(Formulas[NFormulas-1], 'indice 2', 'n2', '-');
 AddFormulaVar(Formulas[NFormulas-1], 'angle 2', 't2', 'rad');

 AddFormula('1/f = 1/p + 1/q (lentille)',
            '1/f=1/p+1/q', fcOptique, 61);
 AddFormulaVar(Formulas[NFormulas-1], 'focale', 'f', 'm');
 AddFormulaVar(Formulas[NFormulas-1], 'dist. obj.', 'p', 'm');
 AddFormulaVar(Formulas[NFormulas-1], 'dist. img.', 'q', 'm');

 { Electromagnetisme }
 AddFormula('F = k q1 q2 / r2 (Coulomb)',
            'F = kq1q2/r2', fcElectroMag, 70);
 AddFormulaVar(Formulas[NFormulas-1], 'force', 'F', 'N');
 AddFormulaVar(Formulas[NFormulas-1], 'charge 1', 'q1', 'C');
 AddFormulaVar(Formulas[NFormulas-1], 'charge 2', 'q2', 'C');
 AddFormulaVar(Formulas[NFormulas-1], 'distance', 'r', 'm');

 AddFormula('E = k q / r2 (champ E)',
            'E = kq/r2', fcElectroMag, 71);
 AddFormulaVar(Formulas[NFormulas-1], 'champ', 'E', 'V/m');
 AddFormulaVar(Formulas[NFormulas-1], 'charge', 'q', 'C');
 AddFormulaVar(Formulas[NFormulas-1], 'distance', 'r', 'm');

 AddFormula('U = R I (loi d Ohm)', 'U = R*I', fcElectroMag, 72);
 AddFormulaVar(Formulas[NFormulas-1], 'tension', 'U', 'V');
 AddFormulaVar(Formulas[NFormulas-1], 'resistance', 'R', 'Ohm');
 AddFormulaVar(Formulas[NFormulas-1], 'courant', 'I', 'A');

 AddFormula('P = U I (puissance elec.)',
            'P = U*I', fcElectroMag, 73);
 AddFormulaVar(Formulas[NFormulas-1], 'puissance', 'P', 'W');
 AddFormulaVar(Formulas[NFormulas-1], 'tension', 'U', 'V');
 AddFormulaVar(Formulas[NFormulas-1], 'courant', 'I', 'A');

 AddFormula('B = mu0 I / (2pi r) (fil)',
            'B = mu0 I/(2pi r)', fcElectroMag, 74);
 AddFormulaVar(Formulas[NFormulas-1], 'champ B', 'B', 'T');
 AddFormulaVar(Formulas[NFormulas-1], 'courant', 'I', 'A');
 AddFormulaVar(Formulas[NFormulas-1], 'distance', 'r', 'm');

 AddFormula('F = B I L (Laplace)',
            'F = BIL', fcElectroMag, 75);
 AddFormulaVar(Formulas[NFormulas-1], 'force', 'F', 'N');
 AddFormulaVar(Formulas[NFormulas-1], 'champ B', 'B', 'T');
 AddFormulaVar(Formulas[NFormulas-1], 'courant', 'I', 'A');
 AddFormulaVar(Formulas[NFormulas-1], 'longueur', 'L', 'm');

 AddFormula('Q = C U (condensateur)',
            'Q = C*U', fcElectroMag, 76);
 AddFormulaVar(Formulas[NFormulas-1], 'charge', 'Q', 'C');
 AddFormulaVar(Formulas[NFormulas-1], 'capacite', 'C', 'F');
 AddFormulaVar(Formulas[NFormulas-1], 'tension', 'U', 'V');

 { Thermodynamique }
 AddFormula('Q = m c DT (chaleur)', 'Q = mc.DT', fcThermo, 80);
 AddFormulaVar(Formulas[NFormulas-1], 'chaleur', 'Q', 'J');
 AddFormulaVar(Formulas[NFormulas-1], 'masse', 'm', 'kg');
 AddFormulaVar(Formulas[NFormulas-1], 'cap. mass.', 'c', 'J/(kg.K)');
 AddFormulaVar(Formulas[NFormulas-1], 'delta T', 'DT', 'K');

 AddFormula('PV = nRT (gaz parfait)', 'PV = nRT', fcThermo, 81);
 AddFormulaVar(Formulas[NFormulas-1], 'pression', 'P', 'Pa');
 AddFormulaVar(Formulas[NFormulas-1], 'volume', 'V', 'm3');
 AddFormulaVar(Formulas[NFormulas-1], 'qte matiere', 'n', 'mol');
 AddFormulaVar(Formulas[NFormulas-1], 'temperature', 'T', 'K');

 AddFormula('eta = 1 - Tc/Tf (Carnot)',
            'eta = 1-Tc/Tf', fcThermo, 82);
 AddFormulaVar(Formulas[NFormulas-1], 'rendement', 'eta', '-');
 AddFormulaVar(Formulas[NFormulas-1], 'T froide', 'Tc', 'K');
 AddFormulaVar(Formulas[NFormulas-1], 'T chaude', 'Tf', 'K');

 AddFormula('P = sigma T4 A (Stefan-B.)',
            'P = sigma.T4.A', fcThermo, 83);
 AddFormulaVar(Formulas[NFormulas-1], 'puissance', 'P', 'W');
 AddFormulaVar(Formulas[NFormulas-1], 'temperature', 'T', 'K');
 AddFormulaVar(Formulas[NFormulas-1], 'aire', 'A', 'm2');

 { Relativite restreinte }
 AddFormula('gamma = 1/sqrt(1-beta2)',
            'g = 1/sqrt(1-b2)', fcRelativite, 90);
 AddFormulaVar(Formulas[NFormulas-1], 'gamma', 'g', '-');
 AddFormulaVar(Formulas[NFormulas-1], 'beta = v/c', 'b', '-');

 AddFormula('E = gamma m c2 (MeV)',
            'E = gamma.m.c2', fcRelativite, 91);
 AddFormulaVar(Formulas[NFormulas-1], 'energie', 'E', 'MeV');
 AddFormulaVar(Formulas[NFormulas-1], 'gamma', 'g', '-');
 AddFormulaVar(Formulas[NFormulas-1], 'masse', 'm', 'MeV/c2');

 AddFormula('E2 = (pc)2 + (mc2)2', 'E2=(pc)2+(mc2)2',
            fcRelativite, 92);
 AddFormulaVar(Formulas[NFormulas-1], 'energie', 'E', 'MeV');
 AddFormulaVar(Formulas[NFormulas-1], 'p*c', 'pc', 'MeV');
 AddFormulaVar(Formulas[NFormulas-1], 'm*c2', 'mc2', 'MeV');

 { Quantique }
 AddFormula('E = h f (photon)', 'E = h*f', fcQuantique, 100);
 AddFormulaVar(Formulas[NFormulas-1], 'energie', 'E', 'J');
 AddFormulaVar(Formulas[NFormulas-1], 'frequence', 'f', 'Hz');

 AddFormula('lambda = h/p (de Broglie)',
            'L = h/p', fcQuantique, 101);
 AddFormulaVar(Formulas[NFormulas-1], 'long. onde', 'L', 'm');
 AddFormulaVar(Formulas[NFormulas-1], 'p', 'p', 'kg.m/s');

 AddFormula('Ec = h f - W (photoel.)',
            'Ec = hf - W', fcQuantique, 102);
 AddFormulaVar(Formulas[NFormulas-1], 'energie cin.', 'Ec', 'J');
 AddFormulaVar(Formulas[NFormulas-1], 'frequence', 'f', 'Hz');
 AddFormulaVar(Formulas[NFormulas-1], 'travail sortie', 'W', 'J');

 AddFormula('E_n = -13.6/n2 eV (Bohr)',
            'E_n = -13.6/n2', fcQuantique, 103);
 AddFormulaVar(Formulas[NFormulas-1], 'energie (eV)', 'E', 'eV');
 AddFormulaVar(Formulas[NFormulas-1], 'niveau n', 'n', '-');
End;

{ ============================================================
  DIALOGUE ET GRAPHEUR POUR FORMULES
  ============================================================ }

{ Dessine la boite formule : zone vars + bouton Calculer / Tracer / Fermer.
  Retourne True si l utilisateur veut tracer. }
Function FormulaDialog(Var F: TFormula): Boolean;
Var
 X1, Y1, X2, Y2, I, YY: Integer;
 LstX1, LstY1, LstX2, LstY2, LstRowH: Integer;
 BufSize: LongInt;
 BgBuf: Pointer;
 Ev: TEvent;
 Done, Ok: Boolean;
 Sel: Integer;
 S: String;
 Unk: Integer;
 Btns: TDlgButtons;
 Hit: Integer;

 Procedure RedrawAll;
 Var J: Integer; SC: String;
 Begin
  SetFillStyle(SolidFill, CLR_BACKGROUND);
  Bar(X1 + 4, Y1 + 22, X2 - 4, Y2 - 50);
  SetColor(Black);
  OutTextXY(X1 + 12, Y1 + 26, 'Formule : ' + F.Expr);
  OutTextXY(X1 + 12, Y1 + 42,
   'Cochez les valeurs CONNUES, laissez 1 inconnue.');
  For J := 0 To F.NVars - 1 Do Begin
   YY := LstY1 + J * LstRowH;
   If J = Sel Then Begin
    SetFillStyle(SolidFill, CLR_MENU_HIGHLIGHT);
    Bar(LstX1, YY - 2, LstX2, YY + LstRowH - 4);
    SetColor(White);
   End Else
    SetColor(Black);
   If F.Vars[J].Known Then SC := '[X] ' Else SC := '[ ] ';
   S := SC + F.Vars[J].Symbol + ' (' + F.Vars[J].Name + ') = ' +
        RealToStr(F.Vars[J].Value, 1, 4) + ' ' + F.Vars[J].Unite;
   OutTextXY(LstX1 + 4, YY, S);
  End;
  SetColor(Black);
  OutTextXY(X1 + 12, Y2 - 60,
   'Souris : clic sur une ligne pour selectionner / cocher.');
  OutTextXY(X1 + 12, Y2 - 46,
   'Clavier : [Up/Dn]=select  [Space]=cocher  [Entree]=editer.');
 End;

 Procedure EditCurrentValue;
 Begin
  S := RealToStr(F.Vars[Sel].Value, 1, 6);
  PutImage(X1, Y1, BgBuf^, NormalPut);
  If InputBoxStr('Valeur ' + F.Vars[Sel].Symbol,
     'Entrez la valeur (' + F.Vars[Sel].Unite + ') :',
     S, 30) Then Begin
   F.Vars[Sel].Value := StrToRealDef(S, F.Vars[Sel].Value);
   F.Vars[Sel].Known := True;
  End;
  DialogBox(X1, Y1, X2, Y2, F.Name);
  RedrawAll;
  DrawDlgButtons(Btns, 3);
 End;

 Procedure DoCalcul;
 Var J: Integer;
 Begin
  Unk := -1; Ok := True;
  For J := 0 To F.NVars - 1 Do
   If Not F.Vars[J].Known Then Begin
    If Unk >= 0 Then Ok := False Else Unk := J;
   End;
  If (Unk < 0) Or (Not Ok) Then Begin
   PutImage(X1, Y1, BgBuf^, NormalPut);
   MessageBox('Erreur',
    ['Marquez exactement une variable comme inconnue.']);
   DialogBox(X1, Y1, X2, Y2, F.Name);
   RedrawAll; DrawDlgButtons(Btns, 3);
   Exit;
  End;
  If SolveFormula(F, Unk) Then Begin
   PutImage(X1, Y1, BgBuf^, NormalPut);
   MessageBox('Resultat',
    [F.Vars[Unk].Symbol + ' = ' +
     RealToStr(F.Vars[Unk].Value, 1, 6) + ' ' +
     F.Vars[Unk].Unite]);
  End Else Begin
   PutImage(X1, Y1, BgBuf^, NormalPut);
   MessageBox('Erreur',
    ['Impossible de resoudre pour ' + F.Vars[Unk].Symbol,
     'avec les valeurs fournies.']);
  End;
  DialogBox(X1, Y1, X2, Y2, F.Name);
  RedrawAll; DrawDlgButtons(Btns, 3);
 End;

Begin
 X1 := 40; Y1 := 60;
 X2 := SCREEN_W - 40;
 Y2 := SCREEN_H - 60;
 BufSize := ImageSize(X1, Y1, X2 + 4, Y2 + 4);
 GetMem(BgBuf, BufSize);
 GetImage(X1, Y1, X2 + 4, Y2 + 4, BgBuf^);
 DialogBox(X1, Y1, X2, Y2, F.Name);
 LstX1 := X1 + 8;  LstY1 := Y1 + 64;
 LstX2 := X2 - 8;  LstRowH := 18;
 LstY2 := LstY1 + F.NVars * LstRowH;
 Sel := 0; Done := False;
 FormulaDialog := False;
 RedrawAll;
 InitDlgButton(Btns[0], '&Calculer', True,  False);
 InitDlgButton(Btns[1], '&Tracer',   False, False);
 InitDlgButton(Btns[2], 'Fer&mer',   False, True);
 LayoutDlgButtons(Btns, 3, X1, X2, Y2 - DLG_BTN_H - 10);
 DrawDlgButtons(Btns, 3);
 Repeat
  PollEvents(Ev);
  If Ev.Kind = EV_NONE Then Begin Delay(15); Continue; End;
  { Clic souris sur la liste de variables }
  If (Ev.Kind = EV_MOUSE_DOWN) Or (Ev.Kind = EV_MOUSE_DBLCLICK) Then
   If (Ev.MouseX >= LstX1) And (Ev.MouseX <= LstX2) And
      (Ev.MouseY >= LstY1) And (Ev.MouseY <  LstY2) Then Begin
    I := (Ev.MouseY - LstY1) Div LstRowH;
    If (I >= 0) And (I < F.NVars) Then Begin
     Sel := I;
     { Clic sur la zone [X]/[ ] (premiere colonne) : toggle Known }
     If Ev.MouseX < LstX1 + 30 Then
      F.Vars[Sel].Known := Not F.Vars[Sel].Known;
     RedrawAll;
     If Ev.Kind = EV_MOUSE_DBLCLICK Then EditCurrentValue;
    End;
    Continue;
   End;
  Hit := HandleDlgButtonEvent(Btns, 3, Ev);
  If Hit = 0 Then DoCalcul
  Else If Hit = 1 Then Begin
   FormulaDialog := True; Done := True;
  End
  Else If Hit = 2 Then Done := True
  Else If Ev.Kind = EV_KEY_DOWN Then Begin
   Case Ev.KeyCode Of
    72: If Sel > 0           Then Begin Dec(Sel); RedrawAll; End;
    80: If Sel < F.NVars - 1 Then Begin Inc(Sel); RedrawAll; End;
   End;
  End
  Else If Ev.Kind = EV_KEY_CHAR Then Begin
   If Ev.KeyChar = ' ' Then Begin
    F.Vars[Sel].Known := Not F.Vars[Sel].Known;
    RedrawAll;
   End
   Else If Ev.KeyChar = #13 Then EditCurrentValue;
  End;
 Until Done;
 PutImage(X1, Y1, BgBuf^, NormalPut);
 FreeMem(BgBuf, BufSize);
End;

{ Grapheur : choisit X et Y, varie X et trace Y }
Procedure PlotFormula(Var F: TFormula);
Var
 XIdx, YIdx, I, J, PrevX, PrevY, GX1, GY1, GX2, GY2, SX, SY: Integer;
 XMin, XMax, YMin, YMax, XSt, XV, YV: Real;
 Choices: Array[0..7] Of String;
 ChXs, ChYs: Array[0..7] Of Integer;
 NC, Sel: Integer;
 BufSize: LongInt;
 BgBuf: Pointer;
 Ev: TEvent;
 Btns: TDlgButtons;
 Done: Boolean;
 SaveKnown: Array[0..MAX_FORM_VARS-1] Of Boolean;
 SaveVal: Array[0..MAX_FORM_VARS-1] Of Real;
 OK: Boolean;
 S: String;
Begin
 { Choix de X }
 NC := 0;
 For I := 0 To F.NVars - 1 Do
  If NC < 8 Then Begin
   Choices[NC] := F.Vars[I].Symbol + ' (' + F.Vars[I].Name + ')';
   ChXs[NC] := I;
   Inc(NC);
  End;
 If NC < 2 Then Begin
  MessageBox('Tracer',
   ['Cette formule n a pas assez de variables pour tracer.']);
  Exit;
 End;
 Sel := 0;
 If Not ChoiceBox('Choisir variable X', Choices, NC, Sel) Then Exit;
 XIdx := ChXs[Sel];
 { Choix de Y }
 NC := 0;
 For I := 0 To F.NVars - 1 Do
  If (I <> XIdx) And (NC < 8) Then Begin
   Choices[NC] := F.Vars[I].Symbol + ' (' + F.Vars[I].Name + ')';
   ChYs[NC] := I;
   Inc(NC);
  End;
 Sel := 0;
 If Not ChoiceBox('Choisir variable Y', Choices, NC, Sel) Then Exit;
 YIdx := ChYs[Sel];
 { Demander Xmin, Xmax }
 XMin := -10; XMax := 10;
 If Not InputBoxReal('Plage X', 'X min (' +
   F.Vars[XIdx].Unite + ') :', XMin) Then Exit;
 If Not InputBoxReal('Plage X', 'X max (' +
   F.Vars[XIdx].Unite + ') :', XMax) Then Exit;
 If XMax <= XMin Then Begin
  MessageBox('Erreur', ['Xmax doit etre > Xmin.']);
  Exit;
 End;

 { Sauvegarder etat }
 For I := 0 To F.NVars - 1 Do Begin
  SaveKnown[I] := F.Vars[I].Known;
  SaveVal[I] := F.Vars[I].Value;
 End;

 { Toutes les autres variables doivent etre connues }
 For I := 0 To F.NVars - 1 Do
  If (I <> XIdx) And (I <> YIdx) And (Not F.Vars[I].Known) Then Begin
   MessageBox('Erreur',
    ['Toutes les autres variables doivent etre connues.',
     'Quittez et fournissez les valeurs manquantes.']);
   Exit;
  End;
 F.Vars[XIdx].Known := True;
 F.Vars[YIdx].Known := False;

 { Echantillonnage }
 GX1 := 60; GY1 := 60;
 GX2 := SCREEN_W - 60; GY2 := SCREEN_H - 80;
 BufSize := ImageSize(GX1 - 4, GY1 - 4, GX2 + 4, GY2 + 4);
 GetMem(BgBuf, BufSize);
 GetImage(GX1 - 4, GY1 - 4, GX2 + 4, GY2 + 4, BgBuf^);
 { Calculer Ymin/Ymax }
 YMin := 1E30; YMax := -1E30;
 XSt := (XMax - XMin) / 200;
 OK := True;
 For I := 0 To 200 Do Begin
  XV := XMin + I * XSt;
  F.Vars[XIdx].Value := XV;
  If SolveFormula(F, YIdx) Then Begin
   YV := F.Vars[YIdx].Value;
   If YV < YMin Then YMin := YV;
   If YV > YMax Then YMax := YV;
  End;
 End;
 If YMin >= YMax Then Begin
  YMin := YMin - 1; YMax := YMax + 1;
 End;
 { Dessiner cadre + axes }
 SetFillStyle(SolidFill, Black);
 Bar(GX1, GY1, GX2, GY2);
 SetColor(LightGray);
 Rectangle(GX1, GY1, GX2, GY2);
 SetColor(Yellow);
 S := 'Y = ' + F.Vars[YIdx].Symbol + ' vs X = ' + F.Vars[XIdx].Symbol;
 OutTextXY(GX1 + 4, GY1 + 4, S);
 S := 'Xmin=' + RealToStr(XMin, 1, 3) +
      '  Xmax=' + RealToStr(XMax, 1, 3);
 OutTextXY(GX1 + 4, GY2 - 14, S);
 S := 'Ymin=' + RealToStr(YMin, 1, 3) +
      '  Ymax=' + RealToStr(YMax, 1, 3);
 OutTextXY(GX1 + 4, GY1 + 18, S);
 { Tracer }
 SetColor(LightCyan);
 PrevX := -1; PrevY := -1;
 For I := 0 To 200 Do Begin
  XV := XMin + I * XSt;
  F.Vars[XIdx].Value := XV;
  If SolveFormula(F, YIdx) Then Begin
   YV := F.Vars[YIdx].Value;
   SX := GX1 + 4 + Round((XV - XMin) / (XMax - XMin) * (GX2 - GX1 - 8));
   SY := GY2 - 4 - Round((YV - YMin) / (YMax - YMin) * (GY2 - GY1 - 30));
   If PrevX >= 0 Then Line(PrevX, PrevY, SX, SY);
   PrevX := SX; PrevY := SY;
  End Else Begin
   PrevX := -1;
  End;
 End;
 SetColor(White);
 InitDlgButton(Btns[0], 'Fer&mer', True, True);
 LayoutDlgButtons(Btns, 1, GX1, GX2, GY2 - DLG_BTN_H - 4);
 DrawDlgButtons(Btns, 1);
 Done := False;
 Repeat
  PollEvents(Ev);
  If Ev.Kind = EV_NONE Then Begin Delay(15); Continue; End;
  If HandleDlgButtonEvent(Btns, 1, Ev) >= 0 Then Done := True;
 Until Done;
 PutImage(GX1 - 4, GY1 - 4, BgBuf^, NormalPut);
 FreeMem(BgBuf, BufSize);

 { Restaurer etat }
 For I := 0 To F.NVars - 1 Do Begin
  F.Vars[I].Known := SaveKnown[I];
  F.Vars[I].Value := SaveVal[I];
 End;
End;

Procedure ShowFormulasByCategory(Cat: TFormulaCat);
Var
 Items: Array[0..31] Of String;
 Idxs: Array[0..31] Of Integer;
 NC, I, Sel: Integer;
Begin
 NC := 0;
 For I := 0 To NFormulas - 1 Do
  If (Formulas[I].Category = Cat) And (NC < 32) Then Begin
   Items[NC] := Formulas[I].Name;
   Idxs[NC] := I;
   Inc(NC);
  End;
 If NC = 0 Then Begin
  MessageBox('Formules', ['Aucune formule dans cette categorie.']);
  Exit;
 End;
 Sel := 0;
 If ChoiceBox('Choisir une formule', Items, NC, Sel) Then Begin
  If FormulaDialog(Formulas[Idxs[Sel]]) Then
   PlotFormula(Formulas[Idxs[Sel]]);
 End;
End;

{ ============================================================
  INITIALISATION ET EXECUTION DES MENUS
  ============================================================ }

Procedure InitMenuBar;
Var
 XPos, I: Integer;
Begin
 MainMenuBar.MenuCount := 0;
 MainMenuBar.Y := 0;
 MainMenuBar.Height := MENUBAR_HEIGHT;
 OpenMenuIdx := -1;
 SelItemIdx := -1;
 MenuActive := False;
 MenuBgBuf := Nil;
 MenuBgSaved := False;

 { 0 - Fichier }
 InitMenu(MainMenuBar.Menus[0], 'Fichier');
 AddMenuItem(MainMenuBar.Menus[0], 'Nouveau run', 'Ctrl+N',
             TAG_FILE_NEW);
 AddMenuItem(MainMenuBar.Menus[0], 'Charger config...', '',
             TAG_FILE_LOADCFG);
 AddMenuItem(MainMenuBar.Menus[0], 'Sauver resultats...', '',
             TAG_FILE_SAVERES);
 AddMenuSeparator(MainMenuBar.Menus[0]);
 AddMenuItem(MainMenuBar.Menus[0], 'Exporter image (BMP)', '',
             TAG_FILE_EXPORT);
 AddMenuSeparator(MainMenuBar.Menus[0]);
 AddMenuItem(MainMenuBar.Menus[0], 'Quitter', 'Alt+X',
             TAG_FILE_QUIT);

 { 1 - Simulation }
 InitMenu(MainMenuBar.Menus[1], 'Simulation');
 AddMenuItem(MainMenuBar.Menus[1], 'Demarrer', 'F5',
             TAG_SIM_START);
 AddMenuItem(MainMenuBar.Menus[1], 'Pause', 'F6',
             TAG_SIM_PAUSE);
 AddMenuItem(MainMenuBar.Menus[1], 'Reset', 'F7',
             TAG_SIM_RESET);
 AddMenuItem(MainMenuBar.Menus[1], 'Pas-a-pas', 'F8',
             TAG_SIM_STEP);
 AddMenuSeparator(MainMenuBar.Menus[1]);
 AddMenuItem(MainMenuBar.Menus[1], 'Plus rapide', '+',
             TAG_SIM_FASTER);
 AddMenuItem(MainMenuBar.Menus[1], 'Plus lent', '-',
             TAG_SIM_SLOWER);

 { 2 - Particules }
 InitMenu(MainMenuBar.Menus[2], 'Particules');
 AddMenuItem(MainMenuBar.Menus[2], 'Electron (e-)', '',
             TAG_PART_ELECTRON);
 AddMenuItem(MainMenuBar.Menus[2], 'Photon (gamma)', '',
             TAG_PART_PHOTON);
 AddMenuItem(MainMenuBar.Menus[2], 'Proton (p)', '',
             TAG_PART_PROTON);
 AddMenuItem(MainMenuBar.Menus[2], 'Alpha (He++)', '',
             TAG_PART_ALPHA);
 AddMenuSeparator(MainMenuBar.Menus[2]);
 AddMenuItem(MainMenuBar.Menus[2], 'Energie (MeV)...', 'E',
             TAG_PART_ENERGY);
 AddMenuItem(MainMenuBar.Menus[2], 'Nombre...', 'N',
             TAG_PART_COUNT);
 AddMenuItem(MainMenuBar.Menus[2], 'Direction (deg)...', '',
             TAG_PART_DIR);

 { 3 - Geometrie }
 InitMenu(MainMenuBar.Menus[3], 'Geometrie');
 AddMenuItem(MainMenuBar.Menus[3], 'Boite', '',
             TAG_GEO_BOX);
 AddMenuItem(MainMenuBar.Menus[3], 'Cylindre', '',
             TAG_GEO_CYL);
 AddMenuItem(MainMenuBar.Menus[3], 'Sphere', '',
             TAG_GEO_SPHERE);
 AddMenuSeparator(MainMenuBar.Menus[3]);
 AddMenuItem(MainMenuBar.Menus[3], 'Dimensions...', '',
             TAG_GEO_SIZE);
 AddMenuItem(MainMenuBar.Menus[3], 'Materiau...', '',
             TAG_GEO_MAT);

 { 4 - Vue }
 InitMenu(MainMenuBar.Menus[4], 'Vue');
 AddMenuItem(MainMenuBar.Menus[4], 'Mode 2D', '',
             TAG_VIEW_2D);
 AddMenuItem(MainMenuBar.Menus[4], 'Mode 3D wireframe', '',
             TAG_VIEW_3D);
 AddMenuSeparator(MainMenuBar.Menus[4]);
 AddMenuItem(MainMenuBar.Menus[4], 'Histogramme dE/dx', 'H',
             TAG_VIEW_HIST);
 AddMenuItem(MainMenuBar.Menus[4], 'Grille', 'G',
             TAG_VIEW_GRID);
 AddMenuSeparator(MainMenuBar.Menus[4]);
 AddMenuItem(MainMenuBar.Menus[4], 'Reinitialiser vue 3D', 'R',
             TAG_VIEW_RESET);

 { 5 - Formules }
 InitMenu(MainMenuBar.Menus[5], 'Formules');
 AddMenuItem(MainMenuBar.Menus[5], 'Cinematique...', '',
             TAG_FORM_BASE + 0);
 AddMenuItem(MainMenuBar.Menus[5], 'Dynamique...', '',
             TAG_FORM_BASE + 1);
 AddMenuItem(MainMenuBar.Menus[5], 'Energie / travail...', '',
             TAG_FORM_BASE + 2);
 AddMenuItem(MainMenuBar.Menus[5], 'Gravitation...', '',
             TAG_FORM_BASE + 3);
 AddMenuItem(MainMenuBar.Menus[5], 'Oscillations...', '',
             TAG_FORM_BASE + 4);
 AddMenuItem(MainMenuBar.Menus[5], 'Ondes...', '',
             TAG_FORM_BASE + 5);
 AddMenuItem(MainMenuBar.Menus[5], 'Optique...', '',
             TAG_FORM_BASE + 6);
 AddMenuItem(MainMenuBar.Menus[5], 'Electromagnetisme...', '',
             TAG_FORM_BASE + 7);
 AddMenuItem(MainMenuBar.Menus[5], 'Thermodynamique...', '',
             TAG_FORM_BASE + 8);
 AddMenuItem(MainMenuBar.Menus[5], 'Relativite restreinte...', '',
             TAG_FORM_BASE + 9);
 AddMenuItem(MainMenuBar.Menus[5], 'Quantique...', '',
             TAG_FORM_BASE + 10);

 { 6 - Aide }
 InitMenu(MainMenuBar.Menus[6], 'Aide');
 AddMenuItem(MainMenuBar.Menus[6], 'A propos de GEANT4', '',
             TAG_HELP_ABOUT);
 AddMenuItem(MainMenuBar.Menus[6], 'Raccourcis clavier', '',
             TAG_HELP_KEYS);
 AddMenuItem(MainMenuBar.Menus[6], 'Documentation', 'F1',
             TAG_HELP_DOC);

 MainMenuBar.MenuCount := 7;

 { Positions + largeurs }
 XPos := 4;
 For I := 0 To MainMenuBar.MenuCount - 1 Do Begin
  MainMenuBar.Menus[I].X := XPos;
  MainMenuBar.Menus[I].Width := MenuItemWidth(MainMenuBar.Menus[I]);
  XPos := XPos + Length(MainMenuBar.Menus[I].Title) * 8 + 16;
 End;
End;

Procedure DoSetGeomSize;
Var SX, SY, SZ: Real;
Begin
 SX := Geom.SX; SY := Geom.SY; SZ := Geom.SZ;
 If Not InputBoxReal('Dimensions',
  'Demi-cote X (cm) :', SX) Then Exit;
 If Not InputBoxReal('Dimensions',
  'Demi-cote Y (ou rayon) (cm) :', SY) Then Exit;
 If Not InputBoxReal('Dimensions',
  'Demi-cote Z (cm) :', SZ) Then Exit;
 Geom.SX := SX; Geom.SY := SY; Geom.SZ := SZ;
 FullRepaint := True;
End;

Procedure DoSetMaterial;
Var
 Items: Array[0..MAX_MATERIALS-1] Of String;
 I, Sel: Integer;
Begin
 For I := 0 To NMaterials - 1 Do Items[I] := Materials[I].Name;
 Sel := Geom.MatIdx;
 If ChoiceBox('Choisir materiau', Items, NMaterials, Sel) Then Begin
  Geom.MatIdx := Sel;
  FullRepaint := True;
 End;
End;

{ ----- Chargement d un fichier de configuration -----
  Format texte simple : KEY=VAL, # ou ; pour commentaire.
  Cles reconnues :
    BeamKind   = electron|photon|proton|alpha
    BeamEnergy = <MeV>
    BeamCount  = <N>
    BeamAngle  = <deg>
    GeomShape  = box|cylinder|sphere
    GeomCX,GeomCY,GeomCZ,GeomSX,GeomSY,GeomSZ = <cm>
    Material   = <nom> (parmi Materials[].Name)
    SimSpeed   = 1..10                                          }

Function LowerStr(S: String): String;
Var I: Integer;
Begin
 For I := 1 To Length(S) Do
  If (S[I] >= 'A') And (S[I] <= 'Z') Then S[I] := Chr(Ord(S[I]) + 32);
 LowerStr := S;
End;

Procedure TrimStr(Var S: String);
Begin
 While (Length(S) > 0) And ((S[1] = ' ') Or (S[1] = #9)) Do Delete(S, 1, 1);
 While (Length(S) > 0) And ((S[Length(S)] = ' ') Or (S[Length(S)] = #9)
   Or (S[Length(S)] = #13)) Do Dec(S[0]);
End;

{ ============================================================
  BOITE D OUVERTURE / SAUVEGARDE DE FICHIERS
  Style Turbo Vision / Windows : navigation des repertoires,
  liste des fichiers, champ nom, filtre de type, choix du
  lecteur, OK / Annuler ; entierement manipulable a la souris
  ou au clavier.
  ============================================================ }

Const
 MAX_FD_ENTRIES = 512;

Type
 TFileFilter = Record
  Desc : String[40];
  Mask : String[20];
 End;
 TFileFiltersArr = Array[0..7] Of TFileFilter;

 TFileEntry = Record
  Name  : String[40];
  Size  : LongInt;
  IsDir : Boolean;
  IsUp  : Boolean;
  IsDrv : Boolean;
  DrvLt : Char;
 End;

Function FdUpStr(S: String): String;
Var I: Integer;
Begin
 For I := 1 To Length(S) Do S[I] := UpCase(S[I]);
 FdUpStr := S;
End;

Function FdEntryLess(Var A, B: TFileEntry): Boolean;
Var R: Boolean;
Begin
 R := False;
 If A.IsUp And Not B.IsUp Then R := True
 Else If B.IsUp And Not A.IsUp Then R := False
 Else If A.IsDrv And Not B.IsDrv Then R := False
 Else If B.IsDrv And Not A.IsDrv Then R := True
 Else If A.IsDir And Not B.IsDir Then R := True
 Else If B.IsDir And Not A.IsDir Then R := False
 Else R := FdUpStr(A.Name) < FdUpStr(B.Name);
 FdEntryLess := R;
End;

Function FdDriveExists(L: Char): Boolean;
Var S: String; IoR: Integer; OK: Boolean;
Begin
 {$I-} GetDir(Ord(UpCase(L)) - Ord('A') + 1, S); {$I+}
 IoR := IOResult;
 OK := (IoR = 0) And (Length(S) > 0);
 FdDriveExists := OK;
End;

Function FdFileExists(FN: String): Boolean;
Var F: File; IoR: Integer; OK: Boolean;
Begin
 Assign(F, FN);
 {$I-} Reset(F, 1); {$I+}
 IoR := IOResult;
 OK := (IoR = 0);
 If OK Then Close(F);
 FdFileExists := OK;
End;

Function FileOpenDialog(Title: String; Var FName: String;
                        Var Filters: TFileFiltersArr;
                        NFilters: Integer;
                        SaveMode: Boolean): Boolean;
Const
 ROW_H = 12;
 FD_MAXNAME = 60;
Var
 X1, Y1, X2, Y2: Integer;
 BufSize: LongInt;
 BgBuf: Pointer;
 CurPath: String;
 EditBuf: String;
 FilterIdx: Integer;
 Sel, TopIdx: Integer;
 Entries: Array[0..MAX_FD_ENTRIES - 1] Of TFileEntry;
 NEntries: Integer;
 EditX1, EditY1, EditX2, EditY2: Integer;
 FltX1, FltY1, FltX2, FltY2: Integer;
 FltLeftX1, FltLeftX2: Integer;
 FltRightX1, FltRightX2: Integer;
 ListX1, ListY1, ListX2, ListY2: Integer;
 SbX1, SbX2: Integer;
 SbUpY1, SbUpY2: Integer;
 SbDnY1, SbDnY2: Integer;
 Btns: TDlgButtons;
 Ev: TEvent;
 Hit, IRow, NewSel: Integer;
 Done, Result_: Boolean;
 Focus: Integer;
 Caret: Boolean;
 LastBlink, NowTs: LongInt;
 NVisible: Integer;
 OkCaption: String;

 Procedure RescanDir;
 Var
  SR: SearchRec;
  M: String;
  P, Q: Integer;
  Tmp: TFileEntry;
  HasParent: Boolean;
  DL: Char;
 Begin
  NEntries := 0;
  GetDir(0, CurPath);
  HasParent := Length(CurPath) > 3;
  {$I-} FindFirst('*.*', Directory, SR); {$I+}
  While (DosError = 0) And (NEntries < MAX_FD_ENTRIES) Do Begin
   If ((SR.Attr And Directory) <> 0) And
      (SR.Name <> '.') And (SR.Name <> '..') Then Begin
    Entries[NEntries].Name := SR.Name;
    Entries[NEntries].Size := 0;
    Entries[NEntries].IsDir := True;
    Entries[NEntries].IsUp := False;
    Entries[NEntries].IsDrv := False;
    Entries[NEntries].DrvLt := ' ';
    Inc(NEntries);
   End;
   FindNext(SR);
  End;
  {$IFDEF FPC} FindClose(SR); {$ENDIF}
  If (FilterIdx >= 0) And (FilterIdx < NFilters) Then
   M := Filters[FilterIdx].Mask
  Else
   M := '*.*';
  {$I-} FindFirst(M, AnyFile, SR); {$I+}
  While (DosError = 0) And (NEntries < MAX_FD_ENTRIES) Do Begin
   If ((SR.Attr And Directory) = 0) And
      ((SR.Attr And VolumeID) = 0) Then Begin
    Entries[NEntries].Name := SR.Name;
    Entries[NEntries].Size := SR.Size;
    Entries[NEntries].IsDir := False;
    Entries[NEntries].IsUp := False;
    Entries[NEntries].IsDrv := False;
    Entries[NEntries].DrvLt := ' ';
    Inc(NEntries);
   End;
   FindNext(SR);
  End;
  {$IFDEF FPC} FindClose(SR); {$ENDIF}
  For P := 0 To NEntries - 2 Do
   For Q := 0 To NEntries - 2 - P Do
    If FdEntryLess(Entries[Q + 1], Entries[Q]) Then Begin
     Tmp := Entries[Q];
     Entries[Q] := Entries[Q + 1];
     Entries[Q + 1] := Tmp;
    End;
  If HasParent And (NEntries < MAX_FD_ENTRIES) Then Begin
   For P := NEntries Downto 1 Do Entries[P] := Entries[P - 1];
   Entries[0].Name := '..';
   Entries[0].Size := 0;
   Entries[0].IsDir := True;
   Entries[0].IsUp := True;
   Entries[0].IsDrv := False;
   Entries[0].DrvLt := ' ';
   Inc(NEntries);
  End;
  For DL := 'A' To 'Z' Do
   If FdDriveExists(DL) And (NEntries < MAX_FD_ENTRIES) Then Begin
    Entries[NEntries].Name := '[-' + DL + '-]';
    Entries[NEntries].Size := 0;
    Entries[NEntries].IsDir := False;
    Entries[NEntries].IsUp := False;
    Entries[NEntries].IsDrv := True;
    Entries[NEntries].DrvLt := DL;
    Inc(NEntries);
   End;
  Sel := 0; TopIdx := 0;
 End;

 Procedure DrawPath;
 Var S: String;
 Begin
  SetFillStyle(SolidFill, CLR_BACKGROUND);
  Bar(X1 + 6, Y1 + 22, X2 - 6, Y1 + 38);
  SetColor(Black);
  S := CurPath;
  If Length(S) > 60 Then S := Copy(S, 1, 28) + '...' + Copy(S, Length(S) - 28, 29);
  OutTextXY(X1 + 12, Y1 + 26, 'Repertoire: ' + S);
 End;

 Procedure DrawEdit;
 Var DispBuf: String;
 Begin
  SetColor(Black);
  OutTextXY(X1 + 12, EditY1 + 4, 'Nom:');
  SetFillStyle(SolidFill, White);
  Bar(EditX1, EditY1, EditX2, EditY2);
  SetColor(CLR_BORDER);
  Rectangle(EditX1 - 1, EditY1 - 1, EditX2 + 1, EditY2 + 1);
  DispBuf := EditBuf;
  While Length(DispBuf) * 8 > (EditX2 - EditX1 - 6) Do Delete(DispBuf, 1, 1);
  SetColor(Black);
  OutTextXY(EditX1 + 3, EditY1 + 4, DispBuf);
  If (Focus = 0) And Caret Then Begin
   Line(EditX1 + 3 + Length(DispBuf) * 8, EditY1 + 3,
        EditX1 + 3 + Length(DispBuf) * 8, EditY1 + 14);
  End;
 End;

 Procedure DrawFilter;
 Var S: String;
 Begin
  SetColor(Black);
  OutTextXY(X1 + 12, FltY1 + 4, 'Type:');
  SetFillStyle(SolidFill, White);
  Bar(FltX1, FltY1, FltX2, FltY2);
  SetColor(CLR_BORDER);
  Rectangle(FltX1 - 1, FltY1 - 1, FltX2 + 1, FltY2 + 1);
  If (FilterIdx >= 0) And (FilterIdx < NFilters) Then
   S := Filters[FilterIdx].Desc + '  (' + Filters[FilterIdx].Mask + ')'
  Else
   S := '(aucun filtre)';
  SetColor(Black);
  OutTextXY(FltX1 + 4, FltY1 + 4, S);
  SetFillStyle(SolidFill, LightGray);
  Bar(FltLeftX1, FltY1, FltLeftX2, FltY2);
  SetColor(CLR_BORDER); Rectangle(FltLeftX1, FltY1, FltLeftX2, FltY2);
  SetColor(Black); OutTextXY(FltLeftX1 + 4, FltY1 + 4, #17);
  SetFillStyle(SolidFill, LightGray);
  Bar(FltRightX1, FltY1, FltRightX2, FltY2);
  SetColor(CLR_BORDER); Rectangle(FltRightX1, FltY1, FltRightX2, FltY2);
  SetColor(Black); OutTextXY(FltRightX1 + 4, FltY1 + 4, #16);
 End;

 Procedure DrawListItem(IdxRel: Integer);
 Var
  AbsIdx, Y, BC, TC: Integer;
  E: TFileEntry;
  S, Sz: String;
 Begin
  AbsIdx := TopIdx + IdxRel;
  Y := ListY1 + 2 + IdxRel * ROW_H;
  SetFillStyle(SolidFill, White);
  Bar(ListX1 + 1, Y, ListX2 - 1, Y + ROW_H - 1);
  If AbsIdx >= NEntries Then Exit;
  E := Entries[AbsIdx];
  If AbsIdx = Sel Then Begin
   If Focus = 1 Then Begin BC := Blue; TC := White; End
   Else                Begin BC := CLR_TITLEBAR; TC := White; End;
   SetFillStyle(SolidFill, BC);
   Bar(ListX1 + 1, Y, ListX2 - 1, Y + ROW_H - 1);
  End Else Begin
   If E.IsDir Or E.IsDrv Or E.IsUp Then TC := Blue Else TC := Black;
  End;
  If E.IsUp Then S := '[..]'
  Else If E.IsDrv Then S := E.Name
  Else If E.IsDir Then S := '[' + E.Name + ']'
  Else S := E.Name;
  SetColor(TC);
  OutTextXY(ListX1 + 4, Y + 2, S);
  If (Not E.IsDir) And (Not E.IsDrv) Then Begin
   Str(E.Size, Sz);
   OutTextXY(ListX2 - 4 - Length(Sz) * 8, Y + 2, Sz);
  End;
 End;

 Procedure DrawList;
 Var I: Integer;
 Begin
  SetFillStyle(SolidFill, White);
  Bar(ListX1, ListY1, ListX2, ListY2);
  SetColor(CLR_BORDER);
  Rectangle(ListX1 - 1, ListY1 - 1, ListX2 + 1, ListY2 + 1);
  For I := 0 To NVisible - 1 Do DrawListItem(I);
 End;

 Procedure DrawScrollbar;
 Var ThumbY1, ThumbY2, TrackH: Integer;
 Begin
  SetFillStyle(SolidFill, LightGray);
  Bar(SbX1, SbUpY1, SbX2, SbUpY2);
  SetColor(CLR_BORDER); Rectangle(SbX1, SbUpY1, SbX2, SbUpY2);
  SetColor(Black);
  Line(SbX1 + 7, SbUpY1 + 4, SbX1 + 4, SbUpY1 + 8);
  Line(SbX1 + 7, SbUpY1 + 4, SbX1 + 10, SbUpY1 + 8);
  Line(SbX1 + 4, SbUpY1 + 8, SbX1 + 10, SbUpY1 + 8);
  SetFillStyle(SolidFill, LightGray);
  Bar(SbX1, SbDnY1, SbX2, SbDnY2);
  SetColor(CLR_BORDER); Rectangle(SbX1, SbDnY1, SbX2, SbDnY2);
  SetColor(Black);
  Line(SbX1 + 4, SbDnY1 + 4, SbX1 + 10, SbDnY1 + 4);
  Line(SbX1 + 4, SbDnY1 + 4, SbX1 + 7, SbDnY1 + 8);
  Line(SbX1 + 10, SbDnY1 + 4, SbX1 + 7, SbDnY1 + 8);
  SetFillStyle(SolidFill, DarkGray);
  Bar(SbX1, SbUpY2 + 1, SbX2, SbDnY1 - 1);
  TrackH := (SbDnY1 - 1) - (SbUpY2 + 1);
  If NEntries <= NVisible Then Begin
   ThumbY1 := SbUpY2 + 1;
   ThumbY2 := SbDnY1 - 1;
  End Else Begin
   ThumbY1 := SbUpY2 + 1 +
              (LongInt(TopIdx) * (TrackH - 14)) Div (NEntries - NVisible);
   ThumbY2 := ThumbY1 + 14;
   If ThumbY2 > SbDnY1 - 1 Then Begin
    ThumbY2 := SbDnY1 - 1;
    ThumbY1 := ThumbY2 - 14;
   End;
  End;
  SetFillStyle(SolidFill, LightGray);
  Bar(SbX1, ThumbY1, SbX2, ThumbY2);
  SetColor(CLR_BORDER); Rectangle(SbX1, ThumbY1, SbX2, ThumbY2);
 End;

 Procedure DrawAll;
 Begin
  DialogBox(X1, Y1, X2, Y2, Title);
  DrawPath;
  DrawEdit;
  DrawFilter;
  DrawList;
  DrawScrollbar;
  DrawDlgButtons(Btns, 2);
 End;

 Procedure ScrollIntoView;
 Begin
  If Sel < TopIdx Then TopIdx := Sel
  Else If Sel >= TopIdx + NVisible Then TopIdx := Sel - NVisible + 1;
  If TopIdx < 0 Then TopIdx := 0;
  If TopIdx > NEntries - NVisible Then TopIdx := NEntries - NVisible;
  If TopIdx < 0 Then TopIdx := 0;
 End;

 Procedure SelectEntry(N: Integer);
 Begin
  If (N < 0) Or (N >= NEntries) Then Exit;
  Sel := N;
  ScrollIntoView;
  If (Not Entries[Sel].IsDir) And (Not Entries[Sel].IsDrv) Then
   EditBuf := Entries[Sel].Name;
  DrawList;
  DrawScrollbar;
  DrawEdit;
 End;

 Procedure NavigateInto(IdxN: Integer);
 Var IoR: Integer; NewPath: String;
 Begin
  If (IdxN < 0) Or (IdxN >= NEntries) Then Exit;
  If Entries[IdxN].IsDrv Then Begin
   {$I-} GetDir(Ord(Entries[IdxN].DrvLt) - Ord('A') + 1, NewPath); {$I+}
   IoR := IOResult;
   If IoR = 0 Then Begin
    {$I-} ChDir(Entries[IdxN].DrvLt + ':'); {$I+} IoR := IOResult;
    {$I-} ChDir(NewPath); {$I+} IoR := IOResult;
   End;
  End
  Else If Entries[IdxN].IsUp Then Begin
   {$I-} ChDir('..'); {$I+} IoR := IOResult;
  End
  Else If Entries[IdxN].IsDir Then Begin
   {$I-} ChDir(Entries[IdxN].Name); {$I+} IoR := IOResult;
  End
  Else Exit;
  RescanDir;
  EditBuf := '';
  DrawAll;
 End;

 Function AcceptFilename: Boolean;
 Var SR: SearchRec; IoR: Integer; OK: Boolean; Tmp: String;
 Begin
  OK := False;
  Tmp := EditBuf;
  While (Length(Tmp) > 0) And (Tmp[1] = ' ') Do Delete(Tmp, 1, 1);
  While (Length(Tmp) > 0) And (Tmp[Length(Tmp)] = ' ') Do Dec(Tmp[0]);
  If Length(Tmp) = 0 Then Begin AcceptFilename := False; Exit; End;
  If (Pos('*', Tmp) > 0) Or (Pos('?', Tmp) > 0) Then Begin
   If (FilterIdx >= 0) And (FilterIdx < NFilters) Then Begin
    Filters[FilterIdx].Mask := Tmp;
    Filters[FilterIdx].Desc := 'Personnalise';
   End;
   RescanDir;
   EditBuf := '';
   DrawAll;
   AcceptFilename := False; Exit;
  End;
  {$I-} FindFirst(Tmp, Directory, SR); {$I+}
  IoR := DosError;
  If (IoR = 0) And ((SR.Attr And Directory) <> 0) Then Begin
   {$IFDEF FPC} FindClose(SR); {$ENDIF}
   {$I-} ChDir(Tmp); {$I+} IoR := IOResult;
   If IoR = 0 Then Begin
    RescanDir; EditBuf := ''; DrawAll;
   End;
   AcceptFilename := False; Exit;
  End;
  {$IFDEF FPC} FindClose(SR); {$ENDIF}
  If (Not SaveMode) And (Not FdFileExists(Tmp)) Then Begin
   PutImage(X1, Y1, BgBuf^, NormalPut);
   MessageBox('Erreur', ['Le fichier n existe pas :', Tmp]);
   GetImage(X1, Y1, X2 + 4, Y2 + 4, BgBuf^);
   DrawAll;
   AcceptFilename := False; Exit;
  End;
  FName := Tmp;
  OK := True;
  AcceptFilename := OK;
 End;

 Function HitListRow(MX, MY: Integer): Integer;
 Var R: Integer;
 Begin
  HitListRow := -1;
  If (MX < ListX1) Or (MX > ListX2) Then Exit;
  If (MY < ListY1) Or (MY > ListY2) Then Exit;
  R := (MY - ListY1 - 2) Div ROW_H;
  If (R < 0) Or (R >= NVisible) Then Exit;
  If TopIdx + R >= NEntries Then Exit;
  HitListRow := TopIdx + R;
 End;

Begin
 X1 := 60; Y1 := 50; X2 := 580; Y2 := 430;
 BufSize := ImageSize(X1, Y1, X2 + 4, Y2 + 4);
 GetMem(BgBuf, BufSize);
 GetImage(X1, Y1, X2 + 4, Y2 + 4, BgBuf^);

 EditX1 := X1 + 60; EditY1 := Y1 + 44;
 EditX2 := X2 - 12; EditY2 := EditY1 + 18;

 FltX1 := X1 + 60; FltY1 := Y1 + 72;
 FltX2 := X2 - 12 - 44; FltY2 := FltY1 + 18;
 FltLeftX1  := FltX2 + 4;  FltLeftX2  := FltLeftX1 + 18;
 FltRightX1 := FltLeftX2 + 2; FltRightX2 := FltRightX1 + 18;

 ListX1 := X1 + 12; ListY1 := Y1 + 100;
 ListX2 := X2 - 12 - 18; ListY2 := Y2 - DLG_BTN_H - 18;
 SbX1 := ListX2 + 3; SbX2 := SbX1 + 14;
 SbUpY1 := ListY1; SbUpY2 := ListY1 + 14;
 SbDnY1 := ListY2 - 14; SbDnY2 := ListY2;
 NVisible := (ListY2 - ListY1 - 4) Div ROW_H;

 If SaveMode Then OkCaption := '&Enregistrer' Else OkCaption := '&Ouvrir';
 InitDlgButton(Btns[0], OkCaption, True,  False);
 InitDlgButton(Btns[1], 'Annuler', False, True);
 LayoutDlgButtons(Btns, 2, X1, X2, Y2 - DLG_BTN_H - 6);

 FilterIdx := 0;
 EditBuf := FName;
 Caret := True; LastBlink := GetTimestamp;
 Focus := 0;
 RescanDir;
 DrawAll;

 Result_ := False;
 Done := False;
 Repeat
  PollEvents(Ev);
  NowTs := GetTimestamp;
  If (Focus = 0) And ((NowTs - LastBlink) > 400) Then Begin
   Caret := Not Caret; LastBlink := NowTs; DrawEdit;
  End;
  If Ev.Kind = EV_NONE Then Begin Delay(15); Continue; End;

  { Boutons OK / Annuler }
  Hit := HandleDlgButtonEvent(Btns, 2, Ev);
  If Hit = 0 Then Begin
   If AcceptFilename Then Begin Result_ := True; Done := True; End;
   Continue;
  End
  Else If Hit = 1 Then Begin Done := True; Continue; End;

  { Clic souris }
  If Ev.Kind = EV_MOUSE_DOWN Then Begin
   IRow := HitListRow(Ev.MouseX, Ev.MouseY);
   If IRow >= 0 Then Begin
    Focus := 1; SelectEntry(IRow); Continue;
   End;
   If (Ev.MouseX >= EditX1) And (Ev.MouseX <= EditX2) And
      (Ev.MouseY >= EditY1) And (Ev.MouseY <= EditY2) Then Begin
    Focus := 0; DrawList; DrawEdit; Continue;
   End;
   If (Ev.MouseX >= FltLeftX1) And (Ev.MouseX <= FltLeftX2) And
      (Ev.MouseY >= FltY1) And (Ev.MouseY <= FltY2) Then Begin
    If NFilters > 0 Then Begin
     Dec(FilterIdx);
     If FilterIdx < 0 Then FilterIdx := NFilters - 1;
     RescanDir; DrawFilter; DrawList; DrawScrollbar;
    End;
    Continue;
   End;
   If (Ev.MouseX >= FltRightX1) And (Ev.MouseX <= FltRightX2) And
      (Ev.MouseY >= FltY1) And (Ev.MouseY <= FltY2) Then Begin
    If NFilters > 0 Then Begin
     Inc(FilterIdx);
     If FilterIdx >= NFilters Then FilterIdx := 0;
     RescanDir; DrawFilter; DrawList; DrawScrollbar;
    End;
    Continue;
   End;
   If (Ev.MouseX >= FltX1) And (Ev.MouseX <= FltX2) And
      (Ev.MouseY >= FltY1) And (Ev.MouseY <= FltY2) Then Begin
    If NFilters > 0 Then Begin
     Inc(FilterIdx);
     If FilterIdx >= NFilters Then FilterIdx := 0;
     RescanDir; DrawFilter; DrawList; DrawScrollbar;
    End;
    Continue;
   End;
   If (Ev.MouseX >= SbX1) And (Ev.MouseX <= SbX2) Then Begin
    If (Ev.MouseY >= SbUpY1) And (Ev.MouseY <= SbUpY2) Then Begin
     If TopIdx > 0 Then Begin Dec(TopIdx); DrawList; DrawScrollbar; End;
     Continue;
    End;
    If (Ev.MouseY >= SbDnY1) And (Ev.MouseY <= SbDnY2) Then Begin
     If TopIdx < NEntries - NVisible Then Begin
      Inc(TopIdx); DrawList; DrawScrollbar;
     End;
     Continue;
    End;
    If (Ev.MouseY > SbUpY2) And (Ev.MouseY < SbDnY1) Then Begin
     If NEntries > NVisible Then Begin
      TopIdx := ((LongInt(Ev.MouseY - SbUpY2 - 7)) * (NEntries - NVisible))
                Div (SbDnY1 - SbUpY2 - 14);
      If TopIdx < 0 Then TopIdx := 0;
      If TopIdx > NEntries - NVisible Then TopIdx := NEntries - NVisible;
      DrawList; DrawScrollbar;
     End;
     Continue;
    End;
   End;
  End;

  If Ev.Kind = EV_MOUSE_DBLCLICK Then Begin
   IRow := HitListRow(Ev.MouseX, Ev.MouseY);
   If IRow >= 0 Then Begin
    Sel := IRow;
    If Entries[Sel].IsDir Or Entries[Sel].IsDrv Or Entries[Sel].IsUp Then
     NavigateInto(Sel)
    Else Begin
     EditBuf := Entries[Sel].Name;
     If AcceptFilename Then Begin Result_ := True; Done := True; End;
    End;
    Continue;
   End;
  End;

  { Clavier }
  If Ev.Kind = EV_KEY_CHAR Then Begin
   If Ev.KeyChar = #9 Then Begin
    Focus := (Focus + 1) Mod 3;
    DrawEdit; DrawList; DrawFilter;
    Continue;
   End;
   If Focus = 0 Then Begin
    If Ev.KeyChar = #8 Then Begin
     If Length(EditBuf) > 0 Then Delete(EditBuf, Length(EditBuf), 1);
     Caret := True; DrawEdit;
    End
    Else If (Ev.KeyChar >= ' ') And (Length(EditBuf) < FD_MAXNAME) Then Begin
     EditBuf := EditBuf + Ev.KeyChar;
     Caret := True; DrawEdit;
    End;
    Continue;
   End;
   If Focus = 2 Then Begin
    If (Ev.KeyChar = ' ') And (NFilters > 0) Then Begin
     Inc(FilterIdx);
     If FilterIdx >= NFilters Then FilterIdx := 0;
     RescanDir; DrawFilter; DrawList; DrawScrollbar;
    End;
    Continue;
   End;
   { Focus = 1 : liste }
   If Ev.KeyChar = #13 Then Begin
    If (Sel >= 0) And (Sel < NEntries) Then Begin
     If Entries[Sel].IsDir Or Entries[Sel].IsDrv Or Entries[Sel].IsUp Then
      NavigateInto(Sel)
     Else Begin
      EditBuf := Entries[Sel].Name;
      If AcceptFilename Then Begin Result_ := True; Done := True; End;
     End;
    End;
    Continue;
   End;
  End;

  If Ev.Kind = EV_KEY_DOWN Then Begin
   Case Ev.KeyCode Of
    72: Begin     { Up }
     If Focus = 1 Then Begin
      NewSel := Sel - 1;
      If NewSel < 0 Then NewSel := 0;
      SelectEntry(NewSel);
     End;
    End;
    80: Begin     { Down }
     If Focus = 1 Then Begin
      NewSel := Sel + 1;
      If NewSel >= NEntries Then NewSel := NEntries - 1;
      SelectEntry(NewSel);
     End;
    End;
    73: Begin     { PgUp }
     If Focus = 1 Then Begin
      NewSel := Sel - NVisible;
      If NewSel < 0 Then NewSel := 0;
      SelectEntry(NewSel);
     End;
    End;
    81: Begin     { PgDn }
     If Focus = 1 Then Begin
      NewSel := Sel + NVisible;
      If NewSel >= NEntries Then NewSel := NEntries - 1;
      SelectEntry(NewSel);
     End;
    End;
    71: Begin SelectEntry(0); End;            { Home }
    79: Begin SelectEntry(NEntries - 1); End; { End  }
   End;
  End;

  If Ev.Kind = EV_CLOSE Then Done := True;
 Until Done;

 PutImage(X1, Y1, BgBuf^, NormalPut);
 FreeMem(BgBuf, BufSize);
 FileOpenDialog := Result_;
End;

Procedure LoadConfigFile(FName: String);
Var
 F: Text;
 Line, Key, Val: String;
 P, I, IVal, Loaded, Unknown: Integer;
 IoR: Integer;
Begin
 Assign(F, FName);
{$I-} Reset(F); {$I+}
 IoR := IOResult;
 If IoR <> 0 Then Begin
  MessageBox('Erreur',
   ['Impossible d ouvrir le fichier :',
    FName,
    'Code IO=' + IntToStr(IoR)]);
  Exit;
 End;
 Loaded := 0;
 Unknown := 0;
 While Not Eof(F) Do Begin
  Readln(F, Line);
  TrimStr(Line);
  If Length(Line) = 0 Then Continue;
  If (Line[1] = '#') Or (Line[1] = ';') Then Continue;
  P := Pos('=', Line);
  If P <= 1 Then Continue;
  Key := LowerStr(Copy(Line, 1, P - 1));
  Val := Copy(Line, P + 1, Length(Line) - P);
  TrimStr(Key);
  TrimStr(Val);

  If Key = 'beamkind' Then Begin
   Val := LowerStr(Val);
   If Val = 'electron' Then BeamKind := pkElectron
   Else If Val = 'photon' Then BeamKind := pkPhoton
   Else If Val = 'proton' Then BeamKind := pkProton
   Else If Val = 'alpha' Then BeamKind := pkAlpha;
   Inc(Loaded);
  End
  Else If Key = 'beamenergy' Then Begin
   BeamEnergy := StrToRealDef(Val, BeamEnergy); Inc(Loaded);
  End
  Else If Key = 'beamcount' Then Begin
   IVal := StrToIntDef(Val, BeamCount);
   If IVal < 1 Then IVal := 1;
   If IVal > MAX_PARTICLES Then IVal := MAX_PARTICLES;
   BeamCount := IVal; Inc(Loaded);
  End
  Else If Key = 'beamangle' Then Begin
   BeamAngleDeg := StrToRealDef(Val, BeamAngleDeg); Inc(Loaded);
  End
  Else If Key = 'geomshape' Then Begin
   Val := LowerStr(Val);
   If (Val = 'box') Or (Val = 'boite') Then Geom.Shape := gsBox
   Else If (Val = 'cylinder') Or (Val = 'cylindre') Then Geom.Shape := gsCylinder
   Else If (Val = 'sphere') Then Geom.Shape := gsSphere;
   Inc(Loaded);
  End
  Else If Key = 'geomcx' Then Begin Geom.CX := StrToRealDef(Val, Geom.CX); Inc(Loaded); End
  Else If Key = 'geomcy' Then Begin Geom.CY := StrToRealDef(Val, Geom.CY); Inc(Loaded); End
  Else If Key = 'geomcz' Then Begin Geom.CZ := StrToRealDef(Val, Geom.CZ); Inc(Loaded); End
  Else If Key = 'geomsx' Then Begin Geom.SX := StrToRealDef(Val, Geom.SX); Inc(Loaded); End
  Else If Key = 'geomsy' Then Begin Geom.SY := StrToRealDef(Val, Geom.SY); Inc(Loaded); End
  Else If Key = 'geomsz' Then Begin Geom.SZ := StrToRealDef(Val, Geom.SZ); Inc(Loaded); End
  Else If Key = 'material' Then Begin
   Val := LowerStr(Val);
   For I := 0 To NMaterials - 1 Do
    If LowerStr(Materials[I].Name) = Val Then Begin
     Geom.MatIdx := I; Break;
    End;
   Inc(Loaded);
  End
  Else If Key = 'simspeed' Then Begin
   IVal := StrToIntDef(Val, SimSpeed);
   If IVal < 1 Then IVal := 1;
   If IVal > 10 Then IVal := 10;
   SimSpeed := IVal; Inc(Loaded);
  End
  Else
   Inc(Unknown);
 End;
 Close(F);
 ResetSimulation;
 FullRepaint := True;
 MessageBox('Configuration chargee',
  ['Fichier : ' + FName,
   IntToStr(Loaded) + ' parametre(s) appliques.',
   IntToStr(Unknown) + ' cle(s) inconnue(s) ignoree(s).']);
End;

Procedure DoLoadConfig;
Var
 FName: String;
 Flt: TFileFiltersArr;
Begin
 FName := 'GEANT4.CFG';
 Flt[0].Desc := 'Configurations'; Flt[0].Mask := '*.CFG';
 Flt[1].Desc := 'Tous les fichiers texte'; Flt[1].Mask := '*.TXT';
 Flt[2].Desc := 'Tous les fichiers'; Flt[2].Mask := '*.*';
 If FileOpenDialog('Charger une configuration', FName, Flt, 3, False) Then
  If Length(FName) > 0 Then LoadConfigFile(FName);
End;

{ ----- Sauvegarde du rapport de simulation ----- }

Function KindToStr(K: TParticleKind): String;
Begin
 Case K Of
  pkElectron: KindToStr := 'electron';
  pkPhoton:   KindToStr := 'photon';
  pkProton:   KindToStr := 'proton';
  pkAlpha:    KindToStr := 'alpha';
 Else         KindToStr := '?';
 End;
End;

Function ShapeToStr(S: TGeoShape): String;
Begin
 Case S Of
  gsBox:      ShapeToStr := 'box';
  gsCylinder: ShapeToStr := 'cylinder';
  gsSphere:   ShapeToStr := 'sphere';
 Else         ShapeToStr := '?';
 End;
End;

Procedure SaveResultsFile(FName: String);
Var
 F: Text;
 I: Integer;
 NAlive, NStopped: Integer;
 ETot, XMin, XMax, BinW, Xc: Real;
 IoR: Integer;
 P: PParticle;
Begin
 Assign(F, FName);
{$I-} Rewrite(F); {$I+}
 IoR := IOResult;
 If IoR <> 0 Then Begin
  MessageBox('Erreur',
   ['Impossible d ecrire le fichier :',
    FName,
    'Code IO=' + IntToStr(IoR)]);
  Exit;
 End;

 Writeln(F, '# GEANT4 demo - rapport de simulation');
 Writeln(F, '# Format texte. Sections : [Beam] [Geometry] [Stats] [Particles] [Histogram]');
 Writeln(F);

 Writeln(F, '[Beam]');
 Writeln(F, 'Kind     = ', KindToStr(BeamKind));
 Writeln(F, 'Energy   = ', RealToStr(BeamEnergy, 1, 4), ' MeV');
 Writeln(F, 'Count    = ', BeamCount);
 Writeln(F, 'Angle    = ', RealToStr(BeamAngleDeg, 1, 3), ' deg');
 Writeln(F);

 Writeln(F, '[Geometry]');
 Writeln(F, 'Shape    = ', ShapeToStr(Geom.Shape));
 Writeln(F, 'Center   = (', RealToStr(Geom.CX, 1, 3), ', ',
                            RealToStr(Geom.CY, 1, 3), ', ',
                            RealToStr(Geom.CZ, 1, 3), ') cm');
 Writeln(F, 'HalfSize = (', RealToStr(Geom.SX, 1, 3), ', ',
                            RealToStr(Geom.SY, 1, 3), ', ',
                            RealToStr(Geom.SZ, 1, 3), ') cm');
 If (Geom.MatIdx >= 0) And (Geom.MatIdx < NMaterials) Then
  Writeln(F, 'Material = ', Materials[Geom.MatIdx].Name,
          ' (Z=', Materials[Geom.MatIdx].Z:0:0,
          ', rho=', RealToStr(Materials[Geom.MatIdx].Density, 1, 4), ' g/cm3)')
 Else
  Writeln(F, 'Material = (none)');
 Writeln(F);

 NAlive := 0; NStopped := 0; ETot := 0;
 P := ParticlesHead;
 While P <> Nil Do Begin
  If P^.Alive Then Inc(NAlive) Else Inc(NStopped);
  ETot := ETot + P^.Energy;
  P := P^.Next;
 End;

 Writeln(F, '[Stats]');
 Writeln(F, 'SimStep    = ', SimStep);
 Writeln(F, 'NParticles = ', NParticles);
 Writeln(F, 'NAlive     = ', NAlive);
 Writeln(F, 'NStopped   = ', NStopped);
 Writeln(F, 'EnergyRemaining = ', RealToStr(ETot, 1, 4), ' MeV');
 Writeln(F);

 Writeln(F, '[Particles]');
 Writeln(F, '# idx kind energy_MeV alive trackLen X Y Z');
 P := ParticlesHead;
 I := 0;
 While P <> Nil Do Begin
  Inc(I);
  Write(F, I:4, ' ', KindToStr(P^.Kind):10, ' ',
           RealToStr(P^.Energy, 1, 4):10, ' ');
  If P^.Alive Then Write(F, 'alive   ')
  Else Write(F, 'stopped ');
  Writeln(F, P^.TrackLen:4, ' ',
              RealToStr(P^.X, 1, 3), ' ',
              RealToStr(P^.Y, 1, 3), ' ',
              RealToStr(P^.Z, 1, 3));
  P := P^.Next;
 End;
 Writeln(F);

 Writeln(F, '[Histogram]');
 Writeln(F, '# bin x_cm dE_MeV');
 XMin := Geom.CX - Geom.SX;
 XMax := Geom.CX + Geom.SX;
 If NHistBins > 0 Then BinW := (XMax - XMin) / NHistBins Else BinW := 0;
 For I := 0 To NHistBins - 1 Do Begin
  Xc := XMin + (I + 0.5) * BinW;
  Writeln(F, I:4, ' ', RealToStr(Xc, 1, 3):10, ' ',
                       RealToStr(Hist[I], 1, 6));
 End;

 Close(F);
 MessageBox('Resultats sauvegardes',
  ['Fichier : ' + FName,
   IntToStr(NParticles) + ' particule(s) ecrites.',
   IntToStr(NHistBins) + ' bin(s) d histogramme.']);
End;

Procedure DoSaveResults;
Var
 FName: String;
 Flt: TFileFiltersArr;
Begin
 FName := 'GEANT4.OUT';
 Flt[0].Desc := 'Resultats GEANT4'; Flt[0].Mask := '*.OUT';
 Flt[1].Desc := 'Fichiers texte'; Flt[1].Mask := '*.TXT';
 Flt[2].Desc := 'Tous les fichiers'; Flt[2].Mask := '*.*';
 If FileOpenDialog('Sauvegarder les resultats', FName, Flt, 3, True) Then
  If Length(FName) > 0 Then SaveResultsFile(FName);
End;

{ ----- Export image BMP 24 bits (capture ecran) -----
  Lit l ecran via GetPixel et ecrit un BMP non compresse,
  bottom-up, 24 bpp, sans palette. Utilise la palette VGA
  16 couleurs standard pour traduire les indices.            }

Procedure SaveScreenBMP(FName: String);
Const
 PaletteR : Array[0..15] Of Byte =
   (  0,   0,   0,   0, 170, 170, 170, 170,
     85,  85,  85,  85, 255, 255, 255, 255);
 PaletteG : Array[0..15] Of Byte =
   (  0,   0, 170, 170,   0,   0,  85, 170,
     85,  85, 255, 255,  85,  85, 255, 255);
 PaletteB : Array[0..15] Of Byte =
   (  0, 170,   0, 170,   0, 170,   0, 170,
     85, 255,  85, 255,  85, 255,  85, 255);
Var
 F: File;
 Hdr: Array[0..53] Of Byte;
 Row: Array[0..SCREEN_W * 3 - 1] Of Byte;
 W, H, X, Y, Px, RowBytes, Pad, I: Integer;
 ImgSize, FileSz: LongInt;
 BW: LongInt;
 IoR: Integer;
 PadByte: Byte;

 Procedure PutW(P: Integer; V: Word);
 Begin
  Hdr[P]     := Byte(V And $FF);
  Hdr[P + 1] := Byte((V Shr 8) And $FF);
 End;

 Procedure PutL(P: Integer; V: LongInt);
 Begin
  Hdr[P]     := Byte(V And $FF);
  Hdr[P + 1] := Byte((V Shr 8) And $FF);
  Hdr[P + 2] := Byte((V Shr 16) And $FF);
  Hdr[P + 3] := Byte((V Shr 24) And $FF);
 End;

Begin
 W := GetScreenWidth;
 H := GetScreenHeight;
 If W > SCREEN_W Then W := SCREEN_W;
 RowBytes := W * 3;
 Pad := (4 - (RowBytes And 3)) And 3;
 ImgSize := LongInt(RowBytes + Pad) * H;
 FileSz  := 54 + ImgSize;

 Assign(F, FName);
{$I-} Rewrite(F, 1); {$I+}
 IoR := IOResult;
 If IoR <> 0 Then Begin
  MessageBox('Erreur',
   ['Impossible d ecrire le fichier :', FName,
    'Code IO=' + IntToStr(IoR)]);
  Exit;
 End;

 FillChar(Hdr, SizeOf(Hdr), 0);
 { BITMAPFILEHEADER }
 Hdr[0] := Ord('B'); Hdr[1] := Ord('M');
 PutL(2,  FileSz);
 PutL(10, 54);
 { BITMAPINFOHEADER }
 PutL(14, 40);
 PutL(18, W);
 PutL(22, H);
 PutW(26, 1);
 PutW(28, 24);
 PutL(30, 0);          { compression = BI_RGB }
 PutL(34, ImgSize);
 PutL(38, 2835);       { 72 dpi en pixels/metre }
 PutL(42, 2835);
 PutL(46, 0);
 PutL(50, 0);
 BlockWrite(F, Hdr, 54, BW);

 PadByte := 0;
 For Y := H - 1 DownTo 0 Do Begin
  For X := 0 To W - 1 Do Begin
   Px := GetPixel(X, Y) And 15;
   Row[X * 3]     := PaletteB[Px];
   Row[X * 3 + 1] := PaletteG[Px];
   Row[X * 3 + 2] := PaletteR[Px];
  End;
  BlockWrite(F, Row, RowBytes, BW);
  For I := 1 To Pad Do BlockWrite(F, PadByte, 1, BW);
 End;

 Close(F);
 MessageBox('Image sauvegardee',
  ['Fichier : ' + FName,
   IntToStr(W) + ' x ' + IntToStr(H) + ' pixels',
   '24 bits par pixel (BMP non compresse)']);
End;

Procedure DoExportImage;
Var
 FName: String;
 Flt: TFileFiltersArr;
Begin
 FName := 'GEANT4.BMP';
 Flt[0].Desc := 'Images Bitmap'; Flt[0].Mask := '*.BMP';
 Flt[1].Desc := 'Tous les fichiers'; Flt[1].Mask := '*.*';
 If FileOpenDialog('Exporter l image au format BMP', FName, Flt, 2, True) Then
  If Length(FName) > 0 Then SaveScreenBMP(FName);
End;

Procedure ExecuteMenuItem(Var Item: TMenuItem);
Var Cat: Integer; PP: PParticle;
Begin
 CloseMenuBar;
 Case Item.Tag Of
  TAG_FILE_NEW: Begin
   ResetSimulation;
   SpawnBeam;
   FullRepaint := True;
  End;
  TAG_FILE_QUIT: QuitRequested := True;
  TAG_FILE_LOADCFG: DoLoadConfig;
  TAG_FILE_SAVERES: DoSaveResults;
  TAG_FILE_EXPORT:  DoExportImage;

  TAG_SIM_START: Begin
   If NParticles = 0 Then SpawnBeam;
   SimRunning := True;
  End;
  TAG_SIM_PAUSE: SimRunning := False;
  TAG_SIM_RESET: Begin
   ResetSimulation;
   FullRepaint := True;
  End;
  TAG_SIM_STEP: Begin
   If NParticles = 0 Then SpawnBeam;
   SimRunning := False;
   { Un pas pour toutes les particules vivantes }
   PP := ParticlesHead;
   While PP <> Nil Do Begin
    If PP^.Alive Then StepParticle(PP^);
    PP := PP^.Next;
   End;
   Inc(SimStep);
   FullRepaint := True;
  End;
  TAG_SIM_FASTER: If SimSpeed < 10 Then Inc(SimSpeed);
  TAG_SIM_SLOWER: If SimSpeed > 1 Then Dec(SimSpeed);

  TAG_PART_ELECTRON: Begin BeamKind := pkElectron; FullRepaint := True; End;
  TAG_PART_PHOTON:   Begin BeamKind := pkPhoton;   FullRepaint := True; End;
  TAG_PART_PROTON:   Begin BeamKind := pkProton;   FullRepaint := True; End;
  TAG_PART_ALPHA:    Begin BeamKind := pkAlpha;    FullRepaint := True; End;
  TAG_PART_ENERGY: Begin
   If InputBoxReal('Energie du faisceau',
    'Energie (MeV) :', BeamEnergy) Then FullRepaint := True;
  End;
  TAG_PART_COUNT: Begin
   If InputBoxInt('Nombre de particules',
    'Nombre (1..' + IntToStr(MAX_PARTICLES) + ') :',
    BeamCount) Then Begin
    If BeamCount < 1 Then BeamCount := 1;
    If BeamCount > MAX_PARTICLES Then BeamCount := MAX_PARTICLES;
    FullRepaint := True;
   End;
  End;
  TAG_PART_DIR: Begin
   If InputBoxReal('Direction du faisceau',
    'Angle XY (degres, 0 = +X) :', BeamAngleDeg) Then
    FullRepaint := True;
  End;

  TAG_GEO_BOX:    Begin Geom.Shape := gsBox; FullRepaint := True; End;
  TAG_GEO_CYL:    Begin Geom.Shape := gsCylinder; FullRepaint := True; End;
  TAG_GEO_SPHERE: Begin Geom.Shape := gsSphere; FullRepaint := True; End;
  TAG_GEO_SIZE:   DoSetGeomSize;
  TAG_GEO_MAT:    DoSetMaterial;

  TAG_VIEW_2D: Begin ViewMode3D := False; FullRepaint := True; End;
  TAG_VIEW_3D: Begin ViewMode3D := True;  FullRepaint := True; End;
  TAG_VIEW_HIST: Begin ShowHist := Not ShowHist; FullRepaint := True; End;
  TAG_VIEW_GRID: Begin ShowGrid := Not ShowGrid; FullRepaint := True; End;
  TAG_VIEW_RESET: Begin
   Cam.AngleX := 0.3; Cam.AngleY := 0.4;
   Cam.Dist := 60; Cam.Zoom := 1.0;
   FullRepaint := True;
  End;

  TAG_HELP_ABOUT: MessageBox('A propos de GEANT4',
   ['GEANT4 - Clone graphique (Pascal)',
    'Version ' + GEANT4_VERSION + ' (' + GEANT4_DATE + ')',
    '',
    'Auteur  : Sylvain Maltais',
    'Web     : https://www.gladir.com/physiq',
    'Licence : MIT',
    '',
    'Simulation du passage de particules',
    'dans la matiere : Bethe-Bloch + scattering',
    'de Highland + interactions photon (PE,',
    'Compton, paire).',
    '',
    'Menu Formules : ~40 formules de la',
    'physique classique avec calculatrice',
    'et grapheur.']);
  TAG_HELP_KEYS: MessageBox('Raccourcis clavier',
   ['F5 = Demarrer  F6 = Pause  F7 = Reset',
    'F8 = Pas-a-pas    + = Plus rapide  - = Plus lent',
    'E = Energie    N = Nombre',
    '2 / 3 = Vue 2D / 3D',
    'H = Histogramme  G = Grille',
    'R = Reset vue 3D',
    'Fleches (3D) = Rotation',
    'Alt + lettre = Ouvre un menu',
    'Esc = Ferme menu / dialogue']);
  TAG_HELP_DOC: MessageBox('Documentation',
   ['GEANT4 (CERN) est un toolkit open-source',
    'pour la simulation Monte-Carlo du passage',
    'de particules dans la matiere.',
    '',
    'Voir : https://geant4.web.cern.ch',
    '',
    'Cette demo Pascal reproduit l esprit :',
    '- choix de particule + energie',
    '- choix de geometrie + materiau',
    '- visualisation des trajectoires',
    '- calculatrice de formules de physique.']);
 Else
  If (Item.Tag >= TAG_FORM_BASE) And (Item.Tag < TAG_FORM_BASE + 16) Then
  Begin
   Cat := Item.Tag - TAG_FORM_BASE;
   Case Cat Of
    0:  ShowFormulasByCategory(fcCinematique);
    1:  ShowFormulasByCategory(fcDynamique);
    2:  ShowFormulasByCategory(fcEnergie);
    3:  ShowFormulasByCategory(fcGravitation);
    4:  ShowFormulasByCategory(fcOscillations);
    5:  ShowFormulasByCategory(fcOndes);
    6:  ShowFormulasByCategory(fcOptique);
    7:  ShowFormulasByCategory(fcElectroMag);
    8:  ShowFormulasByCategory(fcThermo);
    9:  ShowFormulasByCategory(fcRelativite);
    10: ShowFormulasByCategory(fcQuantique);
   End;
   FullRepaint := True;
  End;
 End;
End;

{ ============================================================
  RACCOURCIS CLAVIER GLOBAUX (HORS MENU)
  ============================================================ }

Procedure HandleGlobalKey(Var Ev: TEvent);
Var PP: PParticle;
Begin
 If Ev.Kind = EV_KEY_DOWN Then Begin
  Case Ev.KeyCode Of
   63: Begin { F5 : start }
    If NParticles = 0 Then SpawnBeam;
    SimRunning := True;
   End;
   64: SimRunning := False;       { F6 }
   65: Begin ResetSimulation; FullRepaint := True; End; { F7 }
   66: Begin                      { F8 = pas-a-pas }
    If NParticles = 0 Then SpawnBeam;
    SimRunning := False;
    PP := ParticlesHead;
    While PP <> Nil Do Begin
     If PP^.Alive Then StepParticle(PP^);
     PP := PP^.Next;
    End;
    Inc(SimStep);
    FullRepaint := True;
   End;
   59: ExecuteMenuItem(MainMenuBar.Menus[6].Items[2]); { F1 = doc }
   { Fleches en mode 3D }
   72: If ViewMode3D Then Begin Cam.AngleX := Cam.AngleX - 0.1;
    FullRepaint := True; End;
   80: If ViewMode3D Then Begin Cam.AngleX := Cam.AngleX + 0.1;
    FullRepaint := True; End;
   75: If ViewMode3D Then Begin Cam.AngleY := Cam.AngleY - 0.1;
    FullRepaint := True; End;
   77: If ViewMode3D Then Begin Cam.AngleY := Cam.AngleY + 0.1;
    FullRepaint := True; End;
  End;
 End
 Else If Ev.Kind = EV_KEY_CHAR Then Begin
  Case Ev.KeyChar Of
   '2': Begin ViewMode3D := False; FullRepaint := True; End;
   '3': Begin ViewMode3D := True;  FullRepaint := True; End;
   'h', 'H': Begin ShowHist := Not ShowHist; FullRepaint := True; End;
   'g', 'G': Begin ShowGrid := Not ShowGrid; FullRepaint := True; End;
   'r', 'R': If ViewMode3D Then Begin
    Cam.AngleX := 0.3; Cam.AngleY := 0.4;
    Cam.Dist := 60; Cam.Zoom := 1.0;
    FullRepaint := True;
   End;
   '+', '=': If ViewMode3D Then Begin Cam.Zoom := Cam.Zoom * 1.1;
    FullRepaint := True; End
   Else If SimSpeed < 10 Then Inc(SimSpeed);
   '-', '_': If ViewMode3D Then Begin Cam.Zoom := Cam.Zoom / 1.1;
    FullRepaint := True; End
   Else If SimSpeed > 1 Then Dec(SimSpeed);
  End;
 End;
End;

{ ============================================================
  BOUCLE PRINCIPALE
  ============================================================ }

Procedure SimulationTick;
Var K, NAlive: Integer; PP: PParticle;
Begin
 If Not SimRunning Then Exit;
 For K := 1 To SimSpeed Do Begin
  PP := ParticlesHead;
  While PP <> Nil Do Begin
   If PP^.Alive Then StepParticle(PP^);
   PP := PP^.Next;
  End;
  Inc(SimStep);
 End;
 NeedRedrawView := True;
 { Auto-arret : aucune particule vivante }
 NAlive := 0;
 PP := ParticlesHead;
 While PP <> Nil Do Begin
  If PP^.Alive Then Inc(NAlive);
  PP := PP^.Next;
 End;
 If (NAlive = 0) And (NParticles > 0) Then SimRunning := False;
End;

Var
 InitialCfgFile: String;

Procedure ShowCmdLineHelp;Begin
 WriteLn('GEANT4 - Cette commande permet de lancer un clone ',
          'pedagogique du simulateur Geant4.');
 WriteLn;
 WriteLn('Syntaxe :');
 WriteLn('  GEANT4 [fichier.CFG]');
 WriteLn('  GEANT4 /?');
 WriteLn;
 WriteLn('Parametres :');
 WriteLn('  fichier.CFG    Charge automatiquement le fichier de configuration');
 WriteLn('                 indique au demarrage (format texte CLE=VALEUR).');
 WriteLn('  /?, -?, -h     Affiche cette aide et quitte.');
 WriteLn('  --help, /help');
 WriteLn;
 WriteLn('Cles reconnues dans un fichier .CFG :');
 WriteLn('  BeamKind     = electron | photon | proton | alpha');
 WriteLn('  BeamEnergy   = <MeV>');
 WriteLn('  BeamCount    = <entier>');
 WriteLn('  BeamAngle    = <degres>');
 WriteLn('  GeomShape    = box | cylinder | sphere');
 WriteLn('  GeomCX/CY/CZ = <centre cm>');
 WriteLn('  GeomSX/SY/SZ = <dimensions cm>');
 WriteLn('  Material     = <nom de materiau>');
 WriteLn('  SimSpeed     = 1..10');
 WriteLn;
 WriteLn('Exemple :');
 WriteLn('  GEANT4 GEANT4.CFG');
End;

Function IsHelpArg(S: String): Boolean;
Var L: String; I: Integer; R: Boolean;
Begin
 L := S;
 For I := 1 To Length(L) Do L[I] := UpCase(L[I]);
 R := (L = '/?') Or (L = '-?') Or (L = '/H') Or (L = '-H') Or
      (L = '/HELP') Or (L = '-HELP') Or (L = '--HELP');
 IsHelpArg := R;
End;

Procedure ProcessCmdLine;
Var
 I: Integer;
 P: String;
Begin
 For I := 1 To ParamCount Do Begin
  P := ParamStr(I);
  If IsHelpArg(P) Then Begin
   ShowCmdLineHelp;
   Halt(0);
  End;
 End;
 For I := 1 To ParamCount Do Begin
  P := ParamStr(I);
  If (Length(P) > 0) And (P[1] <> '/') And (P[1] <> '-') Then Begin
   InitialCfgFile := P;
   Exit;
  End;
 End;
End;

Procedure MainLoop;
Var Ev: TEvent;
Begin
 NeedRedrawView := True;
 RedrawAll;
 Repeat
  PollEvents(Ev);
  Case Ev.Kind Of
   EV_MOUSE_DOWN, EV_MOUSE_MOVE: HandleMenuEvent(Ev);
   EV_KEY_DOWN, EV_KEY_CHAR: Begin
    If MenuActive Then HandleMenuEvent(Ev)
    Else Begin
     { Alt+lettre passe par HandleMenuEvent qui regarde KeyCode }
     If Ev.Kind = EV_KEY_DOWN Then HandleMenuEvent(Ev);
     HandleGlobalKey(Ev);
    End;
   End;
  End;
  SimulationTick;
  If FullRepaint Then Begin
   RedrawAll;
   FullRepaint := False;
   NeedRedrawView := False;
  End
  Else If NeedRedrawView Then Begin
   DrawViewport;
   DrawStatusBar;
   NeedRedrawView := False;
  End;
  Delay(15);
 Until QuitRequested;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }

BEGIN
 Randomize;
 RGHaveSpare := False;
 InitialCfgFile := '';
 ProcessCmdLine;
 InitializeGraphics;
 InitMaterials;
 InitGeometry;
 InitFormulas;
 InitMenuBar;
 InitViewport;
 NHistBins := 32;
 HistMax := 0;
 BeamKind := pkProton;
 BeamEnergy := 100.0;     { MeV }
 BeamCount := 10;
 BeamAngleDeg := 0;
 SimRunning := False;
 SimStep := 0;
 SimSpeed := 1;
 NParticles := 0;
 ViewMode3D := False;
 ShowGrid := True;
 ShowHist := True;
 Cam.AngleX := 0.3;
 Cam.AngleY := 0.4;
 Cam.Dist := 60;
 Cam.Zoom := 1.0;
 QuitRequested := False;
 FullRepaint := True;
 PrevMouseX := 0; PrevMouseY := 0; PrevMouseBtn := 0;
 LastClickX := -1; LastClickY := -1;
 LastClickTime := 0; LastClickBtn := MB_NONE;
 If MouseDriverFound Then ShowMouseCursor;
 If Length(InitialCfgFile) > 0 Then LoadConfigFile(InitialCfgFile);
 MainLoop;
 If MouseDriverFound Then HideMouseCursor;
 CloseGraph;
END.