(**************************************************************)
(*      B-Tree Isam Record Converting Ver 5.41                *)
(*   Copyright (C) 1988-1991 Dipl.Math. Ralf Nagel            *)
(*   Copyright (C) 1991-1993 ENZ EDV-Beratung GmbH            *)
(*                All rights reserved                         *)
(*   Modified and used under license by TurboPower Software   *)
(**************************************************************)

{--Conditional defines and compiler options}
  {$I BTDefine.Inc}
  {$F-,V-,B-,S-,I-,R-}
  {$IFDEF CanAllowOverlays}
    {$O+,F+}
  {$ENDIF}
  {$IFDEF CanSetOvrflowCheck}
    {$Q-}
  {$ENDIF}


Unit FixToVar;

Interface

Uses
  Filer, {!!.TP}
  Reorg,
  VReorg;

  Procedure FixToVarFileBlock ( FBlName      : IsamFileBlockName;
                                DatSLenFix   : LongInt;
                                DatSLenVar   : LongInt;
                                NumberOfKeys : Word;
                                IID          : IsamIndDescr;
                                FuncBuildKey : Pointer );
  {-Builds a variable record length fileblock out of a fixed}


Implementation

{$IFDEF XXFPlusOptXX}
  {$UNDEF XXFPlusOptXX}
{$ENDIF}
{$IFOPT F+}
  {$DEFINE XXFPlusOptXX}
{$ENDIF}
{$F+}
  Function IsamChangeDatSNoChange ( Var DatSOld; Var DatSNew; Var Len : Word )
      : Boolean;

  Begin
    IsamChangeDatSNoChange := True;
    Move ( DatSOld, DatSNew, Len );
  End;


  Function IsamChangeDatSElongateCheckZ ( Var DatSOld; Var DatSNew; Len : Word )
      : Boolean;

  Type
    AllArr = Array [0..0] Of Byte;

  Var
    Null : LongInt;

  Begin
    Null := 0;
    Move ( DatSOld, DatSNew, Len );
    Move ( Len, AllArr (DatSNew) [Len], SizeOf (Len) );
    Move ( Null, AllArr (DatSNew) [Len + SizeOf (Word)],
        SizeOf (LongInt) ) ;
    IsamChangeDatSElongateCheckZ := LongInt (DatSOld) = LongInt (0);
  End;
{$IFNDEF XXFPlusOptXX}
  {$F-}
{$ELSE}
  {$UNDEF XXFPlusOptXX}
{$ENDIF}


  Procedure FixToVarFileBlock ( FBlName      : IsamFileBlockName;
                                DatSLenFix   : LongInt;
                                DatSLenVar   : LongInt;
                                NumberOfKeys : Word;
                                IID          : IsamIndDescr;
                                FuncBuildKey : Pointer );

  Var
    IIDDummy       : IsamIndDescr;
    DatSLenEmulVar : LongInt;
    MaxDiffBytes   : Word;

  Begin
    DatSLenEmulVar := DatSLenFix + SizeOf (Word) + SizeOf (LongInt);
    ReorgFileBlock ( FBlName, DatSLenEmulVar,
        0, IIDDummy, DatSLenFix, Nil, @IsamChangeDatSElongateCheckZ );
    If Not IsamOK Then Exit;
    If DatSLenVar > DatSLenEmulVar Then Begin
      MaxDiffBytes := DatSLenVar - DatSLenEmulVar;
    End Else Begin
      MaxDiffBytes := 0;
    End;
    ReorgVFileBlock ( FBlName, DatSLenVar, NumberOfKeys, IID, DatSLenEmulVar,
        MaxDiffBytes, FuncBuildKey, @IsamChangeDatSNoChange );
  End;


{$IFDEF InitAllUnits}
Begin
{$ENDIF}
End.
