{--Conditional defines and compiler options}
  {$I BTDefine.Inc}
  {$F-,V-,B-,S-,I-,R-}
  {$IFDEF CanSetOvrflowCheck}
    {$Q-}
  {$ENDIF}

program ExampleMessages;
{
  This program is meant as an example of the various different messaging and
  packet exchange facilities available in the NetWare and NetBIOS units.

  The sending side runs this program with no command line parameters.  The
  receiving side must specify a parameter on the command line.

  Note how an ExitProc is set up to "undo" the changes to the envirornment
  made by this program in the event of fatal runtime error or user abort.

  This program will check to see if Novell's NetWare and/or a NetBIOS
  compatible operating system are present. The program will then use each of
  the message services available.

  This program also contains an SPX Event Service Routine. Event Service
  Routines are in essence hardware interrupt service routines that get control
  immediately when an IPX/SPX event occurs. The SPX routines in the NetWare
  unit allow a Pascal ESR to be specified for use by the Listen ECB Pool. The
  procedure OurPascalESR is such a routine.
}

uses
  {$IFDEF Windows}
  WinCrt,
  {$ELSE}
  Crt,
  {$ENDIF}
  NetWare, {Services for Novell's NetWare}
  NetBIOS; {Services for NetBIOS}

const
  {NetBIOS const}
  ExampleRec       : NBNameStr = 'ExampleRec*****';
  ExampleSend      : NBNameStr = 'ExampleSend****';

  {Use of Broadcast Datagrams is on by default.  However, Novell's NetBIOS}
  {emulator does not implement these functions, so this program will}
  {automatically set this to FALSE if NetWare is detected.}
  BroadcastDatagrams : Boolean = TRUE;
  SPXConnEstablished : Boolean = False;              {!!.22}

  {NetWare const}
  SPXSessionSocket = $7000;   {the socket for the SPX session}
  IPXSessionSocket = $7001;   {the socket for the IPX exchange}

var
  NetWareIsHere,Logged,
  UsingIPXSPX,
  NetBIOSIsHere    : Boolean;

  {NetWare vars}
  TryConnect       : ConnectionList;
  Connect          : ConnectionList;
  Result           : ConnectionList;
  Receiver,Sender  : IPXAddress;
  {$IFDEF DPMIOrWnd}
  SEvent           : WinSPXRec;
  IEvent           : WinIPXRec;
  {$ELSE}
  SEvent           : SPXRec;
  IEvent           : IPXRec;
  {$ENDIF}

  {NetBIOS vars}
  SaveExitProc     : Pointer;
  NameNum          : Byte;
  SessionLSN       : Byte;
  {$IFDEF DPMIOrWnd}
  OurNCB           : WinNCB;
  Post             : WinPostType;
  {$ELSE}
  OurNCB           : NCB;
  {$ENDIF}

procedure GetConnections(Prompt : String;
                         var Connect : ConnectionList;
                         var TargetName : String);
{Get all the connections which have TargetName Logged In}
begin
  Write(Prompt);
  ReadLn(TargetName);
  GetObjConnNumbers(TargetName,ObjUser,Connect);
end;

function UserBreak : Boolean;
{Abort if Keypressed}
begin
  if UsingIPXSPX then
    IPXRelinquish;
  if Keypressed then begin
    if ReadKey = #0 then ;
    UserBreak := True;                {!!.20}
  end
  else
    UserBreak := FALSE;
end;

function ConnectedWithSomeOne(var TryConnect,Result,
                              Connected : ConnectionList) : Boolean;
{Return TRUE if a message pipe was successfully opened with any node}

var
  I : Word;

begin
  Connected.Count := 0;
  with Result do
    for I := 1 to Count do
      {For each entry with 0 as a Result code, add it to Connected}
      if List[I] = 0 then begin
        Inc(Connected.Count);
        Connected.List[Connected.Count] := TryConnect.List[I];
      end;
  ConnectedWithSomeone := Connected.Count <> 0; {return true if at least one}
                                                {pipe opened}
end;

{$IFDEF DPMIOrWnd}
function WaitForIPX(Rec : WinIPXRec) : Byte;
{$ELSE}
function WaitForIPX(var Rec : IPXRec) : Byte;
{$ENDIF}
{Wait for the completion of an IPX event, return CompletionCode as function
 result.  Check for userbreak and abort if KeyPressed.}
var
  Ret : Byte;                                        {!!.21}
begin
  {$IFDEF DPMIOrWnd}
  while Rec.wirP^.ECB.InUse <> 0 do begin
  {$ELSE}
  while Rec.ECB.InUse <> 0 do begin
  {$ENDIF}
    IPXRelinquish;
    if UserBreak then begin                          {!!.21}
      Ret := IpxCancelEvent(Rec);                    {!!.21}
      WriteLn('User cancelled IPX event');           {!!.21}
      {$IFDEF DPMIOrWnd}
      WaitForIPX := Rec.wirP^.ECB.CompletionCode;
      {$ELSE}
      WaitForIPX := Rec.ECB.CompletionCode;          {!!.21}
      {$ENDIF}
      Exit;                                          {!!.21}
    end;                                             {!!.21}
  end;
  {$IFDEF DPMIOrWnd}
  WaitForIPX := Rec.wirP^.ECB.CompletionCode;
  {$ELSE}
  WaitForIPX := Rec.ECB.CompletionCode;
  {$ENDIF}
end;

{$IFDEF DPMIOrWnd}
function WaitForSPX(Rec : WinSPXRec) : Byte;
{$ELSE}
function WaitForSPX(var Rec : SPXRec) : Byte;
{$ENDIF}
{Wait for the completion of an SPX event, return CompletionCode as function
 result.  Check for userbreak and abort if KeyPressed.}
begin
  {$IFDEF DPMIOrWnd}
  while Rec.wsrP^.ECB.ECBP^.InUse <> 0 do begin
  {$ELSE}
  while Rec.ECB.InUse <> 0 do begin
  {$ENDIF}
    IPXRelinquish;
    if UserBreak then begin                          {!!.21}
      WriteLn('User cancelled SPX event');           {!!.21}
      {$IFDEF DPMIOrWnd}
      WaitForSPX := Rec.wsrP^.ECB.ECBP^.CompletionCode;
      {$ELSE}
      WaitForSPX := Rec.ECB.CompletionCode;          {!!.21}
      {$ENDIF}
      Exit;                                          {!!.21}
    end;                                             {!!.21}
  end;
  {$IFDEF DPMIOrWnd}
  WaitForSPX := Rec.wsrP^.ECB.ECBP^.CompletionCode;
  {$ELSE}
  WaitForSPX := Rec.ECB.CompletionCode;
  {$ENDIF}
end;

{These are declared as static}
const
  IPXMsg           : String[30] = 'IPX is good, clean fun!';
  SPXMsg           : String[30] = 'SPX services are awesome!';

procedure IPXSPXSendDemo;
{Demonstrate SPX and IPX services}
var
  Ret : Byte;

begin
  if not UsingIPXSPX then
    Exit;
  GetInternetAddress(TryConnect.List[1],Receiver);

(*
  Ret := SPXEstablishConn(SEvent,Receiver,SPXSessionSocket,FALSE,512,2,NIL);
  if (Ret <> 0) or (WaitForSPX(SEvent) <> 0) then begin
    WriteLn('Error establishing SPX connection');
    Exit;
  end;
  SPXConnEstablished := True;                        {!!.22}
  SPXSend(SEvent,FALSE,1,Length(SPXMsg)+1,SPXMsg);
  if WaitForSPX(SEvent) = 0 then
    WriteLn('<',SPXMsg,'> send to receiver')
  else
    WriteLn('SPXSend error sending packet to receiver');
*)
  Receiver.Socket := IPXSessionSocket;
  {$IFDEF DPMIOrWnd}
  if not AllocateWinIPXRec(SizeOf(IPXMsg), IEvent) then begin     {!!.40}
    WriteLn('Unable to allocate IPXRec');
    Exit;
  end;
  {$ENDIF}
  Ret := IPXSend(IEvent,Receiver,IPXSessionSocket,FALSE,
                 Length(IPXMsg)+1,IPXMsg);

  if (Ret <> 0) or (WaitForIPX(IEvent) <> 0) then
    WriteLn('Error sending IPX packet');
  {$IFDEF DPMIOrWnd}
  FreeWinIpxRec(IEvent);                                          {!!.40}
  {$ENDIF}
end;

{$F+}
{$S-,R-} {these MUST ALWAYS be off for an ESR}
procedure OurPascalESR(var Event : SPXRec; RetCode : Byte;
                       PoolIndex : Byte;
                       DataType : Byte;
                       DataP : Pointer);
{This is a sample ESR. In general, an ESR should return very quickly. Since
this one does not return quickly, interrupts are enabled.

In a real program, the ESR would need to be somewhat more sophisticated. The
first item of business would be to process or queue the event. Since the state
of the system is unknown at the time the ESR is called (whether DOS is busy or
how much stack is available), the event is usually queued rather than
processed. After queueing the event (or processing it), you must resubmit this
pool index for listening using SPXReplenishPool.

NOTE: If you are queueing the event for later processing, it is important to
copy any data to the queue, as opposed to just passing a pointer to it. This
is necessary because the ECB associated with this PoolIndex is being
resubmitted, meaning if another event comes in on this ECB before you get
around to processing the last event, the last event's data will be lost.
}
var
  I,II : Word;

begin
  {** process or queue event **}
  {** SPXReplenishPool(Event, PoolIndex) **}

  Inline($FB); {STI ; enable interrupts because we stay here too long...}

  {Make a silly sound}
  {$IFNDEF Windows}
  for I := 1 to 1000 do begin
    Sound(I);
    for II := 1 to 80 do ; {NOTE: We can't call Delay here, so we use a loop}
  end;
  NoSound;
  {$ENDIF}
end;
{$F-}
{$S+,R+}

procedure IPXSPXReceiveDemo;
{Demonstrate SPX and IPX services}

var
  PoolIndex : Byte;
  SPXRetCode : Byte;
  DT : Byte;
  Ret : Byte;
  DataP : Pointer;
  Msg : String;
  I : LongInt;
begin
  {Ensure IPX services avail}
  if not UsingIPXSPX then
    Exit;
  Msg := '';
  {$IFDEF Windows}
  for I := 1 to 100000 do ;
  {$ELSE}
  Delay(500);  {pause half a second to allow other side to issue Establish...}
  {$ENDIF}
(*
  {Listen for the SPX connection}
  Ret := SPXListenForConn(SEvent,SPXSessionSocket,FALSE,
                          SizeOf(String),2,@OurPascalESR);
  if (Ret <> 0) or (WaitForSPX(SEvent) <> 0) then begin
    WriteLn('Error Listening for SPX connection');
    Exit;
  end;
  SPXConnEstablished := True;                        {!!.22}
*)
  {$IFDEF DPMIOrWnd}
  if not AllocateWinIPXRec(SizeOf(Msg), IEvent) then begin   {!!.40}
    WriteLn('Unable to allocate IPXRec');
    Exit;
  end;
  {$ENDIF}
  {Listen for an IPX packet}
  Ret := IPXListen(IEvent,IPXSessionSocket,FALSE,SizeOf(String),Msg);

(*
  {Check the Listen ECB Pool for an incoming event}
  with SEvent do begin
    repeat
      if UserBreak then begin                          {!!.21}
        WriteLn('User cancelled SPX event');           {!!.21}
        Exit;                                          {!!.21}
      end;                                             {!!.21}
    until SPXListenPooled(SEvent,SPXRetCode,PoolIndex,DT,DataP);
    {An event occurred, check the CompletionCode, if zero, print message}
    if SPXRetCode = 0 then
      WriteLn('<',String(DataP^),'> received via SPX services')
    else
      WriteLn('Error listening for SPX packet');
  end;

  SPXReplenishPool(SEvent,PoolIndex); {place used ECB back in the listen pool}
*)
  if (WaitForIPX(IEvent) <> 0) then begin
    WriteLn('Error Listening for IPX packet');
    Exit;
  end
  else
    WriteLn('<',Msg,'> received via IPX services');
  {$IFDEF DPMIOrWnd}
  FreeWinIpxRec(IEvent);                               {!!.40}
  {$ENDIF}
end;

procedure NetWareMessageDemo;
{Demonstrate assorted NetWare messaging services}

var
  Name             : String;
  RetCode          : Byte;
  AbortedPipe      : Boolean;                         {!!.21}
const
  ConMsg           = 'Hello console operator!';
  PipeMsg          = 'Message Pipes are fun!!!';

begin
  {Broadcast a message to the NetWare CONSOLE}
  BroadcastToConsole(ConMsg);
  WriteLn('<',ConMsg,'> sent to console');
  WriteLn;
  {Get a connection list}
  GetConnections('Enter user to send to: ',TryConnect,Name);
  if TryConnect.Count = 0 then begin
    WriteLn('User <',Name,'> is not logged on to this network');
    Exit;
  end;

  if not IsNetWare3 then begin                        {!!.22}

    {Open a message pipe (or pipes)}
    WriteLn('Waiting for open message pipe (press any key to give up)...');
    repeat
      AbortedPipe := UserBreak;                              {!!.21}
      {Attempt to open a message pipe with all nodes in connection list}
      if not AbortedPipe then                                {!!.21}
        OpenMessagePipe(TryConnect,Result);
    until ConnectedWithSomeone(TryConnect,Result,Connect) or AbortedPipe;
    if not AbortedPipe then begin                            {!!.21}
    {Send a message to all receptive nodes in conmnection list}
      SendMessagePipe(PipeMsg,Connect,Result);
      WriteLn('<',PipeMsg,'> sent via message pipe');
      {Now close the message pipe(s)}
      RetCode := CloseMessagePipe(Connect,Result);
      if RetCode <> 0 then
        WriteLn('Error ',RetCode,' returned by CloseMessagePipe');
    end                                                      {!!.21}
    else                                                     {!!.21}
      WriteLn('User aborted attempt to open message pipe');  {!!.21}
  end;                                                       {!!.22}
  IPXSPXSendDemo; {IPX/SPX demo}

  {Send a broadcast message to all nodes in Connection list}
  SendBroadcastMsg('Hello '+Name,TryConnect,Result);
  WriteLn('<Hello ',Name,'> broadcast to ',Name);
end;

procedure NetWareReceiverDemo;
{Demonstrate assorted NetWare messaging services}

var
  Msg              : String;
  SourceConn       : Byte;
  RetCode          : Byte;
  Name             : String;
  AbortedPipe      : Boolean;                         {!!.21}
  I : LongInt;
begin
  {Get a connection List}
  GetConnections('Enter user to receive from: ',TryConnect,Name);
  if TryConnect.Count = 0 then begin                  {!!.22}
    WriteLn('User <',Name,'> is not logged on to this network');
    Exit;
  end;
  if not IsNetWare3 then begin                        {!!.22}

    {Open a message pipe (or pipes)}
    WriteLn('Waiting for open message pipe (press any key to give up)...');
    repeat
      AbortedPipe := UserBreak;                              {!!.21}
      {Attempt to open a message pipe with all nodes in connection list}
      if not AbortedPipe then                                {!!.21}
        OpenMessagePipe(TryConnect,Result);                  {!!.21}
    until ConnectedWithSomeone(TryConnect,Result,Connect) or AbortedPipe;{!!.21}
    if not AbortedPipe then begin
      {$IFDEF Windows}
      for I := 1 to 100000 do ;
      {$ELSE}
      Delay(1000);           {give the sender a second to send message}
      {$ENDIF}
      {Receive a message (if available) }
      GetMessagePipe(SourceConn,Msg);
      WriteLn('Message received from ',SourceConn,': <',Msg,'>');

      {Close the message pipe}
      RetCode := CloseMessagePipe(Connect,Result);
      if RetCode <> 0 then
        WriteLn('Error ',RetCode,' returned by CloseMessagePipe');
    end
    else
      WriteLn('User aborted attempt to open message pipe');  {!!.21}
  end;                                                {!!.22}
  IPXSPXReceiveDemo; {IPX/SPX demo}
end;

{$F+}
procedure OurExitProc;
{If Using SPX services - Aborts the SPX connection
 If using NetBIOS - Deletes the name and hangs up the session
}
var
  Ret : Byte;

begin
  ExitProc := SaveExitProc;  {allow chaining to original ExitProc}

  {Abort the SPX Connection if SPX services are being used}
(******
  if NetWareIsHere and UsingIPXSPX and SPXConnEstablished then {!!.22}
    SPXAbortConn(SEvent);
*)
  {If NetBIOS, then Cancel any pending requests, delete the added names, and}
  {hangup the session.}
  if NetBIOSIsHere then begin
    if ParamCount > 0 then
      Ret := NetBIOSDeleteName(ExampleRec)
    else
      Ret := NetBIOSDeleteName(ExampleSend);
    Ret := NetBiosHangUp(SessionLSN);
  end;
end;
{$F-}

procedure NetBIOSReceiverDemo;
{NetBIOS datagram and session demo}

  procedure FreeN;
  begin
    {$IFDEF DPMIOrWnd}
    FreeWinNCB(OurNCB);                               {!!.40}
    {$ENDIF}
  end;

var
  Msg : String;
  Ret : Byte;
  Aborted : Boolean;                                  {!!.21}
begin
  Write('Please wait, adding NetBIOS name...');
  if NetBiosAddName(ExampleRec,NameNum) <> 0 then begin
    WriteLn(^M^J,'Unable to add NetBIOS name');
    Exit;
  end;
  WriteLn(^M^J,'waiting for datagram from remote (press any key to abort)...');
  {$IFDEF DPMIOrWnd}
  if not AllocateWinNCB(OurNCB) then begin            {!!.40}
    WriteLn('Unable to allocate NCB');
    Exit;
  end;
  FillChar(Post, SizeOf(Post), 0);
  ReceiveDatagram(OurNCB,NameNum,FALSE,Post,SizeOf(Msg),@Msg);
  {$ELSE}
  ReceiveDatagram(OurNCB,NameNum,FALSE,SizeOf(Msg),Msg);
  {$ENDIF}
  {$IFDEF DPMIOrWnd}
  while OurNCB.NP^.CmdComplete <> 0 do
  {$ELSE}
  while OurNCB.CmdComplete <> 0 do
  {$ENDIF}
    if UserBreak then begin                         {!!.21}
      WriteLn('User aborted NetBIOS test');         {!!.21}
      Ret := CancelRequest(OurNCB);                     {!!.21}
      FreeN;
      Exit;                                         {!!.21}
    end;                                            {!!.21}
  {$IFDEF DPMIOrWnd}
  Ret := OurNCB.NP^.RetCode;
  {$ELSE}
  Ret := OurNCB.RetCode;
  {$ENDIF}
  if Ret = 0 then
    WriteLn('Datagram <',Msg,'> received from ExampleSend')
  else
    WriteLn('ReceiveDatagram error = ',Ret);

  if BroadcastDatagrams then begin
    {$IFDEF DPMIOrWnd}
    ReceiveBDatagram(OurNCB,NameNum,FALSE, Post, SizeOf(Msg),@Msg);
    {$ELSE}
    ReceiveBDatagram(OurNCB,NameNum,FALSE,SizeOf(Msg),Msg);
    {$ENDIF}
    {$IFDEF DPMIOrWnd}
    while OurNCB.NP^.CmdComplete <> 0 do
    {$ELSE}
    while OurNCB.CmdComplete <> 0 do
    {$ENDIF}
      if UserBreak then begin                         {!!.21}
        WriteLn('User aborted NetBIOS test');         {!!.21}
        Ret := CancelRequest(OurNCB);                 {!!.21}
        FreeN;
        Exit;                                         {!!.21}
      end;                                            {!!.21}
    {$IFDEF DPMIOrWnd}
    Ret := OurNCB.NP^.RetCode;
    {$ELSE}
    Ret := OurNCB.RetCode;
    {$ENDIF}
    if Ret = 0 then
      WriteLn('Broadcast Datagram <',Msg,'> received from ExampleSend')
    else
      WriteLn('ReceiveBDatagram error = ',Ret);
  end;

  Write(^M^J,
  'Attempting to establish a NetBIOS session (press any key to give up)...');

  repeat
    Ret := NetBIOSListen(ExampleSend,ExampleRec,5,5,SessionLSN);
    Aborted := UserBreak;                             {!!.21}
  until (Ret = 0) or Aborted;                         {!!.21}
  if Aborted then begin                               {!!.21}
    WriteLn('User aborted NetBIOS test');             {!!.21}
    Ret := CancelRequest(OurNCB);                     {!!.21}
    FreeN;
    Exit;                                             {!!.21}
  end;                                                {!!.21}

  WriteLn;
  {$IFDEF DPMIOrWnd}
  Ret := NetBIOSReceive(SessionLSN,SizeOf(Msg),@Msg);
  {$ELSE}
  Ret := NetBIOSReceive(SessionLSN,SizeOf(Msg),Msg);
  {$ENDIF}
  if Ret = 0 then
    WriteLn('Session Packet <',Msg,'> received')
  else
    WriteLn('NetBIOSReceive error ',Ret);
  FreeN;
end;

procedure NetBIOSMessageDemo;
{NetBIOS datagram and session demo}

  procedure FreeN;
  begin
    {$IFDEF DPMIOrWnd}
    FreeWinNCB(OurNCB);                               {!!.40}
    {$ENDIF}
  end;

const
  Datagram         : String[20] = 'Datagrams are fun!!!';
  BDatagram        : String[40] = 'Broadcast Datagrams are fun!!!';
  SessionPacket    : String[30] = 'Sessions are fun too!!!';

var
  Ret : Byte;
  Aborted : Boolean;                                  {!!.21}
  I : LongInt;
begin
  Write('Please wait, adding NetBIOS name...');
  if NetBiosAddName(ExampleSend,NameNum) <> 0 then begin
    WriteLn(^M^J,'Unable to add NetBIOS name');
    Exit;
  end;
  WriteLn;
  {Pause until user strikes a key}
  Write('Press any key when ready for NetBIOS tests...');
  if ReadKey = #0 then ;

  WriteLn;
  {$IFDEF DPMIOrWnd}
  if not AllocateWinNCB(OurNCB) then begin
    WriteLn('Unable to allocate NCB');
    Exit;
  end;
  {$ENDIF}

  {Send a datagram}
  {$IFDEF DPMIOrWnd}
  FillChar(Post, SizeOf(Post), 0);
  SendDatagram(OurNCB,NameNum,ExampleRec,FALSE,Post, Length(Datagram)+1,@Datagram);
  {$ELSE}
  SendDatagram(OurNCB,NameNum,ExampleRec,FALSE,Length(Datagram)+1,Datagram);
  {$ENDIF}
  {wait for the NetBIOS event to complete}
  {$IFDEF DPMIOrWnd}
  while OurNCB.NP^.CmdComplete <> 0 do
  {$ELSE}
  while OurNCB.CmdComplete <> 0 do
  {$ENDIF}
    if UserBreak then begin                         {!!.21}
      Ret := CancelRequest(OurNCB);                     {!!.21}
      WriteLn('User aborted NetBIOS test');         {!!.21}
      FreeN;
      Exit;                                         {!!.21}
    end;                                            {!!.21}
  {$IFDEF DPMIOrWnd}
  Ret := OurNCB.NP^.RetCode;
  {$ELSE}
  Ret := OurNCB.RetCode;
  {$ENDIF}
  if Ret = 0 then
    WriteLn('Datagram <',Datagram,'> sent to ExampleRec')
  else
    WriteLn('SendDatagram error = ',Ret);

  {If using Broadcast datagrams, then send one}
  if BroadcastDatagrams then begin
    Write('Pausing...');
    {$IFDEF Windows}
    for I := 1 to 100000 do ;
    {$ELSE}
    Delay(1000);
    {$ENDIF}
    WriteLn;
    {$IFDEF DPMIOrWnd}
    SendBDatagram(OurNCB,NameNum,FALSE,Post, Length(BDatagram)+1,@BDatagram);
    {$ELSE}
    SendBDatagram(OurNCB,NameNum,FALSE,Length(BDatagram)+1,BDatagram);
    {$ENDIF}
    {$IFDEF DPMIOrWnd}
    while OurNCB.NP^.CmdComplete <> 0 do
    {$ELSE}
    while OurNCB.CmdComplete <> 0 do
    {$ENDIF}
      if UserBreak then begin                         {!!.21}
        Ret := CancelRequest                                        (OurNCB);                     {!!.21}
        WriteLn('User aborted NetBIOS test');         {!!.21}
        FreeN;
        Exit;                                         {!!.21}
      end;                                            {!!.21}
    {$IFDEF DPMIOrWnd}
    Ret := OurNCB.NP^.RetCode;
    {$ELSE}
    Ret := OurNCB.RetCode;
    {$ENDIF}
    if Ret = 0 then
      WriteLn('Broadcast Datagram <',BDatagram,'> sent to ExampleRec')
    else
      WriteLn('SendBDatagram error = ',Ret);
  end;
  Write(^M^J,
  'Attempting to establish a NetBIOS session (press any key to give up)...');

  {Establish a NetBIOS call}
  repeat
    Ret := NetBIOSCall(ExampleRec,ExampleSend,5,5,SessionLSN);
    Aborted := UserBreak
  until (Ret = 0) or Aborted;
  WriteLn;
  if Aborted then begin
    Writeln('User aborted NetBIOS session');
    FreeN;
    Exit;
  end;

  {Send a Session Packet}
  {$IFDEF DPMIOrWnd}
  Ret := NetBIOSSend(SessionLSN,Length(SessionPacket)+1,@SessionPacket);
  {$ELSE}
  Ret := NetBIOSSend(SessionLSN,Length(SessionPacket)+1,SessionPacket);
  {$ENDIF}
  if Ret = 0 then
    WriteLn('<',SessionPacket,'> sent to remote')
  else
    WriteLn('NetBIOSReceive error ',Ret);
  FreeN;
end;

var
  Ret : Byte;

begin
  {See what Operating system(s) we have here...}
  NetWareIsHere := NetWareLoaded(Logged);
  NetWareIsHere := NetWareIsHere and Logged;
  NetBIOSIsHere := NetBIOSInstalled;
  UsingIPXSPX   := NetWareIsHere and IPXServicesAvail;

  if not (NetBIOSIsHere or NetWareIsHere) then begin
    WriteLn('No network operating system detected.');
    Halt;
  end;

  if NetWareIsHere then
    BroadcastDatagrams := FALSE; {NetWare does not support these services}

  SaveExitProc := ExitProc;  {save original exitproc}
  ExitProc := @OurExitProc;  {setup our exit procedure}

  {If no parameters, then act as sender}
  if ParamCount = 0 then begin
    if NetWareIsHere then
      NetWareMessageDemo;
    if NetBIOSIsHere then
      NetBIOSMessageDemo;
  end
  {If parameter on the command line, then act as receiver}
  else begin
    if NetWareIsHere then
      NetWareReceiverDemo;
    if NetBIOSIsHere then
      NetBIOSReceiverDemo;
  end;

  {NOTE: OurExitProc is called no matter how we terminate}
end.

