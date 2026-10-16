(**************************************************************)
(*               B-Tree Isam Ver 5.41                         *)
(*   Copyright (C) 1986-1991 Dipl.Math. Ralf Nagel            *)
(*   Copyright (C) 1991-1993 ENZ EDV-Beratung GmbH            *)
(*                All rights reserved                         *)
(*   Modified and used under license by TurboPower Software   *)
(**************************************************************)

{--Conditional defines and compiler options}
  {$I btdefine.inc}
  {$F-,V-,B-,S-,I-,R-}
    {$Q-}


Unit Filer; {!!.TP}

InterFace

Uses
  BaseSupp;


{--Configuration constants}
  {$I filer.cfg}     {General user defined constants}                  {!!.TP}
  {-All previously here defined constants are now placed in Filer.Cfg} {!!.TP}

(***************************************************************************)
  {-Beyond this point there are no user changeable settings}

{--Interfaced constants}
Const
  VersionStr = '05.41';
    {-Current version}

  IsamFileNameLen = 255;
    {-Length of a single file name (64 under MS-DOS)}

  MinimizeUseOfNormalHeap = $40000000;
    {-This value added to Free for BTInitIsam causes the ring buffer to
      use a minimum of normal heap}

  MaxLockEntries = 4;
    {-Maximum number of entries for record locks per level. Multiple levels
      guaranty as much as the heap allows}

{--Interfaced types}
Type
  IsamOSHandle = BaseSupp.IsamOSHandle;
    {-Operating system file handle (a Word under MS-DOS)}

  IsamFileBlockName = String [255];
    {-Name of a fileblock (192 characters under MS-DOS)}

  IsamFileName = String [IsamFileNameLen];
    {-DOS name of a single file}

  IsamKeyStr = String [MaxKeyLen];
    {-A key string}

  IsamFileBlockPtr = ^IsamFileBlock;
    {-Pointer to a fileblock}

  IsamIndDescr = Array [1..MaxNrOfKeys] Of Record
    KeyL      : 1..MaxKeyLen;
    AllowDupK : Boolean;
  End;
    {-Descriptor of the index file}

  IsamFile = Record
    Handle : IsamOSHandle;
    Name   : Array [0..IsamFileNameLen] Of Char;
    Shared : Boolean;    {-Opened for shared (network) access}
  End;
    {-File definition}

  NetSupportType = ( NoNet, Novell, MsNet );
    {-Supported networks}

