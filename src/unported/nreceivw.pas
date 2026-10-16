{*********************************************************}
{*                  NRECEIVW.PAS 5.41                    *}
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

program Windows_Net_Receive;

uses
  {$IFDEF Windows}
  WinProcs,
  WinCrt,
  Strings,
  {$ELSE}
  Crt,
  {$ENDIF}
  WinDPMI,
  NetBios,
  NetWare;

const
  NoRealMem        = 1;
  MaxArgs          = 1024; { this number determines the maximum number    }
                           { of file names that can be held in the list.  }

  DefaultRetries   = 8;

  UsingNetBios     : Boolean  = FALSE;
  Verbose          : Boolean  = FALSE;
  OverwriteMode    : Boolean  = FALSE;
  UserPath         : PathName = '';
  ConnectRetries   : Word     = 0;

  SessionCreated   : Boolean  = FALSE;
  SessionNameCreated
                   : Boolean  = FALSE;

  {NetBIOS constants}

  {The session names}             {1234567890123456}
  SendSessName     : String[16] = 'NetBiosSend   '#88;
  RecSessName      : String[16] = 'NetBiosReceive'#88;

  {NetWare constants}
  SessionSocket    = $4746;   {!!.41}
  {RecSessionSocket = $4848;} {!!.41}
  NumberOfECBs     = 5;
  NetWareCacheSize = $8000;

  NetWareAutoFind  : Boolean  = FALSE;
  CacheIOResult    : Integer = 0;

  WinStringAllocated:Boolean = FALSE;
  ECBAllocated     : Boolean = FALSE;
  RecESRAllocated  : Boolean = FALSE;
  NetBIOSAllocated : Boolean = FALSE;
  NCBAllocated     : Boolean = FALSE;

  MaxNBBuf         = 2048;

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
  SessionBuf       = Array[1..MaxNBBuf] of Char;
  NetBIOSMsg       = record                     {the session data packet}
                       TxtLength : Word;        {length of data in Txt}
                       Txt       : SessionBuf;  {the data}
                     end;
  NetBiosMsgPtr    = ^NetBIOSMsg;
  WinNetBIOSMsg    = record
                       nbmR, nbmP : NetBIOSMsgPtr;
                     end;

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
  SavExitProc      : Pointer;
  Arguments        : ArgumentType;
  NumFilesComing   : Word;
  FName            : PathName;
  Scratch          : WinString;

  {NetBIOS variables}
  SessionLSN       : Byte;
  XmitBlock        : WinNetBiosMsg;
  OurNCB           : WinNCB;
  WinPost          : WinPostType;

  {NetWare variables}
  XmitRec          : WinSPXRec;
  Receiver         : IPXAddress;
  UserName         : String;
  Cache            : FileCache;
  NumListening     : Byte;
  ReceiveESR       : WinESRType;

procedure Terminate(S : String; ErrorLevel : Word);
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
  {$IFDEF Windows}
  Yield;
  {$ENDIF}
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
  end;
end;

procedure CacheBlockWrite(var F : File; var Cache : FileCache;
                          var Buf; Size : Word);

begin

  with Cache do begin
    if CachePos + Size - 1 > CacheSize then begin
      BlockWrite(F,CacheBuf^,CachePos-1);
      CacheIOResult := IOResult;
      CachePos := 1;
    end;
    Move(Buf,CacheBuf^[CachePos],Size);
    CachePos := CachePos + Size;
  end;
end;

procedure FlushCache(var F : File; var Cache : FileCache);

begin

  with Cache do begin
    if CachePos > 1 then begin
      BlockWrite(F,CacheBuf^,CachePos-1);
      CacheIOResult := IOResult;
    end;
    CachePos := 1;
  end;
end;

function MakeFileName(P, F : PathName) : PathName;
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

var
  Ret              : Byte;
  Num              : Byte;
  RetryCount       : Word;

