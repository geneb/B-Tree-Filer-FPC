{Conditional definitions that affect B-Tree Filer units}
{Version 5.41 - Free Pascal port for Windows and Linux}

{--Compiler mode and data layout.
   These settings keep the in-memory layout of all records identical to the
   one produced by Turbo Pascal, so data and index files remain binary
   compatible with files created by the original MS-DOS version.}
{$IFNDEF FPC}
  !! ERROR: This version of B-Tree Filer requires Free Pascal
{$ENDIF}
{$MODE TP}
{$PACKRECORDS 1}
{$PACKENUM 1}
{$PACKSET 1}
{$H-}
{$GOTO ON}

{--Free Pascal predefines WINDOWS for Win32/Win64 targets. In the original
   sources "Windows" meant 16-bit Windows, so make sure it is not seen.
   Use MSWINDOWS or UNIX to test for the target platform.}
{$UNDEF Windows}
{$UNDEF DPMI}

{.$DEFINE NoNet}
{$DEFINE MsNet}
{Valid network interfaces. One of them must be defined, but not both.
 MsNet uses the operating system's byte range locking (LockFileEx on
 Windows, open file description locks on Linux) and works for several
 programs sharing files on the same machine or on a network share.
 The Novell interface of the MS-DOS version is not available.}

{$IFNDEF NoNet}
{.$DEFINE LockBeforeRead}
{Automatically locks any file section before reading it, then unlocks.}
{$ENDIF}

{$DEFINE LengthByteKeys}
{.$DEFINE AsciiZeroKeys}
{One of LengthByteKeys or AsciiZeroKeys must be defined, but not both.
 LengthByteKeys causes FILER to store Turbo Pascal style strings in the index
 file. AsciiZeroKeys causes FILER to store C-style ASCIIZ strings in the index
 file.}

{.$DEFINE InitAllUnits}
{Activate this define to cause all B-Tree Filer units to have an
 initialization block, even if only an empty one.}

(**************************************************************************)
(**************************************************************************)
{Don't change anything beyond this point}

{The following define allows extensions to B-Tree Filer to detect the new
 syntax of versions 5.2 and later.}
{$DEFINE BTree52}

{The following define allows extensions to B-Tree Filer to detect the new
 syntax of versions 5.4 and later.}
{$DEFINE BTree54}

{--The heap behaves like the Turbo Pascal 6.0+ heap}
{$DEFINE Heap6}

{--The overflow check option can be set}
{$DEFINE CanSetOvrflowCheck}

{--Test the definition of the net interfaces}
  {$IFDEF Novell}
    !! ERROR: The Novell interface is not available in this version
  {$ENDIF}
  {$IFDEF NoNet}
    {$IFDEF MsNet}
      !! ERROR: You may not define NoNet and MsNet simultaneously
    {$ENDIF}
  {$ELSE}
    {$IFNDEF MsNet}
      !! ERROR: You must define either NoNet or MsNet
    {$ENDIF}
  {$ENDIF}

{--Test the XXKeys defines}
  {$IFDEF LengthByteKeys}
    {$IFDEF ASCIIZeroKeys}
      !! ERROR: You may not define both LengthByteKeys and AsciiZeroKeys
    {$ENDIF}
  {$ELSE}
    {$IFNDEF ASCIIZeroKeys}
      !! ERROR: You must define either LengthByteKeys or AsciiZeroKeys
    {$ENDIF}
  {$ENDIF}
