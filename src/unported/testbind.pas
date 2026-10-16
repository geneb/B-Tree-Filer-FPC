{
  Test program for NETBIND - Dumps all visible objects in the Bindery

  by Richard S. Sadowsky

  Please address questions and comments about this unit to ALL in section 6 of
  the PCVENB forum on Compuserve.
}

program TestBind;

uses
{$IFDEF Windows}
  WinDos,
  WinCrt,
{$ELSE}
  Dos,
  OpCrt,
  OpDos,
  OpString,
{$ENDIF}
  NetWare,
  NetBind,
  NetQue;

{$IFDEF Windows}
const
  Digits : array[0..$F] of Char = '0123456789ABCDEF';

type
  Long =
    record
      LowWord, HighWord : Word;
    end;


  function HexB(B : Byte) : string;
    {-Return hex string for byte}
  begin
    HexB[0] := #2;
    HexB[1] := Digits[B shr 4];
    HexB[2] := Digits[B and $F];
  end;

  function HexW(W : Word) : string;
    {-Return hex string for word}
  begin
    HexW[0] := #4;
    HexW[1] := Digits[hi(W) shr 4];
    HexW[2] := Digits[hi(W) and $F];
    HexW[3] := Digits[lo(W) shr 4];
    HexW[4] := Digits[lo(W) and $F];
  end;

  function HexL(L : LongInt) : string;
    {-Return hex string for LongInt}
  begin
    with Long(L) do
      HexL := HexW(HighWord)+HexW(LowWord);
  end;
{$ENDIF}

procedure DisplayObject(ObjType : Word; ObjName : ObjNameStr;
                        ObjID : LongInt; ObjFlag : Byte;
                        ObjSec : Byte; HasProp : Boolean);

begin
  WriteLn('Object Type         = ',HexW(ObjType));
  WriteLn('Object Name         = ',ObjName);
  WriteLn('Object ID           = ',HexL(ObjID));
  WriteLn('Object Flag         = ',HexB(ObjFlag));
  WriteLn('Object Security     = ',HexB(ObjSec));
  WriteLn('Has Properties      = ',HasProp);
end;

procedure DisplayProperty(PropName : PropertyStr;
                          PropFlags,PropSec : Byte;
                          HasValue : Boolean);
begin
  Write('Property: ',PropName);
  Write('  flags: ',HexB(PropFlags));
  WriteLn('  security: ',HexB(PropSec),'  HasValue: ',HasValue);
end;

var
  ObjectID,
  Sequence       : LongInt;
  ObjectType     : Word;
  ObjectName     : ObjNameStr;
  PropName       : PropertyStr;
  Result         : Byte;
  ObjectFlag,
  ObjectSecurity,
  PropFlag,
  PropSec        : Byte;

  HasProperties,
  HasValue,
  Done           : Boolean;

begin
  {$IFNDEF Windows}
  Assign(Output,'');
  Rewrite(Output);
  {$ENDIF}
  ObjectID := -1;
  repeat
    ObjectType := bindWild;
    ObjectName := '*';
    Result := ScanObject(ObjectType,ObjectName,ObjectID,ObjectFlag,
                         ObjectSecurity,HasProperties);
    Done := (Result <> 0);
    if not Done then begin
      DisplayObject(ObjectType,ObjectName,ObjectID,ObjectFlag,
                    ObjectSecurity,HasProperties);
      Sequence := -1;
      while HasProperties do begin
        PropName := '*';
        Result := ScanProperty(ObjectType,ObjectName,Sequence,PropName,
                               PropFlag,PropSec,HasValue,HasProperties);
        if Result = 0 then
          DisplayProperty(PropName,PropFlag,PropSec,HasValue);
      end;
     {$IFNDEF Windows}
      if HandleIsConsole(TextRec(Output).Handle) then
     {$ENDIF}
        Done := ReadKey in [^C,^[];
      WriteLn;
    end;
  until Done;
end.
