{*********************************************************}
{*                   NETWARE.INC 5.41                    *}
{*        Copyright (c) TurboPower Software 1989.        *}
{*                 All rights reserved.                  *}
{*********************************************************}

function NetWareLoaded(var LoggedOn : Boolean) : Boolean;
{-Returns TRUE if NetWare shell is loaded}
var
  NovRegs : Registers;

  Request : record
              Len    : Word;
              SubF   : Byte;

            end;
  Reply   : record
              Len    : Word;
              Access : Byte;
              ID     : LongInt;

            end;

begin
  FillChar(Reply,SizeOf(Reply),0);
  Reply.Len := 5;

  with Request do begin
    Len := 1;
    SubF := $46;
  end;

  with NovRegs do begin
    AH := $E3;
    DS := Seg(Request);  {DS:SI points to request}
    SI := Ofs(Request);
    ES := Seg(Reply);    {ES:DI points to reply}
    DI := Ofs(Reply);
    MsDos(NovRegs);
    with Reply do begin
      NetWareLoaded := (AL=0) and (ID <> 0);
      LoggedOn      := (AL=0) and ((ID <> 0) and (ID <> -1));
    end;
  end;
end;


function SetExtFAttr(Path : PathName; Attr : Byte) : Byte;
{
  See GetExtFAttr for meaning of Attr the Attribute
  Function returns error code:
    0  - Success
    2  - File not found
    5  - Access denied
}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }
  PName            : PathName;
begin
  {Novell function B6h subfunction 1}
  with NovRegs do begin
    AX := $B601;
    PName := Path + #0;   {put trainling zero for asciiz string}
    DS := Seg(PName);
    DX := Ofs(PName[1]);  {DS:DX points to the asciiz filespec}
    CL := Attr;           {CL gets the new extended attr}
    MsDos(NovRegs);
    if Odd(Flags) then    {if carry set then error, else success}
      SetExtFAttr := AL
    else
      SetExtFAttr := 0;
  end;
end;

function GetExtFAttr(Path : PathName; var Attributes : Byte) : Byte;
{
  Meaning of Attributes:
  7   6   5   4   3   2   1   0
  |   |   |   |       |   |   |
  |   |   |   |       +---+---+------Search mode  [210]
  |   |   |   +----------------------transactional bit [4]
  |   |   +--------------------------Indexing bit [5]
  |   +------------------------------Read Audit bit [6]
  +----------------------------------Write Audit bit [7]
  Function returns error code:
    0  - Success
    2  - File not found
    18 - No more files (requesting workstation does not have search
                        rights)
}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }
  PName            : PathName;

begin
  {Novell function B6h subfunction 0}
  with NovRegs do begin
    AX := $B600;
    PName := Path + #0;
    DS := Seg(PName);             { skip length byte for AsciiZ string }
    DX := Ofs(PName[1]);
    MsDos(NovRegs);
    GetExtFAttr := AL;              {error code from AL}
    Attributes := CL;               {extended file attr from CL}
  end;
end;

function GetConnNo : Byte;
{ returns connection number of requesting WS (1..MaxConnections) }

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  {Novell function DCh subfunc 0}
  with NovRegs do
    AX := $DC00;
  MsDos(NovRegs);
  GetConnNo := NovRegs.AL   {connection number from AL}
end;

procedure GetInternetAddress(ConnNo : Byte; var InternetAdd : IPXAddress);
{ Returns the IPX Address for the specified connection number. The IPX address
  consists of the Network number, the physical node address, and the socket.
  The socket returned by this function is the socket used by the NetWare shell
  uses to communicate with the file server. This socket MUST NOT be used by
  other applications.
}

var
  NovRegs          : Registers;
  Request          : record
                       Len     : Word;
                       SubF    : Byte;
                       Conn    : Byte;
                     end;
  Reply            : record
                       Len     : Word;
                       Address : IPXAddress;
                     end;

begin
  Reply.Len := 12;
  with Request do begin
    Len  := 2;
    SubF := $13;
    Conn := ConnNo;
  end;
  with NovRegs do begin
    AH := $E3;
    DS := Seg(Request);  {DS:SI points to request}
    SI := Ofs(Request);
    ES := Seg(Reply);    {ES:DI points to reply}
    DI := Ofs(Reply);
    MsDos(NovRegs);
  end;
  Move(Reply.Address,InternetAdd,SizeOf(IPXAddress));
  with InternetAdd do
    Socket := Swap(Socket);
end;

procedure GetObjConnNumbers(ObjectName : ObjectStr;
                            ObjectType : BinderyObject;
                            var Conns : ConnectionList);
{Return all connections with the specified object and object type logged in}
var
  NovRegs          : Registers;
  Request          : record
                       Len     : Word;
                       SubF    : Byte;
                       ObjType : Word;
                       ObjName : ObjectStr;
                     end;
  Reply            : record
                       Len     : Word;
                       Connect : ConnectionList;
                     end;

begin
  Reply.Len := 101;
  with Request do begin
    Len  := 51;
    SubF := $15;
    ObjType := Swap(Word(Ord(ObjectType)));
    ObjName := ObjectName;
  end;
  with NovRegs do begin
    AH := $E3;
    DS := Seg(Request);  {DS:SI points to request}
    SI := Ofs(Request);
    ES := Seg(Reply);    {ES:DI points to reply}
    DI := Ofs(Reply);
    MsDos(NovRegs);
  end;
  Conns := Reply.Connect;
end;


procedure GetConnInfo(ConnNo : Byte; var ConnInfo : ConnInfoType);
{Get information about the object logged on to a given connection. The
 information returned includes the object's ID, the object type, the object's
 name, and the time and date it logged on to the connection.
}

var
  NovRegs          : Registers;
  Request          : record
                       Len     : Word;
                       SubF    : Byte;
                       Conn    : Byte;
                     end;
  Reply            : record
                       Len     : Word;
                       ID      : LongInt;
                       ObjType : Word;
                       ObjName : Array[1..48] of Char;
                       Time    : NovDateType;
                     end;


