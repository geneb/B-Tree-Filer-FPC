{
  NETQUE.INC 1.1
}
function AbortServicingQueueJob(QueueID : LongInt; JobNum : Word) : Byte;
var
  Request    : record
                 Len    : Word;
                 SubF   : Byte;
                 QID    : LongInt;
                 JobN   : Word;
               end;
  Reply      : Word;
  NovRegs    : Registers;

begin
  with Request do begin
    Len    := SizeOf(Request) - 2;
    SubF   := SubFAbortServicingJob;
    QID    := NetWareSwapLong(QueueID);
    JobN   := Swap(JobNum);
  end;
  Reply    := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    AbortServicingQueueJob := AL;
  end;
end;

function AttachQueueServerToQueue(QueueID : LongInt) : Byte;

var
  Request    : record
                 Len    : Word;
                 SubF   : Byte;
                 QID    : LongInt;
               end;
  Reply      : Word;
  NovRegs    : Registers;

begin
  with Request do begin
    Len    := SizeOf(Request) - 2;
    SubF   := SubFAttachQueServ;
    QID    := NetWareSwapLong(QueueID);
  end;
  Reply    := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    AttachQueueServerToQueue := AL;
  end;
end;


function ChangeQueueJobEntry(QueueID : LongInt;
                             var JobEntry : JobEntryType) : Byte;


var
  Request    : record
                 Len    : Word;
                 SubF   : Byte;
                 QID    : LongInt;
                 Job    : JobEntryType;
               end;
  Reply      : Word;
  NovRegs    : Registers;

begin
  with Request do begin
    Len    := SizeOf(Request) - 2;
    SubF   := SubFChangeJobEntry;
    QID    := NetWareSwapLong(QueueID);
    Job    := JobEntry;
  end;
  Reply    := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    ChangeQueueJobEntry := AL;
  end;
end;


function ChangeQueueJobPosition(QueueID : LongInt; JobNumber : Word;
                                NewPosition : Byte) : Byte;


var
  Request    : record
                 Len    : Word;
                 SubF   : Byte;
                 QID    : LongInt;
                 JobN   : Word;
                 NewPos : Byte;
               end;
  Reply      : Word;
  NovRegs    : Registers;

begin
  with Request do begin
    Len    := SizeOf(Request) - 2;
    SubF   := SubFChangeJobPos;
    QID    := NetWareSwapLong(QueueID);
    JobN   := Swap(JobNumber);
    NewPos := NewPosition;
  end;
  Reply    := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    ChangeQueueJobPosition := AL;
  end;
end;

function ChangeToClientRights(QueueID : LongInt; JobNumber : Word) : Byte;
var
  Request    : record
                 Len    : Word;
                 SubF   : Byte;
                 QID    : LongInt;
                 JobN   : Word;
               end;
  Reply      : Word;
  NovRegs    : Registers;

begin
  with Request do begin
    Len    := SizeOf(Request) - SizeOf(Word);
    SubF   := SubFChangeToClient;
    QID    := NetWareSwapLong(QueueID);
    JobN   := Swap(JobNumber);
  end;
  Reply    := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    ChangeToClientRights := AL;
  end;
end;

function CloseFileAndStartJob(QueueID : LongInt; JobNumber : Word) : Byte;
var
  Request    : record
                 Len    : Word;
                 SubF   : Byte;
                 QID    : LongInt;
                 JobN   : Word;
               end;
  Reply      : Word;
  NovRegs    : Registers;

begin
  with Request do begin
    Len    := SizeOf(Request) - SizeOf(Word);
    SubF   := SubFCloseAndStart;
    QID    := NetWareSwapLong(QueueID);
    JobN   := Swap(JobNumber);
  end;
  Reply    := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    CloseFileAndStartJob := AL;
  end;
end;

function CreateQueue(QueType : Word; QueName : ObjNameStr;
                     DirectoryHandle : Byte; PathName : QueuePathType;
                     var QueueID : LongInt) : Byte;
