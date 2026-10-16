{$S-,R-,V-}
program NBChatW;
uses
  {$IFDEF Windows}
  WinProcs,
  WinCrt,
  {$ELSE}
  WinApi,
  Crt,
  {$ENDIF}
  WinDPMI,
  NetBios;
const
  Pending : Boolean = False;
  Msg : String = '';
  NameAdded : Boolean = False;
  RealMemAllocated : Boolean = False;
  SendMemAllocated : Boolean = False;
  RecNCBAllocated : Boolean = False;
  SendNCBAllocated : Boolean = False;
  PostAllocated : Boolean = False;
  Exiting : Boolean = False;
var
  SendNBName : NBNameStr;
  RecNBName  : NBNameStr;
  NBNameNo : Byte;
  Ret : Byte;
  LSN : Byte;
  SR, SP, SendSP, SendSR : ^String;
  Regs : DPMIRegisters;
  RecN, SendN : WinNcb;
  Post : WinPostType;
  SendPost : WinPostType;
  SaveExitProc : Pointer;

  function Num2Str(Num : Byte) : String;
  var
    S : String;
  begin
    Str(Num, S);
    Num2Str := S;
  end;

  function Pad(S : String; Num : Byte) : String;
  var
    Len : Byte;
  begin
    Len := Length(S);
    if Len < Num then
      FillChar(S[Succ(Len)], Num-Len, ' ');
    S[0] := Chr(Num);
    Pad := S;
  end;


  procedure PostRoutine(LastError : Byte; N : WinNCBPtr); Far;
  begin
    if Exiting then Exit;
    Pending := True;
    if LastError = 0 then
      Msg := SP^
    else
      Msg := 'NetBIOS error = ' + Num2Str(LastError);
    ReceiveDatagram(N^, NBNameNo, False, Post, SizeOf(String), SR);
  end;

  procedure GetNames;
  begin
    Write('Enter name for this station: ');
    ReadLn(SendNBName);
    if Length(SendNBName) = 0 then
      Halt;
    SendNBName := Pad(SendNBName, SizeOf(SendNBName) - 1);
    Write('Enter name for partner: ');
    ReadLn(RecNBName);
    if Length(RecNBName) = 0 then
      Halt;
    RecNBName := Pad(RecNBName, SizeOf(RecNBName) - 1);
  end;

  procedure ShowIncoming;
  begin
    WriteLn('<incoming>', Msg);
    Pending := False;
  end;

  procedure SendOutgoing;
  begin
    Write('Enter outgoing message: ');
    ReadLn(SendSP^);
    if Length(SendSP^) <> 0 then
      SendDatagram(SendN, NBNameNo, RecNBName, False, SendPost, SizeOf(String), SendSR);
  end;

  procedure MessageLoop;
  var
    C : Char;
  begin
    WriteLn('Press space bar to enter message, ESC to quit');
    ReceiveDatagram(RecN, NBNameNo, False, Post, SizeOf(String), SR);
    repeat
      while not KeyPressed do begin
        if Pending then
          ShowIncoming;
      end;
      C := ReadKey;
      if C <> ^[ then
        SendOutgoing;
    until C = ^[;
  end;

  procedure AllocateMemory;
  begin
    if GetRealModeMem(SizeOf(String), Pointer(SR), Pointer(SP)) then
      RealMemAllocated := True
    else begin
      WriteLn('Unable to obtain real mode memory for messages');
      Halt;
    end;
    if GetRealModeMem(SizeOf(String), Pointer(SendSR), Pointer(SendSP)) then
      SendMemAllocated := True
    else begin
      WriteLn('Unable to obtain real mode memory for messages');
      Halt;
    end;
    if AllocateWinNCB(RecN) then
      RecNCBAllocated := True
    else begin
      WriteLn('Unable to allocate NCBs');
      Halt;
    end;
    if AllocateWinNCB(SendN) then
      SendNCBAllocated := True
    else begin
      WriteLn('Unable to allocate NCBs');
      Halt;
    end;
    FillChar(SendPost, SizeOf(SendPost), 0);
    if GetWindowsPostRoutine(PostRoutine, DSeg, Post) then
      PostAllocated := True
    else begin
      WriteLn('Unable to obtain real mode callback address');
      Exit;
    end;
  end;

  procedure NBExitProc; Far;
  var
    Ret : Byte;
  begin
    ExitProc := SaveExitProc;
    Exiting := True;
    if RecNCBAllocated then begin
      Ret := CancelRequest(RecN);
      FreeWinNCB(RecN);
    end;
    if SendNCBAllocated then begin
      Ret := CancelRequest(SendN);
      FreeWinNCB(SendN);
    end;
    if NameAdded then
      Ret := NetBIOSDeleteName(SendNBName);
    if RealMemAllocated then
      FreeRealModeMem(Pointer(SP));
    if SendMemAllocated then
      FreeRealModeMem(Pointer(SendSP));
    if PostAllocated then
      FreeWindowsPostRoutine(Post);
  end;

begin
  if not NetBIOSInstalled then begin
    WriteLn('NetBIOS not installed');
    Halt;
  end;
  GetNames;
  SaveExitProc := ExitProc;
  ExitProc := @NBExitProc;
  Ret := NetBIOSAddName(SendNBName, NBNameNo);
  if Ret = 0 then
    NameAdded := True
  else begin
    WriteLn('Error adding NetBIOS name');
    Halt;
  end;
  AllocateMemory;
  MessageLoop;
end.
