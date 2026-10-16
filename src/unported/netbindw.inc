{
 NETBINDW.INC 1.1
}

function AddObjectToSet(ObjType : Word; ObjName : ObjNameStr;
                        PropertyName : PropertyStr;
                        MemberObjType : Word;
                        MemberObjName : ObjNameStr) : Byte;

type
  TRequest      = record
                    Len     : Word;
                    SubF    : Byte;
                    ObjT    : Word;
                    Buf     : Array[1..118] of Byte;
                  end;

var
  Request       : ^TRequest;
  Reply         : ^Word;
  NovRegs       : Registers;
  Incr          : Word;
  Index         : Byte;
  S, P : Pointer;
begin
  AddObjectToSet := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    SubF   := SubFAddObjToSet;
    ObjT   := Swap(ObjType);
    Index  := 1;
    Incr   := Succ(Length(ObjName));
    Move(ObjName,Buf[Index],Incr);
    Inc(Index,Incr);

    Incr   := Succ(Length(PropertyName));
    Move(PropertyName,Buf[Index],Incr);
    Inc(Index,Incr);
    MemberObjType := Swap(MemberObjType);
    Move(MemberObjType,Buf[Index],SizeOf(Word));
    Inc(Index,SizeOf(Word));
    Incr   := Succ(Length(MemberObjName));
    Move(MemberObjName,Buf[Index],Incr);
    Inc(Index,Incr);
    Len := Index + 2; {3?}
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    AddObjectToSet := AL;
  end;
  FreeRealModeMem(P);
end;

function ChangePassword(ObjType : Word; ObjName : ObjNameStr;
                        OldPassword, NewPassword : PasswordStr) : Byte;

const
  BufSize = (SizeOf(PasswordStr) * 2) + SizeOf(ObjNameStr);
type
  TRequest = record
               Len     : Word;
               SubF    : Byte;
               ObjT    : Word;
               Buf     : Array[1..BufSize] of Byte;
             end;
var
  Request : ^TRequest;
  Reply   : ^Word;
  NovRegs : Registers;
  Incr    : Word;
  Index   : Word;
  S, P : Pointer;
begin
  ChangePassword := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    SubF   := SubFChangeObjPass;
    ObjT   := Swap(ObjType);
    Index  := 1;
    Incr   := Succ(Length(ObjName));
    Move(ObjName,Buf[Index],Incr);
    Inc(Index,Incr);

    Incr   := Succ(Length(OldPassword));
    Move(OldPassword,Buf[Index],Incr);
    Inc(Index,Incr);
    Incr   := Succ(Length(NewPassword));
    Move(NewPassword,Buf[Index],Incr);
    Inc(Index,Incr);
    Len := Index + 2; {3?}
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    ChangePassword := AL;
  end;
  FreeRealModeMem(P);
end;

function ChangeObjectSecurity(ObjType : Word; ObjName : ObjNameStr;
                              NewSecurity : Byte) : Byte;

type
  TRequest = record
              Len     : Word;
              SubF    : Byte;
              NewSec  : Byte;
              ObjT    : Word;
              ObjN    : ObjNameStr;
            end;
var
  Request : ^TRequest;
  Reply   : ^Word;
  NovRegs : Registers;
  S, P : Pointer;

begin
  ChangeObjectSecurity := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    Len     := Length(ObjName) + 4;
    SubF    := SubFChangeObjSec;
    NewSec  := NewSecurity;
    ObjT    := Swap(ObjType);
    ObjN    := ObjName;
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    ChangeObjectSecurity := AL;
  end;
  FreeRealModeMem(P);
end;

function ChangePropertySecurity(ObjType : Word; ObjName : ObjNameStr;
                                PropertyName : PropertyStr;
                                NewPropertySecurity : Byte) : Byte;


const
  BufSize = SizeOf(ObjNameStr) + SizeOf(PropertyStr) + SizeOf(Byte);
type
  TRequest = record
              Len     : Word;
              SubF    : Byte;
              ObjT    : Word;
              Buf     : Array[1..BufSize] of Byte;
            end;
var
  Request : ^TRequest;
  Reply   : ^Word;
  NovRegs : Registers;
  Incr    : Word;
  Index   : Word;
  S, P : Pointer;
