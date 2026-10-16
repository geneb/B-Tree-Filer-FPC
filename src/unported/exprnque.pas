{$S-,R-}
program ExPrnQue;
  {-Example program showing how to submit a file directly to a print queue.}
uses
  {$IFNDEF Windows}
  Crt,
  {$ENDIF}
  NetWare,
  NetBind,
  NetQue,
  NetPrnQue
  {$IFDEF Windows}
  , WinCrt
  {$ENDIF}
  ;

var {global vars}
  Result : Byte;
  ObjectID : LongInt;

function Pad(S : String; Len : Byte) : String;
var
  I : Byte;
begin
  if Length(S) < Len then
    for I := 1 to Len - Length(S) do
      S := S + ' ';
  Pad := S;
end;

function Long2Str(L : LongInt) : String;
var
  S : String;
begin
  Str(L, S);
  Long2Str := S;
end;

function ZeroFill(B : Byte) : String;
begin
  if B < 10 then
    ZeroFill := '0' + Long2Str(B)
  else
    ZeroFill := Long2Str(B);
end;

function Date2Str(var DT : QMSDateTime) : String;
type
  PAny = ^TAny;
  TAny =
    record
      L : LongInt;
      W : Word;
    end;
begin
  with PAny(@DT)^ do
    if (L = -1) and (W = $FFFF) then begin
      Date2Str := 'anytime';
      Exit;
    end;
  with DT do
    Date2Str := ZeroFill(H) + ':' + ZeroFill(Min) + ' ' + ZeroFill(M) + '/' +
                ZeroFill(D) + '/' + ZeroFill(Y);
end;

function Banner2Str(var Banner) : String;
var
  B : Array[1..13] of Char absolute Banner;
  S : String;
  I : Byte;
begin
  S := '';
  for I := 1 to 13 do
    if B[I] <> #0 then begin
      Inc(byte(S[0]));
      S[I] := B[I];
    end
    else begin
      Banner2Str := S;
      Exit;
    end;
end;

function Flags2Str(Flags : Byte) : String;
var
  S : String;
begin
  S := '';
  if Flags and jcfUserHold > 0 then
    S := 'U';
  if Flags and jcfOperatorHold > 0 then
    S := S + 'O';
  Flags2Str := S;
end;

function Desc2Str(var TextJob : TextJobField) : String;
var
  S : String;