begin
  Reply.Len := SizeOf(Reply) - 2;      {!!.03}
  with Request do begin
    Len  := 2;
    SubF := $16;
    Conn := ConnNo;
  end;
  with NovRegs do begin
    AH := $E3;
    DS := Seg(Request);  {DS:SI points to request}
    SI := Ofs(Request);
    ES := Seg(Reply);    {ES:DI points to reply}
    DI := Ofs(Reply);
    MsDos(NovRegs);
  end;
  with ConnInfo do begin
    ObjectID   := NetWareSwapLong(Reply.ID);
    ObjectType := Swap(Reply.ObjType);
    ObjectName := AsciiZ2Str(Reply.ObjName,48);
    LoginDate  := Reply.Time;
  end;
end;


function GetConnFromName(LoConn,HiConn : Byte; ObjName : String) : Byte;
{Search connection number LoConn to HiConn looking for a user with
 ObjName. Return the connection number of the first connection found with
 that user logged on. If no connection found with ObjName as a user, then
 returns zero.}

var
  Found            : Boolean;
  Conns            : ConnectionList;
  IndexNo          : Word;
  ConnNo           : Byte;

begin
  Found  := FALSE;
  IndexNo := 1;
  ObjName := UpperCase(ObjName);  {convert the name to all uppercase}
  GetObjConnNumbers(ObjName,ObjUser,Conns);

  with Conns do begin
    if Count > 0 then begin
      while (not Found) and (IndexNo <= Count) do begin
        ConnNo := List[IndexNo];
        if (ConnNo >= LoConn) and (ConnNo <= HiConn) then        {!!.06}
          Found := TRUE                                          {!!.06}
        else
          Inc(IndexNo);          {not found, increment IndexNo}  {!!.06}
      end;
      if Found then
        GetConnFromName := List[IndexNo]
      else
        GetConnFromName := 0;
    end
    else
      GetConnFromName := 0;
  end;
end;

function ServerConnNo : Byte;
{ returns connection number of default file server (1..8) }

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  {Novell function F0h sunfunc 2}
  with NovRegs do
    AX := $F002;
  MsDos(NovRegs);
  ServerConnNo := NovRegs.AL    {server slot number in AL}
end;

function PreferredServerConnNo : Byte;
{returns the connection number of the preferred file server}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  {Novell function F0h sunfunc 1}
  with NovRegs do
    AX := $F001;
  MsDos(NovRegs);
  PreferredServerConnNo := NovRegs.AL    {server slot number in AL}
end;

procedure SetPreferredServerConn(ServConnNo : Byte);
{sets the preferred file server.  ServConnNo must be an active fileserver that
 the workstation has previously attached to and logged into. The value of the
 preferred file server is automatically reset to 0 (meaning no preferred file
 server selected, so default server is used) when an application terminates.}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  with NovRegs do begin
    AX := $F000;
    DL := ServConnNo;
  end;
  MsDos(NovRegs);
end;

function PrimaryServerConnNo : Byte;
{returns the connection number of the default file server}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  {Novell function F0h sunfunc 5}
  with NovRegs do
    AX := $F005;
  MsDos(NovRegs);
  PrimaryServerConnNo := NovRegs.AL    {server slot number in AL}
end;

procedure ServerNameTable(var Servers : FileServerNameTable);
{ returns the NetWare file server name table}

type
  AsciizTable      = Array[1..8] of Array[1..48] of Char;

var
  I                : Word;
  NovRegs          : Registers; { register type for DOS/Novell calls }
  Table            : ^AsciizTable;

begin
  {Novell function EFh subfunc 4}
  with NovRegs do begin
    AX := $EF04;
    MsDos(NovRegs);
    Table := Ptr(ES,SI); {pointer to an 8 element array of 48 byte asciiz}
                         {strings}
    for I := 1 to 8 do
      Servers[I] := AsciiZ2Str(Table^[I],48); {convert the asciiz strings to}
                                              {pascal strings and store in  }
                                              {Servers}
  end;
end;

procedure GetServerInfo(var ServerInfo : ServerInformation);
{returns assorted information about the file server}

var
  Request          : record
                       Len  : Word;
                       SubF : Byte;
                     end;
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  with Request do begin
    Len := 1;
    SubF := $11;
  end;
  ServerInfo.Len := 139;
  with NovRegs do begin
    AH := $E3;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(ServerInfo);
    DI := Ofs(ServerInfo);
    MsDos(NovRegs);
  end;
  with ServerInfo do begin
    MaxConns := Swap(MaxConns);
    UsedConns := Swap(UsedConns);
    MaxVols := Swap(MaxVols);
    PeakConn := Swap(PeakConn);
  end;
end;

function ConsolePriv : Boolean;

var
  Reply            : Word;
  Request          : record
                       Len  : Word;
                       SubF : Byte;
                     end;
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  {build and initialize a request and reply buffer}
  Reply := 0;
  with Request do begin
    Len  := 1;
    SubF := $C8;
  end;
  with NovRegs do begin
    AX := $E300;
    DS := Seg(Request);  {DS:SI points to request}
    SI := Ofs(Request);
    ES := Seg(Reply);    {ES:DI points to reply}
    DI := Ofs(Reply);
    MsDos(NovRegs);
    ConsolePriv := AL <> $C6; {C6h indicates no console priveledges}
  end;
end;

function GetDirHandle(Drive : Char; var StatusFlags : Byte) : Byte;
{ returns directory handle and status flags for a drive

  return byte:
  00   - Invalid Drive Number
  otherwise returned directory handle

  Status Byte
  7  6  5  4  3  2  1  0
  |                 |  +-Permenant Directory Handle
  |                 +----Temporary Directory Handle
  +----------------------Mapped to a local drive
}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  with NovRegs do begin
    AX := $E900;
    DX := Ord(UpCase(Drive)) - Ord('A'); {convert the drive letter to a drive}
                                         {number}
    MsDos(NovRegs);
    GetDirHandle := AL;    {return the directory handle from AL}
    StatusFlags := AH;     {return the status flags from AH}
  end
end;

