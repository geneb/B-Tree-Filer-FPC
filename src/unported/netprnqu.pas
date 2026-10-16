{
  Turbo Pascal Unit of Print Queue Services for NetWare
  Version 1.0  10/2/92

  by Richard S. Sadowsky

  Please address questions and comments about this unit to ALL in section 6 of
  the PCVENB forum on Compuserve.
}
{$S-,R-,V-,I-}
unit NetPrnQue;
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
  NetQue;

{$IFDEF Windows}
type
  Registers            = TRegisters;
{$ENDIF}

const
  DefaultCPP = 132;
  DefaultLPP = 60;

  {print queue flags}
  pqPrintBanner    = $80;    {when set, the banner page is printed}
  pqText           = $40;    {when set, indicates tabs should be expanded}
  pqNotify         = $10;    {when set, NetWare will notify station when done}
  pqFormFeed       = $08;    {when set, suppresses the form feed added by NetWare}

type
  PPrintQueClientRec = ^TPrintQueClientRec;
  TPrintQueClientRec =
    record
      Dummy : Byte;   {server printer?}
      TabSize : Byte; {1..18}
      NumCopies : Word;                                {hi-lo}
      Dummy2 : Byte;
      Flags : Byte;   {Print flags:
                         04h - print interrupted capture
                         08h - Suppress auto form feed
                         10h - Notify submitting station when done
                         40h - Enable tab expansion
                         80h - Print Banner page
                       }
      LinesPerPage : Word;                             {hi-lo}
      ColsPerPage  : Word;                             {hi-lo}
      Unknown : Array[1..22] of Char;
      BannerName : Array[1..13] of Char;
      UserName : Array[1..13] of Char;
    end;

function GetPrinterQueue(LPTDevice : Byte; var printQueueID : LongInt) : Byte;
  {-Undocumented NetWare function to obtain the print queue assigned to a
    specific local LPT port (0=LPT1, 1=LP2, 2=LPT3). Returns 0 if successful.}

procedure MakeClientRecord(pTabSize : Byte; pNumCopies : Word; pFlags : Byte;
                           pLinesPerPage : Word; pColsPerPage : Word;
                           pBannerName : Str20; pUserName : String;
                           var ClientArea : ClientRecordArea);
  {-Given some printer parameters, this routine initializes the
    ClientRecordArea of the JobEntryType. The information needed to write
    this function appears to be undocumented. I obtained the info by reverse
    engineering print jobs created by NetWare.

    pTabSize must be between 1..12 (18?)

    pNumCopies must be 1 or more

    pFlags can be any combination of:
      pqPrintBanner    = $80; print banner
      pqText           = $40; enables tab expansion
      pqNotify         = $10; notifies the submitting workstation when done
      pqFormFeed       = $08; Suppress form feed after form

    pLinesPerPage (not sure how this is used, pass zero here for default)

    pColsPerPage  (not sure how this is used, pass zero here for default)

    pBannerName is the name to appear in the banner. Only has meaning if the
                pqPrintBanner flag is set in pFlags.

     pUserName is the user name to appear in the banner. Only has meaning if
              the pqPrintBanner flag is set in pFlags.

    ClientArea will be formatted correctly for a call to CreateQueueJobAndFile
               (or our higher level replacement, AddFileToPrintQueue).
  }

function AddFileToPrintQueue(QueueID : LongInt;
                             var JobEntry : JobEntryType;
                             FName : String) : Byte;
  {-Adds the file specified by FName to the specified PrintQueue. JobEntry must
    be properly initialized before the call. This call actually copies the
    specified file into the print queue. Returns 0 on success, otherwise DOS or
    NetWare error code.

    The following fields of JobEntry must be initialized before this call:
      TargetServerID   - use -1 to indicate "any server"
      TargetExecTime   - fill with $FF to indicate "first opportunity"
      JobControlFlags  - See the jcfXXX constants in NETQUE.PAS
      TextJobDesc      - Asciiz string text description of print job
  }

implementation

{$IFDEF WindowsOrDPMI}
  {$I NETPRNQW.INC}
{$ELSE}
  {$I NETPRNQU.INC}
{$ENDIF}

procedure MakeClientRecord(pTabSize : Byte; pNumCopies : Word; pFlags : Byte;
                           pLinesPerPage : Word; pColsPerPage : Word;
                           pBannerName : Str20; pUserName : String;
                           var ClientArea : ClientRecordArea);
const
  UnknownConst : Array[0..21] of Char = 'UNKNOWN'#0#0#0#0#0#0#0#0#0#0#0#0#0#0#0;

var
  Client : TPrintQueClientRec absolute ClientArea;
begin
  FillChar(ClientArea, SizeOf(ClientArea), 0);
  with Client do begin
    TabSize := pTabSize;
    NumCopies := Swap(pNumCopies);
    Flags := pFlags;
    if pLinesPerPage = 0 then
      LinesPerPage := Swap(DefaultLPP)
    else
      LinesPerPage := Swap(pLinesPerPage);
    if pColsPerPage = 0 then
      ColsPerPage := Swap(DefaultCPP)
    else
      ColsPerPage := Swap(pColsPerPage);
    Move(UnknownConst, Unknown, SizeOf(Unknown));
    if Length(pBannerName) > 13 then
      Byte(pBannerName[0]) := 13;
    Move(pBannerName[1], BannerName, Length(pBannerName));
    if Length(pUserName) > 13 then
      Byte(pUserName[0]) := 13;
    Move(pUserName[1], UserName, Length(pUserName));
  end;
end;

function AddFileToPrintQueue(QueueID : LongInt;
                             var JobEntry : JobEntryType;
                             FName : String) : Byte;
const
  BufferSize = 8192;
var
  NumRead : Word;
  Buffer : Pointer;
  InF, F : File;
  Result : Byte;
begin
  GetMem(Buffer, BufferSize);
  if Buffer = Nil then begin
    AddFileToPrintQueue := 8;
    Exit;
  end;
  Assign(InF, FName);
  Reset(InF, 1);
  Result := IoResult;
  if Result = 0 then begin
    Result := CreateQueueJobAndFile(QueueID, JobEntry, JobEntry);
    if Result = 0 then begin
      Assign(F, 'NETQ');
      Reset(F, 1);                          {!!.01} {ReWrite}
      Result := IoResult;
      while (Result = 0) and (not EOF(InF)) do begin
        BlockRead(InF, Buffer^, BufferSize, NumRead);
        Result := IoResult;
        if Result = 0 then begin
          BlockWrite(F, Buffer^, NumRead);
          Result := IoResult;
        end;
      end;
      Close(F);
      if Result = 0 then begin
        Result := IoResult;
        Result := CloseFileAndStartJob(QueueID, Swap(JobEntry.JobNumber));
      end
      else begin
        if IoResult <> 0 then ;
        if AbortServicingQueueJob(QueueID, Swap(JobEntry.JobNumber)) <> 0 then ;
      end;
    end;
    Close(InF);
    if IoResult <> 0 then ;
  end;
  FreeMem(Buffer, BufferSize);
  AddFileToPrintQueue := Result;
end;

end.

