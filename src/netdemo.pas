{*********************************************************}
{*                   NETDEMO.PAS 5.41                    *}
{*   Copyright (c) Dipl.Math. Ralf Nagel 1986-1990.      *}
{*   Copyright (c) Enz EDV Beratung GmbH 1989-1990.      *}
{*                 All rights reserved.                  *}
{*          Modified and used under license by           *}
{*                 TurboPower Software.                  *}
{*********************************************************}

{$I btdefine.inc}

{$I-,V-,S-,R-,F-,B-}

program NetDemo;
  {-Demonstrates B-Tree Filer with variable length records and a memo field
    in a multi-user environment}

{Free Pascal port: the MS-DOS version needed Turbo Professional (TPSTRING,
 TPCRT, TPENTRY and TPMEMO). Simple replacements for the routines used are
 now part of this program, so only the Crt unit is needed.}

uses
  {.......................... Free Pascal units}
{$IFDEF UNIX}
  Printer,                   {printing through lpr}
{$ENDIF}
  Crt,                       {basic screen handling}
  BaseSupp,                  {MemAvail}
  {.......................... B-Tree Filer units}
  Filer,                     {database management}
  VRec,                      {variable length records}
  VRebuild,                  {database repair--variable length records}
                                          {!!.06}
  Browser;                   {database browser}

const
  Key1Len        = 30;       {Uppercase last name+first name}
  Key2Len        = 5;        {First five digits of zip}

  FName          = 'address'; {Root name for database}
{$IFDEF UNIX}
  LstDevice      = '|/usr/bin/lpr'; {Where printed output goes (piped to lpr)}
{$ELSE}
  LstDevice      = 'PRN';    {Where printed output goes}
{$ENDIF}
  BrowseRows     = 20;       {Number of rows in browse window}
  FooterRow      = 25;       {row number for footer}

  Header         : String[80] = {Basic string used to build display header}
  ' B-Tree Filer Demo Program                                                      ';

  F1             = $3B00;    {Keycodes for function keys}
  F2             = $3C00;
  F3             = $3D00;
  F4             = $3E00;
  F5             = $3F00;
  F6             = $4000;
  F7             = $4100;
  F8             = $4200;
  F9             = $4300;
  F10            = $4400;

  SectionLength  = 140;      {each record will use from 1 to 8 sections}
  MaxMemoSize    = 932;      {140*8 = 1120, (7*(140-7))+1 = 932}

  CurrentRow : Integer = 0;       {stores the row offset of selected record}

type
  CharSet        = set of Char;
  MemoField      = array[1..MaxMemoSize] of Char;

  PersonDef =                {Definition of the database record}
    record
      Dele           : LongInt;
      FirstName      : String[15];
      Name           : String[15];
      Company        : String[25];
      Address        : String[25];
      City           : String[15];
      State          : String[2];
      Zip            : String[10];
      Telephone      : String[12];
      NotesLen       : Word;      {<-- 133 bytes to here}
      Notes          : MemoField; {memo field: 1..MaxMemoSize bytes}
    end;                          {1065 bytes maximum, 134 minimum}

  BrowseMapRec =             {Used for browse screen efficiency}
    record
      CurRef         : LongInt;
      Horiz          : Integer;
      Highlighted    : Boolean;
    end;
  BrowseMapArray = array[1..BrowseRows] of BrowseMapRec;

  {------------------------------------------------------------------------
    Free Pascal port: the data entry screen (TPENTRY) and memo editor
    (TPMEMO) of Turbo Professional used by the MS-DOS version of this
    program are replaced by the small implementations below, which only
    need the Crt unit.
   ------------------------------------------------------------------------}
const
  MaxEntryFields = 9;        {number of fields on the entry screen}
  MaxMemoLines   = 480;      {maximum number of lines in the memo editor}
  SoftCR         = #141;     {soft carriage return inserted by word wrap}

type
  StringPtr      = ^String;
  EStype         = (ESnone, ESdone, ESquit, ESnested);
  EMtype         = (EMnone, EMquit, EMuser0);
  EFKind         = (efString, efPicture, efNested);

  {validation routine of an entry field}
  EntryValidateFunc = function(var S : String; var ErrorSt : String) : Boolean;

  FieldRec =                 {one field of an entry screen}
    record
      Prompt     : String[20];
      PRow, PCol : Byte;     {position of the prompt, relative to window}
      Picture    : String[20];
      FRow, FCol : Byte;     {position of the field, relative to window}
      EditLen    : Byte;
      ID         : Byte;
      Kind       : EFKind;
      Validate   : Pointer;  {EntryValidateFunc or nil}
      VarPtr     : StringPtr;
      Required,
      Protected  : Boolean;
    end;
  FieldRecPtr    = ^FieldRec;

  ESrecord =                 {an entry screen}
    record
      XL, YL, XH, YH : Byte;
      NumFields      : Integer;
      Fields         : array[0..MaxEntryFields-1] of FieldRec;
      CurrentID      : Integer;
    end;

  MemoLines = array[1..MaxMemoLines] of String[80];

  EMcontrolBlock =           {state of the memo editor}
    record
      XL, YL, XH, YH : Byte;
      Attr           : Byte;
      InsertMode,
      IndentMode,
      WordWrap       : Boolean;
      TabSize        : Byte;
      Margin         : Byte;   {maximum length of a line}
      BufSize        : Word;
      Buffer         : PChar;
      TotalBytes     : Word;   {bytes used in Buffer, including the ^Z}
      CurLine,
      CurCol         : Word;
      NumLines       : Integer;
      TopLine        : Integer;
      Lines          : ^MemoLines;
      Soft           : array[1..MaxMemoLines] of Boolean;
    end;


var
  PS             : LongInt;  {Pages in page stack}
  Free           : LongInt;  {Heap bytes to keep free} {!!.40}
  Pf             : IsamFileBlockPtr; {Isam management variable}

  Person         : PersonDef; {Currently selected record}
  ActRec         : LongInt;  {Record number currently selected}
  ActKeyNr       : Integer;  {Active key number, 1 or 2}
  ActKey         : IsamKeyStr; {Active key string}

  BrowResp       : Integer;
  DatLen         : Word;
  BrowExit       : BKtype;
  AC             : Char;
  UseSaveMode    : Boolean;
  Locked         : Boolean;
  HorizOfs       : Integer;

  BrowseMap      : BrowseMapArray; {For screen management}

  {colors}
  NormAttr       : Byte;
  SeleAttr       : Byte;
  HighAttr       : Byte;
  FielAttr       : Byte;
  HeadAttr       : Byte;
  SaveAttr       : Byte;

  PersonFilter : PersonDef;       {used by the Browser filter routines}

  {data entry stuff}
const
  PhoneMask      : String[12] = '999-999-9999';
  ValidPhone     : String[12] = 'ppp-uuu-uuuu';
  ZipMask        : String[10] = '99999-9999';
  ValidZip       : String[10] = 'uuuuu-pppp';
  ValidationOff  : Boolean = False;

  {coordinates for entry screen and memo field windows}
  EntryXL        = 29;
  EntryYL        = 04;
  EntryXH        = 78;
  EntryYH        = 12;
  MemoXL         = 29;
  MemoYL         = 15;
  MemoXH         = 78;
  MemoYH         = 22;
var
  ESR            : ESrecord; {for entry screens}
  EMCB           : EMcontrolBlock; {for memo fields}
  ScrapPerson    : PersonDef; {used for editing}
  VRecLen        : Word;

  {------------------------------------------------------------------------
    Replacements for the routines of Turbo Professional used by this program
   ------------------------------------------------------------------------}

  procedure DispMessage(Prompt : String; WaitKey, SoundBell : Boolean); forward;
  procedure DisplayHelpPrompt(var ESR : ESrecord); forward;
  procedure MemoFieldStatus(var EMCB : EMcontrolBlock); forward;
  procedure DisplayMemoPrompt; forward;

  function Min(A, B : Integer) : Integer;
  begin
    if A < B then
      Min := A
    else
      Min := B;
  end;

  function Max(A, B : Integer) : Integer;
  begin
    if A > B then
      Max := A
    else
      Max := B;
  end;

  function Long2Str(L : LongInt) : String;
    {-Convert a long integer to a string}
  var
    S : String;
  begin
    Str(L, S);
    Long2Str := S;
  end;

  function Real2Str(R : Real; Width, Places : Byte) : String;
    {-Convert a real to a string}
  var
    S : String;
  begin
    Str(R:Width:Places, S);
    Real2Str := S;
  end;

  function Trim(S : String) : String;
    {-Remove leading and trailing blanks}
  var
    SLen : Byte absolute S;
  begin
    while (SLen > 0) and (S[SLen] <= ' ') do
      Dec(SLen);
    while (SLen > 0) and (S[1] <= ' ') do
      System.Delete(S, 1, 1);
    Trim := S;
  end;

  function Pad(S : String; Len : Byte) : String;
    {-Pad S with blanks to length Len}
  var
    SLen : Byte absolute S;
  begin
    if SLen < Len then begin
      FillChar(S[Succ(SLen)], Len-SLen, ' ');
      SLen := Len;
    end;
    Pad := S;
  end;

  function Center(S : String; Width : Byte) : String;
    {-Center S in a string of Width characters}
  var
    L : Integer;
  begin
    if Length(S) >= Width then
      Center := S
    else begin
      L := (Width-Length(S)) div 2;
      Center := Pad(Pad('', L)+S, Width);
    end;
  end;

  function StUpcase(S : String) : String;
    {-Convert S to upper case}
  var
    I : Integer;
  begin
    for I := 1 to Length(S) do
      S[I] := Upcase(S[I]);
    StUpcase := S;
  end;

  function SameBytes(var A, B; Len : Word) : Boolean;
    {-Compare Len bytes of A and B}
  type
    Bytes = array[1..65520] of Byte;
  var
    BA : Bytes absolute A;
    BB : Bytes absolute B;
    I  : Word;
  begin
    SameBytes := False;
    for I := 1 to Len do
      if BA[I] <> BB[I] then
        Exit;
    SameBytes := True;
  end;

  function ScreenStr(S : String) : String;
    {-Prepares a string for the screen. Under Linux the terminal does not
      use the IBM PC character set, so the line drawing characters are
      replaced by ASCII characters}
{$IFDEF UNIX}
  var
    I : Integer;
  begin
    for I := 1 to Length(S) do
      case S[I] of
        #179, #186 : S[I] := '|';
        #196       : S[I] := '-';
        #205       : S[I] := '=';
        #176..#178,
        #180..#185,
        #187..#195,
        #197..#204,
        #206..#223 : S[I] := '+';
        #251       : S[I] := '*';
        #254       : S[I] := '#';
      end;
    ScreenStr := S;
  end;
{$ELSE}
  begin
    ScreenStr := S;
  end;
{$ENDIF}

  procedure FastWrite(S : String; Row, Col : Integer; Attr : Byte);
    {-Write S at Row, Col with attribute Attr, cursor and TextAttr unchanged}
  var
    SaveAttr : Byte;
    SaveX, SaveY : Integer;
  begin
    if (Row = 25) and (Col+Length(S) > 80) then
      {never write the last column of the last row: the screen would scroll}
      S[0] := Chr(Max(0, 80-Col));
    SaveAttr := TextAttr;
    SaveX := WhereX;
    SaveY := WhereY;
    TextAttr := Attr;
    GotoXY(Col, Row);
    Write(ScreenStr(S));
    TextAttr := SaveAttr;
    GotoXY(SaveX, SaveY);
  end;

  procedure FrameWindow(XL, YL, XH, YH : Byte; FAttr, HAttr : Byte;
                        Header : String);
    {-Draw a frame with an optional header}
  const
    FrameChars : array[1..6] of Char = #213#212#184#190#205#179;
  var
    Row : Byte;
    Span : String;
  begin
    Span := '';
    while Length(Span) < XH-XL-1 do
      Span := Span+FrameChars[5];
    FastWrite(FrameChars[1]+Span+FrameChars[3], YL, XL, FAttr);
    for Row := YL+1 to YH-1 do begin
      FastWrite(FrameChars[6], Row, XL, FAttr);
      FastWrite(FrameChars[6], Row, XH, FAttr);
    end;
    FastWrite(FrameChars[2]+Span+FrameChars[4], YH, XL, FAttr);
    if Header <> '' then
      FastWrite(Header, YL, XL+((XH-XL+1-Length(Header)) div 2), HAttr);
  end;

  procedure RingBell;
    {-Sound the bell}
  begin
    Write(^G);
  end;

  function ReadKeyWord : Word;
    {-Read a key: low byte = character, high byte = scan code of special keys}
  var
    Ch : Char;
  begin
    Ch := ReadKey;
    if Ch = #0 then
      ReadKeyWord := Word(Ord(ReadKey)) shl 8
    else
      ReadKeyWord := Ord(Ch);
  end;

  {------------------------- entry screens --------------------------}

