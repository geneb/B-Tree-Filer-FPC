(**************************************************************)
(*             B-Tree Isam Tools Ver 5.41                     *)
(*     Copyright (C) 1991-1993 ENZ EDV-Beratung GmbH          *)
(*                 All rights reserved                        *)
(*    Portions Copyright (C) TurboPower Software 1989-1993    *)
(*   Modified and used under license by TurboPower Software   *)
(**************************************************************)

{--Conditional defines and compiler options}
  {$I btdefine.inc}
  {$F-,V-,B-,S-,I-,R-}
    {$Q-}

{--Definition of possible languages for error messages of IsamErrormessage }
  (**************************************************************************)
  (*********************)  {.$DEFINE GermanMessage}   (***********************)
  (*********************)  {$DEFINE EnglishMessage}  (***********************)
  (**************************************************************************)
  {-Adding a space before the $ sign of the DEFINE deactivates the error
    messages of this language}


Unit IsamTool;


Interface

Uses
{$IFDEF UNIX}
  BaseUnix,
{$ENDIF}
  BaseSupp,
  Filer;   {!!.TP}

Type
  UsedErrorMessages = ( NoMsg, German, English );

Const
  UseErrorMessage : UsedErrorMessages =
  {$IFDEF EnglishMessage}
    English;
  {$ELSE}
    {$IFDEF GermanMessage}
      German;
    {$ELSE}
      NoMsg;
    {$ENDIF}
  {$ENDIF}

  Procedure ExtendHandles ( NumHandles : Word );
    {-Extends the number of file handles available to this application}

  Function IsamErrorMessage ( ErrorNr : Integer ) : String;
    {-Returns an error describing string}

{$IFDEF LengthByteKeys}
  Procedure InvertString ( Var Dest   : String;
                               Source : String;
                               MaxLen : Byte );
    {-Inverts the string Source under a maximum length of MaxLen returning
      the result in Dest}
{$ENDIF}
{$IFDEF ASCIIZeroKeys}
  Procedure InvertString ( Var Dest;
                           Var Source;
                               MaxLen : Byte );
    {-Inverts the null terminated array of character Source under a
      maximum length of MaxLen returning the result in Dest}
{$ENDIF}