function GetDirRights(DirHandle : Byte; PathName : String;
                      var Rights : Byte) : Byte;
{ returns the requesting workstation's effective directory rights

  return byte
  00h  - Success
  98h  - Volume Does Not Exist
  9Bh  - Bad Directory Handle

  Rights

  7  6  5  4  3  2  1  0
  |  |  |  |  |  |  |  +--Read bit (file reads allowed)
  |  |  |  |  |  |  +-----Write bit (file writes allowed)
  |  |  |  |  |  +--------Open bit (files can be opened)
  |  |  |  |  +-----------Create bit (files can be created)
  |  |  |  +--------------Delete bit (files may be deleted)
  |  |  +-----------------Parental bit (subdirs may be created/deleted
  |  |                                  and trustee rights granted/revoked)
  |  +--------------------Search bit (directory may be searched)
  +-----------------------Modify bit (file status bits can be modified)
}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }
  Reply            : record
                       Len     : Word;
                       Mask    : Byte;
                     end;
  Request          : record
                       Len     : Word;
                       SubF    : Byte;
                       Handle  : Byte;
                       Name    : String;
                     end;

begin
  {build Request and init length field of Reply}
  Reply.Len := 1;
  with Request do begin
    Len     := 3 + Length(PathName); {length of this buffer}
    SubF    := $03;
    Handle  := DirHandle;
    Name    := PathName;
  end;
  with NovRegs do begin
    AX := $E200;
    DS := Seg(Request); {DS:SI points to Request}
    SI := Ofs(Request);
    ES := Seg(Reply);   {ES:DI points to Reply}
    DI := Ofs(Reply);
    MsDos(NovRegs);
    GetDirRights := AL;
  end;
  with Reply do
    Rights := Mask;     {get rights mask from Reply buffer}
end;

function GetDirPath(DirHandle : Byte; var DirPath : String) : Byte;
{ returns the pathname of a directory handle }
var
  NovRegs          : Registers; { register type for DOS/Novell calls }
  Reply            : record
                       Len     : Word;
                       Name    : String;
                     end;
  Request          : record
                       Len     : Word;
                       SubF    : Byte;
                       Handle  : Byte;
                     end;

begin
  {build Request and init Reply}
  Reply.Len := SizeOf(String);
  with Request do begin
    Len     := 2;
    SubF    := $01;
    Handle  := DirHandle;
  end;
  with NovRegs do begin
    AH := $E2;
    DS := Seg(Request); {DS:SI points to Request}
    SI := Ofs(Request);
    ES := Seg(Reply);   {ES:DI pointd to Reply}
    DI := Ofs(Reply);
    MsDos(NovRegs);
    GetDirPath := AL;
  end;
  with Reply do
    DirPath := Name;  {get DirPath name from Reply}
end;

function IsLockModeExtended : Boolean;
{
  returns TRUE if using Advanced NetWare Extended Lock Mode, if FALSE,
  then in compatability mode (for compat with NetWare 4.61 and prior).
}
var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  with NovRegs do begin
    AX := $C602;
    MsDos(NovRegs);
    IsLockModeExtended := AL = 1; {extended mode if AL = 1}
  end;
end;

procedure SetLockMode(Extended : Boolean);
{ sets the lock mode.  If Extended is TRUE, then Extended Lock mode}
{ is selected, else compatability lock mode is selected.  Advanced }
{ NetWare defaults to Compatability lock mode so applications      }
{ written prior to NetWare 4.61 will be compatable.}
var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  with NovRegs do begin
    AH := $C6;
    AL := Ord(Extended); {AL = 0 for compat, 1 for extended}
  end;
  MsDos(NovRegs);
end;

function CancelLPTCapture : Byte;
{Ends spooling for the default printer and cancels anything accumulated in
 the queue
}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  with NovRegs do begin
    AX := $DF00;
    DX := $02;
    MsDos(NovRegs);
    CancelLPTCapture := AL; {return the error code}
  end;
end;

function EndLPTCapture : Byte;
{ Ends spooling for the default printer and queues the job for printing}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  with NovRegs do begin
    AX := $DF00;
    DX := $01;
    MsDos(NovRegs);
    EndLPTCapture := AL; {return the error code as func result}
  end
end;

function FlushLPTCapture : Byte;
{ Flush the queue (queue existing captured chars for printing) and continue
  spooling.
}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  with NovRegs do begin
    AX := $DF00;
    DX := $03;
    MsDos(NovRegs);
    FlushLPTCapture := AL; {return the error code as func result}
  end
end;

function GetDefaultLocalPrinter : PrinterDevice;

var
  NovRegs          : Registers; { register type for DOS/Novell calls }
  PJ               : PrintJobType;

begin
  with DefaultServerInfo do
    if (NetWareVer > 2) or                                    {!!.21}
       ((NetWareVer =  2) and (NetWareSub >= 10)) then begin  {!!.21}
      with NovRegs do begin
        AX := $B804;
        MsDos(NovRegs);
        GetDefaultLocalPrinter := PrinterDevice(DH)
      end
    end
    else begin
      GetPrintJobFlags(PJ);
      GetDefaultLocalPrinter := PrinterDevice(PJ.LocalLPT);
    end;
end;

function StartLPTCapture : Byte;
{ Begins spooling of default printer}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  with NovRegs do begin
    AX := $DF00;
    DX := $00;
    MsDos(NovRegs);
    StartLPTCapture := AL; {return the error code as func result}
  end
end;

function LPTCaptureActive(var QueServer : Byte) : Boolean;
{ returns TRUE if spooling is currently occuring}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  with NovRegs do begin
    AH:= $F0;
    AL := $03;
    MsDos(NovRegs);
    LPTCaptureActive := $FF = AH; {spooling on if AH = FFh}
    QueServer := AL;              {get the server processing the spool}
  end;
end;

function GetCurrentDrive : Char;
var
  R : Registers;

begin
  with R do begin
    AH := $19;
    MsDos(R);
    GetCurrentDrive := Char(Ord('A')+AL);
  end;
end;

function SpoolExistingFile(FName : String) : Byte;
{-Submits an existing file to the print queue. Like the NetWare utility
  NPRINT.  Returns 0 for success or $9C if invalid path (or file not on the
  file server).}

var
  P : Byte;
  NovRegs          : Registers; { register type for DOS/Novell calls }
  Request          : record
                       BufLen : Word; { 2 }
                       SubF,          { $06 }
                       DirHan : Byte;
                       Name : String;
                     end;
  Reply            : record
                       BufLen : Word; { 4 }
                       Bytes  : Array[1..4] of Byte;
                     end;
  DirHandle        : Byte;
  Flags            : Byte;

