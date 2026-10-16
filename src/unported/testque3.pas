{
  TESTQUE3 - Program to test NetWare QMS functions
             by Richard S. Sadowsky

  This program destroys (deletes) the queue created by TESTQUE.
}
program TestQue3;
uses
  {$IFDEF Windows}
  TpString,
  WinCrt,
  {$ELSE}
  OpString,
  {$ENDIF}
  NetBind,
  NetQue;

const
  OurQueName = 'RICH_Q';

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
  QueueName : ObjNameStr;

begin
  ObjectType := bindJobQueue;
  QueueName := OurQueName;
  Result := ScanObject(ObjectType, QueueName, QueueID, ObjectFlag,
                       ObjectSec, HasProp);
  if Result = 0 then
    WriteLn('Result of destroy queue: ',
            HexB(DestroyQueue(QueueID)))
  else
    WriteLn(OurQueName, ' not found');
end.