Implementation

  Procedure ExtendHandles ( NumHandles : Word );
    {-Extends the number of file handles available to this application.
      Under MS-DOS this used function $67. Windows has no fixed limit for
      file handles, so nothing needs to be done; under Linux the soft limit
      of open files (RLIMIT_NOFILE) is raised if it is lower than
      NumHandles}
{$IFDEF UNIX}
  Var
    RL : TRLimit;
{$ENDIF}

  Begin
    IsamClearOK;
  {$IFDEF UNIX}
    If IsamDOSError = 0 Then IsamDOSFunc := $6700;
    If fpGetRLimit ( RLIMIT_NOFILE, @RL ) <> 0 Then Begin
      IsamOK := False;
      IsamError := 10192;
      Exit;
    End;
    If RL.rlim_cur < NumHandles Then Begin
      If RL.rlim_max < NumHandles Then Begin
        IsamOK := False;
        IsamError := 10192;
        Exit;
      End;
      RL.rlim_cur := NumHandles;
      If fpSetRLimit ( RLIMIT_NOFILE, @RL ) <> 0 Then Begin
        IsamOK := False;
        IsamError := 10192;
      End;
    End;
  {$ENDIF}
  End;

  Function IsamErrorMessage ( ErrorNr : Integer ) : String;
    {-Returns an error describing string}

  Var
    S : String [10];

  Begin
    Case UseErrorMessage Of
      NoMsg : Begin
        IsamErrorMessage := '';
      End;
    {$IFDEF GermanMessage}
      German : Begin
        Case ErrorNr Of
           9500..9899 : Begin
             Str ( ErrorNr - 9500 : 0, S );
             IsamErrorMessage := 'DOS Fehlercode <' + S + '>';
           End;
           9900 : IsamErrorMessage := 'Falscher Pfadname';
           9901 : IsamErrorMessage := 'Zu viele offene Dateien';
           9902 : IsamErrorMessage := 'Momentanes Directory ist voll';
           9903 : IsamErrorMessage := 'Datei nicht gefunden';
           9904 : IsamErrorMessage := 'Falsche Dateikennzeichnung (Handle)';
           9908 : IsamErrorMessage := 'Falscher Zugriffscode (open handle)';
          10000 : IsamErrorMessage :=
              'Seitenpuffer ist kleiner als MaxHeight';
          10001..
          10009 : IsamErrorMessage := 'Schwerer IO-Fehler im Save-Modus';
          10010 : IsamErrorMessage :=
              'Dateidefekt, der durch Rebuild zu beheben ist';
          10020 : IsamErrorMessage :=
              'Datensatz kleiner als 22 Bytes oder mehr als 2147483647 Bytes';
          10030 : IsamErrorMessage :=
              'Zu wenig Speicherplatz (Fileblock-Beschreiber)';
          10040 : IsamErrorMessage := 'Nicht genug Speicher vorhanden';
          10050 : IsamErrorMessage := 'Falsche Anzahl Keys';
          10055,
          10125 : IsamErrorMessage := 'Key zu lang';
          10060 : IsamErrorMessage :=
              'Zu viele Keys oder Datei-Lesefehler';
          10065 : IsamErrorMessage :=                           {!!.41}
              'Schreibversuch in Nur-Lese-Fileblock';
          10070 : IsamErrorMessage := 'Datei-Lesefehler';
          10075 : IsamErrorMessage := 'Datei-Schreibfehler';
          10080 : IsamErrorMessage := 'Fileblock nicht offen';
          10090,
          10100,
          10356 : IsamErrorMessage :=
              'Zu wenig Speicherplatz (Fileblock)';
          10110 : IsamErrorMessage := 'Laufwerk nicht bereit';
          10120 : IsamErrorMessage :=
              'PageSize nicht zutreffend';
          10121 : IsamErrorMessage := 'MaxKeyLen zu klein';
          10130,
          10135 : IsamErrorMessage := 'Record 0 darf nicht benutzt werden';
          10140 : IsamErrorMessage :=
              'Zugriff verweigert, undefinierter Fehler';
          10150 : IsamErrorMessage :=
              'Zu wenig Handles (Flush im Netz)';
          10160 : IsamErrorMessage := 'Fileblock nicht korrekt geschlossen';
          10164 : IsamErrorMessage := 'Falsche Key-Nummer';
          10170 : IsamErrorMessage := 'Konsistenz des Fileblocks in Gefahr';
          10180 : IsamErrorMessage :=
              'Reparatur-Versuch des Fileblocks gescheitert';
          10190 : IsamErrorMessage := 'DOS-Version 3.3 notwendig';
          10191 : IsamErrorMessage :=
              'Zu wenig Speicher, um neue Dateitabelle anzulegen';
          10192 : IsamErrorMessage :=
              'Initialisierung der neuen Dateitabelle gescheitert';
          10200 : IsamErrorMessage := 'Kein passender Key gefunden';
          10205 : IsamErrorMessage := 'Datensatz momentan gesperrt';
          10210 : IsamErrorMessage :=
              'Dieser und kein nachfolgender Key vorhanden';
          10220 : IsamErrorMessage := 'Zu entfernender Key nicht gefunden';
          10230 : IsamErrorMessage :=
              'Doppelter Key kann nicht eingetragen werden';
          10240,
          10250 : IsamErrorMessage := 'Kein nachfolgender Key gefunden';
          10245,
          10260 : IsamErrorMessage := 'Kein kleinerer Key gefunden';
          10255,
          10265 : IsamErrorMessage := 'Sequentieller Zugriff nicht erlaubt';
          10270 : IsamErrorMessage := 'Keinen passenden '
              + 'Key mit dieser Datensatzreferenz gefunden';
          10280,
          10285 : IsamErrorMessage := 'Index leer';
          10306 : IsamErrorMessage := 'Zu viele Fileblock-Zugriffe';
          10310 : IsamErrorMessage := 'Netz-Initialisierungs-Fehler';
          10315 : IsamErrorMessage := 'Netz-Deinitialisierungs-Fehler';
          10322,
          10323 : IsamErrorMessage := 'Close des Fileblocks wegen nicht '
              + 'entfernbarem Lock fehlgeschlagen';
          10330 : IsamErrorMessage := 'Fileblock Lock-Versuch gescheitert';
          10332 : IsamErrorMessage := 'Fileblock Readlock-Versuch gescheitert';
          10335 : IsamErrorMessage := 'Datensatz Lock-Versuch gescheitert';
          10337 : IsamErrorMessage := 'Datensatz Lock-Versuch aus '
              + 'Speicherplatzmangel gescheitert';
          10340..
          10342 : IsamErrorMessage := 'Fileblock Unlock-Versuch gescheitert';
          10345 : IsamErrorMessage := 'Datensatz Unlock-Versuch gescheitert';
          10355,
          10397,
          10399 : IsamErrorMessage := 'Ein Lock verhindert die Operation';
          10398 : IsamErrorMessage := 'Operation erfordert einen Fileblock '
              + 'im Lock-Zustand';
          10410 : IsamErrorMessage := 'Daten-Datei nicht gefunden';
          10411 : IsamErrorMessage := 'Puffer wegen zu wenig Heap nicht '
              + 'erstellt';
          10412 : IsamErrorMessage := 'Datensatz mehr als 64K Bytes';
          10415 : IsamErrorMessage := 'Datensatz-Anzahl zu hoch';
          10420,
          10425 : IsamErrorMessage :=
              'Relative Position oder Scalierung falsch';
          10430 : IsamErrorMessage :=
              'Reparatur wegen "read only" gescheitert';
          10435 : IsamErrorMessage := 'Baumseite mehr als 16K';
          10440 : IsamErrorMessage :=
              'Dialogdatei anlegen wegen "read only" gescheitert';
          10445 : IsamErrorMessage := 'Kein Fileblock vorhanden';
          10446 : IsamErrorMessage := 'Rekursiver Aufruf der B-Tree Isam';
          10450 : IsamErrorMessage := 'Initialisierung bereits geschehen';
          10455 : IsamErrorMessage :=
              'Initialisierung noch nicht geschehen';
          10460 : IsamErrorMessage := 'Reorganisation abgebrochen';
          10465 : IsamErrorMessage :=                           {!!.41}
              'Daten- und Sicherungsdatei gleichzeitig vorhanden';
        Else
          IsamErrorMessage := '';
        End;
      End;
    {$ENDIF}
    {$IFDEF EnglishMessage}
      English : Begin
        Case ErrorNr Of
           9500..9899 : Begin
             Str ( ErrorNr - 9500 : 0, S );
             IsamErrorMessage := 'DOS error code <' + S + '>';
           End;
           9900 : IsamErrorMessage := 'Invalid path name';
           9901 : IsamErrorMessage := 'Too many open files';
           9902 : IsamErrorMessage := 'Current directory is full';
           9903 : IsamErrorMessage := 'File not found';
           9904 : IsamErrorMessage := 'Invalid handle';
           9908 : IsamErrorMessage := 'Invalid access code';
          10000 : IsamErrorMessage :=
              'Page buffer is smaller than MaxHeight';
          10001..
          10009 : IsamErrorMessage :=
              'Serious I/O error occurred while in save mode';
          10010 : IsamErrorMessage :=
              'File defect, that can be corrected by rebuild';
          10020 : IsamErrorMessage :=
              'Record length less than 22 or more than 2147483647 bytes';
          10030,
          10040 : IsamErrorMessage := 'Insufficient memory';
          10050 : IsamErrorMessage := 'Invalid number of keys specified';
          10055,
          10125 : IsamErrorMessage := 'Key too long';
          10060 : IsamErrorMessage := 'Too many keys, or file read error';
          10065 : IsamErrorMessage :=                           {!!.41}
              'Attempt to write to read only Fileblock';
          10070 : IsamErrorMessage := 'File read error';
          10075 : IsamErrorMessage := 'File write error';
          10080 : IsamErrorMessage := 'Fileblock not open';
          10090,
          10100,
          10356 : IsamErrorMessage :=
              'Insufficient memory to allocate Fileblock';
          10110 : IsamErrorMessage := 'Drive not ready';
          10120 : IsamErrorMessage := 'PageSize incompatible with Fileblock';
          10121 : IsamErrorMessage := 'MaxKeyLen too small';
          10130,
          10135 : IsamErrorMessage := 'Record 0 must not be accessed';
          10140 : IsamErrorMessage := 'Access not possible, undefined error';
          10150 : IsamErrorMessage :=
              'Insufficient handles for flush of network Fileblock';
          10160 : IsamErrorMessage := 'Fileblock not correctly closed';
          10164 : IsamErrorMessage := 'Invalid key number';
          10170 : IsamErrorMessage := 'Consistency of Fileblock endangered';
          10180 : IsamErrorMessage := 'Attempt to repair Fileblock failed';
          10190 : IsamErrorMessage :=
              'Extend handle function requires DOS 3.3 or later';
          10191 : IsamErrorMessage :=
              'Insufficient memory for new file handle table';
          10192 : IsamErrorMessage :=
              'Unable to initialize new file handle table';
          10200 : IsamErrorMessage := 'No matching key found';
          10205 : IsamErrorMessage := 'Data record is currently locked';
          10210 : IsamErrorMessage :=
              'No key found and no larger keys available';
          10220 : IsamErrorMessage := 'Key to delete was not found';
          10230 : IsamErrorMessage := 'Cannot add duplicate key';
          10240,
          10250 : IsamErrorMessage := 'No larger key found';
          10245,
          10260 : IsamErrorMessage := 'No smaller key found';
          10255,
          10265 : IsamErrorMessage := 'Sequential access not allowed';
          10270 : IsamErrorMessage :=
              'No matching key and record number found';
          10280,
          10285 : IsamErrorMessage := 'Index empty';
          10306 : IsamErrorMessage := 'Too many Fileblock accesses';
          10310 : IsamErrorMessage := 'Network initialization error';
          10315 : IsamErrorMessage := 'Network exit error';
          10322,
          10323 : IsamErrorMessage := 'Close of Fileblock not possible because'
              + ' of a non-removeable lock';
          10330 : IsamErrorMessage := 'Fileblock lock attempt failed';
          10332 : IsamErrorMessage := 'Fileblock readlock attempt failed';
          10335 : IsamErrorMessage := 'Record lock attempt failed';
          10337 : IsamErrorMessage := 'Record lock attempt failed '
              + 'because of insufficient memory';
          10340..
          10342 : IsamErrorMessage := 'Fileblock unlock attempt failed';
          10345 : IsamErrorMessage := 'Record unlock attempt failed';
          10355,
          10397,
          10399 : IsamErrorMessage := 'A lock prevents the operation';
          10398 : IsamErrorMessage := 'Fileblock must be locked';
          10410 : IsamErrorMessage := 'Data file not found';
          10411 : IsamErrorMessage :=
              'Insufficient heap space for work buffers';
          10412 : IsamErrorMessage := 'Record section length exceeds 64K';
          10415 : IsamErrorMessage := 'Too much records';
          10420,
          10425 : IsamErrorMessage := 'Relative position or scale invalid';
          10430 : IsamErrorMessage := 'No repair in read only mode';
          10435 : IsamErrorMessage := 'Tree page greater than 16k';
          10440 : IsamErrorMessage :=
              'No creating of dialog file in read only mode';
          10445 : IsamErrorMessage := 'Invalid Fileblock';
          10446 : IsamErrorMessage := 'Recursive call of B-Tree Isam';
          10450 : IsamErrorMessage := 'Initialization already done';
          10455 : IsamErrorMessage := 'Initialization not yet done';
          10460 : IsamErrorMessage := 'Reorganization aborted';
          10465 : IsamErrorMessage :=                           {!!.41}
              'Data and save file exist simultaneously';
        Else
          IsamErrorMessage := '';
        End;
      End;
  {$ENDIF}
    Else
      IsamErrorMessage := '';
    End;
  End;