begin
  {build the filename}
  P := Pos(':',FName);
  if P > 0 then begin
    if P = 2 then
      DirHandle := GetDirHandle(FName[1],Flags)
    else begin
      SpoolExistingFile := $9C;
      Exit;
    end;
    Delete(FName,1,2);
  end
  else
    DirHandle := GetDirHandle(GetCurrentDrive,Flags);

  {Build the request packet}
  with Request do begin
    BufLen := 3 + Length(FName);
    SubF   := $03;
    DirHan := DirHandle;
    Move(FName,Name,Length(FName)+1);
  end;
  {init the reply packet length}
  Reply.BufLen :=0;
  with NovRegs do begin
    Ah := $E0;
    DS := Seg(Request);  {DS:SI points to Request}
    SI := Ofs(Request);
    ES := Seg(Reply);    {ES:DI points to Reply}
    DI := Ofs(Reply);
  end;
  MsDos(NovRegs);
  SpoolExistingFile := NovRegs.AL;
end;

function SpecifyCaptureFile(FName : String) : Byte;
{This function allows you to specify the file for which the next Capture is to
 use to spool the printer data. The capture file is closed when a
 CancelLPTCapture, EndLPTCapture, or FlushLPTCapture is issued. The file is
 not queued for printing, this must be done explicitly by calling
 SpoolExistingFile. This function is useful for setting up your own print
 queuing routines. Possible function results are 0 for success, or $9C if
 invalid path (or path does not refer to a drive on the file server).}

var
  P : Byte;
  NovRegs          : Registers; { register type for DOS/Novell calls }
  Request          : record
                       BufLen : Word; { 2 }
                       SubF,          { $06 }
                       DirHan : Byte;
                       Name : String;
                     end;
  Reply            : record
                       BufLen : Word; { 4 }
                       Bytes  : Array[1..4] of Byte;
                     end;
  DirHandle        : Byte;
  Flags            : Byte;

begin
  {build the filename (strip drive if any) }
  P := Pos(':',FName);
  if P > 0 then begin
    if P = 2 then
      DirHandle := GetDirHandle(FName[1],Flags) {get DirHandle of specified
                                                 drive}
    else begin
      SpecifyCaptureFile := $9C;
      Exit;
    end;
    Delete(FName,1,2);
  end
  else
    DirHandle := GetDirHandle(GetCurrentDrive,Flags);

  {Build the request packet}
  with Request do begin
    BufLen := 3 + Length(FName);
    SubF   := $09;
    DirHan := DirHandle;
    Move(FName,Name,Length(FName)+1);
  end;
  {init the reply packet length}
  Reply.BufLen :=0;
  with NovRegs do begin
    Ah := $E0;
    DS := Seg(Request);  {DS:SI points to Request}
    SI := Ofs(Request);
    ES := Seg(Reply);    {ES:DI points to Reply}
    DI := Ofs(Reply);
  end;
  MsDos(NovRegs);
  SpecifyCaptureFile := NovRegs.AL;
end;

procedure GetPrinterStatus(NovellPrinter : Byte;
                           var PrinterNo,FormType : Byte;
                           var OffLine,Stopped : Boolean);
{ Return info about a given network printer.  Network printers are numbered
  between 0..4.  The FormType, and Stopped and OffLine status are returned.
  The PrinterNo is also returned, this should be the same as the number passed
  in the parameter NovellPrinter.
}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }
  Request          : record
                       BufLen : Word; { 2 }
                       SubF,          { $06 }
                       Num    : Byte;
                     end;
  Reply            : record
                       BufLen : Word; { 4 }
                       Bytes  : Array[1..4] of Byte;
                     end;

begin
  {Build the request packet}
  with Request do begin
    BufLen := 2;
    SubF   := $06;
    Num    := NovellPrinter;
  end;
  {init the reply packet length}
  Reply.BufLen := 4;
  with NovRegs do begin
    AX := $E000;
    DS := Seg(Request);  {DS:SI points to Request}
    SI := Ofs(Request);
    ES := Seg(Reply);    {ES:DI points to Reply}
    DI := Ofs(Reply);
  end;
  MsDos(NovRegs);
  if Odd(NovRegs.Flags) then        {!!.22}
  { PrinterNo := $FF }              {!!.22}
    PrinterNo := NovRegs.AL         {!!.41}  {Changed to return the function}
                                             {call result in AL}
  else                              {!!.22}
    with Reply do begin
      Stopped   := Bytes[1] = $FF;  {Printer is stopped if first byte FFh}
      OffLine   := Bytes[2] = $01;  {Printer offline if second byte is 1}
      FormType  := Bytes[3];        {third byte is the form number}
      PrinterNo := Bytes[4];        {last byte is the network printer number}
    end;
end;

procedure SetDefaultLocalPrinter(LPTNo : PrinterDevice);
{ Sets the default local printer}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }
  PJ               : PrintJobType;

begin
  with DefaultServerInfo do
    if (NetWareVer > 2) or                                       {!!.21}
       ((NetWareVer =  2) and (NetWareSub >= 10)) then begin     {!!.21}
      with NovRegs do begin
        AX := $B805;
        DH := Ord(LPTNo);   {LPT1 = 0, LPT2 = 1, LPT3 = 2}
      end;
      MsDos(NovRegs);
    end
    else begin
      GetPrintJobFlags(PJ);
      PJ.LocalLPT := Ord(LPTNo);
      SetPrintJobFlags(PJ);
    end;
end;

function GetBannerUser(var BannerUser : Str20) : Boolean;
{ Returns TRUE if the Banner User's Name is returned, FALSE if that call not
  implemented.  If TRUE, the Banner user name that is printed on the banner
  page is returned in BannerUser.}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }
  Buf              : String;

begin
  with DefaultServerInfo do
    if (NetWareVer > 2) or                                       {!!.21}
       ((NetWareVer =  2) and (NetWareSub >= 10)) then begin     {!!.21}
      with NovRegs do begin
        AX := $B808;
        ES := Seg(Buf);  {point ES:BX to buffer to accept asciiz string}
        BX := Ofs(Buf);
        MsDos(NovRegs)
      end;
      { process buf }
      BannerUser := AsciiZ2Str(Buf,20); {buf returned as AsciiZ,}
                                        {convert to str}
      GetBannerUser := TRUE;
    end
    else begin
      BannerUser := '';
      GetBannerUser := FALSE;
    end;
end;

