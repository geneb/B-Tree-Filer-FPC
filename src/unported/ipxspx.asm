;*************************************************************
;*                    IPXSPX.ASM 5.41
;*       Low level IPX/SPX routines routines for the
;*                     NetWare unit.
;*        Copyright (c) TurboPower Software 1989.
;*                 All rights reserved.
;*************************************************************

; the data segment
DATA   SEGMENT WORD PUBLIC
       EXTRN   IPXLocation:DWORD       ; pointer set by IPXServicesAvail
       EXTRN   PascalESR:DWORD
DATA   ENDS

CODE   SEGMENT BYTE PUBLIC

       ASSUME  CS:CODE,DS:DATA

       ; public defs for Turbo Pascal

       ; IPX services
       PUBLIC  IPXOpenSocketPrim,IPXCloseSocketPrim,IPXAssignUniqueSocket
       PUBLIC  IPXSendPrim,IPXListenPrim
       PUBLIC  IPXCancelEventPrim,IPXRelinquish,IPXInternetAddress
       PUBLIC  IPXScheduleEvent,IPXScheduleSpecialEvent
       PUBLIC  IPXGetIntervalMarker,IPXGetLocalTarget
       PUBLIC  PoolESR
       ; SPX services
       PUBLIC  SPXServicesAvailPrim
       PUBLIC  SPXEstablishConnPrim,SPXListenForConnPrim
       PUBLIC  SPXTerminateConnPrim,SPXAbortConnPrim
       PUBLIC  SPXConnStatus,SPXSendPrim,SPXListenPrim
       ; Event Service Routine
       PUBLIC  PoolESR

; the following macro issues the IPX call, note that BP is not preserved
Do_IPX_Call      MACRO
       CALL      DWORD PTR IPXLocation
                 ENDM

Do_IPX_Call_BP   MACRO
       PUSH      BP
       CALL      DWORD PTR IPXLocation
       POP       BP
                 ENDM


;function IPXOpenSocket(RequestedSocket : Word; Forever : Boolean) : Word

Forever          EQU BYTE  PTR [BP+06h]          ; the longevity flag
Requested        EQU WORD  PTR [BP+08h]          ; the requested socket num
ECBPtr           EQU DWORD PTR [BP+06h]          ; the event control block

IPXOpenSocketPrim PROC FAR
       PUSH      BP
       MOV       BP,SP

       XOR       BX,BX                 ; BX = 0
       MOV       AL,Forever            ; Longevity Flag
       MOV       DX,Requested          ; Requested Socket number

       Do_IPX_Call

       POP       BP
       RET       04h
IPXOpenSocketPrim ENDP

;function IPXAssignUniqueSocket(var ReturnedSocket : Word;
;                               Forever : Boolean) : Word

AUForever        EQU BYTE  PTR [BP+06h]          ; the longevity flag
AUReturned       EQU DWORD PTR [BP+08h]          ; the returned socket num

IPXAssignUniqueSocket PROC FAR
       PUSH      BP
       MOV       BP,SP

       XOR       BX,BX                 ; BX = 0
       MOV       AL,Forever            ; Longevity Flag
       XOR       DX,DX                 ; Requested Socket number 0

       Do_IPX_Call_BP
       XCHG      DL,DH                 ; native to Intel word format !!.22
       LES       SI,AUReturned         ; point ES:SI to var ReturnedSocket
       MOV       ES:[SI],DX
       POP       BP
       RET       06h
IPXAssignUniqueSocket ENDP

CSRequested      EQU WORD  PTR [BP+06h]          ; the requested socket num

IPXCloseSocketPrim   PROC FAR
       PUSH      BP
       MOV       BP,SP

       MOV       BX,1                  ; BX = 1
       MOV       DX,CSRequested        ; Requested Socket number

       Do_IPX_Call

       POP       BP
       RET       02h
IPXCloseSocketPrim   ENDP

IPXSendPrim      PROC FAR
       PUSH      BP
       MOV       BP,SP

       MOV       BX,3                  ; BX = 3
       LES       SI,ECBPtr             ; point ES:SI to ECB

       Do_IPX_Call

       POP       BP
       RET       04h
IPXSendPrim      ENDP

IPXListenPrim    PROC FAR
       PUSH      BP
       MOV       BP,SP

       MOV       BX,4                  ; BX = 4
       LES       SI,ECBPtr             ; point ES:SI to ECB

       Do_IPX_Call

       POP       BP
       RET       04h
IPXListenPrim    ENDP

IPXCancelEventPrim PROC FAR
       PUSH      BP
       MOV       BP,SP

       MOV       BX,6                  ; BX = 6
       LES       SI,ECBPtr             ; point ES:SI to ECB

       Do_IPX_Call

       POP       BP
       RET       04h
