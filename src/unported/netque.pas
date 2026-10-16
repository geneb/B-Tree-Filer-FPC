{
  Turbo Pascal Unit of Queue Services for NetWare
  Version 1.1  9/5/91

  by Richard S. Sadowsky

  Please address questions and comments about this unit to ALL in section 6 of
  the PCVENB forum on Compuserve.
}
{$A-,V-,F-}

Unit NetQue;

interface

{$IFDEF Windows}
  {$DEFINE WindowsOrDPMI}
{$ELSE}
  {$IFDEF DPMI}
    {$DEFINE WindowsOrDPMI}
  {$ENDIF}
{$ENDIF}

uses
{$IFDEF Windows}
  WinProcs,
  WinTypes,
  WinDos,
  WinDPMI,
{$ELSE}
  Dos,
  {$IFDEF DPMI}
  WinDPMI,
  {$ENDIF}
{$ENDIF}
  NetWare,
  NetBind;

const
  MaxQueueJobs         = 250;
  QueueMaxConnections  = 25;

  jcfAutoStart         = $08;
  jcfRestart           = $10;
  jcfEntryOpen         = $20;
  jcfUserHold          = $40;
  jcfOperatorHold      = $80;

{$IFDEF Windows}
type
  Registers            = TRegisters;
{$ENDIF}

type
  JobFileNameStr       = String[13];
  QueuePathType        = String[118];
  QMSDateTime          = record
                           Y,M,D,H,Min,S : Byte;
                         end;
  QueueJobList         = record
                           NumJobs : Word;
                           JobList : Array[1..MaxQueueJobs] of Word;
                         end;
  JobFileHandleType    = Array[1..6] of Byte;
  QueueTimeType        = Array[1..6] of Byte;
  TextJobField         = Array[1..50] of Char;
  TextJobStr           = String[49];
  ClientRecordArea     = Array[1..152] of Byte;
  QueueServerIDList    = Array[1..QueueMaxConnections] of LongInt;
  QueueStationList     = Array[1..QueueMaxConnections] of Byte;
  JobEntryType         = record
                           ClientStation    : Byte;
                           ClientTaskNum    : Byte;
                           ClientID         : LongInt;      {hi-lo}
                           TargetServerID   : LongInt;      {hi-lo}
                           TargetExecTime   : QMSDateTime;
                           JobEntryTime     : QMSDateTime;
                           JobNumber        : Word;         {hi-lo}
                           JobType          : Word;         {hi-lo}
                           JobPosition      : Byte;
                           JobControlFlags  : Byte;
                           JobFileName      : JobFileNameStr;
                           JobFileHandle    : JobFileHandleType;
                           ServerStation    : Byte;
                           ServerTaskNum    : Byte;
                           ServerID         : LongInt;      {hi-lo}
                           TextJobDesc      : TextJobField;
                           ClientRecord     : ClientRecordArea;
                         end;
  ServerStatusRecord   = Array[1..64] of Byte;

const
  SubFAbortServicingJob= $73;
  SubFAttachQueServ    = $6F;
  SubFChangeJobPos     = $6E;
  SubFChangeJobEntry   = $6D;
  SubFChangeToClient   = $74;
  SubFCloseAndStart    = $69;
  SubFCreateQue        = $64;
  SubFCreateJobAndFile = $68;
  SubFDestroyQue       = $65;
  SubFDetachFromQue    = $70;
  SubFFinishServicing  = $72;
  SubFGetJobFileSize   = $78;

  SubFGetJobList       = $6B;
  SubFReadCurStatus    = $66;
  SubFReadJobEntry     = $6C;
  SubFReadQueServStatus= $76;
  SubFRemJobFromQue    = $6A;
  SubFChangeToServer   = $75;
  SubFServiceJob       = $71;
  SubFReadQueStatus    = $67;
  SubFSetStatusRec     = $77;

var
  FirstOpportunity     : QMSDateTime;

function AbortServicingQueueJob(QueueID : LongInt; JobNum : Word) : Byte;
  {-Abort servicing a job, close the associated file, amd remove job entry
    from Queue}

