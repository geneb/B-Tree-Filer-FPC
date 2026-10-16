{
  NETQUEW.INC 1.1
}
function AbortServicingQueueJob(QueueID : LongInt; JobNum : Word) : Byte;
type
  TRequest    = record
                  Len    : Word;
                  SubF   : Byte;
                  QID    : LongInt;
                  JobN   : Word;
                end;
var
  Request    : ^TRequest;
  Reply      : ^Word;
  NovRegs    : Registers;
  S, P : Pointer;
begin
  AbortServicingQueueJob := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    Len    := SizeOf(TRequest) - 2;
    SubF   := SubFAbortServicingJob;
    QID    := NetWareSwapLong(QueueID);
    JobN   := Swap(JobNum);
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    AbortServicingQueueJob := AL;
  end;
  FreeRealModeMem(P);
end;

function AttachQueueServerToQueue(QueueID : LongInt) : Byte;

type
  TRequest   = record
                 Len    : Word;
                 SubF   : Byte;
                 QID    : LongInt;
               end;
var
  Request    : ^TRequest;
  Reply      : ^Word;
  NovRegs    : Registers;
  S, P : Pointer;
begin
  AttachQueueServerToQueue := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    Len    := SizeOf(TRequest) - 2;
    SubF   := SubFAttachQueServ;
    QID    := NetWareSwapLong(QueueID);
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    AttachQueueServerToQueue := AL;
  end;
  FreeRealModeMem(P);
end;


function ChangeQueueJobEntry(QueueID : LongInt;
                             var JobEntry : JobEntryType) : Byte;


type
  TRequest   = record
                 Len    : Word;
                 SubF   : Byte;
                 QID    : LongInt;
                 Job    : JobEntryType;
               end;
var
  Request    : ^TRequest;
  Reply      : ^Word;
  NovRegs    : Registers;
  S, P : Pointer;
begin
  ChangeQueueJobEntry := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    Len    := SizeOf(TRequest) - 2;
    SubF   := SubFChangeJobEntry;
    QID    := NetWareSwapLong(QueueID);
    Job    := JobEntry;
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    ChangeQueueJobEntry := AL;
  end;
  FreeRealModeMem(P);
end;


function ChangeQueueJobPosition(QueueID : LongInt; JobNumber : Word;
                                NewPosition : Byte) : Byte;

type
  TRequest   = record
                 Len    : Word;
                 SubF   : Byte;
                 QID    : LongInt;
                 JobN   : Word;
                 NewPos : Byte;
               end;
var
  Request    : ^TRequest;
  Reply      : ^Word;
  NovRegs    : Registers;
  S, P : Pointer;
begin
  ChangeQueueJobPosition := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    Len    := SizeOf(TRequest) - 2;
    SubF   := SubFChangeJobPos;
    QID    := NetWareSwapLong(QueueID);
    JobN   := Swap(JobNumber);
    NewPos := NewPosition;
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    ChangeQueueJobPosition := AL;
  end;
  FreeRealModeMem(P);
end;

function ChangeToClientRights(QueueID : LongInt; JobNumber : Word) : Byte;
Type
  TRequest   = record
                 Len    : Word;
                 SubF   : Byte;
                 QID    : LongInt;
                 JobN   : Word;
               end;
var
  Request    : ^TRequest;
  Reply      : ^Word;
  NovRegs    : Registers;
  S, P : Pointer;
begin
  ChangeToClientRights := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    Len    := SizeOf(TRequest) - SizeOf(Word);
    SubF   := SubFChangeToClient;
    QID    := NetWareSwapLong(QueueID);
    JobN   := Swap(JobNumber);
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    ChangeToClientRights := AL;
  end;
  FreeRealModeMem(P);
end;

function CloseFileAndStartJob(QueueID : LongInt; JobNumber : Word) : Byte;
type
  TRequest   = record
                 Len    : Word;
                 SubF   : Byte;
                 QID    : LongInt;
                 JobN   : Word;
               end;
var
  Request    : ^TRequest;
  Reply      : ^Word;
  NovRegs    : Registers;
  S, P : Pointer;
begin
  CloseFileAndStartJob := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    Len    := SizeOf(TRequest) - SizeOf(Word);
    SubF   := SubFCloseAndStart;
    QID    := NetWareSwapLong(QueueID);
    JobN   := Swap(JobNumber);
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    CloseFileAndStartJob := AL;
  end;
  FreeRealModeMem(P);
end;

function CreateQueue(QueType : Word; QueName : ObjNameStr;
                     DirectoryHandle : Byte; PathName : QueuePathType;
                     var QueueID : LongInt) : Byte;
