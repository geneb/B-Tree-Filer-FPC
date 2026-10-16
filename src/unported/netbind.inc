{
  NETBIND.INC 1.1
}
function AddObjectToSet(ObjType : Word; ObjName : ObjNameStr;
                        PropertyName : PropertyStr;
                        MemberObjType : Word;
                        MemberObjName : ObjNameStr) : Byte;

var
  RequestBuffer : record
                    Len     : Word;
                    SubF    : Byte;
                    ObjT    : Word;
                    Buf     : Array[1..118] of Byte;
                  end;
  Reply         : Word;
  NovRegs       : Registers;
  Incr          : Word;
  Index         : Byte;
begin
  with RequestBuffer do begin
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
  Reply := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(RequestBuffer);
    SI := Ofs(RequestBuffer);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    AddObjectToSet := AL;
  end;
end;

function ChangePassword(ObjType : Word; ObjName : ObjNameStr;
                        OldPassword, NewPassword : PasswordStr) : Byte;

const
  BufSize = (SizeOf(PasswordStr) * 2) + SizeOf(ObjNameStr);
var
  Request : record
              Len     : Word;
              SubF    : Byte;
              ObjT    : Word;
              Buf     : Array[1..BufSize] of Byte;
            end;
  Reply   : Word;
  NovRegs : Registers;
  Incr    : Word;
  Index   : Word;

begin
  with Request do begin
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
  Reply := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    ChangePassword := AL;
  end;
end;

function ChangeObjectSecurity(ObjType : Word; ObjName : ObjNameStr;
                              NewSecurity : Byte) : Byte;

var
  Request : record
              Len     : Word;
              SubF    : Byte;
              NewSec  : Byte;
              ObjT    : Word;
              ObjN    : ObjNameStr;
            end;
  Reply   : Word;
  NovRegs : Registers;

begin
  with Request do begin
    Len     := Length(ObjName) + 4;
    SubF    := SubFChangeObjSec;
    NewSec  := NewSecurity;
    ObjT    := Swap(ObjType);
    ObjN    := ObjName;
  end;
  Reply := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    ChangeObjectSecurity := AL;
  end;
end;

function ChangePropertySecurity(ObjType : Word; ObjName : ObjNameStr;
                                PropertyName : PropertyStr;
                                NewPropertySecurity : Byte) : Byte;


const
  BufSize = SizeOf(ObjNameStr) + SizeOf(PropertyStr) + SizeOf(Byte);
var
  Request : record
              Len     : Word;
              SubF    : Byte;
              ObjT    : Word;
              Buf     : Array[1..BufSize] of Byte;
            end;
  Reply   : Word;
  NovRegs : Registers;
  Incr    : Word;
  Index   : Word;

begin
  with Request do begin
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
  Reply := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    ChangePropertySecurity := AL;
  end;
end;

function CloseBindery : Boolean;

var
  Request : record
              Len  : Word;
              SubF : Byte;
            end;
  Reply   : Word;
  NovRegs : Registers;

begin
  with Request do begin
    Len  := 1;
    SubF := SubFCloseBindery;
  end;
  Reply := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    CloseBindery := AL = 0;
  end;
end;

function CreateObject(ObjType : Word; ObjName : ObjNameStr;
                      DynamicObj : Boolean;
                      ObjSecurity : Byte) : Byte;
var
  Request : record
              Len    : Word;
              SubF   : Byte;
              ObjF   : Boolean;
              ObjSec : Byte;
              ObjT   : Word;
              ObjN   : ObjNameStr;
            end;
  Reply   : Word;
  NovRegs : Registers;

begin
  with Request do begin
    Len     := Length(ObjName) + 6;
    SubF    := SubFCreateObj;
    ObjF    := DynamicObj;
    ObjSec  := ObjSecurity;
    ObjT    := Swap(ObjType);
    ObjN    := ObjName;
  end;
  Reply := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    CreateObject := AL;
  end;
end;

function CreateProperty(ObjType : Word; ObjName : ObjNameStr;
                        PropertyName : PropertyStr;
                        DynamicProp, SetProp : Boolean;
                        PropertySecurity : Byte) : Byte;
