{*********************************************************}
{*                  NSENDW.PAS 5.41                      *}
{*        Copyright (c) TurboPower Software 1989.        *}
{*                 All rights reserved.                  *}
{*********************************************************}

{--Conditional defines and compiler options}
  {$I BTDefine.Inc}
  {$F-,V-,B-,S-,I-,R-}
  {$IFDEF CanSetOvrflowCheck}
    {$Q-}
  {$ENDIF}

{$IFNDEF DPMIOrWnd}
  **Error ** This file is for TPW or DPMI only
{$ENDIF}

{
  This program is a simple file transfer utility designed solely to
  exemplify the use of NetBIOS Session Services and NetWare SPX Services.
  This program must be compiled with Turbo Pascal For Windows and run under
  Microsoft Windows.

  Under NetBIOS, the sender runs NSENDW -B and the receiver runs NRECEIVW -B.
  Both sides are promted for a file name. The sending side will send the file
  specified and the receiver will create it under the name specified on that
  end.

  Under NetWare, the sender runs NSENDW -W and the receiver runs NRECEIVW -W.
  If the -A option is specified, then NSENDW will automatically find a waiting
  NRECEIVW at another workstation. Without the -A option, both sides will be
  prompted for the user name to establish a connection with.

  You may use this program with the DOS based NRECEIVE instead of NRECEIVW if
  you wish.
}

program Windows_Net_Send;

uses
  Strings,
  {$IFDEF Windows}
  WinCrt,
  WinDos,
  {$ELSE}
  Crt,
  Dos,
  {$ENDIF}
  WinDPMI,
  NetBios,
  NetWare;

{$IFDEF Windows}
type
  SearchRec = TSearchRec;
{$ENDIF}

