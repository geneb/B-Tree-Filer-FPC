{*********************************************************}
{*                  NETBIOS.PAS 5.41                     *}
{*        Copyright (c) TurboPower Software 1989.        *}
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

{
 This unit implements support for NetBios name, Datagram and session
 functions.  These facilities can be used to implement peer to peer (station
 to station) communications.

  Supports NoWait operation with Post Routines.

  See SamplePostRoutine at the bottom of this page for a model on how NetBIOS
  post routines are declared.  NetBIOS calls PostRoutines like an interrupt.
  On entry, AL has the NetBIOS return code of the completed event, and
  ES:BX points to the completed NCB.
}

unit NetBIOS;

interface
uses
  {$IFDEF Windows}
  WinProcs,
  WinTypes,
  WinDos,
  WinDPMI;
  {$ELSE}
  Dos
  {$IFDEF DPMI}
  , WinDPMI
  {$ENDIF}
  ;
  {$ENDIF}

const

  NetBiosInt5C     = $5C;  {NetBios is accessed through int 5Ch}
  NetBiosInt21FC   = $2A;  {or DOS function 2Ah}
  CommandPending   = $FF;  {indicates that a command is still pending}
  MaxSessionCount  = 254;  {the max number of sessions allowed}


  NoWait           = $80;  {allows function calls to return immediately}

  NBNameMax        = 16;   {max length of NetBIOS name string}

  NBInvalidCommand
                   = $7F;  {indicates an invalid NetBios call was issued}

  NBAddName        = $30;  {subfunction to add a name}
  NBAddGroupName   = $36;  {subfunction to add a group name}
  NBDeleteName     = $31;  {subfunction to delete a name}
  NBFindName       = $78;  {subfunction to find a name}

  NBResetWaitOnly
                   = $32;  {subfunction to reset adpater}
  NBCancelWaitOnly
                   = $35;  {subfunction to cancel pending netbios call}

  NBCall           = $10;  {subfunction to "call" another station}
  NBListen         = $11;  {subfunction to "listen" for "call" from another}
                           {station}
  NBHangUp         = $12;  {subfunction to hangup a session}
  NBSend           = $14;  {subfunction to send a packet}
  NBSendNoAck      = $71;
  NBChainSend      = $17;
  NBChainSendNoAck
                   = $72;
  NBReceive        = $15;  {subfunction to receive a packet}
  NBReceiveAny     = $16;

  NBSendDatagram   = $20;  {subfunction to send a datagram}
  NBReceiveDatagram      {subfunction to receive a datagram}
                   = $21;
  NBSendBDatagram  = $22;
  NBReceiveBDatagram
                   = $23;
  NBAdapterStatus  = $33;

{******************* NetBIOS Error Codes **********************}
  NBESuccess      = $00;        {successful operation}
  NBEInvalidBufferLength
                   = $01;
  NBEInvalidCommand
                   = $03;
  NBETimedOut      = $05;
  NBEIncomplete    = $06;
  NBELocalNoAckFailed
                   = $07;
  NBEInvalidLSN    = $08;
  NBENoResourceAvail
                   = $09;
  NBESessionClosed
                   = $0A;
  NBECommandCancelled
                   = $0B;
  NBEDuplicateName
                   = $0D;
  NBENameTableFull
                   = $0E;
  NBENameHasActive
                   = $0F;
  NBELocalSessionTableFull
                   = $11;
  NBESessionNoListen
                   = $12;
  NBEIllegalNameNumber
                   = $13;
  NBECannotFindName
                   = $14;
  NBENoAnswer      = $14;
  NBEInvalidName   = $15;
  NBENameInUseOnRemote
                   = $16;
  NBENameDeleted   = $17;
  NBESessionAbnormal
                   = $18;
  NBENameConflict  = $19;
  NBEIncompatibleDevice
                   = $1A;
  NBEInterfaceBusy
                   = $21;
  NBETooManyCommands
                   = $22;
  NBEInvalidLanA   = $23;
  NBECompletedWhileCancel
                   = $24;
  NBEReservedName  = $25;
  NBENotValidCancel
                   = $26;

  NBESystemError   = $40;
  NBEHotCarrierFromRemote
                   = $41;
  NBEHotCarrier
                   = $42;
  NBENoCarrier     = $43;

  {50h-F6h INDICATE ADAPTER MALFUNCTION}

  NBEUnexpectedAdaptClose
                   = $FD;
  NBECommandPending
                   = $FF;
  NBEDPMIError     = $FE;

  DefaultAdapterNum: Byte = 0;


