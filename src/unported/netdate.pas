{$V-}
program NetDate;
{
  This is a simple program that allows two NetBIOS workstations to
  synchronize dates.  It was originally written for my personal use on
  my LANtastic system at home. Since there has been some interest in it
  on Compuserve, I decided to upload it.

  This program uses Broadcast Datagrams to send the time/date.  Some
  NetBIOS implementations like Novell's NetBIOS emulator do not
  implement Broadcast Datagrams.  Under Novell, this program isn't
  necessary because there is an explicit NetWare function call to
  get the Server's time/date (see the NETWARE unit of B-Tree Filer).

  Please address questions or comments regarding this utility on Compuserve in
  the PCVENB forum in section 6.

  by Richard S. Sadowsky
  5/3/90
}
uses
     Dos,
     OpCrt,
     NetBIOS; {Services for NetBIOS from B-Tree Filer}

const
  TimesToRetry     = 500;

  NetDateRec       : NBNameStr = 'NetDateRec*****';
  NetDateSend      : NBNameStr = 'NetDateSend****';
  NetDateSSummons  : NBNameStr = 'NetDateSSummons';
  NetDateRSummons  : NBNameStr = 'NetDateRSummons';
  IDString         : String[11] = 'NetDate-RSS';

type
  DateTimePacket   =
    record
      Year,
      Month,
      Day,
      Hour,
      Min,
      Sec          : Word;
      ID           : String[11];
    end;

var
  SaveExitProc     : Pointer;
  NameNum          : Byte;
  OurNCB           : NCB;
  ActAsSender      : Boolean;

{$F+}
procedure OurExitProc;
{Deletes the netbios name}
var
  Ret : Byte;

begin
  ExitProc := SaveExitProc;  {allow chaining to original ExitProc}

  {Cancel any pending requests and delete the added names}
  Ret := CancelRequest(OurNCB);
  if ActAsSender then
    Ret := NetBIOSDeleteName(NetDateSend)
  else
    Ret := NetBIOSDeleteName(NetDateRec);
end;
{$F-}

procedure CheckForUserBreak;
{Abort if ^C or Esc pressed}
begin
  if not Keypressed then Exit;
  while KeyPressed do begin
    if ReadKey in [^[,^C] then begin
      WriteLn(^M^J,'User break');
      Halt;
    end;
  end;
end;

procedure SetDateAndTime(var Packet : DateTimePacket);
var
  Sec100 : Word;

begin
  with Packet do begin
    Sec100 := 0;
    SetDate(Year,Month,Day);
    SetTime(Hour,Min,Sec,Sec100);
  end;
end;

procedure GetDateAndTime(var Packet : DateTimePacket);
var
  WD,Sec100 : Word;

begin
 with Packet do begin
   GetDate(Year,Month,Day,WD);
   GetTime(Hour,Min,Sec,Sec100);
   ID := IDString;
 end;
end;

procedure WaitForReceiver;
var
  Msg : String;
  Ret : Byte;
  Retries : Word;
begin
  repeat
    Msg := '';
    SendBDatagram(OurNCB,NameNum,FALSE,
                  Length(NetDateSSummons)+1,NetDateSSummons);
    while OurNCB.CmdComplete <> 0 do
      CheckForUserBreak;
    if OurNCB.RetCode <> 0 then begin
      WriteLn('SendBDatagram error = ',OurNCB.RetCode);
      Halt;
    end;
    Retries := 0;
    ReceiveBDatagram(OurNCB,NameNum,FALSE,SizeOf(Msg),Msg);
    while (Retries < TimesToRetry) and (OurNCB.CmdComplete <> 0) do begin
      CheckForUserBreak;
      Inc(Retries);
    end;
    if Retries < TimesToRetry then begin
      if OurNCB.RetCode <> 0 then begin
        WriteLn('ReceiveBDatagram error = ',OurNCB.RetCode);
        Halt;
      end;
    end
    else begin
      Ret := CancelRequest(OurNCB);
      if (Ret <> 0) and (Ret <> $24) then begin
        WriteLn('Error cancelling netbios event');
        Halt;
      end;
      Delay(50);
    end;
  until Msg = NetDateRSummons;
end;

procedure WaitForSender;
var
  Msg : String;
begin
  repeat
    Msg := '';
    ReceiveBDatagram(OurNCB,NameNum,FALSE,SizeOf(Msg),Msg);
    while OurNCB.CmdComplete <> 0 do
      CheckForUserBreak;
    if OurNCB.RetCode <> 0 then begin
      WriteLn('ReceiveBDatagram error = ',OurNCB.RetCode);
      Halt;
    end;
  until Msg = NetDateSSummons;
  Delay(100);
  SendBDatagram(OurNCB,NameNum,FALSE,Length(NetDateRSummons)+1,NetDateRSummons);
  while OurNCB.CmdComplete <> 0 do
    CheckForUserBreak;
  if OurNCB.RetCode <> 0 then begin
    WriteLn('SendBDatagram error = ',OurNCB.RetCode);
    Halt;
  end;
end;

procedure NetBIOSReceiver;
{NetBIOS datagram and session demo}
var
  Packet : DateTimePacket;
  Ret : Byte;

begin
  Write('Please wait, adding NetBIOS name...');
  if NetBiosAddName(NetDateRec,NameNum) <> 0 then begin
    WriteLn(^M^J,'Unable to add NetBIOS name');
    Exit;
  end;
  WriteLn;
  Write('Waiting for sender...');
  WaitForSender;
  WriteLn;
  ReceiveBDatagram(OurNCB,NameNum,FALSE,SizeOf(Packet),Packet);
  while OurNCB.CmdComplete <> 0 do
    CheckForUserBreak;
  if (OurNCB.RetCode = 0) then begin
    if Packet.ID = IDString then begin
      SetDateAndTime(Packet);
      WriteLn('Date and time set');
    end
    else
      WriteLn('Packet received was corrupt - did not set date and time');
  end
  else
    WriteLn('ReceiveBDatagram error = ',OurNCB.RetCode);

end;

procedure NetBIOSSender;
{NetBIOS datagram sender}

var
  Ret : Byte;
  Packet : DateTimePacket;

begin
  Write('Please wait, adding NetBIOS name...');
  if NetBiosAddName(NetDateSend,NameNum) <> 0 then begin
    WriteLn(^M^J,'Unable to add NetBIOS name');
    Exit;
  end;
  WriteLn;
  Write('Waiting for receiver...');
  WaitForReceiver;
  WriteLn;
  GetDateAndTime(Packet);
  SendBDatagram(OurNCB,NameNum,FALSE,SizeOf(Packet),Packet);
  while OurNCB.CmdComplete <> 0 do
    CheckForUserBreak;
  if OurNCB.RetCode = 0 then
    WriteLn('Date sent to receiver')
  else
    WriteLn('SendBDatagram error = ',OurNCB.RetCode)

end;

begin
  ActAsSender := (ParamCount > 0);
  SaveExitProc := ExitProc;  {save original exitproc}
  ExitProc := @OurExitProc;  {setup our exit procedure}
  Delay(1);                  {get delay working}
  WriteLn('NetDate 1.0 by Richard Sadowsky',^M^J);
  if ActAsSender then
    NetBIOSSender
  else
    NetBIOSReceiver;
end.
