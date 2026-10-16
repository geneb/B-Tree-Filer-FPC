(**************************************************************)
(*        B-Tree Isam Reorg Utility Ver 5.41                  *)
(*   Copyright (C) 1988-1991 Dipl.Math. Ralf Nagel            *)
(*   Copyright (C) 1991-1993 ENZ EDV-Beratung GmbH            *)
(*                All rights reserved                         *)
(*   Modified and used under license by TurboPower Software   *)
(**************************************************************)

{--Conditional defines and compiler options}
  {$I btdefine.inc}
  {$F-,V-,B-,S-,I-,R-}
    {$Q-}


Unit Reorg;


Interface

Uses
  BaseSupp,
  Filer; {!!.TP}

Type
  ReorgBuildKeyFunc = Function ( Var DatS; KeyNr : Word ) : IsamKeyStr;
    {-Type of the routine passed in FuncBuildKey}
  ReorgChangeDatSFunc = Function ( Var DatSOld;
                                   Var DatSNew;
                                       Len     : Word ) : Boolean;
    {-Type of the routine passed in ProcChangeDatS}
  ReorgReXUserProc = Procedure (     KeyNr   : Word;
                                     DatSNrR,
                                     DatSNrW : LongInt;
                                 Var DatS;
                                     Len     : Word );
    {-Type of the routine passed in IsamReXUserProcPtr}

  Procedure ReorgFileBlock ( FBlName        : IsamFileBlockName;
                             DatSLen        : LongInt;
                             NumberOfKeys   : Word;
                             IID            : IsamIndDescr;
                             DatSLenOld     : LongInt;
                             FuncBuildKey   : Pointer;
                             ProcChangeDatS : Pointer );
    {-Reorganizes a fixed record length fileblocks data and index structure}


