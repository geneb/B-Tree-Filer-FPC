{*********************************************************}
{*                  IPXSPXD.PAS 5.41                     *}
{*        Copyright (c) TurboPower Software 1991.        *}
{*                 All rights reserved.                  *}
{*********************************************************}

{--Conditional defines and compiler options}
  {$I BTDefine.Inc}
  {$F-,V-,B-,S-,I-,R-}
  {$IFDEF CanAllowOverlays}
    {$F+,O+,A-}
  {$ENDIF}
  {$IFDEF CanSetOvrflowCheck}
    {$Q-}
  {$ENDIF}

{$IFNDEF DPMIOrWnd}
  ** Error ** This file is for TPW or DPMI only
{$ENDIF}

{$C FIXED}

Library IPXSPXD;

uses
  {$IFDEF Windows}
  WinDos, WinProcs, WinTypes,
  {$ELSE}
  Dos,
  {$ENDIF}
  WinDPMI,
  NetWare;

const
  MAXIPXPACKET     = 576;
  IPXServicesAvailable : Boolean = False;
  SPXWatchDog      : Boolean = FALSE; {do not use SPX watchdog services}
  SPXRetryCount    : Byte = 0; {indicates to use the default retry count}
  IPXModifier      : Word = $8000;
var
  IPXLocation : Pointer;

  function GetSPXWatchdog : Boolean; Export;
  begin
    GetSPXWatchdog := SPXWatchDog;
  end;

  procedure SetSPXWatchdog(On : Boolean); Export;
  begin
    SPXWatchDog := On;
  end;

  function GetSPXRetryCount : Byte; Export;
  begin
    GetSPXRetryCount := SPXRetryCount;
  end;

  procedure SetSPXRetryCount(Retries : Byte); Export;
  begin
    SPXRetryCount := Retries;
  end;

  procedure IPXCall(var Regs : DPMIRegisters); Export;
  begin
    with Regs do begin
      CS := SegOfs(IPXLocation).Segm;
      IP := SegOfs(IPXLocation).Ofst;
      BX := BX or IPXModifier;
      Flags := GetCPUFlags;
    end;
    CallFarRealModeProc(0, Regs);
  end;

  function IPXInstalled : Boolean; Export;

  var
    NovRegs          : Registers;

  begin
    with NovRegs do begin
      AX := $7A00;             {func 7Ah of int 2Fh is used to detect IPX}
      WinIntr($2F,NovRegs);
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

  function IPXServicesAvail : Boolean; Export;
  begin
    IPXServicesAvail := IPXServicesAvailable;
  end;

  function IpxOpenSocketPrim(RequestedSocket : Word; Forever : Boolean) : Byte; Export;
  var
    Regs : DPMIRegisters;
  begin
    FillChar(Regs, SizeOf(Regs), 0);
    with Regs do begin
      BX := 0;
      if Forever then
        AX := $FF
      else
        AX := 0;
      DX := RequestedSocket;
    end;
    IPXCall(Regs);
    IpxOpenSocketPrim := Lo(DoubleWord(Regs.AX).LoWord);
  end;

  procedure IpxCloseSocketPrim(RequestedSocket : Word); Export;
  var
    Regs : DPMIRegisters;
  begin
    FillChar(Regs, SizeOf(Regs), 0);
    with Regs do begin
      BX := 1;
      DX := RequestedSocket;
    end;
    IPXCall(Regs);
  end;

  function IPXOpenSocket(RequestedSocket : Word;
                         Forever : Boolean) : Byte; Export;
  begin
    IpxOpenSocket := IpxOpenSocketPrim(Swap(RequestedSocket), Forever);
  end;

  procedure IPXCloseSocket(SocketNum : Word); Export;
  begin
    IPXCloseSocketPrim(Swap(SocketNum));
  end;

  function IPXAssignUniqueSocket(var ReturnedSocket : Word; Forever : Boolean) : Word; Export;
  var
    Regs : DPMIRegisters;
  begin
    FillChar(Regs, SizeOf(Regs), 0);
    with Regs do begin
      BX := 0;
      DX := 0;
      if Forever then
        AX := $FF
      else
        AX := 0;
      IPXCall(Regs);
      ReturnedSocket := Swap(Word(DX));
      IPXAssignUniqueSocket := Lo(DoubleWord(Regs.AX).LoWord);
    end;
  end;

  procedure IPXSendPrim(ECBP : ECBPtr); Export;
  var
    Regs : DPMIRegisters;
  begin
    FillChar(Regs, SizeOf(Regs), 0);
    with Regs do begin
      BX := 3;
      ES := SegOfs(ECBP).Segm;
      SI := SegOfs(ECBP).Ofst;
      IPXCall(Regs);
    end;
  end;

  procedure IPXListenPrim(ECBP : ECBPtr); Export;
  var
    Regs : DPMIRegisters;
  begin
    FillChar(Regs, SizeOf(Regs), 0);
    with Regs do begin
      BX := 4;
      ES := SegOfs(ECBP).Segm;
      SI := SegOfs(ECBP).Ofst;
      IPXCall(Regs);
    end;
  end;

  function IPXCancelEventPrim(ECBP : ECBPtr) : Byte; Export;
  var
    Regs : DPMIRegisters;
  begin
    FillChar(Regs, SizeOf(Regs), 0);
    with Regs do begin
      BX := 6;
      ES := SegOfs(ECBP).Segm;
      SI := SegOfs(ECBP).Ofst;
      IPXCall(Regs);
      IPXCancelEventPrim := Lo(DoubleWord(Regs.AX).LoWord);
    end;
  end;

  procedure IPXRelinquish; Export;
  var
    Regs : DPMIRegisters;
  begin
    FillChar(Regs, SizeOf(Regs), 0);
    with Regs do begin
      BX := $0A;
      IPXCall(Regs);
    end;
  end;

  procedure IPXInternetAddress(var Address : IPXAddress); Export;
  var
    Regs : DPMIRegisters;
    P, R : Pointer;
  begin
    if not GetRealModeMem(SizeOf(Address), R, P) then
      Exit;
    FillChar(P^, SizeOf(Address), 0);
    FillChar(Regs, SizeOf(Regs), 0);
    with Regs do begin
      BX := $09;
      ES := SegOfs(R).Segm;
      SI := SegOfs(R).Ofst;
      IPXCall(Regs);
    end;
    Move(P^, Address, SizeOf(Address));
    FreeRealModeMem(P);
  end;

  procedure IPXScheduleEvent(DelayTime : Word; ECB : WinIPXECB); Export;
  var
    Regs : DPMIRegisters;
  begin
    FillChar(Regs, SizeOf(Regs), 0);
    with Regs do begin
      AX := DelayTime;
      BX := $05;
      ES := SegOfs(ECB.ECBR).Segm;
      SI := SegOfs(ECB.ECBR).Ofst;
      IPXCall(Regs);
    end;
  end;

  procedure IPXScheduleSpecialEvent(DelayTime : Word;
                                    ECB : WinAESECB); Export;
  var
    Regs : DPMIRegisters;
    ECBP : Pointer absolute ECB;
  begin
    FillChar(Regs, SizeOf(Regs), 0);
    with Regs do begin
      AX := DelayTime;
      BX := $07;
      ES := SegOfs(ECB.AESECBR).Segm;
      SI := SegOfs(ECB.AESECBR).Ofst;
      IPXCall(Regs);
    end;
  end;


  function IPXGetIntervalMarker : Word; Export;
  var
    Regs : DPMIRegisters;
  begin
    FillChar(Regs, SizeOf(Regs), 0);
    with Regs do begin
      BX := $08;
      IPXCall(Regs);
      IPXGetIntervalMarker := DoubleWord(Regs.AX).LoWord;
    end;
  end;

  function IPXGetLocalTarget(var LocalTarget : TargetType;
                             var TransportTime : Word) : Byte; Export;
  var
    Ret : Byte;                                           {!!.40}
    Regs : DPMIRegisters;
    LT : Pointer;
    LTP : Pointer;
  begin
    if not GetRealModeMem(SizeOf(LocalTarget), LT, LTP) then begin
      IPXGetLocalTarget := 0;
      Exit;
    end;
    Move(LocalTarget, LTP^, SizeOf(LocalTarget));
    FillChar(Regs, SizeOf(Regs), 0);
    with Regs do begin
      BX := $02;
      ES := SegOfs(LT).Segm;
      DI := SegOfs(LT).Ofst + 12;
      IpxCall(Regs);
      TransportTime := CX;
      Ret := Lo(DoubleWord(Regs.AX).LoWord);              {!!.40}
    end;
    if Ret = 0 then                                       {!!.40}
      Move(LTP^, LocalTarget, SizeOf(LocalTarget));       {!!.40}
    FreeRealModeMem(LTP);
    IPXGetLocalTarget := Ret;
  end;

