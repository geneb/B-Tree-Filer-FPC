{*********************************************************}
{*                   NETWARE.PAS 5.41                    *}
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

unit NetWare;

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
  MaxConnections  = 255; {NetWare 386 currently supports up to 255 workstations}

  NWShareable     = $80;

  { Effective Rights constants represent bit in Mask }
  NWRead          = $01;
  NWWrite         = $02;
  NWOpen          = $04;
  NWCreate        = $08;
  NWDelete        = $10;
  NWParental      = $20;
  NWSearch        = $40;
  NWModify        = $80;

  { status byte }
  NWPermanent     = $01;
  NWTemporary     = $02;
  NWLocal         = $80;

{gerneral error codes }
  NWSuccess       = $00;

  SPXPacketType  = 5;      {indicates that a packet belongs to SPX}

{IPX Error Codes}
  IPXSuccess       = 0;
  IPXDataTooLarge  = 1;      {user  specified data is larger than maximum}

  IPXSocketAlreadyOpen       {attempted to open already open socket}
                   = $FF;
  IPXSocketTableFull
                   = $FE;    {this connection may not have any more open any}
                             {more sockets}
  IPXCancelled     = $FC;    {the event was cancelled}
  IPXMalformedPacket
                   = $FD;    {packet not proper size and/or format}
  IPXPacketUndeliverable
                   = $FE;    {can not deliver the packet}
  IPXPhysicalError = $FF;
  IPXPacketOverflow= $FD;    {more data received than buffer size specified}
  IPXSocketNotOpen = $FF;    {the socket for communications is not open}

{SPX constants}
  SPXEndOfMessage = $10;
  SPXEndOfConn    = $FE;

{SPX ECB Pool Constants}
  MaxECBPool = 32;
  PoolSocketLongevity : Boolean = FALSE;

{$IFDEF DPMIOrWnd}
const
  DPMIErrorVal  = $AA;   {returned when a DPMI service request failed}
{$ENDIF}