var
  Request : record
              Len        : Word;
              SubF       : Byte;
              ObjT       : Word;
              Buf        : Array[1..170] of Byte;
            end;
  Reply   : record
              Len        : Word;
              QID        : LongInt;
            end;
  NovRegs       : Registers;
  Incr          : Word;
  Index         : Byte;
begin
  with Request do begin
    SubF   := SubFCreateQue;
    ObjT   := Swap(QueType);
    Index  := 1;
    Incr   := Succ(Length(QueName));
    Move(QueName,Buf[Index],Incr);
    Inc(Index,Incr);
    Buf[Index] := DirectoryHandle;
    Inc(Index);
    Incr := Succ(Length(PathName));
    Move(PathName,Buf[Index],Incr);
    Inc(Index,Incr);
    Len := Index + 2;
  end;
  Reply.Len := SizeOf(LongInt);
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    CreateQueue := AL;
  end;
  QueueID := NetWareSwapLong(Reply.QID);
end;

function CreateQueueJobAndFile(QueueID : LongInt;
                               JobEntry : JobEntryType;
                               var ReplyEntry : JobEntryType) : Byte;

{page 12-23}
var
  Request : record
              Len      : Word;
              SubF     : Byte;
              QID      : LongInt;
              Entry    : JobEntryType;
            end;
  Reply   : record
              Len      : Word;
              REntry   : JobEntryType;
            end;
  NovRegs       : Registers;
begin
  with Request do begin
    Len     := SizeOf(Request) - SizeOf(Word);
    SubF    := SubFCreateJobAndFile;
    QID     := NetWareSwapLong(QueueID);
    Entry   := JobEntry;
  end;
  Reply.Len := Ofs(Reply.Rentry.TextJobDesc) - Ofs(Reply.Rentry);
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    CreateQueueJobAndFile := AL;
    if AL = 0 then
      ReplyEntry := Reply.REntry;
  end;
end;

function DestroyQueue(QueueID : LongInt) : Byte;

var
  Request    : record
                 Len    : Word;
                 SubF   : Byte;
                 QID    : LongInt;
               end;
  Reply      : Word;
  NovRegs    : Registers;

begin
  with Request do begin
    Len    := SizeOf(Request) - SizeOf(Word);
    SubF   := SubFDestroyQue;
    QID    := NetWareSwapLong(QueueID);
  end;
  Reply    := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    DestroyQueue := AL;
  end;
end;

function DetachQueueServerFromQueue(QueueID : LongInt) : Byte;
var
  Request    : record
                 Len    : Word;
                 SubF   : Byte;
                 QID    : LongInt;
               end;
  Reply      : Word;
  NovRegs    : Registers;

begin
  with Request do begin
    Len    := SizeOf(Request) - SizeOf(Word);
    SubF   := SubFDetachFromQue;
    QID    := NetWareSwapLong(QueueID);
  end;
  Reply    := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    DetachQueueServerFromQueue := AL;
  end;
end;

function FinishServicingQueueJob(QueueID : LongInt; JobNumber : Word;
                                 Charge : LongInt) : Byte;
var
  Request    : record
                 Len    : Word;
                 SubF   : Byte;
                 QID    : LongInt;
                 JobN   : Word;
                 Chrg   : LongInt;
               end;
  Reply      : Word;
  NovRegs    : Registers;

begin
  with Request do begin
    Len    := SizeOf(Request) - SizeOf(Word);
    SubF   := SubFFinishServicing;
    QID    := NetWareSwapLong(QueueID);
    JobN   := Swap(JobNumber);
    Chrg   := Charge;
  end;
  Reply    := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    FinishServicingQueueJob := AL;
  end;
end;

function GetQueueJobList(QueueID : LongInt; var Jobs : QueueJobList) : Byte;

var
  Request     : record
                  Len    : Word;
                  SubF   : Byte;
                  ID     : LongInt;
                end;
  Reply       : record
                  Len    : Word;
                  JobL   : QueueJobList;
                  MaxJ   : Word;
                end;
  NovRegs     : Registers;
  I           : Word;
