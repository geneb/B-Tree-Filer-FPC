{*********************************************************}
{*                    MSORT.PAS 5.41                     *}
{*        Copyright (c) TurboPower Software 1989.        *}
{*                 All rights reserved.                  *}
{*********************************************************}

{--Conditional defines and compiler options}
  {$I btdefine.inc}
  {$F+,V-,B-,S-,I-,R-}
    {$Q-,T-}          {!!.41}

              {!!.41}

{!!.41 All Windows and DPMI support code removed}

{Free Pascal port: the EMS support (MSORTEMS.INC) has been removed, since
 EMS does not exist under Windows and Linux; all temporary files are written
 to disk. UseEMS, UsingEMS and MSortEMSError are kept for compatibility only.
 The inline machine code routines have been replaced by Pascal code, and the
 user routines are called through procedure types.}

Unit Msort;

interface
uses
{$IFDEF MSWINDOWS}
  Windows,
{$ENDIF}
{$IFDEF UNIX}
  BaseUnix,
  Unix,
{$ENDIF}
  SysUtils,
  BaseSupp,
  TPAlloc;

const
  MERGEORDER       = 5;     {The maximum number of input files for merge}
  BiggestDataItem  = 65521; {largest data item Turbo Pascal can handle}
  UseEMS           : Boolean = TRUE; {without effect: EMS is not available}
  MaxHeapToUse     : LongInt = 655210;
  STemp            : String[5] = 'STEMP';

TYPE

  {these are the possible return values of the sort routines}
  MSortStatus       = (MSortSuccess,     {Successful sort}
                       MSortOutOfMemory, {insufficient memory}
                       MSortDiskError,   {disk I/O error}
                       MSortOutOfDisk,   {insufficient disk space for merge}
                       MSortEMSError,    {EMM error}
                       MSortUserAbort);  {User abort}    {!!.05}

  PathName         = String[255];        {string type for pathnames (79 under MS-DOS)}

  MSortLessFunc    = function(var X, Y) : Boolean;
    {-Type of the LessFunc routine}
  MSortUserProc    = procedure;
    {-Type of the GetElements and PutElements routines}

var
  UsingEMS         : Boolean;     {always False}
  GRunLength       : Word;        {To store the run length}
  MSortIOResult    : Integer;     {Stores last IOResult value}
  LastFileName     : PathName;    {The name of the last file written to}

function DoSort(RunLength     : Word;
                RecLength     : Word;
                InFileBufMax  : Word;
                OutFileBufMax : Word;
                TempPath      : PathName;
                GetElements   : Pointer;
                LessFunc      : Pointer;
                PutElements   : Pointer
               ) : MSortStatus;
{-low level sorting routine}


function AutoSort(FSizeInRecs : LongInt;
                  RecLength   : Word;
                  TempPath    : PathName;
                  GetElements : Pointer;
                  LessFunc    : Pointer;
                  PutElements : Pointer
                 ) : MSortStatus;
{-high level sorting routine}

function AutoSortInfo(FSizeInRecs     : LongInt;
                      RecLength       : Word;
                      var HeapSpace   : LongInt;
                      var DiskSpace   : LongInt;
                      var FileHandles : Word;
                      var EMSPages    : Word;
                      var RunLen      : Word;
                      var FileBufs    : Word;
                      var OutFileBufs : Word;
                      var AllInMem    : Boolean) : MSortStatus;


function PutElement(var X) : Boolean;
{-Submits a record to the sort system.  Returns TRUE is record successfully}
{submitted.}

function GetElement(var X) : Boolean;
{-Returns a record from the sort system.  Returns TRUE while there are more}
{ records to return.  When FALSE is returned, the value of the VAR X is    }
{ undefined.}

procedure AbortSort;
{-Prematurely halt the sort from the user defined routines}

implementation

const
  MAXRUNLENGTH     = $FFFF; {maximum number of elements per Run}
  UserFree         = 128;
                                      {!!.06}
  AllInMem         : Boolean = FALSE; {to indicate whether the entire file}
                                      {to be sorted is in memory}
  GFSizeInRecs     : LongInt = MaxLongInt;