IPXCancelEventPrim ENDP

IPXRelinquish    PROC FAR
       MOV       BX,0Ah                ; BX = 0Ah

       Do_IPX_Call_BP
       RET
IPXRelinquish    ENDP

IPXInternetAddress PROC FAR
       PUSH      BP
       MOV       BP,SP

       MOV       BX,09h                ; BX = 09h

       LES       SI,ECBPtr             ; point ES:SI to ECB

       Do_IPX_Call

       POP       BP
       RET       04h
IPXInternetAddress ENDP

;procedure IPXScheduleEvent(DelayTime : Word; var ECB : ECBIPX);

DelayTime        EQU WORD  PTR [BP+0Ah]

IPXScheduleEvent PROC FAR
       PUSH      BP
       MOV       BP,SP

       MOV       BX,05h                ; BX = 05h
       MOV       AX,DelayTime          ; ticks to wait
       LES       SI,ECBPtr             ; point ES:SI to ECB

       Do_IPX_Call

       POP       BP
       RET       06h
IPXScheduleEvent ENDP

;procedure IPXScheduleSpecialEvent(DelayTime : Word; var ECB : AESECB);

DelayTime        EQU WORD  PTR [BP+0Ah]

IPXScheduleSpecialEvent PROC FAR
       PUSH      BP
       MOV       BP,SP

       MOV       BX,07h                ; BX = 07h
       MOV       AX,DelayTime          ; ticks to wait
       LES       SI,ECBPtr             ; point ES:SI to ECB

       Do_IPX_Call

       POP       BP
       RET       06h
IPXScheduleSpecialEvent ENDP

;function IPXGetIntervalMarker : Word;
IPXGetIntervalMarker PROC FAR
       MOV       BX,08h

       Do_IPX_Call_BP

       RET
IPXGetIntervalMarker ENDP

; function IPXGetLocalTarget(var LocalTarget : TargetType;
;                            var TransportTime : Word) : Byte;

GLT_LocalTarget  EQU DWORD PTR [BP+0Ah]
GLT_TransTime    EQU DWORD PTR [BP+06h]

IPXGetLocalTarget proc far
       PUSH      BP
       MOV       BP,SP
       PUSH      DS
       MOV       BX,02h                ; BX = 02h
       LES       SI,GLT_LocalTarget
       ;MOV       CX,ES                ;!!.22
       ;MOV       DS,CX                ;!!.22
       MOV       DI,SI
       ADD       DI,12

       Do_IPX_Call_BP

       POP       DS
       LES       DI,GLT_TransTime
       MOV       WORD PTR ES:[DI],CX

       POP       BP
       RET       08h                   ;!!.22
IPXGetLocalTarget endp

spxVersion       EQU DWORD PTR [BP+0Eh]  ;!!.40
MaxSPXConn       EQU DWORD PTR [BP+0Ah]
AvailSPXConn     EQU DWORD PTR [BP+06h]


;function SPXServicesAvailPrim(var Version : Word;
;                              var MaxSPXConn,
;                              AvailSPXConn : Word) : Boolean;

SPXServicesAvailPrim PROC FAR
       PUSH      BP
       MOV       BP,SP

       MOV       BX,010h               ; BX = 10h
       XOR       AL,AL                 ; AL = 0

       Do_IPX_Call_BP                  ; we need BP preserved to access params

       CMP       AL,0FFh               ; is AL = FFh?
       JNE       No_SPX                ; no, so SPX not loaded

       LES       DI,spxVersion         ; yes, so return version info !!.40
       MOV       WORD PTR ES:[DI],BX

       LES       DI,MaxSPXConn
       MOV       WORD PTR ES:[DI],CX

       LES       DI,AvailSPXConn
       MOV       WORD PTR ES:[DI],DX

       MOV       AL,1
       JMP       SHORT SPXSerExit      ; return TRUE

No_SPX:
       XOR       AL,AL                 ; return FALSE

SPXSerExit:
       POP       BP
       RET       0Ch                   ;!!.41
SPXServicesAvailPrim ENDP

;function SPXEstablishPrim(RetryCount,WatchDog : Byte;
;                          var ECB : ECBIPX;
;                          var AssignedConn : Word) : Byte;

EAssignedConn     EQU DWORD PTR [BP+06h]
EECBPtr           EQU DWORD PTR [BP+0Ah]
EWatchDog         EQU BYTE  PTR [BP+0Eh]
ERetryCount       EQU BYTE  PTR [BP+10h]