begin
  ChangePropertySecurity := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    SubF   := SubFChangePropSec;
    ObjT   := Swap(ObjType);
    Index  := 1;
    Incr   := Succ(Length(ObjName));
    Move(ObjName,Buf[Index],Incr);
    Inc(Index,Incr);
    Buf[Index] := NewPropertySecurity;
    Inc(Index);

    Incr   := Succ(Length(PropertyName));
    Move(PropertyName,Buf[Index],Incr);
    Inc(Index,Incr);
    Len := Index + 2; {3?}
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    ChangePropertySecurity := AL;
  end;
  FreeRealModeMem(P);
end;

function CloseBindery : Boolean;

type
  TRequest = record
               Len  : Word;
               SubF : Byte;
             end;
var
  Request : ^TRequest;
  Reply   : ^Word;
  NovRegs : Registers;
  S, P : Pointer;
begin
  CloseBindery := False;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    Len  := 1;
    SubF := SubFCloseBindery;
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    CloseBindery := AL = 0;
  end;
  FreeRealModeMem(P);
end;

function CreateObject(ObjType : Word; ObjName : ObjNameStr;
                      DynamicObj : Boolean;
                      ObjSecurity : Byte) : Byte;
type
  TRequest = record
               Len    : Word;
               SubF   : Byte;
               ObjF   : Boolean;
               ObjSec : Byte;
               ObjT   : Word;
               ObjN   : ObjNameStr;
             end;
var
  Request : ^TRequest;
  Reply   : ^Word;
  NovRegs : Registers;
  S, P : Pointer;
begin
  CreateObject := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    Len     := Length(ObjName) + 6;
    SubF    := SubFCreateObj;
    ObjF    := DynamicObj;
    ObjSec  := ObjSecurity;
    ObjT    := Swap(ObjType);
    ObjN    := ObjName;
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    CreateObject := AL;
  end;
  FreeRealModeMem(P);
end;

function CreateProperty(ObjType : Word; ObjName : ObjNameStr;
                        PropertyName : PropertyStr;
                        DynamicProp, SetProp : Boolean;
                        PropertySecurity : Byte) : Byte;
const
  BufSize = SizeOf(ObjNameStr) + (SizeOf(Byte) * 2) + SizeOf(PropertyStr);
type
  TRequest = record
               Len    : Word;
               SubF   : Byte;
               ObjT   : Word;
               Buf    : Array[1..BufSize] of Byte;
             end;
var
  Request : ^TRequest;
  Reply   : ^Word;
  NovRegs : Registers;
  Incr    : Word;
  Index   : Word;
  S, P    : Pointer;
begin
  CreateProperty := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    SubF   := SubFCreateProp;
    ObjT   := Swap(ObjType);
    Index  := 1;
    Incr   := Succ(Length(ObjName));
    Move(ObjName,Buf[Index],Incr);
    Inc(Index,Incr);
    Buf[Index] := (Ord(SetProp) shl 1) + Ord(DynamicProp);
    Inc(Index);
    Buf[Index] := PropertySecurity;
    Inc(Index);
    Incr   := Succ(Length(PropertyName));
    Move(PropertyName,Buf[Index],Incr);
    Inc(Index,Incr);
    Len := Index + 2; {3?}
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    CreateProperty := AL;
  end;
  FreeRealModeMem(P);
end;

function DeleteObject(ObjType : Word; ObjName : ObjNameStr) : Byte;
type
  TRequest = record
               Len    : Word;
               SubF   : Byte;
               ObjT   : Word;
               ObjN   : ObjNameStr;
             end;
var
  Request : ^TRequest;
  Reply   : ^Word;
  NovRegs : Registers;
  S, P : Pointer;

begin
  DeleteObject := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    Len     := Length(ObjName) + 4;
    SubF    := SubFDeleteObj;
    ObjT    := Swap(ObjType);
    ObjN    := ObjName;
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    DeleteObject := AL;
  end;
  FreeRealModeMem(P);
end;

function DeleteObjectFromSet(ObjType : Word; ObjName : ObjNameStr;
                             PropertyName : PropertyStr;
                             MemberObjType : Word;
                             MemberName : ObjNameStr) : Byte;

const
  BufSize = (SizeOf(ObjNameStr) * 2) + SizeOf(Word) + SizeOf(PropertyStr);
type
  TRequest = record
               Len    : Word;
               SubF   : Byte;
               ObjT   : Word;
               Buf    : Array[1..BufSize] of Byte;
             end;
