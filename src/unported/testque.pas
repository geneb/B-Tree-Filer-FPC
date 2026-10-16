{
  TESTQUE - Program to test NetWare QMS functions
            by Richard S. Sadowsky

  This program creates a queue called RICH_Q. It then deletes the Q_USERS
  property which means any logged user may use the queue. Then it adds the
  name of the user logged into the calling workstation as a Q_SERVER (means
  that user can service the queue). Then a queue job and file are created, and
  some dummy data written to the file. The queue job and file are close. The
  user is then prompted, if Esc is pressed, the queue is destroyed, otherwise
  it remains in place. If the queue is left in place, then TESTQUE2 and
  TESTQUE3 can be run.

  Note: this program uses drive J for the server, if this isn't right, you'll
  need to change the constant ServerDrive to the appropriate letter.
}
{$S-,R-,I-}
program TestQue;

uses
  {$IFDEF Windows}
  WinCrt,
  {$ELSE}
  OpString,
  OpCrt,
  {$ENDIF}
  NetWare,
  NetBind,
  NetQue;

{$IFDEF Windows}
const
  Digits : array[0..$F] of Char = '0123456789ABCDEF';

type
  Long =
    record
      LowWord, HighWord : Word;
    end;


  function HexB(B : Byte) : string;
    {-Return hex string for byte}
  begin
    HexB[0] := #2;
    HexB[1] := Digits[B shr 4];
    HexB[2] := Digits[B and $F];
  end;

  function HexW(W : Word) : string;
    {-Return hex string for word}
  begin
    HexW[0] := #4;
    HexW[1] := Digits[hi(W) shr 4];
    HexW[2] := Digits[hi(W) and $F];
    HexW[3] := Digits[lo(W) shr 4];
    HexW[4] := Digits[lo(W) and $F];
  end;

  function HexL(L : LongInt) : string;
    {-Return hex string for LongInt}
  begin
    with Long(L) do
      HexL := HexW(HighWord)+HexW(LowWord);
  end;
{$ENDIF}

procedure Abort(S : String);
begin
  WriteLn(S);
  Halt;
end;

type
  StringPtr = ^String;

const
  ServerDrive = 'J';   {****change to appropriate drive letter}
  AnyServer : LongInt = -1;
  TextJobStr : String[15] = 'to satisfy Rich';
  ClientRecStr : String[30] = 'this is the client record area';
  FileStr : String[27]      = 'text added to the job queue';
  OurQueName = 'RICH_Q';
  QueCreated : Boolean = False;

var
  QueueID : LongInt;
  DirHandle, Result, Flags : Byte;
  JobEntry, ReplyEntry : JobEntryType;
  ConnInfo : ConnInfoType;
  ListOfJobs : QueueJobList;
  I : Word;
  S : String;
  F : File;
  SaveExitProc : Pointer;

  {$F+}
  procedure OurExitProc;
  begin
    ExitProc := SaveExitProc;
    if QueCreated then begin
      {destroy the queue in the event of abnormal termination}
      Result := DestroyQueue(QueueID);
      if Result <> 0 then
        WriteLn('Error ' + HexB(Result) + ' on DestroyQueue');
    end;
  end;

  procedure DumpJob(JobNo : Word);
  begin
    FillChar(ReplyEntry, SizeOf(ReplyEntry), 0);

    {read the queue job}
    Result := ReadJobEntry(QueueID, JobNo, ReplyEntry);
    if Result = 0 then begin
      {display info from this job}
      Move(ReplyEntry.TextJobDesc,S[1], SizeOf(TextJobField));
      S[0] := Char(SizeOf(TextJobField));
      WriteLn(S);
      WriteLn(StringPtr(@ReplyEntry.ClientRecord)^);
    end
    else
      WriteLn('Error ' + HexB(Result) + ' on ReadJobEntry for job ', JobNo);
  end;

begin
  SaveExitProc := ExitProc;
  ExitProc := @OurExitProc;
  {get directory handle of server}
  DirHandle := GetDirHandle(ServerDrive, Flags);
  if DirHandle = 0 then Abort('Error getting Directory handle');

  {create the queue}
  Result := CreateQueue(bindJobQueue, OurQueName, DirHandle, '', QueueID);
  if Result <> 0 then Abort('Error ' + HexB(Result) + ' creating queue');
  QueCreated := True;

  {delete the Q_USERS property so anyone can use the queue}
  Result := DeleteProperty(bindJobQueue, OurQueName, 'Q_USERS');
  if Result <> 0 then Abort('Error ' + HexB(Result) + ' deleting propery');

  {get name of use logged onto this workstation}
  GetConnInfo(GetConnNo, ConnInfo);

  {add user at this station to list of Q_SERVERS}
  Result := AddObjectToSet(bindJobQueue, 'RICH_Q', 'Q_SERVERS',
                           bindUser, ConnInfo.ObjectName);
  if Result <> 0 then Abort('Error ' + HexB(Result) + ' adding to Q_SERVERS');

  {initialize the JobEntry record}
  FillChar(JobEntry, SizeOf(JobEntry), 0);
  with JobEntry do begin
    TargetServerID   := AnyServer;
    TargetExecTime   := FirstOpportunity;
    JobType          := 1;
    JobControlFlags  := 0;
    Move(TextJobStr[1], TextJobDesc, Length(TextJobStr));
    Move(ClientRecStr, ClientRecord, Length(ClientRecStr) + 1);
  end;

  {create a queue job}
  Result := CreateQueueJobAndFile(QueueID, JobEntry, ReplyEntry);
  if Result <> 0 then
    Abort('Error ' + HexB(Result) + ' on CreateQueueJobAndHandle');

  {now write to the newly created queue job file}
  Assign(F, 'NETQ');
  Reset(F, 1);
  if IoResult <> 0 then Abort('Error opening NETQ');
  BlockWrite(F, FileStr, SizeOf(FileStr));
  if IoResult <> 0 then Abort('Error writing NETQ');

  {get list of jobs in queue}
  Result := GetQueueJobList(QueueID, ListOfJobs);
  {if successful, dump each job}
  if Result = 0 then
    for I := 1 to ListOfJobs.NumJobs do
      DumpJob(ListOfJobs.JobList[I])
  else
    WriteLn('Error ' + HexB(Result) + ' on GetQueueJobList');

  {close the DOS handle associated with job file}
  Close(F);
  if IoResult <> 0 then Abort('Error closing NETQ');

  {close the NetWare job file and submit the job to the queue for processing}
  Result := CloseFileAndStartJob(QueueID, ListOfJobs.JobList[1]);
  if Result <> 0 then Abort('Error ' + HexB(Result) + ' closing job');

  {ask user to press ESC to destroy queue, or exit with queue in place}
  WriteLn('Press escape to destroy queue or any other key to leave queue in place');
  if ReadKey <> ^[ then begin
    QueCreated := False;
    Halt;
  end;

  {destroy the queue}
  Result := DestroyQueue(QueueID);
  if Result <> 0 then
    Abort('Error ' + HexB(Result) + ' on DestroyQueue');
end.