const
  EntryInsertMode : Boolean = True;

  procedure InitESrecord(var ESR : ESrecord);
    {-Initialize an entry screen}
  begin
    FillChar(ESR, SizeOf(ESR), 0);
  end;

  procedure SetEntryWindow(var ESR : ESrecord; XL, YL, XH, YH : Byte);
    {-Set the window of an entry screen}
  begin
    ESR.XL := XL;
    ESR.YL := YL;
    ESR.XH := XH;
    ESR.YH := YH;
  end;

  procedure AddField(var ESR : ESrecord; Kind : EFKind; Prompt : String;
                     PRow, PCol : Byte; Picture : String;
                     FRow, FCol, Len, ID : Byte; Validate : Pointer;
                     VarPtr : StringPtr);
    {-Add a field to an entry screen}
  begin
    if ESR.NumFields >= MaxEntryFields then
      Exit;
    FillChar(ESR.Fields[ESR.NumFields], SizeOf(FieldRec), 0);
    ESR.Fields[ESR.NumFields].Prompt := Prompt;
    ESR.Fields[ESR.NumFields].PRow := PRow;
    ESR.Fields[ESR.NumFields].PCol := PCol;
    ESR.Fields[ESR.NumFields].Picture := Picture;
    ESR.Fields[ESR.NumFields].FRow := FRow;
    ESR.Fields[ESR.NumFields].FCol := FCol;
    ESR.Fields[ESR.NumFields].EditLen := Len;
    ESR.Fields[ESR.NumFields].ID := ID;
    ESR.Fields[ESR.NumFields].Kind := Kind;
    ESR.Fields[ESR.NumFields].Validate := Validate;
    ESR.Fields[ESR.NumFields].VarPtr := VarPtr;
    Inc(ESR.NumFields);
  end;

  function FindFieldID(var ESR : ESrecord; ID : Byte) : FieldRecPtr;
    {-Return a pointer to the field with the given ID}
  var
    I : Integer;
  begin
    FindFieldID := nil;
    for I := 0 to ESR.NumFields-1 do
      if ESR.Fields[I].ID = ID then begin
        FindFieldID := @ESR.Fields[I];
        Exit;
      end;
  end;

  procedure ChangeProtection(var ESR : ESrecord; ID : Byte; Prot : Boolean);
    {-Protect or unprotect a field}
  var
    FRP : FieldRecPtr;
  begin
    FRP := FindFieldID(ESR, ID);
    if FRP <> nil then
      FRP^.Protected := Prot;
  end;

  function IsLiteral(Pic : Char) : Boolean;
    {-Return True if Pic is a literal character of a picture mask}
  begin
    IsLiteral := not (Pic in ['9', 'A']);
  end;

  function MergePicture(var F : FieldRec; S : String) : String;
    {-Return S as an edit string with the literal characters of the picture}
  var
    I : Integer;
    R : String;
  begin
    R := '';
    for I := 1 to F.EditLen do
      if (I <= Length(F.Picture)) and IsLiteral(F.Picture[I]) then
        R := R+F.Picture[I]
      else if I <= Length(S) then
        R := R+S[I]
      else
        R := R+' ';
    MergePicture := R;
  end;

  function ValidateSubfields(Mask : String; var S : String;
                             var ErrorSt : String) : Boolean;
    {-Check the subfields of S as described by Mask: each run of 'u' must be
      filled completely, each run of 'p' must be either empty or complete}
  var
    I, J  : Integer;
    C     : Char;
    Blank,
    Full  : Boolean;
  begin
    ValidateSubfields := True;
    I := 1;
    while I <= Length(Mask) do begin
      C := Mask[I];
      if C in ['u', 'p'] then begin
        J := I;
        Blank := True;
        Full := True;
        while (J <= Length(Mask)) and (Mask[J] = C) do begin
          if (J > Length(S)) or (S[J] = ' ') then
            Full := False
          else
            Blank := False;
          Inc(J);
        end;
        if not Full and ((C = 'u') or not Blank) then begin
          if Blank then
            ErrorSt := 'Entry required'
          else
            ErrorSt := 'Partial entries not allowed';
          ValidateSubfields := False;
          Exit;
        end;
        I := J;
      end
      else
        Inc(I);
    end;
  end;

  procedure DrawField(var ESR : ESrecord; var F : FieldRec; S : String;
                      Attr : Byte);
    {-Display the contents of a field}
  begin
    if F.Kind = efNested then
      S := '';
    FastWrite(Pad(S, F.EditLen), ESR.YL+F.FRow-1, ESR.XL+F.FCol-1, Attr);
  end;

  procedure ClearEntryWindow(var ESR : ESrecord);
    {-Clear the inside of the entry window}
  var
    Row : Byte;
  begin
    for Row := ESR.YL to ESR.YH do
      FastWrite(Pad('', ESR.XH-ESR.XL+1), Row, ESR.XL, NormAttr);
  end;

  function FieldValue(var F : FieldRec) : String;
    {-Return the edit string for the variable of a field}
  begin
    case F.Kind of
      efString  : FieldValue := Copy(F.VarPtr^, 1, F.EditLen);
      efPicture : FieldValue := MergePicture(F, Copy(F.VarPtr^, 1, F.EditLen));
      else        FieldValue := '';
    end;
  end;

  procedure DrawEditScreen(var ESR : ESrecord);
    {-Display all prompts and fields of an entry screen}
  var
    I : Integer;
  begin
    for I := 0 to ESR.NumFields-1 do
      with ESR.Fields[I] do begin
        FastWrite(Prompt, ESR.YL+PRow-1, ESR.XL+PCol-1, FielAttr);
        FastWrite('[', ESR.YL+FRow-1, ESR.XL+FCol-2, FielAttr);
        FastWrite(']', ESR.YL+FRow-1, ESR.XL+FCol+EditLen-1, FielAttr);
        DrawField(ESR, ESR.Fields[I], FieldValue(ESR.Fields[I]), NormAttr);
      end;
  end;

  procedure StoreField(var F : FieldRec; S : String);
    {-Store the edit string in the variable of a field}
  var
    SLen : Byte absolute S;
  begin
    case F.Kind of
      efString :
        F.VarPtr^ := S;
      efPicture :
        begin
          {trim trailing blanks and hyphens}
          while (SLen > 0) and (S[SLen] in [' ', '-']) do
            Dec(SLen);
          F.VarPtr^ := S;
        end;
    end;
  end;

  function FieldIsValid(var F : FieldRec; var S : String) : Boolean;
    {-Validate the edit string of a field, display an error message}
  var
    ErrorSt : String;
  begin
    FieldIsValid := True;
    ErrorSt := '';
    if F.Required and (Trim(S) = '') then
      ErrorSt := 'Entry required'
    else if F.Validate <> nil then
      if not EntryValidateFunc(F.Validate)(S, ErrorSt) then
        if ErrorSt = '' then
          ErrorSt := 'Invalid entry';
    if ErrorSt <> '' then begin
      DispMessage(ErrorSt, True, True);
      FieldIsValid := False;
    end;
  end;

  function EditField(var ESR : ESrecord; var F : FieldRec;
                     var S : String) : Word;
    {-Edit one field, return the key that ended editing}
  var
    Pos       : Integer;
    K         : Word;
    Ch        : Char;
    FirstKey  : Boolean;
    Row, Col  : Integer;

    function CanEdit(P : Integer) : Boolean;
    begin
      CanEdit := (F.Kind <> efPicture) or (P > Length(F.Picture)) or
                 not IsLiteral(F.Picture[P]);
    end;

    procedure NextPos;
    begin
      repeat
        Inc(Pos);
      until (Pos > F.EditLen) or CanEdit(Pos);
      if Pos > F.EditLen then begin
        Pos := F.EditLen;
        while (Pos > 1) and not CanEdit(Pos) do
          Dec(Pos);
      end;
    end;

    procedure PrevPos;
    var
      Old : Integer;
    begin
      Old := Pos;
      repeat
        Dec(Pos);
      until (Pos < 1) or CanEdit(Pos);
      if Pos < 1 then
        Pos := Old;
    end;

    function CharOK(var C : Char) : Boolean;
    var
      Pic : Char;
    begin
      CharOK := True;
      if (F.Kind = efPicture) or (F.Picture <> '') then begin
        if Pos <= Length(F.Picture) then
          Pic := F.Picture[Pos]
        else
          Pic := 'X';
        case Pic of
          '9' : CharOK := C in ['0'..'9', ' '];
          'A' : begin
                  C := Upcase(C);
                  CharOK := C in ['A'..'Z', ' '];
                end;
        end;
      end;
    end;

    procedure ClearField;
    begin
      if F.Kind = efPicture then
        S := MergePicture(F, '')
      else
        S := '';
    end;

  begin
    Row := ESR.YL+F.FRow-1;
    Col := ESR.XL+F.FCol-1;
    Pos := 1;
    if not CanEdit(Pos) then
      NextPos;
    FirstKey := True;
    repeat
      DrawField(ESR, F, S, SeleAttr);
      GotoXY(Col+Pos-1, Row);
      K := ReadKeyWord;
      Ch := Chr(Lo(K));
      if (Lo(K) >= 32) and (Lo(K) <> 127) then begin
        {a printable character}
        if FirstKey then
          ClearField;
        if CharOK(Ch) then begin
          if F.Kind = efPicture then begin
            S := Pad(S, F.EditLen);
            S[Pos] := Ch;
            NextPos;
          end
          else if Pos <= F.EditLen then begin
            if EntryInsertMode then begin
              if Length(S) < F.EditLen then
                System.Insert(Ch, S, Pos)
              else
                RingBell;
            end
            else begin
              S := Pad(S, Pos-1);
              if Pos > Length(S) then
                S := S+Ch
              else
                S[Pos] := Ch;
            end;
            if Pos < F.EditLen then
              Inc(Pos);
          end;
        end
        else
          RingBell;
        FirstKey := False;
        K := 0;
      end
      else
        case K of
          $4B00 : PrevPos;                               {Left}
          $4D00 : if (F.Kind = efPicture) or (Pos <= Length(S)) then
                    NextPos;                             {Right}
          $4700 : begin                                  {Home}
                    Pos := 1;
                    if not CanEdit(Pos) then
                      NextPos;
                  end;
          $4F00 : if F.Kind = efPicture then             {End}
                    Pos := F.EditLen
                  else
                    Pos := Min(Length(S)+1, F.EditLen);
          $5200 : EntryInsertMode := not EntryInsertMode; {Ins}
          $5300 : if F.Kind = efPicture then begin       {Del}
                    if Pos <= Length(S) then
                      S[Pos] := ' ';
                  end
                  else
                    System.Delete(S, Pos, 1);
          $0008 : if F.Kind = efPicture then begin       {Backspace}
                    PrevPos;
                    if Pos <= Length(S) then
                      S[Pos] := ' ';
                  end
                  else if Pos > 1 then begin
                    Dec(Pos);
                    System.Delete(S, Pos, 1);
                  end;
          $0019 : begin                                  {^Y: clear field}
                    ClearField;
                    Pos := 1;
                    if not CanEdit(Pos) then
                      NextPos;
                  end;
          else
            {all other keys end editing of this field}
            ;
        end;
      if K <> 0 then
        FirstKey := False;
    until (K = $000D) or (K = $0009) or (K = $0F00) or (K = $4800) or
          (K = $5000) or (K = $000A) or (K = $4400) or (K = $001B) or
          (K = $4900) or (K = $5100);
    DrawField(ESR, F, S, NormAttr);
    EditField := K;
  end;

  function EditScreen(var ESR : ESrecord; StartID : Integer;
                      ReadOnly : Boolean) : EStype;
    {-Edit the fields of an entry screen. Returns ESdone for <^Enter> or
      <F10>, ESquit for <Esc>, ESnested for <Enter> on the nested field}
  var
    Cur   : Integer;
    K     : Word;
    S     : String;
    I     : Integer;
    Valid : Boolean;

    procedure MoveTo(Delta : Integer);
    var
      N : Integer;
    begin
      N := 0;
      repeat
        Cur := (Cur+Delta+ESR.NumFields) mod ESR.NumFields;
        Inc(N);
      until not ESR.Fields[Cur].Protected or (N > ESR.NumFields);
    end;

  begin
    EditScreen := ESquit;
    if ESR.NumFields = 0 then
      Exit;
    Cur := 0;
    for I := 0 to ESR.NumFields-1 do
      if ESR.Fields[I].ID = StartID then
        Cur := I;
    if ESR.Fields[Cur].Protected then
      MoveTo(1);
    DrawEditScreen(ESR);
    repeat
      ESR.CurrentID := ESR.Fields[Cur].ID;
      DisplayHelpPrompt(ESR);
      with ESR.Fields[Cur] do
        if Kind = efNested then begin
          {nothing to edit, wait for a command}
          FastWrite('', ESR.YL+FRow-1, ESR.XL+FCol-1, SeleAttr);
          GotoXY(ESR.XL+FCol-1, ESR.YL+FRow-1);
          K := ReadKeyWord;
          if (K = $000D) then begin
            EditScreen := ESnested;
            Exit;
          end;
          S := '';
          Valid := True;
        end
        else begin
          S := FieldValue(ESR.Fields[Cur]);
          K := EditField(ESR, ESR.Fields[Cur], S);
          if K = $001B then begin
            EditScreen := ESquit;
            Exit;
          end;
          Valid := FieldIsValid(ESR.Fields[Cur], S);
          if Valid then
            StoreField(ESR.Fields[Cur], S);
        end;
      if Valid then
        case K of
          $000D, $0009, $5000 : MoveTo(1);       {Enter, Tab, Down}
          $0F00, $4800        : MoveTo(-1);      {Shift-Tab, Up}
          $4900               : begin            {PgUp: first field}
                                  Cur := 0;
                                  if ESR.Fields[Cur].Protected then
                                    MoveTo(1);
                                end;
          $5100               : begin            {PgDn: last field}
                                  Cur := ESR.NumFields-1;
                                  if ESR.Fields[Cur].Protected then
                                    MoveTo(-1);
                                end;
          $000A, $4400 :                         {^Enter, F10: done}
            begin
              {check the required fields}
              for I := 0 to ESR.NumFields-1 do
                with ESR.Fields[I] do
                  if Required and (Kind <> efNested) and
                     (Trim(VarPtr^) = '') then begin
                    DispMessage('Entry required', True, True);
                    Cur := I;
                    K := 0;
                    Break;
                  end;
              if K <> 0 then begin
                EditScreen := ESdone;
                Exit;
              end;
            end;
          $001B :
            begin
              EditScreen := ESquit;
              Exit;
            end;
        end;
    until False;
  end;

  {--------------------------- memo editor ---------------------------}

  procedure InitControlBlock(var EMCB : EMcontrolBlock;
                             XL, YL, XH, YH : Byte;
                             Attr : Byte;
                             InsertOn, IndentOn, WrapOn : Boolean;
                             TabSize : Byte;
                             Margin : Byte;
                             BufSize : Word;
                             var Buffer);
    {-Initialize the memo editor}
  begin
    if EMCB.Lines = nil then
      New(EMCB.Lines);
    EMCB.XL := XL;
    EMCB.YL := YL;
    EMCB.XH := XH;
    EMCB.YH := YH;
    EMCB.Attr := Attr;
    EMCB.InsertMode := InsertOn;
    EMCB.IndentMode := IndentOn;
    EMCB.WordWrap := WrapOn;
    EMCB.TabSize := TabSize;
    EMCB.Margin := Margin;
    EMCB.BufSize := BufSize;
    EMCB.Buffer := @Buffer;
    EMCB.CurLine := 1;
    EMCB.CurCol := 1;
  end;

  procedure InitBufferState(var EMCB : EMcontrolBlock; BufSize : Word;
                            var Buffer);
    {-Load the text from the buffer (terminated by ^Z) into the editor}
  var
    I : Word;
    C : Char;
  begin
    EMCB.BufSize := BufSize;
    EMCB.Buffer := @Buffer;
    EMCB.NumLines := 1;
    EMCB.Lines^[1] := '';
    EMCB.Soft[1] := False;
    I := 0;
    while (I < BufSize) and (EMCB.Buffer[I] <> ^Z) do begin
      C := EMCB.Buffer[I];
      if (C = ^M) or (C = SoftCR) then begin
        {line break; skip the following line feed}
        if (I+1 < BufSize) and (EMCB.Buffer[I+1] = ^J) then
          Inc(I);
        EMCB.Soft[EMCB.NumLines] := (C = SoftCR);
        if EMCB.NumLines < MaxMemoLines then begin
          Inc(EMCB.NumLines);
          EMCB.Lines^[EMCB.NumLines] := '';
          EMCB.Soft[EMCB.NumLines] := False;
        end;
      end
      else if C <> ^J then
        with EMCB do
          if Length(Lines^[NumLines]) < 80 then
            Lines^[NumLines] := Lines^[NumLines]+C;
      Inc(I);
    end;
    EMCB.TotalBytes := I+1;
    EMCB.CurLine := 1;
    EMCB.CurCol := 1;
    EMCB.TopLine := 1;
  end;

  function MemoSize(var EMCB : EMcontrolBlock) : LongInt;
    {-Return the number of bytes needed to store the text}
  var
    I : Integer;
    L : LongInt;
  begin
    L := 1;   {^Z}
    for I := 1 to EMCB.NumLines do begin
      Inc(L, Length(EMCB.Lines^[I]));
      if I < EMCB.NumLines then
        Inc(L, 2);
    end;
    MemoSize := L;
  end;

  procedure SaveBufferState(var EMCB : EMcontrolBlock);
    {-Store the text in the buffer}
  var
    I, J : Integer;
    P    : Word;
  begin
    P := 0;
    for I := 1 to EMCB.NumLines do begin
      for J := 1 to Length(EMCB.Lines^[I]) do begin
        EMCB.Buffer[P] := EMCB.Lines^[I][J];
        Inc(P);
      end;
      if I < EMCB.NumLines then begin
        if EMCB.Soft[I] then
          EMCB.Buffer[P] := SoftCR
        else
          EMCB.Buffer[P] := ^M;
        EMCB.Buffer[P+1] := ^J;
        Inc(P, 2);
      end;
    end;
    EMCB.Buffer[P] := ^Z;
    EMCB.TotalBytes := P+1;
  end;

  procedure DrawMemo(var EMCB : EMcontrolBlock);
    {-Display the visible lines of the memo}
  var
    Row : Integer;
    S   : String;
  begin
    with EMCB do
      for Row := YL to YH do begin
        if TopLine+Row-YL <= NumLines then
          S := Copy(Lines^[TopLine+Row-YL], 1, XH-XL+1)
        else
          S := '';
        FastWrite(Pad(S, XH-XL+1), Row, XL, Attr);
      end;
  end;

  function EditMemo(var EMCB : EMcontrolBlock; ReadOnly : Boolean;
                    var CmdList) : EMtype;
    {-Edit the memo. With ReadOnly = True the memo is only displayed.
      Editing ends with <^Enter> or <F10>}
  var
    K      : Word;
    Ch     : Char;
    S      : String;
    I      : Integer;
    Indent : Integer;

    function Fits(Extra : Integer) : Boolean;
    begin
      Fits := MemoSize(EMCB)+Extra <= EMCB.BufSize;
      if MemoSize(EMCB)+Extra > EMCB.BufSize then begin
        DispMessage('Edit buffer is full', True, True);
        DisplayMemoPrompt;
      end;
    end;

    procedure InsertLine(At : Integer; S : String; IsSoft : Boolean);
    var
      I : Integer;
    begin
      with EMCB do begin
        if NumLines >= MaxMemoLines then
          Exit;
        for I := NumLines downto At do begin
          Lines^[I+1] := Lines^[I];
          EMCB.Soft[I+1] := EMCB.Soft[I];
        end;
        Lines^[At] := S;
        EMCB.Soft[At] := IsSoft;
        Inc(NumLines);
      end;
    end;

    procedure DeleteLine(At : Integer);
    var
      I : Integer;
    begin
      with EMCB do begin
        for I := At to NumLines-1 do begin
          Lines^[I] := Lines^[I+1];
          EMCB.Soft[I] := EMCB.Soft[I+1];
        end;
        if NumLines > 1 then
          Dec(NumLines)
        else begin
          Lines^[1] := '';
          EMCB.Soft[1] := False;
        end;
      end;
    end;

    procedure WrapLine;
      {-Wrap the current line if it is longer than the margin}
    var
      P, Cut : Integer;
      Rest   : String;
    begin
      with EMCB do
        while Length(Lines^[CurLine]) > Margin do begin
          Cut := Margin+1;
          if WordWrap then begin
            P := Margin;
            while (P > 1) and (Lines^[CurLine][P] <> ' ') do
              Dec(P);
            if P > 1 then
              Cut := P+1;
          end;
          Rest := Copy(Lines^[CurLine], Cut, 255);
          Lines^[CurLine] := Copy(Lines^[CurLine], 1, Cut-1);
          if NumLines >= MaxMemoLines then begin
            Exit;
          end;
          InsertLine(CurLine+1, Rest, EMCB.Soft[CurLine]);
          EMCB.Soft[CurLine] := True;
          if CurCol >= Cut then begin
            Dec(CurCol, Cut-1);
            Inc(CurLine);
          end;
        end;
    end;

  begin
    EditMemo := EMnone;
    if ReadOnly then begin
      DrawMemo(EMCB);
      Exit;
    end;
    with EMCB do begin
      if CurLine > NumLines then
        CurLine := NumLines;
      repeat
        {keep the cursor in the window}
        if CurLine < TopLine then
          TopLine := CurLine
        else if CurLine > TopLine+(YH-YL) then
          TopLine := CurLine-(YH-YL);
        if CurCol > Length(Lines^[CurLine])+1 then
          CurCol := Length(Lines^[CurLine])+1;
        DrawMemo(EMCB);
        TotalBytes := MemoSize(EMCB);
        MemoFieldStatus(EMCB);
        GotoXY(XL+Min(CurCol, XH-XL+1)-1, YL+CurLine-TopLine);
        K := ReadKeyWord;
        Ch := Chr(Lo(K));
        if (Lo(K) >= 32) and (Lo(K) <> 127) then begin
          {insert or overwrite a character}
          if InsertMode or (CurCol > Length(Lines^[CurLine])) then begin
            if Fits(1) and (Length(Lines^[CurLine]) < 80) then begin
              System.Insert(Ch, Lines^[CurLine], CurCol);
              Inc(CurCol);
            end;
          end
          else begin
            Lines^[CurLine][CurCol] := Ch;
            Inc(CurCol);
          end;
          WrapLine;
        end
        else
          case K of
            $000D :                                 {Enter: new line}
              if Fits(2) and (NumLines < MaxMemoLines) then begin
                S := Copy(Lines^[CurLine], CurCol, 255);
                Lines^[CurLine] := Copy(Lines^[CurLine], 1, CurCol-1);
                Indent := 0;
                if IndentMode then
                  while (Indent < Length(Lines^[CurLine])) and
                        (Lines^[CurLine][Indent+1] = ' ') do
                    Inc(Indent);
                if not Fits(2+Indent) then
                  Indent := 0;
                InsertLine(CurLine+1, Pad('', Indent)+S, EMCB.Soft[CurLine]);
                EMCB.Soft[CurLine] := False;
                Inc(CurLine);
                CurCol := Indent+1;
              end;
            $0009 :                                 {Tab}
              begin
                I := TabSize-((CurCol-1) mod TabSize);
                if Fits(I) then begin
                  System.Insert(Pad('', I), Lines^[CurLine], CurCol);
                  Inc(CurCol, I);
                  WrapLine;
                end;
              end;
            $0008 :                                 {Backspace}
              if CurCol > 1 then begin
                System.Delete(Lines^[CurLine], CurCol-1, 1);
                Dec(CurCol);
              end
              else if CurLine > 1 then begin
                CurCol := Length(Lines^[CurLine-1])+1;
                S := Lines^[CurLine];
                EMCB.Soft[CurLine-1] := EMCB.Soft[CurLine];
                DeleteLine(CurLine);
                Dec(CurLine);
                Lines^[CurLine] := Copy(Lines^[CurLine]+S, 1, 80);
                WrapLine;
              end;
            $5300 :                                 {Del}
              if CurCol <= Length(Lines^[CurLine]) then
                System.Delete(Lines^[CurLine], CurCol, 1)
              else if CurLine < NumLines then begin
                S := Lines^[CurLine+1];
                EMCB.Soft[CurLine] := EMCB.Soft[CurLine+1];
                DeleteLine(CurLine+1);
                Lines^[CurLine] := Copy(Pad(Lines^[CurLine], CurCol-1)+S,
                                        1, 80);
                WrapLine;
              end;
            $0019 : DeleteLine(CurLine);           {^Y: delete line}
            $4B00 : if CurCol > 1 then              {Left}
                      Dec(CurCol)
                    else if CurLine > 1 then begin
                      Dec(CurLine);
                      CurCol := Length(Lines^[CurLine])+1;
                    end;
            $4D00 : if CurCol <= Length(Lines^[CurLine]) then  {Right}
                      Inc(CurCol)
                    else if CurLine < NumLines then begin
                      Inc(CurLine);
                      CurCol := 1;
                    end;
            $4800 : if CurLine > 1 then             {Up}
                      Dec(CurLine);
            $5000 : if CurLine < NumLines then      {Down}
                      Inc(CurLine);
            $4700 : CurCol := 1;                    {Home}
            $4F00 : CurCol := Length(Lines^[CurLine])+1;  {End}
            $4900 : CurLine := Max(1, CurLine-(YH-YL));   {PgUp}
            $5100 : CurLine := Min(NumLines, CurLine+(YH-YL)); {PgDn}
            $5200 : InsertMode := not InsertMode;   {Ins}
            $000A, $4400 :                          {^Enter, F10: done}
              begin
                SaveBufferState(EMCB);
                EditMemo := EMquit;
                Exit;
              end;
          end;
      until False;
    end;
  end;