const
  BufSize = SizeOf(ObjNameStr) + (SizeOf(Byte) * 2) + SizeOf(PropertyStr);
var
  Request : record
              Len    : Word;
              SubF   : Byte;
              ObjT   : Word;
              Buf    : Array[1..BufSize] of Byte;
            end;
  Reply   : Word;
  NovRegs : Registers;
  Incr    : Word;
  Index   : Word;
begin
  with Request do begin
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
  Reply := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    CreateProperty := AL;
  end;
end;

function DeleteObject(ObjType : Word; ObjName : ObjNameStr) : Byte;
var
  Request : record
              Len    : Word;
              SubF   : Byte;
              ObjT   : Word;
              ObjN   : ObjNameStr;
            end;
  Reply   : Word;
  NovRegs : Registers;

begin
  with Request do begin
    Len     := Length(ObjName) + 4;
    SubF    := SubFDeleteObj;
    ObjT    := Swap(ObjType);
    ObjN    := ObjName;
  end;
  Reply := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    DeleteObject := AL;
  end;
end;

function DeleteObjectFromSet(ObjType : Word; ObjName : ObjNameStr;
                             PropertyName : PropertyStr;
                             MemberObjType : Word;
                             MemberName : ObjNameStr) : Byte;

const
  BufSize = (SizeOf(ObjNameStr) * 2) + SizeOf(Word) + SizeOf(PropertyStr);
var
  Request : record
              Len    : Word;
              SubF   : Byte;
              ObjT   : Word;
              Buf    : Array[1..BufSize] of Byte;
            end;
  Reply   : Word;
  NovRegs : Registers;
  Incr    : Word;
  Index   : Word;
begin
  with Request do begin
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
  Reply := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    DeleteObjectFromSet := AL;
  end;
end;

function DeleteProperty(ObjType : Word; ObjName : ObjNameStr;
                        PropertyName : PropertyStr) : Byte;

const
  BufSize = SizeOf(ObjNameStr) + SizeOf(PropertyStr);

var
  Request : record
              Len    : Word;
              SubF   : Byte;
              ObjT   : Word;
              Buf    : Array[1..BufSize] of Byte;
            end;
  Reply   : Word;
  NovRegs : Registers;
  Incr    : Word;
  Index   : Word;

begin
  with Request do begin
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
  Reply := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    DeleteProperty := AL;
  end;
end;

function GetBinderyAccessLevel(var AccessLevel : Byte;
                               var ObjectID : LongInt) : Byte;

var
  Request   : record
                Len    : Word;
                SubF   : Byte;
              end;
  Reply     : record
                Len    : Word;
                Level  : Byte;
                ID     : LongInt;
              end;
  NovRegs   : Registers;

begin
  with Request do begin
    Len    := 1;
    SubF   := SubFGetAccessLevel;
  end;
  Reply.Len := SizeOf(Reply) - 2;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    GetBinderyAccessLevel := AL;
  end;
  with Reply do begin
    AccessLevel := Level;
    ObjectID    := NetWareSwapLong(ID);
  end;
end;

function GetObjectID(var ObjType : Word; var ObjName : ObjNameStr;
                     var ObjID : LongInt) : Byte;
var
  Request   : record
                Len    : Word;
                SubF   : Byte;
                ObjT   : Word;
                ObjN   : ObjNameStr;
              end;
  Reply     : record
                Len    : Word;
                ID     : LongInt;
                ObjT   : Word;
                ObjN   : ObjNameStr;
              end;
  NovRegs   : Registers;

begin
  with Request do begin
    Len    := Length(ObjName) + 4;
    SubF   := SubFGetObjID;
    ObjT   := Swap(ObjType);
    ObjN   := ObjName;
  end;
  Reply.Len := SizeOf(Reply) - 2;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    GetObjectID := AL;
  end;
  with Reply do begin
    ObjID   := NetWareSwapLong(ID);
    ObjType := Swap(ObjT);
    ObjName := AsciiZ2Str(ObjN,SizeOf(ObjNameStr)-1);      {!!.23}
  end;