type
  TRequest = record
               Len        : Word;
               SubF       : Byte;
               ObjT       : Word;
               Buf        : Array[1..170] of Byte;
             end;
  TReply   = record
               Len        : Word;
               QID        : LongInt;
             end;
var
  Request       : ^TRequest;
  Reply         : ^TReply;
  NovRegs       : Registers;
  Incr          : Word;
  Index         : Byte;
  S, P : Pointer;
begin
  CreateQueue := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));

  with Request^ do begin
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

  Reply^.Len := SizeOf(LongInt);

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    CreateQueue := AL;
  end;
  QueueID := NetWareSwapLong(Reply^.QID);
  FreeRealModeMem(P);
end;

function CreateQueueJobAndFile(QueueID : LongInt;
                               JobEntry : JobEntryType;
                               var ReplyEntry : JobEntryType) : Byte;

{page 12-23}
type
  TRequest = record
               Len      : Word;
               SubF     : Byte;
               QID      : LongInt;
               Entry    : JobEntryType;
             end;
  TReply   = record
               Len      : Word;
               REntry   : JobEntryType;
             end;
var
  Request    : ^TRequest;
  Reply      : ^TReply;
  NovRegs    : Registers;
  S, P : Pointer;
begin
  CreateQueueJobAndFile := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));

  with Request^ do begin
    Len     := SizeOf(TRequest) - SizeOf(Word);
    SubF    := SubFCreateJobAndFile;
    QID     := NetWareSwapLong(QueueID);
    Entry   := JobEntry;
  end;
  Reply^.Len := Ofs(Reply^.Rentry.TextJobDesc) - Ofs(Reply^.Rentry);

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    CreateQueueJobAndFile := AL;
    if AL = 0 then
      ReplyEntry := Reply^.REntry;
  end;
  FreeRealModeMem(P);
end;


function DestroyQueue(QueueID : LongInt) : Byte;

type
  TRequest   = record
                 Len    : Word;
                 SubF   : Byte;
                 QID    : LongInt;
               end;
var
  Request    : ^TRequest;
  Reply      : ^Word;
  NovRegs    : Registers;
  S, P : Pointer;
begin
  DestroyQueue := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    Len    := SizeOf(TRequest) - SizeOf(Word);
    SubF   := SubFDestroyQue;
    QID    := NetWareSwapLong(QueueID);
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    DestroyQueue := AL;
  end;
  FreeRealModeMem(P);
end;

function DetachQueueServerFromQueue(QueueID : LongInt) : Byte;
type
  TRequest   = record
                 Len    : Word;
                 SubF   : Byte;
                 QID    : LongInt;
               end;
var
  Request    : ^TRequest;
  Reply      : ^Word;
  NovRegs    : Registers;
  S, P : Pointer;
begin
  DetachQueueServerFromQueue := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    Len    := SizeOf(TRequest) - SizeOf(Word);
    SubF   := SubFDetachFromQue;
    QID    := NetWareSwapLong(QueueID);
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    DetachQueueServerFromQueue := AL;
  end;
  FreeRealModeMem(P);
end;

function FinishServicingQueueJob(QueueID : LongInt; JobNumber : Word;
                                 Charge : LongInt) : Byte;
type
  TRequest   = record
                 Len    : Word;
                 SubF   : Byte;
                 QID    : LongInt;
                 JobN   : Word;
                 Chrg   : LongInt;
               end;
var
  Request    : ^TRequest;
  Reply      : ^Word;
  NovRegs    : Registers;
  S, P : Pointer;
begin
  FinishServicingQueueJob := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    Len    := SizeOf(TRequest) - SizeOf(Word);
    SubF   := SubFFinishServicing;
    QID    := NetWareSwapLong(QueueID);
    JobN   := Swap(JobNumber);
    Chrg   := Charge;
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    FinishServicingQueueJob := AL;
  end;
  FreeRealModeMem(P);
end;

function GetQueueJobList(QueueID : LongInt; var Jobs : QueueJobList) : Byte;

type
  TRequest     = record
                   Len    : Word;
                   SubF   : Byte;
                   ID     : LongInt;
                 end;
  TReply       = record
                   Len    : Word;
                   JobL   : QueueJobList;
                   MaxJ   : Word;
                 end;
var
  Request    : ^TRequest;
  Reply      : ^TReply;
  NovRegs    : Registers;
  I          : Word;
  S, P : Pointer;