type
  FileName         = String[13];
  BufferType       = Array[1..$FFFF] of Char; {a buffer of Characters}
  HugeArray        = Pointer; {for data structures larger than 64k}
  PointerArray     = Array[0..(MaxInt div SizeOf(Pointer)) - 1] of Pointer;
  PointerArrayPtr  = ^PointerArray;
  FDBuffer         = Array[1..MERGEORDER] of File; {the input file list}
  FDBuf            = ^FDBuffer;
  MarkRec          = record
                       Marker : Pointer;
                       FreeBuf : Pointer;
                       OldFreePtr : Pointer;
                       BufSize : Word;
                     end; {used by fast heap routines MarkFL and ReleaseFL}

var
  BufferPos,    {to hold the current position within each of the I/O buffers}
  BufferSize    {to hold the size of each of the buffers}
                   : Array[0..MERGEORDER] of Word;

  {The following var holds pointers to the I/O buffers.  Position 0 }
  {is the output buffer, and positions 1..MERGEORDER are for each of}
  {the input files.}
  Buffer           : Array[0..MERGEORDER] of ^BufferType;

  RecBuf           : HugeArray; {This huge array holds pointers to the data.}
                                {It may exceed 64K in size if necessary.}
  RecBufSave       : Pointer;   {to save the original value of RecBuf} {!!.04}
  HeapMark         : MarkRec;
  UserLess         : Pointer;   {points to the user's Less procedure}
  UserGet          : Pointer;   {points to the user's GetElements procedure}
  UserPut          : Pointer;   {points to the user's PutElements procedure}
  GTempPath        : PathName;  {Pathname to store temporary files}
  NumElements,
  ElementCount     : LongInt;   {Used by sort routines to count elements}
  FileBufferMax    : Word;      {The maximum size of an input file buffer}
  InFilePtr           : FDBuf;     {a record to hold all the input files for merge}
  OutFile          : File;      {The output file}
  Pivot            : Pointer;   {pointer to pivot element for QuickSort}
  TempRec          : Pointer;   {pointer to temporary record}
  OutBufSize       : Word;      {size of the output buffer}
  HighF            : Word;
  NumElemInRun     : Word;      {element number within this run}
  PtrBufLength     : LongInt;   {The length of the pointer buffer for data}
  GRecLength       : Word;      {To store the record length of the data items}

  Pl               : Word;      {Left edge within partition}
  Pr               : Word;      {Right edge within partition}

  GBasePtr         : Pointer;
  GBytes           : LongInt;
  MSortResult      : MSortStatus; {global sort status}

procedure FillWord(var Dest; Count, Filler : Word);
  {-Fill memory starting at Dest with Count instances of Filler}
type
  WordArray = Array[0..32767] of Word;
var
  W : WordArray absolute Dest;
  I : Word;
begin
  for I := 1 to Count do
    W[I-1] := Filler;
end;

procedure GetRecBuffer(Size : LongInt);
{-Get the record buffer}
begin
  HugeGetMem(RecBuf,Size);
  if (RecBuf = NIL)  then begin
    MSortResult := MSortOutOfMemory;
    Exit;
  end;
  RecBufSave := RecBuf;         {!!.04}
end;

procedure FreeRecBuffer(Size : LongInt);
{-Free the Record buffer}
begin
  HugeFreeMem(RecBufSave,Size);  {!!.04}
end;

function GetPointerPr : PPointer;
{-returns a pointer to the element at index Pr within RecBuf}
begin
  GetPointerPr := @PointerArrayPtr(RecBuf)^[Pr-1];
end;

function GetPointerPl : PPointer;
{-returns a pointer to the element at index Pl within RecBuf}
begin
  GetPointerPl := @PointerArrayPtr(RecBuf)^[Pl-1];
end;

procedure IncPtr(var P : Pointer; Increment : Word);
{-increments a pointer by Increment}
begin
  Inc(PByte(P),Increment);
end;

procedure AllocRunBuffers;
{-allocate space for an entire run's worth of data}
var
  I                : Word;
  P                : Pointer;

begin

  GetRecBuffer(PtrBufLength);
  if MSortResult <> MSortSuccess then Exit;
  GBytes := LongInt(GRecLength) * GRunLength;  {!!.02}
  HugeGetMem(GBasePtr,GBytes);
  if GBasePtr = NIL then begin                 {!!.02}
    MSortResult := MSortOutOfMemory;           {!!.02}
    Exit;                                      {!!.02}
  end;
  P := GBasePtr;
  for I := 1 to GRunLength do begin
    Pr := I;
    GetPointerPr^ := P;
    IncPtr(P,GRecLength);
  end;
end;

procedure DeallocRunBuffers;
{-deallocate the space used by the run data}


begin
  HugeFreeMem(GBasePtr,GBytes);
  FreeRecBuffer(PtrBufLength);
end;

procedure AllocIOBuffers;
{-allocate the input file data buffers}

var
  I                : Word;

begin
  for I := 1 to MERGEORDER do begin
    if FileBufferMax > 0 then begin
      GetMem(Buffer[I],FileBufferMax);
      if Buffer[I] = NIL then begin
        MSortResult := MSortOutOfMemory;
        Exit;
      end;
    end;
    BufferPos[I]  := FileBufferMax + 1;
    BufferSize[I] := FileBufferMax;
  end;
end;

procedure DeallocIOBuffers;
{-deallocate the input file data buffers}

var
  I                : Word;

begin
  for I := 1 to MERGEORDER do
    FreeMem(Buffer[I],FileBufferMax);
end;

function MakePathName(N : FileName) : PathName;
{-appends a filename  to the path for temporary files}
begin
  MakePathName := GTempPath + N;
end;

function Min(A, B : Word) : Word;
  {-Returns the smaller of A and B}
begin
  if A < B then
    Min := A
  else
    Min := B;
end;

procedure ExchangeWords(var I, J : Word);
  {-Exchange words I and J. Useful in sorts}
var
  T : Word;
begin
  T := I;
  I := J;
  J := T;
end;

procedure ExchangePtr(var A,B);
{-Exchange pointers A and B. Useful in sorts}
var
  PA : Pointer absolute A;
  PB : Pointer absolute B;
  T  : Pointer;
begin
  T := PA;
  PA := PB;
  PB := T;
end;


function ULess(var X, Y) : Boolean;
  {-Call the user routine to perform element comparison}
begin
  ULess := MSortLessFunc(UserLess)(X, Y);
end;

procedure CallGetElements;
  {-Call the user GetEl routine}
begin
  MSortUserProc(UserGet);
end;

procedure CallPutElements;
  {-Call the user PutEl routine}
begin
  MSortUserProc(UserPut);
end;

{--Disk file routines (formerly in MSORTEMS.INC together with EMS support)}

procedure Open_InFile(var F : File; FName : PathName; I : Word);
begin
  Assign(F,FName);
  Reset(F,1);
  MSortIOResult := IOResult;
  if MSortIOResult <> 0 then
    MSortResult := MSortDiskError;
  BufferPos[I]  := FileBufferMax + 1;
  BufferSize[I] := FileBufferMax;
end;

procedure Open_OutFile(var F : File; FName : PathName; FSize : LongInt);
begin
  Assign(F,FName);
  Rewrite(F,1);
  BufferPos[0]  := 1;
  MSortIOResult := IOResult;
  if MSortIOResult <> 0 then
    MSortResult := MSortDiskError;
end;

procedure GetPivot(L, R : Word);
{-Load the pivot element}
var
  Sav            : Word;

begin
  {Use a random pivot index to help with pre-sorted arrays}
  Sav := Pr;
  Pr  := L+Random(R-L);
  Move(GetPointerPr^^,Pivot^,GRecLength);
  Pr := Sav;
end;

  procedure QuickSort(L, R : Word);
    {-Non-recursive QuickSort per N. Wirth's "Algorithms and Data Structures"}
  const
    StackSize = 20;
  type
    Stack = array[1..StackSize] of Word;
  var
    Lstack : Stack;          {Pending partitions, left edge}
    Rstack : Stack;          {Pending partitions, right edge}
    StackP : Integer;        {Stack pointer}
  begin
    {Initialize the stack}
    StackP := 1;
    Lstack[1] := L;
    Rstack[1] := R;

    {Repeatedly take top partition from stack}
    repeat
      {Pop the stack}
      L := Lstack[StackP];
      R := Rstack[StackP];
      Dec(StackP);

      {Sort current partition}
      repeat
        {Load the pivot element}
        GetPivot(L,R);
        Pl := L;
        Pr := R;
        {Swap items in sort order around the pivot index}
        repeat
          while ULess(GetPointerPl^^,Pivot^) do
            Inc(Pl);
          while ULess(Pivot^, GetPointerPr^^) do
            Dec(Pr);
          if Pl <= Pr then begin
            if Pl <> Pr then
              {Swap the two elements}
              ExchangePtr(GetPointerPl^,GetPointerPr^);

            if Pl < 65535 then
              Inc(Pl);
            if Pr > 0 then
              Dec(Pr);
          end;
        until Pl > Pr;
        {Decide which partition to sort next}
        if (Pr-L) < (R-Pl) then begin
          {Left partition is bigger}
          if Pl < R then begin
            {Stack the request for sorting right partition}
            Inc(StackP);
            Lstack[StackP] := Pl;
            Rstack[StackP] := R;
          end;
          {Continue sorting left partition}
          R := Pr;
        end else begin
          {Right partition is bigger}
          if L < Pr then begin
            {Stack the request for sorting left partition}
            Inc(StackP);
            Lstack[StackP] := L;
            Rstack[StackP] := Pr;
          end;
          {Continue sorting right partition}
          L := Pl;
        end;

      until L >= R;

    until StackP <= 0;
  end;

procedure QuickSortIt(NLines : Word);
{-calls the non-recursive quicksort}
begin
  QuickSort(1,NLines);
end;

procedure GName(N : Word; var Name : FileName);
{-create a file name in format STEMPxx  where xx is a number}
VAR
  Scratch          : String[8];

begin
  Str(N,Scratch);
  Name := STemp + Scratch;
end;

procedure MakeFile(var F : File; N : Word; Size : LongInt);
{-create a new file}

var
  Name             : PathName;

begin
  GName(N,Name);
  LastFileName := MakePathName(Name);

  Open_OutFile(F,LastFileName,Size);
  BufferPos[0]  := 1;
end;

function GOpen(var InFilePtr : FDBuf; F1,F2 : Word) : LongInt;
{-open files F1 through F2}

var
  Name             : PathName;
  I                : 1..MERGEORDER;
  Size             : LongInt;

begin
  Size := 0;

  for I := 1 to F2-F1+1 do begin
    GName(F1+I-1,Name);
    Name := MakePathName(Name);
    Open_InFile(InFilePtr^[I],Name,I);
    begin
      Size := Size + FileSize(InFilePtr^[I]);
(*code commented out as of 5.22                      !!.22
      MSortIOResult := IOResult;
      if MSortIOResult <> 0 then
        MSortResult := MSortDiskError;
*)
    end;
  end;
  BufferPos[I]  := FileBufferMax + 1;
  BufferSize[I] := FileBufferMax;
  GOpen := Size;
end;

procedure CloseOutFile(var F : File);
{-close an output file (flushing buffers if necessary)}

var
  Size,Num         : Word;

begin
  Size := BufferPos[0] - 1;
  begin
    if Size > 0 then begin
      BlockWrite(F,Buffer[0]^,Size,Num);
      MSortIOResult := IOResult;
      if (MSortIOResult <> 0) or (Num <> Size) then begin
        MSortResult := MSortDiskError;
        if (MSortIOResult = 0) then
          MSortIOResult := -1;
      end;
    end;
    Close(F);
    if MSortIOResult = 0 then begin
      MSortIOResult := IOResult;
      if MSortIOResult <> 0 then
        MSortResult := MSortDiskError;
    end
    else
      if IOResult = 0 then ;
  end;
end;

procedure PutARec(var F : File; var S);
{-put a record to the output File specified as F}

var
  Size,Num         : Word;

begin
  if BufferSize[0] = 0 then begin
  {if we're not buffering the output...}

    begin
      BlockWrite(F,S,GRecLength,Num);
      MSortIOResult := IOResult;
      if (MSortIOResult <> 0) or (Num <> GRecLength) then begin
        MSortResult := MSortDiskError;
        if (MSortIOResult = 0) then
          MSortIOResult := -1;
      end;
    end;
  end
  else begin
  {we are buffering the output}
    Size := BufferPos[0] - 1;
    {see if we need to write out the buffer because its full}
    if LongInt(Size) + GRecLength > BufferSize[0] then begin {!!.40}
      begin
        BlockWrite(F,Buffer[0]^,Size,Num);
        MSortIOResult := IOResult;
        if (MSortIOResult <> 0) or (Num <> Size) then begin
          MSortResult := MSortDiskError;
          if (MSortIOResult = 0) then
            MSortIOResult := -1;
          Exit;
        end;
      end;
      BufferPos[0] := 1;
    end;
    {move the record S into the output buffer}
    Size := BufferPos[0];
    Move(S,Buffer[0]^[Size],GRecLength);
    BufferPos[0] := Size + GRecLength;
  end;
end;

function GetARec(var Line; var F : File; Index : Integer) : Boolean;
{-get a record from the input file F (which is InFilePtr^[Index]) }

var
  Reread,Buffered  : Boolean;
  NumRead          : Word;

begin
  GetARec  := TRUE;

  {Is the Input buffer exhausted, do we need another buffer full?}
  Reread   := BufferPos[Index] + GRecLength - 1 > BufferSize[Index];

  {Are we utilizing an input buffer?}
  Buffered := BufferSize[Index] > 0;
  if Buffered then begin

    if Reread then begin
      {we need a new buffer full}
      begin
        if EOF(F) then begin
          GetARec := FALSE;
          Exit;
        end;
        BlockRead(F,Buffer[Index]^,FileBufferMax,BufferSize[Index]);
        MSortIOResult := IOResult;
        BufferPos[Index] := 1;
      end;
    end;

    {get the record from the input buffers}
    Move(Buffer[Index]^[BufferPos[Index]],Line,GRecLength);
    BufferPos[Index] := BufferPos[Index] + GRecLength;
  end
  else begin
    {no buffering, so read directly}
    if EOF(F) then
      GetARec := FALSE
    else begin
      BlockRead(F,Line,GRecLength);
      MSortIOResult := IOResult;
      if MSortIOResult <> 0 then begin
        MSortResult := MSortDiskError;
        GetARec := FALSE;
      end;
    end;
  end;
end;

procedure GRemove(var InFilePtr : FDBuf; F1,F2 : Word);
{-close the InFiles specified in InFilePtr from F1, F2, and delete them}

var
  Name             : String;
  I                : 1..MERGEORDER;

begin
  for I := 1 to F2-F1+1 do
    begin
      Close(InFilePtr^[I]);
      if IOResult <> 0 then ;  {just clear IOResult}
      Erase(InFilePtr^[I]);
      if IOResult <> 0 then ;  {just clear IOResult}
    end;
end;

function GetARun(var Nlines : Word; var InF : File;
                 II : Word) : Boolean;
{- load an entire run into the Run Buffers, return TRUE if entire Run }
{returned, and FALSE if end of input encountered}

var
  NextPos          : Word;
  Done             : Boolean;

begin
  Nlines  := 0;
  repeat
    Done := (GetARec(TempRec^,InF,II) = FALSE);
    if Not Done then begin
      Inc(NLines);
      NextPos := NLines + 1;
      Pr := NLines;
      Move(TempRec^,GetPointerPr^^,GRecLength);
    end;
  until (Done) or (NLines >= GRunLength);
  GetARun := Done;
end;

procedure PutARun(NLines : Word; var OutFile : File);
{-writes a Run to disk}

var
  I                : Word;

begin
  for I := 1 to NLines do begin
    Pr := I;
    PutARec(OutFile,GetPointerPr^^);
  end;
end;


function PutElement(var X) : Boolean;
{-Submits a record to the sort system.  Returns TRUE is record successfully}
{submitted.}


begin
  if (MSortResult = MSortSuccess) and (NumElements < GFSizeInRecs) then
    PutElement := TRUE
  else begin
    PutElement := FALSE;
    Exit;
  end;

  {if there is still room in RAM, add record to the run buffer, otherwise}
  {sort what's in the run buffer and write out the Run first (flush the  }
  {run), and add the record to the run buffer}
  if (NumElemInRun < GRunLength) then begin
    Inc(NumElemInRun);
    Pr := NumElemInRun;

    Move(X,GetPointerPr^^,GRecLength);
  end
  else begin
    QuickSortIt(NumElemInRun);             {non recursive QS}

    Inc(HighF);
    MakeFile(OutFile,HighF,LongInt(GRunLength)*GRecLength);
    PutARun(NumElemInRun,OutFile);
    CloseOutFile(OutFile);
    NumElemInRun := 1;
    Pr := 1;
    Move(X,GetPointerPr^^,GRecLength);
  end;
  Inc(NumElements);
end;

{this type is used by the Merge System}
type
  MergeItem        = record
                       F  : Word;
                       P  : Pointer;
                       HP : Pointer;
                     end;

{used by Merge System}
var
  MergeList        : Array[1..MERGEORDER] of MergeItem;

procedure Exchange(var Item1,Item2 : MergeItem);
{-exchanges two MergeItems in the MergeList.  Note: The field HP is not}
{exchanged!!!}

begin
  with Item1 do begin
    ExchangePtr(P,Item2.P);
    ExchangeWords(F,Item2.F);
  end;
end;

procedure SortMergeList(NF : Word);
{-simple bubblesort on MergeList.  The MergeList always contains only }
{MERGEORDER elements, so a bubblesort is adequate.}
var
  I,J              : Word;

begin
  for I := NF Downto 2 do
    for J := 1 to I-1 do
      if ULess(MergeList[J+1].P^,MergeList[J].P^) then
        Exchange(MergeList[J+1],MergeList[J]);
end;

procedure ReHeap(NF : Word);
{-make sure first element in MergeList is the smallest}

var
  I,J              : Word;

begin
  i := 1;
  J := 2 * i;
  while (J <= NF) do begin
    if (J < NF) then
      if not ULess(MergeList[J].P^,MergeList[J+1].P^) then
        Inc(J);

    if ULess(MergeList[I].P^,MergeList[J].P^) then
      I := NF
    else
      Exchange(MergeList[I],MergeList[J]);

    I := J;
    J := 2 * I;
  end;
end;

{variables used by the Merge System}
var
  LowF,Lim         : Word;
  NumFiles         : Word;
  LastMerge        : Boolean;
  BottomLoop       : Boolean;
  MergeDone        : Boolean;

function MoreToMerge : Boolean;
{-this routine returns TRUE while there is more data to be merged.  Sets }
{some important merge System variables}
var
  I                : Word;
  MergeSize        : LongInt;

begin
  MoreToMerge := TRUE;
  if BottomLoop and (MSortResult = MSortSuccess) then
    Exit;
  if LowF < HighF then begin

    Lim := Min(LowF+MergeOrder-1,HighF);
    NumFiles := Lim-LowF+1;
    MergeSize := GOpen(InFilePtr,LowF,Lim);
    if MSortResult <> MSortSuccess then begin              {!!.22}
      MoreToMerge := False;                                {!!.22}
      Exit;                                                {!!.22}
    end;                                                   {!!.22}
    Inc(HighF);
    LastMerge := (LowF + MERGEORDER >= HighF);
    if not LastMerge then
      MakeFile(OutFile,HighF,MergeSize);

    for I := 1 to NumFiles do
      with MergeList[I] do begin
        P := HP;
        if GetARec(P^,InFilePtr^[I],I) then
          F := I;
    end;
    SortMergeList(NumFiles);
    BottomLoop := TRUE;
  end
  else
    MoreToMerge := FALSE;
end;

function GetElement(var X) : Boolean;
{-Returns a record from the sort system.  Returns TRUE while there are more}
{ records to return.  When FALSE is returned, the value of the VAR X is    }
{ undefined.}

{This is a complex routine. The Merge Sort Phase, if it is needed, is      }
{actually performed here. The merging technology used by this program is   }
{somewhat complicated, due to two factors: The fact that the source of the }
{input and destination of the output is unknown to the Sort routines.      }
{The final merge of the data is not performed to disk, but is actually     }
{performed to the output stream (this limits the amount of disk space and  }
{time needed by the merge sort).}


const
  LBP              = 1;

var
  FIndex           : Word;
  Error            : Boolean;

begin
  Error := FALSE;
  if (not MergeDone) and (MSortResult = MSortSuccess) then
    GetElement := TRUE
  else begin
    GetElement := FALSE;
    Exit;
  end;
  if AllInMem then begin
  {if the sort is being performed entirely in memory, then just return the}
  {next element in the run buffer.}
    if ElementCount > 0 then begin
      Pr := NumElements - (ElementCount-1);
      Move(GetPointerPr^^,X,GRecLength);
      Dec(ElementCount);
    end
    else
      GetElement := FALSE;
  end
  else
  {not all in memory, so perform the special merge sort technique}
    repeat
      if MoreToMerge and (MSortResult = MSortSuccess) then begin
        if LastMerge then
          Move(MergeList[LBp].P^,X,GRecLength)
        else
          PutARec(OutFile,MergeList[LBp].P^);
        FIndex := MergeList[LBp].F;
        if not GetARec(TempRec^,InFilePtr^[FIndex],FIndex) then begin
          {InFilePtr^[FIndex] is exhausted, so decrement num files}
          Exchange(MergeList[LBp],MergeList[NumFiles]);
          Dec(NumFiles);
          if NumFiles = 0 then begin
            if LastMerge then
              MergeDone := TRUE
            else begin
              BottomLoop := FALSE;
              CloseOutFile(OutFile);
            end;
            GRemove(InFilePtr,LowF,Lim);
            LowF := LowF + MergeOrder;
          end;
        end
        else
          with MergeList[1] do begin
            Move(TempRec^,P^,GRecLength);
            F := FIndex;
          end;
        ReHeap(NumFiles);
      end
      else
        GRemove(InFilePtr,LowF,Lim);
      Error := (MSortResult <> MSortSuccess);
    until LastMerge or Error;
    if Error then begin
      GetElement := FALSE;
    end;
end;

procedure MergeSort;
{-this procedure calls the user routine to retrieve the sorted elements.  If }
{a merge phase is required, it is performed during the calls to GetElement   }
{(see the comments in GetElement above). }
var
  I                : Word;

begin
  {If not all in memory, then allocate the I/O buffers}
  if not AllinMem then begin
    AllocIOBuffers;

    {allocate the memory for the MergeList data}
    for I := 1 to MERGEORDER do
      with MergeList[I] do
        GetMem(HP,GRecLength);
  end;

  {initialize some important sort system variables}
  LowF := 1;
  LastMerge := FALSE;
  BottomLoop := FALSE;
  MergeDone  := FALSE;

  {call the user routine if everything is kosher}
  if MSortResult = MSortSuccess then
    CallPutElements;

  if not AllInMem then begin
    {free the memory used by the MergeList data}
    for I := 1 to MERGEORDER do
      FreeMem(MergeList[I].HP,GRecLength);

    {if I/O buffers were allocated, then free them}
    DeallocIOBuffers;
  end;
end;


function DoSort(RunLength     : Word;
                RecLength     : Word;
                InFileBufMax  : Word;
                OutFileBufMax : Word;
                TempPath      : PathName;
                GetElements   : Pointer;
                LessFunc      : Pointer;
                PutElements   : Pointer
               ) : MSortStatus;

{-the lowest level sorting routine.  This function sorts the elements.  It }
{calls the user GetElements routine to get the elements to be sorted, calls}
{the LessFunc to compare the items, and calls the user PutElements         }
{procedure upon completion.}


Label ExitPoint,FinalExitPoint;

        {!!.06}

begin
  UsingEMS       := False;     {!!.40}

  {Allocate the InFilePtr data structure}

  GetMem(InFilePtr,SizeOf(InFilePtr^));              {!!.03}

  {assume success}
  MSortResult   :=  MSortSuccess;

  {set some global variables needed by the sort system}
  GRecLength   := RecLength;
  GRunLength   := RunLength;
  if (TempPath <> '') and
     not (TempPath[Length(TempPath)] in ['\', '/']) then
    GTempPath := TempPath + DirectorySeparator
  else
    GTempPath := TempPath;

  UserLess     := LessFunc;
  UserGet      := GetElements;
  UserPut      := PutElements;

  {calculate the Run Pointer Buffer size}
  PtrBufLength := LongInt(RunLength) * SizeOf(Pointer);

  {ensure that buffer is an appropriate size}
  OutBufSize   := (OutFileBufMax DIV RecLength) * RecLength;

  {Allocate space for two elements on heap}
  GetMem(Pivot,GRecLength);
  GetMem(TempRec,GRecLength);

  {get memory for output buffer and set buffer variables}
  if OutBufSize > 0 then begin
    GetMem(Buffer[0],OutBufSize);
    if Buffer[0] = NIL then begin
      MSortResult := MSortOutOfMemory;
      Goto FinalExitPoint;
    end;
  end;
  BufferPos[0]  := OutBufSize + 1;
  BufferSize[0] := OutBufSize;

  {figure out InFilePtr buffer size}
  FileBufferMax := ((InFileBufMax DIV MERGEORDER) DIV RecLength)
                   * RecLength;

  NumElements  := 0;
  NumElemInRun := 0;
  HighF        := 0;

  {allocate the memory needed to store a Run in RAM}
  AllocRunBuffers;

  {if error then exit}
  if MSortResult <> MSortSuccess then
    Goto FinalExitPoint;

  {call the user routine to get the elements into the sort system}
  CallGetElements;

  {check to see if all the records fit in RAM}
  if (NumElements <= GRunLength) then                        {!!.05}
    AllInMem := TRUE;                                        {!!.05}

  if (MSortResult <> MSortSuccess) or (NumElements = 0) then {!!.04}
    Goto ExitPoint;                      {if error then exit}

  {Sort the run currently in RAM}
  QuickSortIt(NumElemInRun);
  {If there's more than just that run, then output it in preparation for}
  {merge phase}
  if (not AllInMem) and (MSortResult = MSortSuccess) then begin
    Inc(HighF);
    MakeFile(OutFile,HighF,LongInt(GRunLength)*GRecLength);
    PutARun(NumElemInRun,OutFile);
    CloseOutFile(OutFile);
    DeallocRunBuffers;
  end;

  if MSortResult <> MSortSuccess then
    Goto ExitPoint;

  ElementCount := NumElements;

  {Do the merge sort logic}
  MergeSort;

ExitPoint:
  if AllInMem then
    DeallocRunBuffers;

  AllInMem := FALSE;


  FreeMem(Buffer[0],OutBufSize);

  FreeMem(TempRec,GRecLength);
  FreeMem(Pivot,GRecLength);
  FreeMem(InFilePtr,SizeOf(InFilePtr^));            {!!.03}

FinalExitPoint:
  DoSort := MSortResult;
                                      {!!.06}
end;

function FreeDiskSpace(Path : PathName) : LongInt;
{-returns number of bytes free on the disk holding Path (formerly a DOS
  drive number), at most MaxLongInt; -1 on error}
var
  Free : Int64;
{$IFDEF MSWINDOWS}
  Avail, Total, TotalFree : Int64;
  P : AnsiString;
{$ENDIF}
{$IFDEF UNIX}
  Info : TStatFS;
  P : AnsiString;
{$ENDIF}
begin
  FreeDiskSpace := -1;
  P := Path;
  if P = '' then
    P := '.';
{$IFDEF MSWINDOWS}
  if not GetDiskFreeSpaceExA(PChar(P), Avail, Total, @TotalFree) then
    Exit;
  Free := Avail;
{$ENDIF}
{$IFDEF UNIX}
  if fpStatFS(PChar(P), @Info) <> 0 then
    Exit;
  Free := Int64(Info.bavail) * Int64(Info.bsize);
{$ENDIF}
  if Free > MaxLongInt then
    Free := MaxLongInt;
  FreeDiskSpace := Free;
end;

const
  BUFSLICE         = 14;


{$I msortinf.inc} {The AutoSortInfo routine}


function AutoSort(FSizeInRecs : LongInt;
                  RecLength   : Word;
                  TempPath    : PathName;
                  GetElements : Pointer;
                  LessFunc    : Pointer;
                  PutElements : Pointer
                 ) : MSortStatus;

{-this is the high level sort routine. Similar to DoSort, except it}
{calculates optimum sizes for the sort parameters and checks for   }
{sufficient resources before attempting sort.  Calls AutoSortInfo  }
{to calculate sort parameters.}

var
  RunLen,FileBufs,OutFileBufs
                   : Word;
  FileHands,EMSPgs : Word;
  HeapSp,DiskSp    : LongInt;

function ResourcesAvailable : Boolean;

var
  DiskSpaceFree    : LongInt;

begin
  ResourcesAvailable := FALSE;
  DiskSpaceFree   := FreeDiskSpace(TempPath);
  if AllInMem or (DiskSpaceFree >= DiskSp) then
    ResourcesAvailable := TRUE

end;

var
  Res              : MSortStatus;
begin

  Res := AutoSortInfo(FSizeInRecs,RecLength,HeapSp,DiskSp,FileHands,
                      EMSPgs,RunLen,FileBufs,OutFileBufs,AllInMem);

  if Res = MSortSuccess then begin
    if ResourcesAvailable then begin
      GFSizeInRecs := FSizeInRecs;
      AutoSort := DoSort(RunLen,RecLength,FileBufs,OutFileBufs,TempPath,
                  GetElements,LessFunc,PutElements);
      GFSizeInRecs := MaxLongInt;
    end
    else
      AutoSort := MSortOutOfDisk;
  end
  else
    AutoSort := Res;

end;

procedure AbortSort;
{-Prematurely halt the sort from the user defined routines}
begin
   MSortResult := MSortUserAbort;
end;

begin
  UsingEMS := False;
end.

