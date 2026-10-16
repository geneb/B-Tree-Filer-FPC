{*********************************************************}
{*                   NETWAREW.INC 5.41                   *}
{*        Copyright (c) TurboPower Software 1991.        *}
{*                 All rights reserved.                  *}
{*********************************************************}


function NetWareLoaded(var LoggedOn : Boolean) : Boolean;
{-Returns TRUE if NetWare shell is loaded}
type
  TRequest = record
               Len    : Word;
               SubF   : Byte;
             end;
  TReply   = record
               Len    : Word;
               Access : Byte;
               ID     : LongInt;
             end;

var
  NovRegs : Registers;
  S, P : Pointer;
  Enh : Boolean;
  Request : ^TRequest;
  Reply : ^TReply;
begin
  NetWareLoaded := False;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then
    Exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  FillChar(Reply^,SizeOf(Reply^),0);
  Reply^.Len := 5;
  with Request^ do begin
    Len := 1;
    SubF := $46;
  end;

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    Flags := GetCPUFlags;
    AX := $E300;
    DS := SegOfs(S).Segm;  {DS:SI points to request}
    SI := 0;
    ES := SegOfs(S).Segm;    {ES:DI points to reply}
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    with Reply^ do begin
      NetWareLoaded := (AL=0) and (ID <> 0);
      LoggedOn      := (AL=0) and ((ID <> 0) and (ID <> -1));
    end;
  end;
  FreeRealModeMem(P);
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
  PName            : ^PathName;
  S, P             : Pointer;
begin
  SetExtFAttr := 8;
  if not GetRealModeMem(SizeOf(PathName), S, P) then
    Exit;
  PName := P;
  Move(Path[1], PName^, Length(Path));
  PName^[Length(Path)] := #0;
  {Novell function B6h subfunction 1}
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $B601;
    DS := SegOfs(S).Segm;
    DX := 0;              {DS:DX points to the asciiz filespec}
    CX := Attr;           {CL gets the new extended attr}
    WinIntr($21, NovRegs);
    if Odd(Flags) then    {if carry set then error, else success}
      SetExtFAttr := AL
    else
      SetExtFAttr := 0;
  end;
  FreeRealModeMem(P);
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
  PName            : ^PathName;
  S, P       : Pointer;

begin
  GetExtFAttr := 8;
  if not GetRealModeMem(SizeOf(PathName), S, P) then
    Exit;
  PName := P;
  Move(Path[1], PName^, Length(Path));
  PName^[Length(Path)] := #0;
  {Novell function B6h subfunction 0}
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $B600;
    DS := SegOfs(S).Segm;             { skip length byte for AsciiZ string }
    DX := 0;
    WinIntr($21, NovRegs);
    GetExtFAttr := AL;              {error code from AL}
    Attributes := CL;               {extended file attr from CL}
  end;
  FreeRealModeMem(P);
end;

{*******************************}

function GetConnNo : Byte;
{ returns connection number of requesting WS (1..MaxConnections) }

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  {Novell function DCh subfunc 0}
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  NovRegs.AX := $DC00;
  WinIntr($21, NovRegs);
  GetConnNo := NovRegs.AL;   {connection number from AL}
end;

procedure GetInternetAddress(ConnNo : Byte; var InternetAdd : IPXAddress);
{ Returns the IPX Address for the specified connection number. The IPX address
  consists of the Network number, the physical node address, and the socket.
  The socket returned by this function is the socket used by the NetWare shell
  uses to communicate with the file server. This socket MUST NOT be used by
  other applications.
}

type
  TRequest         = record
                       Len     : Word;
                       SubF    : Byte;
                       Conn    : Byte;
                     end;
  TReply           = record
                       Len     : Word;
                       Address : IPXAddress;
                     end;
var
  Request : ^TRequest;
  Reply : ^TReply;
  NovRegs : Registers;
  S, P : Pointer;
begin
  FillChar(InternetAdd, SizeOf(InternetAdd), 0);
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then
    Exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  FillChar(Reply^,SizeOf(Reply^),0);

  Reply^.Len := 12;
  with Request^ do begin
    Len  := 2;
    SubF := $13;
    Conn := ConnNo;
  end;
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E300;
    DS := SegOfs(S).Segm;    {DS:SI points to request}
    SI := 0;
    ES := SegOfs(S).Segm;    {ES:DI points to reply}
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
  end;
  Move(Reply^.Address,InternetAdd,SizeOf(IPXAddress));
  with InternetAdd do
    Socket := Swap(Socket);
  FreeRealModeMem(P);
end;

procedure GetObjConnNumbers(ObjectName : ObjectStr;
                            ObjectType : BinderyObject;
                            var Conns : ConnectionList);
{Return all connections with the specified object and object type logged in}

type
  TRequest         = record
                       Len     : Word;
                       SubF    : Byte;
                       ObjType : Word;
                       ObjName : ObjectStr;
                     end;
  TReply           = record
                       Len     : Word;
                       Connect : ConnectionList;
                     end;
var
  Request : ^TRequest;
  Reply : ^TReply;
  NovRegs : Registers;
  S, P : Pointer;
begin
  FillChar(Conns, SizeOf(Conns), 0);
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then
    Exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  FillChar(Reply^,SizeOf(Reply^),0);

  Reply^.Len := 101;
  with Request^ do begin
    Len  := 51;
    SubF := $15;
    ObjType := Swap(Word(Ord(ObjectType)));
    ObjName := ObjectName;
  end;

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E300;
    DS := SegOfs(S).Segm;    {DS:SI points to request}
    SI := 0;
    ES := SegOfs(S).Segm;    {ES:DI points to reply}
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
  end;
  Conns := Reply^.Connect;
  FreeRealModeMem(P);
end;


procedure GetConnInfo(ConnNo : Byte; var ConnInfo : ConnInfoType);
{Get information about the object logged on to a given connection. The
 information returned includes the object's ID, the object type, the object's
 name, and the time and date it logged on to the connection.
}

type
  TRequest         = record
                       Len     : Word;
                       SubF    : Byte;
                       Conn    : Byte;
                     end;
  TReply           = record
                       Len     : Word;
                       ID      : LongInt;
                       ObjType : Word;
                       ObjName : Array[1..48] of Char;
                       Time    : NovDateType;
                     end;
var
  NovRegs : Registers;
  Request : ^TRequest;
  Reply : ^TReply;
  S, P : Pointer;