{$IFDEF LengthByteKeys}
  Procedure InvertString ( Var Dest   : String;
                               Source : String;
                               MaxLen : Byte );
    {-Inverts the string Source under a maximum length of MaxLen returning
      the result in Dest}

  Var
    ToSubLen,
    EatCount,
    ResLen,
    ActInd   : Byte;
    Cont     : Boolean;
    I        : Word;

  Begin
    ToSubLen := Length (Source);
    If MaxLen < ToSubLen Then Begin
      Dest := '';
      Exit;
    End;
    FillChar ( Source [Succ (ToSubLen)], MaxLen - ToSubLen, $FF );
    If ToSubLen = 0 Then Begin
      Source [0] := Chr (MaxLen);
      Dest := Source;
      Exit;
    End;
    For I := 1 To ToSubLen Do Begin
      Source [I] := Char (Not Byte (Source [I]));
    End;
      {-Invert string entries up to ToSubLen}
    ResLen := MaxLen;
    If Ord (Source [MaxLen]) >= ToSubLen Then Begin
      Dec (Source [MaxLen], ToSubLen);
    End Else Begin
      If Ord (Succ (Source [MaxLen])) = ToSubLen Then Begin
        ResLen := Pred (MaxLen);
      End Else Begin
        Inc (Source [MaxLen], 257 - ToSubLen);
        EatCount := Ord (Source [MaxLen]);
        ActInd := Pred (MaxLen);
        Cont := True;
        While Cont And (ActInd > 0) Do Begin
          If Source [ActInd] > #0 Then Begin
            Dec (Source [ActInd]);
            Cont := False;
          End Else Begin
            If EatCount < 255 Then Begin
              Source [ActInd] := #255;
              Dec (ActInd);
              Inc (EatCount);
            End Else Begin
              ResLen := Pred (ActInd);
              Cont := False;
            End;
          End;
        End;
        If ActInd = 0 Then ResLen := 0;
      End;
    End;
    Source [0] := Chr (ResLen);
    Dest := Source;
  End;
{$ENDIF}