begin
  S := '';
  Move(TextJob, S[1], SizeOf(TextJobField));
  S[0] := Char(SizeOf(TextJobField));
  while (S[Length(S)] = #0) and (Length(S) > 0) do
    Dec(Byte(S[0]));
  Desc2Str := S;
end;

procedure AddToQue;
var
  JobEntry : JobEntryType;
  FName : String;
  Desc : String;
begin
  Write('Enter filename to add to print queue: ');
  ReadLn(FName);                                     {get name of file}
  if Length(FName) = 0 then
    Exit;
  Write('Enter description of print job: ');
  ReadLn(Desc);
  FillChar(JobEntry, SizeOf(JobEntry), 0);          {zero out record}
  with JobEntry do begin
    TargetServerID := -1;                           {any server will do}
    FillChar(TargetExecTime, SizeOf(TargetExecTime), $FF); {first opportunity}
    JobType := 0;               {!!NOTE: this field specifies the FormType!!}
    JobControlFlags := jcfAutoStart (*+ jcfUserHold*);
    Move(Desc[1], TextJobDesc, Length(Desc));
  end;
  MakeClientRecord(4, 1, pqNotify+pqFormFeed, 0, 0, '', '',
                   JobEntry.ClientRecord);           {format the client record}
  Result := AddFileToPrintQueue(ObjectID, JobEntry, FName); {add file to queue}
  if Result = 0 then
    WriteLn(FName, ' added to queue')
  else
    WriteLn('error ', Result);
end;

procedure DeleteFromQue;
var
  S : String;
  JN, C : Word;
begin
  Write('Enter number of job to delete: ');
  ReadLn(S);
  Val(S, JN, C);
  if C = 0 then
    WriteLn('Result of delete = ', RemoveJobFromQueue(ObjectID, JN))
  else
    WriteLn('Invalid number')
end;

procedure WriteJobHeader;
begin
         {          1         2         3         4         5         6    }
         { 12345678901234567890123456789012345678901234567890123456789012  }
  WriteLn('JobNum Station EntryTime       Type  JobPos  Flags Desc');
end;
procedure DumpJob(JobNumber : Word);
var
  JobEntry : JobEntryType;
begin
  if ReadJobEntry(ObjectID, JobNumber, JobEntry) = 0 then begin
    with JobEntry do begin
      WriteLn(Pad(Long2Str(Swap(JobNumber)), 7),
              Pad(Long2Str(ClientStation), 8),
              Pad(Date2Str(JobEntryTime), 16),
              Pad(Long2Str(JobType), 6),
              Pad(Long2Str(JobPosition), 8),
              Pad(Flags2Str(JobControlFlags), 6),
              Desc2Str(TextJobDesc));
    end;
  end
  else
    WriteLn('Error obtaining job ', JobNumber);
end;

procedure ListQue;
var
  Jobs : QueueJobList;
  I : Word;
begin
  GetQueueJobList(ObjectID, Jobs);
  if Jobs.NumJobs = 0 then begin
    WriteLn('No jobs in queue');
    Exit;
  end;
  WriteJobHeader;
  with Jobs do
    for I := 1 to NumJobs do
      DumpJob(JobList[I]);
end;

procedure DisplayEditMenu;
begin
  WriteLn('1 - Toggle user hold');
  WriteLn('2 - Change text job description');
  WriteLn('3 - Change number of copies');
  WriteLn('4 - Toggle print job flags');
  WriteLn('5 - Change banner');
  WriteLn;
  WriteLn('0 - Save changes');
  WriteLn('Q - Ignore changes and exit');
end;

procedure EditTextJob(var TextJobDesc : TextjobField);
var
  S : String;
begin
  WriteLn('Current text job description is: ', Desc2Str(TextJobDesc));
  Write('Enter new text job description : ');
  ReadLn(S);
  if Length(S) > SizeOf(TextJobField) then
    S[0] := char(SizeOf(TextJobField));
  FillChar(TextJobDesc, SizeOf(TextJobDesc), 0);
  Move(S[1], TextJobDesc, Length(S));
end;

procedure EditCopies(var ClientRecord : ClientRecordArea);
var
  S : String;
  Copies, C : Word;
begin
  with PPrintQueClientRec(@ClientRecord)^ do begin
    WriteLn('Number of copies is currently: ', Swap(NumCopies));
    Write('Enter new number of copies   : ');
    ReadLn(S);
    Val(S, Copies, C);
    if C = 0 then
      NumCopies := Swap(Copies)
    else
      WriteLn('Invalid number');
  end;
end;

function FlagOn(Value, Flag : Byte) : String;
const
  OffOn : Array[Boolean] of String[3] = ('OFF', 'ON');
begin
  FlagOn := OffOn[Value and Flag > 0];
end;

procedure ToggleFlags(var ClientRecord : ClientRecordArea);
var
  S : String;
  C : Char;
  Done : Boolean;
begin
  with PPrintQueClientRec(@ClientRecord)^ do begin
    Done := False;
    repeat
      WriteLn;
      WriteLn('1 - Suppress Form feed        = ', FlagOn(Flags, pqFormFeed));
      WriteLn('2 - Notify submitting station = ', FlagOn(Flags, pqNotify));
      WriteLn('3 - Tab expansion             = ', FlagOn(Flags, pqText));
      WriteLn('4 - Print banner              = ', FlagOn(Flags, pqPrintBanner));
      WriteLn;
      WriteLn('Enter number to toggle or 0 to quit');
      C := Upcase(ReadKey);
      case C of
        '1' :
          if Flags and pqFormFeed > 0 then
            Flags := Flags and (not pqFormFeed)
          else
            Flags := Flags or pqFormFeed;
        '2' :
          if Flags and pqNotify > 0 then
            Flags := Flags and (not pqNotify)
          else
            Flags := Flags or pqNotify;
        '3' :
          if Flags and pqText> 0 then
            Flags := Flags and (not pqText)
          else
            Flags := Flags or pqText;
        '4' :
          if Flags and pqPrintBanner > 0 then
            Flags := Flags and (not pqPrintBanner)
          else
            Flags := Flags or pqPrintBanner;
        '0', 'Q', ^[, ^C : Done := True;
      end;
    until Done;
  end;
end;

procedure EditName(var ClientRecord : ClientRecordArea);
var
  S : String;
  Copies, C : Word;
begin
  with PPrintQueClientRec(@ClientRecord)^ do begin
    WriteLn('Current banner is: ', Banner2Str(BannerName));
    Write('Enter new banner : ');
    ReadLn(S);
    if Length(S) > SizeOf(BannerName) then
      S[0] := Char(SizeOf(BannerName));
    FillChar(BannerName, SizeOf(BannerName), 0);
    Move(S[1], BannerName, Length(S));
  end;
end;

procedure EditJob(JN : Word);
var
  JobEntry : JobEntryType;
  C : Char;
  Done : Boolean;
begin
  if ReadJobEntry(ObjectID, JN, JobEntry) = 0 then begin
    Done := False;
    repeat
      WriteLn;
      DisplayEditMenu;
      C := Upcase(ReadKey);
      case C of
        '1' :
          with JobEntry do
            if JobControlFlags and jcfUserHold > 0 then
              JobControlFlags := JobControlFlags and (not jcfUserHold)
            else
              JobControlFlags := JobControlFlags or jcfUserHold;
        '2' :
          EditTextJob(JobEntry.TextJobDesc);
        '3' : EditCopies(JobEntry.ClientRecord);
        '4' : ToggleFlags(JobEntry.ClientRecord);
        '5' : EditName(JobEntry.ClientRecord);
        '0' :
          begin
            WriteLn('Result of modify attempt = ',
                    ChangeQueueJobEntry(ObjectID, JobEntry));
            Done := True;
          end;
        'Q' :
          Done := True;
      end;
    until Done;
  end
  else
    WriteLn('Error reading job.');
end;
procedure ModifyQue;
var
  S : String;
  JN, C : Word;
begin
  Write('Enter number of job to modify: ');
  ReadLn(S);
  Val(S, JN, C);
  if C = 0 then
    EditJob(JN)
  else
    WriteLn('Invalid number');
end;

procedure UserInterface;

var
  Done : Boolean;
  C : Char;
begin
  Done := False;
  repeat
    WriteLn;
    WriteLn('A to add, D to delete, L to list, M to modify, Q to quit');
    C := Upcase(ReadKey);
    case C of
      'A' : AddToQue;
      'D' : DeleteFromQue;
      'L' : ListQue;
      'M' : ModifyQue;
      'Q', ^[, ^C : Done := True;
    end;
  until Done;
end;

begin
  WriteLn('EXPRNQUE - Example of print queue routines');
  Result := GetPrinterQueue(0, ObjectID);           {get the print queue}
  if Result <> 0 then begin
    WriteLn('Unable to obtain the print queue ID for LPT1');
    Halt;
  end;
  UserInterface;
end.