function AttachQueueServerToQueue(QueueID : LongInt) : Byte;
  {-Attaches a station to a queue as a queue (job) server}

function ChangeQueueJobEntry(QueueID : LongInt;
                             var JobEntry : JobEntryType) : Byte;
  {-Change's information in the job's record entry}

function ChangeQueueJobPosition(QueueID : LongInt; JobNumber : Word;
                                NewPosition : Byte) : Byte;
  {-Changes a job's position in the queue}

function ChangeToClientRights(QueueID : LongInt; JobNumber : Word) : Byte;
  {-Allows a queue (job) server to assume the login identity of the client
    that placed the job in the queue}

function CloseFileAndStartJob(QueueID : LongInt; JobNumber : Word) : Byte;
  {-Closes an associated file and releases the job for servicing}

function CreateQueue(QueType : Word; QueName : ObjNameStr;
                     DirectoryHandle : Byte; PathName : QueuePathType;
                     var QueueID : LongInt) : Byte;
  {-Creates a new queue on a file server}

function CreateQueueJobAndFile(QueueID : LongInt;
                               JobEntry : JobEntryType;
                               var ReplyEntry : JobEntryType) : Byte;
  {-Places a new job in the queue}

function DestroyQueue(QueueID : LongInt) : Byte;
  {-Removes a queue from the bindery and file system of a file server}

function DetachQueueServerFromQueue(QueueID : LongInt) : Byte;
  {-Removes the requesting station from the queue's list of active queue (job_
    servers}

function FinishServicingQueueJob(QueueID : LongInt; JobNumber : Word;
                                 Charge : LongInt) : Byte;
  {-Allows a queue (job) server to signal QMS when it has completed a job}

function GetQueueJobList(QueueID : LongInt; var Jobs : QueueJobList) : Byte;
  {-Provides a list of all jobs contained in a queue}

function GetQueueJobFileSize(QueueID : LongInt;
                             JobNumber : Word;
                             var SizeOfFile : LongInt) : Byte;
  {-Finds the size of the associated file for a job queue}

function ReadQueueCurrentStatus(QueueID : LongInt;
                                var QueueStatus : Byte;
                                var NumberOfJobs : Byte;
                                var NumberOfServers : Byte;
                                var ServerIDList : QueueServerIDList;
                                var StationList  : QueueStationList) : Byte;
  {-Reads the current status of the queue}

function ReadJobEntry(QueueID : LongInt; JobNumber : Word;
                      var JobEntry : JobEntryType) : Byte;
  {-Retrieves information about jobs in a queue}

function ReadQueueServerStatus(QueueID : LongInt; ServerID : LongInt;
                               ServerStation : Byte) : Byte;
  {-Reads the current status record of an attached queue (job) server}

function RemoveJobFromQueue(QueueID : LongInt; JobNumber : Word) : Byte;
  {-Removes a job from the queue}

function RestoreQueueServerRights : Byte;
  {-Restores a server's own identity after assuming the client's rights}

function ServiceQueueJobAndOpenFile(QueueID : LongInt;
                                    TargetJobType : Word;
                                    var JobEntry : JobEntryType) : Byte;
  {-Allows a queue server to request a new job for servicing}

function SetQueueCurrentStatus(QueueID : LongInt;
                               QueueStatus : Byte) : Byte;
  {-Controls the addition of jobs and job servers to a queue by setting and
    clearing bits in the queue status byte}

function SetQueueServerStatusRecord(QueueID : LongInt;
                                    var StatusRec : ServerStatusRecord) : Byte;
  {-Updates QMS' copy of a queue (job) servers's status record}

{high level routines}
function JobSize(QueueID : LongInt; JobNumber : Word;
                 var Size : LongInt) : Byte;
  {-Returns the size of the print data associate with queue QueueID and job
    JobNumber}

implementation

{$IFDEF WindowsOrDPMI}
  {$I NETQUEW.INC}
{$ELSE}
  {$I NETQUE.INC}
{$ENDIF}

begin
  FillChar(FirstOpportunity, SizeOf(FirstOpportunity), $FF);
end.