begin
  ClearNCB(OurNCB.NP^);
  if NetBiosAddName(RecSessName,Num) <> NBESUCCESS then
    Terminate('Can not create session.',1)
  else
    SessionNameCreated := TRUE;

  if ConnectRetries = 0 then
    ConnectRetries := DefaultRetries;
  RetryCount := 0;

  while (not SessionCreated) and (RetryCount <= ConnectRetries) do begin
    (*****delay*****)
    Inc(RetryCount);
    NetBiosListenNoWait(SendSessName,RecSessName,10,10,WinPost,OurNCB);
    {wait until command is complete or user wants out}
    while not NetBiosCmdCompleted(OurNCB,Ret) do
      CheckForUserBreak;

    if Ret =  NBESUCCESS then begin
      SessionLSN := OurNCB.NP^.LSN;
      SessionCreated := TRUE;
    end
    else begin
      WriteLn('Attempt number ',RetryCount,' was unsuccessful');
      CheckForUserBreak;
    end;
  end;
  if not SessionCreated then
    Terminate('Unable to establish communication with sending station',2)
end;

procedure NetBiosCloseSession;

begin
  if SessionCreated then
    if NetBiosHangUp(SessionLSN) <> NBESUCCESS then ;
  if NetBiosDeleteName(RecSessName) <> NBESUCCESS then
    Terminate('Error deleting session name (CloseSession)',4);
  SessionNameCreated := FALSE;
end;

procedure NBReceive(var F : File);

var
  Count            : Word;
  NumBlocksComing  : Word;
  Continue         : Boolean;
  Ret              : Byte;

begin
  Continue := True;
  Count    := 0;
  while Continue do begin
    Ret := NetBiosReceive(SessionLSN,SizeOf(XmitBlock.nbmP^),XmitBlock.nbmR);
    if Ret = 0 then begin
      with XmitBlock, nbmP^ do begin
        if Count = 0 then begin
          Move(Txt,NumBlocksComing,SizeOf(Word));
          Continue := NumBlocksComing > 0;
        end
        else begin
          if Count = NumBlocksComing then
            Continue := FALSE;
          if TxtLength > 0 then begin
            BlockWrite(F,Txt,TxtLength);
            if IOResult <> 0 then
              Terminate('Error writing file',5);
          end;
        end;

      end;
    end
    else begin
      WriteLn('Receive error ',Ret);
      Continue := FALSE;
    end;
    Inc(Count);
  end;
end;

procedure NetBIOSBeInformed(First : Boolean);

var
  Ret              : Byte;

begin
  if First then begin
    {get number of files to expect}
    Ret := NetBiosReceive(SessionLSN,SizeOf(Word),Scratch.wsR);
    if Ret <> NBESUCCESS then
      Terminate('Receive error returned by NetBios',6);
    Move(Scratch.wsP^, NumFilesComing, SizeOf(NumFilesComing));
  end
  else begin
    {get next file name}
    Ret := NetBiosReceive(SessionLSN,SizeOf(FName),Scratch.wsR);
    if Ret <> NBESUCCESS then
      Terminate('Receive error in NetBIOSBeInformed',6);
    FName := Scratch.wsP^;
  end;
end;

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
  Write('Attempting to AutoFind Sender');
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
        if (Result.List[I] = 0) then begin
          Inc(Count);
          List[Count] := I;
        end;
      end;
      Conn := 0;
      Notified := FALSE;
      if Count > 0 then begin
        ListenCount := 0;
        while (ListenCount < ListenAttempts) and (not Notified) do begin
          GetMessagePipe(Conn,InMsg);
          Notified := InMsg = SendStr;
          InMsg := '';
          Inc(ListenCount);
          CheckForUserBreak;
        end;
        if Notified then
          SendMessagePipe(ReceiveStr,Connect,Result);
      end;
    end;
    CheckForUserBreak;
    if Conn = 0 then
      (******Delay(DelayValue)****);
    Inc(TryCount);
  until (Notified) or (Conn <> 0) or (TryCount >= NumAttempts);
  if Conn = 0 then
    Terminate('AutoFind unable to contact receiver',84)
  else
    WriteLn(^M^J,'Found sender at connection ',Conn);
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
      Write('Enter name of user to receive file from: ');
      ReadLn(UserName);
      if UserName = '' then Terminate('No user name specified',97);
    end;
    Conn := GetConnFromName(1,255,UserName);
    if Conn = 0 then
      Terminate(UserName+' not currently logged on to any connections',6);

    WriteLn(UserName,' is logged on to connection number ',Conn);
  end;
  GetInternetAddress(Conn,Receiver);