end;

function GetObjectName(ObjectID : LongInt;
                       var ObjType : Word;
                       var ObjName : ObjNameStr) : Byte;

var
  Request   : record
                Len    : Word;
                SubF   : Byte;
                ID     : LongInt;
              end;
  Reply     : record
                Len    : Word;
                ID     : LongInt;
                ObjT   : Word;
                ObjN   : ObjNameStr;
              end;
  NovRegs   : Registers;

begin
  with Request do begin
    Len    := SizeOf(Request) - 2;
    SubF   := SubFGetObjName;
    ID     := NetWareSwapLong(ObjectID);
  end;
  Reply.Len := SizeOf(Reply) - 2;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    GetObjectName := AL;
  end;
  with Reply do begin
    ObjType := Swap(ObjT);
    ObjName := AsciiZ2Str(ObjN,SizeOf(ObjNameStr)-1);
  end;
end;

function IsObjectInSet(ObjType : Word; ObjName : ObjNameStr;
                       PropertyName  : PropertyStr;
                       MemberObjType : Word;
                       MemberName    : ObjNameStr) : Byte;
  {-Returns 0 as function result if member is in set}
const
  BufSize = (SizeOf(ObjNameStr) * 2) + SizeOf(Word) + SizeOf(PropertyStr);

var
  Request : record
              Len    : Word;
              SubF   : Byte;
              ObjT   : Word;
              Buf    : Array[1..BufSize] of Byte;
            end;
  Reply   : Word;
  NovRegs : Registers;
  Incr    : Word;
  Index   : Word;

begin
  with Request do begin
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
  Reply := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    IsObjectInSet := AL;
  end;
end;

function OpenBindery : Boolean;

var
  Request : record
              Len  : Word;
              SubF : Byte;
            end;
  Reply   : Word;
  NovRegs : Registers;

begin
  with Request do begin
    Len  := 1;
    SubF := SubFOpenBindery;
  end;
  Reply := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    OpenBindery := AL = 0;
  end;
end;

function ReadPropertyValue(ObjType : Word; ObjName : ObjNameStr;
                           SegmentNumber : Byte;
                           PropertyName  : PropertyStr;
                           var PropertyValue : PropertyValueType;
                           var PropertyFlags : Byte;
                           var MoreSegments  : Boolean) : Byte;

const
  BufSize = SizeOf(ObjNameStr) + SizeOf(Byte) + SizeOf(PropertyStr);

var
  Request : record
              Len    : Word;
              SubF   : Byte;
              ObjT   : Word;
              Buf    : Array[1..BufSize] of Byte;
            end;
  Reply   : record
              Len    : Word;
              PVal   : PropertyValueType;
              More   : Byte;
              PFlags : Byte;
            end;
  NovRegs : Registers;
  Incr    : Word;
  Index   : Word;

begin
  with Request do begin
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
  Reply.Len := SizeOf(Reply) - 2;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    ReadPropertyValue := AL;
  end;
  with Reply do begin
    PropertyValue := PVal;
    MoreSegments  := More <> 0;
    PropertyFlags := PFlags;
  end;
end;

function WritePropertyValue(ObjType : Word; ObjName : ObjNameStr;
                           SegmentNumber : Byte;
                           PropertyName  : PropertyStr;
                           var PropertyValue : PropertyValueType;
                           EraseRemainingSegments : Boolean) : byte;

const
  BufSize = Sizeof(ObjName) + Sizeof(Byte) + Sizeof(Byte) +
        Sizeof(PropertyName) + Sizeof(PropertyValueType);

var
  Request : record
              Len    : Word;
              SubF   : Byte;
              ObjT   : Word;
              Buf    : Array[1..BufSize] of Byte;
            end;
  Reply   : record
              Len    : Word;
            end;
  NovRegs : Registers;
  Incr    : Word;
  Index   : Word;

begin
  with Request do begin
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
  Reply.Len := SizeOf(Reply) - 2;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    WritePropertyValue := AL;
  end;
