{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2025
  @website(https://www.gladir.com/physiq)
  @abstract(Target: Turbo Pascal, Free Pascal)
}

Program EMC2;

Var
 m,c,E:Real;
 Err:Word;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('EMC2 : Cette commande permet de calculer l''‚nergie avec ',
                  'l''‚quation E = mc^2 d''Albert Einstein.');
  WriteLn;
  Writeln('Syntaxe : EMC2 <masse> <vitesse de la lumiŠre>');
  WriteLn;
  Halt(0);
 End
  Else
 If ParamCount<2 Then Begin
  Writeln('Syntaxe : EMC2 <masse> <vitesse de la lumiŠre>');
  Halt(1);
 End;
 Val(ParamStr(1), m,Err);
 Val(ParamStr(2), c,Err);
 E:=m*Sqr(c);  { E = m * c^2 }
 Writeln('Energie (E=mc^2) = ', E:0:2);
END.