type

  SegOfs           = record                 {used to get high and low word}
                       Ofst, Segm : Word;   {of pointer types}
                     end;
  WordPtr          = ^Word;

  NBNameStr        = String[NBNameMax];   {type for NetBIOS names}
  CallNameType     = Array[1..16] of Char;  {used by NetBIOS internally}
                                            {for names}

  {this is the data type used in NetBIOS calls}
  NCB              = record
                       Command         : Byte;    {the NetBIOS command}
                       RetCode         : Byte;    {the return code}
                       LSN             : Byte;    {the local session num}
                       NameNum         : Byte;    {the NetBIOS name table num}
                       Buffer          : Pointer; {point to data buffer}
                       BufLen          : Word;    {length of the data buffer}
                       CallName        : CallNameType;  {The local name}
                       Name            : CallNameType;  {the remote name}
                       RTO             : Byte;    {Receive Time Out}
                       STO             : Byte;    {Send Time Out}
                       PostRoutine     : Pointer; {the post event routine}
                       LanaNum         : Byte;    {the LAN adapter number}
                       CmdComplete     : Byte;    {the command complete flag}
                       Reserved        : Array[1..14] of Byte; {scratch}
                     end;
  NCBPtr           = ^NCB;

{$IFDEF DPMIorWnd}
  WinNCB =
    record
      NR, NP : NCBPtr;
    end;
  WinNCBPtr = ^WinNCB;

  RealModeCallbackProc = Pointer;
  NetBiosPostRoutine = procedure(LastError : Byte; N : WinNCBPtr);
  DPMIReg =
    record
      drDI : LongInt;
      drSI : LongInt;
      drBP : LongInt;
      drDeserved : LongInt;
      drBX : LongInt;
      drDX : LongInt;
      drCX : LongInt;
      drAX : LongInt;
      drFlags : Word;
      drES : Word;
      drDS : Word;
      drFS : Word;
      drGS : Word;
      drIP : Word;
      drCS : Word;
      drSP : Word;
      drSS : Word;
    end;
    WinPostType =
      record
        Regs     : DPMIReg;
        Post     : NetBiosPostRoutine;
        CallBack : RealModeCallbackProc;
        NCBs     : WinNCBPtr;
        DataSegm : Word;
      end;

function GetWindowsPostRoutine(ProtectedProc : NetBiosPostRoutine;
                               DataSegment : Word;
                               var WinPost : WinPostType) : Boolean;
  {-Request a real mode callback for NetBIOS post routines.}

procedure FreeWindowsPostRoutine(var WinPost : WinPostType);
  {-Free a real mode callback for NetBIOS post routines.}

function AllocateWinNCB(var N : WinNCB) : Boolean;
  {-Allocate memory for NCB for use under Windows}

procedure FreeWinNCB(N : WinNCB);
  {-Free memory for NCB for use under Windows}
{$ENDIF}

procedure ClearNCB(var N : NCB);
{Initializes an NCB to zero.  This is required before using an NCB.}

function NetBIOSInstalled : Boolean;
{Returns TRUE if NETBIOS is installed.  See implementation section for}
{a warning on the use of this routine.}

function NetBiosAddName(NameToAdd : NBNameStr; var NameNumber : Byte) : Byte;
{Adds a name to the local NETBIOS name table.}