SPXEstablishConnPrim PROC FAR
       PUSH      BP
       MOV       BP,SP

       MOV       BX,011h               ; BX = 11h
       MOV       AL,ERetryCount        ; the retry count
       MOV       AH,EWatchDog          ; watchdog flag
       LES       SI,EECBPtr            ; point ES:SI to ECB

       Do_IPX_Call_BP

       LES       SI,EAssignedConn
       MOV       WORD PTR ES:[SI],DX   ; return the assigned connection num

       POP       BP
       RET       0Ch

SPXEstablishConnPrim ENDP

;procedure SPXListenForConnPrim(Retry,WatchDog : Byte; var ECB : ECBIPX);

LWatchDog         EQU BYTE  PTR [BP+0Ah]
LRetryCount       EQU BYTE  PTR [BP+0Ch]

SPXListenForConnPrim PROC FAR
       PUSH      BP
       MOV       BP,SP

       MOV       BX,012h               ; BX = 12h
       MOV       AL,LRetryCount
       MOV       AH,LWatchDog
       LES       SI,ECBPtr             ; point ES:SI to ECB

       Do_IPX_Call

       POP       BP
       RET       08h

SPXListenForConnPrim ENDP

;procedure SPXTerminateConnPrim(ConnID : Word; var ECB : ECBIPX);

TConnID           EQU WORD  PTR [BP+0Ah]

SPXTerminateConnPrim PROC FAR
       PUSH      BP
       MOV       BP,SP

       MOV       BX,013h               ; BX = 13h
       MOV       DX,TConnID            ; conn ID to terminate
       LES       SI,ECBPtr             ; point ES:SI to ECB

       Do_IPX_Call

       POP       BP
       RET       06h

SPXTerminateConnPrim ENDP

AConn            EQU WORD  PTR [BP+06h]

;procedure SPXAbortConnPrim(ConnID : Word);

AConnID          EQU WORD  PTR [BP+06h]

SPXAbortConnPrim PROC FAR
       PUSH      BP
       MOV       BP,SP

       MOV       BX,014h               ; BX = 14h
       MOV       DX,AConnID            ; conn ID to abort

       Do_IPX_Call

       POP       BP
       RET       02h
SPXAbortConnPrim ENDP

SPXStatusBuf     EQU DWORD PTR [BP+06h]
CSConnID         EQU WORD  PTR [BP+0Ah]

;function SPXConnStatus(ConnID : Word; var SPXStatusBuf : SPXStatus) :
;Boolean

SPXConnStatus    PROC FAR
       PUSH      BP
       MOV       BP,SP

       MOV       BX,015h               ; BX = 15h
       MOV       DX,CSConnID           ; Conn ID to return status of
       LES       SI,SPXStatusBuf       ; point ES:SI to ECB

       Do_IPX_Call

       OR        AL,AL                 ; if AL zero, all is well
       JZ        Okay

       XOR       AL,AL                 ; return FALSE
       JMP       SHORT CSExit

Okay:  MOV       AL,1                  ; return TRUE

CSExit:
       POP       BP
       RET       06h
SPXConnStatus    ENDP

; procedure SPXSendPrim(ConnID : Word; var ECB : ECBIPX);

SPXSendPrim      PROC FAR
       PUSH      BP
       MOV       BP,SP

       MOV       BX,016h               ; BX = 16h
       MOV       DX,CSConnID           ; conn ID to send on
       LES       SI,ECBPtr             ; point ES:SI to ECB

       Do_IPX_Call

       POP       BP
       RET       06h
SPXSendPrim      ENDP

; procedure SPXListenPrim(var ECB : ECBIPX);

SPXListenPrim    PROC FAR
       PUSH      BP
       MOV       BP,SP

       MOV       BX,017h              ; BX = 17h
       LES       SI,ECBPtr            ; point ES:SI to ECB

       Do_IPX_Call

       POP       BP
       RET       04h
SPXListenPrim    ENDP

; This is a stub routine to allow a Turbo Pascal routine to be used as an ESR.
; The Pascal rouitine must be a far, non-nested procedure that takes a single
; var parameter of type IPXECB. The address of the Pascal ESR is assigned to
; the NetWare variable PascalESR. Here's the declaration of the standard
; pascal ESR used by the ECB Listen Pool facilities:
; {$F+}
; procedure PascalPoolESR(var ECB : IPXECB);
;

PoolESR          PROC FAR
       MOV       AX,DATA
       MOV       DS,AX

       MOV       AX,WORD PTR [PascalESR]
       OR        AX,WORD PTR [PascalESR+2]
       JZ        PoolESRExit

       PUSH      ES                             ;!!.23 moved
       PUSH      SI                             ;!!.23 moved
       CALL      DWORD PTR [PascalESR]

PoolESRExit:
       RET
PoolESR          ENDP

CODE    ENDS

        END