function SetBannerUser(UserName : Str20) : Boolean;
{ Sets the user name that is printed on the banner page, returns TRUE if
  banner user name set, FALSE if that fuunction is not supported by this
  version of NetWare}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }
  Buf              : String;

begin
  with DefaultServerInfo do
    if (NetWareVer > 2) or                                       {!!.21}
       ((NetWareVer =  2) and (NetWareSub >= 10)) then begin     {!!.21}
      with NovRegs do begin
        AX := $B809;
        Buf := UserName + #0; {add terminating zero to make asciiz str}
        ES := Seg(Buf);       {ES:BX has pointer to asciiz banner user name}
        BX := Ofs(Buf[1]);    {pass new banner name, skip length byte}
        MsDos(NovRegs)
      end;
      SetBannerUser := TRUE;
    end
    else
      SetBannerUser := FALSE;
end;

procedure GetPrintJobFlags(var PrintJob : PrintJobType);
{ gets the print job flags}

var
  NovRegs          : Registers;

begin
  with NovRegs do begin
    AX := $B800;
    CX := SizeOf(PrintJobType);
    ES := Seg(PrintJob);          {ES:BX points to PrintJobType var}
    BX := Ofs(PrintJob);
  end;
  MsDos(NovRegs);

  {Novell returns word values for the following in high byte-low byte format}
  { so they need to swap bytes to be 8086 word values}

  with PrintJob do
    FlushCaptureTimeout := Swap(FlushCaptureTimeout);
end;

procedure SetPrintJobFlags(var PrintJob : PrintJobType);

var
  NovRegs          : Registers;
  PJs              : PrintJobType; {used to submit new print job flags}

begin
  PJs := PrintJob;

  {Novell expects the following word sized variables in high byte-low byte}
  {format, the 8086 likes them reversed, so swap them for Novell}

  with PJs do
    FlushCaptureTimeout := Swap(FlushCaptureTimeout);

  with NovRegs do begin
    AX := $B801;
    CX := SizeOf(PJs); {the size of the print job flags}
    ES := Seg(PJs);    {point ES:BX at the new print job flags}
    BX := Ofs(PJs);
  end;
  MsDos(NovRegs);
end;

procedure LogNetWorkMessage(Message : Str80);

var
  Request          : record
                       Len    : Word;
                       SubF   : Byte;
                       Msg    : Str80;
                     end;
  Reply            : Word;
  NovRegs          : Registers; { register type for DOS/Novell calls       }

begin
  {initialize the Request packet}
  with Request do begin
    Len   := Length(Message) + 2;
    SubF  := $0D;
    Msg := Message;
  end;
  Reply := 0;
  with NovRegs do begin
    AX := $E300;                                          {!!.06}
    DS := Seg(Request);   {DS:SI points to Request}
    SI := Ofs(Request);
    ES := Seg(Reply);     {ES:DI points to Reply}
    DI := Ofs(Reply);
    MsDos(NovRegs);
  end;
end;

procedure BroadcastToConsole(Message : Str80);

var
  Reply            : Word;
  Request          : record
                       Len   : Word;
                       SubF  : Byte;
                       Msg   : Str80;
                     end;
  NovRegs          : Registers; { register type for DOS/Novell calls       }

begin
  Reply := 0;
  {initialize the Request packet}
  with Request do begin
    Len  := Length(Message) + 2; {add one byte for Subfunc num, and one for}
                                 {length byte of Message}
    SubF := $09;
    Msg  := Message;             {uses the Pascal string, not an Asciiz}
  end;
  with NovRegs do begin
    AX := $E100;
    DS := Seg(Request);  {point DS:SI at Request}
    SI := Ofs(Request);
    ES := Seg(Reply);    {point ES:DI at Reply}
    DI := Ofs(Reply);
    MsDos(NovRegs);
  end;
end;

procedure GetBroadcastMsg(var Message : Str80);
{
  returns a broadcast message from the default file server if one is avail
}

var
  Reply            : record
                       Len   : Word;
                       Msg   : Str80;
                     end;
  Request          : Record
                       Len   : Word;
                       SubF  : Byte;
                     end;
  NovRegs          : Registers; { register type for DOS/Novell calls       }

begin
  {init the length field of Reply packet}
  Reply.Len := 56;
  {Init the Request Packet}
  with Request do begin
    Len  := 1;
    SubF := $01;
  end;
  with NovRegs do begin
    AX := $E100;
    DS := Seg(Request);    {point DS:SI at Request}
    SI := Ofs(Request);
    ES := Seg(Reply);      {point ES:DI at Reply}
    DI := Ofs(Reply);
    MsDos(NovRegs);
    Message := Reply.Msg;  {return the message}
  end
end;

function GetBroadcastMode : Byte;
{ Broadcast mode   server   Shell
==========================================
             0     Store    Retrieve and display
             1     Reject   Retrieve and display
             2     Reject   Ignore
             3     Store    Ignore
}
var
  NovRegs          : Registers; { register type for DOS/Novell calls       }

begin
  with NovRegs do begin
    AX := $DE00;
    DL := $04;
    MsDos(NovRegs);
    GetBroadcastMode := AL;  {Return the broadcast mode from AL}
  end
end;

procedure SetBroadcastMode(Mode : Byte);

var
  NovRegs          : Registers; { register type for DOS/Novell calls       }

begin
  with NovRegs do begin
    AX := $DE00;
    DL := Mode;       {DL gets the new broadcast mode (0..3)}
    MsDos(NovRegs);
  end
end;

type
  Buffer           = Array[1..384] of Byte;              {!!.06}

procedure SendBroadcastMsg(Msg : BroadcastStr;
                           var Connect,Result : ConnectionList);
{ sends the broadcast message to connection list and returns a result code
  for each one.

  Result Codes:
    00h  - Success
    FCh  - Target station already holding message (message rejected)
    FDh  - Bad connection number
    FFh  - Failure, target connection invalid (message rejected)
}

var
  I,W,L            : Word;
  Reply,Req        : Buffer;
  NovRegs          : Registers; { register type for DOS/Novell calls       }