{--Privat types}
  IsamItem = Record
    DataRef,
    PageRef : LongInt;
    KeyStr  : IsamKeyStr;
  End;
  IsamPage = Record
    ItemsOnPage : Word;    {0..PageSize, but must occupy 2 Byte}
    BckwPageRef : LongInt;
    ItemArray   : Array [1..PageSize] Of IsamItem;
  End;
  IsamPagePtr = ^IsamPage;
  IsamSearchStep = Record
    PageRef    : LongInt;
    ItemArrInd : 0..PageSize;
  End;
  IsamPath = Array [1..MaxHeight] Of IsamSearchStep;
  IsamDatIndDescr = Record
    NumKeys,
    FirstFree,
    NumberFree,
    NumRec,
    LenRec,
    RootRef        : LongInt;
    AllowDupKeys,
    InfoRecChanged,
    IRChangedSaveN,
    FirstFreeChanged,
    SearchForSequentialEnabled,
    SequentialOK   : Boolean;
    KeyLen         : 1..MaxKeyLen;
    BlockOfs       : LongInt;
    Path           : IsamPath;
    PathInd        : 0..MaxHeight;
  End;
  IsamDatIndDescrPtr = ^IsamDatIndDescr;
  IsamDatIndDescrAr = Array [0..MaxNrOfKeys] Of IsamDatIndDescrPtr;
  IsamLockEntryRecPtr = ^IsamLockEntryRec;
  IsamLockEntryRec = Record
    EntryArr : Array [1..MaxLockEntries] Of LongInt;
    Count    : 0..MaxLockEntries;
    Next     : IsamLockEntryRecPtr;
  End;
  IsamNetSupport = Record
    Locked,
    ReadLocked,
    FlagSetReadLocked,
    AllStationsReadOnly,
    ReloadAll,
    SaveFileBlockRepaired : Boolean;
    DiaLenM3              : LongInt;
    SetLen                : Word;
    LocalWSNr             : Word;
    LockEntryRec          : IsamLockEntryRec;
  End;
  IsamNetSupportPtr = ^IsamNetSupport;
  IsamFileBlock = Record
    ValidSign    : LongInt;
    DatF         : IsamFile;
    IndF         : IsamFile;
    DiaF         : IsamFile;
    NrOfKeys     : 0..MaxNrOfKeys;
    BlockLen,
    MaxPages     : LongInt;
    DIDPtr       : ^IsamDatIndDescrAr;
    DataBuffered,
    ReadOnlyFB,
    SaveFB       : Boolean;
    NSP          : IsamNetSupportPtr;
  End;
  IsamOpenFileBlockListPtr = ^IsamOpenFileBlockList;
  IsamOpenFileBlockList = Record
    Next    : IsamOpenFileBlockListPtr;
    OIFBPtr : IsamFileBlockPtr;
  End;
  IsamSmallInfoRec = Record
    Gener : Array [1..5] Of LongInt;
    ADK   : Boolean;
  End;
  IsamInfoRec = Record
    InfoRec   : IsamSmallInfoRec;
    DummyFill : Char;
    KeysUsed  : LongInt;   {Must start on an even offset for C-compatibility}
  End;
  IsamSaveInfoRecBuffer = Record
    IST,
    IndNr : Word;
    BIR   : IsamInfoRec;
    SFF   : LongInt;
  End;
  IsamRingBufferRecPtr = ^IsamRingBufferRec;
  IsamPageEntryPtr = ^IsamPageEntry;
  IsamRingBufferRec = Record
    Prev,
    Next         : IsamRingBufferRecPtr;
    IFBlPtr      : IsamFileBlockPtr;
    PageRef      : LongInt;
    PageEntryPtr : IsamPageEntryPtr;
    KeyNr        : Word;
    UpDated,
    SaveBuffered : Boolean;
  End;
  IsamPageEntry = Record
    Page          : IsamPage;
    DummyDist1,
    DummyDist2    : LongInt;
    RingBufferPtr : IsamRingBufferRecPtr;
  End;
  ILI = Record
    Lo, Hi : Word;
  End;
  IsamFlagSet = Set Of Byte;


{--Interfaced variables}
Var
  IsamOK : Boolean;
    {-Contains status of last operation}

  IsamError : Integer;
    {-Contains error code of last operation}

  IsamDOSError : Word;
    {-Contains DOS error code of last operation in case IsamOK is False}

  IsamDOSFunc : Word;
    {-Contains DOS function code of last operation, zero if no DOS function
      was called by last operation}

  IsamReXUserProcPtr : Pointer;
    {-Pointer to a routine used while rebuilding and reorganizing}

  IsamCompiledNets : Set Of NetSupportType;
    {-Initialized of the unit initialization code;
      contains the definined network interfaces}


