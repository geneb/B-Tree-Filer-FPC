{
  TESTQUE2 - Program to test NetWare QMS functions
             by Richard S. Sadowsky

  This program attempts to find the queue created by TESTQUE. If found, this
  program attachs as a queue server and processes a job (if one exists). In
  the case of this test program, processes the job consists of reading the job
  and a string out of the job file.
}
{$S-,R-,I-}
program TestQue2;
uses
  {$IFDEF Windows}
  TpString,
  WinCrt,
  {$ELSE}
  OpString,
  {$ENDIF}
  NetBind,
  NetQue;
{$IFDEF Windows}
type
  StringPtr = ^String;
{$ENDIF}

  procedure Abort(S : String);
  begin
    WriteLn(S);
    Halt;
  end;

var
  HasProp : Boolean;
  QueueID : LongInt;
  Result         : Byte;
  ObjectType,
  Num,
  JobNo          : Word;
  ObjectFlag,
  ObjectSec,
  PropFlag       : Byte;
  SaveExitProc : Pointer;
  JobEntry : JobEntryType;
  QueueName : ObjNameStr;
  F : File;
  S : String;

const
  Attached :Boolean = False;
  OurQueName = 'RICH_Q';

  {$F+}
  procedure OurExitProc;
  begin
    ExitProc := SaveExitProc;
    if Attached then begin
      {detach from queue before terminating}
      Result := DetachQueueServerFromQueue(QueueID);
      if Result <> 0 then WriteLn('Error ', HexB(Result), ' detaching from queue');
    end;
  end;

begin
  SaveExitProc := ExitProc;
  ExitProc := @OurExitProc;

  {scan bindery for our queue}
  ObjectType := bindJobQueue;
  QueueName := OurQueName;
  Result := ScanObject(ObjectType, QueueName, QueueID, ObjectFlag,
                       ObjectSec, HasProp);
  if Result <> 0 then Abort('QUEUE: ' + OurQueName + ' not found');

  {attach to the queue as a queue server}
  Result := AttachQueueServerToQueue(QueueID);
  if Result <> 0 then Abort('Error ' + HexB(Result) + ' attaching to queue');
  Attached := True;

  {service a queue job}
  Result := ServiceQueueJobAndOpenFile(QueueID, $FFFF, JobEntry);
  if Result <> 0 then Abort('Error ' + HexB(Result) + ' servicing queue job');

  {read the job we're servicing}
  Result := ReadJobEntry(QueueID, Swap(JobEntry.JobNumber), JobEntry);
  if Result <> 0 then WriteLn('Error ' + HexB(Result) + ' reading job from queue');

  {display info from this job}
  Move(JobEntry.TextJobDesc,S[1], SizeOf(TextJobField));
  S[0] := Char(SizeOf(TextJobField));
  WriteLn(S);
  WriteLn(StringPtr(@JobEntry.ClientRecord)^);

  {open the queue file}
  Assign(F, 'NETQ');
  Reset(F, 1);
  if IoResult <> 0 then Abort('Can not open NETQ');

  {read the queue file}
  BlockRead(F, S, SizeOf(S), Num);
  if IoResult <> 0 then Abort('Can not read NETQ');

  {display text from file}
  WriteLn(S);

  {close the DOS handle for the queue file}
  Close(F);
  if IoResult <> 0 then Abort('Can not Close NETQ');
end.