type
  Str9             = String[9];
  Str10            = String[10];
  Str20            = String[20];
  PasswordStr      = String[27];
  ObjectStr        = String[47];
  ServerName       = String[48];  {string type used for server name table}
  BroadcastStr     = String[55];  {string type for broadcast strings}
  PathName         = String;      {string type used for filespecs}
  Str80            = String[80];
  MessageStr       = String[126]; {string type used for message services}

  PhysicalNodeAddress
                   = array[1..6] of Byte; {a 6 byte integer type for NetWare}
                                          {node addresses}

  PrinterDevice    = (LPT1,LPT2,LPT3);    { enum type to hold LPT number }

  BinderyObject    = (ObjUnknown,
                      ObjUser,
                      ObjGroup,
                      ObjPrintServer,
                      ObjFileServer,
                      ObjJobServer,
                      ObjGateway,
                      ObjReserved0,
                      ObjArchiveServer,
                      ObjReserved1,
                      ObjJobQueue,
                      ObjWild);

  FileServerNameTable
                   = Array[1..8] of ServerName; {holds the names of up to 8}
                                                {file servers}
  ServerInformation
                   = record
                       Len         : Word;
                       ServName    : Array[1..48] of Char;
                       NetWareVer  : Byte;
                       NetWareSub  : Byte;
                       MaxConns    : Word; {h-l}
                       UsedConns   : Word; {h-l}
                       MaxVols     : Word; {h-l}
                       Revision    : Byte;
                       SFTLevel    : Byte;
                       TTSLevel    : Byte;
                       PeakConn    : Word; {h-l}
                       AccountVer  : Byte;
                       VAPVer      : Byte;
                       QueueVer    : Byte;
                       PrintServVer: Byte;
                       VirtualVer  : Byte;
                       SecurityVer : Byte;
                       BridgeVer   : Byte;
                       Reserved    : Array[1..60] of Byte;
                     end;

  DriverInformation =
    record
      NetworkAddress : LongInt;           {The network address}
      HostAddress : PhysicalNodeAddress;  {The node address of the server}
      OptionNumber : Byte;                {the installation option number}
      LanBoardName,                       {the name of the LAN board}
      HardwareSettings : Str80;           {technical info about the board}
    end;

  ConnectionList   = record  {this type is used extensively by the messaging}
                             {services}
                       Count : Byte;                  {the number of conns}
                       List  : Array[1..MaxConnections] of Byte; {the conn list}
                     end;

  {enum type representing the 7 days of the week}
  DayOfTheWeek     = (Sunday,Monday,Tuesday,Wednesday,Thursday,
                      Friday,Saturday);

  {the date/time record used internally by NetWare.  The year is stored as
   a byte.  If the year is greater than or equal to 80, then the year refers
   to the twentieth century (1980-1999), if it is less than 80, then it refers
   to a year in the twenty-first century
  }
  NovDateType      = record
                       Year,                     {80=1980}
                       Month,
                       Day,
                       Hour,
                       Minute,
                       Second     : Byte;
                       WeekDay    : DayOfTheWeek;
                       Filler     : Byte;    {!!.03}
                     end;

  {record type used to return information about a specific connection number}
  ConnInfoType     = record
                       ObjectID   : LongInt;     {the logged in object's ID}
                       ObjectType : Word;        {the logged object's type}
                       ObjectName : String[48];  {the name of the object}
                       LoginDate  : NovDateType; {the time/date the object}
                                                 {logged on to connection}
                     end;

  PrintJobType     = record
                       Status     : Byte; {a value of 0 here means that   }
                                          {print job flags are enabled and}
                                          {cannot be changed}
                       Flags      : Byte; {Print flags:
                                             04h - print interrupted capture
                                             08h - Suppress auto form feed
                                             40h - Enable tab expansion
                                             80h - Print Banner page
                                           }
                       TabSize    : Byte; {tab size (1..18) }
                       ServerPrinter
                                  : Byte; {0..4}
                       NumCopies  : Byte; {Number of copies (0..255) }
                       FormType   : Byte; {Form type (0..255) }
                       Reserved   : Byte;
                       Banner     : Array[1..13] of Char; {asciiz string}
                       Reserved2  : Byte;
                       LocalLPT   : Byte; {local LPT device (0..2) }
                       FlushCaptureTimeout
                                  : Word; {in units of clock ticks (about
                                           1/18 of a second) }
                       FlushCaptureOnClose
                                  : Byte; {0 = enabled}
                     end;

  {a record type to hold the three part internet addresses for IPX/SPX}
  IPXAddress       = record
                       Network         : LongInt; {high-low}
                       Node            : PhysicalNodeAddress;
                       Socket          : Word;
                     end;

  {the header structure for IPX calls}
  IPXHeader        = record
                       CheckSum        : Word;
                       Len             : Word;
                       TransportControl: Byte;
                       PacketType      : Byte;
                       Destination     : IPXAddress;
                       Source          : IPXAddress;
                     end;

  {the record type used to represent a buffer fragment descriptor for IPX/SPX}
  FragmentDescriptor
                   = record
                       Address         : Pointer;  {the data}
                       Size            : Word;     {the size of the data}
                     end;

  {The IPX/SPX Event Control Block}
  IPXECB           = record
                       Link            : Pointer;  {used internally}
                       ESRAddress      : Pointer;  {the Event Service Routine}
                       InUse           : Byte;     {inuse semaphore}
                       CompletionCode  : Byte;     {error code}
                       SocketNumber    : Word;     {the session socket}
                       IPXWorkSpace    : LongInt;  {reserved for internal use}
                       DriverWorkSpace : Array[1..12] of Byte; {reserved}
                       ImmediateAddress: PhysicalNodeAddress;  {the internet}
                                                               {address}
                       FragmentCount   : Word;     {the number of buffers}
                       FD1             : FragmentDescriptor; {buffer 1}
                       FD2             : FragmentDescriptor; {buffer 2}
                       FD3             : FragmentDescriptor; {buffer 3}
                       FD4             : FragmentDescriptor; {buffer 4}
                     end;

  ECBPtr           = ^IPXECB;
  AESECB           = record
                       Link            : Pointer;
                       ESRAddress      : Pointer;
                       InUse           : Byte;
                       AESWorkSpace    : Array[1..5] of Byte;
                     end;
  {$IFDEF DPMIOrWnd}
  WinIPXECB =
    record
      ECBR, ECBP : ECBPtr;
    end;
  AESECBPtr        = ^AESECB;
  WinAESECB =
    record
      AESECBR, AESECBP : AESECBPtr;
    end;
  {$ENDIF}


  IPXRec =
    record
      IPXHead : IPXHeader;
      ECB     : IPXECB;
    end;
  IPXRecPtr = ^IPXRec;
  WinIPXRec =
    record
      wirP,
      wirR : IPXRecPtr;
    end;

  {the following type is used by the SPXConnStatus function, see its}
  {interface and implementation (in IPXSPX.INC) for more details}
  SPXStatusBlock   = record
                       State           : Byte;
                       Flag            : Byte;
                       SourceConn      : Word; {high-low}
                       DestConn        : Word; {high-low}
                       SequenceNum     : Word; {high-low}
                       AckNum          : Word; {high-low}
                       AllocNum        : Word; {high-low}
                       RemoteAckNum    : Word; {high-low}
                       RemoteAllocNum  : Word; {high-low}
                       ConnSocket      : Word;
                       ImmediateAdd    : PhysicalNodeAddress;
                       Destination     : IPXAddress;
                       RetransmitCount : Word; {high-low}
                       EstimatedRoundTripDelay
                                       : Word; {high-low}
                       RetransmittedPackets
                                       : Word; {high-low}
                       SuppressedPackets
                                       : Word; {high-low}
                     end;
  SPXHeader        = record
                       IPXPacket       : IPXHeader;
                       ConnectControl  : Byte;
                       DataStreamType  : Byte;
                       SourceConnID    : Word;
                       DestConnID      : Word;
                       Sequence        : Word;
                       Acknowledge     : Word;
                       Allocation      : Word;
                     end;
  SPXHeaderPtr     = ^SPXHeader;
  {$IFDEF DPMIOrWnd}
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
  PoolECB = record
              ECB : WinIPXECB;
              Header : SPXHeader;
              DataR, DataP : Pointer;
            end;
  PoolECBPtr = ^PoolECB;
  WinPoolECB =
    record
      wpeR, wpeP : PoolECBPtr;
    end;
  SPXPool          = Array[1..MaxECBPool] of WinPoolECB;
  {$ELSE}
  PoolECB = record
              ECB : IPXECB;
              Header : SPXHeader;
              Data : Pointer;
            end;
  SPXPool          = Array[1..MaxECBPool] of PoolECB;
  {$ENDIF}
  SPXPoolPtr       = ^SPXPool;
  SPXPoolQueue     = Array[1..MaxECBPool] of Byte;
  SPXPoolQueuePtr  = ^SPXPoolQueue;
  {$IFDEF DPMIOrWnd}
  SPXPoolRecPtr    = ^SPXPoolRec;
  SPXPoolRec       = record
                       NumInPool : Byte;
                       DataSize  : Word;
                       PoolR, PoolP : SPXPoolPtr;
                       PoolQueueR, PoolQueueP : SPXPoolQueuePtr;
                       PoolQP    : Byte; {queue pointer}
                       PoolQS    : Byte; {queue size}
                       PoolQO    : Byte; {queue origin}
                       QueueOverflow
                                 : Boolean;
                     end;
  {$ELSE}
  SPXPoolRec       = record
                       NumInPool : Byte;
                       DataSize  : Word;
                       Pool      : SPXPoolPtr;
                       PoolQueue : SPXPoolQueuePtr;
                       PoolQP    : Byte; {queue pointer}
                       PoolQS    : Byte; {queue size}
                       PoolQO    : Byte; {queue origin}
                       QueueOverflow
                                 : Boolean;
                     end;
  {$ENDIF}
  {$IFDEF DPMIOrWnd}
  WinSPXPoolRec =
    record
      prR, prP : SPXPoolRecPtr;
    end;
  SPXRec =
    record
      ConnID : Word;
      SPXHead : SPXHeader;
      ECB : WinIPXECB;
      PoolRec : WinSPXPoolRec;
    end;
  {$ELSE}
  SPXRec =
    record
      ConnID : Word;
      SPXHead : SPXHeader;
      ECB : IPXECB;
      PoolRec : SPXPoolRec;
    end;

  {$ENDIF}
  SPXRecPtr = ^SPXRec;
  {$IFDEF DPMIOrWnd}
  WinSPXRec =
    record
      wsrR, wsrP : SPXRecPtr;
    end;
  {$ENDIF}
  TargetType =
    record
      IPXAdd : IPXAddress;
      TargetNode : PhysicalNodeAddress;
    end;
  {$IFDEF DPMIOrWnd}
  WindowsESRProc = Pointer;
  UserESRType = procedure (var SPXEvent : WinSPXRec;
                           CompletionCode : Byte;
                           PoolIndex : Byte;
                           DataType : Byte;
                           DataPtr : Pointer);
  WinESRType =
    record
      Regs     : DPMIReg;
      PoolPtr  : SPXPoolRecPtr;
      CallBack : Pointer;
      UserESR  : UserESRType;
      DataSegm : Word;
    end;
  Registers = TRegisters;
  {$ENDIF}

const
  {$IFDEF DPMIOrWnd}
  NilPtr           : Pointer = Nil;
  {$ELSE}
  SPXWatchDog      : Boolean = FALSE; {do not use SPX watchdog services}
  SPXRetryCount    : Byte = 0; {indicates to use the default retry count}
  {$ENDIF}
  LPTNames         : Array[PrinterDevice] of String[4] = ('LPT1',
                                                          'LPT2',
                                                          'LPT3');

  AllNodes         : PhysicalNodeAddress = ($FF,$FF,$FF,$FF,$FF,$FF);

var
  {$IFDEF DPMIOrWnd}
  NoESR            : UserESRType absolute NilPtr;
  {$ELSE}
  IPXLocation      : Pointer;
  {$ENDIF}
  DefaultServerInfo
                   : ServerInformation;

{$IFDEF DPMIOrWnd}
const
  DPMIError : Word = 0;

var
  RealMode : Boolean;
{$ENDIF}

function NetWareLoaded(var LoggedOn : Boolean) : Boolean;
  {-Returns True if NetWare shell is loaded at the calling workstation. If
    shell is loaded, the LoggedOn will be true if a user is logged on.}

function IsNetWare3 : Boolean; {!!.21}
  {-Return True if NetWare 386 (version 3.0 or greater) installed}

{***************************************************************
  File, Drive and Directory Services
***************************************************************}

function GetExtFAttr(Path : PathName; var Attributes : Byte) : Byte;
{
  Meaning of Attributes:
  7   6   5   4   3   2   1   0
  |   |   |   |       |   |   |
  |   |   |   |       +---+---+------Search mode  \[210\]
  |   |   |   +----------------------transactional bit \[4\]
  |   |   +--------------------------Indexing bit \[5\]
  |   +------------------------------Read Audit bit \[6\]
  +----------------------------------Write Audit bit \[7\]
  Function returns error code:
    0  - Success
    2  - File not found
    18 - No more files (requesting workstation does not have search
                        rights)
}

function SetExtFAttr(Path : PathName; Attr : Byte) : Byte;
{
  See GetExtFAttr for meaning of Attr the Attribute
  Function returns error code:
    0  - Success
    2  - File not found
    5  - Access denied
}

function FileIsShareable(Path : PathName; var FAttr : Word; var ErrCode : Word)
                       : Boolean;
{ Return TRUE if ifle is flagged as shareable, return file attrib in FAttr }

function MakeFileShareable(Path : PathName) : Byte;
{ Flags a file as Shareable.  Returns zero if successful, or DOS error code
  if not.
}

{***************************************************************
  Server and Workstation Assorted Services
***************************************************************}

procedure GetServerDateTime(var Year : Word;
                            var Month,Day,Hour,Minute,Second : Byte;
                            var WeekDay : DayOfTheWeek);
{ Gets the network time of day and day, month an year info from the file
  server.
}

procedure GetWSInfo(var ShellMajor,ShellMinor,ShellRevision : Byte;
                    var OSType,OSVer,Hardware : String);
{Gets the NetWare shell version number and other info from the server.}

function ConsolePriv : Boolean;
{returns TRUE if this station has CONSOLE privelges}

function GetConnNo : Byte;
{ returns connection number of requesting WS (1..MaxConnection) }

procedure GetInternetAddress(ConnNo : Byte; var InternetAdd : IPXAddress);
{ Returns the IPX Address for the specified connection number. The IPX address
  consists of the Network number, the physical node address, and the socket.
  The socket returned by this function is the socket used by the NetWare shell
  uses to communicate with the file server. This socket MUST NOT be used by
  other applications.
}

procedure GetObjConnNumbers(ObjectName : ObjectStr;
                            ObjectType : BinderyObject;
                            var Conns : ConnectionList);
{Return all connections with the specified object and object type logged in}

procedure GetConnInfo(ConnNo : Byte; var ConnInfo : ConnInfoType);
{Get information about the object logged on to a given connection. The
 information returned includes the object's ID, the object type, the object's
 name, and the time and date it logged on to the connection.
}

function GetConnFromName(LoConn,HiConn : Byte; ObjName : String) : Byte;
{Search connection number LoConn to HiConn looking for a user with
 ObjName. Return the connection number of the first connection found with
 that user logged on. If no connection found with ObjName as a user, then
 returns zero.}

function ServerConnNo: Byte;
{Returns connection number of default file server (1..8) }

function PreferredServerConnNo : Byte;
{Returns the connection number of the preferred file server}

procedure SetPreferredServerConn(ServConnNo : Byte);
{Sets the preferred file server.  ServConnNo must be an active fileserver that
 the workstation has previously attached to and logged into. The value of the
 preferred file server is automatically reset to 0 (meaning no preferred file
 server selected, so default server is used) when an application terminates.}

function PrimaryServerConnNo : Byte;
{returns the connection number of the primary file server}

procedure ServerNameTable(var Servers : FileServerNameTable);
{ returns the NetWare file server name table}

procedure GetServerInfo(var ServerInfo : ServerInformation);
{ returns assorted information about the file server}

function GetDriverConfiguration(LanBoard : Byte;
                                var Driver : DriverInformation) : Boolean;

function GetDirHandle(Drive : Char; var StatusFlags : Byte) : Byte;
{ returns directory handle and status flags for a drive }
{ return byte:
  00   - Invalid Drive Number
  otherwise returned directory handle

  Status Byte
  7  6  5  4  3  2  1  0
  |                 |  +-Permanent Directory Handle
  |                 +----Temporary Directory Handle
  +----------------------Mapped to a local drive
}

function GetDirRights(DirHandle : Byte; PathName : String;
                      var Rights : Byte) : Byte;
{ returns the requesting workstation's effective directory rights }
{ return byte
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

function GetDirPath(DirHandle : Byte; var DirPath : String) : Byte;
{ returns the pathname of a directory handle }

function IsLockModeExtended : Boolean;
{
  returns TRUE if using Advanced NetWare Extended Lock Mode, if FALSE,
  then in compatibility mode (for compat with NetWare 4.61 and prior).
}

procedure SetLockMode(Extended : Boolean);
{ sets the lock mode.  If Extended is TRUE, then Extended Lock mode}
{ is selected, else compatibility lock mode is selected.  Advanced }
{ NetWare defaults to Compatibility lock mode so applications      }
{ written prior to NetWare 4.61 will be compatable.}

function GetCurrentDrive : Char;
{ returns the current drive}

{***************************************************************
   Printing Services
***************************************************************}

function SpoolExistingFile(FName : String) : Byte;
{ submits an existing file to the print queue (like NPRINT) }
{ returns 0 for success, $9C on path not found, or $98 for  }
{ requested file not on server. }

function SpecifyCaptureFile(FName : String) : Byte;

procedure GetPrinterStatus(NovellPrinter : Byte;
                           var PrinterNo, FormType : Byte;
                           var OffLine, Stopped : Boolean);

function GetDefaultLocalPrinter : PrinterDevice;

procedure SetDefaultLocalPrinter(LPTNo : PrinterDevice);

function GetBannerUser(var BannerUser : Str20) : Boolean;

function SetBannerUser(UserName : Str20) : Boolean;


function CancelLPTCapture : Byte;
{ abort capture of default LPT device }

function EndLPTCapture : Byte;
{ end the capture of default LPT device (like ENDSPOOL) }

function FlushLPTCapture : Byte;
{ Flush capture of default LPT device (like running SPOOL or CAPTURE again
  while spooling }

function StartLPTCapture : Byte;
{ Start Capture of default LPT device (Like running SPOOL or CAPTURE) }

function LPTCaptureActive(var QueServer : Byte) : Boolean;
{ Returns true if spooling is occurring now.  If so return the QueServer
  number}

procedure GetPrintJobFlags(var PrintJob : PrintJobType);
{ gets the print job flags}

procedure SetPrintJobFlags(var PrintJob : PrintJobType);

{***********************************************************************}

procedure LogNetWorkMessage(Message : Str80);
{ log the message to the network log }

procedure BroadcastToConsole(Message : Str80);
{ send a message to the CONSOLE ie. the colon prompt : }

procedure GetBroadcastMsg(var Message : Str80);
{ returns a broadcast message from the default file server if one is
  available.
}

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

function GetBroadcastMode : Byte;
{ Returns the current broadcast mode.  Mode is interpreted as follows:

  Broadcast mode   server   Shell
==========================================
             0     Store    Retrieve and display
             1     Reject   Retrieve and display
             2     Reject   Ignore
             3     Store    Ignore
}

procedure SetBroadcastMode(Mode : Byte);
{ Mode explained in GetBroadcastMode }

procedure OpenMessagePipe(var Connect,Result : ConnectionList);
{Attempts tp open a message pipe with the connections specified in Connect}

procedure SendMessagePipe(Msg : MessageStr;
                         var Connect,Result : ConnectionList);
{
  Result codes in Result:
    00h  - Success (message entered into pipe)
    FCh  - Pipe Full (message rejected)
    FEh  - Incomplete pipe (pipe doesn't exist)
    FFh  - Failure (invalid pipe or connection number)
}

procedure GetMessagePipe(var SourceConn : Byte; var Msg : MessageStr);
{Retrieves a message from connection SourceConn if one is available, if not,
 Msg will be the empty string}

function CloseMessagePipe(var Connect,Result : ConnectionList) : Byte;
{
return byte
  00h  - Success
  FCh  - Message Queue is full

  Result codes in Result:
    00h  - Success (message pipe broken)
    FDh  - Failure (target connection invalid, logged out?)
    FFh  - No pipe exists
}

procedure CheckMessagePipe(var Connect,Result : ConnectionList);
{
  Result codes in Result:
    00h  - Success (message pipe exists)
    FEh  - Incomplete pipe (pipe doesn't exist)
    FFh  - Failure (invalid pipe or connection number)
}

{***************************************************************
  Transaction Tracking Services
***************************************************************}

function TTSAbort : Byte;
{ Return code:
  00h  - success
  FDh  - TTS Disabled
  FEh  - Transaction ends records locked (trans aborted, but recs left locked)
  FFh  - no explicit transaction active
}

function TTSBegin : Byte;
{ return code:
  00h  - Success
  96h  - Out of Dynamic Workspace
  FEh  - Implicit transaction active (active implicit turned into explicit)
  FFh  - Explicit Transaction active
}

function TTSEnd(var ID : LongInt)  : Byte;
{ return code:
  00h  - Success
  FDh  - TTS Disabled
  FEh  - Tranaction ends records locked
  FFh  - No Explicit transaction active
}

function TTSStatus(ID : LongInt) : Boolean;
{ returns TRUE if referenced transaction has been committed to disk }

procedure TTSGetAppThresh(var Logical,Physical : Byte);
{ returns the application's logical and physical threshold values for implicit
  transaction tracking}

procedure TTSGetWSThresh(var Logical,Physical : Byte);
{ returns the workstation's logical and physical threshold values for implicit
  transaction tracking}

function TTSAvailable : Boolean;
{ returns TRUE if Transaction Tracking Services are available}

function TTSDisable : Boolean;
{ Disables TTS services. Returns TRUE if TTS services successfully disables.}

function TTSEnable : Boolean;
{ Enables TTS services. Returns TRUE if TTS services successfully enabled.
  NOTE: You should always determine that TTS services are available (by
  calling TTSAvailable) before issuing a TTSEnable. NetWare will often
  report TRUE for a TTSEnable if it is called but TTS is not available.
}

{$IFDEF DPMIOrWnd}

function IPXInstalled : Boolean;
function IPXServicesAvail : Boolean;
procedure IPXInternetAddress(var Address : IPXAddress);
function IpxOpenSocketPrim(RequestedSocket : Word; Forever : Boolean) : Byte;
procedure IpxCloseSocketPrim(RequestedSocket : Word);
function IPXOpenSocket(RequestedSocket : Word;
                       Forever : Boolean) : Byte;
procedure IPXCloseSocket(SocketNum : Word);
procedure IPXRelinquish;
function IPXAssignUniqueSocket(var ReturnedSocket : Word; Forever : Boolean) : Word;
function IPXCancelEvent(IPXEvent : WinIPXRec) : Byte;
function IPXEventComplete(IPXEvent : WinIPXRec;
                          var FinalResult : Byte) : Boolean;


function IPXSend(IPXEvent : WinIPXRec;
                 Receiver : IPXAddress;
                 Socket : Word;
                 WaitForCompletion : Boolean;
                 DataPacketSize : Word;
                 var DataPacket) : Byte;
function IPXListen(IPXEvent : WinIPXRec;
                   Socket : Word;
                   WaitForCompletion : Boolean;
                   MaxPacketSize : Word;
                   var DataPacket) : Byte;

function AllocateWinIPXRec(DataSize : Word;
                        var Event : WinIPXRec) : Boolean;
  {-Allocates a WinIPXRec which contains pointers to an IPXRec addressable in
    both real and protected modes. Also allocates space for the data
    addressable in real mode.}

procedure FreeWinIPXRec(Event : WinIPXRec);
  {-Frees a WinIPXRec previously allocated with AllocateWinIPXRec. The event
    associated with this WinIPXRec must be completed or cancelled before this
    procedure is called.}

function AllocateWinAESECB(DataSize : Word;
                           var ECB : WinAESECB) : Boolean;
  {-Allocates a WinAESECB which contains pointers to an AESECB addressable in
    both real and protected modes. Also allocates space for the data
    addressable in real mode.}

procedure FreeWinAESECB(ECB : WinAESECB);
  {-Frees a WinAESECB previously allocated with AllocateWinAESECB. The event
    associated with this WinAESECB must be completed or cancelled before this
    procedure is called.}

{ SPX Services }
function AllocateWinSPXRec(var WSR : WinSPXRec) : Boolean;
  {-Allocates a WinSPXRec which contains pointers to an SPXRec addressable in
    both real and protected modes. Also allocates space for the data
    addressable in real mode.}

procedure FreeWinSPXRec(WSR : WinSPXRec);
  {-Frees a WinSPXRec previously allocated with AllocateSPXRec. The event
    associated with this WinSPXRec must be completed or cancelled before this
    procedure is called.}

procedure IPXScheduleEvent(DelayTime : Word; ECB : WinIPXECB);

procedure IPXScheduleSpecialEvent(DelayTime : Word;
                                  ECB : WinAESECB);


function SPXServicesAvail(var Version : Word; var MaxSPXConn : Word;
                          var AvailSPXConn : Word) : Boolean;
{ This function Check to see if SPX services are available.  It returns
  TRUE is they are, and FALSE if they are not. If IPX services are available,
  The version number of the SPX driver is returned in the first VAR
  parameter (version major in high byte, minor in low), and the maximum number
  of SPX connections supported and the number of available SPX connections are
  returned in the next two. }

function SPXEstablishConn(var SPXEvent : WinSPXRec;
                          Receiver : IPXAddress;
                          Socket : Word;
                          WaitForCompletion : Boolean;
                          MaxListenDataSize : Word;
                          NumListenPoolECBs : Byte;
                          var WinESR : WinESRType) : Byte;
{The high level SPX function to establish a connection with a partner SPX
 client. This routine isolates the programmer from the details of building the
 SPX header and the Event Control Block. It is designed for use with the
 SPXListenForConn function.

 MaxDataSize is the maximum size for the data buffer for each ECB in the
 Listen ECB Pool. NumPoolECBs is the number of Listen ECBs to allocate for the
 Pool (MUST be at least 1).
 ***********
 PoolESRInPascal points to a Pascal ESR (see
 PoolAllocate and PascalPoolESR for more info on ESRs in Pascal). If no user
 ESR is required, pass NIL for this parameter.
 ************}

function SPXConnStatus(ConnID : Word;
                       var SPXStatusBuf : SPXStatusBlock) : Boolean;
  {-Returns the status of an SPX connection}

function SPXListenForConn(var SPXEvent : WinSPXRec;
                          Socket : Word;
                          WaitForCompletion : Boolean;
                          MaxDataSize : Word;
                          NumPoolECBs : Byte;
                          var WinESR : WinESRType) : Byte;

{The high level SPX function to establish a connection with a partner SPX
 client. This routine isolates the programmer from the details of building the
 SPX header and the Event Control Block. It is designed for use with the
 SPXEstablishConn function.

 MaxDataSize is the maximum size for the data buffer for each ECB in the
 Listen ECB Pool. NumPoolECBs is the number of Listen ECBs to allocate for the
 Pool (MUST be at least one).
 ***************
 PoolESRInPascal points to a Pascal ESR (see
 PoolAllocate and PascalPoolESR for more info on ESRs in Pascal). If no user
 ESR is required, pass NIL for this parameter.
 **************}

function SPXEventComplete(SPXEvent : WinSPXRec;
                          var FinalResult : Byte;
                          var DataType : Byte) : Boolean;

function SPXPoolECBPtr(PoolRec : WinSPXPoolRec; PoolIndex : Byte) : ECBPtr;
{returns a pointer to the ECB in PoolRec at PoolIndex}

function SPXPoolCancelAll(PoolRec : WinSPXPoolRec) : Boolean;
{Cancel the entire Pool's events.  Does this by closing and reopening the
 socket associated with the pool.  Returns false if the socket cannot be
 reopened.}

function SPXPoolDataPtr(PoolRec : WinSPXPoolRec; PoolIndex : Byte) : Pointer;
{returns the data pointer for the PoolIndex element of PoolRec}

procedure SPXReplenishPool(SPXEvent : WinSPXRec; PoolIndex : Byte);
{Submit specified element of the SPX Listen pool back to SPX for listening}

procedure SPXReplenishAll(SPXEvent : WinSPXRec);
{Submit each unused ECB to the SPX for a listen event}

function SPXListenCount(SPXEvent : WinSPXRec) : Byte;
{Return the number of ECBs currently listening in the pool}

procedure SPXPoolStartListening(var PoolRec : WinSPXPoolRec);
{Submit all the ECBs in the pool to SPX to Listen for a Sequenced Packet}

procedure SPXAbortConn(SPXEvent : WinSPXRec);

procedure SPXTerminateConn(SPXEvent : WinSPXRec);
{Cancels all pending events, terminates the connection, and frees heap space
 used by SPXRec's SPXPoolRec. Returns FALSE if unable to free heap space.}

procedure SPXSend(SPXEvent : WinSPXRec;
                  WaitForCompletion : Boolean;
                  DataType : Byte;
                  DataPacketSize : Word;
                  DataPacket : Pointer);

function SPXListenPooled(SPXEvent : WinSPXRec;
                         var CompleteCode : Byte;
                         var PoolIndex : Byte;
                         var DataType : Byte;
                         var DataPtr : Pointer) : Boolean;

function AllocateWindowsESR(EventServiceRoutine : UserESRType;
                            DataSegment : Word;
                            var WindowsESR : WinESRType) : Boolean;
  {-Requests a real mode callback and initializes the data structures needed
    to support ESRs in WinApps.}

procedure FreeWindowsESR(var WindowsESR : WinESRType);
  {-Free a real mode callback previously allocated with a call to
    AllocateWindowsESR.}

function GetSPXWatchdog : Boolean;

procedure SetSPXWatchdog(On : Boolean);

function GetSPXRetryCount : Byte;

procedure SetSPXRetryCount(Retries : Byte);

function PoolAllocate(NumberOfECBs : Byte;
                       DataBufSize  : Word;
                       var PoolRec  : WinSPXPoolRec;
                       var Event    : WinSPXRec;
                       var WinESR : WinESRType) : Boolean;
{-Allocates a pool of Listen ECBs with the number of ECBs specified by
  NumberOfECBs. You must specify the maximum size of the data packet that will
  be received by these ECBs. The real mode memory usage of the Pool can be
  calculated by the equation:

  SizeOf(SPXPoolRec) +
  (NumberOfECBs * (Sizeof(PoolECB) + SizeOf(WinPoolECB) + DataBufSize) +
  NumberOfECBs

  This size must be less than 65535. This function will return FALSE if
  insufficient real mode memory (or size \> 65535).
}

function PoolDeallocate(var PoolRec : WinSPXPoolRec) : Boolean;
{Frees the heap space used by the SPXPoolRec.  Returns TRUE if memory freed.
 Before freeing the heap space, each ECB's InUse flag is checked, if any ECBs
 in the pool are still in use, this function returns FALSE.}

{$ELSE}
{***************************************************************
  Low Level IPX Services (Internetwork Packet Exchange Protocol)
***************************************************************}

{ All low level IPX calls EXCEPT IPXCloseSocket are re-entrant}

{ IPX support up to 50 open sockets per workstation}

function IPXServicesAvail : Boolean;
{ This function returns true if IPX services are available}

procedure IPXSendPrim(var ECB);
{ This procedure prepares an ECB and the IPX header of its associated packet
  and passes the ECB to the network drivers to initiate a send operation.
  This function returns immediately to the calling application.  In other
  words, the send event can not be assumed completed when this function
  returns. When the send event has been completed by the driver, the InUse
  flag of the ECB is reset to 0 (it is $FF while the send event is pending).
  If the ESRAddress pointer within the IPXECB is not NIL, then the Event
  Service Routine (the code pointed to by the ESRAddress field) will be
  called upon completion of the send request (see documentation regarding the
  limitations of ESRs).

  Before calling IPXSendPrim, the follwoing fields within the ECB must be
  initialized: ESRAddress, SocketNumber, ImmediateAddress, FragmentCount,
  and FD1 (and possible FD? if FragmentCount is greater than 1).  The buffer
  specified by FD1 must be at least 30 bytes long and must contain the
  IPX header first. In the IPX header, the following fields must be
  initialized: PacketType, and Destination (Network, Node, and Socket).

  Once the InUse field of the ECB is 0, the CompletionCode field contains
  the result code of the send event. Valid CompletionCode values are:

    $00  = The send completed successfully
    $FC  = The send request was cancelled by an IPXCloseSocket or or an
           IPXCancelEvent function call (IPXEventCancelled).
    $FD  = Malformed Packet - either the packet was less than 30 bytes,
           the first fragment was too small for the header, or the
           fragment count was zero (IPXMalformedPacket).
    $FE  = Packet is undeliverable (IPXPacketUndeliverable).
    $FF  = Physically unable to deliver packet, possibly due to hardware
           or network failure (IPXPhysicalError).
}

procedure IPXListenPrim(var ECB);
{ This procedure delivers the specified ECB to the IPX driver for the purpose
  of receiving an IPX packet.  It returns immediately to the calling
  application.  This procedure only delivers the ECB to the driver, it does
  not wait for delivery of the packet.  While the driver is awaiting receipt
  of a packet after a call to IPXListenPrim, the InUse field of the passed ECB
  is set to $FE. This field remains set until a receive event occurs, the
  request is cancelled, or IPX deems the ECB to be unusable.

  Before calling IPXListenPrim, the ESRAddress, SocketNumber, FragmentCount,
  and FD1 fields of the IPXECB must be initialized.  If FragmentCount is
  greater than one, then each additional FD? field must be initialized.

  After the InUse flag is reset to zero, the CompletionCode field of the ECB
  contains one of the following values:

    $00  = The Packet was received successfully
    $FC  = The receive request was cancelled by an IPXCloseSocket or or an
           IPXCancelEvent function call (IPXEventCancelled).

    $FD  = Packet Overflow.  A packet was received, but the ECB's fragment
           count was zero, or the space defined by the ECB's fragment
           descriptor list was not large enough to contain the entire
           packet (IPXPacketOverflow)
    $FF  = Socket specified to listen on in ECB was not open
           (IPXSocketNotOpen)

  The received packet is placed into memory based on the ECB's fragment
  descriptor list.  See the documentation regarding Fragment Descriptor Lists.
}

procedure IPXCloseSocketPrim(SocketNum : Word);
{ This function closes the socket specified by SocketNum.  See IPXCloseSocket
  for more information.}

function IPXOpenSocketPrim(RequestedSocket : Word;
                           Forever : Boolean) : Byte;
{ Opens a sockets.  See IPXOpenSocket.}

function IPXCancelEventPrim(var ECB) : Byte;
{ This function cancels the event specified by the ECB.  This function cancels
  any kind of event (Send, Listen, Schedule or Reschedule, or special purpose
  event).  If the ECB was in use by IPX, the InUse field of the ECB is set to
  zero, and the CompletionCode field is set to $FC. The ECB is then available
  for reuse by the application.

  There is one case where a valid ECB can not be cancelled.  This is when the
  driver is in the process of transfering data to or from the fragment
  descriptor list descibed by the ECB.  In this case, a function
  CompletionCode of $F9 is returned.

  When an event is cancelled, its associated ESR is not called.  This function
  returns the CompletionCode as its function result.  Valid values are:

    $00  = Event was successfully cancelled
    $FF  = the ECB was not in use by IPX or AES
    $F9  = ECB was in use but unable to cancel

}

procedure IPXRelinquish;
{ This procedure serves one of two purposes, depending whether it is invoked
  from a file server/bridge, or a workstation.  On a file server or network
  bridge, this function releases the machine to the server or bridge process.
  In other words, the application that calls it is temporarily suspended so
  the server or bridge process may have the machine immediately.  This
  procedure must be invoked at least once during each iteration of an idle
  loop to ensure the server or bridge is performing at maximum efficiency.
  When this procedure is called from a workstation, it invokes a polling
  procedure that allows the receiption and sending of internetwork packets.
  For those drivers without hardware interrupts, frequent calls to this
  procedure are crucial to the operation of applications that rely on packet
  exchange.
}

procedure IPXInternetAddress(var Address : IPXAddress);
{ This procedure returns the internetwork address of the node (station)
  on which it is executing.  The first two fields of the IPXAddress are
  filled in.  The third field of an IPXAddress type, the Socket, is not
  returned.
}

procedure IPXScheduleEvent(DelayTime : Word; var ECB : IPXECB);
{ This procedure schedules an IPX event to occur after the specified time
  interval expires. The time interval is specified in clock ticks.

  See the Novell API Reference Volume 2 for info on AES and event service
  routines.
}

procedure IPXScheduleSpecialEvent(DelayTime : Word;
                                  var ECB : AESECB);
{ This procedure schedules a special purpose, application defined event to
  occur after a specified time interval expires.  Since the interval range
  is specified as a word, it may be between 0 and 65,535 clock ticks
  (about 60 minutes).

  See the Novell API Reference Volume 2 for info on AES and event service
  routines.
}

function IPXGetIntervalMarker : Word;
{ This function returns a timing marker.  This marker is the current time
  in clock ticks.  It has no relation to the real-world time.  It is useful
  for comparing with another timing marker, and the difference is elapsed
  clock ticks.
}

function IPXGetLocalTarget(var LocalTarget : TargetType;
                           var TransportTime : Word) : Byte;
{returns the immediate address of an IPXAddress.  If the IPXAddress resides
 on a different network, then the immediate address returned will be that of a
 router station (bridge). The estimated time one-way transport time is also
 returned}

{***************************************************************
  High Level IPX Services (Internetwork Packet Exchange Protocol)
***************************************************************}

function IPXOpenSocket(RequestedSocket : Word; Forever : Boolean) : Byte;
{ Opens a sockets.  Returns the Function Completed Code (explained below).
  The first parameter Forever indicates whether the socket should remain open
  after the program terminates.  If Forever is TRUE, then the socket remains
  open until it is explicitly closed.  If FALSE, the socket is closed
  automatically when the program that opened it terminates.  The Forever flag
  is useful when opening a socket within a TSR.  The second parameter
  RequestedSocket indicates the socket number to open.

  Possible function result (Function Completed Code) values are:
    $00  = Socket successfully open
    $FF  = Socket is Already Open (IPXSocketAlreadyOpen)
    $FE  = Socket Table is already full (IPXSocketTableFull)

}

procedure IPXCloseSocket(SocketNum : Word);
{ This function closes the socket specified by SocketNum.  This automatically
  cancels all associated IPXECBs whether they are in use by IPX or the AES for
  sending, listening, or scheduling.  After closing a socket, all incoming
  packets for that socket are ignored.  Attempting to close a socket that is
  not open has no effect.

  Important: Transient applications (non TSRs) MUST close all their sockets
  before terminating. Failure to close a socket before terminating could
  result in hanging the station.  This comes from the possibility that
  an event service routine within the no longer resident application may be
  called (meaning a call is made to an address where the program no longer
  resides). Even though sockets may be open with a FALSE value for the Forever
  parameter indicating that the socket should be closed automatically upon
  termination of the program, the application should still explicitly close
  all open sockets whenever possible (see Novell API Reference Volume 2).

  IPXCloseSocket may never be called from within an Event Service Routine.
  This is due to the fact that it is not re-entrant.
}

function IPXAssignUniqueSocket(var ReturnedSocket : Word;
                               Forever : Boolean) : Word;
{This routine is used to allow IPX to assign a socket number not currently in
 use. This is considered a high level IPX routine because the socket number is
 returned in native PC format (low byte, high byte) rather than native
 NetWare format (high byte, low byte). All IPX and SPX high level routines
 take and return sockets in PC format, and all low level routines take and
 return sockets in NetWare format.}

function IPXEventComplete(var IPXEvent : IPXRec;
                          var FinalResult : Byte) : Boolean;
{Returns TRUE if the event specified by IPXEvent has completed.  If the event
 is complete, the final completion code is returned in FinalResult.}

function IPXCancelEvent(var IPXEvent : IPXRec) : Byte;

function IPXSend(var IPXEvent : IPXRec;
                 Receiver : IPXAddress;
                 Socket : Word;
                 WaitForCompletion : Boolean;
                 DataPacketSize : Word;
                 var DataPacket) : Byte;

{Opens the desired socket (if not open already) and prepares the ECB for
 an IPXSend operation.

 It is important to remember that an IPX send event can not be assumed
 complete when this function returns. The IPXECB, IPXHeader, and user data
 passed to this function must remain static until this function completes. In
 other words, they must either be global variables, or be declared on the heap
 and not Freed until the operation completes. They should not be local
 variables, unless you can guarantee that the send operation will be completed
 or cancelled before the routine that they are local to completes.
}

function IPXListen(var IPXEvent : IPXRec;
                   Socket : Word;
                   WaitForCompletion : Boolean;
                   MaxPacketSize : Word;
                   var DataPacket) : Byte;

{Opens the desired socket (if not open already) and prepares the ECB for
 an IPXListen operation, and calls IPXListen

 It is important to remember that an IPX Listen event can not be assumed
 complete when this function returns. The IPXECB, IPXHeader, and user data
 passed to this function must remain static until this function completes. In
 other words, they must either be global variables, or be declared on the heap
 and not Freed until the operation completes. They should not be local
 variables, unless you can guarantee that the Listen operation will be
 completed or cancelled before the routine that they are local to completes.
}

{***************************************************************
  low level SPX Services (Sequenced Packet Exchange Protocol)
***************************************************************}

function SPXServicesAvail(var Version : Word; var MaxSPXConn : Word;
                          var AvailSPXConn : Word) : Boolean;
{ This function Check to see if SPX services are available.  It returns
  TRUE is they are, and FALSE if they are not. If IPX services are available,
  The version number of the SPX driver is returned in the first VAR
  parameter (version major in high byte, minor in low), and the maximum number
  of SPX connections supported and the number of available SPX connections are
  returned in the next two. }

function SPXEstablishConnPrim(RetryCount : Byte; WatchDog : Boolean;
                              var ECB : IPXECB;
                              var AssignedConn : Word) : Byte;
{Attemps to establish an SPX connection with a partner client}

procedure SPXListenForConnPrim(Retry : Byte; WatchDog : Boolean;
                               var ECB : IPXECB);
{Attemps to establish an SPX connection with a partner client}

procedure SPXTerminateConnPrim(ConnID : Word;
                               var ECB : IPXECB);
{Terminates an existing connection (informs partner of intention to do so)}

procedure SPXAbortConnPrim(ConnID : Word);
{ Terminates an existing connection (does not inform partner of intention to
  do so).
}

function SPXConnStatus(ConnID : Word;
                       var SPXStatusBuf : SPXStatusBlock) : Boolean;
{Returns the status of an SPX connection}

procedure SPXSendPrim(ConnID : Word; var ECB : IPXECB);
{The low level SPX send procedure used to request the sending of a sequenced
 packet.
}

procedure SPXListenPrim(var ECB : IPXECB);
{The low level SPX listen procedure used to inform NetWare that you are
 expecting the delivery of a sequenced packet.
}

{***************************************************************
  High level SPX Services (Sequenced Packet Exchange Protocol)
***************************************************************}

function SPXEventComplete(var SPXEvent : SPXRec;
                          var FinalResult : Byte;
                          var DataType : Byte) : Boolean;

function SPXEstablishConn(var SPXEvent : SPXRec;
                          Receiver : IPXAddress;
                          Socket : Word;
                          WaitForCompletion : Boolean;
                          MaxListenDataSize : Word;
                          NumListenPoolECBs : Byte;
                          PoolESRInPascal : Pointer) : Byte;
{The high level SPX function to establish a connection with a partner SPX
 client. This routine isolates the programmer from the details of building the
 SPX header and the Event Control Block. It is designed for use with the
 SPXListenForConn function.

 MaxDataSize is the maximum size for the data buffer for each ECB in the
 Listen ECB Pool. NumPoolECBs is the number of Listen ECBs to allocate for the
 Pool (MUST be at least one). PoolESRInPascal points to a Pascal ESR (see
 PoolAllocate and PascalPoolESR for more info on ESRs in Pascal). If no user
 ESR is required, pass NIL for this parameter. }

function SPXListenForConn(var SPXEvent : SPXRec;
                          Socket : Word;
                          WaitForCompletion : Boolean;
                          MaxDataSize : Word;
                          NumPoolECBs : Byte;
                          PoolESRInPascal : Pointer) : Byte;

{The high level SPX function to establish a connection with a partner SPX
 client. This routine isolates the programmer from the details of building the
 SPX header and the Event Control Block. It is designed for use with the
 SPXEstablishConn function.

 MaxDataSize is the maximum size for the data buffer for each ECB in the
 Listen ECB Pool. NumPoolECBs is the number of Listen ECBs to allocate for the
 Pool (MUST be at least one). PoolESRInPascal points to a Pascal ESR (see
 PoolAllocate and PascalPoolESR for more info on ESRs in Pascal). If no user
 ESR is required, pass NIL for this parameter. }

procedure SPXSend(var SPXEvent : SPXRec;
                  WaitForCompletion : Boolean;
                  DataType : Byte;
                  DataPacketSize : Word;
                  var DataPacket);

{ The high level SPX function to send a sequenced packet to a connection
  partner. This routine isolates the programmer from the details of building
  the SPX header and the Event Control Block. It is designed for use with the
  SPXListenPooled procedure.
}

procedure SPXTerminateConn(var SPXEvent : SPXRec);
{Cancels all pending events, terminates the connection, and frees heap space
 used by SPXRec's SPXPoolRec.}

procedure SPXAbortConn(var SPXEvent : SPXRec);
{ Abort active connection. This routine does not inform partner of intention
  to do so, nor is the heap space used reclaimed.}

{***************************************************************
  High level SPX Listen ECB Pool Routines
***************************************************************}

function SPXPoolCancelAll(var PoolRec : SPXPoolRec) : Boolean;
{Cancel the entire Pool's events.  Does this by closing and reopening the
 socket associated with the pool.  Returns false if the socket cannot be
 reopened.}

function SPXListenPooled(var SPXEvent : SPXRec;
                         var CompleteCode : Byte;
                         var PoolIndex : Byte;
                         var DataType : Byte;
                         var DataPtr : Pointer) : Boolean;

function SPXPoolECBPtr(var PoolRec : SPXPoolRec; PoolIndex : Byte) : ECBPtr;
{returns a pointer to the ECB in PoolRec at PoolIndex}

function SPXPoolDataPtr(var PoolRec : SPXPoolRec; PoolIndex : Byte) : Pointer;
{returns the data pointer for the PoolIndex element of PoolRec}

procedure SPXPoolStartListening(var PoolRec : SPXPoolRec);
{Submit all the ECBs in the pool to SPX to Listen for a Sequenced Packet}

procedure SPXReplenishPool(var SPXEvent : SPXRec; PoolIndex : Byte);
{Submit specified element of the SPX Listen pool back to SPX for listening}

procedure SPXReplenishAll(var SPXEvent : SPXRec);
{Submit each unused ECB to the SPX for a listen event}

function SPXListenCount(var SPXEvent : SPXRec) : Byte;
{Return the number of ECBs currently listening in the pool}

{$ENDIF}
{***************************************************************
  General purpose
***************************************************************}
function AsciiZ2Str(var Buffer; Max : Byte) : String;
{converts an Asciiz string (of any type) to a TP string}

function NetWareSwapLong(L : LongInt) : LongInt;
Inline(
  $5A/                   {  pop    dx}
  $86/$D6/               {  xchg   dh,dl}
  $58/                   {  pop    ax}
  $86/$C4);              {  xchg   ah,al}

implementation

type
  DoubleWord       = record
                       LoWord  : Word;
                       HiWord  : Word;
                     end;

  OS =
    record
      O, S : Word;
    end;

function MakeLong(HiWord,LoWord : Word) : LongInt;
{takes hi and lo words and makes a longint }
Inline(
  $58/    { pop ax ; pop low word into AX }
  $5A);   { pop dx ; pop high word into DX }

function AsciiZ2Str(var Buffer; Max : Byte) : String;

const
  AsciiZMAX        = 255;

type
  AsciiZBuffer     = Array[1..AsciiZMAX] of Char;

var
  A                : AsciiZBuffer absolute Buffer;
  I                : Word;
  S                : String;

begin
  I := 1;
  { search for terminating #0, stop if max string length exceeded}
  while (A[I] <> #0) and (I < Max) do begin
    S[I] := A[I];
    Inc(I);
  end;
  S[0] := Char(I-1);
  AsciiZ2Str := S  {return the string}
end;

function UpperCase(S : String) : String;

var
  I                : Word;

begin
  for I := 1 to Length(S) do
    S[I] := UpCase(S[I]);
  UpperCase := S;
end;

function FileIsShareable(Path : PathName; var FAttr : Word; var ErrCode : Word)
                       : Boolean;
{ Return TRUE if file is flagged as shareable, return file attrib in FAttr }

var
  F                : File;
begin
  Assign(F,Path);
  GetFAttr(F,FAttr);  {get the file attribute}
  ErrCode := DOSError;   {get the error code for caller}
  FileIsShareable := (FAttr and NWShareable) <> 0;  { see if SHARE }
end;

function MakeFileShareable(Path : PathName) : Byte;

var
  F                : File;
  Attr             : Word;
  ErrCode          : Word;
  Share            : Boolean;

begin
  Share := FileIsShareable(Path,Attr,ErrCode);  { is it sharable? }
  if (ErrCode = 0) and (not Share) then begin
    {flag file to shareable by ORing $80 with existing file attr}
    Assign(F,Path);
    SetFAttr(F,Attr or NWShareable); { OR existing at with SHARE bit }
    ErrCode := DOSError;
  end;
  MakeFileShareable := Byte(ErrCode);
end;

{$IFDEF DPMIOrWnd}
  {$I NETWAREW.INC}
{$ELSE}
  {$I NETWARE.INC}
  {$I IPXSPX.INC}
{$ENDIF}

  function NetWareShellInstalled : Boolean;

  var
    Logged : Boolean;

  begin
    NetWareShellInstalled := NetWareLoaded(Logged);
  end;

function IsNetWare3 : Boolean; {!!.21}
  {-Return True if NetWare 386 (version 3.0 or greater) installed}
var
  OsType, OsVer, Hardware : String;
  Major, Minor, Revision : Byte;
  IsHere : Boolean;
begin
  {Make sure a netware shell is installed, and check for Ipx services}
  IsHere := NetWareShellInstalled (****and IpxInstalled*);
  if IsHere then begin
    IsHere := DefaultServerInfo.NetWareVer > 2;                  {!!.22}
  end;
  IsNetWare3 := IsHere;
end;

begin
{$IFNDEF DPMIOrWnd}
  IPXServicesAvailable := IPXInstalled;  {sets global vars IPXLocation and}
                                         {IPXServicesAvailable}
  PascalESR := @PascalPoolESR;           {set up the ESR stub for SPX}
{$ENDIF}
  if NetWareShellInstalled then          {If NetWare loaded, return info}
    GetServerInfo(DefaultServerInfo)     {from default file server}
  else
    FillChar(DefaultServerInfo,SizeOf(ServerInformation),0); {No NetWare shell}
end.