end;

procedure GetConnIDFromRemote(var Event, NewEvent : WinSPXRec);

var
  DataP : Pointer;
  RetCode : Byte;
  PoolIndex : Byte;
  DT : Byte;

begin
  NewEvent := Event;
  NewEvent.wsrP^.ConnID := Event.wsrP^.ConnID;
  NewEvent.wsrP^.SPXHead := Event.wsrP^.SPXHead;
  NewEvent.wsrP^.ECB.ECBP^ := Event.wsrP^.ECB.ECBP^;

  with Event do begin
    repeat
      CheckForUserBreak;
    until SPXListenPooled(Event,RetCode,PoolIndex,DT,DataP);
    if RetCode = 0 then
      NewEvent.wsrP^.ConnID := Word(DataP^)
    else
      Terminate('Error listening for SPX Connection ID',60);
  end;

  SPXReplenishPool(Event,PoolIndex);

  SPXReplenishAll(Event);
  SPXReplenishAll(NewEvent);
end;

procedure NetWareOpenSession;
var
  Num              : Byte;
  RetCode          : Byte;
  TempA            : IPXAddress;
  TempC            : Word;

begin
  NetWareFindReceiver;
  {Receiver.Socket := SessionSocket;} {!!.41}
  RetCode := SPXListenForConn(XmitRec,SessionSocket,FALSE, {!!.41}
                              SizeOf(NetWareMsg),NumberOfECBs,ReceiveESR);

  if WaitForSPX(XmitRec) = 0 then
    SessionCreated := TRUE
  else
    Terminate('Unable to establish SPX connection',3);

  XmitRec.wsrP^.ConnID := Word(XmitRec.wsrP^.ECB.ECBP^.IPXWorkspace);
  if Verbose then
    WriteLn('Connection ID = ',XmitRec.wsrP^.ConnID);
end;

procedure NetWareCloseSession;
begin
  SPXTerminateConn(XmitRec);
  SessionCreated := False;
end;

function ListenPools(var Event : WinSPXRec; var PoolIndex : Byte;
                     var DataPointer : Pointer) : Byte;

var
  DT : Byte;
  RetCode : Byte;

begin
  repeat
    if Event.wsrP^.PoolRec.prP^.QueueOverflow then
      Terminate('SPX Pool Queue Overflow',55);
    IPXRelinquish;
    CheckForUserBreak;
  until SPXListenPooled(Event,RetCode,PoolIndex,DT,DataPointer);
  ListenPools := RetCode;
end;

procedure SendNumListeningECBs;

var
  Ret              : Byte;

begin
  NumListening := SPXListenCount(XmitRec);
  Move(NumListening, Scratch.wsP^, SizeOf(NumListening));
  SPXSend(XmitRec,FALSE,1,SizeOf(NumListening),Scratch.wsR);
  if WaitForSPX(XmitRec) <> 0 then begin
    WriteLn('XmitRec.ECB.CompletionCode = ',XmitRec.wsrP^.ECB.ECBP^.CompletionCode);
    Terminate('Error sending number of free ECBs',79);
  end;
end;

procedure NetWareReceive(var F : File);

var
  Count            : Word;
  NumBlocksComing  : Word;
  DataP            : Pointer;
  PoolIndex        : Byte;
  Continue         : Boolean;
  ECBCounter       : Byte;
  RetCode          : Byte;

begin
  Continue := True;
  Count    := 0;
  ECBCounter := 0;
  while Continue do begin
    RetCode := ListenPools(XmitRec,PoolIndex,DataP);
    if RetCode = 0 then begin
      with NetWareMsg(DataP^) do begin
        if Count = 0 then begin
          Move(Txt,NumBlocksComing,SizeOf(Word));
          Continue := NumBlocksComing > 0;
          if Verbose then
            WriteLn('NumBlocksComing = ',NumBlocksComing);
        end
        else begin
          if Count = NumBlocksComing then
            Continue := FALSE;
          CacheBlockWrite(F,Cache,Txt,TxtLength);
          if CacheIOResult <> 0 then
            Terminate('Error writing file',5);
        end;
        SPXReplenishPool(XmitRec,PoolIndex);