function NetBiosAddGroupName(NameToAdd : NBNameStr;
                             var NameNumber : Byte) : Byte;
{Adds a group name to the local NETBIOS name table.}

function NetBiosDeleteName(NameToDelete : NBNameStr) : Byte;
{Deletes a name or group name from the local NETBIOS name table.}

function NetBiosHangUp(SessionLSN : Byte) : Byte;
{Closes an existing session.}

{$IFDEF DPMIorWnd}
function NetBiosSend(SessionLSN : Byte;
                     PacketSize : Word;
                     Packet : Pointer) : Byte;

function NetBiosReceive(SessionLSN : Byte;
                        PacketSize : Word;
                        Packet : Pointer) : Byte;

procedure NetBiosReceiveNoWait(SessionLSN : Byte;
                               PacketSize : Word;
                               var PostEvent  : WinPostType;
                               var N : WinNCB;
                               Packet : Pointer);
{Receive a data packet via session services.  Does not wait for event to
 complete (returns immediately).}

procedure NetBiosSendNoWait(SessionLSN : Byte;
                            PacketSize : Word;
                            var PostEvent  : WinPostType;
                            var N : WinNCB;
                            Packet : Pointer);
{Send a data packet via session services.  Does not wait for event to
 complete (returns immediately).}

function NetBiosCmdCompleted(var N : WinNCB; var FinalRetCode : Byte) : Boolean;
  {-Returns True if NetBIOS called made in NoWait state has been completed.
    If the event is complete, the final return code for the call is returned.}

function CancelRequest(var N : WinNCB) : Byte;
{Cancels a pending NETBIOS request}

procedure SendDataGram(var N : WinNCB; SenderNameNum : Byte;
                       ReceiverName : NBNameStr;
                       Wait : Boolean;
                       var PostEvent : WinPostType;
                       DGSize : Word;
                       Datagram : Pointer);
{Sends a Datagram}

procedure ReceiveDataGram(var N : WinNCB;
                          ReceiverNameNum : Byte;
                          Wait : Boolean;
                          var PostEvent : WinPostType;
                          DGSize : Word;
                          Datagram : Pointer);
{Receives a Datagram}

procedure SendBDataGram(var N : WinNCB; SenderNameNum : Byte;
                        Wait : Boolean;
                        var PostEvent : WinPostType;
                        DGSize : Word;
                        Datagram : Pointer);
{Sends a broadcast datagram}

procedure ReceiveBDataGram(var N : WinNCB;
                           ReceiverNameNum : Byte;
                           Wait : Boolean;
                           var PostEvent : WinPostType;
                           DGSize : Word;
                           Datagram : Pointer);
{Receives a broadcast datagram}

procedure NetBiosCallNoWait(RemoteName,LocalName : NBNameStr;
                            SendTimeOut,RecTimeOut : Byte;
                            var PostEvent : WinPostType;
                            var N : WinNCB);
{attemps to "call" another node to initiate a session, does not wait for
 event to complete (returns immediately). }
procedure NetBiosListenNoWait(RemoteName,LocalName : NBNameStr;
                              SendTimeOut,RecTimeOut : Byte;
                              var PostEvent : WinPostType;
                              var N : WinNCB);
{Listen for a "call" from another node to initiate a session. Does not
 wait for event to complete (returns immediately). }

{$ELSE}
function NetBiosSend(SessionLSN : Byte;
                     PacketSize : Word;
                     var Packet) : Byte;
function NetBiosReceive(SessionLSN : Byte;
                        PacketSize : Word;
                        var Packet) : Byte;

procedure NetBiosReceiveNoWait(SessionLSN : Byte;
                               PacketSize : Word;
                               PostEvent  : Pointer;
                               var N : NCB;
                               var Packet);
{Receive a data packet via session services.  Does not wait for event to
 complete (returns immediately).}
