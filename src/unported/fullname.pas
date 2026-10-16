{*********************************************************************}
{* FULLNAME - Program to display NetWare user's full name            *}
{* version 1.0 1/13/90                                               *}
{* by Richard Sadowsky                                               *}
{*                                                                   *}
{* USAGE: FULLNAME [UserName]                                        *}
{*                                                                   *}
{*   UserName is the name of the user to return full name for.       *}
{*   If no UserName specified, program will prompt for one.          *}
{*                                                                   *}
{*                                                                   *}
{* This program requires the NETWARE unit from B-Tree Filer from     *}
{* TurboPower Software (408) 438-8608.                               *}
{*                                                                   *}
{* Also requires the NETBIND unit.                                   *}
{*                                                                   *}
{* Please address questions and comments about this unit to ALL in   *}
{* section 6 of the PCVENB forum on Compuserve.                      *}
{*                                                                   *}
{*********************************************************************}
{$V-,S-,R-}
program FullName;

{** define the following conditional to use with OPRO, undefine for TPRO}
{$DEFINE UseOPRO}
uses
  {$IFDEF UseOPRO}
  OpString,
  {$ELSE}
  TpString,
  {$ENDIF}
  NetWare,
  NetBind;

const
  FullNamePropName = 'IDENTIFICATION'; {the property name of the full name}

var
  ObjName          : ObjNameStr;
  HasProperties    : Boolean;
  ObjType          : Word;
  ObjID            : LongInt;
  ObjFlag, ObjSec  : Byte;
  Result           : Byte;
  PropVal          : PropertyValueType;

begin
  {if command line parameter specified, then use it as the user name}
  if ParamCount > 0 then
    {uppercase the parameter}
    ObjName := StUpCase(ParamStr(1))
  else begin
    {prompt for user name}
    Write('Enter user name: ');
    ReadLn(ObjName);
    ObjName := StUpCase(ObjName);
  end;
  {if no ObjName, then just quit}
  if Length(ObjName) = 0 then
    Halt;

  ObjType := bindUser;            {look for an user object}
  ObjID   := -1;                  {indicate start of search}
  {scan the bindery for the object}
  Result := ScanObject(ObjType, ObjName, ObjID, ObjFlag,
                       ObjSec, HasProperties);
  case Result of
    $00 : ;                       {No error}
    $FC : begin                   {No such user}
            WriteLn('There is no user ', ObjName, ' defined');
            Halt;
          end;
    else begin                    {other bindery error}
      WriteLn('Bindery error scanning object = ',Result);
      Halt;
    end;
  end;
  {if the user object has no properties, then no full name is defined for user}
  if not HasProperties then begin
    WriteLn('No full name defined for user ', ObjName);
    Halt;
  end;

  {Attempt to read the property value for IDENTIFICATION to return full name}
  Result := ReadPropertyValue(ObjType, ObjName, 1, FullNamePropName, PropVal,
                              ObjFlag, HasProperties);
  case Result of
    $00 : WriteLn('Full Name: ', AsciiZ2Str(PropVal, SizeOf(PropVal)-1));
    $F1, $F9 : WriteLn('You do not have adequate bindery rights to read the user''s full name');
    $FB : WriteLn('No full name defined for user ', ObjName);
    else WriteLn('Bindery error reading property value = ',Result);
  end;
end.