(*
        SPXReplenishAll(XmitRec);
*)
      end;
    end
    else begin
      WriteLn('Receive error ',RetCode);
      Continue := FALSE;
    end;
    Inc(Count);
  end;
  FlushCache(F,Cache);
  if CacheIOResult <> 0 then
    Terminate('Error flushing cache',5);
end;

procedure NetWareBeInformed(First : Boolean);

var
  PoolIndex        : Byte;
  RetCode          : Byte;
  DataP            : Pointer;
  NetData          : record
                       NumF : Word;
                       NumP : Byte;
                     end;
begin
  RetCode := ListenPools(XmitRec,PoolIndex,DataP);
  if RetCode = 0 then begin
    if First then begin
      Move(DataP^,
           NumFilesComing,SizeOf(Word));
    end
    else begin
      Move(DataP^,FName,SizeOf(FName));
      if Verbose then WriteLn('FName = ',FName);
    end;
  end
  else begin
    WriteLn('ECB.CompletionCode = ',RetCode);
    Terminate('Error in NetWareBeInformed',91);
  end;

  SPXReplenishPool(XmitRec,PoolIndex);
end;

procedure Acknowledge(Positive : Boolean);

var
  OKRec            : record
                       OK : Boolean;
                       NumListen : Byte;
                     end;

  Ret              : Byte;

begin
  with OKRec do
    OK := Positive;
  if UsingNetBIOS then begin
    Move(OKRec.OK, Scratch.wsP^, SizeOf(Boolean));
    Ret := NetBiosSend(SessionLSN,SizeOf(Boolean),Scratch.wsR);
    if Ret <> 0 then
      Terminate('Error attempting to acknowledge receipt of file name',89);
  end
  else begin
    NumListening := SPXListenCount(XmitRec);
    with OKRec do
      NumListen := NumListening;

    if Verbose then
      WriteLn('Informing sender ',NumListening,' ECBs available');
    Move(OKRec, Scratch.wsP^, SizeOf(OKRec));
    SPXSend(XmitRec,FALSE,1,SizeOf(OKRec),Scratch.wsR);
    if WaitForSPX(XmitRec) <> 0 then begin
      WriteLn('XmitRec.ECB.CompletionCode = ',XmitRec.wsrP^.ECB.ECBP^.CompletionCode);
      Terminate('Error attempting to acknowledge receipt of file name',89);
    end;
    if Verbose then
      WriteLn('sender informed');
  end;
end;


function Overwrite(FName : PathName) : Boolean;

var
  Ch               : Char;

begin
  if OverwriteMode then
    Overwrite := TRUE
  else begin
    Write(FName,' already exists, overwrite? ');
    repeat
      Ch := UpCase(ReadKey);
    until Ch in ['Y','N'];
    WriteLn(Ch);
    Overwrite := Ch = 'Y';
  end;
end;

procedure CopyFile;

var
  F                : File;

begin
  if UsingNetBios then
    NetBIOSBeInformed(FALSE)
  else
    NetWareBeInformed(FALSE);

  if FName = '' then
    Terminate('No file name specified',93);

  FName := MakeFileName(UserPath,FName);

  Assign(F,FName);
  Reset(F,1);

  if (IOResult = 0) then begin
    Close(F);
    if IOResult <> 0 then ;
    if Overwrite(FName) then
      Acknowledge(TRUE)
    else begin
      Acknowledge(FALSE);
      Exit;
    end;
  end
  else
    Acknowledge(TRUE);

  Rewrite(F,1);
  if IOResult <> 0 then
    Terminate('Can not create ' + FName,3);

  if Verbose then
    WriteLn('Beginning transfer of ',FName);

  if UsingNetBios then
    NBReceive(F)
  else
    NetWareReceive(F);

  Close(F);
  if IOResult <> 0 then ;
  WriteLn(FName,' received');