var
  Request : ^TRequest;
  Reply   : ^Word;
  NovRegs : Registers;
  Incr    : Word;
  Index   : Word;
  S, P : Pointer;
begin
  DeleteObjectFromSet := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    SubF   := SubFDeleteObjFromSet;
    ObjT   := Swap(ObjType);
    Index  := 1;
    Incr   := Succ(Length(ObjName));
    Move(ObjName,Buf[Index],Incr);
    Inc(Index,Incr);
    Incr   := Succ(Length(PropertyName));
    Move(PropertyName,Buf[Index],Incr);
    Inc(Index,Incr);
    MemberObjType := Swap(MemberObjType);
    Move(MemberObjType,Buf[Index],SizeOf(Word));
    Inc(Index,SizeOf(Word));
    Incr   := Succ(Length(MemberName));
    Move(MemberName,Buf[Index],Incr);
    Inc(Index,Incr);

    Len := Index + 2; {3?}
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    DeleteObjectFromSet := AL;
  end;
  FreeRealModeMem(P);
end;

function DeleteProperty(ObjType : Word; ObjName : ObjNameStr;
                        PropertyName : PropertyStr) : Byte;

const
  BufSize = SizeOf(ObjNameStr) + SizeOf(PropertyStr);

type
  TRequest = record
               Len    : Word;
               SubF   : Byte;
               ObjT   : Word;
               Buf    : Array[1..BufSize] of Byte;
             end;
var
  Request : ^TRequest;
  Reply   : ^Word;
  NovRegs : Registers;
  Incr    : Word;
  Index   : Word;
  S, P : Pointer;
begin
  DeleteProperty := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    SubF   := SubFDeleteProp;
    ObjT   := Swap(ObjType);
    Index  := 1;
    Incr   := Succ(Length(ObjName));
    Move(ObjName,Buf[Index],Incr);
    Inc(Index,Incr);
    Incr   := Succ(Length(PropertyName));
    Move(PropertyName,Buf[Index],Incr);
    Inc(Index,Incr);

    Len := Index + 2; {3?}
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    DeleteProperty := AL;
  end;
end;

function GetBinderyAccessLevel(var AccessLevel : Byte;
                               var ObjectID : LongInt) : Byte;

type
  TRequest   = record
                 Len    : Word;
                 SubF   : Byte;
               end;
  TReply     = record
                 Len    : Word;
                 Level  : Byte;
                 ID     : LongInt;
               end;
var
  Request : ^TRequest;
  Reply : ^TReply;
  NovRegs   : Registers;
  S, P : Pointer;
begin
  GetBinderyAccessLevel := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  with Request^ do begin
    Len    := 1;
    SubF   := SubFGetAccessLevel;
  end;

  Reply^.Len := SizeOf(TReply) - 2;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    GetBinderyAccessLevel := AL;
  end;
  with Reply^ do begin
    AccessLevel := Level;
    ObjectID    := NetWareSwapLong(ID);
  end;
  FreeRealModeMem(P);
end;

function GetObjectID(var ObjType : Word; var ObjName : ObjNameStr;
                     var ObjID : LongInt) : Byte;
type
  TRequest   = record
                 Len    : Word;
                 SubF   : Byte;
                 ObjT   : Word;
                 ObjN   : ObjNameStr;
               end;
  TReply     = record
                 Len    : Word;
                 ID     : LongInt;
                 ObjT   : Word;
                 ObjN   : ObjNameStr;
               end;
var
  Request : ^TRequest;
  Reply : ^TReply;
  NovRegs   : Registers;
  S, P : Pointer;
begin
  GetObjectID := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  with Request^ do begin
    Len    := Length(ObjName) + 4;
    SubF   := SubFGetObjID;
    ObjT   := Swap(ObjType);
    ObjN   := ObjName;
  end;

  Reply^.Len := SizeOf(TReply) - 2;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    GetObjectID := AL;
  end;
  with Reply^ do begin
    ObjID   := NetWareSwapLong(ID);
    ObjType := Swap(ObjT);
    ObjName := AsciiZ2Str(ObjN,SizeOf(ObjNameStr)-1);
  end;
  FreeRealModeMem(P);
end;

function GetObjectName(ObjectID : LongInt;
                       var ObjType : Word;
                       var ObjName : ObjNameStr) : Byte;