{$IFDEF ASCIIZeroKeys}
  Procedure InvertString ( Var Dest;
                           Var Source;
                               MaxLen : Byte );
    {-Inverts the null terminated array of character Source under a
      maximum length of MaxLen returning the result in Dest}
  Var
    DestStr   : Array [Byte] Of Byte Absolute Dest;
    SourceStr : Array [Byte] Of Byte Absolute Source;
    ToSubLen,
    EatCount,
    ResLen    : Byte;
    ActInd    : Integer;
    Cont      : Boolean;


    Function AZStrLen ( StrPtr : Pointer ) : Word;
      {-Returns the length of the ASCII zero string;
        formerly inline machine code}
    Var
      P : ^Byte;
      L : Word;

    Begin
      P := StrPtr;
      L := 0;
      While P^ <> 0 Do Begin
        Inc (P);
        Inc (L);
      End;
      AZStrLen := L;
    End;


    Procedure SubFrom256 ( StrPtr : Pointer; Len : Byte );
      {-Subtracts Len Bytes at StrPtr from 256 and stores the result there;
        formerly inline machine code}
    Var
      P : ^Byte;
      I : Word;

    Begin
      P := StrPtr;
      For I := 1 To Len Do Begin
        P^ := Byte (256 - P^);
        Inc (P);
      End;
    End;


  Begin
    ToSubLen := AZStrLen ( @SourceStr );
    If MaxLen < ToSubLen Then Begin
      DestStr [0] := 0;
      Exit;
    End;
    Move ( SourceStr, DestStr, ToSubLen );
    FillChar ( DestStr [ToSubLen], MaxLen - ToSubLen, $FF );
    DestStr [MaxLen] := 0;

    If ToSubLen = 0 Then Exit;
    SubFrom256 ( @DestStr, ToSubLen );

    ResLen := MaxLen;
    If DestStr [Pred (MaxLen)] > ToSubLen Then Begin
      Dec (DestStr [Pred (MaxLen)], ToSubLen);
    End Else Begin
      If DestStr [Pred (MaxLen)] = ToSubLen Then Begin
        ResLen := Pred (MaxLen);
      End Else Begin
        Inc (DestStr [Pred (MaxLen)], 256 - ToSubLen);
        EatCount := DestStr [Pred (MaxLen)];
        ActInd := MaxLen - 2;
        Cont := True;
        While Cont And (ActInd >= 0) Do Begin
          If DestStr [ActInd] > 1 Then Begin
            Dec (DestStr [ActInd]);
            Cont := False;
          End Else Begin
            If EatCount < 255 Then Begin
              DestStr [ActInd] := 255;
              Dec (ActInd);
              Inc (EatCount);
            End Else Begin
              ResLen := ActInd;
              Cont := False;
            End;
          End;
        End;
        If ActInd = -1 Then ResLen := 0;
      End;
    End;
    DestStr [ResLen] := 0;
  End;
{$ENDIF}

{$IFDEF InitAllUnits}
Begin
{$ENDIF}
End.
