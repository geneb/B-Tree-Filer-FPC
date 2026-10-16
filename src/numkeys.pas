{*********************************************************}
{*                   NUMKEYS.PAS 5.41                    *}
{*        Copyright (c) TurboPower Software 1989.        *}
{*                 All rights reserved.                  *}
{*********************************************************}

{--Conditional defines and compiler options}
  {$I btdefine.inc}
  {$F-,V-,B-,S-,I-,R-}
    {$Q-}

unit NumKeys;
  {-Routines to convert numeric types to keys usable for sorting or indexing}

interface

type
  String1  = String[1];
  String2  = String[2];
  String4  = String[4];
  String5  = String[5];
  String6  = String[6];
  String7  = String[7];
  String8  = String[8];
  String9  = String[9];
  String10 = String[10];

{---------------- routines for numeric conversions ----------------}

function ShortToKey(S : ShortInt) : String1;
  {-Convert a shortint to a string}

function KeyToShort(S : String1) : ShortInt;
  {-Convert a string to a shortint}

function ByteToKey(B : Byte) : String1; {!!.41}
  {-Convert a byte to a string}

function KeyToByte(S : String1) : Byte; {!!.41}
  {-Convert a string to a byte}

function IntToKey(I : Integer) : String2;
  {-Convert an integer to a string}

function KeyToInt(S : String2) : Integer;
  {-Convert a string to an integer}

function WordToKey(W : Word) : String2;
  {-Convert a word to a string}

function KeyToWord(S : String2) : Word;
  {-Convert a string to a word}

function LongToKey(L : LongInt) : String4;
  {-Convert a longint to a string}

function KeyToLong(S : String4) : LongInt;
  {-Convert a string to a longint}

function RealToKey(R : Real) : String6;
  {-Convert a real to a string. The key is built from the 6 byte real format
    of Turbo Pascal (Real48), so keys are identical to the ones created by
    the MS-DOS version, although Real is an 8 byte type in Free Pascal}

function KeyToReal(S : String6) : Real;
  {-Convert a string to a real}

function BcdToKey(var B) : String10;
  {-Convert a BCD real to a string}

procedure KeyToBcd(S : String10; var B);
  {-Convert a string to a BCD real}

{Note:
 Although the following two routines work with Extendeds, you can also use
 them with singles, doubles, and comps. You may use any of the following
 string types to hold the results of ExtToKey without losing any precision:

    Single    : String5 (min) - String10 (max)
    Double    : String9 (min) - String10 (max)
    Extended  : String10 (min/max)
    Comp      : String10 (min/max)

 The key is always built from the 10 byte extended format of the 80x87, even
 on platforms where Extended is only an 8 byte type (e.g. Win64).

 Slightly shorter strings (one less than the recommended minimum) may be used
 for singles, doubles, and extendeds if you are willing to sacrifice some
 precision, however. We strongly recommend that you always use a String10 for
 comps.
}
function ExtToKey(E : Extended) : String10;
  {-Convert an extended to a string}

function KeyToExt(S : String10) : Extended;
  {-Convert a string to an extended}

{---------------- routines for packing/unpacking keys ----------------}

function Pack4BitKey(Src : string; Len : Byte) : string;
  {-Pack the Source string into sequences of 4 bits (max length = Len).
    The following characters are mapped to 1-15, respectively, all others
    to 0: '(', ')', '+', '-', '.', '0'..'9'.}

function Pack5BitKeyUC(Src : string; Len : Byte) : string;
  {-Pack the Source string into sequences of 5 bits (max length = Len).
    Characters from 'a' to 'z' converted to upper case, then characters from
    'A' to 'Z' are mapped to 1-26, all others to 0.}

function Pack6BitKeyUC(Src : string; Len : Byte) : string;
  {-Pack the Source string into sequences of 6 bits (max length = Len).
    Characters from 'a' to 'z' converted to upper case, then characters from
    '!' to '_' are mapped to 1-63, all others to 0.}

function Pack6BitKey(Src : string; Len : Byte) : string;
  {-Pack the Source string into sequences of 6 bits (max length = Len).
    Characters from '0'-'9' mapped to 1-10, 'A'-'Z' to 11-36, 'a'-'z' to
    37-62, all others to 0.}