begin
  FillChar(ConnInfo, SizeOf(ConnInfo), 0);
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then
    Exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  FillChar(Reply^,SizeOf(Reply^),0);
  Reply^.Len := SizeOf(Reply^) - 2;      {!!.03}
  with Request^ do begin
    Len  := 2;
    SubF := $16;
    Conn := ConnNo;
  end;

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E300;
    DS := SegOfs(S).Segm;  {DS:SI points to request}
    SI := 0;
    ES := SegOfs(S).Segm;  {ES:DI points to reply}
    DI := SizeOf(Request);
    WinIntr($21, NovRegs);
  end;
  with ConnInfo do begin
    ObjectID   := NetWareSwapLong(Reply^.ID);
    ObjectType := Swap(Reply^.ObjType);
    ObjectName := AsciiZ2Str(Reply^.ObjName,48);
    LoginDate  := Reply^.Time;
  end;
  FreeRealModeMem(P);
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
  NovRegs : Registers; { register type for DOS/Novell calls }

begin
  {Novell function F0h sunfunc 2}
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  NovRegs.AX := $F002;
  WinIntr($21, NovRegs);
  ServerConnNo := Lo(NovRegs.AX)    {server slot number in AL}
end;

function PreferredServerConnNo : Byte;
{returns the connection number of the preferred file server}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  {Novell function F0h sunfunc 1}
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  NovRegs.AX := $F001;
  WinIntr($21, NovRegs);
  PreferredServerConnNo := Lo(NovRegs.AX);    {server slot number in AL}
end;

procedure SetPreferredServerConn(ServConnNo : Byte);
{sets the preferred file server.  ServConnNo must be an active fileserver that
 the workstation has previously attached to and logged into. The value of the
 preferred file server is automatically reset to 0 (meaning no preferred file
 server selected, so default server is used) when an application terminates.}

var
  NovRegs : Registers; { register type for DOS/Novell calls }

begin
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $F000;
    DX := ServConnNo;
  end;
  WinIntr($21, NovRegs);
end;

function PrimaryServerConnNo : Byte;
{returns the connection number of the default file server}

var
  NovRegs : Registers; { register type for DOS/Novell calls }

begin
  {Novell function F0h sunfunc 5}
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  NovRegs.AX := $F005;
  WinIntr($21, NovRegs);
  PrimaryServerConnNo := Lo(NovRegs.AX);    {server slot number in AL}
end;

(*
  function FreeLDTDescriptor(Selector : Word) : Word; Assembler;
  function GetSelectorForRealMem(P : Pointer; Size : LongInt; var Selector : Word) : Word;
*)

procedure ServerNameTable(var Servers : FileServerNameTable);
{ returns the NetWare file server name table}

type
  AsciizTable      = Array[1..8] of Array[1..48] of Char;

var
  I                : Word;
  NovRegs          : Registers; { register type for DOS/Novell calls }
  Table            : ^AsciizTable;
  Sele             : Word;
begin
  {Novell function EFh subfunc 4}
  FillChar(Servers, SizeOf(Servers), 0);
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $EF04;
    WinIntr($21, NovRegs);

    if GetSelectorForRealMem(Ptr(ES, SI), 8*48, Sele) <> 0 then
      Exit;
    Table := Ptr(Sele, 0); {pointer to an 8 element array of 48 byte asciiz}
                           {strings}

    for I := 1 to 8 do
      Servers[I] := AsciiZ2Str(Table^[I],48); {convert the asciiz strings to}
                                              {pascal strings and store in  }
                                              {Servers}
    if FreeLDTDescriptor(Sele) = 0 then ;
  end;
end;

procedure GetServerInfo(var ServerInfo : ServerInformation);
{returns assorted information about the file server}

type
  TRequest         = record
                       Len  : Word;
                       SubF : Byte;
                     end;
var
  Request : ^TRequest;
  SrvInfo : ^ServerInformation;
  NovRegs : Registers; { register type for DOS/Novell calls }
  S, P : Pointer;
begin
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(ServerInformation), S, P) then
    Exit;
  Request := P;
  SrvInfo := P;
  Inc(Word(SrvInfo), SizeOf(TRequest));
  FillChar(SrvInfo^,SizeOf(SrvInfo^),0);
  with Request^ do begin
    Len := 1;
    SubF := $11;
  end;
  SrvInfo^.Len := SizeOf(ServerInformation) - 2;

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E300;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
  end;
  with SrvInfo^ do begin
    MaxConns := Swap(MaxConns);
    UsedConns := Swap(UsedConns);
    MaxVols := Swap(MaxVols);
    PeakConn := Swap(PeakConn);
  end;
  Move(SrvInfo^, ServerInfo, SizeOf(ServerInfo));
  FreeRealModeMem(P);
end;


function ConsolePriv : Boolean;
type
  TRequest         = record
                       Len  : Word;
                       SubF : Byte;
                     end;
var
  Request : ^TRequest;
  Reply   : ^Word;
  NovRegs : Registers; { register type for DOS/Novell calls }
  S, P    : Pointer;
begin
  {build and initialize a request and reply buffer}
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then
    Exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  with Request^ do begin
    Len  := 1;
    SubF := $C8;
  end;
  Reply^ := 0;

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E300;
    DS := SegOfs(S).Segm;  {DS:SI points to request}
    SI := 0;
    ES := SegOfs(S).Segm;    {ES:DI points to reply}
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    ConsolePriv := Lo(AX) <> $C6; {C6h indicates no console priveledges}
  end;
  FreeRealModeMem(P);
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
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E900;
    DX := Ord(UpCase(Drive)) - Ord('A'); {convert the drive letter to a drive}
                                         {number}
    WinIntr($21, NovRegs);
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
type
  TReply           = record
                       Len     : Word;
                       Mask    : Byte;
                     end;
  TRequest         = record
                       Len     : Word;
                       SubF    : Byte;
                       Handle  : Byte;
                       Name    : String;
                     end;
var
  Request : ^TRequest;
  Reply   : ^TReply;
  NovRegs : Registers;
  S, P : Pointer;
begin
  {build Request and init length field of Reply}
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then
    Exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  FillChar(Reply^, SizeOf(Reply^), 0);
  Reply^.Len := 1;
  with Request^ do begin
    Len     := 3 + Length(PathName); {length of this buffer}
    SubF    := $03;
    Handle  := DirHandle;
    Name    := PathName;
  end;

  {make the call}
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E200;
    DS := SegOfs(S).Segm;    {DS:SI points to Request}
    SI := 0;
    ES := SegOfs(S).Segm;    {ES:DI points to Reply}
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    GetDirRights := Lo(AX);
  end;
  with Reply^ do
    Rights := Mask;     {get rights mask from Reply buffer}
  FreeRealModeMem(P);
