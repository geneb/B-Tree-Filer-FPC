{*********************************************************}
{*                   NETBIOS.INC 5.41                    *}
{*        Copyright (c) TurboPower Software 1991.        *}
{*                 All rights reserved.                  *}
{*********************************************************}

function NetBIOSIntVecInstalled : Boolean;
{Determine whether an int 5Ch vector is installed (that does not point to
 the BIOS).
}
var
  Vec              : Pointer;
  S                : Word;

begin
  GetIntVec(NetBiosInt5C,Vec);       {get the int 5Ch vector}
  S := SegOfs(Vec).Segm;             {isolate the segment portion}

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
  PresenceNCB      : NCB;

begin
  ClearNCB(PresenceNCB);
  PresenceNCB.Command := NBInvalidCommand;    {make an impossible request}
  NetBiosRequest(PresenceNCB);                {issue the function call}

  {see if NetBIOS responeded with an invalid command error}
  DoBogusNetBIOSCall := PresenceNCB.RetCode = NBEInvalidCommand;
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

function CancelRequest(var N : NCB) : Byte;
{cancels a pending NetBIOS function request}
var
  CancelNCB        : NCB;

begin
  ClearNCB(CancelNCB);

  {build the cancel NCB.  Note how the buffer is pointed at the NCB to cancel}
  with CancelNCB do begin
    Buffer    := @N;
    Command   := NBCancelWaitOnly;    {this function always waits for the}
                                      {cancel event to complete before   }
                                      {returning}
    LanaNum   := DefaultAdapterNum;
  end;

  NetBiosRequest(CancelNCB);

  with CancelNCB do
    CancelRequest := RetCode;  {return the retcode for the cancel request}
end;


function NetBiosAddName(NameToAdd : NBNameStr; var NameNumber : Byte) : Byte;
{adds a NetBIOS unique name to the name table}

var
  NameNCB          : NCB;

begin
  ClearNCB(NameNCB);
  {build the NCB}
  with NameNCB do begin
    Command := NBAddName;
    Move(NameToAdd[1],Name,Length(NameToAdd)); {move the pascal string into}
                                               {the name field.  The name  }
                                               {field is already padded    }
                                               {with zeros from ClearNCB.  }
    LanaNum := DefaultAdapterNum;
  end;
  NetBiosRequest(NameNCB);      {issue the request}
  with NameNCB do begin
    NetBiosAddName := RetCode;  {get the result code}
    NameNumber := NameNum;      {return the netBIOS name table number}
  end;
end;

function NetBiosAddGroupName(NameToAdd : NBNameStr;
                             var NameNumber : Byte) : Byte;
{adds a NetBIOS group (non unique) name to the name table}

var
  NameNCB          : NCB;

begin
  ClearNCB(NameNCB);
  {build the NCB}
  with NameNCB do begin
    Command := NBAddGroupName;
    Move(NameToAdd[1],Name,Length(NameToAdd));   {move the name into place}
    LanaNum := DefaultAdapterNum;
  end;
  NetBiosRequest(NameNCB);
  with NameNCB do begin
    NetBiosAddGroupName := RetCode;  {return the result code}
    NameNumber := NameNum;           {return the NetBIOS name table number}
  end;
end;

function NetBiosDeleteName(NameToDelete : NBNameStr) : Byte;
{deletes a name or group name from the NetBIOS name table}

var
  NameNCB          : NCB;

begin
  ClearNCB(NameNCB);
  {build the NCB}
  with NameNCB do begin
    Command := NBDeleteName;
    Move(NameToDelete[1],Name,Length(NameToDelete));{move the name into place}
    LanaNum := DefaultAdapterNum;
  end;
  NetBiosRequest(NameNCB);
  with NameNCB do
    NetBiosDeleteName := RetCode;
end;

function NetBiosHangUp(SessionLSN : Byte) : Byte;
{hang up (terminate/disconnect) a NetBIOS session }

var
  N                : NCB;

