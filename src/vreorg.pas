(**************************************************************)
(*    B-Tree Isam Variable Records Reorg Ver 5.41             *)
(*   Copyright (C) 1988-1991 Dipl.Math. Ralf Nagel            *)
(*   Copyright (C) 1991-1993 ENZ EDV-Beratung GmbH            *)
(*                All rights reserved                         *)
(*   Modified and used under license by TurboPower Software   *)
(**************************************************************)

{--Conditional defines and compiler options}
  {$I btdefine.inc}
  {$F-,V-,B-,S-,I-,R-}
    {$Q-}


Unit VReorg;

Interface

Uses
  BaseSupp,
  Filer, {!!.TP}
  Reorg,
  VRec;  {!!.TP}

Type
  VReorgChangeDatSFunc = Function ( Var DatSOld;
                                    Var DatSNew;
                                    Var Len     : Word ) : Boolean;
    {-Type of the routine passed in ProcChangeDatS; the types of
      FuncBuildKey and IsamReXUserProcPtr are defined in unit Reorg}


  Procedure ReorgVFileBlock ( FBlName        : IsamFileBlockName;
                              DatSLen        : LongInt;
                              NumberOfKeys   : Word;
                              IID            : IsamIndDescr;
                              DatSLenOld     : LongInt;
                              MaxDiffBytes   : Word;
                              FuncBuildKey   : Pointer;
                              ProcChangeDatS : Pointer );
    {-Reorganizes a variable record length fileblocks data and index structure}


Implementation