end;

function GetDirPath(DirHandle : Byte; var DirPath : String) : Byte;
{ returns the pathname of a directory handle }
type
  TReply           = record
                       Len     : Word;
                       Name    : String;
                     end;
  TRequest         = record
                       Len     : Word;
                       SubF    : Byte;
                       Handle  : Byte;
                     end;
var
  Request : ^TRequest;
  Reply   : ^TReply;
  NovRegs : Registers;
  S, P : Pointer;
begin
  {build Request and init Reply}
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then
    Exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  FillChar(Reply^, SizeOf(Reply^), 0);
  Reply^.Len := SizeOf(String);
  with Request^ do begin
    Len     := 2;
    SubF    := $01;
    Handle  := DirHandle;
  end;

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E200;
    DS := SegOfs(S).Segm;   {DS:SI points to Request}
    SI := 0;
    ES := SegOfs(S).Segm;   {ES:DI pointd to Reply}
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    GetDirPath := AL;
  end;
  with Reply^ do
    DirPath := Name;  {get DirPath name from Reply}
  FreeRealModeMem(P);
end;

function IsLockModeExtended : Boolean;
{
  returns TRUE if using Advanced NetWare Extended Lock Mode, if FALSE,
  then in compatability mode (for compat with NetWare 4.61 and prior).
}
var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $C602;
    WinIntr($21, NovRegs);
    IsLockModeExtended := (AL = 1); {extended mode if AL = 1}
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
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  NovRegs.AX := $C600 + Ord(Extended); {AL = 0 for compat, 1 for extended}
  WinIntr($21, NovRegs);
end;

function CancelLPTCapture : Byte;
{Ends spooling for the default printer and cancels anything accumulated in
 the queue
}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $DF00;
    DL := $02;
    WinIntr($21, NovRegs);
    CancelLPTCapture := AL; {return the error code}
  end;
end;

function EndLPTCapture : Byte;
{ Ends spooling for the default printer and queues the job for printing}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $DF00;
    DL := $01;
    WinIntr($21, NovRegs);
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
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $DF00;
    DL := $03;
    WinIntr($21, NovRegs);
    FlushLPTCapture := AL; {return the error code as func result}
  end
end;

function GetDefaultLocalPrinter : PrinterDevice;

var
  NovRegs          : Registers; { register type for DOS/Novell calls }
  PJ               : PrintJobType;

begin
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with DefaultServerInfo do
    if (NetWareVer > 2) or                                    {!!.21}
       ((NetWareVer =  2) and (NetWareSub >= 10)) then begin  {!!.21}
      with NovRegs do begin
        AX := $B804;
        WinIntr($21, NovRegs);
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
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $DF00;
    DL := $00;
    WinIntr($21, NovRegs);
    StartLPTCapture := AL; {return the error code as func result}
  end
end;

function LPTCaptureActive(var QueServer : Byte) : Boolean;
{ returns TRUE if spooling is currently occuring}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX:= $F003;
    WinIntr($21, NovRegs);
    LPTCaptureActive := (AH = $FF); {spooling on if AH = FFh}
    QueServer := AL;                {get the server processing the spool}
  end;
end;

function GetCurrentDrive : Char;
var
  NovRegs : Registers;

begin
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $1900;
    WinIntr($21, NovRegs);
    GetCurrentDrive := Char(Ord('A')+AL);
  end;
end;

function SpoolExistingFile(FName : String) : Byte;
{-Submits an existing file to the print queue. Like the NetWare utility
  NPRINT.  Returns 0 for success, $9C if invalid path, or
  $98 for requested file not on file server.}

type
  TRequest         = record
                       BufLen : Word; { 2 }
                       SubF,          { $06 }
                       DirHan : Byte;
                       Name : String;
                     end;
  TReply           = record
                       BufLen : Word; { 4 }
                       Bytes  : Array[1..4] of Byte;
                     end;

var
  Request   : ^TRequest;
  Reply     : ^TReply;
  NovRegs   : Registers;
  S, P      : Pointer;
  DirHandle : Byte;
  Flags     : Byte;
  B         : Byte;
begin
  {build the filename}
  B := Pos(':',FName);
  if B > 0 then begin
    if B = 2 then
      DirHandle := GetDirHandle(FName[1],Flags)
    else begin
      SpoolExistingFile := $9C;
      Exit;
    end;
    Delete(FName,1,2);
  end
  else
    DirHandle := GetDirHandle(GetCurrentDrive,Flags);

  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then begin
    SpoolExistingFile := $9C;
    Exit;
  end;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  FillChar(Reply^, SizeOf(Reply^), 0);

  {Build the request packet}
  with Request^ do begin
    BufLen := 3 + Length(FName);
    SubF   := $03;
    DirHan := DirHandle;
    Move(FName,Name,Length(FName)+1);
  end;

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E000;
    DS := SegOfs(S).Segm;  {DS:SI points to Request}
    SI := 0;
    ES := SegOfs(S).Segm;  {ES:DI points to Reply}
    DI := SizeOf(TRequest);
  end;
  WinIntr($21, NovRegs);
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

type
  TRequest         = record
                       BufLen : Word; { 2 }
                       SubF,          { $06 }
                       DirHan : Byte;
                       Name : String;
                     end;
  TReply           = record
                       BufLen : Word; { 4 }
                       Bytes  : Array[1..4] of Byte;
                     end;
var
  NovRegs          : Registers;
  Request          : ^TRequest;
  Reply            : ^TReply;
  S, P             : Pointer;
  B                : Byte;
  DirHandle        : Byte;
  Flags            : Byte;

begin
  {build the filename (strip drive if any) }
  B := Pos(':',FName);
  if B > 0 then begin
    if B = 2 then
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

  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then begin
    SpecifyCaptureFile := $9C;
    Exit;
  end;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  FillChar(Reply^, SizeOf(Reply^), 0);

  {Build the request packet}
  with Request^ do begin
    BufLen := 3 + Length(FName);
    SubF   := $09;
    DirHan := DirHandle;
    Move(FName,Name,Length(FName)+1);
  end;

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E000;
    DS := SegOfs(S).Segm;  {DS:SI points to Request}
    SI := 0;
    ES := SegOfs(S).Segm;  {ES:DI points to Reply}
    DI := SizeOf(TRequest);
  end;
  WinIntr($21, NovRegs);
  SpecifyCaptureFile := NovRegs.AL;
  FreeRealModeMem(P);
