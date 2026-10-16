{*********************************************************}
{*                    SHARE.INC 5.41                     *}
{*        Copyright (c) TurboPower Software 1991.        *}
{*                 All rights reserved.                  *}
{*********************************************************}

function AsciiZ2Str(var Buffer) : String;
{convert a null terminated string (Asciiz string) to a Pascal string}

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
  {until char(0) found or maximum string length reached, place char from }
  {asciiz string into pascal string}
  while (A[I] <> #0) and (I < AsciiZMax) do begin
    S[I] := A[I];
    Inc(I);
  end;
  S[0] := Char(I-1);
  AsciiZ2Str := S   {return the pascal string as the function result}
end;


function DosVer(var Minor : Byte) : Byte;
{ This function returns the DOS major version as it's result, and }
{ the minor version as a var parameter }
var
  Reg : Registers;

begin
  with Reg do begin
    Ax := $3000;
    MsDos(Reg);
    DosVer := Al;
    Minor  := Ah;
  end;
end;

function SetPrinterSetup(SetUpStr : PrinterSetUpStr;
                         RedirectionIndex : Word) : Boolean;

var
  Regs             : Registers;
  S                : PrinterSetUpStr;

begin
  S := SetUpStr;
  with Regs do begin
    AX := SETPRINTSETUP;
    BX := RedirectionIndex;
    CX := Length(S);
    DS := Seg(S);
    SI := Ofs(S[1]);

    MsDos(Regs);
    SetPrinterSetup := not Odd(Flags);
  end;
end;

function GetPrinterSetup(var SetUpStr : PrinterSetUpStr;
                         RedirectionIndex : Word) : Boolean;

var
  Regs             : Registers;

begin
  with Regs do begin
    AX := GETPRINTSETUP;
    BX := RedirectionIndex;
    ES := Seg(SetUpStr);
    DI := Ofs(SetUpStr[1]);

    MsDos(Regs);
    SetUpStr[0] := Char(CX);
    GetPrinterSetup := not Odd(Flags);
  end;
end;

function GetMachineName(var S : NBNameStr; var MachNum : Byte) : Boolean;

var
  Buffer           : Array[1..16] of Char;
  Regs             : Registers;

begin
  with Regs do begin
    AX := GETMACHNAME;
    DS := Seg(Buffer);            { point DS:DX at buffer to return name}
    DX := Ofs(Buffer);
    MsDos(Regs);
    if Odd(Flags) then            {error if carry flag set}
      GetMachineName := FALSE
    else begin
      GetMachineName := TRUE;
      if CH = 0 then begin        {if CH is zero then no name defined}
        S := '';
        MachNum := 0;
      end
      else begin
        S := AsciiZ2Str(Buffer);  {convert asciiz name to string}
        MachNum := CL;            {return the machine name number}
      end;
    end
  end;
end;

function IBMPCLanLoaded(var Lan : PCLanOpType) : Boolean;
{-Determines whether PC-Lan program is loaded and returns. The operating mode
of the network is returned in the Var parameter Lan. WARNING: Some other
networks will pass this test (Novell's ELS Level II 2.12 certainly does).
}

var
  Regs             : Registers;

begin
  IBMPCLanLoaded := FALSE;        {Assume it's not loaded}
  if DosMajor < 3 then            {DOS 3 services required for this call}
    Exit;

  with Regs do begin
    AX := PCLANCHECK;
    Intr($2F,Regs);               {call dos multiplex interrupt}

    if AL = 0 then                {if AL is zero, then no PC-Lan}
      Exit;

    {decipher opertating type flags}
    if (BL and SERVERFLAG) = SERVERFLAG then
      Lan := LanServer
    else if (BL and MESSENGERFLAG) = MESSENGERFLAG then
      Lan := LanMessenger
    else if (BL and RECEIVERFLAG) = RECEIVERFLAG then
      Lan := LanReceiver
    else if (BL and REDIRECTORFLAG) = REDIRECTORFLAG then
      Lan := LanRedirector
    else
      Lan := LanUnknown;

  end;
  IBMPCLanLoaded := TRUE;
end;

function PCLanInfo(var Lan : PCLanOpType; var MachineName : NBNameStr;
                   var MachineNo : Byte) : Boolean;

{A higher level PC-Lan detection function which returns TRUE if PC-Lan is
 loaded. If PC Lan is loaded, then the opertaing mode, the NetBIOS machine
 name, and NetBIOS Machine name numeber are returned.
}

begin
  if IBMPCLanLoaded(Lan) then begin  {if PCLan is loaded, then...}
    if not GetMachineName(MachineName,MachineNo) then begin {get the name}
      MachineName := '';
      MachineNo := 0;
    end;
    PCLanInfo := TRUE;
  end
  else
    PCLanInfo := FALSE;
end;

function DosLockRec(var F;  FilePosition,FileLength : LongInt) : Word;
{ This function uses DOS call 5Ch to lock all or part of a file.  }
{ The DOS error code is returned as the result.  The file takes a }
{ file, followed by two LongInts, representing the file position  }
{ (or offset), and the size in bytes to lock starting at said     }
{ offset. Make sure you Unlock any locks before closing the file. }
{ An error code of 1 means invalid DOS version. It may also mean  }
{ that SHARE hasn't been run. See DOS Technical Reference or      }
{ Duncan's Advanced MS-DOS) for info on error codes.              }
var
  Reg : Registers;

begin
  if DOSMajor < 3 then begin           {DOS services required}
    DosLockRec:= WrongDosVersion;
    Exit;
  end;
  if FileRec(F).Mode = fmClosed then begin
    DosLockRec := FileNotOpen;
    Exit;
  end;
  with Reg do begin
    {load the info into the regs}
    Ax := $5C00; {DOS call 5Ch}
    Bx := FileRec(F).Handle;
    Cx := DoubleWord(FilePosition).HiWord;
    Dx := DoubleWord(FilePosition).LoWord;
    Si := DoubleWord(FileLength).HiWord;
    Di := DoubleWord(FileLength).LoWord;
    MsDos(Reg);
    if Odd(Flags) then       {error if carry flag set}
      DosLockRec := Ax
    else
      DosLockRec := 0;
  end;
end;

function UnlockDosRec(var F; FilePosition,FileLength : LongInt) : Word;
{ Similar to LockFile, except uses DOS call 5Ch sunfunction 1  }
{ You must ensure that the offset and FileLength are identical }
{ to the ones used to lock the file                            }
var
  Reg : Registers;

begin
  if DOSMajor < 3 then begin           {DOS services required}
    UnlockDosRec := WrongDosVersion;
    Exit;
  end;
  if FileRec(F).Mode = fmClosed then begin
    UnlockDosRec := FileNotOpen;
    Exit;
  end;
  with Reg do begin
    Ax := $5C01; {DOS call 5Ch, subfunction 1}
    Bx := FileRec(F).Handle;
    Cx := DoubleWord(FilePosition).HiWord;
    Dx := DoubleWord(FilePosition).LoWord;
    Si := DoubleWord(FileLength).HiWord;
    Di := DoubleWord(FileLength).LoWord;
    MsDos(Reg);
    if Odd(Flags) then
      UnlockDosRec := Ax        {error if carry flag set}
    else
      UnlockDosRec := 0;
  end;
end;

function RedirectDevice(TypeOfDev : DeviceType; LocalName : NBNameStr;
                        NetWorkName,Password : NetworkStr;
                        Parameter : Word) : Word;
{Redirects a local device name to a network resource. (see interface)}

var
  Regs             : Registers;
  LN               : Array[1..16] of Char;
  NN               : Array[1..128] of Char;
  L                : Word;

begin
  {DOS 3.1 or greater is required for redirector services}
  if (DosMajor > 3) or ((DosMajor = 3) and (DosMinor >= 1)) then begin
    FillChar(LN,SizeOf(LN),0);         {fill buffers with #0s}
    FillChar(NN,SizeOf(NN),0);
    Move(LocalName[1],LN,Length(LocalName));   {move local name into buffer}
    L := Length(NetworkName);
    Move(NetWorkName[1],NN,L);                 {move network name into buffer}
    L := L + 2;
    Move(Password[1],NN[L],Length(Password));  {move password into place}

    with Regs do begin
      AX := $5F03;
      if Boolean(TypeOfDev) then {tell DOS whether this is drive or printer}
        BL := DriveDevice
      else
        BL := PrinterDevice;
      CX := Parameter;
      DS := Seg(LN);
      SI := Ofs(LN);
      ES := Seg(NN);
      DI := Ofs(NN);
      MsDos(Regs);               {error if carry flag set}
      if Odd(Flags) then
        RedirectDevice := AX
      else
        RedirectDevice := 0;
    end;
  end
  else
    RedirectDevice := WrongDosVersion;
end;

function CancelRedirection(LocalName : NBNameStr) : Word;
{Cancels a previous redirection}

var
  Regs             : Registers;
  LN               : Array[1..16] of Char;

begin
  {DOS 3.1 or greater required for redirector services}
  if (DosMajor > 3) or ((DosMajor = 3) and (DosMinor >= 1)) then begin
    FillChar(LN,SizeOf(LN),0);
    Move(LocalName[1],LN,Length(LocalName));   {move local name into place}

    with Regs do begin
      AX := $5F04;
      DS := Seg(LN);         {point to local name buffer (asciiz) }
      SI := Ofs(LN);
      MsDos(Regs);
      if Odd(Flags) then     {error if carry flag set}
        CancelRedirection := AX
      else
        CancelRedirection := 0;
    end;
  end
  else
    CancelRedirection := WrongDosVersion;
end;


function GetRedirectionEntry(RDLIndex : Word; var LocalName : NBNameStr;
                            var NetName : NetworkStr;
                            var Parameter : Word;
                            var Valid : Boolean;
                            var Dev   : DeviceType) : Word;
{Returns a redirection list entry}

var
  LN               : Array[1..16] of Char;
  NN               : Array[1..128] of Char;
  Regs             : Registers;

begin
  {DOS 3.1 or greater required for redirector services}
  if (DosMajor > 3) or ((DosMajor = 3) and (DosMinor >= 1)) then begin
    with Regs do begin
      AX := $5F02;
      BX := RDLIndex;            {the Redirection list index}
      DS := Seg(LN);             {point DS:SI to the local name}
      SI := Ofs(LN);
      ES := Seg(NN);             {point ES:DI to the network name}
      DI := Ofs(NN);
      MsDos(Regs);
      if Odd(Flags) then         {error if carry flag set}
        GetRedirectionEntry := AX
      else begin
        GetRedirectionEntry := 0;            {no error}
        LocalName := AsciiZ2Str(LN); {return the local name}
        NetName   := AsciiZ2Str(NN); {return the network name}
        Parameter := CX;                     {the parameter saved when device}
                                             {was redirected}
        Valid     := BH = 0;
        if BL = PrinterDevice then           {return the device type}
          Dev := DevPrinter
        else
          Dev := DevDrive;
      end;
    end;
  end
  else
    GetRedirectionEntry := WrongDosVersion;
end;

function GetRedirectionEntryNetWare(RDLIndex : Word;                 {!!.53}
                                    var LocalName : NBNameStr;
                                    var NetName : NetworkStr;
                                    var Parameter : Word;
                                    var Valid : Boolean;
                                    var Dev   : DeviceType) : Word;
{ Return redirection entry information from the redirector with special
  NetWare information.}
var
  LN               : Array[1..16] of Char;
  NN               : Array[1..256] of Char;
  Regs             : Registers;
  Scrap            : String;
begin
  {DOS 3.1 or greater required for redirector services}
  if (DosMajor > 3) or ((DosMajor = 3) and (DosMinor >= 1)) then begin
    FillChar(NN, SizeOf(NN), 0);
    with Regs do begin
      AX := $5F02;
      BX := RDLIndex;            {the Redirection list index}
      DS := Seg(LN);             {point DS:SI to the local name}
      SI := Ofs(LN);
      ES := Seg(NN);             {point ES:DI to the network name}
      DI := Ofs(NN);
      MsDos(Regs);
      if Odd(Flags) then         {error if carry flag set}
        GetRedirectionEntryNetWare := AX
      else begin
        GetRedirectionEntryNetWare := 0;            {no error}
        LocalName := AsciiZ2Str(LN); {return the local name}
        NetName   := AsciiZ2Str(NN); {return the network name}
        Scrap     := AsciiZ2Str(NN[Length(NetName) + 2]);
        if Length(Scrap) <> 0 then
          NetName   := NetName + '\' + Scrap;
        Parameter := CX;                     {the parameter saved when device}
                                             {was redirected}
        Valid     := BH = 0;
        if BL = PrinterDevice then           {return the device type}
          Dev := DevPrinter
        else
          Dev := DevDrive;
      end;
    end;
  end
  else
    GetRedirectionEntryNetWare := WrongDosVersion;
end;

function GetTempFileName(PathN : PathStr;
                         var TempFileName : PathStr) : Word;
{Returns the pathname of a unique file for the specified directory}

var
  Regs             : Registers;
  PN               : PathStr;

begin
  if (DosMajor >= 3) then begin        {DOS 3 services required}
    PN := PathN + #0;                  {null terminate the string}
    with Regs do begin
      AH := $5A;
      CX := $00;
      DS := Seg(PN);             {point DS:DX to pathname (skip length byte) }
      DX := Ofs(PN[1]);
      MsDos(Regs);
      if Odd(Flags) then begin   {error if carry flag set}
        TempFileName := '';
        GetTempFileName:= AX;
      end
      else begin
        TempFileName := AsciiZ2Str(PN[1]); {convert Asciiz to }
                                           {pascal string     }

        GetTempFileName := 0;
        BX := AX;
        AH := $3E;
        MsDos(Regs); {close the temp file (func 5Ah leaves it open) }
      end;
    end;
  end
  else begin
    TempFileName := '';
    GetTempFileName := WrongDosVersion;
  end;
end;

function GetExtendedError(var Class,Action,Locus : Byte) : Word;
{returns detailed information about a DOS error}

var
  Regs             : Registers;

begin
  if (DosMajor >= 3) then begin  {DOS 3 or greater required}

    with Regs do begin
      AH := $59;
      BX := $00;
      MsDos(Regs);
      GetExtendedError := AX;  {return the extended error code as func result}
      Class   := BH;           {return the error class}
      Action  := BL;           {return the recommended action}
      Locus   := CH;           {return the location of the error}
    end
  end
  else
    GetExtendedError := 0;
end;

function FlagIsSet(Flags, FlagMask : Word) : Boolean;
  {-Returns True if the bit specified by FlagMask is set in Flags}
  inline(
    $5A/                     {pop dx    ;FlagMask into DX}
    $58/                     {pop ax    ;Flags into AX}
    $21/$D0/                 {and ax,dx ;Mask out everything not in FlagMask}
    $74/$03/                 {jz  Exit}
    $B8/$01/$00);            {mov ax,1  ;AX = Ord(True)}
                             {Exit:}

function IsDriveLocal(Drive : Byte) : Boolean;
{Returns TRUE if drive is local. Drive is the drive number (0 for default, 1
 for A:, 2 for B: ...).
 NOTE: If DOS 3 or greater is not loaded, it is assumed that the Drive is
 local (since DOS has no standard way of knowing under DOS 2).
}

var
  Regs             : Registers;

begin
  if (DosMajor >= 3) then begin  {DOS 3 or greater required}
    with Regs do begin
      AX := $4409;
      BL := Drive;
      MsDos(Regs);
      if Odd(Flags) then
        IsDriveLocal := TRUE  {if error, then assume drive is local}
      else
        {the drive is local if bit 12 of DX is clear}
        IsDriveLocal := not FlagIsSet(DX,$1000); {!!.01}
    end;
  end
  else
    IsDriveLocal := TRUE;        {assume it's local for DOS < 3}
end;

function IsFileLocal(var F) : Boolean;
{Returns TRUE if specified file is on a local drive.
 NOTE: If DOS 3 or greater is not loaded, it is assumed that the file is
 local (since DOS has no standard way of knowing under DOS 2).
}

var
  Regs             : Registers;
  Handle           : Word absolute F;

begin
  if (DosMajor >= 3) then begin  {DOS 3 services required}
    with Regs do begin
      AX := $440A;
      BX := Handle;
      MsDos(Regs);
      if Odd(Flags) then
        IsFileLocal := TRUE  {if error, then assume file is local}
      else
        {the file is local if bit 15 of DX is clear}
        IsFileLocal := not FlagIsSet(DX,$8000)  {!!.01};
    end;
  end
  else
    IsFileLocal := TRUE;         {assume it's local for DOS < 3}
end;

function UpdateFile(var F) : Word;
{ Flushes an open file to disk. Forces a duplicate of file handle, then }
{ closes it.  Error codes are: 0 for success, 4 if no handles are       }
{ available, or 6 if handle invalid or file not open.}

var
  Regs             : Registers;

begin
  if FileRec(F).Mode = fmClosed then begin
    UpDateFile := FileNotOpen;
    Exit;
  end;

  {the DOS version is not relevant here}
  with Regs do begin
    AH := $45;
    BX := FileRec(F).Handle;     {put the file handle in BX}
    MsDos(Regs);
    if not Odd(Flags) then begin {error if carry flag set}
      BX := AX;
      AH := $3E;
      MsDos(Regs); {close the temp file}
      if Odd(Flags) then         {error if carry flag set}
        UpdateFile := AX
      else
        UpdateFile := 0;
    end
    else
      UpDateFile := AX;
  end;
end;

function ShareInstalled : Boolean;
{ Returns TRUE if SHARE installed}

var
  Regs             : Registers;
begin
  {INT $2F functions available only in DOS 3}
  if DosMajor >= 3 then
    with Regs do begin
      AX := $1000;         {get SHARE installed status}
      Intr($2F, Regs);     {DOS multitasking interrupt}
      ShareInstalled := (AL = $FF); {DOS returns $FF in AL if SHARE installed}
    end
  else
    ShareInstalled := False;
end;

