{*********************************************************}
{*                 NETBIOSD.PAS 5.41                     *}
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
  **Error ** This file is for TPW or DPMI only
{$ENDIF}

Library NetBiosD;

uses
  {$IFDEF Windows}
  WinDos, WinProcs, WinTypes,
  {$ELSE}
  Dos,
  {$ENDIF}
  WinDPMI,
  NetBIOS;

procedure CallbackShell; Near; Assembler;
asm
  mov     ax,1681h
  int     2Fh
  push    es
  push    di
  mov     ax,[si]
  mov     dx,[si+2]
  mov     es:[di].WinPostType.Regs.drIP,ax
  mov     es:[di].WinPostType.Regs.drCS,dx
  {mov     es:[di].WinPostType.Regs.drSP,6} {!!.41}
  add     es:[di].WinPostType.Regs.drSP,6   {!!.41}
  push    word ptr es:[di].WinPostType.Regs.drAX
  push    word ptr es:[di].WinPostType.NCBs+2
  push    word ptr es:[di].WinPostType.NCBs
  mov     ax,es:[di].WinPostType.DataSegm
  mov     ds,ax
  call    dword ptr es:[di].WinPostType.Post
  pop     di
  pop     es
  mov     ax,1682h
  int     2Fh
  iret
end;

function GetWindowsPostRoutine(ProtectedProc : NetBiosPostRoutine;
                               DataSegment : Word;
                               var WinPost : WinPostType) : Boolean; Export;
begin
  with WinPost do begin
    Post := ProtectedProc;
    DataSegm := DataSegment;
    AllocateRealModeCallBackAddr(@CallbackShell, DPMIRegisters(Regs), Callback);
    GetWindowsPostRoutine := LongInt(Callback) <> 0;
  end;
end;

procedure FreeWindowsPostRoutine(var WinPost : WinPostType); Export;
begin
  FreeRealModeCallbackAddr(WinPost.Callback);
end;

procedure NetBiosSendNoWait(SessionLSN : Byte;
                            PacketSize : Word;
                            var PostEvent  : WinPostType;
                            var N : WinNCB;
                            Packet : Pointer); Export;
{Send a data packet via session services.  Does not wait for event to
 complete (returns immediately).}