const
  ActualNetType  : NetSupportType = NoNet;

  function MouseOrKeyPressed : Boolean;

  begin
    MouseOrKeyPressed := KeyPressed;
  end;

  function ReadKeyOrMouse : Char;
  begin
    ReadKeyOrMouse := ReadKey;
  end;

  function ReadKeyOrMouseWord : Word;
  begin
    ReadKeyOrMouseWord := ReadKeyWord;
  end;

                                              {!!.06 end}

  function IsLockError : Boolean;
    {-Return true for a locking error}
  begin
    IsLockError := (BTIsamErrorClass = 2);          {!!.06}
  end;

  function Extend(S : String; Len : Byte) : String;
    {-Pad or truncate string to specified length}
  var
    SLen           : Byte absolute S;
  begin
    if SLen >= Len then begin
      SLen := Len;
      Extend := S;
    end
    else
      Extend := Pad(S, Len);
  end;

  procedure WriteHeader(Prompt : String);
    {-Write header and bottom divider}
  var
    S              : String;
    I, J, L        : Integer;
  begin
    {draw frame}
    FrameWindow(1, 2, 80, 24, HeadAttr, HeadAttr, '');

    {draw header}
    S := Header;
    L := Length(Prompt);
    if L > 80 then
      L := 80;
    J := 40-(L shr 1);
    for I := 1 to L do
      S[J+I] := Prompt[I];
    FastWrite(S, 1, 1, HeadAttr);

    {display active key}
    if ActKeyNr = 1 then
      S := ' Key: Last Name '
    else
      S := ' Key: Zip Code ';
    if IsFilteringEnabled then
      FastWrite('®Filter¯', 1, 50, HeadAttr);
    FastWrite(S, 1, 62, HeadAttr);
  end;

  procedure WriteFooter(Prompt : String);
    {-Write a footer on the menu line}
  begin
    FastWrite(Extend(Prompt, 80), FooterRow, 1, HeadAttr);
    GotoXY(Length(Prompt)+2, FooterRow);
  end;

  function Menu(Selection : CharSet; Prompt : String) : Char;
    {-Draw a bar menu and get a selection in the CharSet}
  var
    ChWord         : Word;
    Ch             : Char absolute ChWord;
  begin
    {display prompt}
    WriteFooter(Prompt);

    {flush keyboard buffer}
    while KeyPressed do
      Ch := ReadKey;          {!!.04}

    {wait for valid key}
    repeat
      ChWord := ReadKeyOrMouseWord;
      Ch := Upcase(Ch);
    until (Ch in Selection);

    {clear prompt line}
    WriteFooter('');

    Menu := Ch;
  end;

  procedure DispMessage(Prompt : String; WaitKey, SoundBell : Boolean);
    {-Display a message on the menu line, optionally waiting for keystroke and
      ringing bell}
  var
    C              : Word;
  begin
    if WaitKey then begin
      if Prompt[Length(Prompt)] <> '.' then
        Prompt := Prompt+'.';
      WriteFooter(' '+Prompt+' Press any key...');
      if SoundBell then
        RingBell;
      C := ReadKeyOrMouseWord;
    end
    else
      WriteFooter(' '+Prompt);
  end;

  procedure DispMessageTemp(Prompt : String; Time : Word);
    {-Display a timed message}
  begin
    WriteFooter(Prompt);
    Delay(Time);
    WriteFooter('');
  end;

  procedure IsamErrorNum(F : Integer);
    {-Display Isam error number and wait for key}
  begin
    DispMessage('IsamError: '+Long2Str(F), True, True);
  end;

  function YesNo(Prompt : String; Default : Char) : Boolean;
    {-Display Yes/No prompt}
  var
    Ch             : Char;
  begin
    Ch := Menu(['Y', 'N', ^M], Prompt+' ['+Default+']');
    if Ch = ^M then
      Ch := Default;
    YesNo := (Ch = 'Y');
  end;

  function LockAbort : Boolean;
    {-If a file lock prevents progress, ask whether to try again}
  begin
    LockAbort := False;
    Locked := IsLockError;
    if not Locked then
      Exit;
    LockAbort := not YesNo('A lock prevents access. Try again?', 'Y');
  end;

  procedure AbortPrintMessage;
    {-Display this message while printing}
  begin
    WriteFooter('Press any key to abort print ');
  end;

  function Aborting : Boolean;
    {-Check for a keypress during printing, and offer a chance to quit}
  var
    C              : Char;
  begin
    Aborting := False;
    if KeyPressed then begin
      repeat
        C := ReadKey;               {!!.04}
      until not KeyPressed;
      if YesNo('Do you really wish to quit?', 'N') then
        Aborting := True
      else
        AbortPrintMessage;
    end;
  end;

  procedure ClearPerson(var Person : PersonDef);
    {-Set up for a new person record}
  begin
    FillChar(Person, SizeOf(PersonDef), 0);
    Person.NotesLen := 1;
    Person.Notes[1] := ^Z;
  end;

  function CompPerson(var P1, P2 : PersonDef) : Boolean;
    {-Compare two person records}
  begin
    CompPerson := False;
    if P1.Dele <> P2.Dele then
      Exit;
    if P1.FirstName <> P2.FirstName then
      Exit;
    if P1.Name <> P2.Name then
      Exit;
    if P1.Company <> P2.Company then
      Exit;
    if P1.Address <> P2.Address then
      Exit;
    if P1.City <> P2.City then
      Exit;
    if P1.State <> P2.State then
      Exit;
    if P1.Zip <> P2.Zip then
      Exit;
    if P1.Telephone <> P2.Telephone then
      Exit;
    if P1.NotesLen <> P2.NotesLen then
      Exit;

    {compare memo fields}
    if not SameBytes(P1.Notes, P2.Notes, P1.NotesLen) then
      Exit;

    CompPerson := True;
  end;

  procedure MakeEntryWindow(Header : String; RecNum : LongInt);
    {-Set up the entry window}
  begin
    {fix the header}
    if RecNum <> 0 then
      Header := Header+' Record # '+Long2Str(RecNum);
    Header := ' '+Header+' ';

    {draw the frame}
    FrameWindow(EntryXL-1, EntryYL-1, EntryXH+1, EntryYH+1, HeadAttr, SeleAttr,
                Header);

    {clear the inside of the window}
    ClearEntryWindow(ESR);
  end;

  procedure DisplayMemoField;
    {-Display the memo field}
  const
    EditMemoCmdList : Byte = 0;
  var
    Dummy          : EMtype;
  begin
    {draw the frame}
    FrameWindow(
      MemoXL-1, MemoYL-1, MemoXH+1, MemoYH+1, HeadAttr, SeleAttr, ' Notes ');

    {reinitialize control block}
    InitBufferState(EMCB, SizeOf(MemoField), ScrapPerson.Notes);
    ScrapPerson.NotesLen := EMCB.TotalBytes;

    {display the contents of the memo by making a phony call to EditMemo}
    Dummy := EditMemo(EMCB, True, EditMemoCmdList);
  end;

  procedure DisplayMemoPrompt;
    {-Display prompt at bottom of screen while editing}
  begin
    WriteFooter(
      Center('Press <^Enter> or <F10> when done editing notes',
             79));
  end;

  procedure DisplayPerson(var Person     : PersonDef;
                          Header         : String;
                          RecNum         : LongInt);
    {-Show data about person}
  begin
    {copy into our scrap record}
    ScrapPerson := Person;

    {set up the entry window}
    MakeEntryWindow(Header, RecNum);

    {display entry screen}
    DrawEditScreen(ESR);

    {display memo field if appropriate}
    if RecNum <> 0 then
      DisplayMemoField;
  end;

  procedure EditMemoField;
    {-Edit the memo field}
  const
    NullCmdList    : EMtype = EMnone;
  var
    ExitCommand    : EMtype;
  begin
    {display prompt}
    DisplayMemoPrompt;


    {do the editing}
    ExitCommand := EditMemo(EMCB, False, NullCmdList);


    {save the number of bytes in the buffer}
    ScrapPerson.NotesLen := EMCB.TotalBytes;
  end;

  function GetPerson(var Person : PersonDef; NameRequired : Boolean;
                     Header : String; RecNum : LongInt) : Boolean;
    {-Edit a person record}
  var
    Done           : Boolean;
    ExitCommand    : EStype;
    FRP            : FieldRecPtr;
  begin
    {copy into our scrap record}
    ScrapPerson := Person;

    {need special validation?}
    ValidationOff := not NameRequired;

    {set required status for last name}
    {Note: With Turbo Professional 5.05 or higher we could use the
     ChangeRequired procedure to do this, just as we're using ChangeProtection
     below on the Notes field, but ChangeRequired didn't exist in earlier
     versions.}
    FRP := FindFieldID(ESR, 1);
    FRP^.Required := NameRequired;

    {disable access to Notes field if searching}
    ChangeProtection(ESR, 8, not NameRequired);

    {set up the entry window}
    MakeEntryWindow(Header, RecNum);

    {draw the memo window if not searching}
    if NameRequired then
      DisplayMemoField;

    {start editing on first field}
    ESR.CurrentID := 0;

    Done := False;
    repeat
      {start editing}
      ExitCommand := EditScreen(ESR, ESR.CurrentID, False);

      {see if we need to edit another record}
      case ExitCommand of
        ESdone :             {^Enter or F10}
          begin
            Done := True;
            GetPerson := True;
          end;
        ESquit :             {Esc}
          begin
            Done := True;
            GetPerson := False;
          end;
        ESnested :
          {edit the notes field}
          if NameRequired then
            EditMemoField;
      end;
    until Done;

    {return modified record, even if <Esc> was pressed--caller will ignore
     changes if appropriate}
    Person := ScrapPerson;

    {clear the prompt line}
    WriteFooter('');
  end;

  function CreateFile : Boolean;
    {-Create the database fileblock}
  var
    IID            : IsamIndDescr;
  begin
    IID[1].KeyL := Key1Len;
    IID[1].AllowDupK := False;
    IID[2].KeyL := Key2Len;
    IID[2].AllowDupK := True;
    BTCreateFileBlock(FName, SectionLength, 2, IID);
    CreateFile := IsamOK;
  end;

  function PersonLine(var Person : PersonDef) : String;
    {-Return a string representing Person}
  const
    HaveNotes      : array[Boolean] of Char = (' ', #251);
  begin
    with Person do
      PersonLine :=
        Extend(Zip, 5)+' '+
        Extend(Trim(Name)+', '+Trim(FirstName), 19)+' '+
        Extend(Company, 19)+' '+
        Extend(Address, 19)+' '+
        Extend(City, 13)+' '+
        Extend(State, 2)+' '+
        Extend(Telephone, 12)+' '+
        HaveNotes[NotesLen > 1];
  end;

  {$F+} {the next three routines are called indirectly by BROWSER}

  function BuildKey(var P; KeyNr : Integer) : IsamKeyStr;
    {-Return the key string for either of the two indexes}
  begin
    with PersonDef(P) do
      case KeyNr of
        1 : BuildKey := Extend(StUpCase(Trim(Name)),20) +
                        Extend(StUpCase(Trim(FirstName)),10);
        2 : BuildKey := Copy(Zip, 1, 5);
      end;
  end;

  procedure BuildaRow(var RR : RowRec; KeyNr : Integer;
                      var DatS; DatLen : Word);
    {-Return one row to the browser}
  begin
    with RR, PersonDef(DatS) do
      if Ref <> -1 then
        Row := PersonLine(PersonDef(DatS))
      else begin
        {Record is locked, indicate it on screen}
        Row := '';
        while Length(Row) < MaxCols do
          Row := Row+'**   ';
      end;
  end;

  procedure DisplayaRow(var RR : RowRec; KeyNr, RowNr, StartRow : Integer;
                        HighLight : Boolean; var HorizOfs : Integer);
    {-Display one row for the browser}
  const
    ScreenCols     = 78;
  {
           1         2         3         4         5         6         7         8         9         1
  1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890
   Zip   Name                Company             Address             City         St  Phone       Notes
  zzzzz nnnnnnnnnnnnnnnnnnn ccccccccccccccccccc aaaaaaaaaaaaaaaaaaa ccccccccccccc ss ppp-ppp-pppp n
  }
    Header =
    ' Zip   Name                Company             Address             City         St  Phone       Notes';
  var
    Attr           : Byte;
  begin
    if HorizOfs > (Length(Header)-ScreenCols) then
      HorizOfs := (Length(Header)-ScreenCols);

    with BrowseMap[RowNr] do begin
      if RR.Ref = CurRef then
        if HighLight = Highlighted then
          if HorizOfs = Horiz then
            {Record is already displayed correctly}
            Exit;
      CurRef := RR.Ref;
      Highlighted := HighLight;
      Horiz := HorizOfs;
    end;

    if RowNr = 1 then
      {Write the header line now}
      FastWrite(Extend(Copy(Header, HorizOfs+1, ScreenCols), ScreenCols),
                3, 2, HighAttr);

    if HighLight then
      Attr := SeleAttr
    else
      Attr := NormAttr;
    FastWrite(Extend(Copy(RR.Row, HorizOfs+1, ScreenCols), ScreenCols),
              Pred(StartRow)+RowNr, 2, Attr);
  end;

  {$F-}

  function AddStructure(var P : PersonDef; var Rec : LongInt) : Boolean;
    {-Add a new record}
  begin
    AddStructure := False;
    repeat
      BTAddVariableRec(Pf, Rec, P, P.NotesLen+SizeOf(PersonDef)-SizeOf(MemoField));
      if LockAbort then
        Exit;
    until not Locked;
    if not IsamOK then
      IsamErrorNum(IsamError)
    else
      AddStructure := True;
  end;

  function ModStructure(var P : PersonDef; Rec : LongInt) : Boolean;
    {-Write record over previous version}
  begin
    ModStructure := False;
    repeat
      BTPutVariableRec(Pf, Rec, P,
                       P.NotesLen+SizeOf(PersonDef)-SizeOf(MemoField));
      if LockAbort then
        Exit;
    until not Locked;
    if not IsamOK then
      IsamErrorNum(IsamError)
    else
      ModStructure := True;
  end;

  function DelStructure(var Rec : LongInt) : Boolean;
    {-Delete record}
  begin
    DelStructure := False;
    repeat
      BTDeleteVariableRec(Pf, Rec);
      if LockAbort then
        Exit;
    until not Locked;
    if not IsamOK then
      IsamErrorNum(IsamError)
    else
      DelStructure := True;
  end;

  function AddKey(K : IsamKeyStr; Rec : LongInt; KeyNr : Integer) : Boolean;
    {-Add new key}
  begin
    AddKey := False;
    repeat
      BTAddKey(Pf, KeyNr, Rec, K);
      if LockAbort then
        Exit;
    until not Locked;
    if not IsamOK then
      IsamErrorNum(IsamError)
    else
      AddKey := True;
  end;

  function EraseKey(K : IsamKeyStr; Rec : LongInt; KeyNr : Integer) : Boolean;
    {-Remove a key}
  begin
    EraseKey := False;
    repeat
      BTDeleteKey(Pf, KeyNr, Rec, K);
      if LockAbort then
        Exit;
    until not Locked;
    if not IsamOK then
      IsamErrorNum(IsamError)
    else
      EraseKey := True;
  end;

  function ModKey(AltK, NeuK : IsamKeyStr; Rec : LongInt; KeyNr : Integer) : Boolean;
    {-Replace a key}
  begin
    ModKey := False;
    if EraseKey(AltK, Rec, KeyNr) then
      if AddKey(NeuK, Rec, KeyNr) then
        ModKey := True;
  end;

  procedure Reposition(UserKey : IsamKeyStr);
    {-Set sequential file pointer to another key}
  var
    Rec            : LongInt;
  begin
    repeat
      BTFindKey(Pf, 1, Rec, UserKey);
      if LockAbort then
        Exit;
    until not Locked;
    if not IsamOK then
      ActRec := 0;
  end;

  function LockAll : Boolean;
    {-Lock all open files, returning true if successful}
  var
    OK             : Boolean;
  begin
    LockAll := False;
    repeat
      BTLockAllOpenFileBlocks;
      if not IsamOK then begin
        if not YesNo('The file is presently in use. Try again?', 'Y') then
          Exit;
        OK := False;
      end
      else
        OK := True;
    until OK;
    LockAll := True;
  end;

  procedure NewStructure;
    {-Prompt for and add new record}
  label
    Retry;
  var
    PersonTemp     : PersonDef;
    Key1, Key2     : IsamKeyStr;
    Rec            : LongInt;
    KExists, OK    : Boolean;
  begin
    WriteHeader(' New Entry ');
    ClearPerson(PersonTemp);

Retry:
    {Get the new record}
    if not GetPerson(PersonTemp, True, 'Add Record', 0) then
      Exit;

    {make the index keys}
    Key1 := BuildKey(PersonTemp, 1);
    Key2 := BuildKey(PersonTemp, 2);

    {Lock the database in order to safely add the record}
    if not LockAll then
      Exit;

    {Assure it's not a duplicate key}
    repeat
      KExists := BTKeyExists(Pf, 1, Rec, Key1);
      if LockAbort then begin
        BTUnLockAllOpenFileBlocks;
        Exit;
      end;
    until not Locked;
    if KExists then begin
      BTUnLockAllOpenFileBlocks;
      if not YesNo('The name already exists. Try again?', 'Y') then
        Exit
      else
        goto Retry;
    end;

    {Add the record and its keys}
    OK := AddStructure(PersonTemp, Rec);
    if OK then
      OK := AddKey(Key1, Rec, 1);
    if OK then
      OK := AddKey(Key2, Rec, 2);

                                                   {!!.06 end}

    {Save global pointers to the current record}
    if OK then begin
      ActRec := Rec;
      case ActKeyNr of
        1 : ActKey := Key1;
        2 : ActKey := Key2;
      end;
    end;

    BTUnLockAllOpenFileBlocks;
  end;

  procedure Modify;
    {-Modify an existing record}
  label
    Retry;
  var
    PersonTemp     : PersonDef;
    PersonTemp1    : PersonDef;
    KExists, OK    : Boolean;
    Rec            : LongInt;
    Escaped        : Boolean;
    NoChanges      : Boolean;
  begin
    WriteHeader(' Modify ');
    PersonTemp := Person;

Retry:
    Escaped := not GetPerson(PersonTemp, True, 'Modifying', ActRec);
    NoChanges := CompPerson(Person, PersonTemp);
    if Escaped and not NoChanges then
      NoChanges := YesNo('Ignore changes to record?', 'N');
    if NoChanges then begin
      DispMessageTemp('Files not changed.', 250);
      Exit;
    end;

    {Lock the database in order to safely modify the record}
    if not LockAll then
      Exit;

    if BuildKey(PersonTemp, 1) <> BuildKey(Person, 1) then begin
      KExists := BTKeyExists(Pf, 1, ActRec, BuildKey(PersonTemp, 1));
      if not IsamOK then begin
        IsamErrorNum(IsamError);
        BTUnLockAllOpenFileBlocks;
        Exit;
      end;
      if KExists then begin
        BTUnLockAllOpenFileBlocks;
        if not YesNo('The name already exists. Try again?', 'Y') then
          Exit
        else
          goto Retry;
      end;
    end;

    Rec := ActRec;
    {Read actual disk data}
    BTGetVariableRec(Pf, Rec, PersonTemp1, VRecLen);
    if not IsamOK then begin
      BTUnLockAllOpenFileBlocks;
      DispMessageTemp('Record could not be read from disk.', 1000);
      Exit;
    end;

    if PersonTemp1.Dele <> LongInt(0) then begin
      BTUnLockAllOpenFileBlocks;
      DispMessageTemp('The record has been erased in the meantime.', 1000);
      Exit;
    end;

    if not CompPerson(PersonTemp1, Person) then begin
      BTUnLockAllOpenFileBlocks;
      DispMessageTemp('The record has been changed in the meantime.', 1000);
      Person := PersonTemp1;
      Exit;
    end;

    OK := ModStructure(PersonTemp, ActRec);
    if OK then
      if BuildKey(PersonTemp, 1) <> BuildKey(Person, 1) then begin
        OK := ModKey(BuildKey(Person, 1), BuildKey(PersonTemp, 1), ActRec, 1);
        if OK then
          Reposition(BuildKey(PersonTemp, 1));
      end;
    if OK then
      if BuildKey(PersonTemp, 2) <> BuildKey(Person, 2) then
        OK := ModKey(BuildKey(Person, 2), BuildKey(PersonTemp, 2), ActRec, 2);

    BTUnLockAllOpenFileBlocks;
    if OK then begin                             {!!.06}
      Person := PersonTemp;
                                   {!!.06 end}
    end;                                         {!!.06}
  end;

  procedure Delete;
    {-Prompt for and delete a record}
  var
    Key1, Key2     : IsamKeyStr;
    OK             : Boolean;
  begin
    WriteHeader(' Deleting ');
    DisplayPerson(Person, 'Deleting', ActRec);
    if not YesNo('Should the record really be deleted?', 'N') then
      Exit;

    Key1 := BuildKey(Person, 1);
    Key2 := BuildKey(Person, 2);

    {Lock the database}
    if not LockAll then
      Exit;

    OK := EraseKey(Key1, ActRec, 1);
    if OK then
      OK := EraseKey(Key2, ActRec, 2);
    if OK then
      OK := DelStructure(ActRec);
    if not OK then
      IsamErrorNum(IsamError);

                                                {!!.06 end}

    BTUnLockAllOpenFileBlocks;
  end;

  function MatchString(var SG, ST : String) : Boolean;
    {-Return true if SG and ST match}
  begin
    if Length(SG) = 0 then
      {Nothing to match against}
      MatchString := True
    else
      {Match if ST starts with SG}
      MatchString := (Pos(StUpCase(SG), StUpCase(ST)) = 1);
  end;

  function MatchPerson(var PG, PT : PersonDef) : Boolean;
    {-Compare two person records}
  begin
    MatchPerson := False;
    if PT.Dele <> 0 then
      Exit;
    if not MatchString(PG.FirstName, PT.FirstName) then
      Exit;
    if not MatchString(PG.Name, PT.Name) then
      Exit;
    if not MatchString(PG.Company, PT.Company) then
      Exit;
    if not MatchString(PG.Address, PT.Address) then
      Exit;
    if not MatchString(PG.City, PT.City) then
      Exit;
    if not MatchString(PG.State, PT.State) then
      Exit;
    if not MatchString(PG.Zip, PT.Zip) then
      Exit;
    if not MatchString(PG.Telephone, PT.Telephone) then
      Exit;
    MatchPerson := True;
  end;

  function GetNextRec(var Fptr       : IsamFileBlockPtr;
                      var Data       : PersonDef;
                      KeyNr          : Integer;
                      var Rec        : LongInt;
                      var UserKey    : IsamKeyStr) : Boolean;
    {-Get next record in index order}
  begin
    GetNextRec := False;

    {Get next sequential key}
    repeat
      BTNextKey(Fptr, KeyNr, Rec, UserKey);
      if LockAbort then
        Exit;
    until not Locked;

    if not IsamOK and (IsamError = 10250) then
      {At end of list, try once more to wrap to beginning}
      repeat
        BTNextKey(Fptr, KeyNr, Rec, UserKey);
        if LockAbort then
          Exit;
      until not Locked
    else
      GetNextRec := True;
    if not IsamOK then
      Exit;

    {Get associated data}
    repeat
      BTGetVariableRec(Fptr, Rec, Data, VRecLen);
      if LockAbort then
        Exit;
    until not Locked;
  end;

  procedure Search;
    {-Search for a record}
  var
    R              : LongInt;
    SearchKey      : Integer;
    OK             : Boolean;
    Found          : Boolean;
    Key            : IsamKeyStr;
    PersonGoal     : PersonDef;
    PersonTemp     : PersonDef;

    procedure NotFoundMessage;
    begin
      DispMessage('No matching record found', True, True);
    end;

  begin
    WriteHeader(' Search Key ');
    ClearPerson(PersonGoal);
    ClearPerson(PersonTemp);

    {Get search target}
    ValidationOff := True;
    if not GetPerson(PersonGoal, False, 'Search', 0) or
    CompPerson(PersonTemp, PersonGoal) then
      {Nothing entered}
      Exit;

    WriteFooter('Searching... ');

    {See which key to search on, if any}
    if Length(PersonGoal.Name) <> 0 then
      SearchKey := 1
    else if Length(PersonGoal.Zip) <> 0 then
      SearchKey := 2
    else
      SearchKey := 0;

    if SearchKey <> 0 then begin
      {Use the index system to position to the nearest record}
      Key := BuildKey(PersonGoal, SearchKey);
      repeat
        BTSearchKey(Pf, SearchKey, R, Key);
        if LockAbort then
          Exit;
      until not Locked;
      if not IsamOK then begin
        if IsamError = 10210 then
          NotFoundMessage
        else
          IsamErrorNum(IsamError);
        Exit;
      end;

      {Get the record}
      repeat
        BTGetVariableRec(Pf, R, PersonTemp, VRecLen);
        if LockAbort then
          Exit;
      until not Locked;

      {Position current record pointer at least near to the goal}
      ActRec := R;
      ActKey := BuildKey(PersonTemp, ActKeyNr);

      {Does it match the goal?}
      Found := MatchPerson(PersonGoal, PersonTemp);
      if Found and IsFilteringEnabled then
        Found := MatchPerson(PersonFilter, PersonTemp);
    end
    else begin
      {Start sequential search at the currently active record}
      R := ActRec;
      BTFindKeyAndRef(Pf, ActKeyNr, R, ActKey, 0);
      Found := False;
    end;

    if not Found then begin
      {Sequential search, starting one beyond current position}
      if SearchKey = 0 then
        SearchKey := ActKeyNr;
      repeat
        OK := GetNextRec(Pf, PersonTemp, SearchKey, R, Key);
        if not IsamOK then
          Exit;
        Found := MatchPerson(PersonGoal, PersonTemp);
        if Found and IsFilteringEnabled then
          Found := MatchPerson(PersonFilter, PersonTemp);
      until Found or (R = ActRec);
    end;

    if Found then begin
      ActRec := R;
      ActKey := BuildKey(PersonTemp, ActKeyNr);
    end
    else
      NotFoundMessage;
  end;

  procedure Status;
    {-Show the number of records}
  const
    ModeSt : array[Boolean] of string[6] = ('Normal', 'Save');
  var
    F, U, K           : LongInt;
  begin
    WriteHeader(' Status ');
    repeat
      U := BTUsedRecs(Pf);
      if LockAbort then
        Exit;
    until not Locked;

    repeat
      F := BTFreeRecs(Pf);
      if LockAbort then
        Exit;
    until not Locked;

    repeat
      K := BTUsedKeys(Pf, 1);
      if LockAbort then
        Exit;
    until not Locked;

    DispMessage(
      'Records:'+Long2Str(K)+
      ', Sections:'+Long2Str(U)+
      ', Deleted:'+Long2Str(F)+
      ', Mode:'+ModeSt[UseSaveMode]+
      ', Station:'+Long2Str(BTGetInternalDialogID(Pf)), {!!.40}
      True, False);
  end;

  procedure List;
    {-List all records to printer}
  var
    T              : LongInt;
    Rec            : LongInt;
    KeyNr          : Integer;
    Key            : IsamKeyStr;
    OK             : Boolean;
    C              : Char;
    Lst            : Text;
    S              : String;
    SLen           : Byte absolute S;
  begin
    WriteHeader(' List ');

    {Assure there are records to print}
    repeat
      T := BTUsedRecs(Pf);
      if LockAbort then
        Exit;
    until not Locked;
    if T = 0 then begin
      DispMessage('No records available', True, True);
      Exit;
    end;

    {See what order to print in -- provide chance to abort}
    C := Menu(['N', 'Z', 'A'], 'Sort by  N)ame Z)ipcode A)bort');
    case C of
      'A' : Exit;
      'N' : KeyNr := 1;
      'Z' : KeyNr := 2;
    end;

    {Position over first record}
    repeat
      BTClearKey(Pf, KeyNr);
      if LockAbort then
        Exit;
    until not Locked;
    Rec := 0;
    Key := '';
    if IsamOK then begin
      OK := GetNextRec(Pf, Person, KeyNr, Rec, Key);
      if Locked then
        Exit;

      {Print all the records}
    {$IFDEF UNIX}
      AssignLst(Lst, LstDevice);
    {$ELSE}
      Assign(Lst, LstDevice);
    {$ENDIF}
      Rewrite(Lst);
      if IoResult <> 0 then begin                    {!!.04}
        DispMessage('Error attempting to write to '+LstDevice,True,True);
        Exit;
      end;

      AbortPrintMessage;
      repeat
        {get displayable string and trim checkmarks and blanks}
        S := PersonLine(Person);
        if S[SLen] = #251 then
          Dec(SLen);
        while S[SLen] = ' ' do
          Dec(SLen);

        WriteLn(Lst, S);
        OK := (IoResult = 0);
        if OK then
          OK := not Aborting
        else
          DispMessage('Printer error', True, True);
        if OK then
          OK := GetNextRec(Pf, Person, KeyNr, Rec, Key);
        if Locked then
          OK := False;
      until not(IsamOK and OK);
      Close(Lst);
      if IoResult <> 0 then ;   {clear IoResult}    {!!.04}
    end;
  end;

  function Long2StrDigits(L : LongInt; NumDigits : Byte) : String;
  {-Convert a longint to a string, right justified to NumDigits}
  var
    S : String;
  begin
    Str(L:NumDigits,S);
    Long2StrDigits := S;
  end;

  {$F+}
  procedure UserStatusRoutine(KeyNr : Integer;
                              NumRecsRead,
                              NumRecsWritten : LongInt;
                              var Data;
                              Len : Word);
  {-Display information while rebuilding database}
  var
    StatStr : String[80];

  begin
    StatStr := 'Working on key --> '+Long2StrDigits(KeyNr,1)+
               '   records read --> '+Long2StrDigits(NumRecsRead,6)+
               '   written --> '+Long2StrDigits(NumRecsWritten,6);
    WriteFooter(StatStr);
  end;
  {$F-}

  function Reconstruct : Boolean;
    {-Reconstruct the database from the datafile}
  var
    IID            : IsamIndDescr;
  begin
    IID[1].KeyL := Key1Len;
    IID[1].AllowDupK := False;
    IID[2].KeyL := Key2Len;
    IID[2].AllowDupK := True;
    IsamRexUserProcPtr := @UserStatusRoutine;  {set user status procedure}
    RebuildVFileBlock(FName, SectionLength, 2, IID, @BuildKey);
    Reconstruct := IsamOK;
  end;

  function OpenedFiles : Boolean;
    {-Try to open existing database files}
  var
    OK, OK1        : Boolean;
  begin
    OpenedFiles := False;
    repeat
      BTOpenFileBlock(Pf, FName, False, False, UseSaveMode,
                      BTNetSupported <> NoNet);
      OK := IsamOK;
      if not IsamOK then begin
        if IsamError = 10010 then begin
          if YesNo('Index file defective. Rebuild it?', 'Y') then
            OK1 := Reconstruct
          else
            Exit;
        end
        else if IsamError = 9903 then begin
          if IsamExists(IsamForceExtension(FName, SavExtension)) then begin
            {Previous SAV file found}
            if YesNo('Only data save file found. Rebuild fileblock?', 'Y') then
              OK1 := Reconstruct
            else
              Exit;
          end
          else if YesNo('Data file does not exist. Create new?', 'Y') then begin
            if not CreateFile then
              Exit;
          end
          else
            Exit;
        end
        else begin
          if YesNo('Data error '+Long2Str(IsamError)+'. Attempt rebuild?', 'Y') then
            OK1 := Reconstruct
          else
            Exit;
        end;
      end;
    until OK;
    OpenedFiles := True;
  end;

  procedure SwitchKeys;
    {-Make the other key active}
  begin
    ActKeyNr := (ActKeyNr and 1)+1;
    ActKey := BuildKey(Person, ActKeyNr);
  end;

  {---------------------------filtering hooks-----------------------------
    The following routine is used to implement the special filtering
    capabilities of SIMPDEMO.  When the F6 key is pressed, the user is
    prompted for information to be used to determine what records should
    appear in the Browser.
  ------------------------------------------------------------------------}
  {$F+}
  function ValidatePerson(IFBPtr     : IsamFileBlockPtr;
                          KeyNr      : Integer;
                          Ref        : LongInt;
                          var KeyStr : IsamKeyStr;
                          NetUsed    : Boolean) : Boolean;
    {-Validate a data record against the current Browser filter}
  var
    PersonRecord : PersonDef;
  begin
    ValidatePerson := False;
    BTGetRec(IFBPtr, Ref, PersonRecord, False);
    if not IsamOK then
      Exit;
    with PersonFilter do begin
      if Length(FirstName) > 0 then
        if not MatchString(FirstName, PersonRecord.FirstName) then
          Exit;
      if Length(Name) > 0 then
        if not MatchString(Name, PersonRecord.Name) then
          Exit;
      if Length(Company) > 0 then
        if not MatchString(Company, PersonRecord.Company) then
          Exit;
      if Length(Address) > 0 then
        if not MatchString(Address, PersonRecord.Address) then
          Exit;
      if Length(City) > 0 then
        if not MatchString(City, PersonRecord.City) then
          Exit;
      if Length(State) > 0 then
        if not MatchString(State, PersonRecord.State) then
          Exit;
      if Length(Zip) > 0 then
        if not MatchString(Zip, PersonRecord.Zip) then
          Exit;
      if Length(Telephone) > 0 then
        if not MatchString(Telephone, PersonRecord.Telephone) then
          Exit;
    end;
    ValidatePerson := True;
  end;
  {$F-}

  procedure SetFilterMode(On : Boolean);
    {-Turn Browser filtering on or off}
  begin
    if On then begin
      EnableFiltering(@ValidatePerson);
      NoNetMode := False;
    end
    else begin
      DisableFiltering;
      NoNetMode := (BTNetSupported = NoNet);
    end;
  end;

  procedure Filter;
    {-Prompt for information used by Browser filtering routines}
  var
    PersonGoal, PersonTemp : PersonDef;
    Esc : Boolean;
  begin
    if IsFilteringEnabled then begin
      {filtering already on, prompt user to disable}
      if YesNo('Browser filtering enabled, do you wish to disable?', 'N') then
        SetFilterMode(False);
    end
    else begin
      {get filtering information}
      ClearPerson(PersonGoal);
      ClearPerson(PersonTemp);
      Esc := not GetPerson(PersonGoal, False, 'Filtering Info', 0);
      WriteFooter('');
      if Esc or CompPerson(PersonTemp, PersonGoal) then
        Exit;

      {confirm user desires filtering}
      if YesNo('Enable filtering with this information?', 'Y') then begin
        PersonFilter := PersonGoal;
        SetFilterMode(True);
      end;
    end;
  end;


  procedure RebuildData;
    {-Purge deleted records and rebuild indices}
  begin
    WriteHeader(' Rebuild ');
    WriteFooter('Please wait... ');
    BTCloseFileBlock(Pf);
    if not IsamOK then begin
      IsamErrorNum(IsamError);
      Halt;
    end;
    if not Reconstruct then begin
      DispMessage('Unable to rebuild data files', True, True);
      Halt;
    end;
    if not OpenedFiles then begin
      IsamErrorNum(IsamError);
      Halt;
    end;
    BTSetSearchForSequential(Pf, 1, True);
    BTSetSearchForSequential(Pf, 2, True);
    ActRec := 0;
    ActKeyNr := 1;
    ActKey := '';
  end;


  procedure InitBrowseMap;
    {-Force complete screen rewrite}
  var
    I              : Integer;
  begin
    for I := 1 to BrowseRows do
      with BrowseMap[I] do begin
        CurRef := LongInt($FFFFFFFE);
        Horiz := 0;
        Highlighted := False;
      end;
  end;

  {$F+}

  function ValidateState(var S : String; var ErrorSt : String) : Boolean;
    {-Validate a state entry}
  const
    StateStrings   : array[1..51] of array[1..2] of Char = (
      'AK', 'AL', 'AR', 'AZ', 'CA', 'CO', 'CT', 'DC', 'DE', 'FL', 'GA', 'HI',
      'IA', 'ID', 'IL', 'IN', 'KS', 'KY', 'LA', 'MA', 'MD', 'ME', 'MI', 'MN',
      'MO', 'MS', 'MT', 'NC', 'ND', 'NE', 'NH', 'NJ', 'NM', 'NV', 'NY', 'OH',
      'OK', 'OR', 'PA', 'RI', 'SC', 'SD', 'TN', 'TX', 'UT', 'VA', 'VT', 'WA',
      'WI', 'WV', 'WY');
  var
    I              : Word;
    T              : String[2];
  begin
    ValidateState := True;

    T := Trim(S);
    if not ValidationOff then
      case Length(T) of
        1 :                  {no 1-character abbreviations}
          begin
            ErrorSt := 'Partial entries not allowed';
            ValidateState := False;
          end;
        2 :                  {check list of valid abbreviations}
          begin
            for I := 1 to 51 do
              if T = StateStrings[I] then
                Exit;
            ErrorSt := 'Not a valid abbreviation for a state';
            ValidateState := False;
          end;
      end;
  end;

  function ValidatePhone(var S : String; var ErrorSt : String) : Boolean;
    {-Validate a phone number}
  begin
    if ValidationOff then
      ValidatePhone := True
    else
      ValidatePhone := ValidateSubfields(ValidPhone, S, ErrorSt);
  end;

  function ValidateZip(var S : String; var ErrorSt : String) : Boolean;
    {-Validate a zip code}
  begin
    if ValidationOff then
      ValidateZip := True
    else
      ValidateZip := ValidateSubfields(ValidZip, S, ErrorSt);
  end;

  {Special note: The picture fields for phone numbers and zip codes store
   their contents without trailing blanks and hyphens (see StoreField). This
   is needed for the Search routine, which allows searches based on partial
   zip codes and phone numbers. The ValidationOff flag used in the three
   validation routines shown above is needed for the same reason.}

  procedure DisplayHelpPrompt(var ESR : ESrecord);
    {-Display a help prompt for the current field}
  var
    S              : String[80];
  begin
    case ESR.CurrentID of
      00 : S := 'Enter first name';
      01 : S := 'Enter last name';
      02 : S := 'Enter company name';
      03 : S := 'Enter street address';
      04 : S := 'Enter city of residence';
      05 : S := 'Enter state of residence';
      06 : S := 'Enter a 5- or 9-digit zip code';
      07 : S := 'Enter phone number';
      08 : S := 'Press <Enter> to edit memo field';
    end;
    WriteFooter(' <^Enter>/<F10> Done  <Esc> Abort  '+S);
  end;

  procedure MemoFieldStatus(var EMCB : EMcontrolBlock);
    {-Display status line for memo field}

  const
    StatusLine     : String[48] =
    {         1         2         3         4        }
    {123456789012345678901234567890123456789012345678}
    ' Line: xxx Column: xxx 100%  Insert Indent Wrap ';
    InsertSt       : array[Boolean] of String[6] = (' Over ', 'Insert');
    IndentSt       : array[Boolean] of String[6] = ('      ', 'Indent');
    WrapSt         : array[Boolean] of String[4] = ('    ', 'Wrap');
  var
    S              : String[5];
  begin
    with EMCB do begin
      {insert line number}
      S := Long2Str(CurLine);
      S := Pad(S, 3);
      Move(S[1], StatusLine[8], 3);

      {insert column number}
      S := Long2Str(CurCol);
      S := Pad(S, 3);
      Move(S[1], StatusLine[20], 3);

      {insert percentage of buffer used}
      S := Real2Str(Trunc((TotalBytes*100.0)/(BufSize-2)), 3, 0);
      Move(S[1], StatusLine[24], 3);

      {plug in state stuff}
      Move(InsertSt[InsertMode][1], StatusLine[30], 6);
      Move(IndentSt[IndentMode][1], StatusLine[37], 6);
      Move(WrapSt[WordWrap][1], StatusLine[44], 4);

      {display status line}
      FastWrite(StatusLine, MemoYH+1, MemoXL+1, FielAttr);
    end;
  end;

  procedure InitEntryScreen;
    {-Set up for data entry screens}
  begin
    {clear the scrap record used for editing}
    ClearPerson(ScrapPerson);

    {initialize the edit screen record}
    InitESrecord(ESR);

    {set entry window coordinates}
    SetEntryWindow(ESR, EntryXL, EntryYL, EntryXH, EntryYH);

    {add each of the edit fields in order: left to right, top to bottom}
    {                    Prompt             Prompt  Picture   Field   Fld ID  Validation}
    {.F-}
    AddField(ESR, efString,  'First name', 01, 05, '',        01, 21, 15, 00, nil,
             @ScrapPerson.FirstName);
    AddField(ESR, efString,  'Last name',  02, 05, '',        02, 21, 15, 01, nil,
             @ScrapPerson.Name);
    AddField(ESR, efString,  'Company',    03, 05, '',        03, 21, 25, 02, nil,
             @ScrapPerson.Company);
    AddField(ESR, efString,  'Address',    04, 05, '',        04, 21, 25, 03, nil,
             @ScrapPerson.Address);
    AddField(ESR, efString,  'City',       05, 05, '',        05, 21, 15, 04, nil,
             @ScrapPerson.City);
    AddField(ESR, efString,  'State',      06, 05, 'AA',      06, 21, 02, 05, @ValidateState,
             @ScrapPerson.State);
    AddField(ESR, efPicture, 'Zip',        07, 05, ZipMask,   07, 21, 10, 06, @ValidateZip,
             @ScrapPerson.Zip);
    AddField(ESR, efPicture, 'Telephone',  08, 05, PhoneMask, 08, 21, 12, 07, @ValidatePhone,
             @ScrapPerson.Telephone);
    AddField(ESR, efNested,  'Notes',      09, 05, '',        09, 21, 01, 08, nil,
             nil);
    {.F+}
  end;

  procedure InitMemoFields;
    {-Set up for memo fields}
  begin
    {initialize the edit control block}
    InitControlBlock(
      EMCB,                  {control block}
      MemoXL,                {left column of edit window}
      MemoYL,                {top row of edit window}
      MemoXH,                {right column of edit window}
      MemoYH,                {bottom row of edit window}
      NormAttr,              {attribute for normal text}
      True,                  {insert mode on?}
      True,                  {auto-indent on?}
      True,                  {word wrap on?}
      8,                     {distance between tab stops}
      MemoXH-MemoXL,         {right margin}
      SizeOf(MemoField),     {size of edit buffer}
      ScrapPerson.Notes);    {edit buffer}
  end;

  procedure SetColors;
    {-Choose attributes for display}
  begin
    case LastMode and $FF of
      3 :
        begin
          NormAttr := $1E;
          SeleAttr := $3E;
          HighAttr := $4E;
          FielAttr := $1B;
          HeadAttr := $1F;
        end;
      else
        begin
          NormAttr := $07;
          SeleAttr := $70;
          HighAttr := $0F;
          FielAttr := $07;
          HeadAttr := $0F;
        end;
    end;
  end;

  procedure GetOptionsFromCommandLine;
    {-Get the network type (and station number if necessary) from Command line}
  type
    Str128 = String[128];
  var
    Opt : Str128;

    procedure ShowHelp;
      {-Display help message and halt}
    begin
      WriteLn('Usage: NETDEMO /opt');
      WriteLn;
      WriteLn('where opt is:');
        WriteLn('  /D     - Single-user, no network');
      if MsNet in IsamCompiledNets then
        WriteLn('  /M     - MS-Net or compatible');
      if Novell in IsamCompiledNets then
        WriteLn('  /N     - Novell''s Advanced NetWare');
      Halt;
    end;

    procedure InvalidOption(Opt : String);
      {-Display invalid option message, show help, and halt}
    begin
      WriteLn('Invalid Option: ',Opt);
      WriteLn;
      ShowHelp;
    end;

  begin
    if BTNoNetCompiled then begin
      ActualNetType := NoNet;
      Exit;
    end;
    if ParamCount = 0 then
      ShowHelp;
    Opt := ParamStr(1);
    if (Length(Opt) < 2) or (Opt[1] <> '/') then
      InvalidOption(Opt);
    case UpCase(Opt[2]) of
      '?' : ShowHelp;
      'D' : ActualNetType := NoNet;
      'M' : ActualNetType := MsNet;
      'N' : ActualNetType := Novell;
      else InvalidOption(Opt);
    end; {case}

  end;

begin
  {parse the command line}
  GetOptionsFromCommandLine;

  {initialize screen}
  SetColors;
  InitEntryScreen;
  InitMemoFields;
  SaveAttr := TextAttr;
  TextAttr := NormAttr;
  CheckBreak := False;
  ClrScr;

  {other initialization}
  ActRec := 0;
  ActKeyNr := 1;
  ActKey := '';

  WriteHeader(' Initializing ');

  if ActualNetType = NoNet then
    {Let the browser work faster}
    Browser.NoNetMode := True;

  {Limit the number of index buffers}          {!!.40}
  Free := 10000;                               {!!.40}
  if MemAvail-Free > 200000 then               {!!.40}
    Free := MemAvail-200000;                   {!!.40}
  PS := BTInitIsam(ActualNetType, Free, 0);    {!!.22 moved} {!!.40}
  if not IsamOK then begin
    IsamErrorNum(IsamError);
    Halt;
  end;

  {allocate a buffer for variable length records} {!!.01}
  if not BTSetVariableRecBuffer(SectionLength) then begin
    DispMessageTemp('Insufficient memory. Program aborting.', 2000);
    Halt;
  end;

  UseSaveMode := YesNo('Should the files be handled using Save mode?', 'N');

                                                      {!!.06 end}
  RefreshFunc := @RefreshPeriodically;

  if not OpenedFiles then begin
    DispMessageTemp('Files could not be opened. Program aborting.', 2000);
    Halt;
  end;

  BTSetSearchForSequential(Pf, 1, True);
  BTSetSearchForSequential(Pf, 2, True);

  {add user-defined exit commands}
  if AddBrowseCommand(BKuser1, 1, F1, 0) then {};
  if AddBrowseCommand(BKuser2, 1, F2, 0) then {};
  if AddBrowseCommand(BKuser3, 1, F3, 0) then {};
  if AddBrowseCommand(BKuser4, 1, F4, 0) then {};
  if AddBrowseCommand(BKuser5, 1, F5, 0) then {};
  if AddBrowseCommand(BKuser6, 1, F6, 0) then {};
  if AddBrowseCommand(BKuser8, 1, F8, 0) then {};
  if AddBrowseCommand(BKuser9, 1, F9, 0) then {};
  if AddBrowseCommand(BKuser0, 1, F10, 0) then {};
  if AddBrowseCommand(BKrowEnd, 1, $4F00, 0) then {};  {End key to end of line}
  if AddBrowseCommand(BKrowBegin, 1, $4700, 0) then {};{home key to start of line}


  RowsToJump := 1;
  HorizOfs := 0;
  if BTNetSupported <> NoNet then
    UseReadLock := True;

  repeat
    {Update the screen and browse around the records}
    InitBrowseMap;
    WriteHeader(' Main Menu ');
                {0        1         2         3         4         5         6         7         8}
                {12345678901234567890123456789012345678901234567890123456789012345678901234567890}
    WriteFooter('  F2-Add F3-Del F4-Find F5-Key F6-Filter F8-Print F9-Info F10-Rebuild Esc-Quit');
    BrowExit := BKnone;
    {                           !!!! Needed for variable length records}
    {                           vvvv}
    BrowResp := BrowseAgain(Pf, True, ActKeyNr,
                            '', #255,
                            4, BrowseRows,
                            CurrentRow,
                            HorizOfs,
                            Person, DatLen,
                            ActRec, ActKey, BrowExit,
                            nil, @BuildaRow, @DisplayaRow);
    WriteFooter('');

    {Check for browse errors}
    case BrowResp of
      1 : if IsFilteringEnabled then begin
            DispMessage('No records found matching current filter. Filtering disabled.',
                        True, True);
            SetFilterMode(False);
          end
          else if YesNo('There are no records. Add one?', 'Y') then
            BrowExit := BKuser2
          else
            BrowExit := BKquit;
      2 : if BTIsamErrorClass > 2 then begin                  {!!.41}
            DispMessageTemp('Disk error, aborting. ', 2000);
            IsamErrorNum(IsamError);
            Halt;
          end else begin                                      {!!.41}
            {Not a fatal error; display it and continue}      {!!.41}
            IsamErrorNum(IsamError);                          {!!.41}
            BrowExit := BKnone;                               {!!.41}
          end;                                                {!!.41}
    end;

    {Handle requests for action}
    case BrowExit of
      BKenter,
      BKuser1 : Modify;
      BKuser2 : begin
                  NewStructure;
                  CurrentRow := 0;
                end;
      BKuser3 : Delete;
      BKuser4 : Search;
      BKuser5 : SwitchKeys;
      BKuser6 : begin
                  Filter;
                  CurrentRow := 0;
                end;
      BKuser8 : List;
      BKuser9 : Status;
      BKuser0 : RebuildData;
      BKquit :
        if not YesNo('Quit program?', 'N') then
          BrowExit := BKnone;
    end;
  until BrowExit = BKquit;

  {Close up the database}
  BTCloseFileBlock(Pf);
  if not IsamOK then
    DispMessageTemp('Data may be corrupt.', 2000);

  BTExitIsam;
  BTReleaseVariableRecBuffer;

  {clear the screen}
  TextAttr := SaveAttr;
  ClrScr;
                                                 {!!.06}
end.