Const
  MaxNrOfVRecReorgReads = 2048;
    {-Assumes a minimum record length of 32 bytes for worst case}


  Procedure ReorgVFileBlock ( FBlName        : IsamFileBlockName;
                              DatSLen        : LongInt;
                              NumberOfKeys   : Word;
                              IID            : IsamIndDescr;
                              DatSLenOld     : LongInt;
                              MaxDiffBytes   : Word;
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
    BufLenOld,
    BufLenNew,
    CurRecLen,
    LastWriteLen     : Word;
    L,
    NrOfRecs,
    RefNr,
    RebRef,
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
                          Var Len         : Word ) : Boolean;

    Begin
      ChangeDatS := VReorgChangeDatSFunc (UserRoutine) ( DatSOld, DatSNew,
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


    Procedure UnDo ( Error : Integer; Free : Boolean );

    Var
      Dummy : Integer;

    Begin
      IsamClose ( F );
      If Free Then Begin
        FreeMem ( BufPtrOld, BufLenOld );
        FreeMem ( BufPtrNew, BufLenNew );
      End;
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
      For W := 1 To CurRecLen Do Begin
        Write ( MessageFile, CPtr^ );
        IORes := IOResult;
        If IORes <> 0 Then Exit;
        Inc (CPtr);
      End;
    End;


    Procedure DumpToMessageFile ( KeyRelated : Boolean );

    Begin
      If Not MessageFileOpened Then Begin
        Assign ( MessageFile,
            IsamForceExtension ( FNameD, MsgExtension ) );
        Rewrite ( MessageFile );
        IORes := IOResult;
        If IORes <> 0 Then Exit;
        MessageFileOpened := True;
      End;
      If KeyRelated Then Begin
        Writeln ( MessageFile, 'Key ', IKS );
        IORes := IOResult;
        If IORes <> 0 Then Exit;
        Writeln ( MessageFile, 'with Number ', I, ' duplicate!' );
        IORes := IOResult;
        If IORes <> 0 Then Begin
          UnDo ( IORes, True );
          Exit;
        End;
      End Else Begin
        Writeln ( MessageFile, 'Data not readable' );
        IORes := IOResult;
        If IORes <> 0 Then Exit;
      End;
      Writeln ( MessageFile, 'Dump follows' );
      IORes := IOResult;
      If IORes <> 0 Then Exit;
      DumpDataSet;
      IORes := IOResult;
      If IORes <> 0 Then Exit;
      Writeln ( MessageFile, '' );
      IORes := IOResult;
    End;


    Function AdjustBuffers : Boolean;

    Begin
      AdjustBuffers := False;
      If CurRecLen > BufLenOld Then Begin
        FreeMem ( BufPtrOld, BufLenOld );
        FreeMem ( BufPtrNew, BufLenNew );
        If MaxAvail < CurRecLen Then Exit;
        BufLenOld := CurRecLen;
        GetMem ( BufPtrOld, BufLenOld );
        LPtrOld := Addr ( BufPtrOld^ );
        If MaxAvail < (CurRecLen + MaxDiffBytes) Then Begin
          FreeMem ( BufPtrOld, BufLenOld );
          Exit;
        End;
        BufLenNew := CurRecLen + MaxDiffBytes;
        GetMem ( BufPtrNew, BufLenNew );
        LPtrNew := Addr ( BufPtrNew^ );
      End;
      AdjustBuffers := True;
    End;


  Begin
    IsamClearOK;
    IsamExtractFileNames ( FBlName, FNameD, FNameTemp );
    IsamExtractFileNames ( FNameTemp, FNameI, FNameS );
    ExtraSaveDirUsed := FNameS <> FNameTemp;
    If Not ExtraSaveDirUsed Then Begin
      FNameS := FNameD;
    End;

    If (DatSLenOld > LongInt ( MaxVariableRecLength ))
        Or (DatSLen > LongInt ( MaxVariableRecLength )) Then Begin
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
          IsamOK := False;
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

    BufLenOld := ILI (DatSLenOld).Lo;
    If MaxAvail < BufLenOld Then Begin
      BTCloseFileBlock ( IFBPtr );
      IsamOK := False;
      IsamError := 10411;
      Exit;
    End;
    GetMem ( BufPtrOld, BufLenOld );
    LPtrOld := Addr ( BufPtrOld^ );
    BufLenNew := BufLenOld + MaxDiffBytes;
    If MaxAvail < BufLenNew Then Begin
      FreeMem ( BufPtrOld, BufLenOld );
      BTCloseFileBlock ( IFBPtr );
      IsamOK := False;
      IsamError := 10411;
      Exit;
    End;
    GetMem ( BufPtrNew, BufLenNew );
    LPtrNew := Addr ( BufPtrNew^ );
    MessageFileOpened := False;

    IsamAssign ( F, IsamForceExtension ( FNameS, SavExtension ) );
    IsamReset ( F, False, False );
    If Not IsamOK Then Begin
      UnDo ( IsamError, True );
      Exit;
    End;

    RebRef := LongInt (0);
    DatSRead := LongInt (0);
    DatSWritten := LongInt (0);
    LastWriteLen := 0;
    Repeat
      BTGetVariableRecRebuilt ( F, Word (DatSLenOld), RebRef, True, BufPtrOld^,
          CurRecLen, MaxNrOfVRecReorgReads );
      If Not IsamOK Then Begin
        If (IsamError = 10415) Or (IsamError = 10070) Then Begin
          IsamClearOK;
          CurRecLen := Word (DatSLenOld);
          IsamGetBlock ( F, RebRef * CurRecLen, CurRecLen, BufPtrNew^ );
          If Not IsamOK Then Begin
            UnDo ( IsamError, True );
            Exit;
          End;
          DumpToMessageFile ( False );
          If IORes <> 0 Then Begin
            UnDo ( 9500 + IORes, True );
            Exit;
          End;
        End Else Begin
          UnDo ( IsamError, True );
          Exit;
        End;
      End Else Begin
        If CurRecLen <> 0 Then Begin
          If Not AdjustBuffers Then Begin
            UnDo ( 10411, False );
            Exit;
          End;
          BTGetVariableRecRebuilt ( F, Word (DatSLenOld), RebRef, False,
              BufPtrOld^, CurRecLen, MaxNrOfVRecReorgReads );
          If Not IsamOK Then Begin
            UnDo ( IsamError, True );
            Exit;
          End;
          Inc (DatSRead);
          If ChangeDatS ( ProcChangeDatS, BufPtrOld^, BufPtrNew^, CurRecLen )
              Then Begin
            BTAddVariableRec ( IFBPtr, RefNr, BufPtrNew^, CurRecLen );
            If Not IsamOK Then Begin
              UnDo ( IsamError, True );
              Exit;
            End;
            Inc (DatSWritten);
            LastWriteLen := CurRecLen;
          End;
          If IsamReXUserProcPtr <> Nil Then Begin
            ReXUserRoutine ( IsamReXUserProcPtr, 0, DatSRead, DatSWritten,
                BufPtrNew^, LastWriteLen );
            If Not IsamOK Then Begin
              UnDo ( 10460, True );
              Exit;
            End;
          End;
        End;
      End;
    Until CurRecLen = 0;

    If IsamOK Then BTFlushFileBlock ( IFBPtr );
    If IsamOK Then IsamClose ( F );
    If IsamOK Then IsamDelete ( F );
    If Not IsamOK Then Begin
      UnDo ( IsamError, True );
      Exit;
    End;

    NrOfRecs := BTUsedRecs ( IFBPtr );
    For I := 1 To NumberOfKeys Do Begin
      DatSRead := LongInt (0);
      DatSWritten := LongInt (0);
      For L := LongInt (1) To NrOfRecs Do Begin
        BTGetRec ( IFBPtr, L, BufPtrNew^, False );
        If Not IsamOK Then Begin
          UnDo ( IsamError, True );
          Exit;
        End;
        If LPtrNew^ = LongInt (0) Then Begin
          BTGetVariableRec ( IFBPtr, L, BufPtrNew^, CurRecLen );
          If Not IsamOK Then Begin
            UnDo ( IsamError, True );
            Exit;
          End;
          Inc (DatSRead);
          IKS := BuildKey ( FuncBuildKey, BufPtrNew^, I );
          If AddNullKeys Or (IKS <> '') Then Begin
            BTAddKey ( IFBPtr, I, L, IKS );
            If Not IsamOK Then Begin
              If IsamError = 10230 Then Begin
                DumpToMessageFile ( True );
                If IORes <> 0 Then Begin
                  UnDo ( 9500 + IORes, True );
                  Exit;
                End;
                For J := 1 To Pred (I) Do Begin
                  BTDeleteKey ( IFBPtr, J, L, BuildKey ( FuncBuildKey,
                      BufPtrNew^, J ) );
                End;
                BTDeleteVariableRec ( IFBPtr, L );
              End Else Begin
                UnDo ( IsamError, True );
                Exit;
              End;
            End Else Begin
              Inc (DatSWritten);
            End;
          End;
          If IsamReXUserProcPtr <> Nil Then Begin
            ReXUserRoutine ( IsamReXUserProcPtr, I, DatSRead, DatSWritten,
                BufPtrNew^, CurRecLen );
            If Not IsamOK Then Begin
              UnDo ( 10460, True );
              Exit;
            End;
          End;
        End;
      End;
    End;

    FreeMem ( BufPtrOld, BufLenOld );
    FreeMem ( BufPtrNew, BufLenNew );
    If MessageFileOpened Then Close ( MessageFile );
    I := IOResult;
    BTCloseFileBlock ( IFBPtr );
  End;


{$IFDEF InitAllUnits}
Begin
{$ENDIF}
End.
