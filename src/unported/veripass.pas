{*********************************************************************}
{* VERIPASS - Program to verify a NetWare user's password            *}
{* version 1.0 4/27/90                                               *}
{* by Richard Sadowsky                                               *}
{*                                                                   *}
{* USAGE: VERIPASS UserName [PASSWORD]                               *}
{*                                                                   *}
{*   UserName is the name of the user.                               *}
{*   PASSWORD is the password to verify (if none specified, then     *}
{*                                       empty string passed as      *}
{*                                       the password).              *}
{*                                                                   *}
{* This program displays a message and also sets the DOS ErrorLevel  *}
{* on exit. The returned values are:                                 *}
{*                                                                   *}
{*   0 - Password verified                                           *}
{*   1 - Incorrect password                                          *}
{*   for other values see source                                     *}
{*                                                                   *}
{* This program requires the NETWARE unit from B-Tree Filer from     *}
{* TurboPower Software (408) 438-8608.                               *}
{*                                                                   *}
{* Also requires the NETBIND unit.                                   *}
{*                                                                   *}
{*********************************************************************}
{$V-,S-,R-}
program VerifyAPassword;

uses
  NetWare,
  NetBind;
var
  Ret : Byte;

function UpperCaseSt(S : String) : String;
  {-Return S as all uppercase letters}
var
  Result : String;
  I : Byte;
begin
  Result[0] := S[0];
  for I := 1 to Length(S) do
    Result[I] := UpCase(S[I]);
  UpperCaseSt := Result;
end;

begin
  if ParamCount < 1 then begin
    WriteLn('usage:');
    WriteLn('  VERIPASS UserName [Password]');
    Halt;
  end;
  Ret := VerifyPassword(bindUser, UpperCaseSt(ParamStr(1)),
                        UpperCaseSt(ParamStr(2)));
  case Ret of
    0 : begin
          WriteLn('Password verified');
          Halt(0);
        end;
    $96 : begin
           WriteLn('Server out of memory');
           Halt(2);
         end;
    $F0 : begin
             WriteLn('Wildcard not allowed');
             Halt(3);
          end;
    $FB : begin
             WriteLn('No such property');
             Halt(4);
          end;
    $FC : begin
             WriteLn('No such object');
             Halt(6);
          end;
    $FE : begin
             WriteLn('Bindery locked');
             Halt(7);
          end;
    $FF : begin
             WriteLn('Incorrect password');
             Halt(1);
          end;
    else begin
      WriteLn('Unknown error');
      Halt(8);
    end;
  end;
end.
