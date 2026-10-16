(***********************************************************************
  SPX2WAY.PAS - demonstrates how to set up a two-way SPX communication
                channel. Also demonstrates how to use an IPX broadcast
                to find a cooperating partner for an SPX message
                session.

                Start the "host" by running SPX2WAY on one workstation
                with no command line parameters. Then start the
                "station" by running SPX2WAY on another workstation
                with at least one command line parameter.

                Press <Esc> to break the connection. Press any other
                key to be prompted for a string to send to the other
                station.

                Requires SPX version 3.00 or later. Use Novell's
                NVER utility to check your SPX driver version.

                Kim Kokkonen, TurboPower Software
                Version 1.0 - 11/12/92
                Based on a test program provided by Richard DeMello
                and Steve Pasikowski at Core Technology Corp.
************************************************************************)

{$IFDEF Windows}
  {$DEFINE WinOrDPMI}
{$ENDIF}
{$IFDEF DPMI}
  {$DEFINE WinOrDPMI}
{$ENDIF}

{$R-,S-,I-}
program Spx2Way;

uses
  {$IFDEF Windows}
  WinCrt,
  {$ELSE}
  Crt,
  {$ENDIF}
  {$IFDEF WinOrDPMI}
  WinDPMI,
  {$ENDIF}
  Netware;

const
  Socket1 = $4445;              {Sockets used for each direction of connection}
  Socket2 = $4446;
  NumSPXECBs = 4;               {Number of listening ECBs}
  ConnectionMade : Boolean = False; {True if session created}

const
  MessageType = 0;              {Type code for each SPX message sent}
type
  Message = String;             {Type of user data for each SPX message}

var
  {$IFDEF WinOrDPMI}
  IPXEvent : WinIPXRec;         {Global IPX event variable}
  SPXEvent : WinSPXRec;         {Global SPX event variable}
  SendESR  : WinESRType;        {Do-nothing SPX event service routine}
  MessagePR: ^Message;          {Message pointer, real mode}
  MessagePP: ^Message;          {Message pointer, protected mode}
  {$ELSE}
  IPXEvent : IPXRec;            {Global IPX event variable}
  SPXEvent : SPXRec;            {Global SPX event variable}
  SendESR  : Pointer;           {Do-nothing SPX event service routine}
  MessagePR: ^Message;          {Message pointer}
  {$ENDIF}
  SaveExit : Pointer;           {Saved exit procedure}

procedure CheckNetWare;
var
  LoggedOn : Boolean;
  Version : Word;
  MaxSPXConn : Word;
  AvailSPXConn : Word;
begin
  if not NetWareLoaded(LoggedOn) then begin
    WriteLn('NetWare drivers must be loaded');
    Halt;
  end;
  if not SPXServicesAvail(Version, MaxSPXConn, AvailSPXConn) then begin
    WriteLn('SPX services are not available');
    Halt;
  end;
  if Version < $0300 then begin
    WriteLn('SPX version must be at least 3.00');
    Halt;
  end;
end;

{$F+}
procedure FreeResources;
begin
  ExitProc := SaveExit;
  if ConnectionMade then begin
    SPXTerminateConn(SPXEvent);
    ConnectionMade := False;
    WriteLn('Connection terminated');
  end;
  {$IFDEF WinOrDPMI}
  if SPXEvent.wsrP <> nil then
    FreeWinSPXRec(SPXEvent);
  if IPXEvent.wirP <> nil then
    FreeWinIPXRec(IPXEvent);
  if MessagePP <> nil then
    FreeRealModeMem(MessagePP);
  if SendESR.PoolPtr <> nil then
    FreeWindowsESR(SendESR);
  {$ELSE}
  FreeMem(MessagePR, SizeOf(Message));
  {$ENDIF}
end;
{$F-}

procedure AllocateResources;
begin
  {Install exit procedure to clean up}
  SaveExit := ExitProc;
  ExitProc := @FreeResources;

  {$IFDEF WinOrDPMI}
  FillChar(SPXEvent, SizeOf(SPXEvent), 0);
  FillChar(IPXEvent, SizeOf(IPXEvent), 0);
  FillChar(SendESR, SizeOf(SendESR), 0);
  MessagePP := nil;
  {No user data is transferred via IPX, so use a 1 byte data buffer}
  if not AllocateWinIPXRec(1, IPXEvent) then begin
    WriteLn('Unable to allocate IPXEvent');
    Halt;
  end;
  if not AllocateWinSPXRec(SPXEvent) then begin
    WriteLn('Unable to allocate SPXEvent');
    Halt;
  end;
  {Variables of type Message are transferred via SPX}
  if not GetRealModeMem(SizeOf(Message),
                        Pointer(MessagePR), Pointer(MessagePP)) then begin
    Writeln('Unable to allocate message buffer');
    Halt;
  end;
  if not AllocateWindowsESR(NoESR, DSeg, SendESR) then begin
    WriteLn('Unable to allocate windows ESR');
    Halt;
  end;
  {$ELSE}
  MessagePR := nil;
  if MaxAvail < SizeOf(Message) then begin
    Writeln('Unable to allocate message buffer');
    Halt;
  end;
  GetMem(MessagePR, SizeOf(Message));
  SendESR := nil;
  {$ENDIF}