end;

function RenameObject(ObjType : Word;
                      OldObjName, NewObjName : ObjNameStr) : Byte;

const
  BufSize = SizeOf(ObjNameStr) * 2;

var
  Request : record
              Len    : Word;
              SubF   : Byte;
              ObjT   : Word;
              Buf    : Array[1..BufSize] of Byte;
            end;
  Reply   : Word;
  NovRegs : Registers;
  Incr    : Word;
  Index   : Word;

begin
  with Request do begin
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
  Reply := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    RenameObject := AL;
  end;
end;

function ScanObject(var ObjType       : Word;
                    var ObjName       : ObjNameStr;
                    var ObjID         : LongInt;
                    var ObjFlag       : Byte;
                    var ObjSecurity   : Byte;
                    var HasProperties : Boolean) : Byte;
const
  ReplyBSize = SizeOf(ObjNameStr) + (SizeOf(Byte) * 3);

var
  Request : record
              Len    : Word;
              SubF   : Byte;
              LastID : LongInt;
              ObjT   : Word;
              ObjN   : ObjNameStr;
            end;
  Reply   : record
              Len    : Word;
              ID     : LongInt;
              ObjT   : Word;
              ObjN   : ObjNameField;
              ObjF   : Byte;
              ObjSec : Byte;
              HasProp: Byte;
            end;
  NovRegs : Registers;
  Index   : Word;
  L       : Word;

begin
  with Request do begin
    SubF   := SubFScanObj;
    LastID := NetWareSwapLong(ObjID);
    ObjT   := Swap(ObjType);
    ObjN   := ObjName;
    Len    := Length(ObjName) + 8;
  end;
  Reply.Len := SizeOf(Reply) - 2;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    ScanObject := AL;
    if AL = 0 then
      with Reply do begin
        ObjID         := NetWareSwapLong(ID);
        ObjType       := Swap(ObjT);
        ObjName       := AsciiZ2Str(ObjN,SizeOf(ObjNameStr)-1);
        ObjFlag       := ObjF;
        ObjSecurity   := ObjSec;
        HasProperties := HasProp <> 0;
      end;
  end;
end;

function ScanProperty(ObjType : Word; ObjName : ObjNameStr;
                      var Sequence : LongInt;
                      var PropertyName : PropertyStr;
                      var PropertyFlags, PropertySecurity : Byte;
                      var HasValue, MoreProperties : Boolean) : Byte;

const
  BufSize = SizeOf(ObjNameStr) + SizeOf(LongInt) + SizeOf(PropertyStr);
var
  Request : record
              Len    : Word;
              SubF   : Byte;
              ObjT   : Word;
              Buf    : Array[1..BufSize] of Byte;
            end;
  Reply   : record
              Len      : Word;
              PropN    : PropertyField;
              PropF    : Byte;
              PropSec  : Byte;
              SeqNum   : LongInt;
              HasVal   : Byte;
              More     : Byte;
            end;
  NovRegs : Registers;
  Index   : Word;
  Incr    : Word;

begin
  with Request do begin
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
  Reply.Len := SizeOf(Reply) - 2;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    ScanProperty := AL;
    if AL = 0 then
      with Reply do begin
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
end;

function VerifyPassword(ObjType : Word; ObjName : ObjNameStr;
                        Password : PasswordStr) : Byte;

const
  BufSize = SizeOf(PasswordStr) + SizeOf(ObjNameStr);
var
  Request : record
              Len     : Word;
              SubF    : Byte;
              ObjT    : Word;
              Buf     : Array[1..BufSize] of Char;
            end;
  Reply   : Word;
  NovRegs : Registers;
  Incr    : Word;
  Index   : Word;

begin
  with Request do begin
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
  Reply := 0;
  with NovRegs do begin
    AH := BinderyFunc;
    DS := Seg(Request);
    SI := Ofs(Request);
    ES := Seg(Reply);
    DI := Ofs(Reply);
    MsDos(NovRegs);
    VerifyPassword := AL;
  end;

end;

