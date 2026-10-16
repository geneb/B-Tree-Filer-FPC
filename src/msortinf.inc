{*********************************************************}
{*                  MSORTINF.INC 5.41                    *}
{*        Copyright (c) TurboPower Software 1989.        *}
{*                 All rights reserved.                  *}
{*********************************************************}

const
  SIZETYPEMAX      = 16380;

type
  SizeType         = Array[1..SIZETYPEMAX] of Word;
  SizeTypePtr      = ^SizeType;

function AutoSimulate(SizeInBytes : LongInt; WillUseEMS : Boolean;
                      RunLen,RecLen : Word;
                      var EMSPagesUsed : Word; var Hands : Word) : LongInt;
{-Calculates the amount of disk space needed by simulating the merge process.}
{Accounts for EMS usage (by calling AnalyzeEMS). Since the final merge pass  }
{is not merged to disk, it is not counted. This routine sets up a size table }
{on the heap, and simulates the merge process updating the size table as it  }
{goes. The sum of the largest files existing on disk simultaneously is       }
{calculated, and this is the largest amount of disk space needed during the  }
{merge.}

{If an error occurs, this function will return -1, otherwise the amount of   }
{disk space needed in bytes is returned. }

var
  STSize           : Word;
  MaxST            : Word;
  Files,Peak,Curr  : Word;
  F,HighF,CurF     : Word;
  I                : Word;
  NewSize          : Word;
  AS               : LongInt;
  SizeTable        : SizeTypePtr;

begin
  AutoSimulate := 0; {assume we need no disk space}

  {this tells us the number of files created by splitting the input into}
  {separate files of RunLen}
  F := Word((SizeInBytes DIV RecLen) + RunLen - 1) DIV RunLen;
  Files := F;
  HighF := F;
  CurF  := 1;

  {Figure out the number of file handles we need.  This would never be more}
  {than MERGEORDER + 1}
  if F >= MERGEORDER then
    Hands := MERGEORDER
  else
    Hands := F;
  Inc(Hands);   {add one for output file}

  StSize := SIZETYPEMAX * SizeOf(Word);

  if MaxAvail < (SIZETYPEMAX * SizeOf(Word)) then
    StSize := Word(MaxAvail DIV SizeOf(Word)) * SizeOf(Word);

  MaxST := STSize DIV SizeOf(Word);

  GetMem(SizeTable,StSize);
  FillWord(SizeTable^,MaxST,1);

  while Files > MERGEORDER do begin
    Inc(HighF);                             {increment the high file index}
    if HighF > MaxSt then begin
      {we have run out of space in the SizeTable, so exit}
      AutoSimulate := -1; {indicate that we were unable to calculate size}
      Exit;
    end;

    NewSize := 0;

    {calculate the size of the file created by merging these five files}
    for I := CurF to CurF + MERGEORDER - 1 do
      NewSize := NewSize + SizeTable^[I];

    SizeTable^[HighF] := NewSize;           {set the size of the high file}
    Files := (Files - MERGEORDER) + 1;      {decrement the files}
    CurF  := CurF + MERGEORDER;
  end;
  Peak  := 0;

  for I := CurF - MERGEORDER to HighF do
    Peak := Peak + SizeTable^[I];


  AS := LongInt(Peak) * LongInt(RunLen) * LongInt(RecLen);
  if AS < SizeInBytes then
    AS := SizeInBytes;

  EMSPagesUsed := 0;   {EMS is not available}

  FreeMem(SizeTable,StSize);

  AutoSimulate := AS;
end;

  Function RoundToGranul ( Value : Word ) : Word;
    {-Rounds Value up to the next multiple of 8}
  Begin
    RoundToGranul := (Value + 7) And $FFF8;
  End;

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
label
  ExitPoint;
var
  TotalNeeded,Avail,PBufLen,Temp,DiskSpaceNeeded,DiskSpaceFree,MaxAv
                   : LongInt;
  EMSToBeUsed      : Boolean;
                               {!!.06}
  SaveRecLen       : Word;
                                   {!!.06}
  FreeListSize     : LongInt;


begin
  AutoSortInfo := MSortSuccess;
                                     {!!.06}

  SaveRecLen := RecLength;
  RecLength  := RoundToGranul(RecLength);
  EMSToBeUsed  := False;   {EMS is not available}
  {calculate optimum buffer sizes for RecBuf and I/O buffers}
  FreeListSize := 0;
  MaxAv := MaxAvail;
  if MaxAv > MaxHeapToUse then
    MaxAv := MaxHeapToUse;
  HeapSpace   := MaxAv;               {!!.02}
  Avail       := MaxAv
                 - (2*RecLength)
                 - SizeOf(InFilePtr^)  {!!.04}
                                      {!!.06}
                 - UserFree;

  if Avail <= 0 then begin
    AutoSortInfo := MSortOutOfMemory;
    goto ExitPoint;                    {!!.04}
  end;

  PBufLen:= (LongInt(FSizeInRecs) * SizeOf(Pointer)) + 15;  {!!.04}

  TotalNeeded  := (LongInt(FSizeInRecs+MERGEORDER) * RecLength) + PBufLen;

  if (TotalNeeded < Avail) and (FSizeInRecs < BiggestDataItem) then begin
    {entire file will fit in memory, so no need for I/O buffers}
    AllInMem    := TRUE;
    FileBufs    := 0;
    RunLen      := FSizeInRecs;
    Temp        := Avail - TotalNeeded;
    if Temp > BiggestDataItem then
      Temp := BiggestDataItem;

    OutFileBufs := Temp;
  end
  else begin
    {file won't fit in mem, so pick sizes for RunLen and FileBufs}
    AllInMem     := FALSE;
    Temp         := (Avail DIV BUFSLICE);
    if Temp > BiggestDataItem then
      Temp := BiggestDataItem
    else if Temp < RecLength then
      Temp := 0;

    OutFileBufs  := Temp;
    Avail        := Avail - OutFileBufs;
    Temp         := (Avail DIV (SizeOf(Pointer)+RecLength));
    if Temp > LongInt(MAXRUNLENGTH) then
      Temp := MAXRUNLENGTH;
    RunLen := Word(Temp);

    Temp         := LongInt(OutFileBufs) * 5;             {!!.02}
    if Temp > BiggestDataItem then
      Temp := BiggestDataItem;
    FileBufs := Temp;
  end;
  RecLength := SaveRecLen;
  DiskSpace := AutoSimulate(FSizeInRecs * RecLength,EMSToBeUsed,
                            RunLen,RecLength,
                            EMSPages,FileHandles);
ExitPoint:
                                      {!!.06}
end;