procedure NetBiosSendNoWait(SessionLSN : Byte;
                            PacketSize : Word;
                            PostEvent  : Pointer;
                            var N : NCB;
                            var Packet);
{Send a data packet via session services.  Does not wait for event to
 complete (returns immediately).}

function NetBiosCmdCompleted(var N : NCB; var FinalRetCode : Byte) : Boolean;
  {-Returns True if NetBIOS called made in NoWait state has been completed.
    If the event is complete, the final return code for the call is returned.}

function CancelRequest(var N : NCB) : Byte;
{Cancels a pending NETBIOS request}

procedure NetBiosCallNoWait(RemoteName,LocalName : NBNameStr;
                            SendTimeOut,RecTimeOut : Byte;
                            PostEvent : Pointer;
                            var N : NCB);
{attemps to "call" another node to initiate a session, does not wait for
 event to complete (returns immediately). }

procedure NetBiosListenNoWait(RemoteName,LocalName : NBNameStr;
                              SendTimeOut,RecTimeOut : Byte;
                              PostEvent : Pointer;
                              var N : NCB);
{Listen for a "call" from another node to initiate a session. Does not
 wait for event to complete (returns immediately). }

procedure SendDataGram(var N : NCB; SenderNameNum : Byte;
                       ReceiverName : NBNameStr;
                       Wait : Boolean;
                       DGSize : Word;
                       var Datagram);
{Sends a Datagram}

procedure ReceiveDataGram(var N : NCB;
                          ReceiverNameNum : Byte;
                          Wait : Boolean;
                          DGSize : Word;
                          var Datagram);
{Receives a Datagram}

procedure SendBDataGram(var N : NCB; SenderNameNum : Byte;
                        Wait : Boolean;
                        DGSize : Word;
                        var Datagram);
{Sends a broadcast datagram}

procedure ReceiveBDataGram(var N : NCB;
                           ReceiverNameNum : Byte;
                           Wait : Boolean;
                           DGSize : Word;
                           var Datagram);
{Receives a broadcast datagram}

{$ENDIF}

function NetBiosCall(RemoteName,LocalName : NBNameStr;
                     SendTimeOut,RecTimeOut : Byte;
                     var SessionLSN : Byte) : Byte;
{Used to "call" another station to initiate a session (used with Listen).}

function NetBiosListen(RemoteName,LocalName : NBNameStr;
                       SendTimeOut,RecTimeOut : Byte;
                       var SessionLSN : Byte) : Byte;
{Used to listen for a "call" from another station.}

function ResetAdapter(SessionCount : Byte;
                      CommandCount : Byte) : Byte;
{Reset's the specified NETBIOS adapter.}



{$IFDEF DPMIorWnd}
procedure NetBIOSRequest(N : NCBPtr);
{$ELSE}
procedure NetBIOSRequest(var N : NCB);
{submits the NCB to NetBIOS for processing}
Inline(
  $5B/                   {  pop    bx}
  $07/                   {  pop    es}
  $CD/$5C);              {  int    $5C}
{$ENDIF}

implementation

procedure ClearNCB(var N : NCB);

begin
  FillChar(N,SizeOf(NCB),$00);     {fill the NCB with 0}
end;

{$IFDEF DPMIorWnd}
  {$I NetBIOSw.INC}
{$ELSE}
  {$I NetBIOS.INC}
{$ENDIF}

(***
procedure SamplePostRoutine(Flags,CS,IP,
                            AX,BX,CX,DX,SI,DI,DS,ES,BP : Word); Interrupt;

var
  N   : NCBPtr;

begin
  N := Ptr(ES,BX);                {ES:BX has pointer to completed NCB}
  LastErrorCode := Lo(AX);        {AL has NetBios return code}
  with N^ do begin
    {...}
  end;
end;
***)

  {$IFDEF InitAllUnits}
begin
{$ENDIF}
end.
