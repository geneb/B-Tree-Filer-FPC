{*********************************************************}
{*                   IPXSPX.INC 5.41                     *}
{*        Copyright (c) TurboPower Software 1989.        *}
{*                 All rights reserved.                  *}
{*********************************************************}

const
  MAXIPXPACKET     = 576;
  IPXServicesAvailable
                   : Boolean = FALSE;
  PascalESR        : Pointer = NIL;

function IPXServicesAvail : Boolean;
{-returns TRUE if IPX services are available.}

begin
  IPXServicesAvail := IPXServicesAvailable;
end;

function IPXInstalled : Boolean;

var
  NovRegs          : Registers;

begin
  with NovRegs do begin
    AX := $7A00;             {func 7Ah of int 2Fh is used to detect IPX}
    Intr($2F,NovRegs);
    if AL = $FF then begin   {if AL is FFh then IPX is loaded and available}
      IPXInstalled := TRUE;
      IPXLocation := Ptr(ES,DI); {pointer to IPX entry point in ES:DI}
    end
    else begin
      IPXInstalled := FALSE; {no IPX installed}
      IPXLocation := NIL;
    end;
  end;
end;


{$L IPXSPX}
{$F+}

function IPXGetLocalTarget(var LocalTarget : TargetType;
                           var TransportTime : Word) : Byte; External;
{returns the immediate address of an IPXAddress.  If the IPXAddress resides
 on a different network, then the immediate address returned will be that of a
 router station (bridge). The estimated time one-way transport time is also
 returned}

function IPXOpenSocketPrim(RequestedSocket : Word;
                           Forever : Boolean) : Byte; External;
{ Opens a sockets.  Returns the Function Completed Code (explained below).
  The first parameter Forever indicates whether the socket should remain open
  after the program terminates.  If Forever is TRUE, then the socket remains
  open until it is explicitly closed.  If FALSE, the socket is closed
  automatically when the program that opened it terminates.  The Forever flag
  is useful when opening a socket within a TSR.  The second parameter
  RequestedSocket indicates the socket number to open.

  Possible function result (Function Completed Code) values are:
    $00  = Socket successfully open
    $FF  = Socket is Already Open (IPXSocketAlreadyOpen)
    $FE  = Socket Table is already full (IPXSocketTableFull)

}

procedure IPXCloseSocketPrim(SocketNum : Word); External;
{ This function closes the socket specified by SocketNum.  This automatically
  cancels all associated IPXECBs whether they are in use by IPX or the AES for
  sending, listening, or scheduling.  After closing a socket, all incoming
  packets for that socket are ignored.  Attempting to close a socket that is
  not open has no effect.

  Important: Transient applications (non TSRs) MUST close all their sockets
  before terminating. Failure to close a socket before terminating could
  result in hanging the station.  This comes from the possibility that
  an event service routine within the no longer resident application may be
  called (meaning a call is made to an address where the program no longer
  resides). Even though sockets may be open with a FALSE value for the Forever
  parameter indicating that the socket should be closed automatically upon
  termination of the program, the application should still explicitly close
  all open sockets whenever possible (see NOvell API Reference Volume 2).

  IPXCloseSocketPrim may never be called from within an Event Service Routine.
  This is due to the fact that it is not re-entrant.
}


procedure IPXSendPrim(var ECB); External;
{ This procedure prepares an ECB and the IPX header of its associated packet
  and passes the ECB to the network drivers to initiate a send operation.
  This function returns immediately to the calling application.  In other
  words, the send event can not be assumed completed when this function
  returns. When the send event has been completed by the driver, the InUse
  flag of the ECB is reset to 0 (it is $FF while the send event is pending).
  If the ESRAddress pointer within the IPXECB is not NIL, then the Event
  Service Routine (the code pointed to by the ESRAddress field) will be
  called upon completion of the send request (see documentation regarding the
  limitations of ESRs).

  Before calling IPXSend, the follwoing fields within the ECB must be
  initialized: ESRAddress, SocketNumber, ImmediateAddress, FragmentCount,
  and FD1 (and possible FD? if FragmentCount is greater than 1).  The buffer
  specified by FD1 must be at least 30 bytes long and must contain the
  IPX header first. In the IPX header, the following fields must be
  initialized: PacketType, and Destination (Network, Node, and Socket).

  Once the InUse field of the ECB is 0, the CompletionCode field contains
  the result code of the send event. Valid CompletionCode values are:

    $00  = The send completed successfully
    $FC  = The send request was cancelled by an IPXCloseSocket or or an
           IPXCancelEvent function call (IPXEventCancelled).
    $FD  = Malformed Packet - either the packet was less than 30 bytes,
           the first fragment was too small for the header, or the
           fragment count was zero (IPXMalformedPacket).
    $FE  = Packet is undeliverable (IPXPacketUndeliverable).
    $FF  = Physically unable to deliver packet, possibly due to hardware
           or network failure (IPXPhysicalError).
}