end;

procedure AllocateMemory;
  {-Allocates the real mode memory needed for sessions or SPX}
begin
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
    if AllocateWindowsESR(NoESR, DSeg, ReceiveESR) then
      RecESRAllocated := True
    else
      Terminate('Unable to allocate real mode callback (for ReceiveESR)',NoRealMem);
    if AllocateWinSPXRec(XmitRec) then
      ECBAllocated := True
    else
      Terminate('Unable to allocate real mode memory (for WinSPXRec)',NoRealMem);
  end;
  if AllocateWinString(SizeOf(String) - 1, Scratch) then
    WinStringAllocated := True
  else
    Terminate('Unable to allocate real mode memory (for string)',NoRealMem);
end;

procedure OurExitProc; Far;
{Clean up on error}
begin
  ExitProc := SavExitProc;
  if UsingNetBios then begin
    if OurNCB.NP^.CmdComplete = $FF then
      if CancelRequest(OurNCB) = 0 then ;
    if SessionCreated then
      if NetBiosHangUp(SessionLSN) <> NBESUCCESS then ;
    if SessionNameCreated then
      if NetBiosDeleteName(RecSessName) <> NBESUCCESS then ;
  end
  else begin
    if SessionCreated then begin
      SPXAbortConn(XmitRec);
    end;
    if NetWareAutoFind then
      FlushPipes;     {clear any messages left in the pipe}
  end;
  if WinStringAllocated then
    FreeWinString(Scratch);
  if NetBIOSAllocated then
    FreeWinNetBIOSMsg(XmitBlock);
  if NCBAllocated then
    FreeWinNCB(OurNCB);
  if ECBAllocated then
    FreeWinSPXRec(XmitRec);
  if RecESRAllocated then
    FreeWindowsESR(ReceiveESR);
end;

procedure ShowHelp;
{Display help screen for this program.  This screen is displayed by running
 NRECEIVW /?
}
begin
  WriteLn;
  WriteLn('NRECEIVW /W /A /V /B /Rxxx /Uusername /O');
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
  ' /O         = Overwrite mode (replaces existing files without asking)');
  WriteLn(
  ' /Rxxx      = Set connect retry count (xxx = number between 1..999)');
  WriteLn(
  ' /Dpathname = specifies the drive and/or directory to store the files');
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
   NSEND /W /B /Uusername

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
          'D' : if Len > 2 then
                  UserPath := UpperString(Copy(Param,3,Len));
          'A' : NetWareAutoFind := TRUE;
          'V' : Verbose := TRUE;
          'O' : OverwriteMode := TRUE;
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
      InvalidParam(Param)
  end;
end;

procedure CheckForProperNetwork;

var
  NetWareIsHere,
  NetBiosIsHere,
  Logged           : Boolean;
  M                : Word;

begin
  NetBIOSIsHere := NetBIOSInstalled;
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
  Index            : Word;

begin
  CheckBreak := TRUE;

  WriteLn(
  'NRECEIVW   Copyright (c) 1989 by TurboPower Software    Version 5.41'^M^J);

  EvaluateParams;

  CheckForProperNetwork;

  SavExitProc := ExitProc;
  ExitProc := @OurExitProc;

  if UsingNetBios then
    WriteLn('Using NetBIOS session services to receive file...')
  else
    WriteLn('Using Advanced NetWare SPX services to receive file');

  AllocateMemory;

  if UsingNetBios then
    NetBiosOpenSession   {add session name and create a session}
  else
    NetWareOpenSession;

  if UsingNetBIOS then
    NetBIOSBeInformed(TRUE)
  else begin
    NetWareBeInformed(TRUE);
    AllocateCache(Cache,NetWareCacheSize);
  end;

  WriteLn('Preparing to receive ',NumFilesComing,' files...');
  {$IFNDEF Windows}
  Delay(100);
  {$ENDIF}
  for Index := 1 to NumFilesComing do
    CopyFile;      {send the file to receiving station}

  if UsingNetBios then
    NetBiosCloseSession  {hangup session and delete session name}
  else
    NetWareCloseSession;
end.
