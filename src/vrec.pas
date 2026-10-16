(**************************************************************)
(*      B-Tree Isam Variable Records Ver 5.41                 *)
(*   Copyright (C) 1987-1991 Dipl.Math. Ralf Nagel            *)
(*   Copyright (C) 1991-1993 ENZ EDV-Beratung GmbH            *)
(*                All rights reserved                         *)
(*   Modified and used under license by TurboPower Software   *)
(**************************************************************)

{--Conditional defines and compiler options}
  {$I btdefine.inc}
  {$F-,V-,B-,S-,I-,R-}
    {$Q-}


Unit VRec; {!!.TP}

InterFace

Uses
  BaseSupp,
  Filer; {!!.TP}

Const
  MaxVariableRecLength = $FFF0;

Var
  IsamVRecBufSize : Word;


  Function BTCreateVariableRecBuffer ( IFBPtr : IsamFileBlockPtr ) : Boolean;
    {-Create a variable record buffer for the fileblock with the greatest
      data record length of all variable record fileblocks}

  Procedure BTReleaseVariableRecBuffer;
    {-Release the variable record buffer}

  Function BTSetVariableRecBuffer ( Size : Word ) : Boolean;
    {-Create a variable record buffer with Size bytes as an alternative to
      CreateVariableRecBuffer}

  Procedure BTAddVariableRec (     IFBPtr : IsamFileBlockPtr;
                               Var RefNr  : LongInt;
                               Var Source;
                                   Len    : Word);
    {-Adds a record with variable length}

  Procedure BTDeleteVariableRec ( IFBPtr : IsamFileBlockPtr;
                                  RefNr  : LongInt );
    {-Deletes a record with variable length}

  Procedure BTPutVariableRec (     IFBPtr : IsamFileBlockPtr;
                                   RefNr  : LongInt;
                               Var Source;
                                   Len    : Word );
    {-Puts a record with variable length to its old place}

  Procedure BTGetVariableRecPart (     IFBPtr : IsamFileBlockPtr;
                                       RefNr  : LongInt;
                                   Var Dest;
                                   Var Len    : Word );
    {-Reads at maximum Len bytes of a variable record}

  Procedure BTGetVariableRec (     IFBPtr : IsamFileBlockPtr;
                                   RefNr  : LongInt;
                               Var Dest;
                               Var Len    : Word );
    {-Reads a variable record and returns the read number of bytes in Len}

  Procedure BTGetVRecPartReadOnly (     IFBPtr : IsamFileBlockPtr;
                                        RefNr  : LongInt;
                                    Var Dest;
                                    Var Len    : Word );
    {-Reads a variable record and returns the read number of bytes in Len;
      needs either a record lock or another lock, else will do a readlock}

  Procedure BTGetVRecReadOnly (     IFBPtr : IsamFileBlockPtr;
                                    RefNr  : LongInt;
                                Var Dest;
                                Var Len    : Word );
    {-Reads at maximum Len bytes of a variable record;
      needs either a record lock or another lock, else will do a readlock}

  Procedure BTGetVariableRecLength (     IFBPtr : IsamFileBlockPtr;
                                         RefNr  : LongInt;
                                     Var Len    : Word );
    {-Gets the length of a variable record and returns it in Len}

  Procedure BTGetVariableRecRebuilt ( Var F       : IsamFile;
                                          DatSLen : Word;
                                      Var RefNr   : LongInt;
                                          OnlyLen : Boolean;
                                      Var Dest;
                                      Var Len     : Word;
                                          MaxRecs : Word );
    {-Internal use only!
      Reads a variable record and returns the read number of bytes in Len}


Implementation

Const
  MaxVariableRecLengthM1 = MaxVariableRecLength - 1;

Type
  IsamVRecBuf    = Array [0..MaxVariableRecLengthM1] Of Byte;
  IsamVRecBufPtr = ^IsamVRecBuf;

