{*********************************************************}
{*                   BROWSER.PAS 5.41                    *}
{*   Copyright (c) Dipl.Math. Ralf Nagel 1986-1990.      *}
{*   Copyright (c) Enz EDV Beratung GmbH 1989-1990.      *}
{*                 All rights reserved.                  *}
{*          Modified and used under license by           *}
{*                 TurboPower Software.                  *}
{*********************************************************}

{--Conditional defines and compiler options}
{$I btdefine.inc}
{$F+,V-,B-,S-,I-,R-}
  {$Q-}

unit Browser;

interface

{Free Pascal port: uses the Crt unit of Free Pascal on Windows and Linux.
 The support for the TPCRT/OPCRT and mouse units of Turbo Professional and
 Object Professional has been removed. The user routines are called through
 the procedure types declared below instead of inline machine code.}

uses
  SysUtils,
  TpCmd,
  Crt,
  Filer,
  VRec;

const
  MinRows = 4;                    {Minimum number of usable lines on the screen}
  MaxRows = 20;                   {Maximum number of usable lines on the screen}
  MaxCols = 128;                  {Number of usable columns on screen, must be <= 255}

  {Number of retries for a read operation in case of a Lock-Error}
  RetriesOnLock : Integer = 50;

  {True lets browser go to disk less often, safe only for single user mode}
  NoNetMode : Boolean = False;

  {If True, Browser will use read locks while building its pages}
  UseReadLock : Boolean = False;

  {If False, the data record will not be read prior to calling BuildARow}
  ReadDataRecord : Boolean = True;

var
  BrowseYL : Byte;
  BrowseYH : Byte;

