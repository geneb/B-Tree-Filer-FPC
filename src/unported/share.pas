{*********************************************************}
{*                    SHARE.PAS 5.41                     *}
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

unit Share;
{ This unit contains routines related to networking using DOS 3
  function calls. }

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
  PrinterDevice    = 3;         {indicates a printer to relevent DOS calls}
  DriveDevice      = 4;         {indicates a drive to relevent DOS calls}

  FileNotOpen      = $FFFE;     {File is not open}
  ShareNotLoaded   = $FFFF;     {SHARE.COM or equivelent not loaded}
  WrongDosVersion  = $FFFD;     {DOS version prior to 3.x}
  PrinterSetupMax  = 64;        {the max length of printer setup string}
  NBNameMax        = 16;        {max length of NetBIOS name string}

type
  DeviceType       = (DevPrinter,DevDrive);    {enum type for devices}
  PrinterSetupStr  = String[PrinterSetupMax];  {str type for printer setup}
  PCLanOpType      = (LanUnknown,LanRedirector,LanReceiver,
                      LanMessenger,LanServer); {enum type for PC Lan}
                                                 {operating types}
  NetworkStr       = String[128];                {str type for network names}
  DoubleWord       = record
                       LoWord  : Word;  {low word of a LongInt}
                       HiWord  : Word;  {high word of a LongInt}
                     end;
  NBNameStr        = String[NBNameMax];   {type for NetBIOS names}

  {$IFDEF DPMIOrWnd}
  PathStr     = String[79];
  Registers   = TRegisters;
  {$ENDIF}

  {$IFDEF Ver40}
  PathStr     = String[79];
  {$ENDIF}

var
  DosMajor,DosMinor              {stores the DOS version for reference}
                   : Byte;       {by the networking DOS calls}


function DosLockRec(var F; FilePosition,FileLength : LongInt) : Word;
{ This function uses DOS call 5Ch to lock all or part of a file.  }
{ The DOS error code is returned as the result.  The file takes a }
{ file, followed by two LongInts, representing the file position  }
{ (or offset), and the size in bytes to lock starting at said     }
{ offset. Make sure you Unlock any locks before closing the file. }
{ An error code of 1 means invalid DOS version. It may also mean  }
{ that SHARE hasn't been run. See DOS Technical Reference or      }
{ Duncan's Advanced MS-DOS) for info on error codes.              }

function UnlockDosRec(var F; FilePosition,FileLength : LongInt) : Word;
{ Similar to LockFile, except uses DOS call 5Ch sunfunction 1  }
{ You must ensure that the offset and FileLength are identical }
{ to the ones used to lock the file                            }

function UpdateFile(var F) : Word;
{ Flushes an open file to disk. Forces a duplicate of file handle, then
  closes it.  Error codes are: 0 for success, 4 if no handles are
  available, or 6 if handle invalid or file not open.
}

function SetPrinterSetup(SetUpStr : PrinterSetUpStr;
                         RedirectionIndex : Word) : Boolean;
{ Sets the printer setup string for the print device at entry RedirectionIndex
  in the NetBIOS Name Table.
}

function GetPrinterSetup(var SetUpStr : PrinterSetUpStr;
                         RedirectionIndex : Word) : Boolean;
{ Returns the printer setup string for the print device at entry
  RedirectionIndex in the NetBIOS Name Table.
}

function GetMachineName(var S : NBNameStr; var MachNum : Byte) : Boolean;
{ Returns the machine name and the netbios machine name number associated
  with the calling station.
}

function IBMPCLanLoaded(var Lan : PCLanOpType) : Boolean;
{ Returns true if IBM's PC-LAN program is loaded.  If PC-Lan is loaded, then
  the parameter Lan contains a value of PCLanOpType.  This type indicates
  the mode which the station is operating.

  NOTE: Novell's Advanced NetWare will pass this test if INT24.COM is loaded.
}

function PCLanInfo(var Lan : PCLanOpType; var MachineName : NBNameStr;
                   var MachineNo : Byte) : Boolean;
{ Returns TRUE if PC Lan program is loaded, and returns the operation type,
  Machine's NetBIOS name, and the NetBIOS name table number.

  NOTE: Novell's Advanced NetWare will pass this test if INT24.COM is loaded.
}

function RedirectDevice(TypeOfDev : DeviceType; LocalName : NBNameStr;
                        NetWorkName,Password : NetworkStr;
                        Parameter : Word) : Word;
{ Establish a redirection across the network. TypeOfDev specifies whether the
  device to be redirected is a printer or a drive, LocalName is the name of
  the local device to be redirected, NetworkName is the network resource to
  redirect LocalName to, Password is an optional password string used to grant
  access to the network resource, and parameter is a word sized user defined
  parameter to be returned by subsequent calls to GetRedirectionEntry.
  Possible function results:

0  success
1  function code invalid (source or destination string
   in wrong format or source device already redirected)
3  path not found
5  access denied
8  insufficient memory
}

function CancelRedirection(LocalName : NBNameStr) : Word;
{ Cancels a redirection. LocalName is the name of the local device that was
  previously redirected.
}

function GetRedirectionEntry(RDLIndex : Word; var LocalName : NBNameStr;
                            var NetName : NetworkStr;
                            var Parameter : Word;
                            var Valid : Boolean;
                            var Dev   : DeviceType) : Word;
{ Return redirection entry information from the redirector.}

function GetRedirectionEntryNetWare(RDLIndex : Word;                 {!!.53}
                                    var LocalName : NBNameStr;
                                    var NetName : NetworkStr;
                                    var Parameter : Word;
                                    var Valid : Boolean;
                                    var Dev   : DeviceType) : Word;
{ Return redirection entry information from the redirector with special
  NetWare information.}

function GetTempFileName(PathN : PathStr;
                         var TempFileName : PathStr) : Word;

function ShareInstalled : Boolean;
{ Returns TRUE if SHARE installed}

function GetExtendedError(var Class,Action,Locus : Byte) : Word;
{ Returns DOS Extended error information}

function IsDriveLocal(Drive : Byte) : Boolean;
{ Returns true if a drive is local, and false if it is on a remote machine}

function IsFileLocal(var F) : Boolean;
{ Returns true if a file is local, and false if it is on a remote machine}

implementation

const
  GETMACHNAME     = $5E00;
  SETPRINTSETUP   = $5E02;
  GETPRINTSETUP   = $5E03;
  REDIRECTORFLAG  = $0008;
  RECEIVERFLAG    = $0080;
  MESSENGERFLAG   = $0004;
  SERVERFLAG      = $0040;

  PCLANCHECK      = $B800;

function MakeLong(HiWord,LoWord : Word) : LongInt;
{takes hi and lo words and makes a longint }
Inline(
  $58/    { pop ax ; pop low word into AX }
  $5A);   { pop dx ; pop high word into DX }

{$IFDEF DPMIOrWnd}
  {$I SHAREW.INC}
{$ELSE}
  {$I SHARE.INC}
{$ENDIF}

begin
  DosMajor := DosVer(DosMinor);
end.