begin
  ClearNCB(N.NP^);
  {build the NCB}
  with N.NP^ do begin
    Command := NBSend + NoWait;
    LSN     := SessionLSN;  {we need the local session number}
    Buffer  := Packet;      {point Buffer to the data to send}
    BufLen  := PacketSize;  {set the packet size in the NCB}
    PostRoutine := PostEvent.Callback;
    PostEvent.NCBs := @N;
  end;
  NetBiosRequest(N.NR);        {and we're off}
end;

procedure NetBiosReceiveNoWait(SessionLSN : Byte;
                               PacketSize : Word;
                               var PostEvent  : WinPostType;
                               var N : WinNCB;
                               Packet : Pointer); Export;
{Receive a data packet via session services.  Does not wait for event to
 complete (returns immediately).}

begin
  ClearNCB(N.NP^);
  {build the NCB}
  with N.NP^ do begin
    Command := NBReceive + NoWait;
    LSN     := SessionLSN;  {we need the local session number}
    Buffer  := Packet;      {point Buffer to the buffer to receive the data}
    BufLen  := PacketSize;  {set the size of the data buffer}
    PostRoutine := PostEvent.Callback;
    PostEvent.NCBs := @N;
  end;
  NetBiosRequest(N.NR);        {listen for the packet}
end;

procedure NetBiosCallNoWait(RemoteName,LocalName : NBNameStr;
                            SendTimeOut,RecTimeOut : Byte;
                            var PostEvent : WinPostType;
                            var N : WinNCB); Export;
{attemps to "call" another node to initiate a session, does not wait for
 event to complete (returns immediately). }

begin
  ClearNCB(N.NP^);
  {build the NCB}
  with N.NP^ do begin
    Command := NBCall + NoWait;
    Move(LocalName[1],Name,Length(LocalName)); {set the local name}
    Move(RemoteName[1],CallName,Length(RemoteName));   {set the remote name}
    RTO := RecTimeOut;                  {set the receive time out}
    STO := SendTimeOut;                 {set the send time out}
    PostRoutine := PostEvent.Callback;  {set the post event routine}
    PostEvent.NCBs := @N;
  end;
  NetBiosRequest(N.NR);  {make the call}
end;

procedure NetBiosListenNoWait(RemoteName,LocalName : NBNameStr;
                              SendTimeOut,RecTimeOut : Byte;
                              var PostEvent : WinPostType;
                              var N : WinNCB); Export;
{Listen for a "call" from another node to initiate a session. Does not
 wait for event to complete (returns immediately). }

begin
  ClearNCB(N.NP^);
  {build the NCB}
  with N.NP^ do begin
    Command := NBListen + NoWait;
    Move(LocalName[1],Name,Length(LocalName)); {set the local name}
    Move(RemoteName[1],CallName,Length(RemoteName));   {set the remote name}
    RTO := RecTimeOut;                  {set the receive time out}
    STO := SendTimeOut;                 {set the send time out}
    PostRoutine := PostEvent.Callback;  {set the post event routine}
    PostEvent.NCBs := @N;
  end;
  NetBiosRequest(N.NR);  {listen for the call}
end;

procedure SendDataGram(var N : WinNCB; SenderNameNum : Byte;
                       ReceiverName : NBNameStr;
                       Wait : Boolean;
                       var PostEvent : WinPostType;
                       DGSize : Word;
                       Datagram : Pointer); Export;
{Send a data packet via datagram services}

begin
  ClearNCB(N.NP^);
  {build the NCB}
  with N.NP^ do begin
    Command := NBSendDatagram;
    if not Wait then begin
      Command := Command + NoWait;
      PostRoutine := PostEvent.Callback;           {set the post event routine}
      PostEvent.NCBs := @N;
    end;
    Buffer  := DataGram;          {point Buffer at the data to send}
    BufLen  := DGSize;            {set the size of the data}
    NameNum := SenderNameNum;     {the name number to associate with}
    LanaNum := DefaultAdapterNum;
    Move(ReceiverName[1],CallName,Length(ReceiverName)); {the receiver}
  end;
  NetBiosRequest(N.NR);              {send it off}
end;

procedure ReceiveDataGram(var N : WinNCB;
                          ReceiverNameNum : Byte;
                          Wait : Boolean;
                          var PostEvent : WinPostType;
                          DGSize : Word;
                          Datagram : Pointer); Export;
{receive a data packet via datagram services. If Wait is TRUE, then this
 routine will wait until a datagram is received before returning. Otherwise,
 it waits for the datagram in the background. The CmdCompleted field of the
 NCB reports when the event is complete if Wait is FALSE.
}
begin
  ClearNCB(N.NP^);
  {build the NCB}
  with N.NP^ do begin
    Command := NBReceiveDatagram;
    if not Wait then begin
      Command := Command + NoWait;  {return immediately-do not wait for msg}
      PostRoutine := PostEvent.Callback;           {set the post event routine}
      PostEvent.NCBs := @N;
    end;
    Buffer  := DataGram;           {point buffer at data receive buffer}
    BufLen  := DGSize;
    NameNum := ReceiverNameNum;
  end;
  NetBiosRequest(N.NR);
end;

procedure SendBDataGram(var N : WinNCB; SenderNameNum : Byte;
                        Wait : Boolean;
                        var PostEvent : WinPostType;
                        DGSize : Word;
                        Datagram : Pointer); Export;
{send a data packet via datagram services to all receptive stations.}

begin
  ClearNCB(N.NP^);
  {build the NCB}
  with N.NP^ do begin
    Command := NBSendBDatagram;
    if not Wait then begin
      Command := Command + NoWait;
      PostRoutine := PostEvent.Callback;           {set the post event routine}
      PostEvent.NCBs := @N;
    end;
    Buffer  := DataGram;             {point buffer at the data}
    BufLen  := DGSize;                {set the data size}
    NameNum := SenderNameNum;
    LanaNum := DefaultAdapterNum;
  end;
  NetBiosRequest(N.NR);
end;

procedure ReceiveBDataGram(var N : WinNCB;
                           ReceiverNameNum : Byte;
                           Wait : Boolean;
                           var PostEvent : WinPostType;
                           DGSize : Word;
                           Datagram : Pointer); Export;
{Receive a broadcast datagram}

begin
  ClearNCB(N.NP^);
  {build the NCB}
  with N.NP^ do begin
    Command := NBReceiveBDatagram;
    if not Wait then begin
      Command := Command + NoWait; {don't wait for a response}
      PostRoutine := PostEvent.Callback;           {set the post event routine}
      PostEvent.NCBs := @N;
    end;
    Buffer  := DataGram;
    BufLen  := DGSize;
    NameNum := ReceiverNameNum;
  end;
  NetBiosRequest(N.NR);
end;

exports
  GetWindowsPostRoutine   index 1,
  FreeWindowsPostRoutine  index 2,
  NetBiosSendNoWait       index 3,
  NetBiosReceiveNoWait    index 4,
  NetBiosCallNoWait       index 5,
  NetBiosListenNoWait     index 6,
  SendDataGram            index 7,
  ReceiveDataGram         index 8,
  SendBDataGram           index 9,
  ReceiveBDataGram        index 10;

begin
end.
