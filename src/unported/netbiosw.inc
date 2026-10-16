{*********************************************************}
{*                 NETBIOSW.INC 5.41                     *}
{*        Copyright (c) TurboPower Software 1991.        *}
{*                 All rights reserved.                  *}
{*********************************************************}

function GetWindowsPostRoutine;         external 'NetBIOSd' index 1;
procedure FreeWindowsPostRoutine;       external 'NetBIOSd' index 2;

function AllocateWinNCB(var N : WinNCB) : Boolean;
begin
  with N do
    AllocateWinNCB := GetRealModeMem(SizeOf(NCB),
                                  Pointer(NR),
                                  Pointer(NP));
end;

procedure FreeWinNCB(N : WinNCB);
begin
  FreeRealModeMem(Pointer(N.NP));
end;

procedure NetBIOSRequest(N : NCBPtr);
var
  Regs : DPMIRegisters;
begin
  FillChar(Regs, SizeOf(Regs), 0);
  with Regs do begin
    ES := SegOfs(N).Segm;
    BX := SegOfs(N).Ofst;
  end;
  SimulateRealModeInt($5C, 0, Regs);
end;

function NetBIOSIntVecInstalled : Boolean;
{Determine whether an int 5Ch vector is installed (that does not point to
 the BIOS).
}
var
  Vec              : Pointer;
  S                : Word;

begin
  GetRealModeIntVector(NetBiosInt5C,Vec);  {get the int 5Ch vector}
  S := SegOfs(Vec).Segm;                   {isolate the segment portion}

  {if the segment is either 0000h then the pointer is invalid, and if it is}
  {F000h then the vector points to the BIOS, in either case, it means no   }
  {NetBIOS int 5Ch could be installed.}
  if (S = $0000) or (S = $F000) then
    NetBIOSIntVecInstalled := FALSE
  else
    NetBIOSIntVecInstalled := TRUE; {pointed somewhere other than NIL or BIOS}
end;

function DoBogusNetBIOSCall : Boolean;
{issues an invalid NetBIOS call.   If such a call is made, and the installed
 int 5Ch handler returns the NetBIOS invalid command error code, then NetBIOS
 or a NetBIOS emulator is installed.
}

const
  ErrorInvalidCommand
                   = $03;

var
  PresenceNCB      : WinNCB;

begin
  if not AllocateWinNCB(PresenceNCB) then begin
    DoBogusNetBIOSCall := False;
    Exit;
  end;
  ClearNCB(PresenceNCB.NP^);
  PresenceNCB.NP^.Command := NBInvalidCommand;    {make an impossible request}
  NetBiosRequest(PresenceNCB.NR);                {issue the function call}

  {see if NetBIOS responeded with an invalid command error}
  DoBogusNetBIOSCall := PresenceNCB.NP^.RetCode = NBEInvalidCommand;
  FreeWinNCB(PresenceNCB);
end;

function NetBIOSInstalled : Boolean;
{returns true if NetBIOS (or a NetBIOS emulator) is installed}

