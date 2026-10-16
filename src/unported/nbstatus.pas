{
  This routine displays information about NetBIOS, including a dump of the
  NetBIOS name table. It is NOT compatible with Token Ring Hardware, just
  PC-NET clones. It is compatible with many NetBIOS emulators, like the one
  included with Novell and LANtastic.

  Please address questions or comments regarding this utility on Compuserve in
  the PCVENB forum in section 6.

  by Richard S. Sadowsky
  5/3/90
}
{$S-,R-,A-,V-}
program NBStatus;

uses
  OpString,
  OpCrt,
  NetBios,
  NetBios2;

type
  String16         = String[16];

var
  Table            : PCNetAdapterTable;
  N                : NCB;
  Name             : NBNameStr;
  Ret,Num          : Byte;

function NBName2Str(Name : NBAsciiZ) : String16;

var
  S : String16;
begin
  Move(Name,S[1],16);
  S[0] := #16;
  NBName2Str := S;
end;

function ParseCommandString(Index : Byte) : String;
begin
  ParseCommandString := ParamStr(Index);
end;

procedure Report;
var
  I                : Word;
begin
  ClrScr;
  WriteLn('NetBios Adapter Status Information:'^M^J);
  with Table do begin
    WriteLn('Self test status         = ',SelfTest);
    WriteLn('Alignment errors         = ',AlignmentErrors);
    WriteLn('Collisions               = ',Collisions);
    WriteLn('Transmit Aborts          = ',TransmitAborts);
    WriteLn('Transmits                = ',Transmits);
    WriteLn('Receives                 = ',Receives);
    WriteLn('Resource Depletion       = ',ResourceDepletion);
    WriteLn('Free command blocks      = ',FreeCommandBlocks);
    WriteLn('Current maximum NCBs     = ',CurrentMaxNCBs);
    WriteLn('Hardware maximum NCBs    = ',HardwareMaxNCBs);
    WriteLn('Active sessions          = ',Sessions);
    WriteLn('Current max sessions     = ',CurrentMaxSessions);
    WriteLn('Hardware max sessions    = ',HardwareMaxSessions);
    WriteLn('Maximum packet size      = ',MaxPacketSize);
    Write(^M^J'press any key to display name table (esc to abort)');
    if ReadKey = ^[ then
      Halt;
    ClrScr;
            {1                    22             37 }
    WriteLn('NetBios name         name number    status');
    WriteLn('============================================');
    with NameTable do
      for I := 1 to EntryCount do
        with Entries[I] do begin
          WriteLn(NBName2Str(Name),'      ',NameNum:3,'            ',
                  BinaryB(Stat and $87));
        end;
  end;
end;

begin
  WriteLn('NetBios Adapter Information - version 1.0');
  FillChar(Name,SizeOf(Name),0);
  if ParamCount > 0 then begin

    Name := ParseCommandString(1);
    Write('please wait, getting adapter status for ',Name);
  end
  else begin
    Name := '*';
    Write('please wait, getting this adapters status...');
  end;
  Ret := AdapterStatusPrim(Name,0,SizeOf(Table),True,Nil,N,Table);
  WriteLn;
  case Ret of
    0 : Report;
    5 : WriteLn('No such name found (failed because timeout expired)');
    6 : WriteLn('Reply buffer is too small');
    else WriteLn('NetBios Error = ',Ret);
  end;
end.
