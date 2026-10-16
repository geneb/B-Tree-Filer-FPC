(**************************************************************)
(*         B-Tree Isam Base Support Ver 5.41                  *)
(*   Copyright (C) 1987-1991 Dipl.Math. Ralf Nagel            *)
(*   Copyright (C) 1991-1993 ENZ EDV-Beratung GmbH            *)
(*                All rights reserved                         *)
(*   Modified and used under license by TurboPower Software   *)
(**************************************************************)

(**************************************************************)
(* Free Pascal port:                                          *)
(*   The MS-DOS register based interface (GenRegisters,       *)
(*   CallMsDos, CallIntr, interrupt vectors, real mode memory)*)
(*   has been replaced by a small operating system layer for  *)
(*   Windows and Linux. All routines return MS-DOS compatible *)
(*   error codes (0 = success, 2 = file not found, 3 = path   *)
(*   not found, 4 = too many open files, 5 = access denied,   *)
(*   6 = invalid handle, 32 = sharing violation, 33 = lock    *)
(*   violation), so the error handling of the FILER unit      *)
(*   works unchanged.                                         *)
(**************************************************************)

{--Conditional defines and compiler options}
  {$I btdefine.inc}
  {$F-,V-,B-,S-,I-,R-}
  {$Q-}


Unit BaseSupp;

InterFace

Uses
{$IFDEF MSWINDOWS}
  Windows,
{$ENDIF}
{$IFDEF UNIX}
  BaseUnix,
  Unix,
{$ENDIF}
  Dos,
  SysUtils;

Type
  IsamOSHandle = THandle;
    {-Operating system file handle}

Const
  IsamNoHandle = IsamOSHandle (-1);
    {-Value of a handle not associated with an open file}

  BTDefaultVirtualHeapSize = 4 * 1024 * 1024;

Var
  BTVirtualHeapSize : LongInt;
    {-MemAvail and MaxAvail below report the free space of a "virtual heap"
      of this size. Under MS-DOS the size of the page buffer allocated by
      BTInitIsam and other buffers were limited by the free heap; with the
      practically unlimited memory of Windows and Linux this setting limits
      them instead. It may be changed before BTInitIsam is called.}

  Function MemAvail : LongInt;
    {-Returns the free space of the virtual heap}

  Function MaxAvail : LongInt;
    {-Returns the largest free block of the virtual heap}

  Procedure CallGetTime ( Var Hour, Minute, Second, Sec100 : Word );
    {-Returns the current time}

  Procedure CallGetDate ( Var Year, Month, Day, DayOfWeek : Word );
    {-Returns the current date}

