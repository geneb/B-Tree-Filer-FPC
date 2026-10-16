{
  NETPRNQU.INC 1.0
}
function GetPrinterQueue(LPTDevice : Byte; var printQueueID : LongInt) : Byte;
var
  Request :
    record
      Size : Word;
      SubF : Byte;
      LPTD : Byte;
    end;
  Reply :
    record
      Size : Word;
      ID   : LongInt;
    end;
  NovRegs : Registers;
begin
  Reply.Size := 4;
  with Request do begin
    Size := 2;
    SubF := $0A;
    LPTD := LPTDevice;
  end;
  with NovRegs do begin
    AH := $E0;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    GetPrinterQueue := AL;
  end;
  printQueueID := NetWareSwapLong(Reply.ID);
end;