procedure IPXListenPrim(var ECB); External;
{ This procedure delivers the specified ECB to the IPX driver for the purpose
  of receiving an IPX packet.  It returns immediately to the calling
  application.  This procedure only delivers the ECB to the driver, it does
  not wait for delivery of the packet.  While the driver is awaiting receipt
  of a packet after a call to IPXListen, the InUse field of the passed ECB is
  set to $FE.  This field remains set until a receive event occurs, the
  request is cancelled, or IPX deems the ECB to be unusable.

  Before calling IPXListen, the ESRAddress, SocketNumber, FragmentCount,
  and FD1 fields of the IPXECB must be initialized.  If FragmentCount is
  greater than one, then each additional FD? field must be initialized.

  After the InUse flag is reset to zero, the CompletionCode field of the ECB
  contains one of the following values:

    $00  = The Packet was received successfully
    $FC  = The receive request was cancelled by an IPXCloseSocket or or an
           IPXCancelEvent function call (IPXEventCancelled).

    $FD  = Packet Overflow.  A packet was received, but the ECB's fragment
           count was zero, or the space defined by the ECB's fragment
           descriptor list was not large enough to contain the entire
           packet (IPXPacketOverflow)
    $FF  = Socket specified to listen on in ECB was not open
           (IPXSocketNotOpen)

  The received packet is placed into memory based on the ECB's fragment
  descriptor list.  See the documentation regarding Fragment Descriptor Lists.
}

function IPXCancelEventPrim(var ECB) : Byte; External;
{ This function cancels the event specified by the ECB.  This function cancels
  any kind of event (Send, Listen, Schedule or Reschedule, or special purpose
  event).  If the ECB was in use by IPX, the InUse field of the ECB is set to
  zero, and the CompletionCode field is set to $FC. The ECB is then available
  for reuse by the application.

  There is one case where a valid ECB can not be cancelled.  This is when the
  driver is in the process of transfering data to or from the fragment
  descriptor list descibed by the ECB.  In this case, a function
  CompletionCode of $F9 is returned.

  When an event is cancelled, its associated ESR is not called.  This function
  returns the CompletionCode as its function result.  Valid values are:

    $00  = Event was successfully cancelled
    $FF  = the ECB was not in use by IPX or AES
    $F9  = ECB was in use but unable to cancel

}

procedure IPXRelinquish; External;
{ This procedure serves one of two purposes, depending whether it is invoked
  from a file server/bridge, or a workstation.  On a file server or network
  bridge, this function releases the machine to the server or bridge process.
  In other words, the application that calls it is temporarily suspended so
  the server or bridge process may have the machine immediately.  This
  procedure must be invoked at least once during each iteration of an idle
  loop to ensure the server or bridge is performing at maximum efficiency.
  When this procedure is called from a workstation, it invokes a polling
  procedure that allows the receiption and sending of internetwork packets.
  For those drivers without hardware interrupts, frequent calls to this
  procedure are crucial to the operation of applications that rely on packet
  exchange.
}

procedure IPXInternetAddress(var Address : IPXAddress); External;
{ This procedure returns the internetwork address of the node (station)
  on which it is executing.  The first two fields of the IPXAddress are
  filled in.  The third field of an IPXAddress type, the Socket, is not
  returned.
}

procedure IPXScheduleEvent(DelayTime : Word; var ECB : IPXECB); External;
{ This procedure schedules an IPX event to occur after the specified time
  interval expires. The time interval is specified in clock ticks.

  See the Novell API Reference Volume 2 for info on AES and event service
  routines.
}

procedure IPXScheduleSpecialEvent(DelayTime : Word;
                                  var ECB : AESECB); External;
{ This procedure schedules a special purpose, application defined event to
  occur after a specified time interval expires.  Since the interval range
  is specified as a word, it may be between 0 and 65,535 clock ticks
  (about 60 minutes).

  See the Novell API Reference Volume 2 for info on AES and event service
  routines.
}

function IPXGetIntervalMarker : Word; External;
{ This function returns a timing marker.  This marker is the current time
  in clock ticks.  It has no relation to the real-world time.  It is useful
  for comparing with another timing marker, and the difference is elapsed
  clock ticks.
}
{$IFDEF FMinus}
  {$F-}
{$ENDIF}

{***********************************************************************
  high level IPX routines
***********************************************************************}
function IPXOpenSocket(RequestedSocket : Word;
                       Forever : Boolean) : Byte;
{ Opens a sockets.  Returns the Function Completed Code (explained below).
  The first parameter Forever indicates whether the socket should remain open
  after the program terminates.  If Forever is TRUE, then the socket remains
  open until it is explicitly closed.  If FALSE, the socket is closed
  automatically when the program that opened it terminates.  The Forever flag
  is useful when opening a socket within a TSR.  The second parameter
  RequestedSocket indicates the socket number to open.

  Possible function result (Function Completed Code) values are:
    $00  = Socket successfully open
    $FF  = Socket is Already Open (IPXSocketAlreadyOpen)
    $FE  = Socket Table is already full (IPXSocketTableFull)

}
begin
  IPXOpenSocket := IPXOpenSocketPrim(Swap(RequestedSocket),Forever);
