{
  Turbo Pascal Unit of Bindery APIs for NetWare
  version 1.1    9/5/91

  by Richard S. Sadowsky

  Please address questions and comments about this unit to ALL in section 6 of
  the PCVENB forum on Compuserve.

  WritePropertyValue provided by Ted at Cord Camera, 12/21/92
}

{$A-,V-,F-}

Unit NetBind;

interface

{$IFDEF Windows}
  {$DEFINE WindowsOrDPMI}
{$ELSE}
  {$IFDEF DPMI}
    {$DEFINE WindowsOrDPMI}
  {$ENDIF}
{$ENDIF}

Uses
{$IFDEF Windows}
  WinProcs,
  WinTypes,
  WinDos,
  WinDPMI,
  NetWare;
{$ELSE}
  Dos,
  {$IFDEF DPMI}
  WinDPMI,
  {$ENDIF}
  NetWare;
{$ENDIF}

const
  {bindery object types}
  bindUnknown          = $0000;
  bindUser             = $0001;
  bindGroup            = $0002;
  bindPrintQueue       = $0003;
  bindFileServer       = $0004;
  bindJobServer        = $0005;
  bindGateway          = $0006;
  bindPrintServer      = $0007;
  bindArchiveQueue     = $0008;
  bindArchiveServer    = $0009;
  bindJobQueue         = $000A;
  bindAdministration   = $000B;
  bindRemoteBridge     = $0026;
  bindAdvertisingPrint = $0047;
  bindWild             = $FFFF;

  {Object Security Flags}
  bindAnyOne           = $00;
  bindLogged           = $01;
  bindObject           = $02;
  bindSupervisor       = $03;
  bindNetWare          = $04;

  {bindery Property Flags}
  bindStatic           = $00;
  bindDynamic          = $01;
  bindItem             = $00;
  bindSet              = $02;

  bindFirstProperty    = -1;

  bindSuccess          = $00;
  bindServerOutOfMem   = $96;
  bindMemberAlready    = $E9;
  bindNotGroupProperty = $EB;
  bindNoWildcard       = $F0;
  bindNoPropWritePriv  = $F8;
  bindNoSuchProperty   = $FB;
  bindNoSuchObject     = $FC;
  bindBinderyLocked    = $FE;
  bindBinderyFailure   = $FF;

{$IFDEF Windows}
type
  Registers = TRegisters;
{$ENDIF}

type
  ObjNameStr           = String[47];        {string type for object names}
  ObjNameField         = Array[0..47] of Char;
  PropertyField        = Array[0..15] of Char;
  PropertyStr          = String[15];        {string type for properties}
  PasswordStr          = String[127];       {string type for passwords}
  PropertyValueType    = record
                           case Boolean of
                             True  : (pvItem : Array[1..128] of Char);
                             False : (pvSet  : Array[1..32] of LongInt);
                         end;
const
  LogInControlSt       = 'LOGIN_CONTROL';
  AccountServersSt     = 'ACCOUT_SERVERS';
  AccountBalanceSt     = 'ACCOUNT_BALANCE';
  PasswordSt           = 'PASSWORD';
  SecurityEqualsSt     = 'SECURITY_EQUALS';
  GroupMembersSt       = 'GROUP_MEMBERS';
  GroupsImInSt         = 'GROUPS_I''M_IN';
  NetAddressSt         = 'NET_ADDRESS';
  IdentificationSt     = 'IDENTIFICATION';
  OperatorsSt          = 'OPERATORS';

  {bindery function and subfunction numbers}
  BinderyFunc          = $E3;
  SubFAddObjToSet      = $41;
  SubFChangeObjPass    = $40;
  SubFChangeObjSec     = $38;
  SubFChangePropSec    = $3B;
  SubFCloseBindery     = $44;
  SubFCreateObj        = $32;
  SubFCreateProp       = $39;
  SubFDeleteObj        = $33;
  SubFDeleteObjFromSet = $42;
  SubFDeleteProp       = $3A;
  SubFGetAccessLevel   = $46;
  SubFGetObjID         = $35;
  SubFGetObjName       = $36;
  SubFIsObjInSet       = $43;
  SubFOpenBindery      = $45;
  SubFReadPropVal      = $3D;
  SubFRenameObj        = $34;
  SubFScanObj          = $37;
  SubFScanProp         = $3C;
  SubFWritePropVal     = $3E;
  SubFVerifyPass       = $3F;