function IPXEventComplete(IPXEvent : WinIPXRec;
                          var FinalResult : Byte) : Boolean; Export;

begin
  with IPXEvent.wirP^ do begin
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


function IPXCancelEvent(IPXEvent : WinIPXRec) : Byte; Export;

begin
  with IPXEvent do
    IPXCancelEvent := IPXCancelEventPrim(Ptr(SegOfs(wirR).Segm,
                                         SizeOf(IPXAddress)));
end;

function AllocateWinIPXRec(DataSize : Word;
                           var Event : WinIPXRec) : Boolean; Export;
begin
  with Event do
    AllocateWinIPXRec := GetRealModeMem(SizeOf(IPXRec) + DataSize,
                                        Pointer(wirR),
                                        Pointer(wirP));
end;

procedure FreeWinIPXRec(Event : WinIPXRec); Export;
begin
  FreeRealModeMem(Pointer(Event.wirP));
end;

function AllocateWinAESECB(DataSize : Word;
                           var ECB : WinAESECB) : Boolean; Export;
begin
  with ECB do
    AllocateWinAESECB := GetRealModeMem(SizeOf(AESECB),
                                        Pointer(AESECBR),
                                        Pointer(AESECBP));
end;

procedure FreeWinAESECB(ECB : WinAESECB); Export;
begin
  FreeRealModeMem(Pointer(ECB.AESECBP));
end;

function IPXSend(IPXEvent : WinIPXRec;
                 Receiver : IPXAddress;
                 Socket : Word;
                 WaitForCompletion : Boolean;
                 DataPacketSize : Word;
                 var DataPacket) : Byte; Export;


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
  DataP            : Pointer;
  ECBP             : ECBPtr;
  RealSeg          : Word;