end;

procedure GetPrinterStatus(NovellPrinter : Byte;
                           var PrinterNo,FormType : Byte;
                           var OffLine,Stopped : Boolean);
{ Return info about a given network printer.  Network printers are numbered
  between 0..4.  The FormType, and Stopped and OffLine status are returned.
  The PrinterNo is also returned, this should be the same as the number passed
  in the parameter NovellPrinter.
}

type
  TRequest         = record
                       BufLen : Word; { 2 }
                       SubF,          { $06 }
                       Num    : Byte;
                     end;
  TReply           = record
                       BufLen : Word; { 4 }
                       Bytes  : Array[1..4] of Byte;
                     end;
var
  NovRegs : Registers;
  Request : ^TRequest;
  Reply   : ^TReply;
  S, P    : Pointer;

begin
  {Build the request packet}
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then
    Exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  FillChar(Reply^, SizeOf(Reply^), 0);

  with Request^ do begin
    BufLen := 2;
    SubF   := $06;
    Num    := NovellPrinter;
  end;
  {init the reply packet length}
  Reply^.BufLen := 4;

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E000;
    DS := SegOfs(S).Segm;    {DS:SI points to Request}
    SI := 0;
    ES := SegOfs(S).Segm;    {ES:DI points to Reply}
    DI := SizeOf(TRequest);
  end;
  WinIntr($21, NovRegs);
  if Odd(NovRegs.Flags) then        {!!.22}
    PrinterNo := $FF                {!!.22}
  else                              {!!.22}
    with Reply^ do begin
      Stopped   := Bytes[1] = $FF;  {Printer is stopped if first byte FFh}
      OffLine   := Bytes[2] = $01;  {Printer offline if second byte is 1}
      FormType  := Bytes[3];        {third byte is the form number}
      PrinterNo := Bytes[4];        {last byte is the network printer number}
    end;
  FreeRealModeMem(P);
end;

procedure SetDefaultLocalPrinter(LPTNo : PrinterDevice);
{ Sets the default local printer}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }
  PJ               : PrintJobType;

begin
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with DefaultServerInfo do
    if (NetWareVer > 2) or                                       {!!.21}
       ((NetWareVer =  2) and (NetWareSub >= 10)) then begin     {!!.21}
      with NovRegs do begin
        AX := $B805;
        DX := Ord(LPTNo);   {LPT1 = 0, LPT2 = 1, LPT3 = 2}
      end;
      WinIntr($21, NovRegs);
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
  Buf              : ^String;
  S, P             : Pointer;
begin
  GetBannerUser := False;
  if not GetRealModeMem(SizeOf(String), S, P) then Exit;
  Buf := P;
  FillChar(Buf^, SizeOf(String), 0);

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with DefaultServerInfo do
    if (NetWareVer > 2) or                                       {!!.21}
       ((NetWareVer =  2) and (NetWareSub >= 10)) then begin     {!!.21}
      with NovRegs do begin
        AX := $B808;
        ES := SegOfs(S).Segm;  {point ES:BX to buffer to accept asciiz string}
        BX := 0;
        WinIntr($21, NovRegs)
      end;
      { process buf }
      BannerUser := AsciiZ2Str(Buf^,20); {buf returned as AsciiZ,}
                                         {convert to str}
      GetBannerUser := TRUE;
    end
    else begin
      BannerUser := '';
      GetBannerUser := FALSE;
    end;
  FreeRealModeMem(P);
end;

function SetBannerUser(UserName : Str20) : Boolean;
{ Sets the user name that is printed on the banner page, returns TRUE if
  banner user name set, FALSE if that fuunction is not supported by this
  version of NetWare}

var
  NovRegs          : Registers; { register type for DOS/Novell calls }
  Buf              : ^String;
  S, P             : Pointer;
begin
  SetBannerUser := False;
  if not GetRealModeMem(SizeOf(String), S, P) then Exit;
  Buf := P;
  FillChar(Buf^, SizeOf(String), 0);
  Move(UserName[1], Buf^, Length(UserName));

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with DefaultServerInfo do
    if (NetWareVer > 2) or                                       {!!.21}
       ((NetWareVer =  2) and (NetWareSub >= 10)) then begin     {!!.21}
      with NovRegs do begin
        AX := $B809;
        ES := SegOfs(S).Segm;           {ES:BX has pointer to asciiz banner user name}
        BX := 0;              {pass new banner name, skip length byte}
        WinIntr($21, NovRegs)
      end;
      SetBannerUser := TRUE;
    end
    else
      SetBannerUser := FALSE;
  FreeRealModeMem(P);
end;

procedure GetPrintJobFlags(var PrintJob : PrintJobType);
{ gets the print job flags}

var
  NovRegs          : Registers;
  PJT              : ^PrintJobType;
  S, P             : Pointer;
begin
  if not GetRealModeMem(SizeOf(PrintJobType), S, P) then exit;
  PJT := P;

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $B800;
    CX := SizeOf(PrintJobType);
    ES := SegOfs(S).Segm;          {ES:BX points to PrintJobType var}
    BX := 0;
  end;
  WinIntr($21, NovRegs);

  {Novell returns word values for the following in high byte-low byte format}
  { so they need to swap bytes to be 8086 word values}
  Move(PJT^, PrintJob, SizeOf(PrintJobType));
  with PrintJob do
    FlushCaptureTimeout := Swap(FlushCaptureTimeout);
  FreeRealModeMem(P);
end;

procedure SetPrintJobFlags(var PrintJob : PrintJobType);

var
  NovRegs          : Registers;
  PJs              : ^PrintJobType; {used to submit new print job flags}
  S, P       : Pointer;
begin
  if not GetRealModeMem(SizeOf(PrintJobType), S, P) then exit;
  PJs := P;
  Move(PrintJob, PJs^, SizeOf(PrintJobType));

  {Novell expects the following word sized variables in high byte-low byte}
  {format, the 8086 likes them reversed, so swap them for Novell}

  with PJs^ do
    FlushCaptureTimeout := Swap(FlushCaptureTimeout);

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $B801;
    CX := SizeOf(PJs); {the size of the print job flags}
    ES := SegOfs(S).Segm;        {point ES:BX at the new print job flags}
    BX := 0;
  end;
  WinIntr($21, NovRegs);
  FreeRealModeMem(P);
end;

procedure LogNetWorkMessage(Message : Str80);

type
  TRequest         = record
                       Len    : Word;
                       SubF   : Byte;
                       Msg    : Str80;
                     end;