{--Operating system file interface; all functions return an MS-DOS
   compatible error code, 0 on success}

  Function IsamOSOpen (     Name     : String;
                            ReadOnly,
                            Shared,
                            Inherit  : Boolean;
                        Var Handle   : IsamOSHandle ) : Word;
    {-Opens an existing file}

  Function IsamOSCreate (     Name   : String;
                          Var Handle : IsamOSHandle ) : Word;
    {-Creates a file, truncates an existing one}

  Function IsamOSClose ( Handle : IsamOSHandle ) : Word;
    {-Closes a file}

  Function IsamOSSeek (     Handle : IsamOSHandle;
                            Pos    : Int64;
                            Origin : Word;
                        Var NewPos : Int64 ) : Word;
    {-Moves the file pointer; Origin 0 = start, 1 = current, 2 = end}

  Function IsamOSRead (     Handle    : IsamOSHandle;
                        Var Buffer;
                            Len       : LongInt;
                        Var BytesRead : LongInt ) : Word;
    {-Reads from a file}

  Function IsamOSWrite (     Handle       : IsamOSHandle;
                         Var Buffer;
                             Len          : LongInt;
                         Var BytesWritten : LongInt ) : Word;
    {-Writes to a file; Len = 0 truncates the file at the current position}

  Function IsamOSFlush ( Handle : IsamOSHandle ) : Word;
    {-Writes all buffered data of the file to disk}

  Function IsamOSExists ( Name : String ) : Word;
    {-Returns 0 if the file or directory exists}

  Function IsamOSDelete ( Name : String ) : Word;
    {-Deletes a file}

  Function IsamOSRename ( OldName, NewName : String ) : Word;
    {-Renames a file; fails if NewName already exists}

  Function IsamOSLock ( Handle : IsamOSHandle; Start, Len : Int64 ) : Word;
    {-Locks a byte range exclusively without waiting}

  Function IsamOSUnLock ( Handle : IsamOSHandle; Start, Len : Int64 ) : Word;
    {-Unlocks a byte range}

  Function IsamOSRegionLockedByOther ( Handle   : IsamOSHandle;
                                       Start,
                                       Len      : Int64;
                                       ForWrite : Boolean ) : Boolean;
    {-Returns True, if the byte range is locked through another handle.
      Windows enforces locks itself, so this is only needed on Linux, where
      locks are advisory; it lets reads and writes of a locked region fail
      just like under MS-DOS and Windows.}

  Procedure IsamOSSleep ( MilliSecs : LongInt );
    {-Suspends the program for MilliSecs milliseconds}

  Function IsamOSFileName ( Name : String ) : String;
    {-Converts a file name to the operating system's conventions}


Implementation

  Function MemAvail : LongInt;

  Var
    Used : PtrUInt;

  Begin
    Used := GetFPCHeapStatus.CurrHeapUsed;
    If Used >= PtrUInt (BTVirtualHeapSize) Then Begin
      MemAvail := 0;
    End Else Begin
      MemAvail := LongInt (PtrUInt (BTVirtualHeapSize) - Used);
    End;
  End;


  Function MaxAvail : LongInt;

  Begin
    MaxAvail := MemAvail;
  End;


  Procedure CallGetTime ( Var Hour, Minute, Second, Sec100 : Word );

  Begin
    Dos.GetTime ( Hour, Minute, Second, Sec100 );
  End;


  Procedure CallGetDate ( Var Year, Month, Day, DayOfWeek : Word );

  Begin
    Dos.GetDate ( Year, Month, Day, DayOfWeek );
  End;


  Function IsamOSFileName ( Name : String ) : String;

  Var
    I : Integer;

  Begin
  {$IFDEF UNIX}
    For I := 1 To Length (Name) Do Begin
      If Name [I] = '\' Then Name [I] := '/';
    End;
  {$ENDIF}
    IsamOSFileName := Name;
  End;


  Function CName ( Name : String ) : AnsiString;

  Begin
    CName := IsamOSFileName ( Name );
  End;


  Procedure IsamOSSleep ( MilliSecs : LongInt );

  Begin
    If MilliSecs > 0 Then SysUtils.Sleep ( MilliSecs );
  End;


{$IFDEF MSWINDOWS}
(***************************** Windows *******************************)

  Function SetFilePointerEx (     hFile            : THandle;
                                  liDistanceToMove : Int64;
                                  lpNewFilePointer : PInt64;
                                  dwMoveMethod     : DWord ) : BOOL; StdCall;
      External 'kernel32' Name 'SetFilePointerEx';


  Function MapError ( Err : DWord ) : Word;

  Begin
    Case Err Of
      0 :
        MapError := 0;
      ERROR_ALREADY_EXISTS,
      ERROR_FILE_EXISTS :
        MapError := 5;
      ERROR_INVALID_NAME,
      ERROR_BAD_PATHNAME :
        MapError := 3;
      ERROR_DISK_FULL,
      ERROR_HANDLE_DISK_FULL :
        MapError := 39;
      Else Begin
        {-Most Windows error codes are identical to the MS-DOS ones}
        If Err > $FFFF Then Begin
          MapError := 31;
        End Else Begin
          MapError := Err;
        End;
      End;
    End;
  End;


  Function LastErr : Word;

  Var
    E : Word;

  Begin
    E := MapError ( GetLastError );
    If E = 0 Then E := 31;
    LastErr := E;
  End;


  Function IsamOSOpen (     Name     : String;
                            ReadOnly,
                            Shared,
                            Inherit  : Boolean;
                        Var Handle   : IsamOSHandle ) : Word;

  Var
    Access,
    ShareMode : DWord;
    SA        : TSecurityAttributes;
    H         : THandle;

  Begin
    If ReadOnly Then Begin
      Access := GENERIC_READ;
    End Else Begin
      Access := GENERIC_READ Or GENERIC_WRITE;
    End;
    If Shared Or ReadOnly Then Begin
      ShareMode := FILE_SHARE_READ Or FILE_SHARE_WRITE;
    End Else Begin
      ShareMode := FILE_SHARE_READ;
    End;
    FillChar ( SA, SizeOf (SA), 0 );
    SA.nLength := SizeOf (SA);
    SA.bInheritHandle := Inherit;
    H := CreateFileA ( PChar (CName ( Name )), Access, ShareMode, @SA,
        OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0 );
    If H = INVALID_HANDLE_VALUE Then Begin
      IsamOSOpen := LastErr;
      Exit;
    End;
    Handle := H;
    IsamOSOpen := 0;
  End;


  Function IsamOSCreate (     Name   : String;
                          Var Handle : IsamOSHandle ) : Word;

  Var
    H : THandle;

  Begin
    H := CreateFileA ( PChar (CName ( Name )), GENERIC_READ Or GENERIC_WRITE,
        FILE_SHARE_READ Or FILE_SHARE_WRITE, Nil, CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL, 0 );
    If H = INVALID_HANDLE_VALUE Then Begin
      IsamOSCreate := LastErr;
      Exit;
    End;
    Handle := H;
    IsamOSCreate := 0;
  End;


  Function IsamOSClose ( Handle : IsamOSHandle ) : Word;

  Begin
    If CloseHandle ( Handle ) Then Begin
      IsamOSClose := 0;
    End Else Begin
      IsamOSClose := LastErr;
    End;
  End;


  Function IsamOSSeek (     Handle : IsamOSHandle;
                            Pos    : Int64;
                            Origin : Word;
                        Var NewPos : Int64 ) : Word;

  Var
    Method : DWord;
    NP     : Int64;

  Begin
    Case Origin Of
      1 : Method := FILE_CURRENT;
      2 : Method := FILE_END;
      Else Method := FILE_BEGIN;
    End;
    If SetFilePointerEx ( Handle, Pos, @NP, Method ) Then Begin
      NewPos := NP;
      IsamOSSeek := 0;
    End Else Begin
      IsamOSSeek := LastErr;
    End;
  End;


  Function IsamOSRead (     Handle    : IsamOSHandle;
                        Var Buffer;
                            Len       : LongInt;
                        Var BytesRead : LongInt ) : Word;

  Var
    Done : DWord;

  Begin
    BytesRead := 0;
    If Len <= 0 Then Begin
      IsamOSRead := 0;
      Exit;
    End;
    If ReadFile ( Handle, Buffer, DWord (Len), Done, Nil ) Then Begin
      BytesRead := Done;
      IsamOSRead := 0;
    End Else Begin
      If GetLastError = ERROR_HANDLE_EOF Then Begin
        IsamOSRead := 0;
      End Else Begin
        IsamOSRead := LastErr;
      End;
    End;
  End;


  Function IsamOSWrite (     Handle       : IsamOSHandle;
                         Var Buffer;
                             Len          : LongInt;
                         Var BytesWritten : LongInt ) : Word;

  Var
    Done : DWord;

  Begin
    BytesWritten := 0;
    If Len <= 0 Then Begin
      {-Like MS-DOS: writing zero bytes truncates the file}
      If SetEndOfFile ( Handle ) Then Begin
        IsamOSWrite := 0;
      End Else Begin
        IsamOSWrite := LastErr;
      End;
      Exit;
    End;
    If WriteFile ( Handle, Buffer, DWord (Len), Done, Nil ) Then Begin
      BytesWritten := Done;
      IsamOSWrite := 0;
    End Else Begin
      IsamOSWrite := LastErr;
    End;
  End;


  Function IsamOSFlush ( Handle : IsamOSHandle ) : Word;

  Begin
    If FlushFileBuffers ( Handle ) Then Begin
      IsamOSFlush := 0;
    End Else Begin
      IsamOSFlush := LastErr;
    End;
  End;


  Function IsamOSExists ( Name : String ) : Word;

  Begin
    If GetFileAttributesA ( PChar (CName ( Name )) ) = DWord ($FFFFFFFF)
        Then Begin
      IsamOSExists := LastErr;
    End Else Begin
      IsamOSExists := 0;
    End;
  End;


  Function IsamOSDelete ( Name : String ) : Word;

  Begin
    If DeleteFileA ( PChar (CName ( Name )) ) Then Begin
      IsamOSDelete := 0;
    End Else Begin
      IsamOSDelete := LastErr;
    End;
  End;


  Function IsamOSRename ( OldName, NewName : String ) : Word;

  Begin
    If MoveFileA ( PChar (CName ( OldName )), PChar (CName ( NewName )) )
        Then Begin
      IsamOSRename := 0;
    End Else Begin
      IsamOSRename := LastErr;
    End;
  End;


  Function IsamOSLock ( Handle : IsamOSHandle; Start, Len : Int64 ) : Word;

  Var
    Ov : TOverlapped;

  Begin
    FillChar ( Ov, SizeOf (Ov), 0 );
    Ov.Offset := DWord (Start And $FFFFFFFF);
    Ov.OffsetHigh := DWord (Start Shr 32);
    If LockFileEx ( Handle, LOCKFILE_EXCLUSIVE_LOCK
        Or LOCKFILE_FAIL_IMMEDIATELY, 0, DWord (Len And $FFFFFFFF),
        DWord (Len Shr 32), Ov ) Then Begin
      IsamOSLock := 0;
    End Else Begin
      IsamOSLock := LastErr;
    End;
  End;


  Function IsamOSUnLock ( Handle : IsamOSHandle; Start, Len : Int64 ) : Word;

  Var
    Ov : TOverlapped;

  Begin
    FillChar ( Ov, SizeOf (Ov), 0 );
    Ov.Offset := DWord (Start And $FFFFFFFF);
    Ov.OffsetHigh := DWord (Start Shr 32);
    If UnlockFileEx ( Handle, 0, DWord (Len And $FFFFFFFF),
        DWord (Len Shr 32), Ov ) Then Begin
      IsamOSUnLock := 0;
    End Else Begin
      IsamOSUnLock := LastErr;
    End;
  End;


  Function IsamOSRegionLockedByOther ( Handle   : IsamOSHandle;
                                       Start,
                                       Len      : Int64;
                                       ForWrite : Boolean ) : Boolean;

  Begin
    {-Windows enforces byte range locks on reads and writes itself}
    IsamOSRegionLockedByOther := False;
  End;

{$ENDIF}


{$IFDEF UNIX}
(****************************** Linux ********************************)

  Const
    FD_CLOEXEC = 1;
    F_RDLCK = 0;
    F_WRLCK = 1;
    F_UNLCK = 2;
    F_OFD_GETLK = 36;
    F_OFD_SETLK = 37;
      {-Open file description locks (Linux 3.15 and later). Unlike classic
        POSIX locks they belong to a file handle, not to the process, so they
        behave like MS-DOS and Windows locks: two handles of the same program
        lock against each other, and closing one handle does not release the
        locks of another one.}

  Var
    UseOFDLocks : Boolean;


  Function MapErrNo ( E : LongInt ) : Word;

  Begin
    Case E Of
      0 :
        MapErrNo := 0;
      ESysENOENT :
        MapErrNo := 2;
      ESysENOTDIR,
      ESysENAMETOOLONG :
        MapErrNo := 3;
      ESysEMFILE,
      ESysENFILE :
        MapErrNo := 4;
      ESysEACCES,
      ESysEPERM,
      ESysEROFS,
      ESysEISDIR,
      ESysEEXIST,
      ESysEXDEV :
        MapErrNo := 5;
      ESysEBADF :
        MapErrNo := 6;
      ESysENOMEM :
        MapErrNo := 8;
      ESysENOSPC :
        MapErrNo := 39;
      ESysEAGAIN,
      ESysEDEADLK :
        MapErrNo := 33;
      Else
        MapErrNo := 31;   {general failure}
    End;
  End;


  Function LastErr : Word;

  Var
    E : Word;

  Begin
    E := MapErrNo ( fpGetErrNo );
    If E = 0 Then E := 31;
    LastErr := E;
  End;


  Function IsamOSOpen (     Name     : String;
                            ReadOnly,
                            Shared,
                            Inherit  : Boolean;
                        Var Handle   : IsamOSHandle ) : Word;

  Var
    Flags : cInt;
    H     : cInt;

  Begin
    If ReadOnly Then Begin
      Flags := O_RDONLY;
    End Else Begin
      Flags := O_RDWR;
    End;
    Repeat
      H := fpOpen ( CName ( Name ), Flags );
    Until (H >= 0) Or (fpGetErrNo <> ESysEINTR);
    If H < 0 Then Begin
      IsamOSOpen := LastErr;
      Exit;
    End;
    If Not Inherit Then fpFcntl ( H, F_SETFD, FD_CLOEXEC );
    Handle := H;
    IsamOSOpen := 0;
  End;


  Function IsamOSCreate (     Name   : String;
                          Var Handle : IsamOSHandle ) : Word;

  Var
    H : cInt;

  Begin
    Repeat
      H := fpOpen ( CName ( Name ), O_RDWR Or O_CREAT Or O_TRUNC, $1B6 )  {octal 666};
    Until (H >= 0) Or (fpGetErrNo <> ESysEINTR);
    If H < 0 Then Begin
      IsamOSCreate := LastErr;
      Exit;
    End;
    fpFcntl ( H, F_SETFD, FD_CLOEXEC );
    Handle := H;
    IsamOSCreate := 0;
  End;


  Function IsamOSClose ( Handle : IsamOSHandle ) : Word;

  Begin
    If fpClose ( Handle ) = 0 Then Begin
      IsamOSClose := 0;
    End Else Begin
      IsamOSClose := LastErr;
    End;
  End;


  Function IsamOSSeek (     Handle : IsamOSHandle;
                            Pos    : Int64;
                            Origin : Word;
                        Var NewPos : Int64 ) : Word;

  Var
    Whence : cInt;
    R      : Off_T;

  Begin
    Case Origin Of
      1 : Whence := Seek_Cur;
      2 : Whence := Seek_End;
      Else Whence := Seek_Set;
    End;
    R := fpLSeek ( Handle, Pos, Whence );
    If R < 0 Then Begin
      IsamOSSeek := LastErr;
    End Else Begin
      NewPos := R;
      IsamOSSeek := 0;
    End;
  End;


  Function IsamOSRead (     Handle    : IsamOSHandle;
                        Var Buffer;
                            Len       : LongInt;
                        Var BytesRead : LongInt ) : Word;

  Var
    P : PByte;
    R : TSSize;

  Begin
    BytesRead := 0;
    P := @Buffer;
    While Len > 0 Do Begin
      R := fpRead ( Handle, P^, Len );
      If R < 0 Then Begin
        If fpGetErrNo = ESysEINTR Then Continue;
        IsamOSRead := LastErr;
        Exit;
      End;
      If R = 0 Then Break;
      Inc (BytesRead, R);
      Inc (P, R);
      Dec (Len, R);
    End;
    IsamOSRead := 0;
  End;


  Function IsamOSWrite (     Handle       : IsamOSHandle;
                         Var Buffer;
                             Len          : LongInt;
                         Var BytesWritten : LongInt ) : Word;

  Var
    P   : PByte;
    R   : TSSize;
    Cur : Off_T;

  Begin
    BytesWritten := 0;
    If Len <= 0 Then Begin
      {-Like MS-DOS: writing zero bytes truncates the file}
      Cur := fpLSeek ( Handle, 0, Seek_Cur );
      If (Cur < 0) Or (fpFTruncate ( Handle, Cur ) <> 0) Then Begin
        IsamOSWrite := LastErr;
      End Else Begin
        IsamOSWrite := 0;
      End;
      Exit;
    End;
    P := @Buffer;
    While Len > 0 Do Begin
      R := fpWrite ( Handle, P^, Len );
      If R < 0 Then Begin
        If fpGetErrNo = ESysEINTR Then Continue;
        If (fpGetErrNo = ESysENOSPC) And (BytesWritten > 0) Then Break;
          {-Report a short write like MS-DOS does on a full disk}
        IsamOSWrite := LastErr;
        Exit;
      End;
      If R = 0 Then Break;
      Inc (BytesWritten, R);
      Inc (P, R);
      Dec (Len, R);
    End;
    IsamOSWrite := 0;
  End;


  Function IsamOSFlush ( Handle : IsamOSHandle ) : Word;

  Begin
    If fpFSync ( Handle ) = 0 Then Begin
      IsamOSFlush := 0;
    End Else Begin
      IsamOSFlush := LastErr;
    End;
  End;


  Function IsamOSExists ( Name : String ) : Word;

  Var
    Info : Stat;

  Begin
    If fpStat ( CName ( Name ), Info ) = 0 Then Begin
      IsamOSExists := 0;
    End Else Begin
      IsamOSExists := LastErr;
    End;
  End;


  Function IsamOSDelete ( Name : String ) : Word;

  Begin
    If fpUnlink ( CName ( Name ) ) = 0 Then Begin
      IsamOSDelete := 0;
    End Else Begin
      IsamOSDelete := LastErr;
    End;
  End;


  Function IsamOSRename ( OldName, NewName : String ) : Word;

  Begin
    If IsamOSExists ( NewName ) = 0 Then Begin
      {-MS-DOS and Windows never replace an existing file here}
      IsamOSRename := 5;
      Exit;
    End;
    If fpRename ( CName ( OldName ), CName ( NewName ) ) = 0 Then Begin
      IsamOSRename := 0;
    End Else Begin
      IsamOSRename := LastErr;
    End;
  End;


  Function DoLock ( Handle   : IsamOSHandle;
                    LockType : cShort;
                    Start,
                    Len      : Int64 ) : Word;

  Var
    FL : FLock;
    R  : cInt;

  Begin
    If Len <= 0 Then Begin
      DoLock := 1;   {invalid function, like MS-DOS}
      Exit;
    End;
    FillChar ( FL, SizeOf (FL), 0 );
    FL.l_type := LockType;
    FL.l_whence := Seek_Set;
    FL.l_start := Start;
    FL.l_len := Len;
    FL.l_pid := 0;
    If UseOFDLocks Then Begin
      R := fpFcntl ( Handle, F_OFD_SETLK, FL );
      If (R <> 0) And (fpGetErrNo = ESysEINVAL) Then Begin
        {-Kernel without open file description locks}
        UseOFDLocks := False;
        FL.l_pid := 0;
        R := fpFcntl ( Handle, F_SETLK, FL );
      End;
    End Else Begin
      R := fpFcntl ( Handle, F_SETLK, FL );
    End;
    If R = 0 Then Begin
      DoLock := 0;
    End Else Begin
      If (fpGetErrNo = ESysEACCES) Or (fpGetErrNo = ESysEAGAIN) Then Begin
        DoLock := 33;
      End Else Begin
        DoLock := LastErr;
      End;
    End;
  End;


  Function IsamOSLock ( Handle : IsamOSHandle; Start, Len : Int64 ) : Word;

  Begin
    IsamOSLock := DoLock ( Handle, F_WRLCK, Start, Len );
  End;


  Function IsamOSUnLock ( Handle : IsamOSHandle; Start, Len : Int64 ) : Word;

  Begin
    IsamOSUnLock := DoLock ( Handle, F_UNLCK, Start, Len );
  End;


  Function IsamOSRegionLockedByOther ( Handle   : IsamOSHandle;
                                       Start,
                                       Len      : Int64;
                                       ForWrite : Boolean ) : Boolean;

  Var
    FL  : FLock;
    Cmd : cInt;

  Begin
    IsamOSRegionLockedByOther := False;
    If Len <= 0 Then Exit;
    FillChar ( FL, SizeOf (FL), 0 );
    If ForWrite Then Begin
      FL.l_type := F_WRLCK;
    End Else Begin
      FL.l_type := F_RDLCK;
    End;
    FL.l_whence := Seek_Set;
    FL.l_start := Start;
    FL.l_len := Len;
    If UseOFDLocks Then Begin
      Cmd := F_OFD_GETLK;
    End Else Begin
      Cmd := F_GETLK;
    End;
    If fpFcntl ( Handle, Cmd, FL ) <> 0 Then Exit;
    IsamOSRegionLockedByOther := FL.l_type <> F_UNLCK;
  End;

{$ENDIF}


Begin
  BTVirtualHeapSize := BTDefaultVirtualHeapSize;
{$IFDEF UNIX}
  UseOFDLocks := True;
{$ENDIF}
End.
