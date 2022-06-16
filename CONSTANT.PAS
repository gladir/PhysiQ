{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2022
  @website(https://www.gladir.com/physiq)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program Constant;

Uses Strings;

Type
 PhysiqueConstantRec=Record
  Param,Nom,Formule:PChar;
  Value:Real;
 End;

Const
 Constants:Array[0..24]of PhysiqueConstantRec=(
  (Param:'/PESANTEUR';
   Nom:'AccÇlÇration de la pesanteur';
   Formule:'9.806 65 m/s2';
   Value:9.80665),

  (Param:'/LN';
   Nom:'Base des logarithmes naturels';
   Formule:'2.718 281 828 459...';
   Value:2.718281828459),

  (Param:'/CHARGELEM';
   Nom:'Charge ÇlÇmentaire';
   Formule:'1.602 176 487x10 -19 C';
   Value:1.602176487e-19),

  (Param:'/AVOGADRO';
   Nom:'Constante d''Avogadro';
   Formule:'6.022 141 79x10 23 1/mol';
   Value:6.02214179e23),

  (Param:'/BOLTZMANN';
   Nom:'Constante de Boltzmann';
   Formule:'1.380 6504x10-23 J/K';
   Value:1.3806504e-23),

  (Param:'/FARADAY';
   Nom:'Constante de Faraday';
   Formule:'96 485.3399 C/mol';
   Value:96485.3399),

  (Param:'/GRAVITATION';
   Nom:'Constante de gravitation';
   Formule:'6.674 28x10-11 N m2/kg2';
   Value:6.67428e-11),

  (Param:'/PLANCK';
   Nom:'Constante de Planck';
   Formule:'6.626 068 96x10-34 J s';
   Value:6.62606896e-34),

  (Param:'/MOLGAZ';
   Nom:'Constante molaire des gaz';
   Formule:'8.314 472 J/mol K';
   Value:8.314472),

  (Param:'/SOLAIRE';
   Nom:'Constante solaire';
   Formule:'1366 W/m2';
   Value:1366),

  (Param:'/RAYONNEMENT';
   Nom:'Deuxiäme constante de la loi de rayonnement';
   Formule:'0.014 387 752 m K';
   Value:0.014387752),

  (Param:'/ELECVOLT';
   Nom:'êlectron-volt';
   Formule:'1.602 176 487x10-19 J';
   Value:1.602176487e-19),

  (Param:'/MASSELEC';
   Nom:'Masse de l''Çlectron';
   Formule:'9.109 382 15x10-31 kg';
   Value:9.10938215e-31),

  (Param:'/MAGNVIDE';
   Nom:'PermÇabilitÇ magnÇtique du vide';
   Formule:'12.566 370 614...x10-7 N/A2';
   Value:12.566370614e-7),

  (Param:'/PERMVIDE';
   Nom:'PermittivitÇ du vide';
   Formule:'8.854 187 817...x10-12 F/m';
   Value:8.854187817e-12),

  (Param:'/PI';
   Nom:'Pi';
   Formule:'3.141 592 653 589 793 238...';
   Value:3.141592653589793238),

  (Param:'/LOIRAYON';
   Nom:'Premiäre constante de la loi de rayonnement';
   Formule:'3.741 771 18x10-16 W m2';
   Value:3.74177118e-16),

  (Param:'/PRESSION';
   Nom:'Pression standard';
   Formule:'101 325 Pa';
   Value:101325),

  (Param:'/RAPELECMASS';
   Nom:'Rapport masse de l''Çlectron/masse du proton';
   Formule:'5.446 170 2177x10-4';
   Value:5.4461702177e-4),

  (Param:'/RAYONELEC';
   Nom:'Rayon de l''Çlectron';
   Formule:'2.817 940 2894x10-15 m';
   Value:2.8179402894e-15),

  (Param:'/MASSEATOMIC';
   Nom:'UnitÇ de masse atomique';
   Formule:'1.660 538 782x10-27 kg';
   Value:1.660538782e-27),

  (Param:'/LUMIERE';
   Nom:'Vitesse de la lumiäre dans le vide';
   Formule:'299 792 458 m/s';
   Value:299792458),

  (Param:'/SON';
   Nom:'Vitesse du son dans l''air (Conditions standards)';
   Formule:'331.5 + 0.6 * T/¯C m/s';
   Value:331.5),

  (Param:'/VOLMOL';
   Nom:'Volume molaire (Gaz parfait, T = 273.15 K, p = 101.325 kPa)';
   Formule:'22.413 996x10-3 m3/mol';
   Value:22.413996e-3),

  (Param:'/ZEROABS';
   Nom:'ZÇro absolu';
   Formule:'-273.16 ¯C';
   Value:-273.16)
 );

Function PadRight(S:String;Space:Byte):String;
Var
 I:Byte;
Begin
 If Length(S)<Space Then For I:=Length(S)+1 to Space do S:=S+' ';
 PadRight:=S;
End;

Function StrToUpper(S:String):String;
Var
 I:Byte;
Begin
 For I:=1 to Length(S)do Begin
  If S[I]in['Ç','ä','à',#233]Then S[I]:='E'Else
  If S[I] in['a'..'z']Then S[I]:=Chr(Ord(S[I])-32);
 End;
 StrToUpper:=S;
End;

Var
 I,J:Integer;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('CONSTANT : Cette commande permet une constante physique');
  WriteLn;
  WriteLn('Syntaxe : CONSTANT [parametres]');
  WriteLn;
  For I:=Low(Constants) to High(Constants)do Begin
   WriteLn(PadRight(StrPas(Constants[I].Param),15),'  ',
           StrPas(Constants[I].Nom));
  End;
 End
  Else
 If ParamCount>0Then Begin
  For J:=1 to ParamCount do Begin
   For I:=Low(Constants) to High(Constants)do Begin
    If StrToUpper(ParamStr(J))=StrToUpper(StrPas(Constants[I].Param))Then Begin
     WriteLn(PadRight('Nom : ',15),StrPas(Constants[I].Nom));
     WriteLn(PadRight('Formule : ',15),StrPas(Constants[I].Formule));
     WriteLn(PadRight('Valeur : ',15),Constants[I].Value);
     WriteLn;
    End;
   End;
  End;
 End
  Else
 For I:=Low(Constants) to High(Constants)do Begin
  WriteLn(PadRight('Nom : ',15),StrPas(Constants[I].Nom));
  WriteLn(PadRight('Formule : ',15),StrPas(Constants[I].Formule));
  WriteLn(PadRight('Valeur : ',15),Constants[I].Value);
  WriteLn;
 End;
END.