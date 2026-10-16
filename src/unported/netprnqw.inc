{
  NETPRNQW.INC 1.0
}
function GetPrinterQueue(LPTDevice : Byte; var printQueueID : LongInt) : Byte;
type
  TRequest =
    record
      Size : Word;
      SubF : Byte;
      LPTD : Byte;
    end;
  TReply =
    record
      Size : Word;
      ID   : LongInt;
    end;
var
  Request : ^TRequest;
  Reply   : ^TReply;
  NovRegs : Registers;
  S, P : Pointer;
begin
  GetPrinterQueue := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  Reply^.Size := 4;
  with Request^ do begin
    Size := 2;
    SubF := $0A;
    LPTD := LPTDevice;
  end;
  with NovRegs do begin
    AH := $E0;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    GetPrinterQueue := AL;
  end;
  printQueueID := NetWareSwapLong(Reply^.ID);
  FreeRealModeMem(P);
end;