begin
  GetQueueJobList := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));

  FillChar(Reply^,SizeOf(Reply^),Char(250));
  Reply^.Len := SizeOf(TReply) - 2;
  with Request^ do begin
    Len     := SizeOf(TRequest) - 2;
    SubF    := SubFGetJobList;
    ID      := NetWareSwapLong(QueueID);
  end;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    GetQueueJobList := AL;
    if AL = 0 then
      with Reply^ do begin
        Jobs.NumJobs := Swap(JobL.NumJobs);
        if Jobs.NumJobs > MaxQueueJobs then
          Jobs.NumJobs := MaxQueueJobs;
        for I := 1 to Jobs.NumJobs do
          Jobs.JobList[I] := Swap(JobL.JobList[I]);
      end;
  end;
  FreeRealModeMem(P);
end;


function GetQueueJobFileSize(QueueID : LongInt;
                             JobNumber : Word;
                             var SizeOfFile : LongInt) : Byte;

type
  TRequest    = record
                  Len    : Word;
                  SubF   : Byte;
                  ID     : LongInt;
                  JobN   : Word;
                end;
  TReply      = record
                  Len      : Word;
                  QID      : QueueJobList;
                  JN       : Word;
                  FSize    : LongInt; {h-l}
                end;
var
  Request     : ^TRequest;
  Reply       : ^TReply;
  NovRegs     : Registers;
  I           : Word;
  S, P : Pointer;
begin
  GetQueueJobFileSize := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));

  FillChar(Reply^,SizeOf(Reply^),0);
  Reply^.Len := SizeOf(TReply) - 2;
  with Request^ do begin
    Len     := SizeOf(TRequest) - 2;
    SubF    := SubFGetJobFileSize;
    ID      :=  NetWareSwapLong(QueueID);
    JobN    := JobNumber;
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    GetQueueJobFileSize := AL;
  end;

  SizeOfFile := NetWareSwapLong(Reply^.FSize);
  FreeRealModeMem(P);
end;

function ReadQueueCurrentStatus(QueueID : LongInt;
                                var QueueStatus : Byte;
                                var NumberOfJobs : Byte;
                                var NumberOfServers : Byte;
                                var ServerIDList : QueueServerIDList;
                                var StationList  : QueueStationList) : Byte;

type
  TRequest    = record
                  Len    : Word;
                  SubF   : Byte;
                  ID     : LongInt;
                end;
  TReply      = record
                  Len       : Word;
                  ID        : LongInt;
                  Status    : Byte;
                  NumJobs   : Byte;
                  NumServ   : Byte;
                  ServerIDs : QueueServerIDList;
                  Stations  : QueueStationList;
                  MaxServs  : Byte;
                end;
var
  Request    : ^TRequest;
  Reply      : ^TReply;
  NovRegs    : Registers;
  I          : Word;
  S, P : Pointer;
begin
  ReadQueueCurrentStatus := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));

  FillChar(Reply^,SizeOf(Reply^),Char(25));
  Reply^.Len := SizeOf(TReply) - 2;
  with Request^ do begin
    Len     := SizeOf(TRequest) - 2;
    SubF    := SubFReadCurStatus;
    ID      := NetWareSwapLong(QueueID);                   {!!.24}
  end;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    ReadQueueCurrentStatus := AL;
    if AL = 0 then
      with Reply^ do begin
        QueueStatus      := Status;
        NumberOfJobs     := NumJobs;
        NumberOfServers  := NumServ;
        ServerIDList     := ServerIDs;
        StationList      := Stations;
      end;
  end;
  FreeRealModeMem(P);
end;

function ReadJobEntry(QueueID : LongInt; JobNumber : Word;
                      var JobEntry : JobEntryType) : Byte;
type
  TRequest    = record
                  Len    : Word;
                  SubF   : Byte;
                  ID     : LongInt;
                  Num    : Word;
                end;
  TReply      = record
                  Len       : Word;
                  Entry     : JobEntryType;
                end;
var
  Request    : ^TRequest;
  Reply      : ^TReply;
  NovRegs    : Registers;
  S, P : Pointer;
begin
  ReadJobEntry := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));

  with Request^ do begin
    Len    := SizeOf(TRequest) - 2;
    SubF   := SubFReadJobEntry;
    ID     := NetWareSwapLong(QueueID);
    Num    := Swap(JobNumber);
  end;
  Reply^.Len := SizeOf(TReply) - 2;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    ReadJobEntry := AL;
    if AL = 0 then begin
(*
      Reply^.Entry.JobNumber := Swap(Reply^.Entry.JobNumber);
*)
      Reply^.Entry.JobType   := Swap(Reply^.Entry.JobType);
      JobEntry := Reply^.Entry;
    end;
  end;
  FreeRealModeMem(P);
end;

function ReadQueueServerStatus(QueueID : LongInt; ServerID : LongInt;
                               ServerStation : Byte) : Byte;