type
  TRequest   = record
                 Len    : Word;
                 SubF   : Byte;
                 ID     : LongInt;
               end;
  TReply     = record
                 Len    : Word;
                 ID     : LongInt;
                 ObjT   : Word;
                 ObjN   : ObjNameStr;
               end;
var
  Request : ^TRequest;
  Reply : ^TReply;
  NovRegs   : Registers;
  S, P : Pointer;
begin
  GetObjectName := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  with Request^ do begin
    Len    := SizeOf(TRequest) - 2;
    SubF   := SubFGetObjName;
    ID     := NetWareSwapLong(ObjectID);
  end;
  Reply^.Len := SizeOf(TReply) - 2;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    GetObjectName := AL;
  end;
  with Reply^ do begin
    ObjType := Swap(ObjT);
    ObjName := AsciiZ2Str(ObjN,SizeOf(ObjNameStr)-1);
  end;
  FreeRealModeMem(P);
end;

function IsObjectInSet(ObjType : Word; ObjName : ObjNameStr;
                       PropertyName  : PropertyStr;
                       MemberObjType : Word;
                       MemberName    : ObjNameStr) : Byte;
  {-Returns 0 as function result if member is in set}
const
  BufSize = (SizeOf(ObjNameStr) * 2) + SizeOf(Word) + SizeOf(PropertyStr);

type
  TRequest = record
               Len    : Word;
               SubF   : Byte;
               ObjT   : Word;
               Buf    : Array[1..BufSize] of Byte;
             end;
var
  Request : ^TRequest;
  Reply   : ^Word;
  NovRegs : Registers;
  Incr    : Word;
  Index   : Word;
  S, P : Pointer;
begin
  IsObjectInSet := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    SubF   := SubFIsObjInSet;
    ObjT   := Swap(ObjType);
    Index  := 1;
    Incr   := Succ(Length(ObjName));
    Move(ObjName,Buf[Index],Incr);
    Inc(Index,Incr);
    Incr   := Succ(Length(PropertyName));
    Move(PropertyName,Buf[Index],Incr);
    Inc(Index,Incr);
    MemberObjType := Swap(MemberObjType);
    Move(MemberObjType,Buf[Index],SizeOf(Word));
    Inc(Index,SizeOf(Word));
    Incr   := Succ(Length(MemberName));
    Move(MemberName,Buf[Index],Incr);
    Inc(Index,Incr);
    Len := Index + 2; {3?}
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    IsObjectInSet := AL;
  end;
  FreeRealModeMem(P);
end;

function OpenBindery : Boolean;

type
  TRequest = record
               Len  : Word;
               SubF : Byte;
             end;
var
  Request : ^TRequest;
  Reply   : ^Word;
  NovRegs : Registers;
  S, P : Pointer;
begin
  OpenBindery := False;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    Len  := 1;
    SubF := SubFOpenBindery;
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    OpenBindery := AL = 0;
  end;
  FreeRealModeMem(P);
end;

function ReadPropertyValue(ObjType : Word; ObjName : ObjNameStr;
                           SegmentNumber : Byte;
                           PropertyName  : PropertyStr;
                           var PropertyValue : PropertyValueType;
                           var PropertyFlags : Byte;
                           var MoreSegments  : Boolean) : Byte;

const
  BufSize = SizeOf(ObjNameStr) + SizeOf(Byte) + SizeOf(PropertyStr);

type
  TRequest = record
               Len    : Word;
               SubF   : Byte;
               ObjT   : Word;
               Buf    : Array[1..BufSize] of Byte;
             end;
  TReply   = record
               Len    : Word;
               PVal   : PropertyValueType;
               More   : Byte;
               PFlags : Byte;
             end;
var
  Request : ^TRequest;
  Reply   : ^TReply;
  NovRegs : Registers;
  Incr    : Word;
  Index   : Word;
  S, P : Pointer;
begin
  ReadPropertyValue := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  with Request^ do begin
    SubF   := SubFReadPropVal;
    ObjT   := Swap(ObjType);
    Index  := 1;
    Incr   := Succ(Length(ObjName));
    Move(ObjName,Buf[Index],Incr);
    Inc(Index,Incr);
    Buf[Index] := SegmentNumber;
    Inc(Index);
    Incr   := Succ(Length(PropertyName));
    Move(PropertyName,Buf[Index],Incr);
    Inc(Index,Incr);
    Len := Index + 2; {3?}
  end;
  Reply^.Len := SizeOf(TReply) - 2;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    ReadPropertyValue := AL;
  end;
  with Reply^ do begin
    PropertyValue := PVal;
    MoreSegments  := More <> 0;
    PropertyFlags := PFlags;
  end;
  FreeRealModeMem(P);
