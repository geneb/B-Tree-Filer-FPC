(**************************************************************)
(*          B-Tree Isam Include Ver 5.41                      *)
(*   Copyright (C) 1987-1991 Dipl.Math. Ralf Nagel            *)
(*   Copyright (C) 1991-1993 ENZ EDV-Beratung GmbH            *)
(*                All rights reserved                         *)
(*   Modified and used under license by TurboPower Software   *)
(**************************************************************)

{--Free Pascal port:
   The MS-DOS critical error (INT 24h) handler is not needed any more, since
   Windows and Linux return lock violations directly as error codes.
   The Novell interface (INT 21h, functions BCh/BEh) is not available.
   The MsNet interface uses the byte range locking of the operating system
   (see BaseSupp: LockFileEx on Windows, fcntl locks on Linux).}

(*****************************************************************************)

{--Start of NoNet definition}
  Function NoNetLockRecord  ( Start,
                              Len       : LongInt;
                              Handle    : IsamOSHandle;
                              TimeOut,
                              DelayTime : Word ) : Boolean;

  Begin
    NoNetLockRecord := True;
  End;


  Function NoNetUnLockRecord  ( Start,
                                Len    : LongInt;
                                Handle : IsamOSHandle ) : Boolean;

  Begin
    NoNetUnLockRecord := True;
  End;


  Function NoNetExitNet : Boolean;

  Begin
    NoNetExitNet := True;
  End;


  Function NoNetInitNet : Boolean;

  Begin
    IsamNrOfWS := 0;
    IsamLockRecord := NoNetLockRecord;
    IsamUnLockRecord := NoNetUnLockRecord;
    IsamExitNet := NoNetExitNet;
    NoNetInitNet := True;
  End;


{--NoNet definition finished}

(*****************************************************************************)

{$IFDEF MsNet}

  Function MsNetLockRecord  ( Start,
                              Len       : LongInt;
                              Handle    : IsamOSHandle;
                              TimeOut,
                              DelayTime : Word ) : Boolean;

  Var
    TimeCount : Word;
    OK        : Boolean;
    Err       : Word;

  Begin
    TimeCount := 0;
    Repeat
      Inc (TimeCount, DelayTime);
      If IsamDOSError = 0 Then IsamDOSFunc := $5C00;
      Err := IsamOSLock ( Handle, Start, Len );
      If (Err <> 0) And (IsamDOSError = 0) Then IsamDOSError := Err;
      OK := Err = 0;
      If Not OK And (TimeCount < TimeOut) Then Begin
        IsamDelay ( DelayTime );
      End;
    Until OK Or (TimeCount >= TimeOut);
    MsNetLockRecord := OK;
  End;


  Function MsNetUnLockRecord  ( Start,
                                Len    : LongInt;
                                Handle : IsamOSHandle ) : Boolean;

  Var
    Err : Word;

  Begin
    If IsamDOSError = 0 Then IsamDOSFunc := $5C01;
    Err := IsamOSUnLock ( Handle, Start, Len );
    If (Err <> 0) And (IsamDOSError = 0) Then IsamDOSError := Err;
    MsNetUnLockRecord := Err = 0;
  End;


  Function MsNetExitNet : Boolean;

  Begin
    MsNetExitNet := True;
  End;


  Function MsNetInitNet : Boolean;
    {-Byte range locking is always available under Windows and Linux, so
      TestNetExistance has no effect any more}
  Begin
    IsamNrOfWS := MaxNrOfWorkStations;
    IsamLockRecord := MsNetLockRecord;
    IsamUnLockRecord := MsNetUnLockRecord;
    IsamExitNet := MsNetExitNet;
    MsNetInitNet := True;
  End;


{$ENDIF}    {MsNet definition finished}


  {--Additional net interfaces insert here}

(*****************************************************************************)
(*****************************************************************************)

  Function IsamInitNet ( ExpectedNet : NetSupportType ) : Boolean;

  Begin
    Case ExpectedNet Of
      NoNet :
        IsamInitNet := NoNetInitNet;

  {$IFDEF MsNet}
      MsNet :
        IsamInitNet := MsNetInitNet;
  {$ENDIF}

      Else Begin
        IsamInitNet := False;
      End;
    End; {Case}
  End;