end;

procedure HaltIfKeyPressed;
begin
  if KeyPressed then begin
    WriteLn('Aborted by user');
    Halt;
  end;
end;

procedure HaltIfError(Status : Byte);
begin
  if Status <> 0 then begin
    WriteLn('Error: ', Status);
    Halt;
  end;
end;

procedure InitHost;
var
  StationAddr : IPXAddress;
  Status : Byte;
  IPXBuf : Byte;
begin
  WriteLn('Host Mode.');

  Write('Waiting for IPX broadcast on socket ', Socket1, '... ');
  Status := IPXListen(IPXEvent, Socket1, False, 1, IPXBuf);
  if Status = 0 then
    while not IPXEventComplete(IPXEvent, Status) do
      HaltIfKeyPressed;
  HaltIfError(Status);

  {The address of the station is now in the IPXEvent}
  {$IFDEF WinOrDPMI}
  StationAddr := IPXEvent.wirP^.IPXHead.Source;
  {$ELSE}
  StationAddr := IPXEvent.IPXHead.Source;
  {$ENDIF}

  {Use a second socket for the SPX connection}
  {StationAddr.Socket := Swap(Socket2);} {!!.41}

  WriteLn;
  Write('IPX broadcast received. Establishing SPX connection... ');
  Status := SPXEstablishConn(SPXEvent, StationAddr, Socket2, True, {!!.41}
                             SizeOf(Message), NumSPXECBs, SendESR);
  HaltIfError(Status);
  ConnectionMade := True;
  WriteLn;
end;

procedure InitStation;
var
  HostAddr : IPXAddress;
  Status : Byte;
  ComplCode : Byte;
  DataType : Byte;
  IPXBuf : Byte;
begin
  WriteLn('Station Mode.');

  WriteLn('Broadcasting IPX on socket ',
          Socket1,
          ' and waiting for SPX connection... ');
  Status := SPXListenForConn(SPXEvent, Socket2, False, SizeOf(Message),
                             NumSPXECBs, SendESR);
  while not SPXEventComplete(SPXEvent, ComplCode, DataType) do begin
    {Send an IPX broadcast}
    {$IFDEF WinOrDPMI}
    IPXEvent.wirP^.IPXHead.PacketType := $FE;
    {$ELSE}
    IPXEvent.IPXHead.PacketType := $FE;
    {$ENDIF}
    FillChar(HostAddr.Node, 6, $FF);
    HostAddr.Network := 0;
    {HostAddr.Socket := Socket1;} {!!.41}
    Status := IPXSend(IPXEvent, HostAddr, Socket1, True, 1, IPXBuf);
    HaltIfKeyPressed;
  end;

  WriteLn;
  WriteLn('SPX connection established');
  ConnectionMade := True;

  {Store the connection ID}
  {$IFDEF WinOrDPMI}
  SPXEvent.wsrP^.ConnID := Word(SPXEvent.wsrP^.ECB.ECBP^.IPXWorkspace);
  {$ELSE}
  SPXEvent.ConnID := Word(SPXEvent.ECB.IPXWorkspace);
  {$ENDIF}
end;

procedure TransmitAndReceive;
var
  Key : Char;
  ComplCode : Byte;
  PoolIndex : Byte;
  DataType : Byte;
  MessagePtr : ^Message;
begin
  WriteLn;
  WriteLn('Ready to transmit messages. <Esc> to quit, any other key to send.');
  repeat
    if KeyPressed then begin
      {Keyboard command}
      Key := ReadKey;
      if Key = #27 {ESC} then
        Exit;
      {Send a message}
      Write('Enter message: ');
      {$IFDEF WinOrDPMI}
      ReadLn(MessagePP^);
      SPXSend(SPXEvent, True, MessageType, Length(MessagePP^)+1, MessagePR);
      {$ELSE}
      ReadLn(MessagePR^);
      SPXSend(SPXEvent, True, MessageType, Length(MessagePR^)+1, MessagePR^);
      {$ENDIF}
      WriteLn('<Sent>');
    end;
    if SPXListenPooled(SPXEvent, ComplCode, PoolIndex,
                       DataType, Pointer(MessagePtr)) then
      if (ComplCode = 0) and (DataType = MessageType) then begin
        {Message received}
        WriteLn('Message received: "', MessagePtr^, '"');
        SPXReplenishPool(SPXEvent, PoolIndex);
      end else begin
        {Connection terminated or other error}
        (*WriteLn('Completion code ', ComplCode, '  DataType ', DataType);*)
        Exit;
      end;
  until False;
end;

begin
  CheckNetWare;
  AllocateResources;
  if ParamCount = 0 then
    {Host side, wait for call from station}
    InitHost
  else
    {Station side, look for host}
    InitStation;
  TransmitAndReceive;
end.