var
  Request          : ^TRequest;
  Reply            : ^Word;
  NovRegs          : Registers; { register type for DOS/Novell calls }
  S, P       : Pointer;
begin
  {initialize the Request packet}
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then
    Exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := 0;
  with Request^ do begin
    Len   := Length(Message) + 2;
    SubF  := $0D;
    Msg := Message;
  end;

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E300;                                          {!!.06}
    DS := SegOfs(S).Segm;   {DS:SI points to Request}
    SI := 0;
    ES := SegOfs(S).Segm;     {ES:DI points to Reply}
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
  end;
  FreeRealModeMem(P);
end;

procedure BroadcastToConsole(Message : Str80);

type
  TRequest         = record
                       Len   : Word;
                       SubF  : Byte;
                       Msg   : Str80;
                     end;
var
  Request          : ^TRequest;
  Reply            : ^Word;
  S, P             : Pointer;
  NovRegs          : Registers; { register type for DOS/Novell calls       }

begin
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then
    Exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := 0;
  {initialize the Request packet}
  with Request^ do begin
    Len  := Length(Message) + 2; {add one byte for Subfunc num, and one for}
                                 {length byte of Message}
    SubF := $09;
    Msg  := Message;             {uses the Pascal string, not an Asciiz}
  end;

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E100;
    DS := SegOfs(S).Segm;  {point DS:SI at Request}
    SI := 0;
    ES := SegOfs(S).Segm;    {point ES:DI at Reply}
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
  end;
  FreeRealModeMem(P);
end;

procedure GetBroadcastMsg(var Message : Str80);
{
  returns a broadcast message from the default file server if one is avail
}

type
  TReply           = record
                       Len   : Word;
                       Msg   : Str80;
                     end;
  TRequest         = Record
                       Len   : Word;
                       SubF  : Byte;
                     end;
var
  NovRegs          : Registers; { register type for DOS/Novell calls       }
  Request          : ^TRequest;
  Reply            : ^TReply;
  S, P       : Pointer;

begin
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then
    Exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  FillChar(Reply^, SizeOf(Reply^), 0);
  {init the length field of Reply packet}
  Reply^.Len := 56;
  {Init the Request Packet}
  with Request^ do begin
    Len  := 1;
    SubF := $01;
  end;

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E100;
    DS := SegOfs(S).Segm;    {point DS:SI at Request}
    SI := 0;
    ES := SegOfs(S).Segm;      {point ES:DI at Reply}
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    Message := Reply^.Msg;  {return the message}
  end;
  FreeRealModeMem(P);
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
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $DE00;
    DX := $0004;
    WinIntr($21, NovRegs);
    GetBroadcastMode := Lo(AX);  {Return the broadcast mode from AL}
  end
end;

procedure SetBroadcastMode(Mode : Byte);

var
  NovRegs          : Registers; { register type for DOS/Novell calls       }

begin
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $DE00;
    DX := Mode;       {DL gets the new broadcast mode (0..3)}
    WinIntr($21, NovRegs);
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
  Reply,Request    : ^Buffer;
  NovRegs          : Registers; { register type for DOS/Novell calls       }
  S, P       : Pointer;
begin
  {building the packets for this call is a little more complex then most }
  {other NetWare APIs because the size of the fields are not  fixed,     }
  {meaning a Pascal record can not be used.  Instead, a 256 byte buffer  }
  {is set aside, and the Move() procedure is used to fill in the buffers.}

  FillChar(Result, SizeOf(Result), 0);
  if not GetRealModeMem(SizeOf(Buffer) shl 1, S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(Buffer));
  FillChar(Reply^, SizeOf(Reply^), 0);

  W := SizeOf(Buffer) - SizeOf(Word);  {length word does not count as part}
                                       {of length of the buffers}
  Move(W,Reply^,SizeOf(Word));         {move length word into first 2 bytes}
  I := 1;
  L := Length(Msg);
  W := Connect.Count + L + 3;          {calculate length of Req buffer}
  Move(W,Request^[I],SizeOf(Word));        {move length word into first 2 bytes}
  Inc(I,SizeOf(Word));                 {point to byte after length word}
  Request^[I] := $00;                      {put a zero there}
  Inc(I);                              {point to the 4th byte}
  W := Succ(Connect.Count);            {account for Count byte of COnnect}
  Move(Connect,Request^[I],W);             {Move connection list into Req}
  Inc(I,W);                            {point to position after Connect}
  W := Succ(L);                        {get length of Msg + 1}
  Move(Msg,Request^[I],W);                 {move Msg and Length byte into Req}
  Inc(I,W);

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E100;
    DS := SegOfs(S).Segm;     {DS:SI points to Req}
    SI := 0;
    ES := SegOfs(S).Segm;     {ES:DI points to Reply}
    DI := SizeOf(Buffer);
    WinIntr($21, NovRegs);
  end;
  Move(Reply^[3],Result,SizeOf(Result)); {return the Result list}
  FreeRealModeMem(P);
end;

procedure OpenMessagePipe(var Connect,Result : ConnectionList);
{ offer a pipe half to all connections in Connect and return result of each
  in Result.
}
var
  I,W              : Word;
  Reply,Request    : ^Buffer;
  NovRegs          : Registers; { register type for DOS/Novell calls       }
  S, P       : Pointer;