end;

procedure IPXCloseSocket(SocketNum : Word);
{ This function closes the socket specified by SocketNum.  This automatically
  cancels all associated IPXECBs whether they are in use by IPX or the AES for
  sending, listening, or scheduling.  After closing a socket, all incoming
  packets for that socket are ignored.  Attempting to close a socket that is
  not open has no effect.

  Important: Transient applications (non TSRs) MUST close all their sockets
  before terminating. Failure to close a socket before terminating could
  result in hanging the station.  This comes from the possibility that
  an event service routine within the no longer resident application may be
  called (meaning a call is made to an address where the program no longer
  resides). Even though sockets may be open with a FALSE value for the Forever
  parameter indicating that the socket should be closed automatically upon
  termination of the program, the application should still explicitly close
  all open sockets whenever possible (see NOvell API Reference Volume 2).

  IPXCloseSocket may never be called from within an Event Service Routine.
  This is due to the fact that it is not re-entrant.
}
begin
  IPXCloseSocketPrim(Swap(SocketNum));
end;

function IPXAssignUniqueSocket(var ReturnedSocket : Word;
                               Forever : Boolean) : Word; External;

{This routine is used to allow IPX to assign a socket number not currently in
 use. This is considered a high level IPX routine because the socket number is
 returned in native PC format (low byte, high byte) rather than native
 NetWare format (high byte, low byte). All IPX and SPX high level routines
 take and return sockets in PC format, and all low level routines take and
 return sockets in NetWare format.}

function IPXEventComplete(var IPXEvent : IPXRec;
                          var FinalResult : Byte) : Boolean;

begin
  with IPXEvent do begin
    IPXRelinquish;
    if ECB.InUse = 0 then begin
      IPXEventComplete := TRUE;
      with ECB do
        FinalResult := CompletionCode;
    end
    else
      IPXEventComplete := FALSE;
  end;
end;


function IPXCancelEvent(var IPXEvent : IPXRec) : Byte;

begin
  with IPXEvent do
    IPXCancelEvent := IPXCancelEventPrim(ECB);
end;

function IPXSend(var IPXEvent : IPXRec;
                 Receiver : IPXAddress;
                 Socket : Word;
                 WaitForCompletion : Boolean;
                 DataPacketSize : Word;
                 var DataPacket) : Byte;


{Opens the desired socket (if not open already) and prepares the ECB for
 an IPXSend operation.

 It is important to remember that an IPX send event can not be assumed
 complete when this function returns. The IPXECB, IPXHeader, and user data
 passed to this function must remain static until this function completes. In
 other words, they must either be global variables, or be declared on the heap
 and not Freed until the operation completes. They should not be local
 variables, unless you can guarantee that the send operation will be completed
 or cancelled before the routine that they are local to completes.
}

var
  Final            : Byte;
  TransportTime    : Word;             {!!.22}
  ActualTarget     : TargetType;       {!!.22}

