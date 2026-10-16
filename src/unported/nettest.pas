{$V-}
program NetTester;
{
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

uses Crt,
     NetWare, {Services for Novell's NetWare}
     NetBIOS; {Services for NetBIOS}

const
  ActAsSender : Boolean = TRUE;

  {NetBIOS const}
  ExampleRec       : NBNameStr = 'ExampleRec*****';
  ExampleSend      : NBNameStr = 'ExampleSend****';

  {Use of Broadcast Datagrams is on by default.  However, Novell's NetBIOS}
  {emulator does not implement these functions, so this program will}
  {automatically set this to FALSE if NetWare is detected.}
  BroadcastDatagrams : Boolean = TRUE;

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
  SEvent           : SPXRec;
  IEvent           : IPXRec;

  {NetBIOS vars}
  SaveExitProc     : Pointer;
  NameNum          : Byte;
  SessionLSN       : Byte;
  OurNCB           : NCB;

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
  IPXRelinquish;
  if Keypressed then begin
    if ReadKey = #0 then ;
    WriteLn(^M^J,'User break');
    Halt;
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

function WaitForIPX(var Rec : IPXRec) : Byte;
{Wait for the completion of an IPX event, return CompletionCode as function
 result.  Check for userbreak and abort if KeyPressed.}
begin
  while Rec.ECB.InUse <> 0 do begin
    IPXRelinquish;
    if UserBreak then ;
  end;
  WaitForIPX := Rec.ECB.CompletionCode;
end;

function WaitForSPX(var Rec : SPXRec) : Byte;
{Wait for the completion of an SPX event, return CompletionCode as function
 result.  Check for userbreak and abort if KeyPressed.}
begin
  while Rec.ECB.InUse <> 0 do begin
    IPXRelinquish;
    if UserBreak then ;
  end;
  WaitForSPX := Rec.ECB.CompletionCode;
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
  {Ensure IPX services avail}
  if IPXServicesAvail then
    UsingIPXSPX := TRUE
  else begin
    UsingIPXSPX := FALSE;
    Exit;
  end;
  GetInternetAddress(Connect.List[1],Receiver);

  Ret := SPXEstablishConn(SEvent,Receiver,SPXSessionSocket,FALSE,512,2,NIL);
  if (Ret <> 0) or (WaitForSPX(SEvent) <> 0) then begin
    WriteLn('Error establishing SPX connection');
    Exit;
  end;
  SPXSend(SEvent,FALSE,1,Length(SPXMsg)+1,SPXMsg);
  if WaitForSPX(SEvent) = 0 then
    WriteLn('<',SPXMsg,'> send to receiver')
  else
    WriteLn('SPXSend error sending packet to receiver');

  Receiver.Socket := IPXSessionSocket;

  Ret := IPXSend(IEvent,Receiver,IPXSessionSocket,FALSE,
                 Length(IPXMsg)+1,IPXMsg);

  if (Ret <> 0) or (WaitForIPX(IEvent) <> 0) then begin
    WriteLn('Error sending IPX packet');
    Exit;
  end;
end;

{$F+}
{$S-,R-} {these MUST ALWAYS be off for an ESR}
procedure OurPascalESR(var Event : SPXRec; RetCode : Byte;
                       PoolIndex : Byte;
                       DataType : Byte;
                       DataP : Pointer);
{This is a sample ESR. First it calls PoolQueueTheEvent to queue the incoming
 event for processing. The rest of the ESR is for examplification only. In
 general, an ESR should return very quickly. Since this one does not return
 quickly, interrupts are enabled as soon as the event has been properly
 queued.
}
var
  I,II : Word;

begin
  Inline($FB); {STI ; enable interrupts because we stay here too long...}

  {Make a silly sound}
  for I := 1 to 1000 do begin
    Sound(I);
    for II := 1 to 20 do ; {NOTE: We can't call Delay here, so we use a loop}
  end;
  NoSound;
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

begin
  {Ensure IPX services avail}
  if IPXServicesAvail then
    UsingIPXSPX := TRUE
  else begin
    UsingIPXSPX := FALSE;
    Exit;
  end;

  Delay(500);  {pause half a second to allow other side to issue Establish...}

  {Listen for the SPX connection}
  Ret := SPXListenForConn(SEvent,SPXSessionSocket,FALSE,
                          SizeOf(String),2,@OurPascalESR);
  if (Ret <> 0) or (WaitForSPX(SEvent) <> 0) then begin
    WriteLn('Error Listening for SPX connection');
    Exit;
  end;

  {Listen for an IPX packet}
  Ret := IPXListen(IEvent,IPXSessionSocket,FALSE,SizeOf(String),Msg);

  {Check the Listen ECB Pool for an incoming event}
  with SEvent do begin
    repeat
      if UserBreak then ;
    until SPXListenPooled(SEvent,SPXRetCode,PoolIndex,DT,DataP);
    {An event occurred, check the CompletionCode, if zero, print message}
    if SPXRetCode = 0 then
      WriteLn('<',String(DataP^),'> received via SPX services')
    else
      WriteLn('Error listening for SPX packet');
  end;

  SPXReplenishPool(SEvent,PoolIndex); {place used ECB back in the listen pool}

  if (WaitForIPX(IEvent) <> 0) then begin
    WriteLn('Error Listening for IPX packet');
    Exit;
  end
  else
    WriteLn('<',Msg,'> received via IPX services');
end;

procedure NetWareMessageDemo;
{Demonstrate assorted NetWare messaging services}

var
  Name             : String;
  RetCode          : Byte;

const
  PipeMsg          = 'Message Pipes are fun!!!';

begin
  {Get a connection list}
  GetConnections('Enter user to send to: ',TryConnect,Name);
  if TryConnect.Count = 0 then begin
    WriteLn('User <',Name,'> is not logged on to this network');
    Exit;
  end;

  {Open a message pipe (or pipes)}
  WriteLn('Waiting for open message pipe (press any key to give up)...');
  repeat
    {Attempt to open a message pipe with all nodes in connection list}
    OpenMessagePipe(TryConnect,Result);
  until ConnectedWithSomeone(TryConnect,Result,Connect) or UserBreak;

  {Send a message to all receptive nodes in conmnection list}
  SendMessagePipe(PipeMsg,Connect,Result);
  WriteLn('<',PipeMsg,'> sent via message pipe');

  {Now close the message pipe(s)}
  RetCode := CloseMessagePipe(Connect,Result);
  if RetCode <> 0 then
    WriteLn('Error ',RetCode,' returned by CloseMessagePipe');

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
begin
  {Get a connection List}
  GetConnections('Enter user to receive from: ',TryConnect,Name);

  {Open a message pipe (or pipes)}
  WriteLn('Waiting for open message pipe (press any key to give up)...');
  repeat
    {Attempt to open a message pipe with all nodes in connection list}
    OpenMessagePipe(TryConnect,Result);
  until ConnectedWithSomeone(TryConnect,Result,Connect) or UserBreak;

  Delay(1000);           {give the sender a second to send message}

  {Receive a message (if available) }
  GetMessagePipe(SourceConn,Msg);
  WriteLn('Message received from ',SourceConn,': <',Msg,'>');

  {Close the message pipe}
  RetCode := CloseMessagePipe(Connect,Result);
  if RetCode <> 0 then
    WriteLn('Error ',RetCode,' returned by CloseMessagePipe');

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
  if NetWareIsHere and UsingIPXSPX then
    SPXAbortConn(SEvent);

  {If NetBIOS, then Cancel any pending requests, delete the added names, and}
  {hangup the session.}
  if NetBIOSIsHere then begin
    Ret := CancelRequest(OurNCB);
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
var
  Msg : String;
  Ret : Byte;

begin
  Write('Please wait, adding NetBIOS name...');
  if NetBiosAddName(ExampleRec,NameNum) <> 0 then begin
    WriteLn(^M^J,'Unable to add NetBIOS name');
    Exit;
  end;
  WriteLn(^M^J,'waiting for datagram from remote (press any key to abort)...');
  ReceiveDatagram(OurNCB,NameNum,FALSE,SizeOf(Msg),Msg);
  while OurNCB.CmdComplete <> 0 do
    if UserBreak then ;
  if OurNCB.RetCode = 0 then
    WriteLn('Datagram <',Msg,'> received from ExampleSend')
  else
    WriteLn('ReceiveDatagram error = ',OurNCB.RetCode);

  if BroadcastDatagrams then begin
    ReceiveBDatagram(OurNCB,NameNum,FALSE,SizeOf(Msg),Msg);
    while OurNCB.CmdComplete <> 0 do
      if UserBreak then ;
    if OurNCB.RetCode = 0 then
      WriteLn('Broadcast Datagram <',Msg,'> received from ExampleSend')
    else
      WriteLn('ReceiveBDatagram error = ',OurNCB.RetCode);
  end;

  Write(^M^J,
  'Attempting to establish a NetBIOS session (press any key to give up)...');

  repeat
    Ret := NetBIOSListen(ExampleSend,ExampleRec,5,5,SessionLSN);
  until (Ret = 0) or UserBreak;
  WriteLn;

  Ret := NetBIOSReceive(SessionLSN,SizeOf(Msg),Msg);
  if Ret = 0 then
    WriteLn('Session Packet <',Msg,'> received')
  else
    WriteLn('NetBIOSReceive error ',Ret);
end;

procedure NetBIOSMessageDemo;
{NetBIOS datagram and session demo}

const
  Datagram         : String[20] = 'Datagrams are fun!!!';
  BDatagram        : String[40] = 'Broadcast Datagrams are fun!!!';
  SessionPacket    : String[30] = 'Sessions are fun too!!!';

var
  Ret : Byte;

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
  {Send a datagram}
  SendDatagram(OurNCB,NameNum,ExampleRec,FALSE,Length(Datagram)+1,Datagram);
  {wait for the NetBIOS event to complete}
  while OurNCB.CmdComplete <> 0 do
    if UserBreak then ;
  if OurNCB.RetCode = 0 then
    WriteLn('Datagram <',Datagram,'> sent to ExampleRec')
  else
    WriteLn('SendDatagram error = ',OurNCB.RetCode);

  {If using Broadcast datagrams, then send one}
  if BroadcastDatagrams then begin
    Write('Pausing one second...');
    Delay(1000);
    WriteLn;
    SendBDatagram(OurNCB,NameNum,FALSE,Length(BDatagram)+1,BDatagram);
    while OurNCB.CmdComplete <> 0 do
      if UserBreak then ;
    if OurNCB.RetCode = 0 then
      WriteLn('Broadcast Datagram <',BDatagram,'> sent to ExampleRec')
    else
      WriteLn('SendBDatagram error = ',OurNCB.RetCode);
  end;
  Write(^M^J,
  'Attempting to establish a NetBIOS session (press any key to give up)...');

  {Establish a NetBIOS call}
  repeat
    Ret := NetBIOSCall(ExampleRec,ExampleSend,5,5,SessionLSN);
  until (Ret = 0) or UserBreak;
  WriteLn;

  {Send a Session Packet}
  Ret := NetBIOSSend(SessionLSN,Length(SessionPacket)+1,SessionPacket);
  if Ret = 0 then
    WriteLn('<',SessionPacket,'> sent to remote')
  else
    WriteLn('NetBIOSReceive error ',Ret);
end;

procedure InvalidOption(S : String);

begin
  WriteLn(S,' is an invalid command line option');
end;

procedure ShowHelp;

begin
  WriteLn('NetTest [OPTIONS]'^M^J);
  WriteLn('  /R    Act as receiving side');
  WriteLn('  /B    Test NetBIOS only');
  WriteLn('  /N    Test Advanced NetWare only');
  WriteLn('  /?    This help message');
  Halt;
end;

procedure ParseCommandLine;

var
  Opt : String;
  I : Byte;

begin
  for I := 1 to ParamCount do begin
    Opt := ParamStr(I);
    if (Length(Opt) = 2) and (Opt[1] in ['-','/']) then
      case UpCase(Opt[2]) of
        'B' : NetWareIsHere := FALSE;
        'W','N' : NetBIOSIsHere := FALSE;
        'R' : ActAsSender := FALSE;
        '?','H' : ShowHelp;
        else InvalidOption(Opt);
      end
    else
      InvalidOption(Opt);
  end;
end;

var
  Ret : Byte;

begin
  WriteLn('NetTest version 1.0'^M^J);
  {See what Operating system(s) we have here...}
  NetWareIsHere := NetWareLoaded(Logged);
  NetWareIsHere := NetWareIsHere and Logged;
  NetBIOSIsHere := NetBIOSInstalled;

  ParseCommandLine;

  if not (NetBIOSIsHere or NetWareIsHere) then begin
    WriteLn('No network operating system detected.');
    Halt;
  end;

  if NetWareIsHere then
    BroadcastDatagrams := FALSE; {NetWare does not support these services}

  SaveExitProc := ExitProc;  {save original exitproc}
  ExitProc := @OurExitProc;  {setup our exit procedure}

  if ActAsSender then begin
    if NetWareIsHere then
      NetWareMessageDemo;
    if NetBIOSIsHere then
      NetBIOSMessageDemo;
  end
  else begin
    if NetWareIsHere then
      NetWareReceiverDemo;
    if NetBIOSIsHere then
      NetBIOSReceiverDemo;
  end;

  {NOTE: OurExitProc is called no matter how we terminate}
end.