end;

function WritePropertyValue(ObjType : Word; ObjName : ObjNameStr;
                           SegmentNumber : Byte;
                           PropertyName  : PropertyStr;
                           var PropertyValue : PropertyValueType;
                           EraseRemainingSegments : Boolean) : byte;

const
  BufSize = Sizeof(ObjName) + Sizeof(Byte) + Sizeof(Byte) +
        Sizeof(PropertyName) + Sizeof(PropertyValueType);

type
  TRequest = record
              Len    : Word;
              SubF   : Byte;
              ObjT   : Word;
              Buf    : Array[1..BufSize] of Byte;
            end;
  TReply   = record
              Len    : Word;
            end;

var
  Request : ^TRequest;
  Reply   : ^TReply;
  NovRegs : Registers;
  Incr    : Word;
  Index   : Word;
  S,P     : pointer;

begin
  WritePropertyValue := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  with Request^ do begin
    SubF   := SubFWritePropVal;
    ObjT   := Swap(ObjType);
    Index  := 1;
    Incr   := Succ(Length(ObjName));
    Move(ObjName,Buf[Index],Incr);
    Inc(Index,Incr);
    Buf[Index] := SegmentNumber;
    Inc(Index);
    if EraseRemainingSegments then
      Buf[Index] := $00
    else
      Buf[Index] := $FF;
    inc(Index);
    Incr   := Succ(Length(PropertyName));
    Move(PropertyName,Buf[Index],Incr);
    Inc(Index,Incr);
    Move(PropertyValue,Buf[Index],Sizeof(PropertyValue));
    Len := Index + Sizeof(PropertyValue) + 2;
  end;
  Reply^.Len := SizeOf(Reply) - 2;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := Sizeof(TRequest);
    WinIntr($21,NovRegs);
    WritePropertyValue := AL;
  end;
end;

function RenameObject(ObjType : Word;
                      OldObjName, NewObjName : ObjNameStr) : Byte;

const
  BufSize = SizeOf(ObjNameStr) * 2;

type
  TRequest = record
               Len    : Word;
               SubF   : Byte;
               ObjT   : Word;
               Buf    : Array[1..BufSize] of Byte;
             end;
var
  Request : ^TRequest;
  Reply   : ^Word;
  NovRegs : Registers;
  Incr    : Word;
  Index   : Word;
  S, P : Pointer;
begin
  RenameObject := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    SubF   := SubFRenameObj;
    ObjT   := Swap(ObjType);
    Index  := 1;
    Incr   := Succ(Length(OldObjName));
    Move(OldObjName,Buf[Index],Incr);
    Inc(Index,Incr);
    Incr   := Succ(Length(NewObjName));
    Move(NewObjName,Buf[Index],Incr);
    Inc(Index,Incr);
    Len := Index + 2; {3?}
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    RenameObject := AL;
  end;
  FreeRealModeMem(P);
end;

function ScanObject(var ObjType       : Word;
                    var ObjName       : ObjNameStr;
                    var ObjID         : LongInt;
                    var ObjFlag       : Byte;
                    var ObjSecurity   : Byte;
                    var HasProperties : Boolean) : Byte;
const
  ReplyBSize = SizeOf(ObjNameStr) + (SizeOf(Byte) * 3);

type
  TRequest = record
               Len    : Word;
               SubF   : Byte;
               LastID : LongInt;
               ObjT   : Word;
               ObjN   : ObjNameStr;
             end;
  TReply   = record
               Len    : Word;
               ID     : LongInt;
               ObjT   : Word;
               ObjN   : ObjNameField;
               ObjF   : Byte;
               ObjSec : Byte;
               HasProp: Byte;
             end;
var
  Request : ^TRequest;
  Reply   : ^TReply;
  NovRegs : Registers;
  Index   : Word;
  L       : Word;
  S, P : Pointer;