begin
  {building the packets for this call is a little more complex then most }
  {other NetWare APIs because the size of the fields are not  fixed,     }
  {meaning a Pascal record can not be used.  Instead, a 256 byte buffer  }
  {is set aside, and the Move() procedure is used to fill in the buffers.}
  FillChar(Result, SizeOf(Result), 0);
  if not GetRealModeMem(SizeOf(Buffer) shl 1, S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(Buffer));
  FillChar(Reply^, SizeOf(Reply^), 0);

  I := 1;
  W := SizeOf(Buffer) - SizeOf(Word);   {length word doesn't count}
  Move(W,Reply^,SizeOf(Word));          {move length word into place}
  W := Connect.Count + 2;               {calculate length of Req}
  Move(W,Request^[I],SizeOf(Word));         {move in length of Req}
  Inc(I,SizeOf(Word));                  {point past length}
  Request^[I] := $06;                       {next byte = 06h}
  Inc(I);
  Move(Connect,Request^[I],Succ(Connect.Count)); {move connection list into place}

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E100;
    DS := SegOfs(S).Segm;       {DS:SI points to Req}
    SI := 0;
    ES := SegOfs(S).Segm;       {ES:DI points to Reply}
    DI := SizeOf(Buffer);
    WinIntr($21, NovRegs);
    {!!.21}
    if AL = 0 then
      Move(Reply^[3],Result,SizeOf(Result)) {return the result list}
    else
      FillChar(Result, SizeOf(Result), 0);
  end;
  FreeRealModeMem(P);
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
  Reply,Request    : ^Buffer;
  NovRegs          : Registers; { register type for DOS/Novell calls       }
  S, P       : Pointer;
begin
  {building the packets for this call is a little more complex then most }
  {other NetWare APIs because the size of the fields are not  fixed,     }
  {meaning a Pascal record can not be used.  Instead, a 256 byte buffer  }
  {is set aside, and the Move() procedure is used to fill in the buffers.}
  FillChar(Result, SizeOf(Result), 0);
  if not GetRealModeMem(SizeOf(Buffer) shl 1, S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(P), SizeOf(Buffer));
  FillChar(Reply^, SizeOf(Reply^), 0);

  I := 1;
  W := SizeOf(Buffer) - SizeOf(Word);  {length of the Reply packet}
  Move(W,Reply^,SizeOf(Word));         {move length into place}
  L := Length(Msg);
  W := Connect.Count + L + 3;          {calculate size of Request packet}
  Move(W,Request^[I],SizeOf(Word));        {move size into place}
  Inc(I,SizeOf(Word));                 {point past size}
  Request^[I] := $04;                      {subfunction code}
  Inc(I);                              {point to next byte}
  W := Succ(Connect.Count);            {calculate size of connection list}
  Move(Connect,Request^[I],W);             {move Conn list into place}
  Inc(I,W);                            {point past conn list}
  W := Succ(L);                        {size of the Msg (a pascal string)}
  Move(Msg,Request^[I],W);                 {move Msg into place}
  Inc(I,W);

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E100;
    DS := SegOfs(S).Segm;    {DS:SI points to Req}
    SI := 0;
    ES := SegOfs(S).Segm;  {ES:DI points to Reply}
    DI := SizeOf(Buffer);
    WinIntr($21, NovRegs);
    {!!.21}
    if AL = 0 then
      Move(Reply^[3],Result,SizeOf(Result))   {return the result list}
    else
      FillChar(Result, SizeOf(Result), 0);
  end;
  FreeRealModeMem(P);
end;

procedure GetMessagePipe(var SourceConn : Byte; var Msg : MessageStr);

type
  TRequest         = record
                       Len  : Word;
                       SubF : Byte;
                     end;
var
  Request          : ^TRequest;
  Reply            : ^Buffer;
  W                : Word;
  NovRegs          : Registers; { register type for DOS/Novell calls       }
  S, P       : Pointer;

begin
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Buffer), S, P) then
    Exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  FillChar(Reply^, SizeOf(Reply^), 0);

  {initialize the Request packet}
  with Request^ do begin
    Len  := 1;
    SubF := $05;
  end;
  {building the Reply packet for this call is a little more complex then  }
  {most other NetWare APIs because the size of the fields are not  fixed, }
  {meaning a Pascal record can not be used.  Instead, a 256 byte buffer   }
  {is set aside, and the Move() procedure is used to fill in the buffer.  }

  W := SizeOf(Buffer) - SizeOf(Word); {calculate the size of the reply packet}
  Move(W,Reply^,SizeOf(Word));        {move size into place}

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E100;
    DS := SegOfs(S).Segm;   {DS:SI points to request packet}
    SI := 0;
    ES := SegOfs(S).Segm;   {ES:DI points to Reply packet}
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
  end;
  Move(Reply^[1],W,SizeOf(Word));    {get the length of the Reply packet}
  if (W > 1) and                    {!!.21}
     (NovRegs.AL = 0) then begin    {if length above zero then msg arrived}
    SourceConn := Reply^[3];         {return the connection num of msg source}
    Move(Reply^[4],Msg,Succ(Reply^[4])); {return the incoming message}
  end
  else begin                        {no incoming message}
    SourceConn := 0;                {return 0 for source connection}
    Msg := '';                      {return the empty string}
  end;
  FreeRealModeMem(P);
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
  Reply,Request    : ^Buffer;
  NovRegs          : Registers; { register type for DOS/Novell calls       }
  S, P             : Pointer;

begin
  {building the packets for this call is a little more complex then most }
  {other NetWare APIs because the size of the fields are not  fixed,     }
  {meaning a Pascal record can not be used.  Instead, a 256 byte buffer  }
  {is set aside, and the Move() procedure is used to fill in the buffers.}
  FillChar(Result, SizeOf(Result), 0);
  if not GetRealModeMem(SizeOf(Buffer) shl 1, S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(Buffer));
  FillChar(Reply^, SizeOf(Reply^), 0);

  W := SizeOf(Buffer) - SizeOf(Word);  {calculate size of the reply buffer}
  Move(W,Reply^,SizeOf(Word));          {move size into place}
  I := 1;
  W := Connect.Count + 2;              {calculate size of request buffer}
  Move(W,Request^[I],SizeOf(Word));         {move size into place}
  Inc(I,SizeOf(Word));                 {point past size word}
  Request^[I] := $08;                       {set subfunction}
  Inc(I);                              {point to next byte after subfunc}
  W := Succ(Connect.Count);            {calculate size of connection list}
  Move(Connect,Request^[I],W);              {move conn list into place}
  Inc(I,W);

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E100;
    DS := SegOfs(S).Segm;    {DS:SI points to request packet}
    SI := 0;
    ES := SegOfs(S).Segm;  {ES:DI points to reply packet}
    DI := SizeOf(Buffer);
    WinIntr($21, NovRegs);
    {!!.21}
    if AL = 0 then
      Move(Reply^[3],Result,SizeOf(Result)) {return the result list}
    else
      FillChar(Result, SizeOf(Result), 0);
  end;
  FreeRealModeMem(P);
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
  Reply,Request    : ^Buffer;
  NovRegs          : Registers; { register type for DOS/Novell calls       }
  S, P       : Pointer;