Var
  IVRBPtr : IsamVRecBufPtr;


  Function CreateVariableRecBuffer ( S : Word ) : Boolean;

  Begin
    CreateVariableRecBuffer := False;
    If MaxAvail < S Then Exit;
    GetMem ( IVRBPtr, S );
    IsamVRecBufSize := S;
    CreateVariableRecBuffer := True;
  End;


  Function CreateVariableRecBufferIFB ( IFBPtr : IsamFileBlockPtr ) : Boolean;

  Begin
    CreateVariableRecBufferIFB := CreateVariableRecBuffer
        ( Word (ILI (IFBPtr^.DIDPtr^[0]^.LenRec).Lo) );
  End;


  Function BTCreateVariableRecBuffer ( IFBPtr : IsamFileBlockPtr ) : Boolean;
    {-Create a variable record buffer for the fileblock with the greatest
      data record length of all variable record fileblocks}
  Begin
    IsamClearOK;
    BTCreateVariableRecBuffer := CreateVariableRecBufferIFB ( IFBPtr );
  End;


  Procedure ReleaseVariableRecBuffer;

  Begin
    If IsamVRecBufSize <> 0 Then Begin
      FreeMem ( IVRBPtr, IsamVRecBufSize );
      IsamVRecBufSize := 0;
    End;
  End;


  Procedure BTReleaseVariableRecBuffer;
    {-Release the variable record buffer}
  Begin
    IsamClearOK;
    ReleaseVariableRecBuffer;
  End;


  Function BTSetVariableRecBuffer ( Size : Word ) : Boolean;
    {-Create a variable record buffer with Size bytes as an alternative to
      CreateVariableRecBuffer}
  Begin
    IsamClearOK;
    BTSetVariableRecBuffer := CreateVariableRecBuffer ( Size );
  End;


  Function AdjustVariableRecBuffer ( Size : Word ) : Boolean;

  Begin
    If IsamVRecBufSize < Size Then Begin
      ReleaseVariableRecBuffer;
      AdjustVariableRecBuffer := CreateVariableRecBuffer ( Size );
    End Else Begin
      AdjustVariableRecBuffer := True;
    End;
  End;


  Procedure IsamAddRestVarRec (     IFBPtr : IsamFileBlockPtr;
                                Var RefNr  : LongInt;
                                Var Source;
                                    Len    : Word);

  Var
    SPtr   : IsamVRecBufPtr;
    CPtr   : ^Word;
    LPtr   : ^LongInt;
    SetLen,
    Pos,
    Number : Word;
    Prev   : LongInt;

  Begin
    SetLen := Word ( ILI (IFBPtr^.DIDPtr^[0]^.LenRec).Lo ) - 7;
    Number := Len Div SetLen;
    If Number * SetLen <> Len Then Begin
      Inc (Number);
    End;
    Pos := Pred (Number) * SetLen;
    Prev := 0;
    CPtr := Addr ( IVRBPtr^ [Succ (SetLen)] );
    LPtr := Addr ( IVRBPtr^ [SetLen+3] );
    SPtr := Addr ( Source );
    While Number > 0 Do Begin
      IVRBPtr^ [0] := 1;
      If Prev = 0 Then Begin
        CPtr^ := Len-Pos;
      End Else Begin
        CPtr^ := SetLen;
      End;
      Move ( SPtr^ [Pos], IVRBPtr^ [1], CPtr^ );
      LPtr^ := Prev;
      BTAddRec ( IFBPtr, Prev, IVRBPtr^ [0] );
      If Not IsamOK Then Exit;
      Dec (Number);
      If Number <> 0 Then Pos := Pos-SetLen;
    End;
    RefNr := Prev;
  End;


  Procedure BTAddVariableRec (     IFBPtr : IsamFileBlockPtr;
                               Var RefNr  : LongInt;
                               Var Source;
                                   Len    : Word);
    {-Adds a record with variable length}
  Var
    S    : Word;
    SPtr : IsamVRecBufPtr;
    CPtr : ^Word;
    LPtr : ^LongInt;

  Begin
    IsamClearOK;
    S := Word ( ILI (IFBPtr^.DIDPtr^[0]^.LenRec).Lo );
    If Not AdjustVariableRecBuffer ( S ) Then Begin
      IsamOK := False;
      IsamError := 10040;
      Exit;
    End;
    SPtr := Addr (Source);
    CPtr := Addr (IVRBPtr^ [S-6]);
    LPtr := Addr (IVRBPtr^ [S-4]);
    If Len > (S-6) Then Begin
      IsamAddRestVarRec ( IFBPtr, RefNr, SPtr^ [S-6], Len-(S-6) );
      If Not IsamOK Then Exit;
      Len := S-6;
    End Else Begin
      RefNr := 0;
    End;
    Move ( SPtr^ [0], IVRBPtr^ [0], Len );
    CPtr^ := Len;
    LPtr^ := RefNr;
    BTAddRec ( IFBPtr, RefNr, IVRBPtr^ [0] );
  End;


  Procedure BTDeleteVariableRec ( IFBPtr : IsamFileBlockPtr;
                                  RefNr  : LongInt );
    {-Deletes a record with variable length}
  Var
    NextRefNr : LongInt;
    S         : Word;

  Begin
    IsamClearOK;
    S := ILI (IFBPtr^.DIDPtr^[0]^.LenRec).Lo;
    Repeat
      IsamGetBlock ( IFBPtr^.DatF, LongInt (S) * RefNr + LongInt (S-4),
                     SizeOf (LongInt), NextRefNr );
      If Not IsamOK Then Exit;
      BTDeleteRec ( IFBPtr, RefNr );
      If Not IsamOK Then Exit;
      RefNr := NextRefNr;
    Until NextRefNr = 0;
  End;


  Procedure BTPutVariableRec (     IFBPtr : IsamFileBlockPtr;
                                   RefNr  : LongInt;
                               Var Source;
                                   Len    : Word );
    {-Puts a record with variable length to its old place}
  Var
    S        : Word;
    DelRefNr,
    AddRefNr : LongInt;
    SPtr     : IsamVRecBufPtr;
    CPtr     : ^Word;
    LPtr     : ^LongInt;

  Begin
    IsamClearOK;
    S := Word (ILI (IFBPtr^.DIDPtr^[0]^.LenRec).Lo);
    If Not AdjustVariableRecBuffer ( S ) Then Begin
      IsamOK := False;
      IsamError := 10040;
      Exit;
    End;
    SPtr := Addr (Source);
    CPtr := Addr (IVRBPtr^ [S-6]);
    LPtr := Addr (IVRBPtr^ [S-4]);
    If Len > (S-6) Then Begin
      IsamAddRestVarRec ( IFBPtr, AddRefNr, SPtr^ [S-6], Len - (S-6) );
      If Not IsamOK Then Exit;
      Len := S-6;
    End Else Begin
      AddRefNr := 0;
    End;
    IsamGetBlock ( IFBPtr^.DatF, LongInt (S) * RefNr + LongInt (S-4),
                   SizeOf (LongInt), DelRefNr );
    If Not IsamOK Then Exit;
    If DelRefNr <> 0 Then Begin
      BTDeleteVariableRec ( IFBPtr, DelRefNr );
      If Not IsamOK Then Exit;
    End;
    Move ( SPtr^ [0], IVRBPtr^ [0], Len );
    CPtr^ := Len;
    LPtr^ := AddRefNr;
    BTPutRec ( IFBPtr, RefNr, IVRBPtr^ [0], False );
  End;


  Procedure IsamGetVariableRecPart (     IFBPtr : IsamFileBlockPtr;
                                         RefNr  : LongInt;
                                     Var Dest;
                                     Var Len    : Word;
                                         UseRO  : Boolean );

  Var
    Err  : Integer;
    RL   : Boolean;


    Function GetVRec : Boolean;

    Var
      SecSize    : Word;
      DestPos    : Word;
      SrcPos     : Word;
      LeftToRead : Word;
      LenToMove  : Word;
      DestPtr    : IsamVRecBufPtr;
      LenPtr     : ^Word;
      RefPtr     : ^LongInt;

    Begin
      GetVRec := True;
      SecSize := Word (ILI(IFBPtr^.DIDPtr^[0]^.LenRec).Lo);
      LenPtr := @IVRBPtr^ [SecSize-6]; {Points to actual length of record
                                          section}
      RefPtr := @IVRBPtr^ [SecSize-4]; {Points to next segment reference}
      DestPtr := @Dest;                  {Points to base of output area}
      DestPos := 0;                      {Position of data in output area}
      SrcPos := 0;                       {Position of data in input section}
      RefPtr^ := RefNr;                  {First section to read}
      LeftToRead := Len;                 {Bytes left to read}
      Len := 0;                          {In case we exit with error}

      Repeat
      {--Read the next section}
        If (DestPos = 0) And UseRO Then Begin
          BTGetRecReadOnly ( IFBPtr, RefPtr^, IVRBPtr^ [0] );
          If IsamError = 10205 Then Begin
            GetVRec := False;
            IsamClearOK;
          End;
        End Else Begin
          BTGetRec ( IFBPtr, RefPtr^, IVRBPtr^ [0], True );
        End;
        If Not IsamOK Then Exit;

      {--Transfer section to destination}
        If LenPtr^ > LeftToRead Then Begin
          LenToMove := LeftToRead;
        End Else Begin
          LenToMove := LenPtr^;
        End;
        Move ( IVRBPtr^ [SrcPos], DestPtr^ [DestPos], LenToMove );

      {--Move to next area of destination}
        Inc ( DestPos, LenToMove );
        Dec ( LeftToRead, LenToMove );

      {--Data starts at position 1 for all sections but the first}
        SrcPos := 1;
      Until (RefPtr^ = 0) Or (LeftToRead = 0);

    {--Return the actual length}
      Len := DestPos;
    End;


  Begin
    IsamClearOK;
    If Not AdjustVariableRecBuffer
        ( Word (ILI (IFBPtr^.DIDPtr^[0]^.LenRec).Lo) ) Then Begin
      IsamOK := False;
      IsamError := 10040;
      Exit;
    End;
    RL := True;
    If BTIsNetFileBlock ( IFBPtr ) Then Begin
      RL := BTFileBlockIsReadLocked ( IFBPtr )
          Or BTFileBlockIsLocked ( IFBPtr ) Or BTRecIsLocked ( IFBPtr, RefNr );
      If Not RL Then BTReadLockFileBlock ( IFBPtr );
      If Not IsamOK Then Exit;
    End;
    If Not GetVRec And IsamOK Then Begin
      IsamOK := False;
      IsamError := 10205;
    End;
    If Not RL Then Begin
      Err := IsamError;
      BTUnLockFileBlock ( IFBPtr );
      If IsamOK Then Begin
        IsamError := Err;
        IsamOK := IsamError = 0;
      End;
    End;
  End;


  Procedure BTGetVariableRecPart (     IFBPtr : IsamFileBlockPtr;
                                       RefNr  : LongInt;
                                   Var Dest;
                                   Var Len    : Word );
    {-Reads at maximum Len bytes of a variable record}
  Begin
    IsamGetVariableRecPart ( IFBPtr, RefNr, Dest, Len, False );
  End;


  Procedure BTGetVariableRec (     IFBPtr : IsamFileBlockPtr;
                                   RefNr  : LongInt;
                               Var Dest;
                               Var Len    : Word );
    {-Reads a variable record and returns the read number of bytes in Len}
  Begin
    Len := MaxVariableRecLength;
    IsamGetVariableRecPart ( IFBPtr, RefNr, Dest, Len, False );
  End;


  Procedure BTGetVRecPartReadOnly (     IFBPtr : IsamFileBlockPtr;
                                        RefNr  : LongInt;
                                    Var Dest;
                                    Var Len    : Word );
    {-Reads a variable record and returns the read number of bytes in Len;
      needs either a record lock or another lock, else will do a readlock}
  Begin
    IsamGetVariableRecPart ( IFBPtr, RefNr, Dest, Len, True );
  End;


  Procedure BTGetVRecReadOnly (     IFBPtr : IsamFileBlockPtr;
                                    RefNr  : LongInt;
                                Var Dest;
                                Var Len    : Word );
    {-Reads at maximum Len bytes of a variable record;
      needs either a record lock or another lock, else will do a readlock}
  Begin
    Len := MaxVariableRecLength;
    IsamGetVariableRecPart ( IFBPtr, RefNr, Dest, Len, True );
  End;


  Procedure BTGetVariableRecLength (     IFBPtr : IsamFileBlockPtr;
                                       RefNr  : LongInt;
                                   Var Len    : Word );
    {-Gets the length of a variable record and returns it in Len}
  Var
    RL  : Boolean;
    S   : Word;
    Err : Integer;
    Inf : Record
      L         : Word;
      NextRefNr : LongInt;
    End;

  Begin
    IsamClearOK;
    RL := True;
    If BTIsNetFileBlock (IFBPtr) Then Begin
      RL := BTFileBlockIsReadLocked (IFBPtr) Or BTFileBlockIsLocked (IFBPtr);
      If Not RL Then BTReadLockFileBlock ( IFBPtr );
      If Not IsamOK Then Exit;
    End;
    S := Word ( ILI (IFBPtr^.DIDPtr^[0]^.LenRec).Lo );
    If Not AdjustVariableRecBuffer ( S ) Then Begin
      IsamOK := False;
      IsamError := 10040;
      Exit;
    End;
    Len := 0;
    Repeat
      IsamGetBlock ( IFBPtr^.DatF, LongInt (S) * RefNr + LongInt (S-6),
                     SizeOf (Inf), Inf );
      If Not IsamOK Then Begin
        If Not RL Then Begin
          Err := IsamError;
          BTUnLockFileBlock ( IFBPtr );
          If IsamOK Then Begin
            IsamError := Err;
            IsamOK := IsamError = 0;
          End;
        End;
        Exit;
      End;
      With Inf Do Begin
        If Len > MaxVariableRecLength - L Then Begin
          Err := 10415;
          BTUnLockFileBlock ( IFBPtr );
          If IsamOK Then Begin
            IsamError := Err;
            IsamOK := False;
          End;
          Exit;
        End;
        RefNr := NextRefNr;
        Inc (Len, L);
      End;
    Until RefNr = 0;
    If Not RL Then BTUnLockFileBlock ( IFBPtr );
  End;


  Procedure BTGetVariableRecRebuilt ( Var F       : IsamFile;
                                          DatSLen : Word;
                                      Var RefNr   : LongInt;
                                          OnlyLen : Boolean;
                                      Var Dest;
                                      Var Len     : Word;
                                          MaxRecs : Word );
    {-Internal use only!
      Reads a variable record and returns the read number of bytes in Len}
  Var
    Pos,
    NrOfRecs,
    S        : Word;
    DPtr     : IsamVRecBufPtr;
    CPtr     : ^Word;
    LPtr     : ^LongInt;
    LRef,
    TRef     : LongInt;


    Function FindNextValidRecStart ( Var NRef : LongInt ) : Boolean;

    Var
      TILI : LongInt;
      LPtr : ^LongInt;

    Begin
      FindNextValidRecStart := False;
      LPtr := Addr (IVRBPtr^ [0]);
      TILI := NRef * LongInt (DatSLen);
      Repeat
        TILI := TILI + LongInt (DatSLen);
        Inc (NRef);
        IsamGetBlock ( F, TILI, SizeOf (LongInt), IVRBPtr^ [0] );
        If Not IsamOK Then Begin
          If IsamError = 10070 Then IsamClearOK;
          Exit;
        End;
      Until LPtr^ = 0;
      FindNextValidRecStart := True;
    End;


  Begin
    IsamClearOK;
    If Not AdjustVariableRecBuffer ( DatSLen ) Then Begin
      IsamOK := False;
      IsamError := 10040;
      Exit;
    End;
    TRef := RefNr;
    If Not FindNextValidRecStart ( TRef ) Then Begin
      Len := 0;
      Exit;
    End;
    S := DatSLen;
    DPtr := Addr (Dest);
    CPtr := Addr (IVRBPtr^ [S-6]);
    LPtr := Addr (IVRBPtr^ [S-4]);
    IsamGetBlock ( F, TRef * LongInt (DatSLen), DatSLen, IVRBPtr^ [0] );
    If Not IsamOK Then Begin
      If IsamError = 10070 Then RefNr := TRef;
      Exit;
    End;
    If Not OnlyLen Then Move ( IVRBPtr^ [0], DPtr^ [0], CPtr^ );
    Pos := CPtr^;
    NrOfRecs := 0;
    While (LPtr^ <> 0) And (NrOfRecs < MaxRecs) Do Begin
      Inc (NrOfRecs);
      LRef := LPtr^;
      IsamGetBlock ( F, LRef * LongInt (DatSLen), DatSLen, IVRBPtr^ [0] );
      If Not IsamOK Then Begin
        If IsamError = 10070 Then RefNr := TRef;
        Exit;
      End;
      If (Pos > MaxVariableRecLength - CPtr^) Or (LRef = LPtr^) Then Begin
        IsamOK := False;
        IsamError := 10415;
        RefNr := TRef;
        Exit;
      End;
      If Not OnlyLen Then Move ( IVRBPtr^ [1], DPtr^ [Pos], CPtr^ );
      Inc (Pos, CPtr^);
    End;
    If (NrOfRecs >= MaxRecs) Or (Pos = 0) Then Begin
      IsamOK := False;
      IsamError := 10415;
      RefNr := TRef;
      Exit;
    End;
    Len := Pos;
    If Not OnlyLen Then RefNr := TRef;
  End;


Begin
  IsamVRecBufSize := 0;
End.
