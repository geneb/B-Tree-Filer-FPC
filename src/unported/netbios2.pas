
{$I BTDEFINE.INC}
{$F-,V-,B-,S-,I-,R-}
{$IFDEF CanAllowOverlays}
  {$O+,F+,A-}
{$ENDIF}
{$IFDEF CanSetOvrflowCheck}
  {$Q-}
{$ENDIF}

{*********************************************************}
{*                 NETBIOS2.PAS 1.01                     *}
{*********************************************************}

{
  Complements the NETBIOS.PAS unit.

  This unit adds support for Network Adapter Status function call. Among
  other things, this allows you to return the NetBios Name Table for any
  active node.

  Please address questions or comments regarding this utility on Compuserve in
  the PCVENB forum in section 6.

  by Richard S. Sadowsky
  5/3/90

  Jan 93 - Modified to support protected mode.
}

Unit NetBios2;

interface

Uses
  {$IFDEF Windows}
  WinProcs,
  WinTypes,
  WinDos,
  WinDPMI,
  {$ELSE}
  Dos,
  {$IFDEF DPMI}
  WinDPMI,
  {$ENDIF}
  {$ENDIF}
  NetBios;

const
  NBAdapterStatus  = $33;
  MaxTableEntries  = 64;

type
  NBAsciiZ         = Array[0..15] of Char;
  TableEntry       =
    record
      Name         : NBAsciiZ;
      NameNum      : Byte;
      Stat         : Byte;
    end;
  TableEntries     = Array[1..MaxTableEntries] of TableEntry;

  NetBiosNameTable =
    record
      EntryCount             : Word;
      Entries                : TableEntries;
    end;

  PCNetAdapterTable =
    record
      PermanentNodeName      : Array[1..6] of Char;
      ExtJumbers             : Byte;
      SelfTest               : Byte;
      ProtocolMajor          : Byte;
      ProtocolMinor          : Byte;
      ReportingPeriod        : Word;
      CRCCount               : Word;
      AlignmentErrors        : Word;
      Collisions             : Word;
      TransmitAborts         : Word;
      Transmits              : LongInt;
      Receives               : LongInt;
      Retransmits            : Word;
      ResourceDepletion      : Word;
      ReservedArea1          : Array[1..8] of Char;
      FreeCommandBlocks      : Word;
      CurrentMaxNCBs         : Word;
      HardwareMaxNCBs        : Word;
      ReservedArea2          : Array[1..4] of Char;
      Sessions               : Word;
      CurrentMaxSessions     : Word;
      HardwareMaxSessions    : Word;
      MaxPacketSize          : Word;
      NameTable              : NetBiosNameTable;
    end;
  PCNetAdapterTablePtr       =  ^PCNetAdapterTable;

{$IFDEF DPMIorWnd}
type
  WinPCNetAdapterTable = record
                           natR, natP : PCNetAdapterTablePtr;
                         end;

function AdapterStatusPrim(    TargetName  : NBNameStr;
                               LanaNumber  : Byte;
                               ReplyBufLen : Word;
                               Wait        : Boolean;
                           var PostEvent   : WinPostType;
                           var N           : WinNCB;
                               ReplyBuf    : Pointer) : Byte;
  {-Returns adapter status}
{$ELSE}
function AdapterStatusPrim(    TargetName  : NBNameStr;
                               LanaNumber  : Byte;
                               ReplyBufLen : Word;
                               Wait        : Boolean;
                               PostEvent   : Pointer;
                           var N           : NCB;
                           var ReplyBuf    {untyped}) : Byte;
  {-Returns adapter status}
{$ENDIF}

function MaximumPacketSize : Word;
  {-Returns the maximum size of a session packet (in Bytes), or zero if error}

implementation

{$IFDEF DPMIorWnd}
function AdapterStatusPrim(    TargetName  : NBNameStr;
                               LanaNumber  : Byte;
                               ReplyBufLen : Word;
                               Wait        : Boolean;
                           var PostEvent   : WinPostType;
                           var N           : WinNCB;
                               ReplyBuf    : Pointer) : Byte;
  {-Returns adapter status}
begin
  ClearNCB(N.NP^);
  with N.NP^ do begin
    Command := NBAdapterStatus;
    if not Wait then begin
      Command := Command + NoWait;
      PostRoutine := PostEvent.Callback;     {set the post event routine}
      PostEvent.NCBs := @N;
    end;
    Move(TargetName[1],CallName,Length(TargetName));  {set the call name}
    BufLen := ReplyBufLen;
    Buffer := ReplyBuf;
  end;
  NetBiosRequest(N.NR);                                {send off request}
  AdapterStatusPrim := N.NP^.RetCode;
end;

function MaximumPacketSize : Word;
  {-Returns the maximum size of a session packet (in Bytes), or zero if error}
var
  Table            : WinPCNetAdapterTable;
  N                : WinNCB;
  Name             : NBNameStr;
  PostEvent        : WinPostType;

begin
  MaximumPacketSize := 0;
  if not AllocateWinNCB(N) then
    Exit;
  with Table do
    if not GetRealModeMem(SizeOf(PCNetAdapterTable),
                          Pointer(natR),
                          Pointer(natP)) then Exit;

  FillChar(PostEvent,SizeOf(PostEvent),#0);

  Name := '*';
  if AdapterStatusPrim(Name,0,SizeOf(Table.natP^),True,
      PostEvent,N,Table.natR) = 0 then
    MaximumPacketSize := Table.natP^.MaxPacketSize;

  FreeRealModeMem(Table.natP);
  FreeWinNCB(N);
end;

{$ELSE}

function AdapterStatusPrim(    TargetName  : NBNameStr;
                               LanaNumber  : Byte;
                               ReplyBufLen : Word;
                               Wait        : Boolean;
                               PostEvent   : Pointer;
                           var N           : NCB;
                           var ReplyBuf    {untyped}) : Byte;
  {-Returns adapter status}
begin
  ClearNCB(N);
  with N do begin
    Command := NBAdapterStatus;
    if not Wait then
      Command := Command + NoWait;
    Move(TargetName[1],CallName,Length(TargetName));   {set the call name}
    BufLen := ReplyBufLen;
    Buffer := @ReplyBuf;
    PostRoutine := PostEvent;           {set the post event routine}
  end;
  NetBiosRequest(N);
  AdapterStatusPrim := N.RetCode;
end;

function MaximumPacketSize : Word;
  {-Returns the maximum size of a session packet (in Bytes), or zero if error}
var
  Table            : PCNetAdapterTable;
  N                : NCB;
  Name             : NBNameStr;

begin
  Name := '*';
  if AdapterStatusPrim(Name,0,SizeOf(Table),True,Nil,N,Table) = 0 then
    MaximumPacketSize := Table.MaxPacketSize
  else
    MaximumPacketSize := 0;
end;
{$ENDIF}


end.