begin
  {building the packets for this call is a little more complex then most }
  {other NetWare APIs because the size of the fields are not  fixed,     }
  {meaning a Pascal record can not be used.  Instead, a 256 byte buffer  }
  {is set aside, and the Move() procedure is used to fill in the buffers.}
  FillChar(Result, SizeOf(Result), 0);
  if not GetRealModeMem(SizeOf(Buffer) shl 1, S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(Buffer));
  FillChar(Reply^, SizeOf(Reply^), 0);

  W := SizeOf(Buffer) - SizeOf(Word);  {calculate size of Reply buffer}
  Move(W,Reply^,SizeOf(Word));         {move size into place}
  I := 1;
  W := Connect.Count + 2;              {calculate size of request buffer}
  Move(W,Request^[I],SizeOf(Word));        {move size into place}
  Inc(I,SizeOf(Word));
  Request^[I] := $07;                      {subfunction value}
  Inc(I);
  W := Succ(Connect.Count);            {calculate size of conn list}
  Move(Connect,Request^[I],W);             {move Conn List into place}
  Inc(I,W);

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E100;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(Buffer);
    WinIntr($21, NovRegs);

    CloseMessagePipe := AL;            {return the error code}
    {!!.21}
    if AL = 0 then
      Move(Reply^[3],Result,SizeOf(Result)) {return the result list}
    else
      FillChar(Result, SizeOf(Result), 0);
  end;
  FreeRealModeMem(P);
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
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $C703;
    WinIntr($21, NovRegs);     {issue function C7h subfunc 3}
    TTSAbort := Lo(AX);     {return the error byte}
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
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $C700;       {issue function C7h subfunc 0}
    WinIntr($21, NovRegs);
    TTSBegin := Lo(AX);    {return the error byte}
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
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $C701;           {issue function C7h subfunc 1}
    WinIntr($21, NovRegs);
    ID := MakeLong(CX,DX); {make longint out of CX:DX and return as}
                           {Transaction reference ID}
    TTSEnd := Lo(AX);      {return the error byte}
  end
end;

procedure TTSGetAppThresh(var Logical,Physical : Byte);

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $C705;       {issue function C7h subfunc 1}
    WinIntr($21, NovRegs);
    Logical  := Lo(CX);    {return the logical threshold}
    Physical := Hi(CX);    {return the physical threshold}
  end;
end;

procedure TTSGetWSThresh(var Logical,Physical : Byte);

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $C707;       {issue function C7h subfunc 7}
    WinIntr($21, NovRegs);
    Logical  := Lo(CX);    {return the logical threshold}
    Physical := Hi(CX);    {return the physical threshold}
  end;
end;

function TTSAvailable : Boolean;

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $C702;             {issue function C7h subfunc 2}
    WinIntr($21, NovRegs);
    TTSAvailable := (Lo(AX) = 1);  {TTS avail if AL = 1}
  end
end;

function TTSSetAppThresh(Logical,Physical : Byte) : Byte;

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $C706;                       {issue function C7h subfunc 6}
    CX := (Physical shl 8) + Logical;  {CL gets new logical thresh}
    WinIntr($21, NovRegs);
    TTSSetAppThresh := Lo(AX);  {return the error byte}
  end;
end;

function TTSSetWSThresh(Logical,Physical : Byte) : Byte;

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $C708;            {issue function C7h subfunc 8}
    CX := (Physical shl 8) + Logical;          {CL gets new logical thresh}
    WinIntr($21, NovRegs);
    TTSSetWSThresh := Lo(AX);   {return the error byte}
  end;
end;

function TTSStatus(ID : LongInt) : Boolean;
{ returns TRUE if referenced transaction has been committed to disk }

var
  NovRegs          : Registers; { register type for DOS/Novell calls }

begin
  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin     {issue function C7h subfunc 4}
    AX := $C704;
    CX := DoubleWord(ID).HiWord; {CX gets high word of Trans Ref ID}
    DX := DoubleWord(ID).LoWord; {DX gets low word of Trans Ref ID}
    WinIntr($21, NovRegs);
    TTSStatus := Lo(AX) = 0;         {written to disk if AL is zero}
  end
end;

function TTSDisable : Boolean;

type
  TRequest         = Record
                       Len  : Word;
                       SubF : Byte;
                     end;
var
  Request          : ^TRequest;
  Reply            : ^Word;
  NovRegs          : Registers;
  S, P       : Pointer;

begin
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then
    Exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := 0;
  {initialize the request buffer}
  with Request^ do begin
    Len  := 1;
    SubF := $CF;
  end;

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E300;
    DS := SegOfs(S).Segm;     {DS:SI points to Request}
    SI := 0;
    ES := SegOfs(S).Segm;     {ES:DI points to Reply}
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    TTSDisable := AL = 0;   {TTS disabled if AL is zero}
  end;
  FreeRealModeMem(P);
end;

function TTSEnable : Boolean;

type
  TRequest         = Record
                       Len  : Word;
                       SubF : Byte;
                     end;
var
  Request          : ^TRequest;
  Reply            : ^Word;
  NovRegs          : Registers;
  S, P       : Pointer;

begin
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then
    Exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := 0;
  {init request packet}
  with Request^ do begin
    Len  := 1;
    SubF := $D0;
  end;

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E300;
    DS := SegOfs(S).Segm;  {DS:SI points to Request}
    SI := 0;     {ES:DI points to Reply}
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    TTSEnable := (AL = 0); {no error if AL = 0}
  end;
  FreeRealModeMem(P);
end;

procedure GetServerDateTime(var Year : Word;
                            var Month,Day,Hour,Minute,Second : Byte;
                            var WeekDay : DayOfTheWeek);

type
  ReplyBuffer      = array[1..10] of Byte;

var
  NovRegs          : Registers; { register type for DOS/Novell calls }
  Reply            : ^ReplyBuffer;
  S, P       : Pointer;
begin
  if not GetRealModeMem(SizeOf(ReplyBuffer), S, P) then exit;
  Reply := P;
  FillChar(Reply^, SizeOf(Reply^), 0);

  FillChar(NovRegs, SizeOf(NovRegs), 0);
  with NovRegs do begin
    AX := $E700;
    DS := SegOfs(S).Segm;    {point DS:DX at buffer}
    DX := 0;
  end;
  WinIntr($21, NovRegs);        {issue the call}

  Year    := Word(Reply^[1]) + 1900;  {return year}
  Month   := Word(Reply^[2]);         {return month}
  Day     := Word(Reply^[3]);         {return day}
  Hour    := Word(Reply^[4]);         {return hour}
  Minute  := Word(Reply^[5]);         {return minute}
  Second  := Word(Reply^[6]);         {return second}
  WeekDay := DayOfTheWeek(Reply^[7]); {return the day of the week as enum}

  FreeRealModeMem(P);
end;

procedure GetWSInfo(var ShellMajor,ShellMinor,ShellRevision : Byte;
                    var OSType,OSVer,Hardware : String);