begin
  if NetBIOSIntVecInstalled then           {if int 5Ch points somewhere valid}
    NetBIOSInstalled := DoBogusNetBIOSCall {check for NetBIOS by making an   }
                                           {impossible request and checking  }
                                           {NetBIOS' response to it}
  else
    NetBIOSInstalled := FALSE;             {no vector, no NetBIOS}
end;

function CancelRequest(var N : WinNCB) : Byte;
{cancels a pending NetBIOS function request}
var
  CancelNCB        : WinNCB;

begin
  if not AllocateWinNCB(CancelNCB) then begin
    CancelRequest := NBEDPMIError;
    Exit;
  end;
  ClearNCB(CancelNCB.NP^);

  {build the cancel NCB.  Note how the buffer is pointed at the NCB to cancel}
  with CancelNCB.NP^ do begin
    Buffer    := N.NR;
    Command   := NBCancelWaitOnly;    {this function always waits for the}
                                      {cancel event to complete before   }
                                      {returning}
    LanaNum   := DefaultAdapterNum;
  end;

  NetBiosRequest(CancelNCB.NR);

  with CancelNCB.NP^ do
    CancelRequest := RetCode;  {return the retcode for the cancel request}
  FreeWinNCB(CancelNCB);
end;


function NetBiosAddName(NameToAdd : NBNameStr; var NameNumber : Byte) : Byte;
{adds a NetBIOS unique name to the name table}

var
  NameNCB : WinNCB;

begin
  if not AllocateWinNCB(NameNCB) then begin
    NetBIOSAddName := NBEDPMIError;
    Exit;
  end;
  ClearNCB(NameNCB.NP^);
  {build the NCB}
  with NameNCB.NP^ do begin
    Command := NBAddName;
    Move(NameToAdd[1],Name,Length(NameToAdd)); {move the pascal string into}
                                               {the name field.  The name  }
                                               {field is already padded    }
                                               {with zeros from ClearNCB.  }
    LanaNum := DefaultAdapterNum;
  end;
  NetBiosRequest(NameNCB.NR);      {issue the request}
  with NameNCB.NP^ do begin
    NetBiosAddName := RetCode;  {get the result code}
    NameNumber := NameNum;      {return the netBIOS name table number}
  end;
  FreeWinNCB(NameNCB);
end;

function NetBiosAddGroupName(NameToAdd : NBNameStr;
                             var NameNumber : Byte) : Byte;
{adds a NetBIOS group (non unique) name to the name table}

var
  NameNCB : WinNCB;

begin
  if not AllocateWinNCB(NameNCB) then begin
    NetBIOSAddGroupName := NBEDPMIError;
    Exit;
  end;
  ClearNCB(NameNCB.NP^);
  {build the NCB}
  with NameNCB.NP^ do begin
    Command := NBAddGroupName;
    Move(NameToAdd[1],Name,Length(NameToAdd));   {move the name into place}
    LanaNum := DefaultAdapterNum;
  end;
  NetBiosRequest(NameNCB.NR);
  with NameNCB.NP^ do begin
    NetBiosAddGroupName := RetCode;  {return the result code}
    NameNumber := NameNum;           {return the NetBIOS name table number}
  end;
  FreeWinNCB(NameNCB);
end;

function NetBiosDeleteName(NameToDelete : NBNameStr) : Byte;
{deletes a name or group name from the NetBIOS name table}

var
  NameNCB : WinNCB;

begin
  if not AllocateWinNCB(NameNCB) then begin
    NetBIOSDeleteName := NBEDPMIError;
    Exit;
  end;
  ClearNCB(NameNCB.NP^);
  {build the NCB}
  with NameNCB.NP^ do begin
    Command := NBDeleteName;
    Move(NameToDelete[1],Name,Length(NameToDelete));{move the name into place}
    LanaNum := DefaultAdapterNum;
  end;
  NetBiosRequest(NameNCB.NR);
  with NameNCB.NP^ do
    NetBiosDeleteName := RetCode;
  FreeWinNCB(NameNCB);
end;

function NetBiosHangUp(SessionLSN : Byte) : Byte;
{hang up (terminate/disconnect) a NetBIOS session }

var
  N : WinNCB;

begin
  if not AllocateWinNCB(N) then begin
    NetBiosHangUp := NBEDPMIError;
    Exit;
  end;
  ClearNCB(N.NP^);
  {build the NCB}
  with N.NP^ do begin
    Command := NBHangUp;
    LSN     := SessionLSN;   {The local session number is all that's needed}
  end;
  NetBiosRequest(N.NR);
  with N.NP^ do
    NetBiosHangUp := RetCode;
  FreeWinNCB(N);
end;

function NetBiosSend(SessionLSN : Byte;
                     PacketSize : Word;
                     Packet : Pointer) : Byte;
{send a data packet via session services}
var
  N : WinNCB;
begin
  if not AllocateWinNCB(N) then begin
    NetBiosSend := NBEDPMIError;
    Exit;
  end;

  ClearNCB(N.NP^);
  {build the NCB}
  with N.NP^ do begin
    Command := NBSend;
    LSN     := SessionLSN;  {we need the local session number}
    Buffer  := Packet;      {point Buffer to the data to send}
    BufLen  := PacketSize;  {set the packet size in the NCB}
  end;
  NetBiosRequest(N.NR);        {and we're off}
  with N.NP^ do
    NetBIOSSend := RetCode;
  FreeWinNCB(N);
end;

procedure NetBiosSendNoWait;       external 'NetBIOSd' index 3;


function NetBiosReceive(SessionLSN : Byte;
                        PacketSize : Word;
                        Packet : Pointer) : Byte;
{receive a data packet via session services}

var
  N : WinNCB;
begin
  if not AllocateWinNCB(N) then begin
    NetBiosReceive := NBEDPMIError;
    Exit;
  end;
  ClearNCB(N.NP^);
  {build the NCB}
  with N.NP^ do begin
    Command := NBReceive;
    LSN     := SessionLSN;  {we need the local session number}
    Buffer  := Packet;      {point Buffer to the buffer to receive the data}
    BufLen  := PacketSize;  {set the size of the data buffer}
  end;
  NetBiosRequest(N.NR);        {listen for the packet}
  with N.NP^ do
    NetBiosReceive := RetCode;
  FreeWinNCB(N);
end;

procedure NetBiosReceiveNoWait;    external 'NetBIOSd' index 4;


function NetBiosCall(RemoteName,LocalName : NBNameStr;
                     SendTimeOut,RecTimeOut : Byte;
                     var SessionLSN : Byte) : Byte;
{attemps to "call" another node to initiate a session}
var
  N : WinNCB;

begin
  if not AllocateWinNCB(N) then begin
    NetBiosCall := NBEDPMIError;
    Exit;
  end;
  ClearNCB(N.NP^);
  {build the NCB}
  with N.NP^ do begin
    Command := NBCall;
    Move(LocalName[1],Name,Length(LocalName)); {set the local name}
    Move(RemoteName[1],CallName,Length(RemoteName));   {set the remote name}
    RTO := RecTimeOut;                             {set the receive time out}
    STO := SendTimeOut;                            {set the send time out}
  end;
  NetBiosRequest(N.NR);  {make the call}
  with N.NP^ do begin
    NetBIOSCall := RetCode;
    SessionLSN := LSN;
  end;
  FreeWinNCB(N);
end;

procedure NetBiosCallNoWait;       external 'NetBIOSd' index 5;


function NetBiosListen(RemoteName,LocalName : NBNameStr;
                       SendTimeOut,RecTimeOut : Byte;
                       var SessionLSN : Byte) : Byte;
{Listen for a "call" from another node to initiate a session}

var
  N : WinNCB;

begin
  if not AllocateWinNCB(N) then begin
    NetBiosListen := NBEDPMIError;
    Exit;
  end;
  ClearNCB(N.NP^);
  {build the NCB}
  with N.NP^ do begin
    Command := NBListen;
    Move(LocalName[1],Name,Length(LocalName)); {set the local name}
    Move(RemoteName[1],CallName,Length(RemoteName));   {set the remote name}
    RTO := RecTimeOut;                             {set the receive time out}
    STO := SendTimeOut;                            {set the send time out}
  end;
  NetBiosRequest(N.NR);  {listen for the call}
  with N.NP^ do begin
    NetBiosListen := RetCode;
    SessionLSN := LSN;
  end;
  FreeWinNCB(N);
end;

procedure NetBiosListenNoWait;     external 'NetBIOSd' index 6;

{$IFDEF CommentedOut}
procedure NetBiosListenNoWait(RemoteName,LocalName : NBNameStr;
                              SendTimeOut,RecTimeOut : Byte;
                              var PostEvent : WinPostType;
                              var N : WinNCB);
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
{$ENDIF}

function NetBiosCmdCompleted(var N : WinNCB; var FinalRetCode : Byte) : Boolean;
  {-Returns True if NetBIOS called made in NoWait state has been completed.
    If the event is complete, the final return code for the call is returned.}
begin
  if N.NP^.CmdComplete = $FF then
    NetBiosCmdCompleted := False
  else begin
    FinalRetCode := N.NP^.RetCode;
    NetBiosCmdCompleted := True;
  end;
end;

function ResetAdapter(SessionCount : Byte;
                      CommandCount : Byte) : Byte;
{reset the LAN adapter}

var
  N                : WinNCB;

begin
  if not AllocateWinNCB(N) then begin
    ResetAdapter := NBEDPMIError;
    Exit;
  end;
  ClearNCB(N.NP^);
  {build the NCB}
  with N.NP^ do begin
    Command   := NBResetWaitOnly;
    LanaNum   := DefaultAdapterNum; {the adapter to reset (0=primary)}
    LSN       := SessionCount;      {the max sessions}
    NameNum   := CommandCount;      {the max pending commands}
  end;
  NetBiosRequest(N.NR);                {do the reset}
  with N.NP^ do
    ResetAdapter := RetCode;
  FreeWinNCB(N);
end;

procedure SendDataGram;            external 'NetBIOSd' index 7;
procedure ReceiveDataGram;         external 'NetBIOSd' index 8;
procedure SendBDataGram;           external 'NetBIOSd' index 9;
procedure ReceiveBDataGram;        external 'NetBIOSd' index 10;

{$IFDEF CommentedOut}
procedure SendDataGram(var N : WinNCB; SenderNameNum : Byte;
                       ReceiverName : NBNameStr;
                       Wait : Boolean;
                       var PostEvent : WinPostType;
                       DGSize : Word;
                       Datagram : Pointer);
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
                          Datagram : Pointer);
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
                        Datagram : Pointer);
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
                           Datagram : Pointer);
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
{$ENDIF}