begin
  FillChar(Reply,SizeOf(Reply),Char(250));
  Reply.Len := SizeOf(Reply) - 2;
  with Request do begin
    Len     := SizeOf(Request) - 2;
    SubF    := SubFGetJobList;
    ID      := NetWareSwapLong(QueueID);
  end;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    GetQueueJobList := AL;
    if AL = 0 then
      with Reply do begin
        Jobs.NumJobs := Swap(JobL.NumJobs);
        if Jobs.NumJobs > MaxQueueJobs then
          Jobs.NumJobs := MaxQueueJobs;
        for I := 1 to Jobs.NumJobs do
          Jobs.JobList[I] := Swap(JobL.JobList[I]);
      end;
  end;
end;
function GetQueueJobFileSize(QueueID : LongInt;
                             JobNumber : Word;
                             var SizeOfFile : LongInt) : Byte;

var
  Request     : record
                  Len    : Word;
                  SubF   : Byte;
                  ID     : LongInt;
                  JobN   : Word;
                end;
  Reply       : record
                  Len      : Word;
                  QID      : QueueJobList;
                  JN       : Word;
                  FSize    : LongInt; {h-l}
                end;

  NovRegs     : Registers;
  I           : Word;

begin
  FillChar(Reply,SizeOf(Reply),0);
  Reply.Len := SizeOf(Reply) - 2;
  with Request do begin
    Len     := SizeOf(Request) - 2;
    SubF    := SubFGetJobFileSize;
    ID      :=  NetWareSwapLong(QueueID);
    JobN    := JobNumber;
  end;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    GetQueueJobFileSize := AL;
  end;
  SizeOfFile := NetWareSwapLong(Reply.FSize);
end;

function ReadQueueCurrentStatus(QueueID : LongInt;
                                var QueueStatus : Byte;
                                var NumberOfJobs : Byte;
                                var NumberOfServers : Byte;
                                var ServerIDList : QueueServerIDList;
                                var StationList  : QueueStationList) : Byte;

var
  Request     : record
                  Len    : Word;
                  SubF   : Byte;
                  ID     : LongInt;
                end;
  Reply       : record
                  Len       : Word;
                  ID        : LongInt;
                  Status    : Byte;
                  NumJobs   : Byte;
                  NumServ   : Byte;
                  ServerIDs : QueueServerIDList;
                  Stations  : QueueStationList;
                  MaxServs  : Byte;
                end;
  NovRegs     : Registers;
  I           : Word;
begin
  FillChar(Reply,SizeOf(Reply),Char(25));
  Reply.Len := SizeOf(Reply) - 2;
  with Request do begin
    Len     := SizeOf(Request) - 2;
    SubF    := SubFReadCurStatus;
    ID      := NetWareSwapLong(QueueID);                    {!!.24}
  end;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    ReadQueueCurrentStatus := AL;
    if AL = 0 then
      with Reply do begin
        QueueStatus      := Status;
        NumberOfJobs     := NumJobs;
        NumberOfServers  := NumServ;
        ServerIDList     := ServerIDs;
        StationList      := Stations;
      end;
  end;
end;

function ReadJobEntry(QueueID : LongInt; JobNumber : Word;
                      var JobEntry : JobEntryType) : Byte;
var
  Request     : record
                  Len    : Word;
                  SubF   : Byte;
                  ID     : LongInt;
                  Num    : Word;
                end;
  Reply       : record
                  Len       : Word;
                  Entry     : JobEntryType;
                end;
  NovRegs     : Registers;

begin
  with Request do begin
    Len    := SizeOf(Request) - 2;
    SubF   := SubFReadJobEntry;
    ID     := NetWareSwapLong(QueueID);
    Num    := Swap(JobNumber);
  end;
  Reply.Len := SizeOf(Reply) - 2;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    ReadJobEntry := AL;
    if AL = 0 then begin
(*
      Reply.Entry.JobNumber := Swap(Reply.Entry.JobNumber);
*)
      Reply.Entry.JobType   := Swap(Reply.Entry.JobType);
      JobEntry := Reply.Entry;
    end;
  end;
end;

function ReadQueueServerStatus(QueueID : LongInt; ServerID : LongInt;
                               ServerStation : Byte) : Byte;