begin
  {building the packets for this call is a little more complex then most }
  {other NetWare APIs because the size of the fields are not  fixed,     }
  {meaning a Pascal record can not be used.  Instead, a 256 byte buffer  }
  {is set aside, and the Move() procedure is used to fill in the buffers.}

  W := SizeOf(Buffer) - SizeOf(Word); {length word does not count as part}
                                      {of length of the buffers}
  Move(W,Reply,SizeOf(Word));         {move length word into first 2 bytes}
  I := 1;
  L := Length(Msg);
  W := Connect.Count + L + 3;         {calculate length of Req buffer}
  Move(W,Req[I],SizeOf(Word));        {move length word into first 2 bytes}
  Inc(I,SizeOf(Word));                {point to byte after length word}
  Req[I] := $00;                      {put a zero there}
  Inc(I);                             {point to the 4th byte}
  W := Succ(Connect.Count);           {account for Count byte of COnnect}
  Move(Connect,Req[I],W);             {Move connection list into Req}
  Inc(I,W);                           {point to position after Connect}
  W := Succ(L);                       {get length of Msg + 1}
  Move(Msg,Req[I],W);                 {move Msg and Length byte into Req}
  Inc(I,W);
  with NovRegs do begin
    AX := $E100;
    DS := Seg(Req);     {DS:SI points to Req}
    SI := Ofs(Req);
    ES := Seg(Reply);   {ES:DI points to Reply}
    DI := Ofs(Reply);
    MsDos(NovRegs);
  end;
  Move(Reply[3],Result,SizeOf(Result)); {return the Result list}
end;

procedure OpenMessagePipe(var Connect,Result : ConnectionList);
{ offer a pipe half to all connections in Connect and return result of each
  in Result.
}
var
  I,W              : Word;
  Reply,Req        : Buffer;
  NovRegs          : Registers; { register type for DOS/Novell calls       }