begin
  ScanObject := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  with Request^ do begin
    SubF   := SubFScanObj;
    LastID := NetWareSwapLong(ObjID);
    ObjT   := Swap(ObjType);
    ObjN   := ObjName;
    Len    := Length(ObjName) + 8;
  end;
  Reply^.Len := SizeOf(TReply) - 2;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    ScanObject := AL;
    if AL = 0 then
      with Reply^ do begin
        ObjID         := NetWareSwapLong(ID);
        ObjType       := Swap(ObjT);
        ObjName       := AsciiZ2Str(ObjN,SizeOf(ObjNameStr)-1);
        ObjFlag       := ObjF;
        ObjSecurity   := ObjSec;
        HasProperties := HasProp <> 0;
      end;
  end;
  FreeRealModeMem(P);
end;

function ScanProperty(ObjType : Word; ObjName : ObjNameStr;
                      var Sequence : LongInt;
                      var PropertyName : PropertyStr;
                      var PropertyFlags, PropertySecurity : Byte;
                      var HasValue, MoreProperties : Boolean) : Byte;

const
  BufSize = SizeOf(ObjNameStr) + SizeOf(LongInt) + SizeOf(PropertyStr);
type
  TRequest = record
               Len    : Word;
               SubF   : Byte;
               ObjT   : Word;
               Buf    : Array[1..BufSize] of Byte;
             end;
  TReply   = record
               Len      : Word;
               PropN    : PropertyField;
               PropF    : Byte;
               PropSec  : Byte;
               SeqNum   : LongInt;
               HasVal   : Byte;
               More     : Byte;
             end;
var
  Request : ^TRequest;
  Reply   : ^TReply;
  NovRegs : Registers;
  Index   : Word;
  Incr    : Word;
  S, P : Pointer;
begin
  ScanProperty := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(TReply), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  with Request^ do begin
    SubF   := SubFScanProp;
    ObjT   := Swap(ObjType);
    Index  := 1;
    Incr   := Succ(Length(ObjName));
    Move(ObjName,Buf[Index],Incr);
    Inc(Index,Incr);
    Move(Sequence,Buf[Index],SizeOf(LongInt));
    Inc(Index,SizeOf(LongInt));
    Incr   := Succ(Length(PropertyName));
    Move(PropertyName,Buf[Index],Incr);
    Inc(Index,Incr);
    Len := Index + 2; {3?}
  end;
  Reply^.Len := SizeOf(TReply) - 2;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    ScanProperty := AL;
    if AL = 0 then
      with Reply^ do begin
        PropertyName     := AsciiZ2Str(PropN,SizeOf(PropertyStr) - 1);
        PropertyFlags    := PropF;
        PropertySecurity := PropSec;
        Sequence         := SeqNum;
        HasValue         := HasVal <> 0;
        MoreProperties   := More <> 0;
      end
    else begin
      HasValue         := False;
      MoreProperties   := False;
    end;
  end;
  FreeRealModeMem(P);
end;

function VerifyPassword(ObjType : Word; ObjName : ObjNameStr;
                        Password : PasswordStr) : Byte;

const
  BufSize = SizeOf(PasswordStr) + SizeOf(ObjNameStr);
type
  TRequest = record
               Len     : Word;
               SubF    : Byte;
               ObjT    : Word;
               Buf     : Array[1..BufSize] of Char;
             end;
var
  Request : ^TRequest;
  Reply   : ^Word;
  NovRegs : Registers;
  Incr    : Word;
  Index   : Word;
  S, P : Pointer;
begin
  VerifyPassword := DPMIErrorVal;
  if not GetRealModeMem(SizeOf(TRequest)+SizeOf(Word), S, P) then exit;
  Request := P;
  Reply := P;
  Inc(Word(Reply), SizeOf(TRequest));
  Reply^ := $0000;

  with Request^ do begin
    SubF   := SubFVerifyPass;
    ObjT   := Swap(ObjType);
    Index  := 1;
    Incr   := Succ(Length(ObjName));
    Move(ObjName,Buf[Index],Incr);
    Inc(Index,Incr);

    Incr   := Succ(Length(Password));
    Move(Password,Buf[Index],Incr);
    Inc(Index,Incr);
    Len := Index + 2;
  end;

  with NovRegs do begin
    AH := BinderyFunc;
    DS := SegOfs(S).Segm;
    SI := 0;
    ES := SegOfs(S).Segm;
    DI := SizeOf(TRequest);
    WinIntr($21, NovRegs);
    VerifyPassword := AL;
  end;
  FreeRealModeMem(P);
end;

