(**************************************************************)
(*   B-Tree Isam Variable Records Rebuild Ver 5.41            *)
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


Unit VRebuild;


Interface

Uses
  Filer, {!!.TP}
  VReorg;

  Procedure RebuildVFileBlock ( FBlName      : IsamFileBlockName;
                                DatSLen      : LongInt;
                                NumberOfKeys : Word;
                                IID          : IsamIndDescr;
                                FuncBuildKey : Pointer );
    {-Rebuilds a variable record length fileblocks data and index structure}


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
    If LongInt (DatSOld) = LongInt (0) Then Begin
      Move ( DatSOld, DatSNew, Len );
      IsamChangeDatSNoChange := True;
    End Else Begin
      IsamChangeDatSNoChange := False;
    End;
  End;
{$IFNDEF XXFPlusOptXX}
  {$F-}
{$ELSE}
  {$UNDEF XXFPlusOptXX}
{$ENDIF}


  Procedure RebuildVFileBlock ( FBlName      : IsamFileBlockName;
                                DatSLen      : LongInt;
                                NumberOfKeys : Word;
                                IID          : IsamIndDescr;
                                FuncBuildKey : Pointer );

  Begin
    ReorgVFileBlock ( FBlName, DatSLen, NumberOfKeys, IID, DatSLen, 0,
        FuncBuildKey, @IsamChangeDatSNoChange );
  End;


{$IFDEF InitAllUnits}
Begin
{$ENDIF}
End.