type
  Buffer           = Array[1..40] of Char;
var
  NovRegs          : Registers; { register type for DOS/Novell calls }
  BufPtr           : ^Buffer;
  I                : Word;
  S, P             : Pointer;
begin
  {This function call supported by NetWare versions }
  FillChar(NovRegs, SizeOf(NovRegs), 0);
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


  if not GetRealModeMem(SizeOf(Buffer), S, P) then
    Exit;
  BufPtr := P;

  with NovRegs do begin
    AX := $EA01;
    ES := SegOfs(S).Segm;
    DI := 0;
    WinIntr($21, NovRegs);
    ShellMajor    := Hi(BX);
    ShellMinor    := Lo(BX);
    ShellRevision := Lo(CX);
  end;

  {the buffer contains 4 asciiz strings (only three are returned by this}
  {procedure) one after another}
  OSType := AsciiZ2Str(BufPtr^[1],10); {return the first string}
  I := Length(OSType) + 2;         {point past first string (account for #0)}
  OSVer  := AsciiZ2Str(BufPtr^[I],10); {return the second string}
  Inc(I,Length(OSVer)+1);          {point past second string (account for #0)}
  HardWare := AsciiZ2Str(BufPtr^[I],10); {return the third string}

  FreeRealModeMem(P);
end;

function GetDriverConfiguration(LanBoard : Byte;
                                var Driver : DriverInformation) : Boolean;

type
  TRequest = record
    Len : Word;
    SubF : Byte;
    LanNo : Byte;
  end;
  TReply = record
    Len : Word;
    NetAdd : LongInt;
    HostAdd : PhysicalNodeAddress;
    DriverInstalled : Byte;
    OptNum : Byte;
    Buffer : Array[1..160] of Char;
  end;

var
  Request     : ^TRequest;
  Reply       : ^TReply;
  NovRegs     : Registers;
  S, P        : Pointer;
  I           : Byte;

begin
  GetDriverConfiguration := False;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then
    Exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  FillChar(Reply^, SizeOf(Reply^), 0);

  {init reply packet}
  Reply^.Len := 172;
  {init request packet}
  with Request^ do begin
    Len  := 2;
    SubF := $E3;
    LanNo := LanBoard;
  end;

  with NovRegs do begin
    AX := $E300;
    DS := SegOfs(S).Segm;  {DS:SI points to Request}
    SI := 0;       {ES:DI points to Reply}
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    {!!.21}
    if (AL = 0) and (Reply^.DriverInstalled <> 0) then begin
      GetDriverConfiguration := True;
      with Driver do begin
        NetworkAddress := Reply^.NetAdd;
        HostAddress := Reply^.HostAdd;
        OptionNumber := Reply^.OptNum;
        LanBoardName := AsciiZ2Str(Reply^.Buffer[1],80); {return the first string}
        I := Length(LanBoardName) + 2;  {point past first string (account for #0)}
        HardwareSettings := AsciiZ2Str(Reply^.Buffer[I],80);
      end;
    end
    else begin
      FillChar(Driver, SizeOf(Driver), 0);
      GetDriverConfiguration := False;
    end;
    FreeRealModeMem(P);
  end;
end;

function IPXInstalled;                      external 'IPXSPXD' index 2;
function IPXServicesAvail;                  external 'IPXSPXD' index 3;
function IPXOpenSocketPrim;                 external 'IPXSPXD' index 4;
procedure IPXCloseSocketPrim;               external 'IPXSPXD' index 5;
function IPXOpenSocket;                     external 'IPXSPXD' index 6;
procedure IPXCloseSocket;                   external 'IPXSPXD' index 7;
function IPXAssignUniqueSocket;             external 'IPXSPXD' index 8;
procedure IPXInternetAddress;               external 'IPXSPXD' index 13;
function AllocateWinIPXRec;                 external 'IPXSPXD' index 20;
procedure FreeWinIPXRec;                    external 'IPXSPXD' index 21;
function IPXSend;                           external 'IPXSPXD' index 22;
function IPXListen;                         external 'IPXSPXD' index 23;
function IPXCancelEvent;                    external 'IPXSPXD' index 19;
function IPXEventComplete;                  external 'IPXSPXD' index 18;
procedure IPXRelinquish;                    external 'IPXSPXD' index 12;
function AllocateWinSPXRec;                 external 'IPXSPXD' index 43;
procedure FreeWinSPXRec;                    external 'IPXSPXD' index 44;
function SPXServicesAvail;                  external 'IPXSPXD' index 32;
function SPXEstablishConn;                  external 'IPXSPXD' index 41;
function SPXListenForConn;                  external 'IPXSPXD' index 42;
function SPXEventComplete;                  external 'IPXSPXD' index 33;
function PoolAllocate;                      external 'IPXSPXD' index 39;
function PoolDeallocate;                    external 'IPXSPXD' index 40;
procedure SPXAbortConn;                     external 'IPXSPXD' index 46;
procedure SPXSend;                          external 'IPXSPXD' index 48;
function SPXListenPooled;                   external 'IPXSPXD' index 53;
function AllocateWindowsESR;                external 'IPXSPXD' index 57;
procedure FreeWindowsESR;                   external 'IPXSPXD' index 58;
procedure SPXTerminateConn;                 external 'IPXSPXD' index 47;
function SPXPoolCancelAll;                  external 'IPXSPXD' index 50;
function SPXPoolECBPtr;                     external 'IPXSPXD' index 51;
function SPXPoolDataPtr;                    external 'IPXSPXD' index 52;
procedure SPXPoolStartListening;            external 'IPXSPXD' index 34;
procedure SPXReplenishPool;                 external 'IPXSPXD' index 54;
procedure SPXReplenishAll;                  external 'IPXSPXD' index 55;
function SPXListenCount;                    external 'IPXSPXD' index 56;
function GetSPXWatchdog;                    external 'IPXSPXD' index 59;
procedure SetSPXWatchdog;                   external 'IPXSPXD' index 60;
function GetSPXRetryCount;                  external 'IPXSPXD' index 61;
procedure SetSPXRetryCount;                 external 'IPXSPXD' index 62;
function AllocateWinAESECB;                 external 'IPXSPXD' index 63;
procedure FreeWinAESECB;                    external 'IPXSPXD' index 64;
procedure IPXScheduleEvent;                 external 'IPXSPXD' index 14;
procedure IPXScheduleSpecialEvent;          external 'IPXSPXD' index 15;
function SPXConnStatus;                     external 'IPXSPXD' index 29;