{--Interfaced routines}
  Function BTInitIsam ( ExpectedNet      : NetSupportType;
                        Free             : LongInt;
                        NrOfEMSTreePages : Word ) : LongInt;
    {-Initializes B-Tree Isam;
      high word of result: pages on EMS heap; low word: pages on normal heap.
      EMS is not available under Windows and Linux: NrOfEMSTreePages is
      ignored and the high word of the result is always zero}

  Procedure BTExitIsam;
    {-Exits use of B-Tree Isam}

  Function BTIsamErrorClass : Integer;
    {-Evaluates IsamError in error classes 0..4}

  Procedure BTReadLockFileBlock ( IFBPtr : IsamFileBlockPtr );
    {-Readlocks the fileblock IFBPtr^}

  Procedure BTLockFileBlock ( IFBPtr : IsamFileBlockPtr );
    {-Locks the fileblock IFBPtr^}

  Procedure BTUnLockFileBlock ( IFBPtr : IsamFileBlockPtr );
    {-Unlocks the fileblock IFBPtr^}

  Procedure BTReadLockAllOpenFileBlocks;
    {-Readlocks all open fileblocks}

  Procedure BTLockAllOpenFileBlocks;
    {-Locks all open fileblocks}

  Procedure BTUnLockAllOpenFileBlocks;
    {-Unlocks all open fileblocks}

  Procedure BTLockRec ( IFBPtr : IsamFileBlockPtr; Ref : LongInt );
    {-Locks record Ref}

  Procedure BTUnLockRec ( IFBPtr : IsamFileBlockPtr; Ref : LongInt );
    {-Unlocks record Ref}

  Procedure BTUnLockAllRecs ( IFBPtr : IsamFileBlockPtr );
    {-Unlocks all locked records of IFBPtr^}

  Function BTRecIsLocked ( IFBPtr : IsamFileBlockPtr; Ref : LongInt )
                                                                    : Boolean;
    {-Returns whether the record Ref is locked}

  Function BTPeekRecIsLocked ( IFBPtr : IsamFileBlockPtr; Ref : LongInt )
                                                                    : Boolean;
    {-Just like the routine without "Peek", but not destroying the previous
      error on success}

  Function BTaRecIsLocked ( IFBPtr : IsamFileBlockPtr ) : Boolean;
    {-Returns whether a record is locked}

  Function BTPeekaRecIsLocked ( IFBPtr : IsamFileBlockPtr ) : Boolean;
    {-Just like the routine without "Peek", but not destroying the previous
      error on success}

  Procedure BTInformTTSAbortSuccessful ( IFBPtr : IsamFileBlockPtr );
    {-Resets all internal data to nothing buffered and no lock at all}

  Procedure BTGetRecordInfo (     IFBPtr     : IsamFileBlockPtr;
                                  Ref        : LongInt;
                              Var Start, Len : LongInt;
                              Var Handle     : IsamOSHandle );
    {-Returns information about record Ref}

  Procedure BTPeekGetRecordInfo (     IFBPtr     : IsamFileBlockPtr;
                                      Ref        : LongInt;
                                  Var Start, Len : LongInt;
                                  Var Handle     : IsamOSHandle );
    {-Just like the routine without "Peek", but not destroying the previous
      error on success}

  Function BTFileBlockIsOpen ( IFBPtr : IsamFileBlockPtr ) : Boolean;
    {-Returns True, if the fileblock is curently open}

  Function BTPeekFileBlockIsOpen ( IFBPtr : IsamFileBlockPtr ) : Boolean;
    {-Just like the routine without "Peek", but not destroying the previous
      error on success}

  Function BTFileBlockIsLocked ( IFBPtr : IsamFileBlockPtr ) : Boolean;
    {-Returns True, if the fileblock is currently locked}

  Function BTPeekFileBlockIsLocked ( IFBPtr : IsamFileBlockPtr ) : Boolean;
    {-Just like the routine without "Peek", but not destroying the previous
      error on success}

  Function BTFileBlockIsReadLocked ( IFBPtr : IsamFileBlockPtr ) : Boolean;
    {-Returns True, if the fileblock is currently readlocked}

  Function BTPeekFileBlockIsReadLocked ( IFBPtr : IsamFileBlockPtr )
                                                                   : Boolean;
    {-Just like the routine without "Peek", but not destroying the previous
      error on success}

  Procedure BTForceWritingMark ( FFM : Boolean );
    {-Forces to write the "modify mark" to disk}

  Function BTSetDosRetry ( NrOfRetries, WaitTime : Integer ) : Boolean;
    {-Sets number of retries and delay time between on locks and accesses
      in a MicroSoft compatible network}

  Function BTNetSupported : NetSupportType;
    {-Returns the currently supported network}

  Function BTPeekNetSupported : NetSupportType;
    {-Just like the routine without "Peek", but not destroying the previous
      error on success}

  Function BTNoNetCompiled : Boolean;
    {-Returns True, if B-Tree Isam was compiled without network support}

  Function BTPeekNoNetCompiled : Boolean;
    {-Just like the routine without "Peek", but not destroying the previous
      error on success}

  Function BTIsNetFileBlock ( IFBPtr : IsamFileBlockPtr ) : Boolean;
    {-Returns True, if the fileblock is a net fileblock}

  Function BTPeekIsNetFileBlock ( IFBPtr : IsamFileBlockPtr ) : Boolean;
    {-Just like the routine without "Peek", but not destroying the previous
      error on success}

  Procedure BTForceNetBufferWriteThrough ( DoIt : Boolean );
    {-With DoIt = True the save mode tries to suppress all buffering in a
      network or multitasking environment}

  Procedure BTPutRec (     IFBPtr  : IsamFileBlockPtr;
                           RefNr   : LongInt;
                       Var Source;
                           ISOLock : Boolean );
    {-Puts the specified record at the given reference}

  Procedure BTGetRec (     IFBPtr  : IsamFileBlockPtr;
                           RefNr   : LongInt;
                       Var Dest;
                           ISOLock : Boolean );
    {-Gets the specified record from the given reference}

  Procedure BTGetRecReadOnly (     IFBPtr  : IsamFileBlockPtr;
                                   RefNr   : LongInt;
                               Var Dest              );
    {-Gets the specified record from the given reference even if it's locked}

  Procedure BTGetStartingLong (     IFBPtr  : IsamFileBlockPtr;
                                    RefNr   : LongInt;
                                Var Dest    : LongInt );
    {-Gets the first four bytes of the specified record with the given
      reference}

  Procedure BTAddRec (     IFBPtr : IsamFileBlockPtr;
                       Var RefNr  : LongInt;
                       Var Source                );
    {-Adds a record to the given fileblock and returns the reference}

  Procedure BTDeleteRec ( IFBPtr : IsamFileBlockPtr; RefNr : LongInt );
    {-Deletes the record with reference RefNr}

  Function BTUsedRecs ( IFBPtr : IsamFileBlockPtr ) : LongInt;
    {-Returns the number of currently used records}

  Function BTUsedKeys ( IFBPtr : IsamFileBlockPtr; Key : Word ) : LongInt;
    {-Returns the number of currently used keys of the specified number}

  Function BTFreeRecs ( IFBPtr : IsamFileBlockPtr ) : LongInt;
    {-Returns the number of currently not used records}

  Function BTFileLen ( IFBPtr : IsamFileBlockPtr ) : LongInt;
    {-Returns the number of currently occupied records by this fileblock}

  Function BTNrOfKeys ( IFBPtr : IsamFileBlockPtr ) : Word;
    {-Returns the number of defined keys}

  Function BTPeekNrOfKeys ( IFBPtr : IsamFileBlockPtr ) : Word;
    {-Just like the routine without "Peek", but not destroying the previous
      error on success}

  Function BTDatRecordSize ( IFBPtr : IsamFileBlockPtr ) : LongInt;
    {-Returns the lenght of a data record}

  Function BTPeekDatRecordSize ( IFBPtr : IsamFileBlockPtr ) : LongInt;
    {-Just like the routine without "Peek", but not destroying the previous
      error on success}

  Function BTKeyRecordSize ( IFBPtr : IsamFileBlockPtr ) : LongInt;
    {-Returns the maximum number of bytes used for a following key adding}

  Function BTPeekKeyRecordSize ( IFBPtr : IsamFileBlockPtr ) : LongInt;
    {-Just like the routine without "Peek", but not destroying the previous
      error on success}

  Function BTMinimumDatKeys ( IFBPtr : IsamFileBlockPtr; Space : LongInt )
                                                                  : LongInt;
    {-Returns the minimum number of data (including keys), that can be placed
      on a disk having Space bytes free space}

  Function BTPeekMinimumDatKeys ( IFBPtr : IsamFileBlockPtr;
                                  Space  : LongInt ) : LongInt;
    {-Just like the routine without "Peek", but not destroying the previous
      error on success}

  Procedure BTSetSearchForSequential ( IFBPtr : IsamFileBlockPtr;
                                       Key    : Word;
                                       On     : Boolean );
    {-Sets search mode in sequential key operations to On}

  Procedure BTGetSearchForSequential (     IFBPtr : IsamFileBlockPtr;
                                           Key    : Word;
                                       Var SFS    : Boolean );
    {-Gets search mode for sequential key operations in TSFS}

  Procedure BTClearKey ( IFBPtr : IsamFileBlockPtr; Key : Word );
    {-Places the internal sequential pointer to a null position}

  Procedure BTNextKey (     IFBPtr     : IsamFileBlockPtr;
                            Key        : Word;
                        Var UserDatRef : LongInt;
                        Var UserKey    : IsamKeyStr    );
    {-Returns in UserKey / UserDatRef the value and reference number of the
      next key}

  Procedure BTPrevKey (     IFBPtr     : IsamFileBlockPtr;
                            Key        : Word;
                        Var UserDatRef : LongInt;
                        Var UserKey    : IsamKeyStr       );
    {-Returns in UserKey / UserDatRef the value and reference number of the
      privious key}

  Procedure BTFindKey (     IFBPtr     : IsamFileBlockPtr;
                            Key        : Word;
                        Var UserDatRef : LongInt;
                            UserKey    : IsamKeyStr       );
    {-Returns in UserDatRef the reference number of the specified key}

  Procedure BTSearchKey (     IFBPtr     : IsamFileBlockPtr;
                              Key        : Word;
                          Var UserDatRef : LongInt;
                          Var UserKey    : IsamKeyStr    );
    {-Returns in UserKey / UserDatRef the value and reference number of the
      via UserKey specified or the following key}

  Procedure BTFindKeyAndRef (     IFBPtr                  : IsamFileBlockPtr;
                                  Key                     : Word;
                              Var UserDatRef              : LongInt;
                              Var UserKey                 : IsamKeyStr;
                                  NotFoundSearchDirection : Integer    );
    {-Returns in UserKey / UserDatRef the value and reference number of the
      via UserKey / UserDatRef specified combination.
      NotFoundSearchDirection determines whether and where to search for a
      result in case nothing was found}

  Procedure BTSearchKeyAndRef (     IFBPtr     : IsamFileBlockPtr;
                                    Key        : Word;
                                Var UserDatRef : LongInt;
                                Var UserKey    : IsamKeyStr );
    {-Returns in UserKey / UserDatRef the value and reference number of the
      via UserKey / UserDatRef specified combination.
      In case nothing was found a following result is searched. If this does
      not exist, a previous combination is searched}

  Function BTKeyExists ( IFBPtr     : IsamFileBlockPtr;
                         Key        : Word;
                         UserDatRef : LongInt;
                         UserKey    : IsamKeyStr    ) : Boolean;
    {-Returns True, if the combination UserKey / UserDatRef exists}

  Procedure BTNextDiffKey (     IFBPtr     : IsamFileBlockPtr;
                                Key        : Word;
                            Var UserDatRef : LongInt;
                            Var UserKey    : IsamKeyStr    );
    {-Returns in UserKey / UserDatRef the value and reference number of the
      next from UserKey different key}

  Procedure BTPrevDiffKey (     IFBPtr     : IsamFileBlockPtr;
                                Key        : Word;
                            Var UserDatRef : LongInt;
                            Var UserKey    : IsamKeyStr    );
    {-Returns in UserKey / UserDatRef the value and reference number of the
      previous from UserKey different key}

  Procedure BTAddKey ( IFBPtr     : IsamFileBlockPtr;
                       Key        : Word;
                       UserDatRef : LongInt;
                       UserKey    : IsamKeyStr    );
    {-Adds the combination UserKey / UserDatRef to the tree}

  Procedure BTDeleteKey ( IFBPtr     : IsamFileBlockPtr;
                          Key        : Word;
                          UserDatRef : LongInt;
                          UserKey    : IsamKeyStr    );
    {-Deletes the combination UserKey / UserDatRef in the tree}

  Procedure BTDeleteAllKeys ( IFBPtr : IsamFileBlockPtr; Key : Word );
    {-Deletes all keys with number Key}

  Function BTOtherWSChangedKey ( IFBPtr : IsamFileBlockPtr;
                                 Key    : Word ) : Boolean;
    {-Returns True, if it is definite, that a key of number Key was changed
      by another work station}

  Procedure BTGetApprRelPos (     IFBPtr     : IsamFileBlockPtr;
                                  Key        : Word;
                              Var RelPos     : Word;
                                  Scale      : Word;
                                  UserKey    : IsamKeyStr;
                                  UserDatRef : LongInt );
    {-Returns in RelPos the approximate relative position of the combination
      UserKey / UserDatRef in 0..Scale}

  Procedure BTGetApprKeyAndRef (     IFBPtr     : IsamFileBlockPtr;
                                     Key,
                                     RelPos     : Word;
                                     Scale      : Word;
                                 Var UserKey    : IsamKeyStr;
                                 Var UserDatRef : LongInt );
    {-Returns the combination UserKey / UserDatRef, that is approximately
      at the position RelPos in 0..Scale}

  Procedure BTFlushAllFileBlocks;
    {-Flushes all new data of all fileblocks to disk}

  Procedure BTFlushFileBlock ( IFBPtr : IsamFileBlockPtr );
    {-Flushes all new data of this fileblocks to disk}

  Procedure BTCreateFileBlock ( FName        : IsamFileBlockName;
                                DatSLen      : LongInt;
                                NumberOfKeys : Word;
                                IID          : IsamIndDescr );
    {-Creates a closed fileblock}

  Procedure BTOpenFileBlock ( Var IFBPtr      : IsamFileBlockPtr;
                                  FName       : IsamFileBlockName;
                                  ReadOnly,
                                  AllReadOnly,
                                  Save,
                                  Net         : Boolean );
    {-Opens a fileblock}

  Procedure BTCloseFileBlock ( Var IFBPtr : IsamFileBlockPtr );
    {-Closes a fileblock}

  Procedure BTCloseAllFileBlocks;
    {-Closes all open fileblocks}

  Procedure BTDeleteFileBlock ( FName  : IsamFileBlockName );
    {-Deletes a fileblock}

  Function BTDataFileName ( IFBPtr : IsamFileBlockPtr ) : IsamFileName;
    {-Returns the name of the data file including path and extension}

  Function BTPeekDataFileName ( IFBPtr : IsamFileBlockPtr ) : IsamFileName;
    {-Just like the routine without "Peek", but not destroying the previous
      error on success}

  Function BTIndexFileName ( IFBPtr : IsamFileBlockPtr ) : IsamFileName;
    {-Returns the name of the index file including path and extension}

  Function BTPeekIndexFileName ( IFBPtr : IsamFileBlockPtr ) : IsamFileName;
    {-Just like the routine without "Peek", but not destroying the previous
      error on success}

  Function BTGetNextUsedAddRecRef ( IFBPtr : IsamFileBlockPtr ) : LongInt;
    {-Returns the data reference, that is used for adding the next record;
      this function is of a more internal nature}

  Function BTGetAfterNextUsedAddRecRef ( IFBPtr : IsamFileBlockPtr ) : LongInt;
    {-Returns the data reference, that is used after adding the next record;
      this function is of a more internal nature}

  Function BTGetInternalDialogID ( IFBPtr : IsamFileBlockPtr ) : Word;
    {-Returns the internal ID used by network accesss to this fileblock}

 {--Interfaced only for compatibility reasons; not used outside except
    for network tests}
  Function BTIsamLockRecord ( Start,
                              Len       : LongInt;
                              Handle    : IsamOSHandle;
                              TimeOut,
                              DelayTime : Word ) : Boolean;
    {-Locks the bytes Start to Start+Len-1 of the file
      with handle Handle; TimeOut is the maximum wait time which may be
      separated in several retries with DelayTime milliseconds}

  Function BTIsamUnLockRecord ( Start,
                                Len    : LongInt;
                                Handle : IsamOSHandle ) : Boolean;
    {-Unlocks the bytes Start to Start+Len-1 of the file
      with handle Handle}

{--Routines of internal nature, but interfaced as well}
  Procedure IsamClearOK;
    {-Resets all status variables, even internal ones}

  Function IsamExists ( Name : IsamFileName ) : Boolean;
    {-Returns True, if the specified file exists}

  Procedure IsamAssign ( Var F : IsamFile; FName : IsamFileName );
    {-Assigns FName to the file F}

  Procedure IsamRewrite ( Var F : IsamFile );
    {-Creates the file F}

  Procedure IsamReset ( Var F : IsamFile; NetUsed, ReadOnly : Boolean );
    {-Opens the file F in the specified mode}

  Procedure IsamClose ( Var F : IsamFile );
    {-Closes the file F}

  Procedure IsamDelete ( Var F : IsamFile );
    {-Deletes the file F}

  Procedure IsamRename ( Var F : IsamFile; FName : IsamFileName );
    {-Renames the file F to FName}

  Procedure IsamLongSeek ( Var F : IsamFile; Ref : LongInt );
    {-Seeks the position Ref in the file F}

  Procedure IsamLongSeekEOF ( Var F : IsamFile; Var Len : LongInt );
    {-Seeks the end of file position in the file F and returns its length}

  Procedure IsamBlockRead ( Var F : IsamFile; Var Dest; Len  : Word );
    {-Reads a block of data with Len bytes out of the file F to Dest}

  Procedure IsamBlockReadRetLen ( Var F         : IsamFile;
                                  Var Dest;
                                      Len       : Word;
                                  Var BytesRead : Word );
    {-Reads a block of data with Len bytes out of the file F to Dest;
      returns the number of bytes read in BytesRead}

  Procedure IsamBlockWrite ( Var F : IsamFile; Var Source; Len : Word );
    {-Writes a block of data with Len bytes to the file F from Source}

  Procedure IsamGetBlock ( Var F : IsamFile; Ref, Len : LongInt; Var Dest );
    {-Reads a block of data with Len bytes starting at Ref out of the file
      F to Dest}

  Procedure IsamPutBlock ( Var F : IsamFile; Ref, Len : LongInt; Var Source );
    {-Writes a block of data with Len bytes to the file F starting at Ref
      from Source}

  Procedure IsamFlush ( Var F        : IsamFile;
                        Var WithDUP  : Boolean;
                            NetUsed  : Boolean );
    {-Flushes the buffers of F to disk, depending on the constant
      FlushDOS33 and the parameter NetUsed}

  Procedure IsamExtractFileNames (     FNameComp : IsamFileBlockName;
                                   Var FNameD,
                                       FNameI    : IsamFileBlockName );
    {-Seperates two file names seperated by ";"}

  Procedure IsamCopyFile ( Source,
                           Dest                  : IsamFileBlockName;
                           DeleteSourceAfterCopy : Boolean );

    {-Copies file Source to Dest}

  Function IsamForceExtension ( Name, Ext : IsamFileName ) : IsamFileName;
    {-Forces the extension Ext to the file name Name}

  Function RoundToGranul ( Value : Word ) : Word;
    {-Rounds Value up to the next multiple of 8}

  Procedure IsamDelay ( MilliSecs : LongInt );
    {-Delays for MilliSecs milliseconds using a DOS call, not the CRT unit}


Implementation

{--Privat constants}
Const
  OptCheckLock = $0100;
  OptReadPrefix = $0200;
  OptKeyRoutine = $0400;
  OptWriteRoutine = $0800;                                    {!!.41}
  NoOptions = 0;
  NotAFileBlockPtr = $FFFFFFFF;
  IsamFBValidSign = $11195851;

{--Privat types}
Type
  LongPtr = ^LongInt;

  ErrStatSaveRec = Record
    OK     : Boolean;
    Error  : Integer;
    DError,
    DFunc  : Word;
  End;

  IsamLockRecFunc = Function ( Start,
                               Len       : LongInt;
                               Handle    : IsamOSHandle;
                               TimeOut,
                               DelayTime : Word ) : Boolean;
  IsamUnLockRecFunc = Function ( Start,
                                 Len    : LongInt;
                                 Handle : IsamOSHandle ) : Boolean;
  IsamExitNetFunc = Function : Boolean;

{--Privat variables}
Var
  IsamRBR1Ptr            : IsamRingBufferRecPtr;
  IsamOFBLPtr            : IsamOpenFileBlockListPtr;
  IsamNrOfRingBufferRecs : Word;
  IsamDriveNotReadyError,
  IsamLockError,
  IsamNetEmu,
  IsamForceFlushOfMark,
  IsamIsCriticalActive,
  IsamIsInitialized      : Boolean;

  IsamNrOfWS             : Word;
  IsamInitializedNet     : NetSupportType;

  IsamLockRecord         : IsamLockRecFunc;
  IsamUnLockRecord       : IsamUnLockRecFunc;
  IsamExitNet            : IsamExitNetFunc;

  {$I isambase.inc}
  {$I isamwork.inc}
{$IFNDEF NoNet}
  {$I isnetsup.inc}
  {$I isamnwrk.inc}
{$ENDIF}
  {$I isamlow.inc}
  {$I filer.inc}  {!!.TP}

  Var
    SaveExitProc : Pointer;

  {$F+}
  Procedure IsamExitProc;

  Begin
    If IsamIsInitialized Then Begin
      IsamCloseAllFileBlocks;
      IsamClearOK;
    End;
    ExitProc := SaveExitProc;
  End;


Begin
  IsamDelay ( 0 );
    {-Initialization call with dummy parameter}
  IsamIsInitialized := False;
  IsamCompiledNets := []
{$IFDEF NoNet}
      + [NoNet]
{$ELSE}
  {$IFDEF MsNet}
      + [MsNet]
  {$ENDIF}
{$ENDIF}
  ;
  SaveExitProc := ExitProc;
  ExitProc := @IsamExitProc;
End.
