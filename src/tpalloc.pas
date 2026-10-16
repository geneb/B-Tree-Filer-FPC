{*********************************************************}
{*                   TPALLOC.PAS 5.41                    *}
{*        Copyright (c) TurboPower Software 1989.        *}
{*                 All rights reserved.                  *}
{*********************************************************}

{Free Pascal port:
 Under MS-DOS this unit managed the Turbo Pascal free list directly in order
 to allocate blocks larger than 64K, and worked with segment:offset pointers.
 Windows and Linux use a flat address space where GetMem can allocate blocks
 of any size, so the routines below are simple wrappers. Linear addresses
 are of type PtrInt (LongInt under MS-DOS) since pointers have 64 bits on
 64 bit systems. The SegOfs type has been removed.}

{$I btdefine.inc}
{$S-,R-,I-,V-,B-}

unit TpAlloc;
  {-Routines for allocating/deallocating blocks of memory larger than 64K}

interface

  {----- memory management routines -----}

procedure HugeGetMem(var Pt; Bytes : LongInt);
  {-Allocate a block of memory of size Bytes and store pointer to it in
    Pt. Pt is nil if Bytes > MaxAvail}

procedure HugeFreeMem(var Pt; Bytes : LongInt);
  {-Deallocate a block of memory of size Bytes pointed to by Pt, a pointer
    variable. Pt is set to nil on Exit. Does nothing if Pt is nil.}

  {----- pointer manipulation routines -----}

function Linear(P : Pointer) : PtrInt;
  {-Converts a pointer to a linear address to allow differences in addresses
    to be calculated.}

function LinearToPointer(L : PtrInt) : Pointer;
  {-Return linear address L as a pointer}

function PtrDiff(P1, P2 : Pointer) : PtrInt;
  {-Return the number of bytes between P1^ and P2^}

function Normalized(P : Pointer) : Pointer;
  {-Return P as a normalized pointer; all pointers are normalized in a flat
    address space, so P is returned unchanged}

  {=============================================================}

implementation

uses
  BaseSupp;

  function Linear(P : Pointer) : PtrInt;
  begin
    Linear := PtrInt(P);
  end;

  function LinearToPointer(L : PtrInt) : Pointer;
  begin
    LinearToPointer := Pointer(L);
  end;

  function PtrDiff(P1, P2 : Pointer) : PtrInt;
  begin
    PtrDiff := Abs(Linear(P1)-Linear(P2));
  end;

  function Normalized(P : Pointer) : Pointer;
  begin
    Normalized := P;
  end;

  procedure HugeGetMem(var Pt; Bytes : LongInt);
  var
    ThisP : Pointer absolute Pt;
  begin
    ThisP := nil;
    if (Bytes <= 0) or (Bytes > MaxAvail) then
      Exit;
    GetMem(ThisP, Bytes);
  end;

  procedure HugeFreeMem(var Pt; Bytes : LongInt);
  var
    ThisP : Pointer absolute Pt;
  begin
    if (ThisP = nil) or (Bytes = 0) then
      Exit;
    FreeMem(ThisP, Bytes);
    ThisP := nil;
  end;

end.
