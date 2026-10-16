{Copyright (C) 1992 ENZ EDV-Beratung GmbH}

{-Test program to reach network or multitasking traffic in a given frequency

  Usage:
    Traffic (/N | /M | /O) (/R | /W | /Bx) [/Dy] [/Tz] [/Ff] [/Ll]
  /N : Novell
  /M : MsNet
  /O : without a Net

  /R : read only
  /W : write only
  /B : both read and write (after x reads a write is done)

  /D : delay time of y milliseconds after each operation (default 100ms)

  /T : timeout of z milliseconds for each operation
       (default IsamLockTimeOut ms)

  /F : timeout factor f for fileblock lock in relation to readlock
       (default IsamFBLockTimeOutFactor)

  /L : delay time of l milliseconds after a failed lock attempt
       (default IsamDelayBetwLocks ms)


  If not used with /R the fileblock "TRAFFIC" with 4 keys may be created}


{--Conditional defines and compiler options}
  {$I btdefine.inc}
  {$F-,V-,B-,S-,I-,R-}
    {$Q-}


Program Traffic;

Uses
  Crt,
  BaseSupp,
  Filer; {!!.TP}

Const
  TrafficFBName = 'traffic';
  RandomMax = 65535;

Type
  TrafficRecDef = Record
    Null : LongInt;
    S    : String [48];
    Fill : Array [1..300] Of Byte;
  End;
  OperationModeDef = ( ReadOnly, WriteOnly, Both );