var
  Request     : record
                  Len    : Word;
                  SubF   : Byte;
                  ID     : LongInt; {h-l}
                  ServID : LongInt; {h-l}
                  ServSt : Byte;
                end;
  Reply       : record
                  Len : Word;
                  ServStatusRec : ServerStatusRecord;
                end;
  NovRegs     : Registers;

begin
  Reply.Len := SizeOf(Reply) - 2;
  with Request do begin
    Len    := SizeOf(Request) - 2;
    SubF   := SubFReadQueServStatus;
    ID     := NetWareSwapLong(QueueID);
    ServID := ServerID;
    ServSt := ServerStation;
  end;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    ReadQueueServerStatus := AL;
  end;
end;

function RemoveJobFromQueue(QueueID : LongInt; JobNumber : Word) : Byte;
var
  Request     : record
                  Len    : Word;
                  SubF   : Byte;
                  ID     : LongInt;
                  Num    : Word;
                end;
  Reply       : Word;
  NovRegs     : Registers;

begin
  Reply := 0;
  with Request do begin
    Len    := SizeOf(Request) - 2;
    SubF   := SubFRemJobFromQue;
    ID     := NetWareSwapLong(QueueID);
    Num    := Swap(JobNumber);
  end;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    RemoveJobFromQueue := AL;
  end;
end;

function RestoreQueueServerRights : Byte;
var
  Request : record
              Len  : Word;
              SubF : Byte;
            end;
  Reply   : Word;
  NovRegs     : Registers;

begin
  Reply := 0;
  with Request do begin
    Len    := SizeOf(Request) - 2;
    SubF   := SubFChangeToServer;
  end;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    RestoreQueueServerRights := AL;
  end;
end;

function ServiceQueueJobAndOpenFile(QueueID : LongInt;
                                    TargetJobType : Word;
                                    var JobEntry : JobEntryType) : Byte;
var
  Request : record
              Len    : Word;
              SubF   : Byte;
              QID    : LongInt;
              JobT   : Word;
            end;
  Reply   : record
              Len    : Word;
              Entry  : JobEntryType;
            end;
  NovRegs : Registers;

begin
  FillChar(Reply,SizeOf(Reply),0);
  Reply.Len := SizeOf(Reply) - 2;
  with Request do begin
    Len    := SizeOf(Request) - 2;
    SubF   := SubFServiceJob;
    QID    := NetWareSwapLong(QueueID);
    JobT   := TargetJobType;
  end;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    JobEntry := Reply.Entry;
    ServiceQueueJobAndOpenFile := AL;
  end;
end;

function SetQueueCurrentStatus(QueueID : LongInt;
                               QueueStatus : Byte) : Byte;

var
  Request : record
              Len    : Word;
              SubF   : Byte;
              QID    : LongInt;
              QStat  : Byte;
            end;
  Reply   : Word;
  NovRegs : Registers;

begin
  Reply := 0;
  with Request do begin
    Len    := SizeOf(Request) - 2;
    SubF   := SubFReadQueStatus;
    QID    := NetWareSwapLong(QueueID);
    QStat  := QueueStatus;
  end;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    SetQueueCurrentStatus := AL;
  end;
end;
function SetQueueServerStatusRecord(QueueID : LongInt;
                                    var StatusRec : ServerStatusRecord) : Byte;

var
  Request : record
              Len    : Word;
              SubF   : Byte;
              QID    : LongInt;
              SRec   : ServerStatusRecord;
            end;
  Reply   : Word;
  NovRegs : Registers;

begin
  Reply := 0;
  with Request do begin
    Len    := SizeOf(Request) - 2;
    SubF   := SubFSetStatusRec;
    QID    := NetWareSwapLong(QueueID);
    SRec   := StatusRec;
  end;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    SetQueueServerStatusRecord := AL;
  end;
end;

function JobSize(QueueID : LongInt; JobNumber : Word;
                      var Size : LongInt) : Byte;
  {-Returns the size of the data associate with queue QueueID and job
    JobNumber}
begin
  JobSize := GetQueueJobFileSize(QueueID,JobNumber,Size);
  Size := Size - SizeOf(JobEntryType);
end;