begin
  ClearNCB(N);
  {build the NCB}
  with N do begin
    Command := NBHangUp;
    LSN     := SessionLSN;   {The local session number is all that's needed}
  end;
  NetBiosRequest(N);
  with N do
    NetBiosHangUp := RetCode;
end;

function NetBiosSend(SessionLSN : Byte;
                     PacketSize : Word;
                     var Packet) : Byte;
{send a data packet via session services}
var
  N                : NCB;

begin
  ClearNCB(N);
  {build the NCB}
  with N do begin
    Command := NBSend;

    LSN     := SessionLSN;  {we need the local session number}
    Buffer  := @Packet;     {point Buffer to the data to send}
    BufLen  := PacketSize;  {set the packet size in the NCB}
  end;
  NetBiosRequest(N);        {and we're off}
  with N do
    NetBIOSSend := RetCode;
end;

procedure NetBiosSendNoWait(SessionLSN : Byte;
                            PacketSize : Word;
                            PostEvent  : Pointer;
                            var N : NCB;
                            var Packet);
{Send a data packet via session services.  Does not wait for event to
 complete (returns immediately).}

begin
  ClearNCB(N);
  {build the NCB}
  with N do begin
    Command := NBSend + NoWait;
    LSN     := SessionLSN;  {we need the local session number}
    Buffer  := @Packet;     {point Buffer to the data to send}
    BufLen  := PacketSize;  {set the packet size in the NCB}
    PostRoutine := PostEvent;
  end;
  NetBiosRequest(N);        {and we're off}
end;

function NetBiosReceive(SessionLSN : Byte;
                        PacketSize : Word;
                        var Packet) : Byte;
{receive a data packet via session services}

var
  N                : NCB;

begin
  ClearNCB(N);
  {build the NCB}
  with N do begin
    Command := NBReceive;
    LSN     := SessionLSN;  {we need the local session number}
    Buffer  := @Packet;     {point Buffer to the buffer to receive the data}
    BufLen  := PacketSize;  {set the size of the data buffer}
  end;
  NetBiosRequest(N);        {listen for the packet}
  with N do
    NetBiosReceive := RetCode;
end;

procedure NetBiosReceiveNoWait(SessionLSN : Byte;
                               PacketSize : Word;
                               PostEvent  : Pointer;
                               var N : NCB;
                               var Packet);
{Receive a data packet via session services.  Does not wait for event to
 complete (returns immediately).}

begin
  ClearNCB(N);
  {build the NCB}
  with N do begin
    Command := NBReceive + NoWait;
    LSN     := SessionLSN;  {we need the local session number}
    Buffer  := @Packet;     {point Buffer to the buffer to receive the data}
    BufLen  := PacketSize;  {set the size of the data buffer}
    PostRoutine := PostEvent;
  end;
  NetBiosRequest(N);        {listen for the packet}
end;

function NetBiosCall(RemoteName,LocalName : NBNameStr;
                     SendTimeOut,RecTimeOut : Byte;
                     var SessionLSN : Byte) : Byte;
{attemps to "call" another node to initiate a session}
var
  N                : NCB;

begin
  ClearNCB(N);
  {build the NCB}
  with N do begin
    Command := NBCall;
    Move(LocalName[1],Name,Length(LocalName)); {set the local name}
    Move(RemoteName[1],CallName,Length(RemoteName));   {set the remote name}
    RTO := RecTimeOut;                             {set the receive time out}
    STO := SendTimeOut;                            {set the send time out}
  end;
  NetBiosRequest(N);  {make the call}
  with N do begin
    NetBIOSCall := RetCode;
    SessionLSN := LSN;
  end;
end;

procedure NetBiosCallNoWait(RemoteName,LocalName : NBNameStr;
                            SendTimeOut,RecTimeOut : Byte;
                            PostEvent : Pointer;
                            var N : NCB);
{attemps to "call" another node to initiate a session, does not wait for
 event to complete (returns immediately). }

begin
  ClearNCB(N);
  {build the NCB}
  with N do begin
    Command := NBCall + NoWait;
    Move(LocalName[1],Name,Length(LocalName)); {set the local name}
    Move(RemoteName[1],CallName,Length(RemoteName));   {set the remote name}
    RTO := RecTimeOut;                  {set the receive time out}
    STO := SendTimeOut;                 {set the send time out}
    PostRoutine := PostEvent;           {set the post event routine}
  end;
  NetBiosRequest(N);  {make the call}
end;


function NetBiosListen(RemoteName,LocalName : NBNameStr;
                       SendTimeOut,RecTimeOut : Byte;
                       var SessionLSN : Byte) : Byte;
{Listen for a "call" from another node to initiate a session}

var
  N                : NCB;

begin
  ClearNCB(N);
  {build the NCB}
  with N do begin
    Command := NBListen;
    Move(LocalName[1],Name,Length(LocalName)); {set the local name}
    Move(RemoteName[1],CallName,Length(RemoteName));   {set the remote name}
    RTO := RecTimeOut;                             {set the receive time out}
    STO := SendTimeOut;                            {set the send time out}
  end;
  NetBiosRequest(N);  {listen for the call}
  with N do begin
    NetBiosListen := RetCode;
    SessionLSN := LSN;
  end;
end;


procedure NetBiosListenNoWait(RemoteName,LocalName : NBNameStr;
                              SendTimeOut,RecTimeOut : Byte;
                              PostEvent : Pointer;
                              var N : NCB);
{Listen for a "call" from another node to initiate a session. Does not
 wait for event to complete (returns immediately). }

begin
  ClearNCB(N);
  {build the NCB}
  with N do begin
    Command := NBListen + NoWait;
    Move(LocalName[1],Name,Length(LocalName)); {set the local name}
    Move(RemoteName[1],CallName,Length(RemoteName));   {set the remote name}
    RTO := RecTimeOut;                  {set the receive time out}
    STO := SendTimeOut;                 {set the send time out}
    PostRoutine := PostEvent;           {set the post event routine}
  end;
  NetBiosRequest(N);  {listen for the call}
end;

function NetBiosCmdCompleted(var N : NCB; var FinalRetCode : Byte) : Boolean;
  {-Returns True if NetBIOS called made in NoWait state has been completed.
    If the event is complete, the final return code for the call is returned.}
begin
  if N.CmdComplete = $FF then
    NetBiosCmdCompleted := False
  else begin
    FinalRetCode := N.RetCode;
    NetBiosCmdCompleted := True;
  end;
end;

function ResetAdapter(SessionCount : Byte;
                      CommandCount : Byte) : Byte;
{reset the LAN adapter}

var
  N                : NCB;

begin
  ClearNCB(N);
  {build the NCB}
  with N do begin
    Command   := NBResetWaitOnly;
    LanaNum   := DefaultAdapterNum; {the adapter to reset (0=primary)}
    LSN       := SessionCount;      {the max sessions}
    NameNum   := CommandCount;      {the max pending commands}
  end;
  NetBiosRequest(N);                {do the reset}
  with N do
    ResetAdapter := RetCode;
end;

procedure SendDataGram(var N : NCB; SenderNameNum : Byte;
                       ReceiverName : NBNameStr;
                       Wait : Boolean;
                       DGSize : Word;
                       var Datagram);
{Send a data packet via datagram services}

var
  ClientName       : NBNameStr;

begin
  ClientName := ReceiverName;
  ClearNCB(N);
  {build the NCB}
  with N do begin
    Command := NBSendDatagram;
    if not Wait then
      Command := Command + NoWait;

    Buffer  := @DataGram;         {point Buffer at the data to send}
    BufLen  := DGSize;            {set the size of the data}
    NameNum := SenderNameNum;     {the name number to associate with}
    LanaNum := DefaultAdapterNum;
    Move(ClientName[1],CallName,Length(ClientName)); {the receiver}
  end;
  NetBiosRequest(N);              {send it off}
end;

procedure ReceiveDataGram(var N : NCB;
                          ReceiverNameNum : Byte;
                          Wait : Boolean;
                          DGSize : Word;
                          var Datagram);
{receive a data packet via datagram services. If Wait is TRUE, then this
 routine will wait until a datagram is received before returning. Otherwise,
 it waits for the datagram in the background. The CmdCompleted field of the
 NCB reports when the event is complete if Wait is FALSE.
}
begin
  ClearNCB(N);
  {build the NCB}
  with N do begin
    Command := NBReceiveDatagram;
    if not Wait then
      Command := Command + NoWait;  {return immediately-do not wait for msg}
    Buffer  := @DataGram;           {point buffer at data receive buffer}
    BufLen  := DGSize;
    NameNum := ReceiverNameNum;
  end;
  NetBiosRequest(N);
end;

procedure SendBDataGram(var N : NCB; SenderNameNum : Byte;
                        Wait : Boolean;
                        DGSize : Word;
                        var Datagram);
{send a data packet via datagram services to all receptive stations.}

begin
  ClearNCB(N);
  {build the NCB}
  with N do begin
    Command := NBSendBDatagram;
    if not Wait then
      Command := Command + NoWait;
    Buffer  := @DataGram;             {point buffer at the data}
    BufLen  := DGSize;                {set the data size}
    NameNum := SenderNameNum;
    LanaNum := DefaultAdapterNum;
  end;
  NetBiosRequest(N);
end;

procedure ReceiveBDataGram(var N : NCB;
                           ReceiverNameNum : Byte;
                           Wait : Boolean;
                           DGSize : Word;
                           var Datagram);
{Receive a broadcast datagram}

begin
  ClearNCB(N);
  {build the NCB}
  with N do begin
    Command := NBReceiveBDatagram;
    if not Wait then
      Command := Command + NoWait; {don't wait for a response}
    Buffer  := @DataGram;
    BufLen  := DGSize;
    NameNum := ReceiverNameNum;
  end;
  NetBiosRequest(N);
end;