begin
  {building the packets for this call is a little more complex then most }
  {other NetWare APIs because the size of the fields are not  fixed,     }
  {meaning a Pascal record can not be used.  Instead, a 256 byte buffer  }
  {is set aside, and the Move() procedure is used to fill in the buffers.}
  I := 1;
  W := SizeOf(Buffer) - SizeOf(Word);  {length word doesn't count}
  Move(W,Reply,SizeOf(Word));          {move length word into place}
  W := Connect.Count + 2;              {calculate length of Req}
  Move(W,Req[I],SizeOf(Word));         {move in length of Req}
  Inc(I,SizeOf(Word));                 {point past length}
  Req[I] := $06;                       {next byte = 06h}
  Inc(I);
  Move(Connect,Req[I],Succ(Connect.Count)); {move connection list into place}
  with NovRegs do begin
    AX := $E100;
    DS := Seg(Req);       {DS:SI points to Req}
    SI := Ofs(Req);
    ES := Seg(Reply);     {ES:DI points to Reply}
    DI := Ofs(Reply);
    MsDos(NovRegs);
    {!!.21}
    if AL = 0 then
      Move(Reply[3],Result,SizeOf(Result)) {return the result list}
    else
      FillChar(Result, SizeOf(Result), 0);
  end;
end;

procedure SendMessagePipe(Msg : MessageStr;
                          var Connect,Result : ConnectionList);
{
  Result codes in Result:
    00h  - Success (message entered into pipe)
    FCh  - Pipe Full (message rejected)
    FEh  - Incomplete pipe (pipe doesn't exist)
    FFh  - Failure (invalid pipe or connection number)
}
var
  I,W,L            : Word;
  Reply,Req        : Buffer;
  NovRegs          : Registers; { register type for DOS/Novell calls       }

begin
  {building the packets for this call is a little more complex then most }
  {other NetWare APIs because the size of the fields are not  fixed,     }
  {meaning a Pascal record can not be used.  Instead, a 256 byte buffer  }
  {is set aside, and the Move() procedure is used to fill in the buffers.}
  I := 1;
  W := SizeOf(Buffer) - SizeOf(Word); {length of the Reply packet}
  Move(W,Reply,SizeOf(Word));         {move length into place}
  L := Length(Msg);
  W := Connect.Count + L + 3;         {calculate size of Request packet}
  Move(W,Req[I],SizeOf(Word));        {move size into place}
  Inc(I,SizeOf(Word));                {point past size}
  Req[I] := $04;                      {subfunction code}
  Inc(I);                             {point to next byte}
  W := Succ(Connect.Count);           {calculate size of connection list}
  Move(Connect,Req[I],W);             {move Conn list into place}
  Inc(I,W);                           {point past conn list}
  W := Succ(L);                       {size of the Msg (a pascal string)}
  Move(Msg,Req[I],W);                 {move Msg into place}
  Inc(I,W);
  with NovRegs do begin
    AX := $E100;
    DS := Seg(Req);    {DS:SI points to Req}
    SI := Ofs(Req);
    ES := Seg(Reply);  {ES:DI points to Reply}
    DI := Ofs(Reply);
    MsDos(NovRegs);
    {!!.21}
    if AL = 0 then
      Move(Reply[3],Result,SizeOf(Result))   {return the result list}
    else
      FillChar(Result, SizeOf(Result), 0);
  end;
end;

procedure GetMessagePipe(var SourceConn : Byte; var Msg : MessageStr);

var
  Reply            : Buffer;
  Req              : record
                       Len  : Word;
                       SubF : Byte;
                     end;
  W                : Word;
  NovRegs          : Registers; { register type for DOS/Novell calls       }

begin
  {initialize the Request packet}
  with Req do begin
    Len  := 1;
    SubF := $05;
  end;
  {building the Reply packet for this call is a little more complex then  }
  {most other NetWare APIs because the size of the fields are not  fixed, }
  {meaning a Pascal record can not be used.  Instead, a 256 byte buffer   }
  {is set aside, and the Move() procedure is used to fill in the buffer.  }
  W := SizeOf(Buffer) - SizeOf(Word); {calculate the size of the reply packet}
  Move(W,Reply,SizeOf(Word));         {move size into place}
  with NovRegs do begin
    AX := $E100;
    DS := Seg(Req);   {DS:SI points to request packet}
    SI := Ofs(Req);
    ES := Seg(Reply); {ES:DI points to Reply packet}
    DI := Ofs(Reply);
    MsDos(NovRegs);
  end;
  Move(Reply[1],W,SizeOf(Word));    {get the length of the Reply packet}
  if (W > 1) and                    {!!.21}
     (NovRegs.AL = 0) then begin    {if length above zero then msg arrived}
    SourceConn := Reply[3];         {return the connection num of msg source}
    Move(Reply[4],Msg,Succ(Reply[4])); {return the incoming message}
  end
  else begin                        {no incoming message}
    SourceConn := 0;                {return 0 for source connection}
    Msg := '';                      {return the empty string}
  end;
end;

procedure CheckMessagePipe(var Connect,Result : ConnectionList);
{
  Result codes in Result:
    00h  - Success (message pipe is complete)
    FEh  - Incomplete pipe (pipe doesn't exist)
    FFh  - Failure (invalid pipe or connection number)
}
var
  I,W              : Word;
  Reply,Req        : Buffer;
  NovRegs          : Registers; { register type for DOS/Novell calls       }

begin
  {building the packets for this call is a little more complex then most }
  {other NetWare APIs because the size of the fields are not  fixed,     }
  {meaning a Pascal record can not be used.  Instead, a 256 byte buffer  }
  {is set aside, and the Move() procedure is used to fill in the buffers.}
  W := SizeOf(Buffer) - SizeOf(Word);  {calculate size of the reply buffer}
  Move(W,Reply,SizeOf(Word));          {move size into place}
  I := 1;
  W := Connect.Count + 2;              {calculate size of request buffer}
  Move(W,Req[I],SizeOf(Word));         {move size into place}
  Inc(I,SizeOf(Word));                 {point past size word}
  Req[I] := $08;                       {set subfunction}
  Inc(I);                              {point to next byte after subfunc}
  W := Succ(Connect.Count);            {calculate size of connection list}
  Move(Connect,Req[I],W);              {move conn list into place}
  Inc(I,W);
  with NovRegs do begin
    AX := $E100;
    DS := Seg(Req);    {DS:SI points to request packet}
    SI := Ofs(Req);
    ES := Seg(Reply);  {ES:DI points to reply packet}
    DI := Ofs(Reply);
    MsDos(NovRegs);
    {!!.21}
    if AL = 0 then
      Move(Reply[3],Result,SizeOf(Result)) {return the result list}
    else
      FillChar(Result, SizeOf(Result), 0);
  end;
end;

function CloseMessagePipe(var Connect,Result : ConnectionList) : Byte;
{return byte
  00h  - Success
  FCh  - Message Queue is full

  Result codes in Result:
    00h  - Success (message pipe broken)
    FDh  - Failure (target connection invalid, logged out?)
    FFh  - No pipe exists
}
var
  I,W              : Word;
  Reply,Req        : Buffer;
  NovRegs          : Registers; { register type for DOS/Novell calls       }

begin
  {building the packets for this call is a little more complex then most }
  {other NetWare APIs because the size of the fields are not  fixed,     }
  {meaning a Pascal record can not be used.  Instead, a 256 byte buffer  }
  {is set aside, and the Move() procedure is used to fill in the buffers.}
  W := SizeOf(Buffer) - SizeOf(Word); {calculate size of Reply buffer}
  Move(W,Reply,SizeOf(Word));         {move size into place}
  I := 1;
  W := Connect.Count + 2;             {calculate size of request buffer}
  Move(W,Req[I],SizeOf(Word));        {move size into place}
  Inc(I,SizeOf(Word));
  Req[I] := $07;                      {subfunction value}
  Inc(I);
  W := Succ(Connect.Count);           {calculate size of conn list}
  Move(Connect,Req[I],W);             {move Conn List into place}
  Inc(I,W);
  with NovRegs do begin
    AX := $E100;
    DS := Seg(Req);
    SI := Ofs(Req);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    CloseMessagePipe := AL;             {return the error code}
    {!!.21}
    if AL = 0 then
      Move(Reply[3],Result,SizeOf(Result)) {return the result list}
    else
      FillChar(Result, SizeOf(Result), 0);
  end;
end;

{***************** transaction tracking services ******************}

function TTSAbort : Byte;
{ Return code:
  00h  - success
  FDh  - TTS Disabled
  FEh  - Transaction ends records locked (trans aborted, but recs left locked
  FFh  - no explicit transaction active
}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  with NovRegs do begin
    AX := $C703;
    MsDos(NovRegs);     {issue function C7h subfunc 3}
    TTSAbort := AL      {return the error byte}
  end;
end;

function TTSBegin : Byte;
{ return code:
  00h  - Success
  96h  - Out of Dynamic Workspace
  FEh  - Implicit transaction active (active implicit turned into explicit)
  FFh  - Explicit Transaction active
}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  with NovRegs do begin
    AX := $C700;       {issue function C7h subfunc 0}
    MsDos(NovRegs);
    TTSBegin := AL     {return the error byte}
  end
end;

function TTSEnd(var ID : LongInt)  : Byte;
{ return code:
  00h  - Success
  FDh  - TTS Disabled
  FEh  - Tranaction ends records locked
  FFh  - No Explicit transaction active
}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  with NovRegs do begin
    AX := $C701;           {issue function C7h subfunc 1}
    MsDos(NovRegs);
    ID := MakeLong(CX,DX); {make longint out of CX:DX and return as}
                           {Transaction reference ID}
    TTSEnd := AL           {return the error byte}
  end
end;

procedure TTSGetAppThresh(var Logical,Physical : Byte);

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  with NovRegs do begin
    AX := $C705;       {issue function C7h subfunc 1}
    MsDos(NovRegs);
    Logical  := CL;    {return the logical threshold}
    Physical := CH;    {return the physical threshold}
  end;
end;

procedure TTSGetWSThresh(var Logical,Physical : Byte);

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  with NovRegs do begin
    AX := $C707;       {issue function C7h subfunc 7}
    MsDos(NovRegs);
    Logical  := CL;    {return the logical threshold}
    Physical := CH;    {return the physical threshold}
  end;
end;

function TTSAvailable : Boolean;

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  with NovRegs do begin

    AX := $C702;             {issue function C7h subfunc 2}
    MsDos(NovRegs);
    TTSAvailable := AL = 1;  {TTS avail if AL = 1}
  end
end;

function TTSSetAppThresh(Logical,Physical : Byte) : Byte;

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  with NovRegs do begin
    AX := $C706;            {issue function C7h subfunc 6}
    CL := Logical;          {CL gets new logical thresh}
    CH := Physical;         {CH gets new physical thresh}
    MsDos(NovRegs);
    TTSSetAppThresh := AL;  {return the error byte}
  end;
end;

function TTSSetWSThresh(Logical,Physical : Byte) : Byte;

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  with NovRegs do begin
    AX := $C708;            {issue function C7h subfunc 8}
    CL := Logical;          {CL gets new logical thresh}
    CH := Physical;         {CH gets new physical thresh}
    MsDos(NovRegs);
    TTSSetWSThresh := AL;   {return the error byte}
  end;
end;

function TTSStatus(ID : LongInt) : Boolean;
{ returns TRUE if referenced transaction has been committed to disk }

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  with NovRegs do begin     {issue function C7h subfunc 4}
    AX := $C704;
    CX := DoubleWord(ID).HiWord; {CX gets high word of Trans Ref ID}
    DX := DoubleWord(ID).LoWord; {DX gets low word of Trans Ref ID}
    MsDos(NovRegs);
    TTSStatus := AL = 0;         {written to disk if AL is zero}
  end
end;

function TTSDisable : Boolean;

var
  NovRegs          : Registers; { register type for DOS/Novell calls }
  Reply            : Word;
  Request          : Record
                       Len  : Word;
                       SubF : Byte;
                     end;

begin
  {Reply packet length is zero}
  Reply := 0;
  {initialize the request buffer}
  with Request do begin
    Len  := 1;
    SubF := $CF;
  end;
  with NovRegs do begin
    AX := $E300;
    DS := Seg(Request);     {DS:SI points to Request}
    SI := Ofs(Request);
    ES := Seg(Reply);       {ES:DI points to Reply}
    DI := Ofs(Reply);
    MsDos(NovRegs);
    TTSDisable := AL = 0;   {TTS disabled if AL is zero}
  end
end;

function TTSEnable : Boolean;

var
  NovRegs          : Registers; { register type for DOS/Novell calls }
  Reply            : Word;
  Request          : Record
                       Len  : Word;
                       SubF : Byte;
                     end;

begin
  {init reply packet}
  Reply := 0;
  {init request packet}
  with Request do begin
    Len  := 1;
    SubF := $D0;
  end;
  with NovRegs do begin
    AX := $E300;
    DS := Seg(Request);  {DS:SI points to Request}
    SI := Ofs(Request);  {ES:DI points to Reply}
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    TTSEnable := AL = 0; {no error if AL = 0}
  end
end;

procedure GetServerDateTime(var Year : Word;
                            var Month,Day,Hour,Minute,Second : Byte;
                            var WeekDay : DayOfTheWeek);

type
  ReplyBuffer      = array[1..10] of Byte;

var
  NovRegs          : Registers; { register type for DOS/Novell calls }
  Reply            : ReplyBuffer;

begin
  with NovRegs do begin
    AX := $E700;
    DS := Seg(Reply);    {point DS:DX at buffer}
    DX := Ofs(Reply);
  end; {with}
  MsDos(NovRegs);        {issue the call}
  Year    := Word(Reply[1]) + 1900;  {return year}
  Month   := Word(Reply[2]);         {return month}
  Day     := Word(Reply[3]);         {return day}
  Hour    := Word(Reply[4]);         {return hour}
  Minute  := Word(Reply[5]);         {return minute}
  Second  := Word(Reply[6]);         {return second}
  WeekDay := DayOfTheWeek(Reply[7]); {return the day of the week as enum}
end;

procedure GetWSInfo(var ShellMajor,ShellMinor,ShellRevision : Byte;
                    var OSType,OSVer,Hardware : String);

var
  NovRegs          : Registers; { register type for DOS/Novell calls }
  Buffer           : Array[1..40] of Char;
  I                : Word;

begin
  {This function call supported by NetWare versions }
  with DefaultServerInfo do
    if not ((NetWareVer > 2) or                                   {!!.21}
       ((NetWareVer =  2) and (NetWareSub >= 10))) then begin     {!!.21}
      ShellMajor := 0;
      ShellMinor := 0;
      ShellRevision := 0;
      OSType := '';
      OSVer := '';
      Hardware := '';
      Exit;
    end;
  with NovRegs do begin
    AX := $EA01;
    ES := Seg(Buffer);
    DI := Ofs(Buffer);
    MsDos(NovRegs);
    ShellMajor    := BH;
    ShellMinor    := BL;
    ShellRevision := CL;
  end;
  {the buffer contains 4 asciiz strings (only three are returned by this}
  {procedure) one after another}
  OSType := AsciiZ2Str(Buffer[1],10); {return the first string}
  I := Length(OSType) + 2;         {point past first string (account for #0)}
  OSVer  := AsciiZ2Str(Buffer[I],10); {return the second string}
  Inc(I,Length(OSVer)+1);          {point past second string (account for #0)}
  HardWare := AsciiZ2Str(Buffer[I],10); {return the third string}
end;

function GetDriverConfiguration(LanBoard : Byte;
                                var Driver : DriverInformation) : Boolean;

var
  NovRegs          : Registers; { register type for DOS/Novell calls }
  Request :
    record
      Len : Word;
      SubF : Byte;
      LanNo : Byte;
    end;
  Reply :
    record
      Len : Word;
      NetAdd : LongInt;
      HostAdd : PhysicalNodeAddress;
      DriverInstalled : Byte;
      OptNum : Byte;
      Buffer : Array[1..160] of Char;
    end;
  I : Byte;

begin
  {init reply packet}
  Reply.Len := 172;
  {init request packet}
  with Request do begin
    Len  := 2;
    SubF := $E3;
    LanNo := LanBoard;
  end;
  with NovRegs do begin
    AH := $E3;
    DS := Seg(Request);  {DS:SI points to Request}
    SI := Ofs(Request);  {ES:DI points to Reply}
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    {!!.21}
    if (AL = 0) and (Reply.DriverInstalled <> 0) then begin
      GetDriverConfiguration := True;
      with Driver do begin
        NetworkAddress := Reply.NetAdd;
        HostAddress := Reply.HostAdd;
        OptionNumber := Reply.OptNum;
        LanBoardName := AsciiZ2Str(Reply.Buffer[1],80); {return the first string}
        I := Length(LanBoardName) + 2;  {point past first string (account for #0)}
        HardwareSettings := AsciiZ2Str(Reply.Buffer[I],80);
      end;
    end
    else begin
      FillChar(Driver, SizeOf(Driver), 0);
      GetDriverConfiguration := False;
    end;
  end;
end;