function Unpack4BitKey(Src : string) : string;
  {-Unpack a key created by Pack4BitKey}

function Unpack5BitKeyUC(Src : string) : string;
  {-Unpack a key created by Pack5BitKeyUC}

function Unpack6BitKeyUC(Src : string) : string;
  {-Unpack a key created by Pack6BitKeyUC}

function Unpack6BitKey(Src : string) : string;
  {-Unpack a key created by Pack6BitKey}

{---------------- miscellaneous routines ----------------}

function DescendingKey(S : string; MaxLen : Byte) : string;
  {-Invert values in S to allow descending sorts, pad to MaxLen with #$FF}

function CStyleNumKey(S : String) : String; {!!.41}
  {-Convert Pascal-style numkey S into a C-style numkey, compatible with ASCIIZ}

function PascalStyleNumKey(S : String) : String; {!!.41}
  {-Convert C-style numkey S into a Pascal-style numkey}

function CStyleDescendingKey(S : string; MaxLen : byte) : string; {!!.41}
  {-Convert S to a descending key, using C-style algorithm}

  {=========================================================================}

implementation

{Free Pascal port: the routines formerly written as inline machine code and
 the external routines of NUMKEYS.ASM (Pack/Unpack/DescendingKey) are now
 implemented in Pascal. They produce exactly the same keys.}

type
  PackProc = function(C : Char) : Byte;
  UnpackProc = function(B : Byte) : Byte;
  nkBytes = array[0..65520] of Byte;

  {---------------- character mapping (formerly NUMKEYS.ASM) ----------------}

  function Pack4(C : Char) : Byte;
    {-Map '(', ')', '+', '-', '.', '0'..'9' to 1-15, all others to 0}
  const
    {characters   (  )  *  +  ,  -  .  /  0  1  2  3   4   5   6   7   8   9}
    Pack4Table : array[0..17] of Byte =
                 (1, 2, 0, 3, 0, 4, 5, 0, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
  begin
    if (C < '(') or (C > '9') then
      Pack4 := 0
    else
      Pack4 := Pack4Table[Ord(C) - Ord('(')];
  end;

  function Pack5(C : Char) : Byte;
    {-Map 'a'..'z' and 'A'..'Z' to 1-26, all others to 0}
  begin
    if C > 'z' then
      Pack5 := 0
    else if C >= 'a' then
      Pack5 := Ord(C) - 96
    else if (C >= 'A') and (C <= 'Z') then
      Pack5 := Ord(C) - 64
    else
      Pack5 := 0;
  end;

  function Pack6UC(C : Char) : Byte;
    {-Map '!'..'_' to 1-63, 'a'..'z' to 33-58, all others to 0}
  begin
    if C > '_' then begin
      if (C >= 'a') and (C <= 'z') then
        Pack6UC := Ord(C) - 64
      else
        Pack6UC := 0;
    end
    else if C < '!' then
      Pack6UC := 0
    else
      Pack6UC := Ord(C) - 32;
  end;

  function Pack6(C : Char) : Byte;
    {-Map '0'..'9' to 1-10, 'A'..'Z' to 11-36, 'a'..'z' to 37-62, others to 0}
  begin
    if C > 'z' then
      Pack6 := 0
    else if C >= 'a' then
      Pack6 := Ord(C) - 60
    else if (C >= 'A') and (C <= 'Z') then
      Pack6 := Ord(C) - 54
    else if (C >= '0') and (C <= '9') then
      Pack6 := Ord(C) - 47
    else
      Pack6 := 0;
  end;

  function Unpack4(B : Byte) : Byte;
  const
    {                0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15}
    Unpack4Table : array[0..15] of Char =
                  (' ','(',')','+','-','.','0','1','2','3','4','5','6','7','8','9');
  begin
    Unpack4 := Ord(Unpack4Table[B and $0F]);
  end;

  function Unpack5(B : Byte) : Byte;
  begin
    if B = 0 then
      Unpack5 := Ord(' ')
    else
      Unpack5 := Byte(B + 64);
  end;

  function Unpack6UC(B : Byte) : Byte;
  begin
    if B = 0 then
      Unpack6UC := Ord(' ')
    else
      Unpack6UC := Byte(B + 32);
  end;

  function Unpack6(B : Byte) : Byte;
  begin
    if B = 0 then
      Unpack6 := Ord(' ')
    else if B >= 37 then
      Unpack6 := Byte(B + 60)
    else if B >= 11 then
      Unpack6 := Byte(B + 54)
    else
      Unpack6 := Byte(B + 47);
  end;

  {---------------- packing primitives (formerly NUMKEYS.ASM) ----------------}

  function PackKey(var Src : string; Len : Byte; BitsPerChar : Byte;
                   Proc : PackProc) : string;
    {-Pack the characters of Src into sequences of BitsPerChar bits,
      result has exactly Len bytes (padded with zeros)}
  var
    Res      : array[0..300] of Byte;
    R        : string;
    DI       : Word;
    SI       : Word;
    CharsLeft: Byte;
    BitCount : Byte;
    AL, AH   : Byte;
    I        : Byte;
  begin
    Res[0] := Len;
    DI := 1;
    SI := 1;
    CharsLeft := Length(Src);
    BitCount := 0;
    AH := 0;
    while DI < Word(Len) + 1 do begin
      if CharsLeft = 0 then begin
        {store the remaining bits, then pad with zeros}
        if BitCount <> 0 then begin
          Res[DI] := Byte(AH shl (8 - BitCount));
          Inc(DI);
        end;
        while DI < Word(Len) + 1 do begin
          Res[DI] := 0;
          Inc(DI);
        end;
        Break;
      end;
      AL := Proc(Src[SI]);
      Inc(SI);
      Dec(CharsLeft);
      AL := Byte(AL shl (8 - BitsPerChar));   {move bits to the top of AL}
      for I := 1 to BitsPerChar do begin
        if BitCount >= 8 then begin
          Res[DI] := AH;
          Inc(DI);
          BitCount := 0;
        end;
        AH := Byte((AH shl 1) or (AL shr 7));  {rotate high bit of AL into AH}
        AL := Byte(AL shl 1);
        Inc(BitCount);
      end;
    end;
    Move(Res, R, Succ(Len));
    PackKey := R;
  end;

  function UnpackKey(var Src : string; BitsPerChar : Byte;
                     Proc : UnpackProc) : string;
    {-Unpack a key created by PackKey}
  var
    Res       : string;
    ResLen    : Word;
    SI        : Word;
    CharsLeft : Byte;
    BitsLeft  : Byte;
    AL, AH    : Byte;
    I         : Byte;

    procedure Store(B : Byte);
    begin
      if ResLen < 255 then begin
        Inc(ResLen);
        Res[ResLen] := Char(B);
      end;
    end;

  begin
    ResLen := 0;
    SI := 1;
    CharsLeft := Length(Src);
    BitsLeft := 0;
    AL := 0;
    while CharsLeft <> 0 do begin
      AH := 0;
      for I := 1 to BitsPerChar do begin
        if BitsLeft = 0 then begin
          AL := Byte(Src[SI]);
          Inc(SI);
          Dec(CharsLeft);
          BitsLeft := 8;
        end;
        AH := Byte((AH shl 1) or (AL shr 7));
        AL := Byte((AL shl 1) or (AL shr 7));  {ROL AL,1}
        Dec(BitsLeft);
      end;
      Store(Proc(AH));
    end;
    if BitsLeft >= BitsPerChar then begin
      {a full character is left in AL}
      AL := AL shr (8 - BitsLeft);
      Store(Proc(AL));
    end;
    Res[0] := Char(ResLen);
    UnpackKey := Res;
  end;

  function Pack4BitKey(Src : string; Len : Byte) : string;
  begin
    Pack4BitKey := PackKey(Src, Len, 4, Pack4);
  end;

  function Pack5BitKeyUC(Src : string; Len : Byte) : string;
  begin
    Pack5BitKeyUC := PackKey(Src, Len, 5, Pack5);
  end;

  function Pack6BitKeyUC(Src : string; Len : Byte) : string;
  begin
    Pack6BitKeyUC := PackKey(Src, Len, 6, Pack6UC);
  end;

  function Pack6BitKey(Src : string; Len : Byte) : string;
  begin
    Pack6BitKey := PackKey(Src, Len, 6, Pack6);
  end;

  function Unpack4BitKey(Src : string) : string;
  begin
    Unpack4BitKey := UnpackKey(Src, 4, Unpack4);
  end;

  function Unpack5BitKeyUC(Src : string) : string;
  begin
    Unpack5BitKeyUC := UnpackKey(Src, 5, Unpack5);
  end;

  function Unpack6BitKeyUC(Src : string) : string;
  begin
    Unpack6BitKeyUC := UnpackKey(Src, 6, Unpack6UC);
  end;

  function Unpack6BitKey(Src : string) : string;
  begin
    Unpack6BitKey := UnpackKey(Src, 6, Unpack6);
  end;

  function DescendingKey(S : string; MaxLen : Byte) : string;
    {-Invert values in S to allow descending sorts, pad to MaxLen with #$FF}
  var
    Res : string;
    I   : Word;
  begin
    Res[0] := Char(MaxLen);
    for I := 1 to Length(S) do
      Res[I] := Char(not Byte(S[I]));
    for I := Succ(Length(S)) to MaxLen do
      Res[I] := #$FF;
    DescendingKey := Res;
  end;

  {---------------- helpers (formerly inline machine code) ----------------}

  procedure ReverseBytes(var V; Size : Word);
    {-Reverse the ordering of bytes from V[1] to V[Size]. Size must be >= 2.}
  var
    B    : nkBytes absolute V;
    I, J : Word;
    T    : Byte;
  begin
    I := 0;
    J := Size - 1;
    while I < J do begin
      T := B[I];
      B[I] := B[J];
      B[J] := T;
      Inc(I);
      Dec(J);
    end;
  end;

  procedure ToggleBits(var V; Size : Word);        {!!.04}
    {-Toggle the bits from V[1] to V[Size]}        {!!.04}
  var
    B : nkBytes absolute V;
    I : Word;
  begin
    for I := 0 to Size - 1 do
      B[I] := not B[I];
  end;

  function SwapWord(L : LongInt) : LongInt;
    {-Swap low- and high-order words of L}
  begin
    SwapWord := LongInt((LongWord(L) shl 16) or (LongWord(L) shr 16));
  end;

  function FirstRotation(W : Word) : Word;
    {-Move sign bit from high bit of MSB of mantissa (AH) into high bit of
      exponent (AL), rotating low bit of exponent into its place.}
  var
    AL, AH, NewAL, NewAH : Byte;
  begin
    AL := Lo(W);
    AH := Hi(W);
    NewAL := Byte((((AH xor $80) shr 7) shl 7) or (AL shr 1));
    NewAH := Byte(((AL and 1) shl 7) or (AH and $7F));
    FirstRotation := Word(NewAH) shl 8 or NewAL;
  end;

  function SecondRotation(W : Word) : Word;
    {-Undo the work of the first rotation}
  var
    AL, AH, NewAL, NewAH : Byte;
  begin
    AL := Lo(W);
    AH := Hi(W);
    NewAL := Byte(((AL xor $80) shl 1) or (AH shr 7));
    NewAH := Byte((((AL xor $80) shr 7) shl 7) or (AH and $7F));
    SecondRotation := Word(NewAH) shl 8 or NewAL;
  end;

  {---------------- floating point format conversions ----------------}

type
  TReal48 = array[0..5] of Byte;    {Turbo Pascal 6 byte real}
  TExt80  = array[0..9] of Byte;    {80x87 10 byte extended}

  procedure DoubleToReal48(D : Double; var R : TReal48);
    {-Convert a double to the Turbo Pascal 6 byte real format}
  var
    Bits : QWord absolute D;
    Sign : Byte;
    E    : LongInt;
    M    : QWord;
    I    : Integer;
  begin
    FillChar(R, SizeOf(R), 0);
    Sign := Byte(Bits shr 63);
    E := LongInt((Bits shr 52) and $7FF);
    M := Bits and QWord($000FFFFFFFFFFFFF);
    if E = 0 then
      Exit;                     {zero or denormal: too small for a Real48}
    {round 52 bit fraction to 39 bits}
    M := (M + (QWord(1) shl 12)) shr 13;
    if M >= (QWord(1) shl 39) then begin
      M := 0;
      Inc(E);
    end;
    E := E - 1023 + 129;
    if E <= 0 then
      Exit;                     {underflow}
    if E > 255 then begin
      E := 255;                 {overflow: largest Real48}
      M := (QWord(1) shl 39) - 1;
    end;
    R[0] := Byte(E);
    for I := 1 to 5 do begin
      R[I] := Byte(M and $FF);
      M := M shr 8;
    end;
    R[5] := (R[5] and $7F) or (Sign shl 7);
  end;

  function Real48ToDouble(var R : TReal48) : Double;
    {-Convert a Turbo Pascal 6 byte real to a double}
  var
    D    : Double;
    Bits : QWord absolute D;
    M    : QWord;
    I    : Integer;
  begin
    if R[0] = 0 then begin
      Real48ToDouble := 0.0;
      Exit;
    end;
    M := 0;
    for I := 5 downto 1 do
      M := (M shl 8) or R[I];
    M := M and ((QWord(1) shl 39) - 1);
    Bits := (QWord(R[5] shr 7) shl 63) or
            (QWord(LongInt(R[0]) - 129 + 1023) shl 52) or (M shl 13);
    Real48ToDouble := D;
  end;

  procedure ExtendedToExt80(E : Extended; var X : TExt80);
    {-Store E in the 80x87 10 byte format}
{$IFDEF FPC_HAS_TYPE_EXTENDED}
  begin
    Move(E, X, SizeOf(X));
  end;
{$ELSE}
  var
    D    : Double;
    Bits : QWord absolute D;
    Sign : Word;
    Ex   : LongInt;
    M    : QWord;
    I    : Integer;
  begin
    D := E;
    FillChar(X, SizeOf(X), 0);
    Sign := Word(Bits shr 63);
    Ex := LongInt((Bits shr 52) and $7FF);
    M := Bits and QWord($000FFFFFFFFFFFFF);
    if Ex = $7FF then
      Ex := $7FFF                               {infinity or NaN}
    else if Ex = 0 then begin
      if M <> 0 then begin                      {denormal: normalize}
        Ex := 1;
        while M and (QWord(1) shl 52) = 0 do begin
          M := M shl 1;
          Dec(Ex);
        end;
        M := M and QWord($000FFFFFFFFFFFFF);
        Ex := Ex - 1023 + 16383;
      end;
    end
    else
      Ex := Ex - 1023 + 16383;
    if (Ex <> 0) or (M <> 0) then
      M := (M shl 11) or (QWord(1) shl 63);     {explicit integer bit}
    for I := 0 to 7 do begin
      X[I] := Byte(M and $FF);
      M := M shr 8;
    end;
    X[8] := Byte(Ex and $FF);
    X[9] := Byte((Ex shr 8) and $7F) or Byte(Sign shl 7);
  end;
{$ENDIF}

  function Ext80ToExtended(var X : TExt80) : Extended;
    {-Convert a value in the 80x87 10 byte format}
{$IFDEF FPC_HAS_TYPE_EXTENDED}
  var
    E : Extended;
  begin
    Move(X, E, SizeOf(X));
    Ext80ToExtended := E;
  end;
{$ELSE}
  var
    D    : Double;
    Bits : QWord absolute D;
    Sign : QWord;
    Ex   : LongInt;
    M    : QWord;
    I    : Integer;
  begin
    M := 0;
    for I := 7 downto 0 do
      M := (M shl 8) or X[I];
    Ex := LongInt(X[8]) or (LongInt(X[9] and $7F) shl 8);
    Sign := QWord(X[9] shr 7) shl 63;
    if (Ex = 0) or (M = 0) then
      Bits := Sign                              {zero}
    else if Ex = $7FFF then
      Bits := Sign or (QWord($7FF) shl 52) or ((M shl 1) shr 12)
    else begin
      Ex := Ex - 16383 + 1023;
      M := ((M shl 1) shr 1);                   {remove integer bit}
      M := (M + (QWord(1) shl 10)) shr 11;      {round to 52 bits}
      if M >= (QWord(1) shl 52) then begin
        M := M and QWord($000FFFFFFFFFFFFF);
        Inc(Ex);
      end;
      if Ex >= $7FF then
        Bits := Sign or (QWord($7FF) shl 52)    {overflow: infinity}
      else if Ex <= 0 then
        Bits := Sign                            {underflow: zero}
      else
        Bits := Sign or (QWord(Ex) shl 52) or M;
    end;
    Ext80ToExtended := D;
  end;
{$ENDIF}

  {---------------- numeric conversions ----------------}

  procedure ZeroPad(var S : String; Len : Word);
    {-Pad S to length Len with 0's}
  var
    SLen  : Byte absolute S;
  begin
    if SLen < Len then begin
      FillChar(S[Succ(SLen)], Len-SLen, 0);
      SLen := Len;
    end;
  end;

  function ShortToKey(S : ShortInt) : String1;
    {-Convert a shortint to a string}
  begin
    ShortToKey[0] := #1;
    ShortToKey[1] := Char(Byte(S) xor $80);
  end;

  function KeyToShort(S : String1) : ShortInt;
    {-Convert a string to a shortint}
  begin
    KeyToShort := ShortInt(Byte(S[1]) xor $80);
  end;

  function ByteToKey(B : Byte) : String1; {!!.41}
    {-Convert a byte to a string}
  begin
    ByteToKey[0] := #1;
    ByteToKey[1] := Char(B);
  end;

  function KeyToByte(S : String1) : Byte; {!!.41}
    {-Convert a string to a byte}
  begin
    KeyToByte := Byte(S[1]);
  end;

  function IntToKey(I : Integer) : String2;
    {-Convert an integer to a string}
  const
    Result :
      record case Byte of
        0 : (Len : Byte; RI : Word);
        1 : (Str : String2);
      end = (Str : '  ');
  begin
    Result.RI := Swap(Word(Word(I) xor $8000));
    IntToKey := Result.Str;
  end;

  function KeyToInt(S : String2) : Integer;
    {-Convert a string to an integer}
  var
    Temp :
      record
        Len : Byte;
        I   : Word;
      end absolute S;
  begin
    KeyToInt := Integer(Word(Swap(Temp.I) xor $8000));
  end;

  function WordToKey(W : Word) : String2;
    {-Convert a word to a string}
  const
    Result :
      record case Byte of
        0 : (Len : Byte; RW : Word);
        1 : (Str : String2);
      end = (Str : '  ');
  begin
    Result.RW := Swap(W);
    WordToKey := Result.Str;
  end;

  function KeyToWord(S : String2) : Word;
    {-Convert a string to a word}
  var
    Temp :
      record
        Len : Byte;
        W   : Word;
      end absolute S;
  begin
    KeyToWord := Swap(Temp.W);
  end;

  function LongToKey(L : LongInt) : String4;
    {-Convert a longint to a string}
  const
    Result :
      record case Byte of
        0 : (Len : Byte; W1, W2 : Word);
        1 : (Str : String4);
      end = (Str : '    ');
  var
    LRec :
      record
        L1 : Word;
        L2 : Word;
      end absolute L;
  begin
    L := LongInt(LongWord(L) xor $80000000);
    Result.W1 := Swap(LRec.L2);
    Result.W2 := Swap(LRec.L1);
    LongToKey := Result.Str;
  end;

  function KeyToLong(S : String4) : LongInt;
    {-Convert a string to a longint}
  var
    Temp :
      record case Byte of
        0 : (Len : Byte; W1, W2 : Word);
        1 : (X : Byte; L : LongInt);
      end absolute S;
  begin
    Temp.W1 := Swap(Temp.W1);
    Temp.W2 := Swap(Temp.W2);
    KeyToLong := LongInt(LongWord(SwapWord(Temp.L)) xor $80000000);
  end;

  function RealToKey(R : Real) : String6;
    {-Convert a real to a string}
  const
    Temp :
      record case Byte of
        0 : (Len : Byte; RR : TReal48);
        1 : (Str : String6);
        2 : (XXX, Exp, LSB : Byte);
        3 : (YYY : Byte; MantExp : Word);
      end = (Str : '      ');
  begin
    DoubleToReal48(R, Temp.RR);

    {put the mantissa into MSB->LSB order}
    ReverseBytes(Temp.LSB, 5);

    {move the sign bit from the MSB of the mantissa into the high bit
     of the exponent, rotating the low bit of the exponent into its place}
    Temp.MantExp := FirstRotation(Temp.MantExp);

    if Temp.Exp and $80 = 0 then begin  {!!.04}
      ToggleBits(Temp.RR, 6);           {!!.04}
      Temp.Exp := Temp.Exp and $7F;     {!!.04}
    end;                                {!!.04}

    RealToKey := Temp.Str;
  end;

  function KeyToReal(S : String6) : Real;
    {-Convert a string to a real}
  var
    Temp :
      record case Byte of
        0 : (Len : Byte; RR : TReal48);
        1 : (Str : String6);
        2 : (XXX, Exp, MSB : Byte);
        3 : (YYY : Byte; MantExp : Word);
      end absolute S;
  begin
    {pad to proper length just in case}
    ZeroPad(S, 6);

    if Temp.Exp and $80 = 0 then begin {!!.04}
      ToggleBits(Temp.RR, 6);          {!!.04}
      Temp.Exp := Temp.Exp and $7F;    {!!.04}
    end;                               {!!.04}

    {put the sign bit back where it belongs}
    Temp.MantExp := SecondRotation(Temp.MantExp);

    {put the mantissa back into LSB->MSB order}
    ReverseBytes(Temp.MSB, 5);

    KeyToReal := Real48ToDouble(Temp.RR);
  end;

type
  nkBCD = array[1..10] of Byte;

  function BcdToKey(var B) : String10;
    {-Convert a BCD real to a string}
  const
    Temp :
      record case Byte of
        0 : (Len : Byte; BT : nkBCD);
        1 : (Str : String10);
        2 : (XXX, Exp, LSB : Byte);
      end = (Str : '          ');
  var
    BP : nkBCD absolute B;
  begin
    {regularize 0 values}
    if BP[1] and $7F = 0 then
      FillChar(BP, SizeOf(BP), 0);

    Temp.BT := BP;

    {put the mantissa into MSB->LSB order}
    ReverseBytes(Temp.LSB, 9);

    {flip the sign bit}
    Temp.Exp := Temp.Exp xor $80;

    if Temp.Exp and $80 = 0 then begin
      ToggleBits(Temp.BT, 10);
      Temp.Exp := Temp.Exp and $7F;
    end;

    BcdToKey := Temp.Str;
  end;

  procedure KeyToBcd(S : String10; var B);
    {-Convert a string to a BCD real}
  var
    Temp :
      record case Byte of
        0 : (Len : Byte; BT : nkBCD);
        1 : (XXX, Exp, MSB : Byte);
      end absolute S;
    BR : nkBcd absolute B;
  begin
    {pad to proper length just in case}
    ZeroPad(S, 10);

    {flip the sign bit}
    Temp.Exp := Temp.Exp xor $80;

    if Temp.Exp and $80 <> 0 then begin
      ToggleBits(Temp.BT, 10);
      Temp.Exp := Temp.Exp or $80;
    end;

    {put the mantissa back into LSB->MSB order}
    ReverseBytes(Temp.MSB, 9);

    BR := Temp.BT;
  end;

  function ExtToKey(E : Extended) : String10;
    {-Convert an extended to a string}
  const
    Temp :
      record case Byte of
        0 : (Len : Byte; EE : TExt80);
        1 : (XXX, Exp : Byte);
        2 : (Str : String10);
      end = (Str : '          ');
  begin
    ExtendedToExt80(E, Temp.EE);

    {move the exponent to the front and put mantissa in MSB->LSB order}
    ReverseBytes(Temp.EE, 10);

    {flip the sign bit}
    Temp.Exp := Temp.Exp xor $80;

    if Temp.Exp and $80 = 0 then begin  {!!.04}
      ToggleBits(Temp.EE, 10);          {!!.04}
      Temp.Exp := Temp.Exp and $7F;     {!!.04}
    end;                                {!!.04}

    ExtToKey := Temp.Str;
  end;

  function KeyToExt(S : String10) : Extended;
    {-Convert a string to an extended}
  var
    Temp :
      record case Byte of
        0 : (Len : Byte; EE : TExt80);
        1 : (XXX, Exp : Byte);
        2 : (Str : String10);
      end absolute S;
  begin
    {pad to proper length just in case}
    ZeroPad(S, 10);

    {flip the sign bit}
    Temp.Exp := Temp.Exp xor $80;

    if Temp.Exp and $80 <> 0 then begin {!!.04}
      ToggleBits(Temp.EE, 10);          {!!.04}
      Temp.Exp := Temp.Exp or $80;      {!!.04}
    end;                                {!!.04}

    {move the exponent back to the end and put mantissa in LSB->MSB order}
    ReverseBytes(Temp.EE, 10);

    KeyToExt := Ext80ToExtended(Temp.EE);
  end;

function CStyleNumKey(S : String) : String;
  {-Convert Pascal-style numkey S into a C-style numkey, compatible with ASCIIZ}
const
  MaxInpStrLen = 223;
type
  PWord = ^Word;
var
  WPtr : PWord;
  I, ResLen, ShiftCount, OrigLen : Word;
  ResStr : String;
begin
  OrigLen := Length(S);
  if (OrigLen = 0) or (OrigLen > MaxInpStrLen) then begin
    CStyleNumKey := '';
    Exit;
  end;

  ResLen := OrigLen+Succ(Pred(OrigLen) DIV 7);
  ResStr[0] := Chr(ResLen);

  S[0] := #0;
  if OrigLen = 4 then
    ShiftCount := 4
  else
    ShiftCount := 1;
  WPtr := @S;

  for I := 1 To ResLen do begin
    ResStr[I] := Chr(((Swap(WPtr^) shr ShiftCount) and $FF) or $80);
    if ShiftCount < 7 then begin
      Inc(ShiftCount);
      WPtr := PWord(PChar(WPtr) + 1);       {advance one byte}
    end else
      ShiftCount := 0;
  end;

  if OrigLen = 4 then
    ResStr[1] := Chr(Byte((Byte(ResStr [1]) shl 4) or $01));

  CStyleNumKey := ResStr;
end;

function PascalStyleNumKey(S : String) : String;
  {-Convert C-style numkey S into a Pascal-style numkey}
Type
  PByte = ^Byte;
Var
  B1Ptr, B2Ptr : PByte;
  I, ShiftLCount, ShiftRCount, ResLen, OrigLen : Word;
begin
  OrigLen := Length(S);
  if OrigLen = 0 then begin
    PascalStyleNumKey := '';
    Exit;
  end;

  ResLen := OrigLen-Succ(Pred(OrigLen) DIV 8);
  S[0] := Chr(ResLen);

  B1Ptr := @S[1];
  B2Ptr := @S[2];
  if OrigLen = 5 then begin
    B1Ptr^ := B1Ptr^ shr 4;
    ShiftLCount := 4;
    ShiftRCount := 3;
  end else begin
    ShiftLCount := 1;
    ShiftRCount := 6;
  end;

  for I := 1 To ResLen do begin
    B1Ptr^ := Byte((B1Ptr^ shl ShiftLCount) or ((B2Ptr^ and $7F) shr ShiftRCount));
    if ShiftLCount < 7 then begin
      Inc(ShiftLCount);
      Dec(ShiftRCount);
      Inc(B1Ptr);
      Inc(B2Ptr);
    end else begin
      ShiftLCount := 1;
      ShiftRCount := 6;
      Inc(B1Ptr, 2);
      Inc(B2Ptr, 2);
    end;
  end;

  PascalStyleNumKey := S;
end;

function CStyleDescendingKey(S : string; MaxLen : byte) : string;
  {-Convert S to a descending key, using C-style algorithm}
var
  I     : Word;
  ToAdd : Integer;
begin
  ToAdd := MaxLen-Length(S);
  if ToAdd < 0 then begin
    CStyleDescendingKey := '';
    exit;
  end;
  for I := 1 to Length(S) do
    S[I] := Char(Byte(256 - Byte(S[I])));
  FillChar(S[succ(Length(S))], ToAdd, $FF);
  S[0] := Chr(MaxLen);
  CStyleDescendingKey := S;
end;

end.