function AddObjectToSet(ObjType : Word; ObjName : ObjNameStr;
                        PropertyName : PropertyStr;
                        MemberObjType : Word;
                        MemberObjName : ObjNameStr) : Byte;
function ChangePassword(ObjType : Word; ObjName : ObjNameStr;
                        OldPassword, NewPassword : PasswordStr) : Byte;
function ChangeObjectSecurity(ObjType : Word; ObjName : ObjNameStr;
                              NewSecurity : Byte) : Byte;
function ChangePropertySecurity(ObjType : Word; ObjName : ObjNameStr;
                                PropertyName : PropertyStr;
                                NewPropertySecurity : Byte) : Byte;
function CloseBindery : Boolean;
function CreateObject(ObjType : Word; ObjName : ObjNameStr;
                      DynamicObj : Boolean;
                      ObjSecurity : Byte) : Byte;
function CreateProperty(ObjType : Word; ObjName : ObjNameStr;
                        PropertyName : PropertyStr;
                        DynamicProp, SetProp : Boolean;
                        PropertySecurity : Byte) : Byte;
function DeleteObject(ObjType : Word; ObjName : ObjNameStr) : Byte;
function DeleteObjectFromSet(ObjType : Word; ObjName : ObjNameStr;
                             PropertyName : PropertyStr;
                             MemberObjType : Word;
                             MemberName : ObjNameStr) : Byte;
function DeleteProperty(ObjType : Word; ObjName : ObjNameStr;
                        PropertyName : PropertyStr) : Byte;
function GetBinderyAccessLevel(var AccessLevel : Byte;
                               var ObjectID : LongInt) : Byte;
function GetObjectID(var ObjType : Word; var ObjName : ObjNameStr;
                     var ObjID : LongInt) : Byte;
function GetObjectName(ObjectID : LongInt;
                       var ObjType : Word;
                       var ObjName : ObjNameStr) : Byte;
function IsObjectInSet(ObjType : Word; ObjName : ObjNameStr;
                       PropertyName  : PropertyStr;
                       MemberObjType : Word;
                       MemberName    : ObjNameStr) : Byte;
  {-Returns 0 as function result if member is in set}
function OpenBindery : Boolean;
function ReadPropertyValue(ObjType : Word; ObjName : ObjNameStr;
                           SegmentNumber : Byte;
                           PropertyName  : PropertyStr;
                           var PropertyValue : PropertyValueType;
                           var PropertyFlags : Byte;
                           var MoreSegments  : Boolean) : Byte;
function RenameObject(ObjType : Word;
                      OldObjName, NewObjName : ObjNameStr) : Byte;
function ScanObject(var ObjType       : Word;
                    var ObjName       : ObjNameStr;
                    var ObjID         : LongInt;
                    var ObjFlag       : Byte;
                    var ObjSecurity   : Byte;
                    var HasProperties : Boolean) : Byte;
function ScanProperty(ObjType : Word; ObjName : ObjNameStr;
                      var Sequence : LongInt;
                      var PropertyName : PropertyStr;
                      var PropertyFlags, PropertySecurity : Byte;
                      var HasValue, MoreProperties : Boolean) : Byte;
function VerifyPassword(ObjType : Word; ObjName : ObjNameStr;
                        Password : PasswordStr) : Byte;

implementation

{$IFDEF WindowsOrDPMI}
  {$I NETBINDW.INC}
{$ELSE}
  {$I NETBIND.INC}
{$ENDIF}

end.