type
  RowRec =
    record
      IKS : IsamKeyStr;
      Ref : LongInt;
      Row : string[MaxCols];
    end;
  {Basic type of the browser. The browser is used in three steps:
   1) <IKS> and <Ref> are allocated.
   2) <ProcBuildaRow> (procedure parameter) determines the row.
   3) <ProcDisplayaRow> (procedure parameter) puts <Row> on the screen}

  {----------------- programmer's hooks -------------}
var
  BrowseKeyPtr : Pointer;      {pointer to routine to return next keystroke}
  BrowseHelpPtr : Pointer;     {pointer to routine to display help}
  BrowseHelpIndex : Word;      {current help topic}

  {.F-}
const
  BKnone      = 00; {Not a command}
  BKchar      = 01; {Regular character--not a command}
  BKenter     = 02; {Select}
  BKquit      = 03; {Escape}
  BKfirstRec  = 04; {Cursor to first record}
  BKlastRec   = 05; {Cursor to last record}
  BKleft      = 06; {Cursor left one column}
  BKright     = 07; {Cursor right one column}
  BKup        = 08; {Cursor up one row}
  BKdown      = 09; {Cursor down one row}
  BKpageUp    = 10; {Cursor up one page}
  BKpageDown  = 11; {Cursor down one page}
  BKplus      = 12; {Reread current record}
  BKhelp      = 13; {Invoke help routine}
  BKredraw    = 14; {redraw the browse screen}
  BKprobe     = 15; {signals a mouse event}
  BKRowEnd    = 16; {command to go to end of row}
  BKRowBegin  = 17; {comamnd to go to start of row}

  BKtask0     = 18; {user-defined task commands}
  BKtask1     = 19;
  BKtask2     = 20;
  BKtask3     = 21;
  BKtask4     = 22;
  BKtask5     = 23;
  BKtask6     = 24;
  BKtask7     = 25;
  BKtask8     = 26;
  BKtask9     = 27;
  BKuser0     = 28; {user-defined exit commands}
  BKuser1     = 29;
  BKuser2     = 30;
  BKuser3     = 31;
  BKuser4     = 32;
  BKuser5     = 33;
  BKuser6     = 34;
  BKuser7     = 35;
  BKuser8     = 36;
  BKuser9     = 37;

type
  BKtype = BKnone..BKuser9;

  {Types of the user routines passed as pointers}
  BrowseBuildRowProc = procedure(var RR : RowRec;
                                 KeyNr : Integer;
                                 var DatS;
                                 DatLen : Word);
  BrowseDisplayRowProc = procedure(var RR : RowRec;
                                   KeyNr,
                                   RowNr,
                                   StartRow : Integer;
                                   HighLight : Boolean;
                                   var HorizOfs : Integer);
  BrowseSpecialTaskProc = procedure(IFBPtr : IsamFileBlockPtr;
                                    var DatS;
                                    Ref : LongInt;
                                    IKS : IsamKeyStr;
                                    KeyNr : Integer;
                                    var Command : BKtype;
                                    var ExitCode : Integer;
                                    DatLen : Word);
  BrowseValidateFunc = function(IFBPtr     : IsamFileBlockPtr;
                                KeyNr      : Integer;
                                Ref        : LongInt;
                                var KeyStr : IsamKeyStr;
                                NetUsed    : Boolean) : Boolean;
  BrowseRefreshFunc = function(IFBPtr : IsamFileBlockPtr;
                               KeyNo : Integer) : Boolean;
  BrowseKeyFunc = function : Word;
  BrowseHelpProc = procedure(UnitCode : Byte; IdPtr : Pointer;
                             HelpIndex : Word);
const
    HelpForBrowse = 7;

  {Keystroke to command mapping}
  BrowseKeyMax = 200;   {last available slot in BrowseKeySet}

  {ID string for installation programs}
  BrowseKeyID : string[17] = 'browser key array';

  {default key assignments}
  BrowseKeySet : array[0..BrowseKeyMax] of Byte = (
   {length keys         command type     key sequence}
    3,     $00, $00,    BKquit,          {^Break}
    3,     $00, $3B,    BKhelp,          {F1}
    3,     $00, $47,    BKfirstRec,      {Home}
    3,     $00, $48,    BKup,            {Up}
    3,     $00, $49,    BKpageUp,        {PgUp}
    3,     $00, $4B,    BKleft,          {Left}
    3,     $00, $4D,    BKright,         {Right}
    3,     $00, $4F,    BKlastRec,       {End}
    3,     $00, $50,    BKdown,          {Down}
    3,     $00, $51,    BKpageDown,      {PgDn}
    3,     $00, $76,    BKlastrec,       {^PgDn}
    3,     $00, $84,    BKfirstrec,      {^PgUp}
    2,     $03,         BKpageDown,      {^C}
    2,     $04,         BKright,         {^D}
    2,     $05,         BKup,            {^E}
    2,     $0D,         BKenter,         {^M, Enter}
    2,     $12,         BKpageUp,        {^R}
    2,     $13,         BKleft,          {^S}
    2,     $17,         BKup,            {^W}
    2,     $18,         BKdown,          {^X}
    2,     $1A,         BKdown,          {^Z}
    2,     $1B,         BKquit,          {Esc}
    2,     $2B,         BKplus,          {+}
    3,     $11, $03,    BKlastrec,       {^Q^C}
    3,     $11, $12,    BKfirstrec,      {^Q^R}
    {-----------pad to end of array----------}
                            0, 0,        {90}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,        {100}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,        {110}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,        {120}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,        {130}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,        {140}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,        {150}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,        {160}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,        {170}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,        {180}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,        {190}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0);       {200}
{.F+}

  RowsToJump : Integer = 0;


  RefreshFunc  : Pointer = Nil; {Ptr to refresh function}         {!!.06}

function Browse(IFBPtr : IsamFileBlockPtr;
                VarRec : Boolean;
                KeyNr : Integer;
                LowKey : IsamKeyStr;
                HighKey : IsamKeyStr;
                StartScreenRow : Integer;
                NrOfRows : Integer;
                var DatS;
                var DatLen : Word;
                var Ref : LongInt;
                var KeyStr : IsamKeyStr;
                var ExitKey : BKtype;
                ProcSpecialTask : Pointer;
                ProcBuildaRow : Pointer;
                ProcDisplayaRow : Pointer) : Integer;
    {-A list is created with the corresponding keys from <LowKey> to <HighKey>
      inclusive and their data structures.

      The parameter <VarRec> must be true for variable record lengths
      (otherwise false).

      The display starts at the row <StartScreenRow> and entails <NrOfRows>
      rows. <NrOfRows> may not be less than 4.

      <DatS> is a buffer for the data structure.

      <DatLen> contains the length of the current variable length record only
      if <VarRec> is true.

      <ExitKey> returns the code for the command that exited the Browser. In
      addition this determines the first action the Browser should perform.
      BKnone (Byte 0) must be passed if no action is to be performed.

      The procedures whose addresses are passed through the pointer-parameters
      <ProcBuildaRow> and <ProcDisplayaRow> are used to create and display a
      row. These procedures must be supplied by the user of Browser and must
      be declared as in the example procedure definition. These procedures
      must be declared as "FAR." This is either done through the use of the
      compiler directive $F+, or through the exportation from another Unit.
      Handling it in any other way will produce a program crash.

      There are three possible return values:
        0: No error encountered.
           <ExitKey> = BKquit  : Esc was pressed.
           <ExitKey> <> BKquit : <DatS> contains the data structure,
                                 <Ref> the corresponding reference,
                                 <KeyStr> the chosen key.
        1: There were no keys available that were in the requested range.
        2: Hard Error by Isam-Access (Class 2 or higher).

      Browser has the following default actions for each command:
        BKquit     : exit Browser without making a selection
        BKenter    : exit Browser making a choice
        BKfirstRec : scroll to the first data structure
        BKlastRec  : scroll to the last data structure
        BKpageUp   : scroll back a page
        BKpageDown : scroll forward a page
        BKup       : scroll up a row
        BKdown     : scroll down a row

      If <ProcDisplayaRow> points to a procedure that makes use of the
      parameter <HorizOfs>, horizontal scrolling is available through the
      following commands:
        BKleft  : Move the display window towards the left
        BKright : Move the display window towards the right.}

function BrowseAgain(IFBPtr : IsamFileBlockPtr;
                     VarRec : Boolean;
                     KeyNr : Integer;
                     LowKey : IsamKeyStr;
                     HighKey : IsamKeyStr;
                     StartScreenRow,
                     NrOfRows : Integer;
                     var HighlightedRow : Integer;
                     var HorizOfs : Integer;
                     var DatS;
                     var DatLen : Word;
                     var Ref : LongInt;
                     var KeyStr : IsamKeyStr;
                     var ExitKey : BKtype;
                     ProcSpecialTask : Pointer;
                     ProcBuildaRow : Pointer;
                     ProcDisplayaRow : Pointer) : Integer;
  {-Same as Browse, except takes a value for the row to position the highlight
    bar on initially. If <HighlightedRow> if 0, then the browser will position
    the scroll bar for you. Otherwise <HighlightedRow> must be between 1 and
    <NrOfRows>. The value <HorizOfs> is also passed. This value is passed to
    the user procedure <ProcDislayaRow> to indicate the horizontal offset of
    the line.}

function AddBrowseCommand(Cmd : BKtype; NumKeys : Byte; Key1, Key2 : Word) : Boolean;
  {-Add a new command key assignment or change an existing one}

function BrowseReadKey : Word;
  {-Return next keystroke as a word}

procedure EnableFiltering(ValidateFunc : Pointer);
  {-Enables Browser filtering. <ValidateFunc> is a pointer to a user defined
    function that determines whether a given record should be displayed in the
    Browser. The <ValidateFunc> must be a FAR, non-nested function declared as
    follows:

    function ValidateARecord(IFBPtr     : IsamFileBlockPtr;
                             KeyNr      : Integer;
                             Ref        : LongInt;
                             var KeyStr : IsamKeyStr;
                             NetUsed    : Boolean) : Boolean;
  }

procedure DisableFiltering;
  {-Disables Browser filtering. Has no effect if filtering is not enabled.}

function IsFilteringEnabled : Boolean;
  {-Returns True if Browser filtering is enabled.}


{!!.06 begin}
function RefreshAtEachCommand(IFBPtr : IsamFileBlockPtr;
                              KeyNo : Integer) : Boolean;
  {-Check for need to refresh before each command if no keystrokes pending}

const
  RefreshPeriod : Word = 90; {about 5 seconds}

function RefreshPeriodically(IFBPtr : IsamFileBlockPtr;
                             KeyNo : Integer) : Boolean;
  {-Check for need to refresh every RefreshPeriod clock ticks}
{!!.06 end}
  {=========================================================================}

implementation


const
  RepositionDesired : Boolean = False;
  FilterState       : Boolean = False;

  {------------- Browser filtering hooks ------------}
const
  SearchKeyPtr      : Pointer = Nil;
  NextKeyPtr        : Pointer = Nil;
  PrevKeyPtr        : Pointer = Nil;
  FindKeyAndRefPtr  : Pointer = Nil;
  ValidatePtr       : Pointer = Nil;

type
  RowRange   = 1..MaxRows;
  BrowScreenType = array[RowRange] of RowRec;

var
  CurRow     : RowRange;
  gHighKey   : IsamKeyStr;                 {!!.22}
  gLowKey    : IsamKeyStr;                 {!!.22}

type
  BrowseKeyRoutine = procedure(IFBPtr         : IsamFileBlockPtr;
                               KeyNr          : Integer;
                               var DatRef     : LongInt;
                               var KeyStr     : IsamKeyStr;
                               Net            : Boolean);
  BrowseFindKeyRoutine = procedure(IFBPtr         : IsamFileBlockPtr;
                                   KeyNr          : Integer;
                                   var DatRef     : LongInt;
                                   var KeyStr     : IsamKeyStr;
                                   NFSD           : Integer;
                                   Net            : Boolean);

  procedure HelpRoutine(UnitCode : Byte; IdPtr : Pointer; HelpIndex : Word);
    {-Call routine pointed to by BrowseHelpPtr}
  begin
    BrowseHelpProc(BrowseHelpPtr)(UnitCode, IdPtr, HelpIndex);
  end;

  function GetKey : Word;
    {-Call routine pointed to by BrowseKeyPtr}
  begin
    GetKey := BrowseKeyFunc(BrowseKeyPtr);
  end;

  function KeyInBounds(KeyStr : IsamKeyStr) : Boolean;    {!!.22 moved}
  begin
    KeyInBounds := False;
    if Copy(KeyStr, 1, Length(gLowKey)) < gLowKey then    {!!.22}
      Exit;
    if Copy(KeyStr, 1, Length(gHighKey)) > gHighKey then  {!!.22}
      Exit;
    KeyInBounds := True;
  end;

  function BrowseReadKey : Word;
    {-Return next keystroke as a word}
  var
    Ch : Char;
  begin
    Ch := ReadKey;
    if Ch <> #0 then
      BrowseReadKey := Ord(Ch)
    else
      BrowseReadKey := Word(Ord(ReadKey)) shl 8;
  end;


  function Validate(IFBPtr     : IsamFileBlockPtr;
                    Key        : Integer;
                    Ref        : LongInt;
                    var KeyStr : IsamKeyStr;
                    NetUsed    : Boolean) : Boolean;
  begin
    Validate := BrowseValidateFunc(ValidatePtr)(IFBPtr, Key, Ref, KeyStr,
                                                NetUsed);
  end;

  {$F+}
  procedure Next_Key(IFBPtr         : IsamFileBlockPtr;
                     Key            : Integer;
                     var UserDatRef : LongInt;
                     var UserKey    : IsamKeyStr;
                     NetUsed        : Boolean);
  var
    RT : Integer;
  begin
    RT := 0;
    repeat
      BTNextKey(IFBPtr, Key, UserDatRef, UserKey);
      Inc(RT);
    until (RT >= RetriesOnLock) or (BTIsamErrorClass <> 2);
  end;

  procedure Search_Key(IFBPtr         : IsamFileBlockPtr;
                       Key            : Integer;
                       var UserDatRef : LongInt;
                       var UserKey    : IsamKeyStr;
                       NetUsed        : Boolean);
  var
    RT : Integer;
  begin
    RT := 0;
    repeat
      BTSearchKey(IFBPtr, Key, UserDatRef, UserKey);
      Inc(RT);
    until (RT >= RetriesOnLock) or (BTIsamErrorClass <> 2);
  end;

  procedure Prev_Key(IFBPtr : IsamFileBlockPtr;
                     Key : Integer;
                     var UserDatRef : LongInt;
                     var UserKey : IsamKeyStr;
                     NetUsed        : Boolean);
  var
    RT : Integer;
  begin
    RT := 0;
    repeat
      BTPrevKey(IFBPtr, Key, UserDatRef, UserKey);
      Inc(RT);
    until (RT >= RetriesOnLock) or (BTIsamErrorClass <> 2);
  end;

  procedure Find_Key(IFBPtr         : IsamFileBlockPtr;
                     Key            : Integer;
                     var UserDatRef : LongInt;
                     var UserKey    : IsamKeyStr;
                     NFSD           : Integer;
                     NetUsed        : Boolean);
  var
    RT : Integer;

  begin
    RT := 0;
    repeat
      BTFindKeyAndRef(IFBPtr, Key, UserDatRef, UserKey, NFSD);
      Inc(RT);
    until (RT >= RetriesOnLock) or (BTIsamErrorClass <> 2);
  end;

  procedure FilterNextKey(IFBPtr         : IsamFileBlockPtr;
                          Key            : Integer;
                          var UserDatRef : LongInt;
                          var UserKey    : IsamKeyStr;
                          NetUsed        : Boolean);
  var
    Done : Boolean;
  begin
    Next_Key(IFBPtr, Key, UserDatRef, UserKey, NetUsed);
    Done := False;                                         {!!.22 begin}
    while IsamOK and (not Done) and KeyInBounds(UserKey) do begin
      Done := Validate(IFBPtr, Key, UserDatRef, UserKey, NetUsed);
      if (not Done) and IsamOK then
        Next_Key(IFBPtr, Key, UserDatRef, UserKey, NetUsed);
    end;                                                   {!!.22 end}
  end;

  procedure FilterSearchKey(IFBPtr         : IsamFileBlockPtr;
                            Key            : Integer;
                            var UserDatRef : LongInt;
                            var UserKey    : IsamKeyStr;
                            NetUsed        : Boolean);
  var
    Done : Boolean;
  begin
    Search_Key(IFBPtr, Key, UserDatRef, UserKey, NetUsed);
    Done := False;                                         {!!.22 begin}
    while IsamOK and (not Done) and KeyInBounds(UserKey) do begin
      Done := Validate(IFBPtr, Key, UserDatRef, UserKey, NetUsed);
      if (not Done) and (IsamOK) then
        Next_Key(IFBPtr, Key, UserDatRef, UserKey, NetUsed);
    end;                                                   {!!.22 end}
    if BTIsamErrorClass = 1 then
      IsamError := 10210;
  end;

  procedure FilterPrevKey(IFBPtr : IsamFileBlockPtr;
                          Key : Integer;
                          var UserDatRef : LongInt;
                          var UserKey : IsamKeyStr;
                          NetUsed        : Boolean);
  var
    Done : Boolean;
  begin
    Prev_Key(IFBPtr, Key, UserDatRef, UserKey, NetUsed);
    Done := False;                                         {!!.07}
    while IsamOK and (not Done) and KeyInBounds(UserKey) do begin
      Done := Validate(IFBPtr, Key, UserDatRef, UserKey, NetUsed);
      if (not Done) and IsamOK then
        Prev_Key(IFBPtr, Key, UserDatRef, UserKey, NetUsed);
    end;                                                   {!!.07}
  end;

  procedure FilterFindKey(IFBPtr         : IsamFileBlockPtr;
                          Key            : Integer;
                          var UserDatRef : LongInt;
                          var UserKey    : IsamKeyStr;
                          NFSD           : Integer;
                          NetUsed        : Boolean);
  var
    Done : Boolean;
  begin
    Find_Key(IFBPtr, Key, UserDatRef, UserKey, NFSD, NetUsed);
    Done := False;                                         {!!.22 begin}
    while IsamOK and (not Done) and KeyInBounds(UserKey) do begin
      Done := Validate(IFBPtr, Key, UserDatRef, UserKey, NetUsed);
      if (not Done) and (IsamOK) then
        case NFSD of
          0 : begin {no direction}
                IsamOK := False;
                IsamError := 10270;
              end;
          1 : Next_Key(IFBPtr, Key, UserDatRef, UserKey, NetUsed);
          else
            Prev_Key(IFBPtr, Key, UserDatRef, UserKey, NetUsed);
        end;
    end;                                                   {!!.22 end}
  end;

  {$F-}

  {$I browser.inc}    {include the BrowseI function}

  {The cursor shape was read and set through the video BIOS (INT 10h);
   the Crt unit can only switch the cursor on and off}
  function GetCursorMode : Word;
  begin
    GetCursorMode := $0607;   {normal cursor}
  end;

  procedure SetCursorMode(Mode : Word);
  begin
    if Mode and $2000 <> 0 then
      CursorOff
    else
      CursorOn;
  end;


  function Browse(IFBPtr : IsamFileBlockPtr;
                  VarRec : Boolean;
                  KeyNr : Integer;
                  LowKey : IsamKeyStr;
                  HighKey : IsamKeyStr;
                  StartScreenRow,
                  NrOfRows : Integer;
                  var DatS;
                  var DatLen : Word;
                  var Ref : LongInt;
                  var KeyStr : IsamKeyStr;
                  var ExitKey : BKtype;
                  ProcSpecialTask : Pointer;
                  ProcBuildaRow : Pointer;
                  ProcDisplayaRow : Pointer) : Integer;
  var
    SaveTextAttr : Byte;
    SaveCursor : Word;
    SaveSFS : Boolean;
    SaveError : Integer;
    Desired, HorizOfs : Integer;


  begin
    SaveTextAttr := TextAttr;
    SaveCursor := GetCursorMode;
    BrowseYL   := StartScreenRow;
    BrowseYH   := BrowseYL + Pred(NrOfRows);
    {Hide the cursor}
    SetCursorMode($2000);
    BTGetSearchForSequential(IFBPtr, KeyNr, SaveSFS);
    BTSetSearchForSequential(IFBPtr, KeyNr, True);
    Desired := 1;
    HorizOfs := 0;
    Browse := BrowseI(IFBPtr, VarRec, KeyNr, LowKey, HighKey, StartScreenRow,
                      NrOfRows, Desired, HorizOfs, DatS, DatLen, Ref, KeyStr,
                      ExitKey, ProcSpecialTask, ProcBuildaRow,
                      ProcDisplayaRow);
    SaveError := IsamError;
    BTSetSearchForSequential(IFBPtr, KeyNr, SaveSFS);
    IsamError := SaveError;
    IsamOK := (IsamError = 0);
    SetCursorMode(SaveCursor);
    TextAttr := SaveTextAttr;
  end;

  function BrowseAgain(IFBPtr : IsamFileBlockPtr;
                       VarRec : Boolean;
                       KeyNr : Integer;
                       LowKey : IsamKeyStr;
                       HighKey : IsamKeyStr;
                       StartScreenRow,
                       NrOfRows : Integer;
                       var HighlightedRow : Integer;
                       var HorizOfs : Integer;
                       var DatS;
                       var DatLen : Word;
                       var Ref : LongInt;
                       var KeyStr : IsamKeyStr;
                       var ExitKey : BKtype;
                       ProcSpecialTask : Pointer;
                       ProcBuildaRow : Pointer;
                       ProcDisplayaRow : Pointer) : Integer;
  var
    SaveTextAttr : Byte;
    SaveCursor : Word;
    SaveSFS : Boolean;
    SaveError : Integer;


  begin
    SaveTextAttr := TextAttr;
    SaveCursor := GetCursorMode;
    BrowseYL   := StartScreenRow;
    BrowseYH   := BrowseYL + Pred(NrOfRows);
    {Hide the cursor}
    SetCursorMode($2000);
    BTGetSearchForSequential(IFBPtr, KeyNr, SaveSFS);
    BTSetSearchForSequential(IFBPtr, KeyNr, True);
    BrowseAgain := BrowseI(IFBPtr, VarRec, KeyNr, LowKey, HighKey,
                            StartScreenRow, NrOfRows, HighlightedRow,
                            HorizOfs, DatS, DatLen, Ref, KeyStr,
                            ExitKey, ProcSpecialTask, ProcBuildaRow,
                            ProcDisplayaRow);
    SaveError := IsamError;
    BTSetSearchForSequential(IFBPtr, KeyNr, SaveSFS);
    IsamError := SaveError;
    IsamOK := (IsamError = 0);
    SetCursorMode(SaveCursor);
    TextAttr := SaveTextAttr;
  end;
  procedure EnableFiltering(ValidateFunc : Pointer);
    {-Enables Browser filtering. <ValidateFunc> is a pointer to a user defined
      function that determines whether a given record should be displayed in the
      Browser. The <ValidateFunc> must be a FAR, non-nested function declared as
      follows:

      function ValidateARecord(IFBPtr : IsamFileBlockPtr;
                               KeyNr  : Integer;
                               Ref    : LongInt;
                               var KeyStr : IsamKeyStr) : Boolean;
    }
  begin
    FilterState := True;
    SearchKeyPtr      := @FilterSearchKey;
    NextKeyPtr        := @FilterNextKey;
    PrevKeyPtr        := @FilterPrevKey;
    FindKeyAndRefPtr  := @FilterFindKey;
    ValidatePtr       := ValidateFunc;
  end;

  procedure DisableFiltering;
    {-Disables Browser filtering.}
  begin
    FilterState := False;
    SearchKeyPtr      := @Search_Key;
    NextKeyPtr        := @Next_Key;
    PrevKeyPtr        := @Prev_Key;
    FindKeyAndRefPtr  := @Find_Key;
  end;

  function IsFilteringEnabled : Boolean;
    {-Returns True if Browser filtering is enabled.}
  begin
    IsFilteringEnabled := FilterState;
  end;

  function AddBrowseCommand(Cmd : BKtype; NumKeys : Byte; Key1, Key2 : Word) : Boolean;
    {-Add a new command key assignment or change an existing one}
  begin
    AddBrowseCommand :=
      AddCommandPrim(BrowseKeySet, BrowseKeyMax, Cmd, NumKeys, Key1, Key2);
  end;


begin
  {initialize procedure pointers}
  BrowseHelpPtr := nil;
  DisableFiltering;
    BrowseKeyPtr := @BrowseReadKey;
end.