begin
  DataP := IPXEvent.wirP;
  Inc(Word(DataP), SizeOf(IPXRec));
  Move(DataPacket, DataP^, DataPacketSize);
  Socket := Swap(Socket);
  RealSeg := SegOfs(IPXEvent.wirR).Segm;
  {check the size of the data passed to make sure it is not too big}
  if DataPacketSize > (MAXIPXPACKET - SizeOf(IPXHeader)) then
    IPXSend := IPXDataTooLarge
  {note: It is not considered an error if the socket is already open}
  else if IPXOpenSocketPrim(Socket,FALSE) = IPXSocketTableFull then
    IPXSend := IPXSocketTableFull {can't open any more sockets}
  else begin
    IPXSend := 0;
    with IPXEvent.wirP^ do begin
      {the FillChar implicitly initializes the ESRAddress to NIL and the }
      {InUse flag to zero}
      FillChar(ECB,SizeOf(ECB),0);
      FillChar(IPXHead, SizeOf(IPXHead), 0);
      with ECB do begin
        SocketNumber   := Socket;
        {the high level IPX routines always use two buffer fragments. FD1 }
        {points to the IPX header, and FD2 points to the user data.}
        FragmentCount  := 2;
        with FD1 do begin
          Address := Ptr(RealSeg, Ofs(IPXHead));  {FD1 points to the IPXHeader}
          Size    := SizeOf(IPXHeader);
        end;
        with FD2 do begin
          Address := Ptr(RealSeg, SizeOf(IPXRec));{FD2 points to the user data}
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
      ECBP := Ptr(RealSeg, SizeOf(IPXHeader));
      IPXSendPrim(ECBP); {make the send request of IPX}
    end;
    if WaitForCompletion then
      repeat
        IPXRelinquish
      until IPXEventComplete(IPXEvent,Final);
  end;
end;

function IPXListen(IPXEvent : WinIPXRec;
                   Socket : Word;
                   WaitForCompletion : Boolean;
                   MaxPacketSize : Word;
                   var DataPacket) : Byte; Export;

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
  DataP            : Pointer;
  ECBP             : ECBPtr;
  RealSeg          : Word;

begin
  DataP := IPXEvent.wirP;
  Inc(Word(DataP), SizeOf(IPXRec));
  RealSeg := SegOfs(IPXEvent.wirR).Segm;
  Socket := Swap(Socket);
  {check the size of the data passed to make sure it is not too big}
  if MaxPacketSize > (MAXIPXPACKET - SizeOf(IPXHeader)) then
    IPXListen := IPXDataTooLarge
  {note: It is not considered an error if the socket is already open}
  else if IPXOpenSocketPrim(Socket,FALSE) = IPXSocketTableFull then
    IPXListen := IPXSocketTableFull

  else begin
    IPXListen := 0;
    with IPXEvent.wirP^ do begin
      {the FillChar implicitly initializes the ESRAddress to NIL and the }
      {InUse flag to zero}
      FillChar(ECB,SizeOf(ECB),0);
      FillChar(IPXHead, SizeOf(IPXHead), 0);   {!!.40}
      with ECB do begin
        SocketNumber   := Socket;
        {the high level IPX routines always use two buffer fragments. FD1 }
        {points to the IPX header, and FD2 points to the user data.}
        FragmentCount  := 2;
        with FD1 do begin
          Address := Ptr(RealSeg, Ofs(IPXHead)); {FD1 points to the IPX Header}
          Size    := SizeOf(IPXHeader);
        end;
        with FD2 do begin
          Address := Ptr(RealSeg, SizeOf(IPXRec));{FD2 points to the user data}
          Size    := MaxPacketSize;
        end;
      end;
      ECBP := Ptr(RealSeg, SizeOf(IPXHeader));
      IPXListenPrim(ECBP);  {submit the listen request to IPX}
    end;
    if WaitForCompletion then begin
      repeat
        IPXRelinquish
      until IPXEventComplete(IPXEvent,Final);
      Move(DataP^, DataPacket, MaxPacketSize);                 {!!.41}
                                            {!!.41 Dereferenced DataP}
    end;
  end;
end;

function SPXServicesAvailPrim(var Version : Word; var MaxSPXConn : Word;
                              var AvailSPXConn : Word) : Boolean; Export;
{ This function Check to see if SPX services are available.  It returns
  TRUE is they are, and FALSE if they are not. If IPX services are available,
  The version number of the SPX driver is returned in the first VAR
  parameter (version major in high byte, minor in low), and the maximum number
  of SPX connections supported and the number of available SPX connections are
  returned in the next two. }
var
  Regs : DPMIRegisters;
begin
  FillChar(Regs, SizeOf(Regs), 0);
  with Regs do begin
    BX := $10;
    AX := 0;
    IPXCall(Regs);
    if Lo(DoubleWord(AX).LoWord) = $FF then begin
      Version := DoubleWord(BX).LoWord;
      MaxSPXConn := DoubleWord(CX).LoWord;
      AvailSPXConn := DoubleWord(DX).LoWord;
      SpxServicesAvailPrim := True;
    end
    else
      SPXServicesAvailPrim := False;
  end;
end;

function SPXEstablishConnPrim(RetryCount : Byte; WatchDog : Boolean;
                              ECB : ECBPtr;
                              var AssignedConn : Word) : Byte; Export;
{Attemps to establish an SPX connection with a partner client}
var
  Regs : DPMIRegisters;
begin
  FillChar(Regs, SizeOf(Regs), 0);
  with Regs do begin
    BX := $11;
    AX := (Word(WatchDog) shl 8) + RetryCount;
    ES := SegOfs(ECB).Segm;
    SI := SegOfs(ECB).Ofst;
    IPXCall(Regs);
    AssignedConn := DoubleWord(DX).LoWord;
    SPXEstablishConnPrim := Lo(DoubleWord(AX).LoWord);
  end;
end;

procedure SPXListenForConnPrim(Retry : Byte; WatchDog : Boolean;
                               ECB : ECBPtr); Export;
{Attemps to establish an SPX connection with a partner client}
var
  Regs : DPMIRegisters;
begin
  FillChar(Regs, SizeOf(Regs), 0);
  with Regs do begin
    BX := $12;
    AX := (Word(WatchDog) shl 8) + Retry;
    ES := SegOfs(ECB).Segm;
    SI := SegOfs(ECB).Ofst;
    IPXCall(Regs);
  end;
end;

procedure SPXTerminateConnPrim(ConnID : Word;
                               ECB : ECBPtr); Export;
{Terminates an existing connection (informs partner of intention to do so)}
var
  Regs : DPMIRegisters;
begin
  FillChar(Regs, SizeOf(Regs), 0);
  with Regs do begin
    BX := $13;
    DX := ConnID;
    ES := SegOfs(ECB).Segm;
    SI := SegOfs(ECB).Ofst;
    IPXCall(Regs);
  end;
end;

procedure SPXAbortConnPrim(ConnID : Word); Export;
{ Terminates an existing connection (does not inform partner of intention to
  do so).
}
var
  Regs : DPMIRegisters;
begin
  FillChar(Regs, SizeOf(Regs), 0);
  with Regs do begin
    BX := $14;
    DX := ConnID;
    IPXCall(Regs);
  end;
end;

function SPXConnStatus(ConnID : Word;
                       var SPXStatusBuf : SPXStatusBlock) : Boolean; Export;
{Returns the status of an SPX connection}
var
  Regs : DPMIRegisters;
  R, P : ^SPXStatusBlock;
begin
  if not GetRealModeMem(SizeOf(SPXStatusBuf), Pointer(R), Pointer(P)) then begin
    SPXConnStatus := False;
    Exit;
  end;
  FillChar(Regs, SizeOf(Regs), 0);
  with Regs do begin
    BX := $15;
    DX := ConnID;
    ES := SegOfs(R).Segm;
    SI := SegOfs(R).Ofst;
    IPXCall(Regs);
    Move(P^, SPXStatusBuf, SizeOf(SPXStatusBuf));
    SPXConnStatus := Lo(DoubleWord(AX).LoWord) = 0;
  end;
  FreeRealModeMem(Pointer(P));
end;

procedure SPXSendPrim(ConnID : Word; ECB : ECBPtr); Export;
{The low level SPX send procedure used to request the sending of a sequenced
 packet.
}
var
  Regs : DPMIRegisters;
begin
  FillChar(Regs, SizeOf(Regs), 0);
  with Regs do begin
    BX := $16;
    DX := ConnID;
    ES := SegOfs(ECB).Segm;
    SI := SegOfs(ECB).Ofst;
    IPXCall(Regs);
  end;
end;

procedure SPXListenPrim(ECB : ECBPtr); Export;
{The low level SPX listen procedure used to inform NetWare that you are
 expecting the delivery of a sequenced packet.
}
var
  Regs : DPMIRegisters;
begin
  FillChar(Regs, SizeOf(Regs), 0);
  with Regs do begin
    BX := $17;
    ES := SegOfs(ECB).Segm;
    SI := SegOfs(ECB).Ofst;
    IPXCall(Regs);
  end;
end;

{***********************************************************************
  High level SPX routines
***********************************************************************}

function SPXServicesAvail(var Version : Word; var MaxSPXConn : Word;
                          var AvailSPXConn : Word) : Boolean; Export;
{ This function Check to see if SPX services are available.  It returns
  TRUE is they are, and FALSE if they are not. If IPX services are available,
  The version number of the SPX driver is returned in the first VAR
  parameter (version major in high byte, minor in low), and the maximum number
  of SPX connections supported and the number of available SPX connections are
  returned in the next two.

  NOTE: This routine calls IPXServicesAvail first to ensure that it is safe to
  call the SPX Services Available function (which is an IPX call).}

begin
  if IPXInstalled then
    SPXServicesAvail := SPXServicesAvailPrim(Version,MaxSPXConn,AvailSPXConn)
  else
    SPXServicesAvail := FALSE;
end;

function SPXEventComplete(SPXEvent : WinSPXRec;
                          var FinalResult : Byte;
                          var DataType : Byte) : Boolean; Export;

begin
  with SPXEvent.wsrP^, ECB, ECBP^ do begin
    IPXRelinquish;
    if InUse = 0 then begin
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

procedure InitSPXHeaders(SPXEvent : WinSPXRec;
                         Add : IPXAddress); Export;
{ Used by the High level SPX routines to initialize the required fields of the
  SPX Header.
}

begin
  with SPXEvent.wsrP^ do begin
    FillChar(SPXHead,SizeOf(SPXHeader),0);
    with SPXHead do
      {init the IPXHeader portion of the SPX header}
      with IPXPacket do
        {init the destination record}
        Destination := Add;
  end;
end;

procedure SPXPoolStartListening(var PoolRec : WinSPXPoolRec); Export;
{Submit all the ECBs in the pool to SPX to Listen for a Sequenced Packet}
var
  I                : Byte;

begin
  with PoolRec, prP^ do
    for I := 1 to NumInPool do
      SPXListenPrim(PoolP^[I].wpeP^.ECB.ECBR);
end;


function NextInPool(var PoolRec : SPXPoolRec; PoolIndex : Byte) : Byte; Export;
{Given an index into the pool, returns the next index}
begin
  with PoolRec do
    if PoolIndex < NumInPool then
      NextInPool := PoolIndex + 1
    else
      NextInPool := 1;
end;

function PrevInPool(var PoolRec : SPXPoolRec; PoolIndex : Byte) : Byte; Export;
{Given an index into the pool, returns the previous index}

begin
  with PoolRec do
    if PoolIndex > 1 then
      PrevInPool := PoolIndex - 1
    else
      PrevInPool := NumInPool;
end;

function PoolPutQueue(var PoolRec : SPXPoolRec;
                      PoolIndex : Byte) : Boolean; Export;
{Put an index into the PoolQueue}
begin
  with PoolRec do
    if PoolQS < NumInPool then begin
      Inc(PoolQS);
      PoolQueueP^[PoolQP] := PoolIndex;
      PoolPutQueue := TRUE;
      PoolQP := NextInPool(PoolRec,PoolQP);
    end
    else
      PoolPutQueue := FALSE;
end;

function PoolGetQueue(var PoolRec : SPXPoolRec;
                      var PoolIndex : Byte) : Boolean; Export;
{Get an index from the PoolQueue}
begin
  with PoolRec do
    if PoolQS > 0 then begin
      Dec(PoolQS);
      PoolIndex := PoolQueueP^[PoolQO];
      PoolQO := NextInPool(PoolRec,PoolQO);
      PoolGetQueue := TRUE;
    end
    else
      PoolGetQueue := FALSE;
end;

procedure PascalPoolESR(wpeP : PoolECBPtr); Far;
var
  RecPtr           : ^WinSPXRec;
  UserESR          : UserESRType;
  Index            : Byte;
begin
  {First, queue the event, then call user's ESR (if one specified)}
  with wpeP^, ECB, ECBP^ do begin
    with FD3 do begin
      RecPtr := Address; {FD3 has the address of the WinSPXRec in the Address}
                         {field and the PoolIndex number in the Size field}
      with RecPtr^, wsrP^, PoolRec.prP^ do begin
                      {add this event to the event queue}
        QueueOverflow := not PoolPutQueue(PoolRec.prP^,Byte(Size));
        if not QueueOverflow then
          {If user Pascal ESR then call it}
          if FD4.Address <> NIL then begin
            @UserESR := FD4.Address;
            with PoolP^[Byte(Size)].wpeP^ do
              UserESR(RecPtr^, CompletionCode, Byte(Size),
                      Header.DataStreamType,
                      DataP);
          end;
      end;
    end;
  end;
end;
procedure CallbackShell; Near; Assembler;
asm
  mov     ax,1681h
  int     2Fh
  push    di
  push    es
  mov     ax,[si]                              {grab return addr off real stack}
  mov     dx,[si+2]
  mov     es:[di].WinESRType.Regs.drIP,ax      {put ret addr into DPMI Regs}
  mov     es:[di].WinESRType.Regs.drCS,dx
  add     es:[di].WinESRType.Regs.drSP, 4
  mov     dx,es:[di].WinESRType.Regs.drES      {get real mode ptr to ECB}
  mov     ax,word ptr es:[di].WinESRType.Regs.drSI
  lds     si,es:[di].WinESRType.PoolPtr        {grab prot mode ptr to PoolRec}
  mov     cl,[si].SPXPoolRec.NumInPool         {num in pool for loop counter}
  xor     ch,ch
  jcxz    @@ExitPoint
  lds     si,[si].SPXPoolRec.PoolP             {ds:si points to pool of ECBs}
  push    ds                                   {save ds:si for later}
  push    si
  xor     bx,bx                                {start at first element}
{now we find the real mode ptr to the ECB in the pool so we can access the
 protected mode ptr}
@@Next:
  les     di,[si+bx].WinPoolECB.wpeP           {es:di gets elements addr}
  cmp     word ptr es:[di].PoolECB.ECB.ECBR,ax {cmp to our real mode ECB ptr}
  jne     @@NoMatch
  cmp     word ptr es:[di].PoolECB.ECB.ECBR+2,dx
  je      @@Match                              {bingo, call Pascal ESR}
@@NoMatch:
  add     bx,8                                 {point to next element}
  loop    @@Next
  pop     si                                   {no match so just exit}
  pop     ds
  jmp     @@ExitPoint
@@Match:
  pop     si
  pop     ds
  pop     es
  pop     di
  push    di
  push    es
  push    word ptr [si+bx+2].WinPoolECB.wpeP   {push prot mode ptr to pool ecb}
  push    word ptr [si+bx].WinPoolECB.wpeP
  mov     ax,es:[di].WinESRType.DataSegm       {setup correct DS}
  mov     ds,ax
  call    PascalPoolESR                        {call Pascal ESR handler}
@@ExitPoint:
  pop     es
  pop     di
  mov     ax,1682h
  int     2Fh
  iret
end;

function AllocateWindowsESR(EventServiceRoutine : UserESRType;
                            DataSegment : Word;
                            var WindowsESR : WinESRType) : Boolean; Export;
begin
  with WindowsESR do begin
    FillChar(WindowsESR, SizeOf(WindowsESR), 0);
    AllocateRealModeCallbackAddr(@CallbackShell, DPMIRegisters(Regs), Callback);
    UserESR := EventServiceRoutine;
    DataSegm := DataSegment;
    AllocateWindowsESR := LongInt(Callback) <> 0;
  end;
end;

procedure FreeWindowsESR(var WindowsESR : WinESRType); Export;
begin
  FreeRealModeCallbackAddr(WindowsESR.Callback);
end;

function PoolAllocate(NumberOfECBs : Byte;
                       DataBufSize  : Word;
                       var PoolRec  : WinSPXPoolRec;
                       var Event    : WinSPXRec;
                       var WinESR : WinESRType) : Boolean; Export;
{-Allocates a pool of Listen ECBs with the number of ECBs specified by
  NumberOfECBs. You must specify the maximum size of the data packet that will
  be received by these ECBs. The real mode memory usage of the Pool can be
  calculated by the equation:

  SizeOf(SPXPoolRec) +
  (NumberOfECBs * (Sizeof(PoolECB) + SizeOf(WinPoolECB) + DataBufSize) +
  NumberOfECBs

  This size must be less than 65535. This function will return FALSE if
  insufficient real mode memory (or size > 65535).
}

var
  I : Byte;
  Size : LongInt;
  P, R : Pointer;
begin
  PoolAllocate := False;
  Size := LongInt(SizeOf(SPXPoolRec)) +
          (NumberOfECBs * (Sizeof(PoolECB) +
                           SizeOf(WinPoolECB) +
                           SizeOf(IPXECB) +
                           DataBufSize)) +
          NumberOfECBs;
  if Size > LongInt($FFFF) then
    Exit;
  if not GetRealModeMem(Size, R, P) then
    Exit;
  FillChar(P^, Size, 0);
  with PoolRec do begin
    prP := P;
    prR := R;
    Inc(Word(P), SizeOf(SPXPoolRec));
    Inc(Word(R), SizeOf(SPXPoolRec));
  end;
  with PoolRec.prP^ do begin
    NumInPool := NumberOfECBs;
    DataSize := DataBufSize;
    PoolP := P;
    PoolR := R;
    Inc(Word(P), NumberOfECBs * SizeOf(WinPoolECB));
    Inc(Word(R), NumberOfECBs * SizeOf(WinPoolECB));
    PoolQueueP := P;
    PoolQueueR := R;
    Inc(Word(P), NumberOfECBs);
    Inc(Word(R), NumberOfECBs);
    for I := 1 to NumberOfECBs do begin
      with PoolP^[I] do begin
        wpeR := R;
        wpeP := P;
        Inc(Word(P), SizeOf(PoolECB));
        Inc(Word(R), SizeOf(PoolECB));
        with wpeP^ do begin
          Header := Event.wsrP^.SPXHead;
          with ECB do begin
            ECBR := R;
            ECBP := P;
            Inc(Word(P), SizeOf(IPXECB));
            Inc(Word(R), SizeOf(IPXECB));
          end;
          ECB.ECBP^ := Event.wsrP^.ECB.ECBP^;
          with ECB, ECBP^ do begin
            if WinESR.Callback <> Nil then begin
              ESRAddress := WinESR.Callback;
              WinESR.PoolPtr := PoolRec.prP;
            end
            else
              ESRAddress := Nil;
            FragmentCount := 2;
            with FD1 do begin
              Address := Ptr(SegOfs(wpeR).Segm, SegOfs(wpeR).Ofst + SizeOf(WinIPXECB));
              Size := SizeOf(SPXHeader);
            end;
            with FD2 do begin
              if DataBufSize > 0 then begin
                DataR := R;
                DataP := P;
                Inc(Word(P), DataBufSize);
                Inc(Word(R), DataBufSize);
              end;
              Address := DataR;
              Size := DataBufSize;
            end;
            {FD3 is used to store a pool index for this field and to point }
            {to the SPXRec. This allows an ESR to have access to the       }
            {Pool and queue information in the SPXPoolRec and to pass the  }
            {SPXRec to the user ESR (if one exists)}
            with FD3 do begin
              Address := @Event;     {the address field of FD3 points (prot. mode}
                                     { ptr) to the SPXRec associated with       }
                                     {this Event.}
              Size := I;             {the Size field of FD3 holds the pool index}
            end;
            FD4.Address := @WinESR.UserESR;
          end;
        end;
      end;
    end;
    {init the Pool Queue fields}
    PoolQO := 1;   {queue origin to 1}
    PoolQP := 1;   {queue pointer to 1}
    PoolQS := 0;   {queue size to 0}
    QueueOverflow := FALSE;
  end;
  PoolAllocate := True;
end;

function PoolDeallocate(var PoolRec : WinSPXPoolRec) : Boolean; Export;
{Frees the heap space used by the SPXPoolRec.  Returns TRUE if memory freed.
 Before freeing the heap space, each ECB's InUse flag is checked, if any ECBs
 in the pool are still in use, this function returns FALSE.}

var
  I : Byte;

begin
  PoolDeallocate := FALSE;
  with PoolRec.prP^ do
    for I := 1 to NumInPool do
      if PoolP^[I].wpeP^.ECB.ECBP^.InUse <> 0 then
        (*WriteLn('** debug ** Pool item  ',I,' in use');*)  {!!.51}
        Exit;
  FreeRealModeMem(Pointer(PoolRec.prP));
  PoolDeallocate := TRUE;
end;

function SPXEstablishConn(var SPXEvent : WinSPXRec;
                          Receiver : IPXAddress;
                          Socket : Word;
                          WaitForCompletion : Boolean;
                          MaxListenDataSize : Word;
                          NumListenPoolECBs : Byte;
                          var WinESR : WinESRType) : Byte; Export;

var
  FinalResult      : Byte;
  DType            : Byte;

begin
  Socket := Swap(Socket);
  {note: It is not considered an error if the socket is already open}
  if IPXOpenSocketPrim(Socket,FALSE) = IPXSocketTableFull then
    SPXEstablishConn := IPXSocketTableFull
  else begin
    with SPXEvent, wsrP^ do begin
        {the FillChar implicitly initializes the ESRAddress to NIL and the }
        {InUse flag to zero}
        FillChar(ECB.ECBP^,SizeOf(IPXECB),0);
        {Init the Event Control Block}
        with ECB, ECBP^ do begin
          SocketNumber   := Socket;
          {we only use one buffer fragment to initiate a connection}
          FragmentCount  := 1;
          with FD1 do begin
            Address := Ptr(SegOfs(wsrR).Segm, SegOfs(wsrR).Ofst + SizeOf(Word));{FD1 points to SPX Header}
            Size    := 42;
          end;
        end;
        {init the SPX headers}
        Receiver.Socket := Socket; {!!.41}
        InitSPXHeaders(SPXEvent,Receiver);

        if NumListenPoolECBs < 2 then
          NumListenPoolECBs := 2;

        PoolAllocate(NumListenPoolECBs,MaxListenDataSize,PoolRec,SPXEvent,
                     WinESR);

        SPXPoolStartListening(PoolRec);

        {call the low level establish connection routine}
        SPXEstablishConn := SPXEstablishConnPrim(SPXRetryCount,SPXWatchDog,
                                                ECB.ECBR,ConnID);
       if WaitForCompletion then begin
        repeat
          IPXRelinquish;
        until SPXEventComplete(SPXEvent,FinalResult,DType);
      end;
    end;
  end;
end;

function SPXListenForConn(var SPXEvent : WinSPXRec;
                          Socket : Word;
                          WaitForCompletion : Boolean;
                          MaxDataSize : Word;
                          NumPoolECBs : Byte;
                          var WinESR : WinESRType) : Byte; Export;

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
    with SPXEvent, wsrP^ do begin
      {the FillChar implicitly initializes the ESRAddress to NIL and the }
      {InUse flag to zero}
      FillChar(ECB.ECBP^,SizeOf(IPXECB),0);
      FillChar(NoNodes,SizeOf(IPXAddress),0);

      FillChar(SPXHead,SizeOf(SPXHeader),0);

      {Init the Event Control Block}
      with ECB, ECBP^ do begin
        SocketNumber   := Socket;
        FragmentCount  := 1;
        {we only use one buffer fragment to initiate a connection}
        with FD1 do begin
          Address := Ptr(SegOfs(wsrR).Segm, SegOfs(wsrR).Ofst + SizeOf(Word));{FD1 points to SPX Header}
          Size    := 42;
        end;
      end;

      if NumPoolECBs < 2 then
        NumPoolECBs := 2;

      PoolAllocate(NumPoolECBs,MaxDataSize,PoolRec,SPXEvent,WinESR);
      SPXPoolStartListening(PoolRec);

      {call the low level listen for connection routine}
      SPXListenForConnPrim(SPXRetryCount,SPXWatchDog,ECB.ECBR);

      if WaitForCompletion then begin
        repeat
          IPXRelinquish;
        until SPXEventComplete(SPXEvent,FinalResult,DType);
      end;
    end;
  end;
end;

function AllocateWinSPXRec(var WSR : WinSPXRec) : Boolean; Export;
var
  P, R : Pointer;
begin
  if GetRealModeMem(SizeOf(SPXRec) + SizeOf(IPXECB),
                    R, P) then begin
    AllocateWinSPXRec := True;
    FillChar(P^, SizeOf(SPXRec) + SizeOf(IPXECB), 0);
    with WSR do begin
      wsrR := R;
      wsrP := P;
      Inc(word(R), SizeOf(SPXRec));
      Inc(word(P), SizeOf(SPXRec));
      with wsrP^, ECB do begin
        ECBR := R;
        ECBP := P;
      end;
    end;
  end
  else
    AllocateWinSPXRec := False;
end;

procedure FreeWinSPXRec(WSR : WinSPXRec); Export;
begin
  FreeRealModeMem(Pointer(WSR.wsrP));
end;

procedure PoolTerminateAll(PoolRec : WinSPXPoolRec); Export;

var
  I                : Word;

begin
  IPXCloseSocketPrim(PoolRec.prP^.PoolP^[1].wpeP^.ECB.ECBP^.SocketNumber);
end;

procedure SPXAbortConn(SPXEvent : WinSPXRec); Export;

begin
  with SPXEvent, wsrP^ do begin
    SPXAbortConnPrim(ConnID);
    PoolTerminateAll(PoolRec);
    if PoolDeallocate(PoolRec) then ;
  end;
end;

procedure SPXTerminateConn(SPXEvent : WinSPXRec); Export;
{Cancels all pending events, terminates the connection, and frees heap space
 used by SPXRec's SPXPoolRec. Returns FALSE if unable to free heap space.}

begin
  with SPXEvent, wsrP^ do begin
    SPXTerminateConnPrim(ConnID,ECB.ECBR);      {!!.40}
    while ECB.ECBP^.InUse <> 0 do
      IPXRelinquish;
    PoolTerminateAll(PoolRec);
    if PoolDeallocate(PoolRec) then ;
  end;
end;

procedure SPXSend(SPXEvent : WinSPXRec;
                  WaitForCompletion : Boolean;
                  DataType : Byte;
                  DataPacketSize : Word;
                  DataPacket : Pointer); Export;

{ The high level SPX function to send a sequenced packet to a connection
  partner. This routine isolates the programmer from the details of building
  the SPX header and the Event Control Block. It is designed for use with the
  SPXListen procedure.
}

var
  FinalResult      : Byte;
  DType            : Byte;

begin
  with SPXEvent, wsrP^ do begin
    {init the required fields of the ECB}
    with ECB, ECBP^ do begin
      {the high level SPX routines always use two buffer fragments. FD1 }
      {points to the SPX header, and FD2 points to the user data.}
      FragmentCount := 2;
      with FD1 do begin
        Address := Ptr(SegOfs(wsrR).Segm, SegOfs(wsrR).Ofst + SizeOf(Word));{FD1 points to SPX Header}
        Size    := SizeOf(SPXHeader);
      end;
      with FD2 do begin
        Address := DataPacket;      {point FD2 at the user data}
        Size    := DataPacketSize;
      end;
    end;
    with SPXHead do
      DataStreamType := DataType;  {let SPX know the user defined data type}

    SPXSendPrim(ConnID,ECB.ECBR); {submit the send request to SPX}
    if WaitForCompletion then
      repeat
          IPXRelinquish;
      until SPXEventComplete(SPXEvent,FinalResult,DType);
  end;
end;

procedure SPXListen(SPXEvent : WinSPXRec;
                    WaitForCompletion : Boolean;
                    MaxPacketSize : Word;
                    DataPacket : Pointer); Export;

{ The high level SPX function to listen for a sequenced packet from a
  connection partner. This routine isolates the programmer from the details of
  building the SPX header and the Event Control Block. It is designed for use
  with the SPXSend procedure.
}

var
  FinalResult      : Byte;
  DType            : Byte;

begin
  with SPXEvent, wsrP^ do begin
    with ECB, ECBP^ do begin
      {the high level SPX routines always use two buffer fragments. FD1 }
      {points to the SPX header, and FD2 points to the user data.}
      InUse := 0;
      ESRAddress := NIL;
      FragmentCount := 2;
      with FD1 do begin
        Address := Ptr(SegOfs(wsrR).Segm, SegOfs(wsrR).Ofst + SizeOf(Word));{FD1 points to SPX Header}
        Size    := SizeOf(SPXHeader);
      end;
      with FD2 do begin
        Address := DataPacket;        {point FD2 at the user data}
        Size    := MaxPacketSize;
      end;
    end;
    SPXListenPrim(ECB.ECBP);  {submit the listen request to SPX}
    if WaitForCompletion then
      repeat
        IPXRelinquish;
      until SPXEventComplete(SPXEvent,FinalResult,DType);
  end;
end;

{***********************************************************************
  High level SPX ECB Pool routines
***********************************************************************}

function SPXPoolCancelAll(PoolRec : WinSPXPoolRec) : Boolean; Export;
{Cancel the entire Pool's events.  Does this by closing and reopening the
 socket associated with the pool.  Returns false if the socket cannot be
 reopened.}
var
  I                : Word;
  SN               : Word;

begin
  with PoolRec, prP^ do begin
    SN := PoolP^[1].wpeP^.ECB.ECBP^.SocketNumber;
    IPXCloseSocketPrim(SN);
    for I := 1 to 10000 do ;
    SPXPoolCancelAll := IPXOpenSocketPrim(SN,PoolSocketLongevity) = 0;
  end;
end;


function SPXPoolECBPtr(PoolRec : WinSPXPoolRec; PoolIndex : Byte) : ECBPtr; Export;
{returns a pointer to the ECB in PoolRec at PoolIndex}
begin
  SPXPoolECBPtr := PoolRec.PrP^.PoolP^[PoolIndex].wpeP^.ECB.ECBP;
end;

function SPXPoolDataPtr(PoolRec : WinSPXPoolRec; PoolIndex : Byte) : Pointer; Export;
{returns the data pointer for the PoolIndex element of PoolRec}
begin
  SPXPoolDataPtr := PoolRec.prP^.PoolP^[PoolIndex].wpeP^.DataP;
end;


function SPXListenPooled(SPXEvent : WinSPXRec;
                         var CompleteCode : Byte;
                         var PoolIndex : Byte;
                         var DataType : Byte;
                         var DataPtr : Pointer) : Boolean; Export;

begin
  IPXRelinquish;

  if PoolGetQueue(SPXEvent.wsrP^.PoolRec.prP^,PoolIndex) then begin
    SPXListenPooled := TRUE;
    with SPXEvent, wsrP^ do begin
      DataType := PoolRec.prP^.PoolP^[PoolIndex].wpeP^.Header.DataStreamType;
      CompleteCode := SPXPoolECBPtr(PoolRec,PoolIndex)^.CompletionCode;
      DataPtr := SPXPoolDataPtr(PoolRec,PoolIndex);
    end;
  end
  else
    SPXListenPooled := FALSE;
end;

procedure SPXReplenishPool(SPXEvent : WinSPXRec; PoolIndex : Byte); Export;
{Submit specified element of the SPX Listen pool back to SPX for listening}

begin
  with SPXEvent, wsrP^, PoolRec, prP^ do
    if (PoolIndex >= 1) and (PoolIndex <= NumInPool) then
      with PoolP^[PoolIndex].wpeP^, ECB do
        if ECBP^.InUse = 0 then begin            {!!.40}
(*                                               {!!.41}
          if PoolQS > 0 then                     {!!.40}
            Dec(PoolQS);                         {!!.40}
*)                                               {!!.41}
          SPXListenPrim(ECBR);
        end;                                     {!!.40}
end;

procedure SPXReplenishAll(SPXEvent : WinSPXRec); Export;
{Submit each unused ECB to the SPX for a listen event}
var
  I                : Byte;
begin
  with SPXEvent, wsrP^, PoolRec, prP^ do
    for I := 1 to NumInPool do
      with PoolP^[I], ECB do
        if ECBP^.InUse = 0 then
          SPXListenPrim(ECBR);
end;

function SPXListenCount(SPXEvent : WinSPXRec) : Byte; Export;
{Return the number of ECBs currently listening in the pool}
var
  Num,I : Byte;

begin
  Num := 0;
  with SPXEvent, wsrP^, PoolRec, prP^ do
    for I := 1 to NumInPool do
      if PoolP^[I].wpeP^.ECB.ECBP^.InUse <> 0 then
        Inc(Num);
  SPXListenCount := Num;
end;

exports
  IPXCall                    index 1,
  IPXInstalled               index 2,
  IPXServicesAvail           index 3,
  IPXOpenSocketPrim          index 4,
  IPXCloseSocketPrim         index 5,
  IPXOpenSocket              index 6,
  IPXCloseSocket             index 7,
  IPXAssignUniqueSocket      index 8,
  IPXSendPrim                index 9,
  IPXListenPrim              index 10,
  IPXCancelEventPrim         index 11,
  IPXRelinquish              index 12,
  IPXInternetAddress         index 13,
  IPXScheduleEvent           index 14,
  IPXScheduleSpecialEvent    index 15,
  IPXGetIntervalMarker       index 16,
  IPXGetLocalTarget          index 17,
  IPXEventComplete           index 18,
  IPXCancelEvent             index 19,
  AllocateWinIPXRec          index 20,
  FreeWinIPXRec              index 21,
  IPXSend                    index 22,
  IPXListen                  index 23,
  SPXServicesAvailPrim       index 24,
  SPXEstablishConnPrim       index 25,
  SPXListenForConnPrim       index 26,
  SPXTerminateConnPrim       index 27,
  SPXAbortConnPrim           index 28,
  SPXConnStatus              index 29,
  SPXSendPrim                index 30,
  SPXListenPrim              index 31,
  SPXServicesAvail           index 32,
  SPXEventComplete           index 33,
  SPXPoolStartListening      index 34,
  NextInPool                 index 35,
  PrevInPool                 index 36,
  PoolPutQueue               index 37,
  PoolGetQueue               index 38,
  PoolAllocate               index 39,
  PoolDeallocate             index 40,
  SPXEstablishConn           index 41,
  SPXListenForConn           index 42,
  AllocateWinSPXRec          index 43,
  FreeWinSPXRec              index 44,
  PoolTerminateAll           index 45,
  SPXAbortConn               index 46,
  SPXTerminateConn           index 47,
  SPXSend                    index 48,
  SPXListen                  index 49,
  SPXPoolCancelAll           index 50,
  SPXPoolECBPtr              index 51,
  SPXPoolDataPtr             index 52,
  SPXListenPooled            index 53,
  SPXReplenishPool           index 54,
  SPXReplenishAll            index 55,
  SPXListenCount             index 56,
  AllocateWindowsESR         index 57,
  FreeWindowsESR             index 58,
  GetSPXWatchdog             index 59,
  SetSPXWatchdog             index 60,
  GetSPXRetryCount           index 61,
  SetSPXRetryCount           index 62,
  AllocateWinAESECB          index 63,
  FreeWinAESECB              index 64;

begin
  if InRealMode then
    IPXServicesAvailable := False
  else
    IPXServicesAvailable := IpxInstalled;
end.