begin
  Socket := Swap(Socket);
  {check the size of the data passed to make sure it is not too big}
  if DataPacketSize > (MAXIPXPACKET - SizeOf(IPXHeader)) then
    IPXSend := IPXDataTooLarge
  {note: It is not considered an error if the socket is already open}
  else if IPXOpenSocketPrim(Socket,FALSE) = IPXSocketTableFull then
    IPXSend := IPXSocketTableFull {can't open any more sockets}
  else begin
    IPXSend := 0;
    with IPXEvent do begin
      {the FillChar implicitly initializes the ESRAddress to NIL and the }
      {InUse flag to zero}
      FillChar(ECB,SizeOf(ECB),0);
      with ECB do begin
        SocketNumber   := Socket;
        {the high level IPX routines always use two buffer fragments. FD1 }
        {points to the IPX header, and FD2 points to the user data.}
        FragmentCount  := 2;
        with FD1 do begin
          Address := @IPXHead;          {FD1 points to the IPXHeader}
          Size    := SizeOf(IPXHeader);
        end;
        with FD2 do begin
          Address := @DataPacket;       {FD2 points to the user data}
          Size    := DataPacketSize;
        end;
        {init the ImmediateAddress}
        Move(Receiver, ActualTarget, SizeOf(Receiver));             {!!.22}
        if IPXGetLocalTarget(ActualTarget, TransportTime) <> 0 then {!!.22}
          Move(Receiver.Node, ActualTarget.TargetNode,              {!!.22}
               SizeOf(ActualTarget.TargetNode));                    {!!.22}
        Move(ActualTarget.TargetNode,ImmediateAddress,              {!!.22}
             SizeOf(PhysicalNodeAddress));                          {!!.22}
      end;
      {init the IPX Header}
      with IPXHead do begin
        {calculate length and swap bytes for NetWare}
        Len := Swap(SizeOf(IPXHeader) + DataPacketSize);
        {init the Destination record with Network, node and socket info}
        Destination.Network := Receiver.Network;
        Destination.Node := Receiver.Node;
        Destination.Socket := Socket;
      end;
      IPXSendPrim(ECB); {make the send request of IPX}
    end;
    if WaitForCompletion then
      repeat
        IPXRelinquish
      until IPXEventComplete(IPXEvent,Final);
  end;
end;

function IPXListen(var IPXEvent : IPXRec;
                   Socket : Word;
                   WaitForCompletion : Boolean;
                   MaxPacketSize : Word;
                   var DataPacket) : Byte;

{Opens the desired socket (if not open already) and prepares the ECB for
 an IPXListen operation, and calls IPXListen

 It is important to remember that an IPX Listen event can not be assumed
 complete when this function returns. The IPXECB, IPXHeader, and user data
 passed to this function must remain static until this function completes. In
 other words, they must either be global variables, or be declared on the heap
 and not Freed until the operation completes. They should not be local
 variables, unless you can guarantee that the Listen operation will be
 completed or cancelled before the routine that they are local to completes.
}

var
  Final            : Byte;

begin
  Socket := Swap(Socket);
  {check the size of the data passed to make sure it is not too big}
  if MaxPacketSize > (MAXIPXPACKET - SizeOf(IPXHeader)) then
    IPXListen := IPXDataTooLarge
  {note: It is not considered an error if the socket is already open}
  else if IPXOpenSocketPrim(Socket,FALSE) = IPXSocketTableFull then
    IPXListen := IPXSocketTableFull

  else begin
    IPXListen := 0;
    with IPXEvent do begin
      {the FillChar implicitly initializes the ESRAddress to NIL and the }
      {InUse flag to zero}
      FillChar(ECB,SizeOf(ECB),0);
      with ECB do begin
        SocketNumber   := Socket;
        {the high level IPX routines always use two buffer fragments. FD1 }
        {points to the IPX header, and FD2 points to the user data.}
        FragmentCount  := 2;
        with FD1 do begin
          Address := @IPXHead;         {FD1 points to the IPX Header}
          Size    := SizeOf(IPXHeader);
        end;
        with FD2 do begin
          Address := @DataPacket;      {FD2 points to the user data}
          Size    := MaxPacketSize;
        end;
      end;
      IPXListenPrim(ECB);  {submit the listen request to IPX}
    end;
    if WaitForCompletion then
      repeat
        IPXRelinquish
      until IPXEventComplete(IPXEvent,Final);
  end;
end;

{***********************************************************************
  low level SPX routines
***********************************************************************}

{$F+}
function SPXServicesAvailPrim(var Version : Word; var MaxSPXConn : Word;
                              var AvailSPXConn : Word) : Boolean; External;
{ This function Check to see if SPX services are available.  It returns
  TRUE is they are, and FALSE if they are not. If IPX services are available,
  The version number of the SPX driver is returned in the first VAR
  parameter (version major in high byte, minor in low), and the maximum number
  of SPX connections supported and the number of available SPX connections are
  returned in the next two. }

function SPXEstablishConnPrim(RetryCount : Byte; WatchDog : Boolean;
                              var ECB : IPXECB;
                              var AssignedConn : Word) : Byte; External;
{Attemps to establish an SPX connection with a partner client}

procedure SPXListenForConnPrim(Retry : Byte; WatchDog : Boolean;
                               var ECB : IPXECB); External;
{Attemps to establish an SPX connection with a partner client}

procedure SPXTerminateConnPrim(ConnID : Word;
                               var ECB : IPXECB); External;
{Terminates an existing connection (informs partner of intention to do so)}

procedure SPXAbortConnPrim(ConnID : Word); External;
{ Terminates an existing connection (does not inform partner of intention to
  do so).
}

function SPXConnStatus(ConnID : Word;
                       var SPXStatusBuf : SPXStatusBlock) : Boolean; External;
{Returns the status of an SPX connection}

procedure SPXSendPrim(ConnID : Word; var ECB : IPXECB); External;
{The low level SPX send procedure used to request the sending of a sequenced
 packet.
}

procedure SPXListenPrim(var ECB : IPXECB); External;
{The low level SPX listen procedure used to inform NetWare that you are
 expecting the delivery of a sequenced packet.
}
{$IFDEF FMinus}
  {$F-}
{$ENDIF}

{***********************************************************************
  High level SPX routines
***********************************************************************}

function SPXServicesAvail(var Version : Word; var MaxSPXConn : Word;
                          var AvailSPXConn : Word) : Boolean;
{ This function Check to see if SPX services are available.  It returns
  TRUE is they are, and FALSE if they are not. If IPX services are available,
  The version number of the SPX driver is returned in the first VAR
  parameter (version major in high byte, minor in low), and the maximum number
  of SPX connections supported and the number of available SPX connections are
  returned in the next two.

  NOTE: This routine calls IPXServicesAvail first to ensure that it is safe to
  call the SPX Services Available function (which is an IPX call).}

begin
  if IPXServicesAvail then
    SPXServicesAvail := SPXServicesAvailPrim(Version,MaxSPXConn,AvailSPXConn)
  else
    SPXServicesAvail := FALSE;
end;

function SPXEventComplete(var SPXEvent : SPXRec;
                          var FinalResult : Byte;
                          var DataType : Byte) : Boolean;

begin
  with SPXEvent do begin
    IPXRelinquish;
    if ECB.InUse = 0 then begin
      SPXEventComplete := TRUE;
      with ECB do begin
        FinalResult := CompletionCode;
        DataType := SPXHead.DataStreamType;
      end;
    end
    else
      SPXEventComplete := FALSE;
  end;
end;

procedure InitSPXHeaders(var SPXEvent : SPXRec;
                        Add : IPXAddress;
                        Sock : Word);
{ Used by the High level SPX routines to initialize the required fields of the
  SPX Header.
}

begin
  with SPXEvent do begin
    FillChar(SPXHead,SizeOf(SPXHeader),0);
    with SPXHead do
      {init the IPXHeader portion of the SPX header}
      with IPXPacket do begin
        Len := Swap(Word(42));               {swap bytes for NetWare}
        {init the destination record}
        Destination := Add;
        Destination.Socket := Sock;   {!!.41}
        PacketType :=  SPXPACKETTYPE;  {indicate this is an SPX packet}
      end;
  end;
end;

procedure SPXPoolStartListening(var PoolRec : SPXPoolRec);
{Submit all the ECBs in the pool to SPX to Listen for a Sequenced Packet}
var
  I                : Byte;

begin
  with PoolRec do
    for I := 1 to NumInPool do
      SPXListenPrim(Pool^[I].ECB);
end;


function NextInPool(var PoolRec : SPXPoolRec; PoolIndex : Byte) : Byte;
{Given an index into the pool, returns the next index}
begin
  with PoolRec do
    if PoolIndex < NumInPool then
      NextInPool := PoolIndex + 1
    else
      NextInPool := 1;
end;

function PrevInPool(var PoolRec : SPXPoolRec; PoolIndex : Byte) : Byte;
{Given an index into the pool, returns the previous index}

begin
  with PoolRec do
    if PoolIndex > 1 then
      PrevInPool := PoolIndex - 1
    else
      PrevInPool := NumInPool;
end;

function PoolPutQueue(var PoolRec : SPXPoolRec;
                      PoolIndex : Byte) : Boolean;
{Put an index into the PoolQueue}
begin
  with PoolRec do
    if PoolQS < NumInPool then begin
      Inc(PoolQS);
      PoolQueue^[PoolQP] := PoolIndex;
      PoolPutQueue := TRUE;
      PoolQP := NextInPool(PoolRec,PoolQP);
    end
    else
      PoolPutQueue := FALSE;
end;

function PoolGetQueue(var PoolRec : SPXPoolRec;
                      var PoolIndex : Byte) : Boolean;
{Get an index from the PoolQueue}
begin
  with PoolRec do
    if PoolQS > 0 then begin
      Dec(PoolQS);
      PoolIndex := PoolQueue^[PoolQO];
      PoolQO := NextInPool(PoolRec,PoolQO);
      PoolGetQueue := TRUE;
    end
    else
      PoolGetQueue := FALSE;
end;


{$F+}
procedure PoolESR; External;
{The assembly stub of the ESR from IPXSPX.ASM}

{ Stack and range checking must be off for the ESR (S-,R-) }

var
  UserPascalESR    : Pointer;

procedure CallUserESR(var SPXEvent : SPXRec;
                      CompletionCode : Byte;
                      PoolIndex : Byte;
                      DataType : Byte;
                      DataPtr : Pointer);
  inline($FF/$1E/>UserPascalESR); {CALL DWORD PTR [>UserPascalESR]}

procedure PascalPoolESR(var ECB : IPXECB);
{The pascal portion of the ESR.  Submits the ECB of the event occurred to
 the PoolQueue}

var
  RecPtr           : ^SPXRec;

begin
  {First, queue the event, then call user's ESR (if one specified)}
  with ECB do begin
    with FD3 do begin
      RecPtr := Address; {FD3 has the address of the SPXRec in the Address}
                         {field and the PoolIndex number in the Size field}
      with RecPtr^,PoolRec do begin
                      {add this event to the event queue}
        QueueOverflow := not PoolPutQueue(PoolRec,Byte(Size));
        if not QueueOverflow then
          {If user Pascal ESR then call it}
          if FD4.Address <> NIL then begin
            UserPascalESR := FD4.Address;
            CallUserESR(RecPtr^,CompletionCode,Byte(Size),
                        SPXHeader(FD1.Address^).DataStreamType,
                        FD2.Address);
          end
      end;
    end;
  end;
end;
{$F-}

procedure PoolAllocate(NumberOfECBs : Byte;
                       DataBufSize  : Word;
                       var PoolRec  : SPXPoolRec;
                       var Event    : SPXRec;
                       PascalESR    : Pointer);
{Allocates a pool of Listen ECBs with the number of ECBs specified by
 NumberOfECBs. You must specify the maximum size of the data packet that will
 be received by these ECBs. The heap space usage of the Pool can be calculated
 by the equation:

   (NumberOfECBs * SizeOf(PoolECB)) + (NumberOfECBs * DataBufSize)

  The final parameter PascalESR may be used to specify a pointer to an Event
  Service routine coded in Pascal. For most applications, this will be passed
  as NIL. If NIL is specifed, then a default ESR called PascalPoolESR is used.
  This standard ESR simple queues the event for processing. ESRs are in
  essence hardware interrupts that are called in an interrupt disabled state.
  }

var
  I : Byte;

begin
  with PoolRec do begin
    NumInPool := NumberOfECBs;
    DataSize := DataBufSize;
    GetMem(Pool,NumberOfECBs * SizeOf(PoolECB));
    GetMem(PoolQueue,NumberofECBs);
    for I := 1 to NumberOfECBs do begin
      with Pool^[I] do begin
        Header := Event.SPXHead;
        ECB := Event.ECB;
        with ECB do begin
          ESRAddress := @PoolESR;
          FragmentCount := 2;
          with FD1 do begin
            Address := @Header;
            Size := SizeOf(SPXHeader);
          end;
          with FD2 do begin
            if DataBufSize > 0 then
              GetMem(Data,DataBufSize);

            Address := Data;
            Size := DataBufSize;
          end;
          {FD3 is used to store a pool index for this field and to point }
          {to the SPXRec. This allows an ESR to have access to the       }
          {Pool and queue information in the SPXPoolRec and to pass the  }
          {SPXRec to the user ESR (if one exists)}
          with FD3 do begin
            Address := @Event; {the address field of FD3 points to the    }
                               {SPXRec associated with this Event.        }
            Size := I;         {the Size field of FD3 holds the pool index}
          end;
          FD4.Address := PascalESR;
        end;
      end;
    end;
    {init the Pool Queue fields}
    PoolQO := 1;   {queue origin to 1}
    PoolQP := 1;   {queue pointer to 1}
    PoolQS := 0;   {queue size to 0}
    QueueOverflow := FALSE;
  end;
end;

function PoolDeallocate(var PoolRec : SPXPoolRec) : Boolean;
{Frees the heap space used by the SPXPoolRec.  Returns TRUE if memory freed.
 Before freeing the heap space, each ECB's InUse flag is checked, if any ECBs
 in the pool are still in use, this function returns FALSE.}

var
  I : Byte;

begin
  PoolDeallocate := FALSE;
  with PoolRec do begin
    for I := 1 to NumInPool do
      if Pool^[I].ECB.InUse <> 0 then begin
        (*WriteLn('** debug ** Pool item  ',I,' in use');*)  {!!.51}
        Exit;
      end;

    for I := 1 to NumInPool do
      with Pool^[I] do
        if DataSize > 0 then
          if Data <> Nil then                                {!!.51}
            FreeMem(Data,DataSize);
    if PoolQueue <> Nil then                                 {!!.51}
      FreeMem(PoolQueue,NumInPool);
    if Pool <> Nil then                                      {!!.51}
      FreeMem(Pool,NumInPool * SizeOf(PoolECB));
  end;
  PoolDeallocate := TRUE;
end;

function SPXEstablishConn(var SPXEvent : SPXRec;
                          Receiver : IPXAddress;
                          Socket : Word;
                          WaitForCompletion : Boolean;
                          MaxListenDataSize : Word;
                          NumListenPoolECBs : Byte;
                          PoolESRInPascal : Pointer) : Byte;
{The high level SPX function to establish a connection with a partner SPX
 client. This routine isolates the programmer from the details of building the
 SPX header and the Event Control Block. It is designed for use with the
 SPXListenForConn function.

 MaxDataSize is the maximum size for the data buffer for each ECB in the
 Listen ECB Pool. NumPoolECBs is the number of Listen ECBs to allocate for the
 Pool (MUST be at least 1). PoolESRInPascal points to a Pascal ESR (see
 PoolAllocate and PascalPoolESR for more info on ESRs in Pascal). If no user
 ESR is required, pass NIL for this parameter. }

var
  FinalResult      : Byte;
  DType            : Byte;

begin
  Socket := Swap(Socket);
  {note: It is not considered an error if the socket is already open}
  if IPXOpenSocketPrim(Socket,FALSE) = IPXSocketTableFull then
    SPXEstablishConn := IPXSocketTableFull
  else begin
    with SPXEvent do begin
        {the FillChar implicitly initializes the ESRAddress to NIL and the }
        {InUse falg to zero}
        FillChar(ECB,SizeOf(ECB),0);
        {Init the Event Control Block}
        with ECB do begin
          SocketNumber   := Socket;
          {we only use one buffer fragment to initiate a connection}
          FragmentCount  := 1;
          with FD1 do begin
            Address := @SPXHead;    {FD1 points to SPX Header}
            Size    := 42;
          end;
        end;
        {init the SPX headers}
        InitSPXHeaders(SPXEvent,Receiver,Socket);

        if NumListenPoolECBs < 2 then
          NumListenPoolECBs := 2;

        PoolAllocate(NumListenPoolECBs,MaxListenDataSize,PoolRec,SPXEvent,
                     PoolESRInPascal);

        SPXPoolStartListening(PoolRec);

        {call the low level establish connection routine}
        SPXEstablishConn := SPXEstablishConnPrim(SPXRetryCount,SPXWatchDog,
                                                ECB,ConnID);
       if WaitForCompletion then begin
        repeat
          IPXRelinquish;
        until SPXEventComplete(SPXEvent,FinalResult,DType);
      end;
    end;
  end;
end;


function SPXListenForConn(var SPXEvent : SPXRec;
                          Socket : Word;
                          WaitForCompletion : Boolean;
                          MaxDataSize : Word;
                          NumPoolECBs : Byte;
                          PoolESRInPascal : Pointer) : Byte;

{The high level SPX function to establish a connection with a partner SPX
 client. This routine isolates the programmer from the details of building the
 SPX header and the Event Control Block. It is designed for use with the
 SPXEstablishConn function.

 MaxDataSize is the maximum size for the data buffer for each ECB in the
 Listen ECB Pool. NumPoolECBs is the number of Listen ECBs to allocate for the
 Pool (MUST be at least one). PoolESRInPascal points to a Pascal ESR (see
 PoolAllocate and PascalPoolESR for more info on ESRs in Pascal). If no user
 ESR is required, pass NIL for this parameter. }

var
  FinalResult      : Byte;
  DType            : Byte;
  NoNodes          : IPXAddress;

begin
  Socket := Swap(Socket);

  {note: It is not considered an error if the socket is already open}
  if IPXOpenSocketPrim(Socket,FALSE) = IPXSocketTableFull then
    SPXListenForConn := IPXSocketTableFull
  else begin
    SPXListenForConn := 0;
    with SPXEvent do begin
      {the FillChar implicitly initializes the ESRAddress to NIL and the }
      {InUse falg to zero}
      FillChar(ECB,SizeOf(ECB),0);
      FillChar(NoNodes,SizeOf(IPXAddress),0);


      InitSPXHeaders(SPXEvent,NoNodes,Socket);

      {Init the Event Control Block}
      with ECB do begin
        SocketNumber   := Socket;
        FragmentCount  := 1;
        {we only use one buffer fragment to initiate a connection}
        with FD1 do begin
          Address := @SPXHead;  {FD1 points to SPX Header}
          Size    := 42;
        end;
      end;

      if NumPoolECBs < 2 then
        NumPoolECBs := 2;

      PoolAllocate(NumPoolECBs,MaxDataSize,PoolRec,SPXEvent,PoolESRInPascal);
      SPXPoolStartListening(PoolRec);

      {call the low level listen for connection routine}
      SPXListenForConnPrim(SPXRetryCount,SPXWatchDog,ECB);

      if WaitForCompletion then begin
        repeat
          IPXRelinquish;
        until SPXEventComplete(SPXEvent,FinalResult,DType);
      end;
    end;
  end;
end;

procedure SPXSend(var SPXEvent : SPXRec;
                  WaitForCompletion : Boolean;
                  DataType : Byte;
                  DataPacketSize : Word;
                  var DataPacket);

{ The high level SPX function to send a sequenced packet to a connection
  partner. This routine isolates the programmer from the details of building
  the SPX header and the Event Control Block. It is designed for use with the
  SPXListen procedure.
}

var
  FinalResult      : Byte;
  DType            : Byte;

begin
  with SPXEvent do begin
    {init the required fields of the ECB}
    with ECB do begin
      {the high level SPX routines always use two buffer fragments. FD1 }
      {points to the SPX header, and FD2 points to the user data.}
      FragmentCount := 2;
      with FD1 do begin
        Address := @SPXHead;         {point FD1 at the SPX Header}
        Size    := SizeOf(SPXHeader);
      end;
      with FD2 do begin
        Address := @DataPacket;      {point FD2 at the user data}
        Size    := DataPacketSize;
      end;
    end;
    with SPXHead do
      DataStreamType := DataType;  {let SPX know the user defined data type}

    SPXSendPrim(ConnID,ECB); {submit the send request to SPX}
    if WaitForCompletion then
      repeat
          IPXRelinquish;
      until SPXEventComplete(SPXEvent,FinalResult,DType);
  end;
end;
(*
procedure SPXListen(var SPXEvent : SPXRec;
                    WaitForCompletion : Boolean;
                    MaxPacketSize : Word;
                    var DataPacket);

{ The high level SPX function to listen for a sequenced packet from a
  connection partner. This routine isolates the programmer from the details of
  building the SPX header and the Event Control Block. It is designed for use
  with the SPXSend procedure.
}

var
  FinalResult      : Byte;
  DType            : Byte;

begin
  with SPXEvent do begin
    with ECB do begin
      {the high level SPX routines always use two buffer fragments. FD1 }
      {points to the SPX header, and FD2 points to the user data.}
      InUse := 0;
      ESRAddress := NIL;
      FragmentCount := 2;
      with FD1 do begin
        Address := @SPXHead;          {point FD1 at the SPX Header}
        Size    := SizeOf(SPXHeader);
      end;
      with FD2 do begin
        Address := @DataPacket;       {point FD2 at the user data}
        Size    := MaxPacketSize;
      end;
    end;
    SPXListenPrim(ECB);  {submit the listen request to SPX}
    if WaitForCompletion then
      repeat
        IPXRelinquish;
      until SPXEventComplete(SPXEvent,FinalResult,DType);
  end;
end;
*)
procedure PoolTerminateAll(var PoolRec : SPXPoolRec);

var
  I                : Word;

begin
  with PoolRec do
    IPXCloseSocketPrim(Pool^[1].ECB.SocketNumber);
end;

procedure SPXAbortConn(var SPXEvent : SPXRec);

begin
  with SPXEvent do begin                     {!!.07}
    SPXAbortConnPrim(ConnID);
    PoolTerminateAll(PoolRec);               {!!.07}
    if PoolDeallocate(PoolRec) then ;        {!!.07}
  end;                                       {!!.07}
end;

procedure SPXTerminateConn(var SPXEvent : SPXRec);
{Cancels all pending events, terminates the connection, and frees heap space
 used by SPXRec's SPXPoolRec. Returns FALSE if unable to free heap space.}

begin
  with SPXEvent do begin
    SPXTerminateConnPrim(ConnID,ECB);
    while ECB.InUse <> 0 do
      IPXRelinquish;
    PoolTerminateAll(PoolRec);
    if PoolDeallocate(PoolRec) then ;
  end;
end;

{***********************************************************************
  High level SPX ECB Pool routines
***********************************************************************}

function SPXPoolCancelAll(var PoolRec : SPXPoolRec) : Boolean;
{Cancel the entire Pool's events.  Does this by closing and reopening the
 socket associated with the pool.  Returns false if the socket cannot be
 reopened.}
var
  I                : Word;
  SN               : Word;

begin
  with PoolRec do begin
    SN := Pool^[1].ECB.SocketNumber;
    IPXCloseSocketPrim(SN);
    for I := 1 to 10000 do ;
    SPXPoolCancelAll := IPXOpenSocketPrim(SN,PoolSocketLongevity) = 0;
  end;
end;

function SPXPoolECBPtr(var PoolRec : SPXPoolRec; PoolIndex : Byte) : ECBPtr;
{returns a pointer to the ECB in PoolRec at PoolIndex}
begin
  with PoolRec do
    SPXPoolECBPtr := @Pool^[PoolIndex].ECB;
end;

function SPXPoolDataPtr(var PoolRec : SPXPoolRec; PoolIndex : Byte) : Pointer;
{returns the data pointer for the PoolIndex element of PoolRec}
begin
  with PoolRec do
    SPXPoolDataPtr := Pool^[PoolIndex].Data;
end;

function SPXListenPooled(var SPXEvent : SPXRec;
                         var CompleteCode : Byte;
                         var PoolIndex : Byte;
                         var DataType : Byte;
                         var DataPtr : Pointer) : Boolean;

begin
  IPXRelinquish;

  if PoolGetQueue(SPXEvent.PoolRec,PoolIndex) then begin
    SPXListenPooled := TRUE;
    with SPXEvent do begin
      DataType := PoolRec.Pool^[PoolIndex].Header.DataStreamType; {!!.01}
      CompleteCode := SPXPoolECBPtr(PoolRec,PoolIndex)^.CompletionCode;
      DataPtr := SPXPoolDataPtr(PoolRec,PoolIndex);
    end;
  end
  else
    SPXListenPooled := FALSE;
end;

procedure SPXReplenishPool(var SPXEvent : SPXRec; PoolIndex : Byte);
{Submit specified element of the SPX Listen pool back to SPX for listening}

begin
  with SPXEvent do
    if (PoolIndex >= 1) and (PoolIndex <= PoolRec.NumInPool) then
      with PoolRec.Pool^[PoolIndex] do
        if ECB.InUse = 0 then begin             {!!.40}
(*                                              {!!.41}
          if PoolRec.PoolQS > 0 then            {!!.40}
            Dec(PoolRec.PoolQS);                {!!.40}
*)                                              {!!.41}
          SPXListenPrim(ECB);
        end;                                    {!!.40}
end;

procedure SPXReplenishAll(var SPXEvent : SPXRec);
{Submit each unused ECB to the SPX for a listen event}
var
  I                : Byte;
begin
  with SPXEvent.PoolRec do
    for I := 1 to NumInPool do
      with Pool^[I] do
        if ECB.InUse = 0 then
          SPXListenPrim(ECB);
end;

function SPXListenCount(var SPXEvent : SPXRec) : Byte;
{Return the number of ECBs currently listening in the pool}
var
  Num,I : Byte;

begin
  Num := 0;
  with SPXEvent.PoolRec do
    for I := 1 to NumInPool do
      if Pool^[I].ECB.InUse <> 0 then
        Inc(Num);
  SPXListenCount := Num;
end;

