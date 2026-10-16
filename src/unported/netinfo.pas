{*********************************************************}
{*                   NETINFO.PAS 5.41                    *}
{*        Copyright (c) TurboPower Software 1989.        *}
{*                 All rights reserved.                  *}
{*********************************************************}

{$R-,S-,I+,V-}

{
  This program attempts to determine the type of network you are
  running under, and provides information known about that system.

  If Novell NetWare is running, a comprehensive report is shown
  with file server information, workstation information, and
  network printer information.  Also, if Novell's NetBIOS emulator
  is running a message informing you of that is printed.

  No matter what network is running, a redirection report is run
  listing all of the currently redirected devices.  Also, any network
  print devices are listed with their printer setup strings.
}

{$I BTDEFINE.INC}

program NovellTest;

uses
  {$IFDEF Windows}
  WinDos,
  WinProcs,
  WinCrt,
  WinDPMI,
  {$ELSE}
    {$IFNDEF UseOPCRT}
      {$IFDEF UseTPCRT}
        TpCrt,
      {$ELSE}
        Crt,
      {$ENDIF}
    {$ELSE}
      OpCrt,
    {$ENDIF}
  Dos,
  {$ENDIF}
  NetWare,   {the routines for Novell's NetWare}
  NetBIOS,   {NetBIOS related routines}
  Share;     {DOS and redirector services}

type
  Str40            = String[40];

  {the following are the various network configurations recognized by this}
  {program}
  NetType          = (LanNovell,LanNovellWithNetBIOS,LanNetBIOS,
                      LanPCLan,LanOther);
  {$IFDEF Windows}
  Registers = TRegisters;
  {$ENDIF}
const
  Digits           : array[0..$F] of Char = '0123456789ABCDEF';
  DayNames         : Array[DayOfTheWeek] of Str9 = ('Sunday',
                                                    'Monday',
                                                    'Tuesday',
                                                    'Wednesday',
                                                    'Thursday',
                                                    'Friday',
                                                    'Saturday');
  MonthNames       : Array[1..12] of Str9 =
                     ('January','February','March',
                      'April','May','June',
                      'July','August','September',
                      'October','November','December');

  HiLite           = $0F;              {color attribute used for emphasis}
  CtrlAttr         = $70;

var
  PCLanOperation   : PCLanOpType;         {for PC Lan if present, indicates }
                                          {mode in which PC LAN is opertaing}
  NovServers       : FileServerNameTable; {for Novell if present, holds a   }
                                          {list of available file servers.  }
function HexB(B : Byte) : string;
{-Return hex string for byte}
begin
  HexB[0] := #2;
  HexB[1] := Digits[B shr 4];
  HexB[2] := Digits[B and $F];
end;

function HexW(W : Word) : string;
  {-Return hex string for word}
begin
  HexW[0] := #4;
  HexW[1] := Digits[hi(W) shr 4];
  HexW[2] := Digits[hi(W) and $F];
  HexW[3] := Digits[lo(W) shr 4];
  HexW[4] := Digits[lo(W) and $F];
end;

function HexPtr(P : Pointer) : string;
  {-Return hex string for pointer}
begin
  HexPtr := HexW(Seg(P^))+':'+HexW(Ofs(P^));
end;


procedure PressAnyKey(S : String);
{Display a prompt, waits for a keypress, and clears the prompt}

var
  SavAtt           : Word;

begin
  {$IFDEF Windows}
  Write('Press any key ',S);
  if ReadKey = #0 then ;
  WriteLn;
  {$ELSE}
  SavAtt := TextAttr;
  TextAttr := $0F;
  Write('Press any key ',S);
  if ReadKey = #0 then ;
  GotoXY(1,WhereY);
  ClrEOL;
  TextAttr := SavAtt;
  {$ENDIF}
end;

function Pad(S : String; Num : Byte) : String;
{Pads a string with spaces so it is Num Length}

var
  L,I              : Byte;

begin
  L := Length(S);
  if L < Num then             {make sure Num > the length of the string}
    for I := L+1 to Num do
      S[I] := ' ';
  S[0] := Char(Num);          {set the length byte}
  Pad := S;
end;

function WordToStr(W : Word) : Str40;
{converts a word to a string}

var
  S                : Str40;

begin
  Str(W,S);
  WordToStr := S
end;

function ZeroFillNum(W : Word) : Str9;
{left zero fills a number to two digits (for use in date/time display)}

begin
  if W < 10 then
    ZeroFillNum := '0' + WordtoStr(W)
  else
    ZeroFillNum := WordToStr(W)
end;

function OptionSpecified(Option : Char) : Boolean;
{returns TRUE if the character specifed by Option was specified on the command
 line (preceeded by a / or a -).}

var
  I                : Word;
  S                : String;

begin
  OptionSpecified := TRUE;
  Option := UpCase(Option);
  for I := 1 to ParamCount do begin
    S := ParamStr(I);
    if Length(S) > 1 then
      if S[1] in ['/','-'] then
        if Option = UpCase(S[2]) then
          Exit
  end;
  OptionSpecified := FALSE;
end;

function GetCurrentDrive : Char;
{get the currently logged drive via DOS function 19h}

var
  Regs             : Registers;

begin
  with Regs do begin
    AH := $19;
    MsDos(Regs);
    GetCurrentDrive := Char(Ord('A') + AL); {convert to drive letter}
  end;
end;

function GetCurrentDir : PathName;
{return the current directory via DOS function 47h}

var
  Regs             : Registers;
  S                : PathName;

begin
  with Regs do begin
    AH := $47;
    DL := 0;
    DS := Seg(S);
    SI := Ofs(S[1]);
    MsDos(Regs);
  end;
  S[0] := Char(SizeOf(PathName)  - 1);
  S[0] := Char(Pos(#0,S) - 1);          {convert from AsciiZ to Pascal string}
  GetCurrentDir := S;
end;

function GetPathName : PathName;
{returns the current drive an path name}

begin
  GetPathName := GetCurrentDrive + ':\' + GetCurrentDir;
end;

function FormatTime(Hour,Minute,Second : Word) : Str80;
{formats a time into HH:MM:SS format}

begin
  FormatTime :=  ZeroFillNum(Hour) + ':' + ZeroFillNum(Minute) + ':' +
                ZeroFillNum(Second);
end;

procedure ConvertCtrlChars(S : String; CtrlAtt : Byte);
{ a quick and dirty routine to convert control characters to the ^x format. In
  other words, if a string consisting of #3'hello'#1 were passed as S, this
  function would return ^Chello^A.
}

var
  I                : Word;
  C                : Char;
  OrigAtt          : Byte;

begin
  {$IFDEF Windows}
  Write(C);
  {$ELSE}
  OrigAtt := TextAttr;
  for I := 1 to Length(S) do begin
    C := S[I];
    {if this char is greater than #0 and less than #32, then xlat it}
    if (Ord(C) < 32) and (Ord(C) > 0) then begin
      TextAttr := CtrlAtt;
      Write('^',Char(Ord('A') - 1 + Ord(C)));
      TextAttr := OrigAtt;
    end
    else
      Write(C);
  end;
  {$ENDIF}
end;

function FormatDateTime(Year,Month,Day,Hour,Minute,Second : Word;
                    WeekDay : DayOfTheWeek) : Str80;
{formats a data and time for display}

begin
  FormatDateTime := DayNames[WeekDay] + ' ' + MonthNames[Month] + ' ' +
                    WordToStr(Day) + ', ' + WordToStr(Year) + '  ' +
                    FormatTime(Hour,Minute,Second);
end;

function NetBIOSMachineName : String;
{return the NetBIOS machine name for this station}

var
  Name             : NBNameStr;
  NameNum          : Byte;

begin
  if not GetMachineName(Name,NameNum) then
    Name := '';
  NetBIOSMachineName := Name;
end;

procedure PrinterSetupStr;
{show the printer setup string for each network print device}

var
  Parm,I           : Word;
  Name,NetName,SetUp
                   : String;
  Dev              : DeviceType;
  Valid            : Boolean;
  Sav              : Byte;

begin
  I := 0;
  {for each redirected printer device, show the printer setup string}
  WriteLn('Looking in redirection list for Network printers...');
  while (GetRedirectionEntry(I,Name,NetName,Parm,Valid,Dev)=0) do begin
    {see if this is a valid Printer device, and if so, show its setup string}
    if Valid and (Dev = DevPrinter) then
      if GetPrinterSetup(SetUp,I) then begin
        Write('Setup string for ',Name,' = ');
        {$IFNDEF Windows}
        Sav := TextAttr;
        TextAttr := HiLite;
        {$ENDIF}

        if SetUp = '' then
          WriteLn('<none>')
        else begin
          ConvertCtrlChars(SetUp,CtrlAttr);
          WriteLn;
        end;
        {$IFNDEF Windows}
        TextAttr := Sav;
        {$ENDIF}
      end;
    Inc(I);
  end;
  WriteLn(' ');
end;

procedure NovellSystem(NetBIOSEmulator : Boolean);
{This is a Novell NetWare system.  Show assorted NetWare related info}

procedure ServerInfo;
{Information relating to the file server and server services}

const
  SFTLevelStr      : Array[1..3] of String[3] = ('I','II','III');

var
  Y                : Word;
  M,D,H,Min,S      : Byte;
  WeekDay          : DayOfTheWeek;
  DateTime         : Str80;
  SerConnNum       : Byte;
  ServInf          : ServerInformation;
  Driver           : DriverInformation;

begin
  GetServerInfo(ServInf);
  with ServInf do begin
    Write('File server is running ');
    if NetWareVer > 1 then
      Write('Advanced ');
    Write('NetWare ');
    case MaxConns of
      4 : Write('ELS Level I ');
      8 : Write('ELS Level II ');
    end;
    WriteLn('version ',NetWareVer,'.',NetWareSub,' revision ',Revision);
    if SFTLevel > 0 then
      WriteLn('SFT Level ',SFTLevelStr[SFTLevel]);
    WriteLn('Using ',UsedConns,' of the ',MaxConns,' possible connections');
  end;

  if GetDriverConfiguration(0,Driver) then
    with Driver do begin
      WriteLn(^M^J'Driver configuration at the file server is:');
      WriteLn(LanBoardName);
      WriteLn(HardwareSettings);
      WriteLn('Installation option ',OptionNumber);
      WriteLn;
    end;

  {get the time and date maintained by the file server}
  GetServerDateTime(Y,M,D,H,Min,S,WeekDay);
  DateTime := FormatDateTime(Y,M,D,H,Min,S,WeekDay);
  WriteLn('The server says it is: ',DateTime);

  {Determine whether this version of NetWare supports TTS}
  Write('Transaction tracking is ');
  if not TTSAvailable then
    Write('not ');
  WriteLn('available.');

  {Get the server slot number}
  SerConnNum := ServerConnNo;

  {return the file server name table}
  ServerNameTable(NovServers);
  {Display the name of the prefered file server}
  WriteLn('Default File server name     : ',NovServers[SerConnNum]);
  WriteLn('Default File server number   : ',SerConnNum);
  WriteLn('Preferred file server number : ',PreferredServerConnNo);
  WriteLn('Primary file server number   : ',PrimaryServerConnNo);
  WriteLn;
  PressAnyKey('for workstation information');
end;

procedure WSInfo;
{Information related to the workstation this program is run from}

var
  Y,M,D,H,Min,S,S100,WD
                   : Word;
  Major,Minor,Rev  : Byte;
  S1,S2,S3         : String;
  DateTime         : Str80;

begin
  {$IFNDEF Windows}
  ClrScr;
  {$ENDIF}
  {get the local time and date from the workstation}
  GetDate(Y,M,D,WD);
  GetTime(H,Min,S,S100);
  WriteLn(^M^J'This workstation says it is: ',
          FormatDateTime(Y,M,D,H,Min,S,DayOfTheWeek(WD)));

  {Get the netware version info}

  with DefaultServerInfo do
    if (NetWareVer = 2) and (NetWareSub >= 10) then begin
      GetWSInfo(Major,Minor,Rev,S1,S2,S3);
      if Major > 1 then Write('Advanced ');
      WriteLn('NetWare Shell version ',Major,'.',ZeroFillNum(Minor)
              ,' revision ',Rev,' installed on this workstation.');
      WriteLn('NetWare installed for: ',S1,'   ',S2,'    ',S3);
    end;
  {check for console priviledges}
  Write('This workstation ');
  if ConsolePriv then
    Write('has ')
  else
    Write('does not have ');
  WriteLn('console privileges.');

  {is lock mode extended or compatibility?}
  Write('NetWare is operating in ');
  if IsLockModeExtended then
    WriteLn('extended lock mode.')
  else
    WriteLn('compatibility lock mode.');
  {report the current broadcast mode}
  WriteLn('Current broadcast mode is ',GetBroadcastMode);

  {return this node's connection number}
  WriteLn('Connection number of this workstation: ',GetConnNo);
end;

procedure PrinterInfo;
{information on the network printers}

var
  BannerUser       : Str20;
  PrinterNo,FormType,Que
                   : Byte;
  OffLine,Stopped,Spooled
                   : Boolean;
  PJs              : PrintJobType;

begin
  {Get the name of the default local printer}

  WriteLn('The default local printer is ',LPTNames[GetDefaultLocalPrinter]);

  {The user name printed on the banner page (if the version of NetWare in use}
  {supports that function}
  if GetBannerUser(BannerUser) then
    WriteLn('The banner user name is: ',BannerUser);

  {Return some info on the default network printer}
  GetPrintJobFlags(PJs);
  GetPrinterStatus(PJs.ServerPrinter,PrinterNo,FormType,OffLine,Stopped);
  if PrinterNo <> $FF then begin    {!!.22}
    Write('Current network printer number is ',PrinterNo);
    WriteLn('   Current form type is ',FormType);
    Write('Network printer is ');
    if OffLine then
      WriteLn('offline')
    else
      WriteLn('online');
    if Stopped then
      WriteLn('Network printer is stopped');
  end;                              {!!.22}

  {determine whether spooler is active, and if so, report the QueServer num}
  Spooled := LPTCaptureActive(Que);
  if Spooled then
    WriteLn('Spooling is enabled, the queue server is connection ',Que)
  else
    WriteLn('Spooling is not active');
  PrinterSetupStr;
end;


procedure PrintJobDump;

const
  M1 = 'Status           : ';
  M2 = 'Flags            : ';
  M3 = 'TabSize          : ';
  M4 = 'ServerPrinter    : ';
  M5 = 'NumCopies        : ';
  M6 = 'FormType         : ';
  M7 = 'Reserved         : ';
  M8 = 'Banner           : ';
  M9 = 'LocalLPT         : ';
  M10= 'FlushCaptureTO   : ';
  M11= 'FlushCaptureOnCl : ';

procedure WriteHex(S : String; Bite : Byte);

  function HexB(B : Byte) : string;
    {-Return hex string for byte}
  const
    Digits : array[0..$F] of Char = '0123456789ABCDEF';
  begin
    HexB[0] := #2;
    HexB[1] := Digits[B shr 4];
    HexB[2] := Digits[B and $F];
  end;

begin
  WriteLn(S,HexB(Bite));
end;

var
  PJ : PrintJobType;

begin
  GetPrintJobFlags(PJ);
  with PJ do begin
    WriteHex(M1,Status);
    WriteHex(M2,Flags);
    WriteLn(M3,TabSize);
    WriteLn(M4,ServerPrinter);
    WriteLn(M5,NumCopies);
    WriteLn(M6,FormType);
    WriteLn(M7,Reserved);
    WriteLn(M8,AsciiZ2Str(Banner,20));
    WriteLn(M9,LocalLPT);
    WriteLn(M10,FlushCaptureTimeout);
    WriteLn(M11,FlushCaptureOnClose);
  end;
end;

begin
  {tell them this is Novell}
  Write('This system is running Novell NetWare');
  {report whether the NetBIOS emulator is loaded}
  if NetBIOSEmulator then
    WriteLn(' with the NetBIOS emulator')
  else
    WriteLn;
  WriteLn;

  {display the network information}
  ServerInfo;
  WSInfo;
  PrinterInfo;
  if OptionSpecified('p') then begin
    PressAnyKey('to begin dump of print job flags');
    {$IFNDEF Windows}
    ClrScr;
    {$ENDIF}
    PrintJobDump;
  end;
end;

procedure DoNetBIOSInfo;


begin
  WriteLn;
  WriteLn('The network name for this machine is: ',NetBIOSMachineName);

  PrinterSetupStr;
end;

procedure NetBIOSSystem;
{This is a NetBIOS compatible system.}

begin
  {Tell them this is NetBIOS}
  WriteLn('This system is running a NetBIOS network');
  DoNetBIOSInfo;
end;

procedure OtherSystem;
{We can not identify the LAN running on this system (it may be that no LAN is
 is running).
}

begin
  WriteLn('This system is running some unknown LAN');
  WriteLn('It is possible that no LAN software is installed');
  WriteLn;
  WriteLn(
   'Attempting to continue with DOS Information and Redirection report'^M^J);

end;

procedure PCLanSystem;
{IBM PC Lan or close compatible is running on this system}
begin
  WriteLn('This system is running under PC-Lan (or close compatible)');
  DoNetBIOSInfo;
end;

function DetermineNetwork : NetType;
{Determine the network type to the best of our ability}

var
  NetBiosIsPresent : Boolean;
  Logged           : Boolean;

begin
  NetBiosIsPresent := NetBiosInstalled; {see if NetBios or an emulator is here}

  {first check for Novell.  This is important, because Novell will pass the}
  {test for PC Lan if the INT24.COM file is loaded.}
  if NetWareLoaded(Logged) then begin
    if not Logged then begin
      WriteLn('NetWare shell loaded, but user not logged on.');
      Halt(2);
    end;
    if NetBiosIsPresent then
      DetermineNetwork := LanNovellWithNetBIOS
    else
      DetermineNetwork := LanNovell;
  end

  {check for PC Lan before NetBIOS since PC Lan will pass the test for}
  {NetBIOS}
  else if IBMPCLanLoaded(PCLanOperation) then
    DetermineNetwork := LanPCLan
  else if NetBiosIsPresent then
    DetermineNetwork := LanNetBIOS
  else
    DetermineNetwork := LanOther;
end;

function DeviceIs(Dev : DeviceType) : String;
{Used by RedirectionReport to print header for either a printer or a drive}
begin
  if Dev = DevPrinter then
    DeviceIs := 'printer   => '
  else
    DeviceIs := 'disk drive=> ';
end;

procedure RedirectionReport(Net : NetType);
{Show all the redirections currently in use by the LAN.  Stop when keypressed
 or redirection list exhausted.  Will pause every 24 lines if necessary
}
  {!!.53 begin}
  function GetRedirectionEntry(RDLIndex : Word; var LocalName : NBNameStr;
                               var NetName : NetworkStr;
                               var Parameter : Word;
                               var Valid : Boolean;
                               var Dev   : DeviceType) : Word;
  begin
    if Net in [LanNovell, LanNovellWithNetBIOS] then
      GetRedirectionEntry := Share.GetRedirectionEntryNetWare(RDLIndex,
                                                              LocalName,
                                                              NetName,
                                                              Parameter,
                                                              Valid,
                                                              Dev)
    else
      GetRedirectionEntry := Share.GetRedirectionEntry(RDLIndex,
                                                       LocalName,
                                                       NetName,
                                                       Parameter,
                                                       Valid,
                                                       Dev);
  end;
  {!!.53 end}

const
  LINESPERSCREEN   = 20;

var
  Parm,I           : Word;
  Name,NetName     : String;
  Dev              : DeviceType;
  Valid            : Boolean;

begin
  I := 0;
  {display each item in the redirection list.  The list is exhausted when}
  {GetRedirectionEntry returns a non-zero function result}
  while (not KeyPressed) and
        (GetRedirectionEntry(I,Name,NetName,Parm,Valid,Dev)=0) do begin
    if Valid then
      {display the redirection info for this entry}
      WriteLn(DeviceIs(Dev),Pad(Name,5),' has been redirected to=> ',NetName);
    Inc(I);
    {pause every 20 lines}
    if I MOD LINESPERSCREEN = 0 then
      PressAnyKey(' for more');
  end;
  if I = 0 then
    WriteLn('No redirected devices');
end;

procedure DosInformationReport(Net : NetType);
{Show information obtained through DOS 3 calls}
begin
  WriteLn('DOS version ',DosMajor,'.',DosMinor);
  if DosMajor > 2 then begin
    Write('SHARE is ');
    if ShareInstalled then
      WriteLn('loaded')
    else
      WriteLn('not loaded');
    RedirectionReport(Net);  {report on redirected network devices}
  end
  else
    WriteLn('DOS 3 services required for this report');
end;

procedure CheckWindows;
begin
end;

var
  Network          : NetType;

begin
  ClrScr;
  WriteLn('NetINFO - by TurboPower Software - Version 5.41');
  WriteLn;
  CheckWindows;
  {try to figure out what LAN we're running on}
  Network := DetermineNetwork;
  case Network of
    LanNovell       : NovellSystem(FALSE);  {NetWare without NetBIOS}
    LanNovellWithNetBIOS
                    : NovellSystem(TRUE);   {NetWare with NetBIOS}
    LanNetBIOS      : NetBIOSSystem;        {NetBIOS}
    LanPCLan        : PCLanSystem;          {PC Lan}
    LanOther        : OtherSystem;          {Unkown or no network}
  end;

  WriteLn;

  PressAnyKey('to begin DOS information report');{pause before starting report}
  DosInformationReport(Network);            {!!.23}
end.