Implementation

  Procedure ReorgFileBlock ( FBlName        : IsamFileBlockName;
                             DatSLen        : LongInt;
                             NumberOfKeys   : Word;
                             IID            : IsamIndDescr;
                             DatSLenOld     : LongInt;
                             FuncBuildKey   : Pointer;
                             ProcChangeDatS : Pointer );

  Var
    F                : IsamFile;
    FNameTemp,
    FNameD,
    FNameI,
    FNameS           : IsamFileBlockName;
    IFBPtr           : IsamFileBlockPtr;
    BufPtrOld,
    BufPtrNew        : ^Byte;
    DLenWOld,
    DLenWNew         : Word;
    L,
    NrOfRecs,
    RefNr,
    DatSRead,
    DatSWritten      : LongInt;
    IKS              : IsamKeyStr;
    MessageFileOpened,
    ExtraSaveDirUsed : Boolean;
    MessageFile      : Text;
    LPtrOld,
    LPtrNew          : ^LongInt;
    IORes,
    I, J             : Integer;


    {-The user routines are called through procedure types; formerly
      inline machine code (call far dword ptr [bp+UserRoutine])}
    Function BuildKey (     UserRoutine : Pointer;
                        Var DatS;
                            KeyNr       : Word ) : IsamKeyStr;

    Begin
      BuildKey := ReorgBuildKeyFunc (UserRoutine) ( DatS, KeyNr );
    End;


    Function ChangeDatS (     UserRoutine : Pointer;
                          Var DatSOld;
                          Var DatSNew;
                              Len         : Word ) : Boolean;

    Begin
      ChangeDatS := ReorgChangeDatSFunc (UserRoutine) ( DatSOld, DatSNew,
          Len );
    End;


    Procedure ReXUserRoutine (     UserRoutine : Pointer;
                                   KeyNr       : Word;
                                   DatSNrR     : LongInt;
                                   DatSNrW     : LongInt;
                               Var DatS;
                                   Len         : Word );

    Begin
      ReorgReXUserProc (UserRoutine) ( KeyNr, DatSNrR, DatSNrW, DatS, Len );
    End;


    Procedure UnDo ( Error : Integer );

    Var
      Dummy : Integer;

    Begin
      IsamClose ( F );
      FreeMem ( BufPtrOld, DLenWOld );
      FreeMem ( BufPtrNew, DLenWNew );
      BTCloseFileBlock ( IFBPtr );
      If MessageFileOpened Then Close ( MessageFile );
      Dummy := IOResult;
      IsamAssign ( F, IsamForceExtension ( FNameI, IxExtension ) );
      IsamDelete ( F );
        {-Abort, so destroy index file}
      IsamOK := False;
      IsamError := Error;
    End;


    Procedure DumpDataSet;

    Var
      CPtr : ^Char;
      W    : Word;

    Begin
      CPtr := Addr ( BufPtrNew^ );
      For W := 1 To DLenWNew Do Begin
        Write ( MessageFile, CPtr^ );
        IORes := IOResult;
        If IORes <> 0 Then Exit;
        Inc (CPtr);
      End;
    End;


  Begin
    IsamClearOK;
    IsamExtractFileNames ( FBlName, FNameD, FNameTemp );
    IsamExtractFileNames ( FNameTemp, FNameI, FNameS );
    ExtraSaveDirUsed := FNameS <> FNameTemp;
    If Not ExtraSaveDirUsed Then Begin
      FNameS := FNameD;
    End;

    If (DatSLenOld > LongInt ( 65535 )) Or (DatSLen > LongInt ( 65535 ))
        Then Begin
      IsamOK := False;
      IsamError := 10412;
      Exit;
    End;

    If IsamExists ( IsamForceExtension ( FNameS, SavExtension ) ) And
        IsamExists ( IsamForceExtension ( FNameD, DatExtension ) )
        Then Begin
      IsamOK := False;
      IsamError := 10465;
      Exit;
    End;

    IsamAssign ( F, IsamForceExtension ( FNameD, DatExtension ) );
    IsamRename ( F, IsamForceExtension ( FNameS, SavExtension ) );
    If Not IsamOK Then Begin
      If IsamError = 10140 Then Begin
        IsamError := 10399;
        Exit;
      End;
      If Not IsamExists ( IsamForceExtension ( FNameS, SavExtension ) )
          Then Begin
        If Not ExtraSaveDirUsed Then Begin
          IsamError := 10410;
          Exit;
        End;
        IsamClearOK;
        IsamAssign ( F, IsamForceExtension ( FNameI, IxExtension ) );
        IsamDelete ( F );
        IsamClearOK;
        IsamCopyFile ( IsamForceExtension ( FNameD, DatExtension ),
            IsamForceExtension ( FNameS, SavExtension ), True );
        If Not IsamOK Then Exit;
      End;
    End;

    BTCreateFileBlock ( FNameD + ';' + FNameI, DatSLen, NumberOfKeys, IID );
    If Not IsamOK Then Exit;
    BTOpenFileBlock ( IFBPtr, FNameD + ';' + FNameI, False, False, False,
        False );
    If Not IsamOK Then Exit;

    DLenWOld := ILI (DatSLenOld).Lo;
    If MaxAvail < DatSLenOld Then Begin
      BTCloseFileBlock ( IFBPtr );
      IsamOK := False;
      IsamError := 10411;
      Exit;
    End;
    GetMem ( BufPtrOld, DLenWOld );
    LPtrOld := Addr ( BufPtrOld^ );
    DLenWNew := ILI (DatSLen).Lo;
    If MaxAvail < DatSLen Then Begin
      FreeMem ( BufPtrOld, DLenWOld );
      BTCloseFileBlock ( IFBPtr );
      IsamOK := False;
      IsamError := 10411;
      Exit;
    End;
    GetMem ( BufPtrNew, DLenWNew );
    LPtrNew := Addr ( BufPtrNew^ );
    MessageFileOpened := False;

    IsamAssign ( F, IsamForceExtension ( FNameS, SavExtension ) );
    IsamReset ( F, False, False );
    If Not IsamOK Then Begin
      UnDo ( IsamError );
      Exit;
    End;
    IsamBlockRead ( F, BufPtrOld^, DLenWOld );
    If Not IsamOK Then Begin
      UnDo ( IsamError );
      Exit;
    End;
    IsamBlockRead ( F, BufPtrOld^, DLenWOld );
    DatSRead := LongInt (0);
    DatSWritten := LongInt (0);

    While IsamOK Do Begin
      Inc (DatSRead);
      If ChangeDatS ( ProcChangeDatS, BufPtrOld^, BufPtrNew^, DLenWOld )
          Then Begin
        BTAddRec ( IFBPtr, RefNr, BufPtrNew^ );
        If Not IsamOK Then Begin
          UnDo ( IsamError );
          Exit;
        End;
        Inc (DatSWritten);
      End;
      If IsamReXUserProcPtr <> Nil Then Begin
        ReXUserRoutine ( IsamReXUserProcPtr, 0, DatSRead, DatSWritten,
            BufPtrNew^, DLenWNew );
        If Not IsamOK Then Begin
          UnDo ( 10460 );
          Exit;
        End;
      End;
      IsamClearOK;
      IsamBlockRead ( F, BufPtrOld^, DLenWOld );
    End;

    If IsamError <> 10070 Then Begin
      UnDo ( IsamError );
      Exit;
    End Else Begin
      IsamClearOK;
    End;
    BTFlushFileBlock ( IFBPtr );
    If IsamOK Then IsamClose ( F );
    If IsamOK Then IsamDelete ( F );
    If Not IsamOK Then Begin
      UnDo ( IsamError );
      Exit;
    End;

    NrOfRecs := BTUsedRecs ( IFBPtr );
    For I := 1 To NumberOfKeys Do Begin
      DatSWritten := LongInt (0);
      For L := LongInt (1) To NrOfRecs Do Begin
        BTGetRec ( IFBPtr, L, BufPtrNew^, False );
        If Not IsamOK Then Begin
          UnDo ( IsamError );
          Exit;
        End;
        If LPtrNew^ = LongInt (0) Then Begin
          IKS := BuildKey ( FuncBuildKey, BufPtrNew^, I );
          If AddNullKeys Or (IKS <> '') Then Begin
            BTAddKey ( IFBPtr, I, L, IKS );
            If Not IsamOK Then Begin
              If IsamError = 10230 Then Begin
                If Not MessageFileOpened Then Begin
                  Assign ( MessageFile,
                      IsamForceExtension ( FNameD, MsgExtension ) );
                  Rewrite ( MessageFile );
                  IORes := IOResult;
                  If IORes <> 0 Then Begin
                    UnDo ( 9500 + IORes );
                    Exit;
                  End;
                  MessageFileOpened := True;
                End;
                Writeln ( MessageFile, 'Key ', IKS );
                IORes := IOResult;
                If IORes = 0 Then Begin
                  Writeln ( MessageFile, 'with Number ', I, ' duplicate!' );
                  IORes := IOResult;
                End;
                If IORes = 0 Then Begin
                  Writeln ( MessageFile, 'Dump follows' );
                  IORes := IOResult;
                End;
                If IORes = 0 Then Begin
                  DumpDataSet;
                  IORes := IOResult;
                End;
                If IORes = 0 Then Begin
                  Writeln ( MessageFile, '' );
                  IORes := IOResult;
                End;
                If IORes <> 0 Then Begin
                  UnDo ( 9500 + IORes );
                  Exit;
                End;
                For J := 1 To Pred (I) Do Begin
                  BTDeleteKey ( IFBPtr, J, L, BuildKey ( FuncBuildKey,
                      BufPtrNew^, J ) );
                End;
                BTDeleteRec ( IFBPtr, L );
              End Else Begin
                UnDo ( IsamError );
                Exit;
              End;
            End Else Begin
              Inc (DatSWritten);
            End;
          End;
          If IsamReXUserProcPtr <> Nil Then Begin
            ReXUserRoutine ( IsamReXUserProcPtr, I, L, DatSWritten,
                BufPtrNew^, DLenWNew );
            If Not IsamOK Then Begin
              UnDo ( 10460 );
              Exit;
            End;
          End;
        End;
      End;
    End;
    FreeMem ( BufPtrOld, DLenWOld );
    FreeMem ( BufPtrNew, DLenWNew );
    If MessageFileOpened Then Close ( MessageFile );
    I := IOResult;
    BTCloseFileBlock ( IFBPtr );
  End;


{$IFDEF InitAllUnits}
Begin
{$ENDIF}
End.