type
  TRequest    = record
                  Len    : Word;
                  SubF   : Byte;
                  ID     : LongInt; {h-l}
                  ServID : LongInt; {h-l}
                  ServSt : Byte;
                end;
  TReply      = record
                  Len : Word;
                  ServStatusRec : ServerStatusRecord;
                end;
var
  Request    : ^TRequest;
  Reply      : ^TReply;
  NovRegs    : Registers;
  S, P : Pointer;
begin
  ReadQueueServerStatus := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));

  Reply^.Len := SizeOf(TReply) - 2;
  with Request^ do begin
    Len    := SizeOf(TRequest) - 2;
    SubF   := SubFReadQueServStatus;
    ID     := NetWareSwapLong(QueueID);
    ServID := ServerID;
    ServSt := ServerStation;
  end;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    ReadQueueServerStatus := AL;
  end;
  FreeRealModeMem(P);
end;

function RemoveJobFromQueue(QueueID : LongInt; JobNumber : Word) : Byte;
type
  TRequest    = record
                  Len    : Word;
                  SubF   : Byte;
                  ID     : LongInt;
                  Num    : Word;
                end;
var
  Request    : ^TRequest;
  Reply      : ^Word;
  NovRegs    : Registers;
  S, P : Pointer;
begin
  RemoveJobFromQueue := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    Len    := SizeOf(TRequest) - 2;
    SubF   := SubFRemJobFromQue;
    ID     := NetWareSwapLong(QueueID);
    Num    := Swap(JobNumber);
  end;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    RemoveJobFromQueue := AL;
  end;
  FreeRealModeMem(P);
end;

function RestoreQueueServerRights : Byte;
type
  TRequest    = record
                  Len  : Word;
                  SubF : Byte;
                end;
var
  Request    : ^TRequest;
  Reply      : ^Word;
  NovRegs    : Registers;
  S, P : Pointer;
begin
  RestoreQueueServerRights := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    Len    := SizeOf(TRequest) - 2;
    SubF   := SubFChangeToServer;
  end;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    RestoreQueueServerRights := AL;
  end;
  FreeRealModeMem(P);
end;

function ServiceQueueJobAndOpenFile(QueueID : LongInt;
                                    TargetJobType : Word;
                                    var JobEntry : JobEntryType) : Byte;
type
  TRequest = record
               Len    : Word;
               SubF   : Byte;
               QID    : LongInt;
               JobT   : Word;
             end;
  TReply   = record
               Len    : Word;
               Entry  : JobEntryType;
             end;
var
  Request    : ^TRequest;
  Reply      : ^TReply;
  NovRegs    : Registers;
  S, P : Pointer;
begin
  ServiceQueueJobAndOpenFile := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));

  FillChar(Reply^,SizeOf(Reply^),0);
  Reply^.Len := SizeOf(TReply) - 2;
  with Request^ do begin
    Len    := SizeOf(TRequest) - 2;
    SubF   := SubFServiceJob;
    QID    := NetWareSwapLong(QueueID);
    JobT   := TargetJobType;
  end;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    JobEntry := Reply^.Entry;
    ServiceQueueJobAndOpenFile := AL;
  end;
  FreeRealModeMem(P);
end;

function SetQueueCurrentStatus(QueueID : LongInt;
                               QueueStatus : Byte) : Byte;

type
  TRequest = record
               Len    : Word;
               SubF   : Byte;
               QID    : LongInt;
               QStat  : Byte;
             end;
var
  Request    : ^TRequest;
  Reply      : ^Word;
  NovRegs    : Registers;
  S, P : Pointer;
begin
  SetQueueCurrentStatus := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    Len    := SizeOf(TRequest) - 2;
    SubF   := SubFReadQueStatus;
    QID    := NetWareSwapLong(QueueID);
    QStat  := QueueStatus;
  end;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    SetQueueCurrentStatus := AL;
  end;
  FreeRealModeMem(P);
end;

function SetQueueServerStatusRecord(QueueID : LongInt;
                                    var StatusRec : ServerStatusRecord) : Byte;

type
  TRequest = record
               Len    : Word;
               SubF   : Byte;
               QID    : LongInt;
               SRec   : ServerStatusRecord;
             end;
var
  Request    : ^TRequest;
  Reply      : ^Word;
  NovRegs    : Registers;
  S, P : Pointer;
begin
  SetQueueServerStatusRecord := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    Len    := SizeOf(TRequest) - 2;
    SubF   := SubFSetStatusRec;
    QID    := NetWareSwapLong(QueueID);
    SRec   := StatusRec;
  end;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    SetQueueServerStatusRecord := AL;
  end;
  FreeRealModeMem(P);
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