const
  NoRealMem        = 1;
  NumberECBs       = 4;
  MaxArgs          = 1024; { this number determines the maximum number    }
                           { of file names that can be held in the list.  }

  DefaultRetries   = 8;

  UsingNetBios     : Boolean = FALSE;
  Verbose          : Boolean = FALSE;
  ConnectRetries   : Word = 0;
  DosDelimSet      : set of Char = ['\', ':', #0];

  {NetBios constants}

  {The session names}             {1234567890123456}
  SendSessName     : String[16] = 'NetBiosSend   '#88;
  RecSessName      : String[16] = 'NetBiosReceive'#88;
  {the character #88 is used to terminate the session names to ensure that}
  {there is no conflict with any names reserved by IBM}

  {NetWare constants}
  SessionSocket    = $4746;   {!!.41}
  {RecSessionSocket = $4848;} {!!.41}
  NetWareCacheSize = $8000;
  MaxNBBuf         = 2048;
  DelayForRemote   : Word = 0;
  NetWareAutoFind  : Boolean = FALSE;
  CacheIOResult    : Integer = 0;
  ReceiversECBs    : Byte = 1;

  {some flags used by the exitproc OurExitProc}
  SessionCreated   : Boolean = FALSE;
  SessionNameCreated
                   : Boolean = FALSE;
  WinStringAllocated:Boolean = FALSE;
  NetWareAllocated : Boolean = FALSE;
  ECBAllocated     : Boolean = FALSE;
  AckAllocated     : Boolean = FALSE;
  SendESRAllocated : Boolean = FALSE;
  RecESRAllocated  : Boolean = FALSE;
  NetBIOSAllocated : Boolean = FALSE;
  NCBAllocated     : Boolean = FALSE;

type
  String80         = String[80];
  ArgsList         = Array[1..MaxArgs] of ^PathName; { list type to hold }
                                                      { the expanded file }
                                                      { names }
  ArgumentType     = record
                       NArgs : Word;
                       Args  : ArgsList;
                     end;
  StringPtr        = ^String;
  WinString        = record
                       wsR, wsP : StringPtr;
                     end;

  {NetBIOS types}
  SessionBuf       = Array[1..MaxNBBuf] of Char; {the data buffer for sessions}
  NetBIOSMsg       = record                     {the session data packet}
                       TxtLength : Word;        {length of data in Txt}
                       Txt       : SessionBuf;  {the data}
                     end;
  NetBiosMsgPtr    = ^NetBIOSMsg;
  WinNetBIOSMsg    = record
                       nbmR, nbmP : NetBIOSMsgPtr;
                     end;


  {NetWare type}
  XmitData         = Array[1..512] of Char;    {the data buffer for SPX}
  NetWareMsg       = record                    {the SPX data packet}
                       TxtLength : Word;        {length of data in Txt}
                       Txt       : XmitData;   {the data}
                     end;
  NetWareMsgPtr    = ^NetWareMsg;
  WinNetWareMsg    = record
                       nwmR, nwmP : NetWareMsgPtr;
                     end;

  CacheBuffer      = Array[1..$FFF0] of Char;
  FileCache        = record
                       CacheSize   : Word;
                       CachePos    : Word;
                       CacheEnd    : Word;
                       CacheBuf    : ^CacheBuffer;
                     end;

var
  SavExitProc      : Pointer;    {to save the original exit proc}
  Arguments        : ArgumentType;
  FName            : PathName;   {the name of the file to send}
  Scratch          : WinString;

  {NetBIOS variables}
  SessionLSN       : Byte;         {The local session number for this session}
  XmitBlock        : WinNetBIOSMsg;{the message packet for NetBIOS}
  OurNCB           : WinNCB;
  WinPost          : WinPostType;

  {NetWare variables}
  XmitPacket       : WinNetWareMsg; {the message packet for Novell}
  XmitRec          : WinSPXRec;     {the SPX Record}
  SendESR          : WinESRType;
  ReceiveESR       : WinESRType;
  Receiver         : IPXAddress;    {The IPX address of the receiver}
  UserName         : String;        {the name of the user to send to}
  Cache            : FileCache;


procedure Terminate(S : String; ErrorLevel : Word);
{Halt program (triggering the Exit Procedures) and set errorlevel}
begin
  WriteLn(^M^J,S);
  Halt(ErrorLevel);
end;

procedure CheckForUserBreak;
{If user has pressed ^C or Esc, Abort, otherwise just clear keyboard buffer}

begin
  if KeyPressed then begin
    if ReadKey in [^C,^[] then begin
      WriteLn;
      Terminate('User break',99);
    end;
  end;
end;

function JustPathname(PathName : string) : string;
  {-Return just the drive:directory portion of a pathname}
var
  I : Word;
begin
  I := Succ(Word(Length(PathName)));
  repeat
    Dec(I);
  until (PathName[I] in DosDelimSet) or (I = 0);

  if I = 0 then
    {Had no drive or directory name}
    JustPathname[0] := #0
  else if I = 1 then
    {Either the root directory of default drive or invalid pathname}
    JustPathname := PathName[1]
  else if (PathName[I] = '\') then begin
    if PathName[Pred(I)] = ':' then
      {Root directory of a drive, leave trailing backslash}
      JustPathname := Copy(PathName, 1, I)
    else
      {Subdirectory, remove the trailing backslash}
      JustPathname := Copy(PathName, 1, Pred(I));
  end else
    {Either the default directory of a drive or invalid pathname}
    JustPathname := Copy(PathName, 1, I);
end;

function JustFilename(Name : PathName) : string;
{-Return just the filename of a pathname}


var
  I : Word;

begin
  I := Succ(Word(Length(Name)));
  repeat
    Dec(I);
  until (Name[I] in DosDelimSet) or (I = 0);
  JustFilename := Copy(Name, Succ(I), 64);
end;

function UpperString(S : String) : String;
{returns the string as all uppercase charcaters}
var
  I                : Byte;

begin
  for I := 1 to Length(S) do
    S[I] := UpCase(S[I]);
  UpperString := S;
end;

procedure AllocateCache(var Cache : FileCache; Size : Word);

begin
  with Cache do begin
    GetMem(CacheBuf,Size);
    CacheSize := Size;
    CachePos := 1;
    CacheEnd := 1;
  end;
end;

function CacheEOF(var F : File; var Cache : FileCache) : Boolean;

begin
  with Cache do
    CacheEOF := (CachePos >= CacheEnd) and EOF(F);
end;

procedure CacheBlockRead(var F : File; var Cache : FileCache;
                         var Buf; Size : Word; var NumRead : Word);

begin
  with Cache do begin
    if CachePos >= CacheEnd then begin
      BlockRead(F,CacheBuf^,CacheSize,CacheEnd);
      CacheIOResult := IOResult;
      CachePos := 1;
    end;
    if Size > CacheEnd - (CachePos-1) then
      NumRead := CacheEnd - (CachePos-1)
    else
      NumRead := Size;
    Move(CacheBuf^[CachePos],Buf,NumRead);
    CachePos := CachePos + NumRead;
  end;
end;

{$IFDEF Windows}
function MakeFileName(P : PathName; F : PChar) : PathName;
{Makes a full pathname from a drive and/or subdirectory and a file name}
var
  FS : String;
begin
  FS := StrPas(F);
  if Length(P) = 0 then
    MakeFileName := FS
  else
    if (Length(P) = 2) and (P[2] = ':') then
      MakeFileName := P + FS
    else
      if P[Length(P)] = '\' then
        MakeFileName := P + FS
      else
        MakeFileName := P + '\' + FS;
end;
{$ELSE}
function MakeFileName(P,F : PathName) : PathName;
{Makes a full pathname from a drive and/or subdirectory and a file name}

begin
  if Length(P) = 0 then
    MakeFileName := F
  else
    if (Length(P) = 2) and (P[2] = ':') then
      MakeFileName := P + F
    else
      if P[Length(P)] = '\' then
        MakeFileName := P + F
      else
        MakeFileName := P + '\' + F;
end;
{$ENDIF}

procedure AddArgs(var Args : ArgumentType; FName : PathName);
{ add the file name to Args and increment NArgs }
begin
  with Args do begin
    Inc(NArgs);

    if NArgs > MaxArgs then         { check for overflow}
      Terminate('Argument overflow - Too many files found',90);

    New(Args[NArgs]);
    Args[NArgs]^ := FName
  end;
end;


procedure ExpandArgs(var Args : ArgumentType; FileSpec : PathName);
{Expands the FileSpec placing each file that matches into the Args list}
{$IFDEF Windows}
var
  DirInfo          : SearchRec;
  PName            : PathName;
  PC               : Array[0..SizeOf(PathName)-1] of Char;
begin
  { expand filename w/wildcard }
  PName := UpperString(JustPathName(FileSpec));
  StrPCopy(PC, FileSpec);
  FindFirst(PC,faArchive,DirInfo);
  while DOSError = 0 do begin
    AddArgs(Args,MakeFileName(PName,DirInfo.Name)); { add each file matching}
                                                    { filespec to Args }
    FindNext(DirInfo);
  end; {while}
end;
{$ELSE}
var
  DirInfo          : SearchRec;
  PName            : PathName;
begin
  { expand filename w/wildcard }
  PName := UpperString(JustPathName(FileSpec));
  FindFirst(FileSpec,Archive,DirInfo);
  while DOSError = 0 do begin
    AddArgs(Args,MakeFileName(PName,DirInfo.Name)); { add each file matching}
                                                    { filespec to Args }
    FindNext(DirInfo);
  end; {while}
end;
{$ENDIF}

function AllocateWinString(MaxLen : Byte; var WS : WinString) : Boolean;
begin
  with WS do
    AllocateWinString := GetRealModeMem(Word(MaxLen) + 1,
                                        Pointer(wsR),
                                        Pointer(wsP));
end;

procedure FreeWinString(var WS : WinString);
begin
  FreeRealModeMem(WS.wsP);
end;

{NetBIOS routines}
function AllocateWinNetBIOSMsg(var Msg : WinNetBIOSMsg) : Boolean;
begin
  with Msg do
    AllocateWinNetBIOSMsg := GetRealModeMem(SizeOf(NetBIOSMsg),
                                            Pointer(nbmr),
                                            Pointer(nbmP));
end;

procedure FreeWinNetBIOSMsg(var Msg : WinNetBIOSMsg);
begin
  FreeRealModeMem(Msg.nbmP);
end;

procedure NetBiosOpenSession;
{add our session name, and create a session.  Aborts on any errors}

var
  Num              : Byte;
  Ret              : Byte;
  RetryCount       : Word;

begin
  ClearNCB(OurNCB.NP^);
  if Verbose then
    WriteLn('Adding name to the NetBIOS name table...');
  {first try to add the session name}
  if NetBiosAddName(SendSessName,Num) <> NBESUCCESS then
    Terminate('Can not create session.',1)
  else
    SessionNameCreated := TRUE;  {set to TRUE so exit handler knows to remove}

  {create the session}
  if ConnectRetries = 0 then
    ConnectRetries := DefaultRetries;
  RetryCount := 0;

  WriteLn('Attempting to find remote receiver...');
  while (not SessionCreated) and (RetryCount <= ConnectRetries) do begin
    (****delay****)
    Inc(RetryCount);
    NetBiosCallNoWait(RecSessName,SendSessName,10,10,WinPost,OurNCB);
    {wait until command is complete or user wants out}
    while not NetBiosCmdCompleted(OurNCB,Ret) do
      CheckForUserBreak;
    if Ret = NBESUCCESS then begin
      SessionLSN := OurNCB.NP^.LSN;
      SessionCreated := TRUE {set to TRUE so exit handler knows to terminate}
    end
    else begin
      WriteLn('Attempt number ',RetryCount,' was unsuccessful');
      if CancelRequest(OurNCB) = 0 then ;
      ClearNCB(OurNCB.NP^);
      CheckForUserBreak;
    end;
  end;
  if not SessionCreated then
    Terminate('Unable to establish communication with receiving station',2);
end;

procedure NetBiosCloseSession;
{Hang up session and delete session name}
begin
  if NetBiosHangUp(SessionLSN) <> NBESUCCESS then
    Terminate('Error on hang up',9);

  if NetBiosDeleteName(SendSessName) <> NBESUCCESS then begin
    Terminate('Error deleting session name',10);
    SessionNameCreated := FALSE;
  end;
end;

procedure NetBiosTransmit(var F : File);
{Sends the file to the receiving station.  The first packet sent is a word}
{specifying the number of packets to expect.  Then for each packet, fill  }
{the sessionbuf with bytes from the file, and use NetBiosSend to send the }
{packet.  Aborts on any errors.}
var
  NumBlocksGoing   : Word;
  Count,NumRead    : Word;
  FSize            : LongInt;
  Ret              : Byte;

begin
  FSize := FileSize(F);
  if IOResult <> 0 then
    Terminate('Error getting size of file',4);

  {Calculate the number of blocks to send}
  NumBlocksGoing := Word((FSize + SizeOf(SessionBuf) - 1) DIV
                    LongInt(SizeOf(SessionBuf)));
  Count   := 0;
  repeat
    with XmitBlock.nbmP^ do begin
      {check to see if this is the first packet of this file.  If it is, then}

      if Count <> 0 then begin
        BlockRead(F,Txt,SizeOf(SessionBuf),NumRead);
        if IOResult <> 0 then
          Terminate('Error reading file',5);
        TxtLength := NumRead;
      end
      else begin
        TxtLength := SizeOf(Word);
        Move(NumBlocksGoing,Txt,SizeOf(Word));
      end;
      Ret := NetBiosSend(SessionLSN,TxtLength+SizeOf(Word),XmitBlock.nbmR);
    end;
    if Ret <> NBESUCCESS then
      Terminate('Send error returned by NetBios',6);
    Inc(Count);
  until EOF(F);
  WriteLn('File transmitted!');
end;

procedure NetBIOSInformNumOfFiles;
{Inform the session partner of the number of files coming}

var
  Ret              : Byte;

begin
  with Arguments do begin
    WriteLn('Sending ',NArgs,' files');
    Move(NArgs, Scratch.wsP^, SizeOf(Word));
    Ret := NetBiosSend(SessionLSN,SizeOf(Word),Scratch.wsR);
    if Ret <> NBESUCCESS then
      Terminate('Send error returned by NetBios',6);
  end;
end;

function NetBIOSInform(Name : PathName) : Boolean;

var
  Ret              : Byte;

begin
  Scratch.wsP^ := JustFileName(Name);
  Ret := NetBiosSend(SessionLSN,Length(Scratch.wsP^)+1,Scratch.wsR);
  if Ret <> NBESUCCESS then
    Terminate('Send error returned by NetBios',6);
  Ret := NetBiosReceive(SessionLSN,SizeOf(Boolean),Scratch.wsR);
  if Ret <> NBESUCCESS then
    Terminate('Receive error returned by NetBios',6);
  NetBIOSInform := Boolean(Scratch.wsP^[0]);
end;


{NetWare routines}
function AllocateWinNetWareMsg(var Msg : WinNetWareMsg) : Boolean;
begin
  with Msg do
    AllocateWinNetWareMsg := GetRealModeMem(SizeOf(NetWareMsg),
                                            Pointer(nwmR),
                                            Pointer(nwmP));
end;

procedure FreeWinNetWareMsg(var Msg : WinNetWareMsg);
begin
  FreeRealModeMem(Msg.nwmP);
end;

function ConnIDFromListenECB(WE : WinIPXECB) : Word;

begin
  ConnIDFromListenECB := Word(WE.ECBP^.IPXWorkspace);
end;

function WaitForSPX(Rec : WinSPXRec) : Byte;
begin
  while Rec.wsrP^.ECB.ECBP^.InUse <> 0 do begin
    IPXRelinquish;
    CheckForUserBreak;
  end;
  WaitForSPX := Rec.wsrP^.ECB.ECBP^.CompletionCode;
end;

var
  Connect,Result   : ConnectionList;

function BroadcastPresence : Byte;

const
  SendStr          = '**-TurboPower-**NSEND';
  ReceiveStr       = '**-TurboPower-**NRECEIVE';
  NumAttempts      = 60;
  ListenAttempts   = 60;
  DelayValue       = 500;

var
  ServerInf        : ServerInformation;
  InMsg            : MessageStr;
  Num,I            : Byte;
  Conn             : Byte;
  Notified         : Boolean;
  TryCount         : Word;
  ListenCount      : Word;

begin
  Write('Attempting to AutoFind Receiver');
  TryCount := 0;
  GetServerInfo(ServerInf);
  repeat
    Write('.');
    with Connect do begin
      Count := ServerInf.MaxConns;
      for I := 1 to Count do
        List[I] := I;

      List[GetConnNo] := List[Count];
      Dec(Count);

      OpenMessagePipe(Connect,Result);
      Num := Count;
      Count := 0;
      for I := 1 to Num do begin
        if Result.List[I] = 0 then begin
          Inc(Count);
          List[Count] := I;
        end;
      end;
      Conn := 0;
      Notified := FALSE;
      if Count > 0 then begin
        SendMessagePipe(SendStr,Connect,Result);
        ListenCount := 0;
        while (ListenCount < ListenAttempts) and (not Notified) do begin
          GetMessagePipe(Conn,InMsg);
          Notified := InMsg = ReceiveStr;
          InMsg := '';
          Inc(ListenCount);
          CheckForUserBreak;
        end;
      end;
    end;

    (*delay**************)

    CheckForUserBreak;
    Inc(TryCount);
  until (Notified) or (Conn <> 0) or (TryCount >= NumAttempts);
  if Conn = 0 then
    Terminate('AutoFind unable to contact Receiver',84)
  else
    WriteLn(^M^J,'Found receiver at connection ',Conn);

  BroadcastPresence := Conn;
end;

procedure FlushPipes;
{Clears the message pipes }
var
  Conn             : Byte;
  Msg              : MessageStr;
  ServerInf        : ServerInformation;               {!!.21}
begin
  if Connect.Count > 0 then begin
    repeat
      GetMessagePipe(Conn,Msg);
    until (Conn = 0) or (Msg = '');
    GetServerInfo(ServerInf);                         {!!.21}
    Connect.Count := ServerInf.MaxConns;              {!!.21}
    for Conn := 1 to Connect.Count do                 {!!.21}
      Connect.List[Conn] := Conn;                     {!!.21}
    Connect.List[GetConnNo] := Connect.List[Connect.Count];     {!!.21}
    Dec(Connect.Count);                               {!!.21}
    if CloseMessagePipe(Connect,Result) <> 0 then
      Terminate('Error closing message pipes',85);
  end;
end;

procedure NetWareFindReceiver;

var
  Conn             : Byte;

begin
  if NetWareAutoFind then begin
    Conn := BroadcastPresence;
  end
  else begin
    if UserName = '' then begin
      Write('Enter name of user to send file to: ');
      ReadLn(UserName);
      if UserName = '' then Terminate('No user name specified',97);
    end;

    {search up to the maximum number of connections for UserName}
    with DefaultServerInfo do
      Conn := GetConnFromName(1,MaxConns,UserName);

    if Conn = 0 then
      Terminate(UserName+' not currently logged on to any connections',6);

    WriteLn(UserName,' is logged on to connection number ',Conn);
  end;

  GetInternetAddress(Conn,Receiver);
end;

function ListenPool(Event : WinSPXRec; var PoolIndex : Byte;
                    var DataPointer : Pointer) : Byte;
var
  DT : Byte;
  RetCode : Byte;

begin
  with Event, wsrP^ do begin
    repeat
      if PoolRec.prP^.QueueOverflow then
        Terminate('SPX Pool Queue Overflow',55);
      IPXRelinquish;
      CheckForUserBreak;
    until SPXListenPooled(Event,RetCode,PoolIndex,DT,DataPointer);
    ListenPool := RetCode;
  end;
end;

procedure InterruptsOn;
Inline(
  $FB);                  {sti}

procedure InterruptsOff;
Inline(
  $FA);                  {cli}

procedure NetWareOpenSession;
var
  Num              : Byte;
  RetCode          : Byte;
  PoolIndex        : Byte;
  DataP            : Pointer;

begin
  NetWareFindReceiver;
  {Receiver.Socket := RecSessionSocket;} {!!.41}
  RetCode :=
  SPXEstablishConn(XmitRec, Receiver, SessionSocket, FALSE, 512, NumberECBs, SendESR);
  if WaitForSPX(XmitRec) = 0 then
    SessionCreated := TRUE
  else begin
    WriteLn('SPXEstablishConn = ',XmitRec.wsrP^.ECB.ECBP^.CompletionCode);
    Terminate('Unable to establish SPX connection',3);
  end;

end;

procedure NetWareCloseSession;

begin
  SPXAbortConn(XmitRec);                              {!!.21}
  SessionCreated := False;
end;

procedure NetWareTransmit(var F : File);

var
  NumBlocksGoing   : Word;
  Count,NumRead    : Word;
  FSize            : LongInt;
  XFerOK           : Boolean;
  ECBCounter       : Byte;

begin
  FSize := FileSize(F);
  if IOResult <> 0 then
    Terminate('Error getting size of file',4);

  {calculate the total number of blocks to send}
  NumBlocksGoing := Word((FSize + SizeOf(XmitData) - 1) DIV
                    LongInt(SizeOf(XmitData)));

  Count   := 0;
  XFerOK  := TRUE;
  ECBCounter := 0;
  repeat
    with XmitPacket, nwmP^ do begin
      if Count <> 0 then begin
        CacheBlockRead(F,Cache,Txt,SizeOf(XmitData),NumRead);
        if CacheIOResult <> 0 then
          Terminate('Error reading file',5);
        TxtLength := NumRead;
      end
      else begin
        TxtLength := SizeOf(Word);
        Move(NumBlocksGoing,Txt,SizeOf(Word));
        if Verbose then
          WriteLn('Number of packets going = ',NumBlocksGoing);
      end;

      SPXSend(XmitRec,FALSE,1,TxtLength+SizeOf(Word),XmitPacket.nwmR);

      XFerOK := WaitForSPX(XmitRec) = 0;
      Inc(Count);
    end;
  until CacheEOF(F,Cache) or (not XFerOK);
  if not XFerOK then
    WriteLn('Error in file transfer ',XmitRec.wsrP^.ECB.ECBP^.CompletionCode);
end;

procedure NetWareInformNumOfFiles;

begin
  with Arguments do begin
    WriteLn('Sending ',NArgs,' files');
    Move(NArgs, Scratch.wsP^, SizeOf(NArgs));
    SPXSend(XmitRec,FALSE,1,SizeOf(Word),Scratch.wsR);
  end;
  if WaitForSPX(XmitRec) <> 0 then
    Terminate('Error sending number of files',91);
end;

function NetWareInform(Name : PathName) : Boolean;

var
  DataP            : Pointer;
  PoolIndex        : Byte;
  RetCode          : Byte;
  OKRec            : record
                       OK : Boolean;
                       NumECBs : Word;
                     end;

begin
  Scratch.wsP^ := JustFileName(Name);
  if Verbose then
    Write('Sending file name...');
  SPXSend(XmitRec,FALSE,1,Length(Scratch.wsP^)+1,Scratch.wsR);

  if WaitForSPX(XmitRec) <> 0 then
    Terminate('Error sending number of files',91);

  RetCode := ListenPool(XmitRec,PoolIndex,DataP);
  if  RetCode <> 0 then
    Terminate('Error listening for acknowledgment from receiver',91);

  Move(DataP^,OKRec,SizeOf(OKRec));

  with OKRec do begin
    NetWareInform := OK;
    ReceiversECBs := NumECBs;
  end;

  if Verbose then begin
    if OKRec.OK then
      WriteLn('Copy accepted by receiver')
    else
      WriteLn('Copy declined by receiver');
    WriteLn('Receiver has ',ReceiversECBs,' available');
  end;

  SPXReplenishPool(XmitRec,PoolIndex);
end;

procedure CopyFile(FName : PathName);
{get the file name to send from user if it wasn't specified on the command  }
{line, open it, call transmit, and close it. Aborts if file is not found.}

var
  F                : File;

begin

  {open the file to send}
  Assign(F,FName);
  Reset(F,1);
  if IOResult <> 0 then
    Terminate(FName + ' not found',3);

  WriteLn('transferring ',FName,'...');

  if UsingNetBios then begin
    if NetBiosInform(FName) then
      NetBiosTransmit(F)     {Use NetBIOS session services to send file}
    else
      WriteLn(FName,
             ' not sent (remote user opted not to overwrite existing file)');
  end
  else begin
    if NetWareInform(FName) then
      NetWareTransmit(F)    {Use NetWare SPX services to send file}
    else
      WriteLn(FName,
             ' not sent (remote user opted not to overwrite existing file)');
  end;
  Close(F);
  if IOResult <> 0 then ;
end;

procedure OurExitProc; Far;
{If using NetBIOS then hang up Session if it was created. If the session
name was added, then delete it. If using NetWare, then simply abort the
connection}

begin
  ExitProc := SavExitProc;    {reset ExitProc to original ExitProc}

  if UsingNetBios then begin
    {using NetBIOS, so delete the session and name (if they were created)}
    if OurNCB.NP^.CmdComplete = $FF then
      if CancelRequest(OurNCB) = 0 then ;
    if SessionCreated then
      if NetBiosHangUp(SessionLSN) <> NBESUCCESS then ;
    if SessionNameCreated then
      if NetBiosDeleteName(SendSessName) <> NBESUCCESS then ;
  end else begin
    {using NetWare services, so abort the connection}
    if SessionCreated then begin
      SPXAbortConn(XmitRec);
    end;
    if NetWareAutoFind then
      FlushPipes;
  end;
  if WinStringAllocated then
    FreeWinString(Scratch);
  if NetWareAllocated then
    FreeWinNetWareMsg(XmitPacket);
  if NetBIOSAllocated then
    FreeWinNetBIOSMsg(XmitBlock);
  if NCBAllocated then
    FreeWinNCB(OurNCB);
  if ECBAllocated then
    FreeWinSPXRec(XmitRec);
  if SendESRAllocated then
    FreeWindowsESR(SendESR);
  if RecESRAllocated then
    FreeWindowsESR(ReceiveESR);
end;

procedure AllocateMemory;
  {-Allocates the real mode memory needed for sessions or SPX}
begin
  if AllocateWinString(SizeOf(String) - 1, Scratch) then
    WinStringAllocated := True
  else
    Terminate('Unable to allocate real mode memory (for string)',NoRealMem);
  if UsingNetBIOS then begin
    if AllocateWinNetBIOSMsg(XmitBlock) then
      NetBIOSAllocated := True
    else
      Terminate('Unable to allocate real mode memory (for NetBIOS)',NoRealMem);
    if AllocateWinNCB(OurNCB) then
      NCBAllocated := True
    else
      Terminate('Unable to allocate real mode memory (for NCB)',NoRealMem);
    FillChar(WinPost, SizeOf(WinPost), 0);
  end
  else begin
    if AllocateWinSPXRec(XmitRec) then
      ECBAllocated := True
    else
      Terminate('Unable to allocate real mode memory (for WinSPXRec)',NoRealMem);
    if AllocateWinNetWareMsg(XmitPacket) then
      NetWareAllocated := True
    else
      Terminate('Unable to allocate real mode memory (for SPX)',NoRealMem);
    if AllocateWindowsESR(NoESR, DSeg, SendESR) then
      SendESRAllocated := True
    else
      Terminate('Unable to allocate real mode callback (for SendESR)',NoRealMem);
    if AllocateWindowsESR(NoESR, DSeg, ReceiveESR) then
      RecESRAllocated := True
    else
      Terminate('Unable to allocate real mode callback (for ReceiveESR)',NoRealMem);
  end;
end;

procedure ShowHelp;
{Display help screen for this program.  This screen is displayed by running
 NSENDW /?
}
begin
  WriteLn;
  WriteLn('NSENDW /W /A /V /B /Rxxx /Uusername FileName');
  WriteLn;
  WriteLn('all parameters are optional');
  WriteLn;
  WriteLn('where:');
  WriteLn(' /W         = use NetWare''s SPX');
  WriteLn(
  ' /Uusername = specifies the user name to send to (valid for NetWare only)');
  WriteLn(' /A         = Find receiver automatically (valid for NetWare only)');
  WriteLn(' /B         = use NetBIOS'' Session Services');
  WriteLn(' /V         = Verbose mode');
  WriteLn(
  ' /Rxxx      = Set connect retry count (xxx = number between 1..999)');
  WriteLn(' /?         = shows this help screen');
  Halt
end;

function ExtractWordParam(Param : String80) : Word;

var
  W                : Word;
  Code             : Integer;

begin
  Param := Copy(Param,3,Length(Param));
  Val(Param,W,Code);
  if Code = 0 then
    ExtractWordParam := W
  else
    ExtractWordParam := 0;
end;

procedure InvalidParam(Param : String80);

begin
  WriteLn(Param,' is an invalid parameter');
end;

procedure EvaluateParams;
{examine the parameters on the command line. The program is run with the
 following command line syntax:
   NSENDW /W /B /Uusername FileName

   all parameters are optional

   where
     /B         = use NetBIOS' Session services
     /W         = use NetWare's SPX
     /A         = Automatically find receiver (valid for NetWare only)
     /Uusername = specifies the user name to send to (valid for NetWare only)
     /?         = shows help screen

}
var
  I                : Word;
  Len              : Word;
  Param            : String80;

begin
  FName := '';
  UserName := '';
  FillChar(Arguments,SizeOf(Arguments),0);

  for I := 1 to ParamCount do begin
    Param := ParamStr(I);
    if Param[1] in ['-','/'] then begin
      Len := Length(Param);
      if Len > 1 then begin
        case UpCase(Param[2]) of
          'W' : UsingNetBios := FALSE;
          'B' : UsingNetBios := TRUE;
          'U' : if Len > 2 then
                  UserName := Copy(Param,3,Len);
          'A' : NetWareAutoFind := TRUE;
          'V' : Verbose := TRUE;
          'R' : begin
                  ConnectRetries := ExtractWordParam(Param);
                  if ConnectRetries = 0 then
                    InvalidParam(Param);
                end;
          'H','?'
              : ShowHelp;
          else InvalidParam(Param);
        end
      end
      else
        InvalidParam(Param)
    end
    else
      ExpandArgs(Arguments,Param);
  end;
end;

procedure CheckForProperNetwork;
{This routine ensures that the network protocol that the user has requested
 (NetWare or NetBIOS) is available. If not, the program automatically adjusts
 to the other protocol. If neither protocol is found, then the program is
 aborted.}

var
  NetWareIsHere,
  NetBiosIsHere,
  Logged           : Boolean;
  M                : Word;

begin
  {Check for NetBIOS}
  NetBIOSIsHere := NetBIOSInstalled;

  {Check for Novell. For SPX services, we require that the netware shell be
   loaded, and the user logged on, Then a function call is made to ensure this
   version of NetWare supports SPX Services.}

  NetWareIsHere := NetWareLoaded(Logged);
  NetWareIsHere := NetWareIsHere and Logged;

  if NetWareIsHere then begin                                   {!!.21}
    if not (IPXServicesAvail and SPXServicesAvail(M,M,M)) then begin
      WriteLn('This version of NetWare does not support IPX/SPX services.');
      if not NetBIOSIsHere then begin
        WriteLn(
         'NetBIOS is not loaded, so no peer-to-peer protocol is available.');
        Halt;
      end;
    end;
    if NetWareAutoFind and IsNetWare3 then begin                {!!.21 begin}
      WriteLn('Autofind options not available under NetWare 3.0 or greater');
      Halt;
    end;
  end;                                                          {!!.21 end}

{Now make sure that the selected protocol is available, if not, try the}
  {other one, if it is not available either, then abort the program}
  if UsingNetBios then begin
    if not NetBiosIsHere then
      if NetWareIsHere then
        UsingNetBios := FALSE
      else
        Terminate('No network operating system detected',5);
  end
  else
    if (not NetWareIsHere) then
      if NetBiosIsHere then
        UsingNetBios := TRUE
      else
        Terminate('No network operating system detected',5);
end;

var
  ArgIndex         : Word;

begin
  CheckBreak := TRUE;

  WriteLn(
  'NSENDW    Copyright (c) 1989 by TurboPower Software    Version 5.41'^M^J);

  EvaluateParams;        {evaluate the command line parameters}

  CheckForProperNetwork; {check to make sure selected network exists}

  {set up our own exit procedure to hangup the session and delete the session}
  {name in the event of a fatal error.}
  SavExitProc := ExitProc;
  ExitProc := @OurExitProc;

  {Notify user which services will be used to send the file}
  if UsingNetBios then
    WriteLn('Using NetBIOS session services to send file...')
  else
    WriteLn('Using Advanced NetWare SPX services to send file');

  AllocateMemory;

  if UsingNetBios then
    NetBiosOpenSession   {add session name and create a session}
  else
    NetWareOpenSession;  {establish an SPX connection}


  {If no file name specified, then prompt for one}
  if Arguments.NArgs = 0 then begin
    Write('Enter file to send: ');
    ReadLn(FName);
    if FName = '' then Terminate('No file name specified',96);
    ExpandArgs(Arguments,FName);
  end;

  if Arguments.NArgs = 0 then
    Terminate('No file name specified',96);

  {Tell session partner how many files to expect}
  if UsingNetBios then
    NetBIOSInformNumOfFiles
  else begin
    NetWareInformNumOfFiles;
    AllocateCache(Cache,NetWareCacheSize);
  end;

  {send each file}
  with Arguments do
    for ArgIndex := 1 to NArgs do
      CopyFile(Args[ArgIndex]^);    {send the file to receiving station}

  {end the session}
  if UsingNetBios then
    NetBiosCloseSession  {hangup session and delete session name}
  else
    NetWareCloseSession; {terminate the SPX session}
end.
