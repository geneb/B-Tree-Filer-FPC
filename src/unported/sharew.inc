{*********************************************************}
{*                   SHAREW.INC 5.41                     *}
{*        Copyright (c) TurboPower Software 1991.        *}
{*                 All rights reserved.                  *}
{*********************************************************}
{$IFNDEF Windows}
type
  TFileRec = Dos.FileRec;
{$ENDIF}

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
    Regs : Registers;
  begin
    FillChar(Regs, SizeOf(Regs), 0);
    with Regs do begin
      Ax := $3000;
      WinIntr($21, Regs);
      DosVer := Al;
      Minor  := Ah;
    end;
  end;

  function SetPrinterSetup(SetUpStr : PrinterSetUpStr;
                           RedirectionIndex : Word) : Boolean;

  var
    Regs             : Registers;
    PSS              : ^PrinterSetUpStr;
    S, P : Pointer;
  begin
    SetPrinterSetup := False;
    if not GetRealModeMem(SizeOf(PrinterSetUpStr), S, P) then exit;
    PSS := P;
    Move(SetUpStr, PSS^, Succ(Length(SetUpStr)));

    FillChar(Regs, SizeOf(Regs), 0);
    with Regs do begin
      AX := SETPRINTSETUP;
      BX := RedirectionIndex;
      CX := Length(PSS^);
      DS := SegOfs(S).Segm;
      SI := 1;

      WinIntr($21, Regs);
      SetPrinterSetup := not Odd(Flags);
    end;
    FreeRealModeMem(P);
  end;

  function GetPrinterSetup(var SetUpStr : PrinterSetUpStr;
                           RedirectionIndex : Word) : Boolean;

  var
    Regs             : Registers;
    PSS              : ^PrinterSetUpStr;
    S, P : Pointer;
  begin
    GetPrinterSetup := False;
    if not GetRealModeMem(SizeOf(PrinterSetUpStr), S, P) then exit;
    PSS := P;

    FillChar(Regs, SizeOf(Regs), 0);
    with Regs do begin
      AX := GETPRINTSETUP;
      BX := RedirectionIndex;
      ES := SegOfs(S).Segm;
      DI := 1;

      WinIntr($21, Regs);

      Move(PSS^[1], SetUpStr[1], CX);
      SetUpStr[0] := Char(CX);
      GetPrinterSetup := not Odd(Flags);
    end;
    FreeRealModeMem(P);
  end;

  function GetMachineName(var S : NBNameStr; var MachNum : Byte) : Boolean;

  type
    BufferType       = Array[1..16] of Char;
  var
    BufP             : ^BufferType;
    Regs             : Registers;
    Sm, P       : Pointer;
  begin
    GetMachineName := False;
    if not GetRealModeMem(SizeOf(BufferType), Sm, P) then exit;
    BufP := P;

    FillChar(Regs, SizeOf(Regs), 0);
    with Regs do begin
      AX := GETMACHNAME;
      DS := SegOfs(Sm).Segm;            { point DS:DX at buffer to return name}
      DX := 0;
      WinIntr($21, Regs);
      if Odd(Flags) then            {error if carry flag set}
        GetMachineName := FALSE
      else begin
        GetMachineName := TRUE;
        if CH = 0 then begin        {if CH is zero then no name defined}
          S := '';
          MachNum := 0;
        end
        else begin
          S := AsciiZ2Str(BufP^);   {convert asciiz name to string}
          MachNum := CL;            {return the machine name number}
        end;
      end
    end;
    FreeRealModeMem(P);
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

    FillChar(Regs, SizeOf(Regs), 0);
    with Regs do begin
      AX := PCLANCHECK;
      WinIntr($2F,Regs);               {call dos multiplex interrupt}

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
   name, and NetBIOS Machine name number are returned.
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
    Regs : Registers;

  begin
    if DOSMajor < 3 then begin           {DOS services required}
      DosLockRec:= WrongDosVersion;
      Exit;
    end;
    if TFileRec(F).Mode = fmClosed then begin
      DosLockRec := FileNotOpen;
      Exit;
    end;

    FillChar(Regs, SizeOf(Regs), 0);
    with Regs do begin
      {load the info into the regs}
      Ax := $5C00; {DOS call 5Ch}
      Bx := TFileRec(F).Handle;
      Cx := DoubleWord(FilePosition).HiWord;
      Dx := DoubleWord(FilePosition).LoWord;
      Si := DoubleWord(FileLength).HiWord;
      Di := DoubleWord(FileLength).LoWord;
      WinIntr($21, Regs);
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
    Regs : Registers;

  begin
    if DOSMajor < 3 then begin           {DOS services required}
      UnlockDosRec := WrongDosVersion;
      Exit;
    end;
    if TFileRec(F).Mode = fmClosed then begin
      UnlockDosRec := FileNotOpen;
      Exit;
    end;

    FillChar(Regs, SizeOf(Regs), 0);
    with Regs do begin
      Ax := $5C01; {DOS call 5Ch, subfunction 1}
      Bx := TFileRec(F).Handle;
      Cx := DoubleWord(FilePosition).HiWord;
      Dx := DoubleWord(FilePosition).LoWord;
      Si := DoubleWord(FileLength).HiWord;
      Di := DoubleWord(FileLength).LoWord;
      WinIntr($21, Regs);
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

  type
    LNA = Array[1..16] of Char;
    NNA = Array[1..128] of Char;
  var
    Regs             : Registers;
    LN               : ^LNA;
    NN               : ^NNA;
    L                : Word;
    S, P       : Pointer;
  begin
    if not GetRealModeMem(SizeOf(LNA)+SizeOf(NNA), S, P) then exit;
    LN := P;
    NN := P;
    Inc(Word(NN), SizeOf(LNA));

    {DOS 3.1 or greater is required for redirector services}
    if (DosMajor > 3) or ((DosMajor = 3) and (DosMinor >= 1)) then begin
      FillChar(LN^,SizeOf(LN^),0);         {fill buffers with #0s}
      FillChar(NN^,SizeOf(NN^),0);
      Move(LocalName[1],LN^,Length(LocalName));   {move local name into buffer}
      L := Length(NetworkName);
      Move(NetWorkName[1],NN^,L);                 {move network name into buffer}
      L := L + 2;
      Move(Password[1],NN^[L],Length(Password));  {move password into place}

      FillChar(Regs, SizeOf(Regs), 0);
      with Regs do begin
        AX := $5F03;
        if Boolean(TypeOfDev) then {tell DOS whether this is drive or printer}
          BL := DriveDevice
        else
          BL := PrinterDevice;
        CX := Parameter;
        DS := SegOfs(S).Segm;
        SI := 0;
        ES := SegOfs(S).Segm;
        DI := SizeOf(LNA);
        WinIntr($21, Regs);               {error if carry flag set}
        if Odd(Flags) then
          RedirectDevice := AX
        else
          RedirectDevice := 0;
      end;
    end
    else
      RedirectDevice := WrongDosVersion;
    FreeRealModeMem(P);
  end;

  function CancelRedirection(LocalName : NBNameStr) : Word;
  {Cancels a previous redirection}

  type
    LNA              = Array[1..16] of Char;
  var
    Regs             : Registers;
    LN               : ^LNA;
    S, P       : Pointer;
  begin
    if not GetRealModeMem(SizeOf(LNA), S, P) then exit;
    LN := P;

    {DOS 3.1 or greater required for redirector services}
    if (DosMajor > 3) or ((DosMajor = 3) and (DosMinor >= 1)) then begin
      FillChar(LN^,SizeOf(LN^),0);
      Move(LocalName[1],LN^,Length(LocalName));   {move local name into place}

      with Regs do begin
        AX := $5F04;
        DS := SegOfs(S).Segm;         {point to local name buffer (asciiz) }
        SI := 0;
        WinIntr($21, Regs);
        if Odd(Flags) then     {error if carry flag set}
          CancelRedirection := AX
        else
          CancelRedirection := 0;
      end;
    end
    else
      CancelRedirection := WrongDosVersion;
    FreeRealModeMem(P);
  end;


  function GetRedirectionEntry(RDLIndex : Word; var LocalName : NBNameStr;
                              var NetName : NetworkStr;
                              var Parameter : Word;
                              var Valid : Boolean;
                              var Dev   : DeviceType) : Word;
  {Returns a redirection list entry}
  type
    LNA = Array[1..16] of Char;
    NNA = Array[1..128] of Char;
  var
    LN               : ^LNA;
    NN               : ^NNA;
    Regs             : Registers;
    S, P       : Pointer;
  begin
    if not GetRealModeMem(SizeOf(LNA)+SizeOf(NNA), S, P) then exit;
    LN := P;
    NN := P;
    Inc(Word(NN), SizeOf(LNA));

    {DOS 3.1 or greater required for redirector services}
    if (DosMajor > 3) or ((DosMajor = 3) and (DosMinor >= 1)) then begin
      with Regs do begin
        AX := $5F02;
        BX := RDLIndex;            {the Redirection list index}
        DS := SegOfs(S).Segm;             {point DS:SI to the local name}
        SI := 0;
        ES := SegOfs(S).Segm;             {point ES:DI to the network name}
        DI := SizeOf(LNA);
        WinIntr($21, Regs);
        if Odd(Flags) then         {error if carry flag set}
          GetRedirectionEntry := AX
        else begin
          GetRedirectionEntry := 0;            {no error}
          LocalName := AsciiZ2Str(LN^); {return the local name}
          NetName   := AsciiZ2Str(NN^); {return the network name}
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
    FreeRealModeMem(P);
  end;

  function GetRedirectionEntryNetWare(RDLIndex : Word; var LocalName : NBNameStr;
                                      var NetName : NetworkStr;
                                      var Parameter : Word;
                                      var Valid : Boolean;
                                      var Dev   : DeviceType) : Word;
  {Returns a redirection list entry}
  type
    LNA = Array[1..16] of Char;
    NNA = Array[1..256] of Char;
  var
    LN               : ^LNA;
    NN               : ^NNA;
    Regs             : Registers;
    S, P             : Pointer;
    Scrap            : String;
  begin
    if not GetRealModeMem(SizeOf(LNA)+SizeOf(NNA), S, P) then exit;
    LN := P;
    NN := P;
    Inc(Word(NN), SizeOf(LNA));

    {DOS 3.1 or greater required for redirector services}
    if (DosMajor > 3) or ((DosMajor = 3) and (DosMinor >= 1)) then begin
      FillChar(P^, SizeOf(LNA)+SizeOf(NNA), 0);
      with Regs do begin
        AX := $5F02;
        BX := RDLIndex;            {the Redirection list index}
        DS := SegOfs(S).Segm;             {point DS:SI to the local name}
        SI := 0;
        ES := SegOfs(S).Segm;             {point ES:DI to the network name}
        DI := SizeOf(LNA);
        WinIntr($21, Regs);
        if Odd(Flags) then         {error if carry flag set}
          GetRedirectionEntryNetWare := AX
        else begin
          GetRedirectionEntryNetWare := 0;            {no error}
          LocalName := AsciiZ2Str(LN^); {return the local name}
          NetName   := AsciiZ2Str(NN^); {return the network name}
          Scrap     := AsciiZ2Str(NN^[Length(NetName) + 2]);
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
    FreeRealModeMem(P);
  end;

  function GetTempFileName(PathN : PathStr;
                           var TempFileName : PathStr) : Word;
  {Returns the pathname of a unique file for the specified directory}

  var
    Regs             : Registers;
    PN               : ^PathStr;
    S, P       : Pointer;
  begin
    if not GetRealModeMem(SizeOf(PathStr), S, P) then exit;
    PN := P;
    FillChar(PN^, SizeOf(PN^), 0);
    Move(PathN[1], PN^, Length(PathN));

    if (DosMajor >= 3) then begin        {DOS 3 services required}
      FillChar(Regs, SizeOf(Regs), 0);
      with Regs do begin
        AH := $5A;
        CX := $00;
        DS := SegOfs(S).Segm;             {point DS:DX to pathname (skip length byte) }
        DX := 0;
        WinIntr($21, Regs);
        if Odd(Flags) then begin   {error if carry flag set}
          TempFileName := '';
          GetTempFileName:= AX;
        end
        else begin
          TempFileName := AsciiZ2Str(PN^);    {convert Asciiz to }
                                              {pascal string     }

          GetTempFileName := 0;
          BX := AX;
          AH := $3E;
          WinIntr($21, Regs); {close the temp file (func 5Ah leaves it open) }
        end;
      end;
    end
    else begin
      TempFileName := '';
      GetTempFileName := WrongDosVersion;
    end;
    FreeRealModeMem(P);
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
        WinIntr($21, Regs);
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
        WinIntr($21, Regs);
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
        WinIntr($21, Regs);
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
    if TFileRec(F).Mode = fmClosed then begin
      UpDateFile := FileNotOpen;
      Exit;
    end;

    {the DOS version is not relevant here}
    with Regs do begin
      AH := $45;
      BX := TFileRec(F).Handle;     {put the file handle in BX}
      WinIntr($21, Regs);
      if not Odd(Flags) then begin {error if carry flag set}
        BX := AX;
        AH := $3E;
        WinIntr($21, Regs); {close the temp file}
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
        WinIntr($2F, Regs);     {DOS multitasking interrupt}
        ShareInstalled := (AL = $FF); {DOS returns $FF in AL if SHARE installed}
      end
    else
      ShareInstalled := False;
  end;