Var
  DelayTime          : Word;
  OperationMode      : OperationModeDef;
  NrOfReadsEachWrite : Word;
  NetToInit          : NetSupportType;
  TrafficFB          : IsamFileBlockPtr;


  Procedure ShowParams;

  Begin
    Writeln;
    Writeln ( 'Usage:' );

    Writeln ( '  Traffic (/N | /M | /O) (/R | /W | /Bx) '
        + '[/Dy] [/Tz] [/Ff] [/Ll]' );
    Writeln ( '/N : Novell' );
    Writeln ( '/M : MsNet' );
    Writeln ( '/O : without a net' );
    Writeln;
    Writeln ( '/R : read only' );
    Writeln ( '/W : write only' );
    Writeln ( '/B : both read and write (after x reads a write is done)' );
    Writeln;
    Writeln ( '/D : delay time of y milliseconds after each operation '
        + '(default 100ms)' );
    Writeln;
    Writeln ( '/T : timeout of z milliseconds for each operation (default ',
        IsamLockTimeOut, 'ms)' );
    Writeln;
    Writeln ( '/F : timeout factor f for fileblock lock in relation '
        + 'to readlock (default ', IsamFBLockTimeOutFactor, ')' );
    Writeln;
    Writeln ( '/L : delay time of l milliseconds after a failed '
        + 'lock attempt (default ', IsamDelayBetwLocks, 'ms)' )
  End;


  Function GetParams : Boolean;

  Const
    MaxParams = 6;
    FixParams = 2;

  Var
    P             : String [20];
    Error         : Integer;
    Value         : Word;
    I             : Word;

  Begin
    GetParams := False;

    If Not (ParamCount In [FixParams..MaxParams]) Then Exit;

    P := ParamStr ( 1 );
    If P [1] <> '/' Then Exit;
    Delete ( P, 1, 1);
    If Length ( P ) <> 1 Then Exit;
    Case Upcase (P [1]) Of
      'N' : NetToInit := Novell;
      'M' : NetToInit := MsNet;
      'O' : NetToInit := NoNet;
      Else Exit;
    End; {Case}

    P := ParamStr ( 2 );
    If P [1] <> '/' Then Exit;
    Delete ( P, 1, 1);
    If Length ( P ) = 0 Then Exit;
    Case Upcase (P [1]) Of
      'R' : OperationMode := ReadOnly;
      'W' : OperationMode := WriteOnly;
      'B' : Begin
        Delete ( P, 1, 1);
        Val ( P, NrOfReadsEachWrite, Error );
        If Error <> 0 Then Exit;
        OperationMode := Both;
      End;
      Else Exit;
    End; {Case}

    DelayTime := 100;
    For I := Succ (FixParams) To ParamCount Do Begin
      P := ParamStr ( I );
      If P [1] <> '/' Then Exit;
      Delete ( P, 1, 1);
      If Length ( P ) = 0 Then Exit;
      Case Upcase (P [1]) Of
        'D', 'T', 'F', 'L' : Begin
          Val ( Copy (P, 2, 255), Value, Error );
          If Error <> 0 Then Exit;
          Case Upcase (P [1]) Of
            'D' : DelayTime := Value;
            'T' : IsamLockTimeOut := Value;
            'F' : IsamFBLockTimeOutFactor := Value;
            'L' : IsamDelayBetwLocks := Value;
          End; {Case}
        End;
        Else Exit;
      End; {Case}
    End;

    GetParams := True;
  End;


  Function PrepareFileBlock : Boolean;

  Var
    PSS : LongInt;
    S   : String [20];

    Function CreateFB : Boolean;

    Var
      IID : IsamIndDescr;
      I   : Word;

    Begin
      CreateFB := False;

      With IID [1] Do Begin
        KeyL := 12;
        AllowDupK := False;
      End;
      For I := 2 To 4 Do Begin
        With IID [I] Do Begin
          KeyL := 12;
          AllowDupK := True;
        End;
      End;
      BTCreateFileBlock ( TrafficFBName, SizeOf (TrafficRecDef), 4, IID );
      If Not IsamOK Then Exit;

      CreateFB := True;
    End;


  Begin
    PrepareFileBlock := False;
    Randomize;
    PSS := BTInitIsam ( NetToInit, MemAvail - 100000, 0 );
    If Not IsamOK Then Exit;
    BTOpenFileBlock ( TrafficFB, TrafficFBName, False, False, False, True );
    If IsamError = 9903 Then Begin
      If OperationMode = ReadOnly Then Exit;
      If Not CreateFB Then Exit;
      BTOpenFileBlock ( TrafficFB, TrafficFBName, False, False, False, True );
      If Not IsamOK Then Exit;
      S := 'created and ';
    End Else Begin
      If Not IsamOK Then Exit;
      S := '';
    End;

    Writeln ( 'B-Tree Filer initialized with ', PSS Shr 16, '/',
        PSS And $FFFF, ' page buffers' );
    Writeln ( 'Fileblock TRAFFIC ' + S + 'opened successfully' );
    Case BTNetSupported Of
      NoNet  : S := 'Supported net: NoNet';
      Novell : S := 'Supported net: Novell';
      MsNet  : S := 'Supported net: MsNet';
    End;
    Writeln ( S + '      Dialog ID: ', BTGetInternalDialogID ( TrafficFB ) );
    PrepareFileBlock := True;
  End;


  Function DoTraffic : Boolean;

  Var
    C         : Char;
    ReadCount : Word;
    CurOper   : OperationModeDef;


    Procedure BuildString ( Nr : LongInt; Var DataStr : String );

    Var
      I  : Word;
      St : Array [1..4] Of String [12];

    Begin
      Str ( Nr:12, St [1] );
      St [2] := '            ';
      For I := 1 To 12 Do Begin
        St [2] [I] := St [1] [13 - I];
      End;
      Str ( RandomMax - Nr:12, St [3] );
      Str ( Nr Mod 10 : 12 , St [4] );

      DataStr := St [2] + St [1] + St [3] + St [4];
    End;


    Function GetKey ( Var DataStr : String; KeyNr : Integer ) : String;

    Begin
      GetKey := '';
      Case KeyNr Of
        1: GetKey := Copy ( DataStr, 13, 12 );
        2: GetKey := Copy ( DataStr, 1, 12 );
        3: GetKey := Copy ( DataStr, 25, 12 );
        4: GetKey := Copy ( DataStr, 37, 12 );
      End; {Case}
    End;


    Function AddRecord : Integer;

    Var
      I          : Word;
      RefNr      : LongInt;
      TrafficRec : TrafficRecDef;


    Begin
      TrafficRec.Null := 0;
      BuildString ( Succ (Random (RandomMax)), TrafficRec.S );
      FillChar ( TrafficRec.Fill, SizeOf (TrafficRec.Fill), 0 );
      BTLockFileBlock ( TrafficFB );
      AddRecord := BTIsamErrorClass;
      If Not IsamOK Then Exit;
      If BTKeyExists ( TrafficFB, 1, 0, GetKey ( TrafficRec.S, 1 ) )
          Then Begin
        BTUnLockFileBlock ( TrafficFB );
        If IsamOK Then Begin
          AddRecord := -1;
        End Else Begin
          AddRecord := BTIsamErrorClass;
        End;
        Exit;
      End;
      BTAddRec ( TrafficFB, RefNr, TrafficRec );
      If Not IsamOK Then Begin
        AddRecord := BTIsamErrorClass;
        BTUnLockFileBlock ( TrafficFB );
        If Not IsamOK Then Begin
          AddRecord := BTIsamErrorClass;
        End;
        Exit;
      End;
      For I := 1 To 4 Do Begin
        BTAddKey ( TrafficFB, I, RefNr,  GetKey ( TrafficRec.S, I ) );
        If Not IsamOK Then Begin
          AddRecord := BTIsamErrorClass;
          BTUnLockFileBlock ( TrafficFB );
          If Not IsamOK Then Begin
            AddRecord := BTIsamErrorClass;
          End;
          Exit;
        End;
      End;
      BTUnLockFileBlock ( TrafficFB );
      AddRecord := BTIsamErrorClass;
    End;


    Function GetRecord : Integer;

    Var
      RefNr      : LongInt;
      TrafficRec : TrafficRecDef;
      MyKey      : IsamKeyStr;
      MyKeyNr    : Word;

    Begin
      BuildString ( Succ (Random (RandomMax)), TrafficRec.S );
      BTReadLockFileBlock ( TrafficFB );
      GetRecord := BTIsamErrorClass;
      If Not IsamOK Then Exit;
      MyKeyNr := Succ (Random (4));
      MyKey := GetKey ( TrafficRec.S, MyKeyNr );
      RefNr := Succ (Random (RandomMax));

      BTSearchKeyAndRef ( TrafficFB, MyKeyNr, RefNr, MyKey );
      If Not IsamOK Then Begin
        GetRecord := BTIsamErrorClass;
        BTUnLockFileBlock ( TrafficFB );
        If Not IsamOK Then Begin
          GetRecord := BTIsamErrorClass;
        End;
        Exit;
      End;
      BTGetRec ( TrafficFB, RefNr, TrafficRec, False );
      GetRecord := BTIsamErrorClass;
      BTUnLockFileBlock ( TrafficFB );
      If Not IsamOK Then Begin
        GetRecord := BTIsamErrorClass;
      End;
    End;


  Begin
    DoTraffic := False;
    ReadCount := 0;
    CurOper := OperationMode;
    CheckBreak := False;
    C := #0;
    Repeat
      If OperationMode = Both Then Begin
        If ReadCount >= NrOfReadsEachWrite Then Begin
          CurOper := WriteOnly;
          ReadCount := 0;
        End Else Begin
          CurOper := ReadOnly;
          Inc (ReadCount);
        End;
      End;
      Case CurOper Of
        WriteOnly : Begin
          Case AddRecord Of
            -1 : Write ( 'O' );
             0 : Write ( ':' );
             2 : Write ( 'X' );
            Else Exit;
          End; {Case}
        End;
        ReadOnly : Begin
          Case GetRecord Of
             0 : Write ( '.' );
             1 : Write ( 'o' );
             2 : Write ( 'x' );
            Else Exit;
          End; {Case}
        End;
      End; {Case}
      IsamDelay ( DelayTime );
      If KeyPressed Then C := ReadKey;
    Until C = #3;
    DoTraffic := True;
  End;


  Var
    SaveExitProc : Pointer;

  {$F+}
  Procedure TrafficExitProc;

  Begin
    If Not IsamOK Then Begin
      Writeln;
      Writeln ( 'IsamError: ', IsamError );
    End;
    ExitProc := SaveExitProc;
  End;


Begin
  ClrScr;

  If BTNoNetCompiled Then Begin
    Writeln;
    WriteLn('This program is for the network version of B-Tree Filer only');
    WriteLn('Be sure that at least one network model is defined in BTDEFINE.INC');
    Halt;
  End;

  If Not GetParams Then Begin
    ShowParams;
    Halt;
  End;
  SaveExitProc := ExitProc;
  ExitProc := @TrafficExitProc;
  If Not PrepareFileBlock Then Halt;

  If DoTraffic Then Begin
    BTCloseFileBlock ( TrafficFB );
    If IsamOK Then BTExitIsam;
  End;
End.
