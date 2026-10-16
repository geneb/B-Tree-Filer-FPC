(**************************************************************)
(*          B-Tree Isam Include Ver 5.41                      *)
(*   Copyright (C) 1986-1991 Dipl.Math. Ralf Nagel            *)
(*   Copyright (C) 1991-1993 ENZ EDV-Beratung GmbH            *)
(*                All rights reserved                         *)
(*   Modified and used under license by TurboPower Software   *)
(**************************************************************)

  Function IsamCheckLockError : Boolean;

  Begin
    IsamCheckLockError := False;
    If IsamDriveNotReadyError Or (IOResult = 152) Then Begin
      IsamDriveNotReadyError := False;
      IsamLockError := False;
      IsamOK := False;
      IsamError := 10110;
      IsamCheckLockError := True;
      Exit;
    End;
    If IsamLockError Then Begin
      IsamLockError := False;
      IsamOK := False;
      IsamError := 10140;
      IsamCheckLockError := True;
    End;
  End;


  Procedure IsamClearOK;

  Begin
    IsamOK := True;
    IsamError := 0;
    IsamLockError := False;
    IsamDriveNotReadyError := False;
    IsamDOSError := 0;
    IsamDOSFunc := 0;
  End;


  Procedure SaveErrorStat ( Var ErrSt : ErrStatSaveRec );

  Begin
    With ErrSt Do Begin
      OK := IsamOK;
      Error := IsamError;
      DError := IsamDOSError;
      DFunc := IsamDOSFunc;
    End;
  End;


  Procedure RestoreErrorStat ( ErrSt : ErrStatSaveRec );

  Begin
    With ErrSt Do Begin
      IsamOK := OK;
      IsamError := Error;
      IsamDOSError := DError;
      IsamDOSFunc := DFunc;
    End;
  End;


  Function IsamSetDosRetry ( NrOfRetries, WaitTime : Integer ) : Boolean;
    {-The MS-DOS sharing retry count has no equivalent under Windows and
      Linux; lock attempts are retried by FILER itself, see IsamLockTimeOut}
  Begin
    IsamSetDosRetry := True;
  End;


  Function IsamOSResult ( Err, Func : Word ) : Boolean;
    {-Stores the error state of an operating system call the same way as it
      was done for the MS-DOS calls; returns True on success}
  Begin
    If IsamDOSError = 0 Then IsamDOSFunc := Func;
    If (Err <> 0) And (IsamDOSError = 0) Then IsamDOSError := Err;
    IsamOSResult := Err = 0;
  End;


  Procedure IsamAssign ( Var F : IsamFile; FName : IsamFileName );

  Var
    L : Word;

  Begin
    With F Do Begin
      L := Length (FName);
      If L > Pred (SizeOf (Name)) Then L := Pred (SizeOf (Name));
      Move ( FName [1], Name, L );
      Name [L] := #0;
      Handle := IsamNoHandle;
      Shared := False;
    End;
  End;


  Function IsamGetFileName ( Var F : IsamFile ) : IsamFileName;

  Var
    FName : IsamFileName;

  Begin
    FName [0] := Char (Pred (SizeOf (IsamFileName)));
    Move ( F.Name, FName [1], Byte (FName [0]));
    FName [0] := Char (Pred (Pos (#0, FName)));
    IsamGetFileName := FName;
  End;


  Function IsamExistsIsamFile ( Var IsamF : IsamFile ) : Boolean;

  Var
    Err : Word;

  Begin
    Err := IsamOSExists ( IsamGetFileName ( IsamF ) );
    IsamExistsIsamFile := False;
    If IsamCheckLockError Then Exit;
    IsamExistsIsamFile := IsamOSResult ( Err, $4300 );
  End;


  Function IsamExists ( Name : IsamFileName ) : Boolean;

  Var
    IsamF : IsamFile;

  Begin
    IsamAssign ( IsamF, Name );
    IsamExists := IsamExistsIsamFile ( IsamF );
  End;


  Procedure IsamRewrite ( Var F : IsamFile );

  Var
    Err : Word;
    H   : IsamOSHandle;

  Begin
    Err := IsamOSCreate ( IsamGetFileName ( F ), H );
    If IsamCheckLockError Then Exit;
    If Not IsamOSResult ( Err, $3C00 ) Then Begin
      IsamOK := False;
      Case Err Of
        3 : IsamError := 9900;
        4 : IsamError := 9901;
        Else IsamError := 10140;
      End;
      Exit;
    End;
    F.Handle := H;
    F.Shared := False;
  End;


  Procedure IsamClose ( Var F : IsamFile );

  Var
    Err : Word;

  Begin
    Err := IsamOSClose ( F.Handle );
    If IsamCheckLockError Then Exit;
    If Not IsamOSResult ( Err, $3E00 ) Then Begin
      IsamOK := False;
      Case Err Of
        6 : IsamError := 9904;
        Else IsamError := 10140;
      End;
      Exit;
    End;
    F.Handle := IsamNoHandle;
  End;


  Procedure IsamDelete ( Var F : IsamFile );

  Var
    Err : Word;

  Begin
    Err := IsamOSDelete ( IsamGetFileName ( F ) );
    If IsamCheckLockError Then Exit;
    If Not IsamOSResult ( Err, $4100 ) Then Begin
      IsamOK := False;
      Case Err Of
        2 : IsamError := 9903;
        3 : IsamError := 9900;
        Else IsamError := 10140;
      End;
    End;
  End;


  Procedure IsamRename ( Var F : IsamFile; FName : IsamFileName );

  Var
    Err : Word;

  Begin
    Err := IsamOSRename ( IsamGetFileName ( F ), FName );
    If IsamCheckLockError Then Exit;
    If Not IsamOSResult ( Err, $5600 ) Then Begin
      IsamOK := False;
      Case Err Of
        2  : IsamError := 9903;
        3,
        17 : IsamError := 9900;
        Else IsamError := 10140;
      End;
    End;
  End;


  Procedure IsamLongSeek ( Var F : IsamFile; Ref : LongInt );

  Var
    Err    : Word;
    NewPos : Int64;

  Begin
    Err := IsamOSSeek ( F.Handle, Ref, 0, NewPos );
    If IsamDOSError = 0 Then IsamDOSFunc := $4200;
    If IsamCheckLockError Then Exit;
    If Not IsamOSResult ( Err, $4200 ) Then Begin
      IsamOK := False;
      Case Err Of
        6 : IsamError := 9904;
        Else IsamError := 10140;
      End;
    End;
  End;


  Procedure IsamLongSeekEOF ( Var F : IsamFile; Var Len : LongInt );

  Var
    Err    : Word;
    NewPos : Int64;

  Begin
    Err := IsamOSSeek ( F.Handle, 0, 2, NewPos );
    If IsamCheckLockError Then Exit;
    If Not IsamOSResult ( Err, $4202 ) Then Begin
      IsamOK := False;
      Case Err Of
        6 : IsamError := 9904;
        Else IsamError := 10140;
      End;
      Exit;
    End;
    Len := LongInt (NewPos);
  End;


  Function IsamRegionLocked ( Var F    : IsamFile;
                                  Len  : LongInt;
                                  Wr   : Boolean ) : Boolean;
    {-Emulates the mandatory locking of MS-DOS and Windows on systems with
      advisory locks: returns True, if the next Len bytes at the current
      file position are locked through another handle}
  Var
    CurPos : Int64;

  Begin
    IsamRegionLocked := False;
  {$IFDEF UNIX}
    If Not F.Shared Or (Len <= 0) Then Exit;
    If IsamOSSeek ( F.Handle, 0, 1, CurPos ) <> 0 Then Exit;
    IsamRegionLocked := IsamOSRegionLockedByOther ( F.Handle, CurPos, Len,
        Wr );
  {$ENDIF}
  End;


  Procedure IsamBlockReadRetLen ( Var F         : IsamFile;
                                  Var Dest;
                                      Len       : Word;
                                  Var BytesRead : Word );

  Var
    Err  : Word;
    Done : LongInt;

  Begin
    If IsamRegionLocked ( F, Len, False ) Then Begin
      Err := 33;
      Done := 0;
    End Else Begin
      Err := IsamOSRead ( F.Handle, Dest, Len, Done );
    End;
    If IsamDOSError = 0 Then IsamDOSFunc := $3F00;
    If IsamCheckLockError Then Exit;
    If Not IsamOSResult ( Err, $3F00 ) Then Begin
      IsamOK := False;
      Case Err Of
        6 : IsamError := 9904;
        Else IsamError := 10140;
      End;
    End Else Begin
      BytesRead := Done;
    End;
  End;


  Procedure IsamBlockRead ( Var F    : IsamFile;
                            Var Dest;
                                Len  : Word );

  Var
    BytesRead : Word;

  Begin
    IsamBlockReadRetLen ( F, Dest, Len, BytesRead );
    If IsamOK Then Begin
      If BytesRead <> Len Then Begin
        IsamOK := False;
        IsamError := 10070;
      End;
    End;
  End;


  Procedure IsamBlockWrite ( Var F       : IsamFile;
                             Var Source;
                                 Len     : Word );

  Var
    Err  : Word;
    Done : LongInt;

  Begin
    If IsamRegionLocked ( F, Len, True ) Then Begin
      Err := 33;
      Done := 0;
    End Else Begin
      Err := IsamOSWrite ( F.Handle, Source, Len, Done );
    End;
    If IsamDOSError = 0 Then IsamDOSFunc := $4000;
    If IsamCheckLockError Then Exit;
    If Not IsamOSResult ( Err, $4000 ) Then Begin
      IsamOK := False;
      Case Err Of
        6 : IsamError := 9904;
        Else IsamError := 10140;
      End;
      Exit;
    End Else Begin
      If Len <> Done Then Begin
        IsamOK := False;
        IsamError := 10075;
      End;
    End;
  End;


  Procedure IsamReset ( Var F : IsamFile; NetUsed, ReadOnly : Boolean );

  Var
    Err  : Word;
    H    : IsamOSHandle;
    Func : Word;

  Begin
    If ReadOnly Then Begin
      Func := $3D00;
    End Else Begin
      Func := $3D02;
    End;
    If Not InheritFileHandles Then Func := Func Or $80;
    If NetUsed Then Func := Func Or 64;
    Err := IsamOSOpen ( IsamGetFileName ( F ), ReadOnly, NetUsed,
        InheritFileHandles, H );
    If IsamCheckLockError Then Exit;
    If Not IsamOSResult ( Err, Func ) Then Begin
      IsamOK := False;
      Case Err Of
        2  : IsamError := 9903;
        3  : IsamError := 9900;
        4  : IsamError := 9901;
        12 : IsamError := 9908;
        Else IsamError := 10140;
      End;
      Exit;
    End;
    F.Handle := H;
    F.Shared := NetUsed;
  End;


  Procedure IsamGetBlock ( Var F : IsamFile; Ref, Len : LongInt; Var Dest );

  Var
    DestPtr : ^Byte;

  Const
    LIMaxInt = $FFF0;

  Begin
    DestPtr := Addr (Dest);
    IsamLongSeek ( F, Ref );
    If Not IsamOK Then Exit;
    While Len > LIMaxInt Do Begin
      IsamBlockRead ( F, DestPtr^, LIMaxInt );
      If Not IsamOK Then Exit;
      Len := Len - LIMaxInt;
      Inc (DestPtr, LIMaxInt);
    End;
    IsamBlockRead ( F, DestPtr^, Word (Len) );
  End;


  Procedure IsamPutBlock ( Var F : IsamFile; Ref, Len : LongInt; Var Source );

  Var
    SourcePtr : ^Byte;

  Const
    LIMaxInt = $FFF0;

  Begin
    SourcePtr := Addr (Source);
    IsamLongSeek ( F, Ref );
    If Not IsamOK Then Exit;
    While Len > LIMaxInt Do Begin
      IsamBlockWrite ( F, SourcePtr^, LIMaxInt );
      If Not IsamOK Then Exit;
      Len := Len - LIMaxInt;
      Inc (SourcePtr, LIMaxInt);
    End;
    IsamBlockWrite ( F, SourcePtr^, Word (Len) );
  End;


  Procedure IsamPutDummyBlock ( Var F : IsamFile; Ref, Len : LongInt );

  Const
    EmptyArrLen = 1536;

  Var
    EmptyArr : Array [1..EmptyArrLen] Of Char;

  Begin
    FillChar ( EmptyArr, SizeOf (EmptyArr), 0 );
    IsamLongSeek ( F, Ref );
    If Not IsamOK Then Exit;
    While Len > EmptyArrLen Do Begin
      IsamBlockWrite ( F, EmptyArr, SizeOf (EmptyArr) );
      If Not IsamOK Then Exit;
      Len := Len - SizeOf (EmptyArr);
    End;
    IsamBlockWrite ( F, EmptyArr, Word (Len) );
  End;


  Procedure IsamFlush ( Var F        : IsamFile;
                        Var WithDUP  : Boolean;
                            NetUsed  : Boolean );
    {-Under MS-DOS the handle was either flushed with function $68 or
      duplicated and closed; FlushFileBuffers/fsync replace both. WithDUP
      is always returned True, since the file position is never lost}
  Var
    Err : Word;

  Begin
    WithDUP := True;
    If Not IsamFlushDOS33 Then Exit;
      {-Flushing to disk was disabled by the user}
    Err := IsamOSFlush ( F.Handle );
    If Not IsamOSResult ( Err, $6800 ) Then Begin
      IsamOK := False;
      If Err = 6 Then Begin
        IsamError := 9904;
      End Else Begin
        IsamError := 10140;
      End;
    End;
  End;


  Procedure IsamExtractFileNames (     FNameComp : IsamFileBlockName;
                                   Var FNameD,
                                       FNameI    : IsamFileBlockName );

  Var
    SP : Word;


    Procedure Trim ( Var S : IsamFileBlockName );

    Var
      P : Word;

    Begin
      While True Do Begin
        P := Pos ( ' ', S );
        If P = 0 Then Exit;
        Delete ( S, P, 1 );
      End;
    End;


  Begin
    Trim ( FNameComp );
    SP := Pos ( ';', FNameComp );
    If SP = 0 Then Begin
      FNameD := FNameComp;
      FNameI := FNameComp;
    End Else Begin
      FNameD := Copy ( FNameComp, 1, Pred (SP) );
      FNameI := Copy ( FNameComp, Succ (SP), Length (FNameComp) - SP );
    End;
  End;


  Procedure IsamCopyFile ( Source,
                           Dest                  : IsamFileBlockName;
                           DeleteSourceAfterCopy : Boolean );

  Var
    SourceF,
    DestF     : IsamFile;
    BufPtr    : Pointer;
    BufSize,
    BytesRead : Word;


    Procedure UnDo ( Err : Integer; All : Boolean );

    Begin
      If All Then FreeMem ( BufPtr, BufSize );
      IsamClose ( SourceF );
      IsamClose ( DestF );
      IsamOK := False;
      IsamError := Err;
    End;


    Function DetermineBufferSize : Boolean;

    Const
      MinBufSize = 2048;
      MaxBufSize = 63488;

    Var
      MaxFree : LongInt;
      Nr      : Word;

    Begin
      DetermineBufferSize := True;
      MaxFree := MaxAvail;
      If MaxFree >= MaxBufSize Then Begin
        BufSize := MaxBufSize;
        Exit;
      End;
      If MaxFree < MinBufSize Then Begin
        DetermineBufferSize := False;
        Exit;
      End;
      Nr := MaxFree Div MinBufSize;
      BufSize := Nr * MinBufSize;
    End;


  Begin
    IsamAssign ( SourceF, Source );
    IsamAssign ( DestF, Dest );
    IsamReset ( SourceF, False, True );
    If Not IsamOK Then Exit;
    IsamRewrite ( DestF );
    If Not IsamOK Then Begin
      UnDo ( IsamError, False );
      Exit;
    End;
    If DetermineBufferSize Then Begin
      GetMem ( BufPtr, BufSize );
    End Else Begin
      UnDo ( 10420, False );
      Exit;
    End;
    Repeat
      IsamBlockReadRetLen ( SourceF, BufPtr^, BufSize, BytesRead );
      If BytesRead <> 0 Then Begin
        IsamBlockWrite ( DestF, BufPtr^, BytesRead );
        If Not IsamOK Then Begin
          UnDo ( IsamError, True );
          Exit;
        End;
      End;
    Until BytesRead = 0;
    FreeMem ( BufPtr, BufSize );
    IsamClose ( SourceF );
    If Not IsamOK Then Begin
      UnDo ( IsamError, False );
      Exit;
    End;
    IsamClose ( DestF );
    If Not IsamOK Then Begin
      UnDo ( IsamError, False );
      Exit;
    End;
    If DeleteSourceAfterCopy Then IsamDelete ( SourceF );
  End;


  Function IsamForceExtension ( Name, Ext : IsamFileName ) : IsamFileName;

  Var
    DotPos : Word;


    Function HasExtension ( Name : IsamFileBlockName; Var DotPos : Word )
        : Boolean;

    Var
      W : Word;

    Begin
      DotPos := 0;
      For W := Length (Name) DownTo 1 Do Begin
        If (Name [W] = '.') And (DotPos = 0) Then Begin
          DotPos := W;
        End;
      End;
      HasExtension := (DotPos > 0) And
          (Pos ('\', Copy (Name, Succ (DotPos), 255)) = 0) And
          (Pos ('/', Copy (Name, Succ (DotPos), 255)) = 0);
    End;


  Begin
    If HasExtension ( Name, DotPos ) Then Begin
      IsamForceExtension := Copy ( Name, 1, DotPos ) + Ext;
    End Else Begin
      IsamForceExtension := Name + '.' + Ext;
    End;
  End;


  Function RoundToGranul ( Value : Word ) : Word;
    {-Rounds Value up to the next multiple of 8}
  Begin
    RoundToGranul := (Value + 7) And $FFF8;
  End;


  Procedure IsamDelay ( MilliSecs : LongInt );
    {-Delays for MilliSecs milliseconds without using the CRT unit}
  Const
    MilliSecsInOneHour = 3600000;

  Begin
    If MilliSecs > MilliSecsInOneHour Then Begin
      MilliSecs := MilliSecsInOneHour;
        {-No Delay beyond one hour}
    End;
    IsamOSSleep ( MilliSecs );
  End;
