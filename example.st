PROGRAM PLC_PRG_M258_ST
VAR CONSTANT

    (* IP address of the ATV-IMC controller *)
    c_sAddressAtvImc                : STRING := '192.168.1.222'; 

END_VAR
VAR

    (* For initializations only: TRUE during first cycle only *)
    (* NOTE: Used so that the Function Blocks first see their "Execute" input *)
    (*       as FALSE in order to detect a subsequent rising edge.            *)
    v_xIsFirstCycle                 : BOOL   := TRUE;

    (**********************)
    (*** ADDM Variables ***)
    (**********************)

    (* Complete Modbus TCP address of the ATV-IMC (ATV-IMC card) *)
    v_sAddressAtvImc_Card           : STRING := '';

    (* ADDM Function Block for formatting the Modbus TCP address of the ATV-IMC *)
    ADDM_ModbusTCP_ATVIMC           : ADDM;

    (* ADDRESS structure for the Modbus TCP address of the ATV-IMC *)
    v_addressModbusTcpAtvImc        : ADDRESS;

    (* Result of the conversion of the Modbus TCP address of the ATV-IMC: OK if "Done" without any "Error" *)
    v_xAddressIsOK_ModbusTcpAtvImc  : BOOL   := FALSE;


    (*************************************************************)
    (*** Variables for Reading the ATV-IMC applicative counter ***)
    (*************************************************************)

    (* Command to read the counter of the ATV-IMC: IF Address is OK AND Previous read is finished *)
    v_xReadCounter_ATV              : BOOL   := FALSE;

    (* READ_VAR Function Block for reading the counter produced by the ATV-IMC controller *)
    READ_VAR_Counter_ATV            : READ_VAR;

    (* Buffer for the value of the counter produced by the ATV-IMC controller: Remote value of the Source *)
    v_wCounter_ATV_Srce_Remote      : WORD   := 0;

    (* Presence (TRUE) or absence (FALSE) of the ATV12 controller *)
    v_xPresenceAtvImc               : BOOL   := FALSE;

    (* Communication error with the ATV-IMC controller (Timeout excluded) *)
    v_xCommErrorAtvImc              : BOOL   := FALSE;


    (******************************************************************)
    (*** Variables for Writing back the ATV-IMC applicative counter ***)
    (******************************************************************)

    (* F_TRIG Function Block for detecting the end of the ATV counter read operation and trigerring the write operation *)
    F_TRIG_ReadAtvCounter_End       : F_TRIG;

    (* Memorization of the end of the ATV counter read operation *)
    v_xMemReadAtvCounter_End        : BOOL   := FALSE;

    (* Command to write back the counter of the ATV-IMC: IF Address is OK AND at the (memorized) end of each read operation *)
    v_xWriteCounter_ATV             : BOOL   := FALSE;

    (* Buffer for the value of the copy of the counter produced by the ATV-IMC controller: Local value of the Copy *)
    v_wCounter_ATV_Copy_Local       : WORD   := 0;

    (* SINGLE_WRITE Function Block for writing back the counter to the ATV-IMC controller *)
    SINGLE_WRITE_Counter_ATV        : SINGLE_WRITE;


    (****************************************************************************)
    (*** Variables for Writing the M258 status and Reading the ATV-IMC status ***)
    (****************************************************************************)

    (* BLINK Function Block for periodic write and read of the M258 and ATV-IMC statuses *)
    BLINK_RW_Statuses               : BLINK;

    (* "OUT" output of the BLINK Function Block: Clock for writing and reading the M258 and ATV-IMC statuses *)
    v_xClockReadWriteStatuses       : BOOL   := FALSE;

    (* Command to write and read the M258 and ATV-IMC statuses: IF Address is OK AND Once per second (duration = 900 ms) *)
    v_xReadWriteStatuses            : BOOL   := FALSE;

    (* NOTE: The "Read/write multiple registers (%MW)" Modbus function (function #23 (17 hex)) is not supported by the ATV-IMC; *)
    (*       because of this, the standard "Read Holding Registers" and "Write Multiple Registers" Modbus functions (functions #03 and #16) are used. *)
    (* WRITE_VAR Function Block for writing the M258 status *)
    WRITE_VAR_Status                : WRITE_VAR;
    (* READ_VAR  Function Block for reading the ATV-IMC status *)
    READ_VAR_Status                 : READ_VAR;

    (* Registers read on the ATV-IMC by the M258 controller *)
    v_wAtvImc_ReadRegisters         : ARRAY [1..5] OF WORD := [5(0)];

    (* F_TRIG Function Block for detecting the end of the ATV-IMC status read operation *)
    F_TRIG_ReadStatus_End           : F_TRIG;

    (* Controller Hardware Version of the ATV-IMC controller (copy of the DWORD at %MW60008), read by the M258 controller *)
    v_dwAtvImc_CtrlHWVersion        : DWORD := 0;

    (* Controller Coprocessor Version of the ATV-IMC controller (copy of the DWORD at %MW60010), read by the M258 controller *)
    v_dwAtvImc_CtrlCoProcVersion    : DWORD := 0;

    (* State of the ATV-IMC controller (copy of the WORD at %MW60012), read by the M258 controller *)
    v_wAtvImc_State                 : WORD  := 0;

END_VAR



(********************************************************)
(*** Formatting the Modbus TCP Address of the ATV-IMC ***)
(*** Function Block(s): ADDM                          ***)
(********************************************************)

IF v_xIsFirstCycle THEN
    (* Complete Modbus TCP address of the ATV-IMC (ATV-IMC card) *)
    (*  - <communication port number> = 3 for the Ethernet port of the local M258 controller *)
    (*  - <IP address A.B.C.D> = IP address of the remote ATV-IMC controller *)
    (*  - No <port> : The default TCP port is used (502) *)
    (*  - <slave address> = 252 = "UnitId" of the ATV-IMC card *)
    v_sAddressAtvImc_Card := CONCAT( '3{' , c_sAddressAtvImc );
    v_sAddressAtvImc_Card := CONCAT( v_sAddressAtvImc_Card , '}252' );
END_IF

(* ADDM Function Block for formatting the Modbus TCP address of the ATV-IMC controller *)
(* NOTE: In ST language, this call syntax is required for Function Blocks that include *)
(*       at least one "VAR_IN_OUT" variable ("AddrTable" in the case of ADDM)          *)
ADDM_ModbusTCP_ATVIMC(
    (* IN/OUT - Resulting ADDRESS structure *)
    AddrTable := v_addressModbusTcpAtvImc,
    (* IN     - Rising Edge signal that triggers this Function Block *)
    Execute   := NOT v_xIsFirstCycle,
    (* IN     - Modbus TCP Address of the ATV-IMC controller's card *)
    (*          Format = "<communication port number>{<IP address A.B.C.D>:<port>}<slave address>" *)
    Addr      := v_sAddressAtvImc_Card,
    (* OUT    - Resulting address is OK (this output will directly be used in the program) *)
    Done      => ,
    (* OUT    - Resulting address is not OK (this output will directly be used in the program) *)
    Error     => ,
    (* OUT    - This error code is not used in this program *)
    CommError => );

(* Result of the conversion of the Modbus/TCP address of the ATV-IMC: OK if "Done" without any "Error" *)
v_xAddressIsOK_ModbusTcpAtvImc := ADDM_ModbusTCP_ATVIMC.Done AND NOT ADDM_ModbusTCP_ATVIMC.Error;


(*****************************************************************)
(*** Modbus TCP Communications: ATV counter read in permanence ***)
(*** Function Block(s): READ_VAR                               ***)
(*****************************************************************)

(* Command to read the counter of the ATV-IMC: IF Address is OK AND Previous read is finished *)
v_xReadCounter_ATV := v_xAddressIsOK_ModbusTcpAtvImc AND NOT READ_VAR_Counter_ATV.Busy;

(* READ_VAR Function Block for reading the counter produced by the ATV-IMC controller *)
(* NOTE: In ST language, this call syntax is required for Function Blocks of the            *)
(*       "PLCCommunication" library that use an "Addr" INPUT variable (data type = ADDRESS) *)
READ_VAR_Counter_ATV(
    (* IN  - Rising Edge signal that triggers this Function Block *)
    Execute    := v_xReadCounter_ATV,
    (* IN  - Function Block not aborted (FALSE) *)
    Abort      := FALSE,
    (* IN  - Formatted Modbus TCP address of the ATV-IMC controller *)
    Addr       := v_addressModbusTcpAtvImc,
    (* IN  - Timeout of 500 ms *)
    Timeout    := 5,
    (* IN  - Type of object to be read: MW --> The Modbus function #3 (read holding registers) is used *)
    ObjType    := ObjectType.MW,
    (* IN  - First object to be read: The applicative counter of the ATV-IMC (address = %MW100) *)
    FirstObj   := 100,
    (* IN  - Number of objects to read: 1 register *)
    Quantity   := 1,
    (* IN  - Address of the variable for RECEIVING the value of the applicative counter of the ATV-IMC *)
    Buffer     := ADR(v_wCounter_ATV_Srce_Remote),
    (* OUT - "Done" result of the ATV counter read operation (this output will directly be used in the program) *)
    Done       => ,
    (* OUT - "Busy" output of the ATV counter read operation (this output will directly be used in the program) *)
    Busy       => ,
    (* OUT - This output is not used in this program *)
    Aborted    =>,
    (* OUT - "Error" result of the ATV counter read operation (this output will directly be used in the program) *)
    Error      => ,
    (* OUT - "CommError" result of the ATV counter read operation (this output will directly be used in the program) *)
    CommError  => ,
    (* OUT - This error code is not used in this program (this output will directly be used in the program) *)
    OperError  => );

(* At the end of the current Modbus TCP read operation for the applicative counter of the ATV-IMC controller *)
IF NOT READ_VAR_Counter_ATV.Busy THEN
    (* The ATV-IMC controller is present (TRUE) if it has correctly answered *)
    IF NOT READ_VAR_Counter_ATV.Error AND READ_VAR_Counter_ATV.Done THEN
        (* The ATV-IMC controller is present: In this example, this permanent read command is *)
        (* used to determine the presence of the ATV-IMC controller on the Ethernet network.  *)
        v_xPresenceAtvImc  := TRUE;
        (* No communication error *)
        v_xCommErrorAtvImc := FALSE;
    (* Otherwise, a communication error is reported: Timeout or other error? *)
    ELSIF READ_VAR_Counter_ATV.Error THEN
        (* Absence of the ATV-IMC controller on the Ethernet network *)
        IF ( READ_VAR_Counter_ATV.CommError = CommunicationErrorCodes.TimedOut ) THEN
            v_xPresenceAtvImc  := FALSE;
        (* Other communication error (Timeout excluded) *)
        ELSE
            v_xCommErrorAtvImc := TRUE;
        END_IF
    END_IF
END_IF


(***************************************************************************)
(*** Modbus TCP Communications: ATV counter written back after each read ***)
(*** Function Block(s): SINGLE_WRITE                                     ***)
(***************************************************************************)

(* Update of the value of the copy of the counter produced by the ATV-IMC controller: Remote value of the Source *)
v_wCounter_ATV_Copy_Local := v_wCounter_ATV_Srce_Remote;

(* F_TRIG Function Block for detecting the end of the ATV counter read operation and trigerring the write operation *)
F_TRIG_ReadAtvCounter_End.CLK := READ_VAR_Counter_ATV.Busy;
F_TRIG_ReadAtvCounter_End();
(* Memorization of the end of the ATV counter read operation *)
IF F_TRIG_ReadAtvCounter_End.Q THEN
    v_xMemReadAtvCounter_End := TRUE;
END_IF

(* Command to write back the counter of the ATV-IMC: IF Address is OK *)
(* AND at the (memorized) end of each read operation *)
(* AND Previous write is finished *)
IF v_xAddressIsOK_ModbusTcpAtvImc AND v_xMemReadAtvCounter_End AND NOT SINGLE_WRITE_Counter_ATV.Busy THEN
    v_xWriteCounter_ATV         := TRUE;
    (* Reset of the memorization: Each read value is only sent back once *)
    v_xMemReadAtvCounter_End    := FALSE;
END_IF

(* SINGLE_WRITE Function Block for writing back the counter to the ATV-IMC controller *)
(* NOTE: In ST language, this call syntax is required for Function Blocks of the            *)
(*       "PLCCommunication" library that use an "Addr" INPUT variable (data type = ADDRESS) *)
SINGLE_WRITE_Counter_ATV(
    (* IN  - Rising Edge signal that triggers this Function Block *)
    Execute    := v_xWriteCounter_ATV,
    (* IN  - Function Block not aborted (FALSE) *)
    Abort      := FALSE,
    (* IN  - Formatted Modbus TCP address of the ATV-IMC controller *)
    Addr       := v_addressModbusTcpAtvImc,
    (* IN  - Timeout of 500 ms *)
    Timeout    := 5,
    (* IN  - Type of object to be written: MW --> The Modbus function #6 (write single register) is used *)
    ObjType    := ObjectType.MW,
    (* IN  - Object to be written: The copy of the applicative counter of the ATV-IMC (address = %MW101) *)
    FirstObj   := 101,
    (* IN  - Value to write in the copy of the counter produced by the ATV-IMC controller *)
    theWord    := v_wCounter_ATV_Copy_Local,
    (* OUT - This output is not used in this program *)
    Done       => ,
    (* OUT - "Busy" output of the ATV counter write operation (this output will directly be used in the program) *)
    Busy       => ,
    (* OUT - These outputs are not used in this program *)
    Aborted    => ,
    Error      => ,
    CommError  => ,
    OperError  => );

(* At the end of the current Modbus TCP write operation for the copy of the applicative counter of the ATV-IMC controller *)
IF NOT SINGLE_WRITE_Counter_ATV.Busy THEN
    (* Resets the command to write back the counter of the ATV-IMC *)
    v_xWriteCounter_ATV := FALSE;
END_IF

(******************************************************************)
(*** Periodic command (once per second) : Write & Read Statuses ***)
(*** Function Block(s): READ_VAR                                ***)
(***                    WRITE_VAR                               ***)
(******************************************************************)

(* NOTE: The "Read/write multiple registers (%MW)" Modbus function (function #23 (17 hex)) is *)
(*       not supported by the ATV-IMC; one READ command and one WRITE command are used here.  *)

(* BLINK Function Block for periodic read and write of the ATV-IMC and M258 statuses: 1-second clock *)
(* IN  - Enabled (TRUE) after the first cycle *)
BLINK_RW_Statuses.ENABLE   := NOT v_xIsFirstCycle;
(* IN  - Duration of the LOW  state (100 ms) *)
BLINK_RW_Statuses.TIMELOW  := T#100MS;
(* IN  - Duration of the HIGH state (900 ms) *)
BLINK_RW_Statuses.TIMEHIGH := T#900MS;
(* Function Block call *)
BLINK_RW_Statuses();
(* OUT - Resulting 1-second clock *)
v_xClockReadWriteStatuses := BLINK_RW_Statuses.OUT;

(* Command to read and write the ATV-IMC and M258 statuses: IF Address is OK AND Once per second (duration = 900 ms) *)
v_xReadWriteStatuses := v_xAddressIsOK_ModbusTcpAtvImc AND v_xClockReadWriteStatuses;

(* WRITE_VAR Function Block for writing (sending) the M258 status into the ATV-IMC *)
(* NOTE: In ST language, this call syntax is required for Function Blocks of the            *)
(*       "PLCCommunication" library that use an "Addr" INPUT variable (data type = ADDRESS) *)
WRITE_VAR_Status(
    (* IN  - Rising Edge signal that triggers this Function Block *)
    Execute       := v_xReadWriteStatuses,
    (* IN  - Function Block not aborted (FALSE) *)
    Abort         := FALSE,
    (* IN  - Formatted Modbus TCP address of the ATV-IMC controller *)
    Addr          := v_addressModbusTcpAtvImc,
    (* IN  - Timeout of 500 ms *)
    Timeout       := 5,
    (* IN  - Type of object to be written: MW --> The Modbus function #16 (write multiple registers) is used *)
    ObjType       := ObjectType.MW,
    (* IN  - Object to be written: All addresses given below are addresses on the ATV-IMC controller *)
    (*       %MD100 (%MW200+%MW201) = Controller Hardware Version of the M258 controller    *)
    (*       %MD101 (%MW202+%MW203) = Controller Coprocessor Version of the M258 controller *)
    (*       %MW204                 = State of the controller of the M258 controller        *)
    FirstObj      := 200,
    (* IN  - Number of objects to write: 5 registers (2 DWORDs + 1 WORD) *)
    Quantity      := 5,
    (* IN  - Address of the CONSECUTIVE variables which values will be SENT to the ATV-IMC controller *)
    (*       %MW60008 (DWORD) = Controller Hardware Version    *)
    (*       %MW60010 (DWORD) = Controller Coprocessor Version *)
    (*       %MW60012 (WORD ) = State of the controller        *)
    Buffer        := ADR(PLC_R.i_dwHardVersion),
    (* OUT - This output is not used in this program *)
    Done          => ,
    (* OUT - "Busy" output of the M258 status write operation (this output will directly be used in the program) *)
    Busy          => ,
    (* OUT - These outputs are not used in this program *)
    Aborted       => ,
    Error         => ,
    CommError     => ,
    OperError     => );

(* READ_VAR Function Block for reading the ATV-IMC status *)
(* NOTE: In ST language, this call syntax is required for Function Blocks of the            *)
(*       "PLCCommunication" library that use an "Addr" INPUT variable (data type = ADDRESS) *)
READ_VAR_Status(
    (* IN  - Rising Edge signal that triggers this Function Block *)
    Execute       := v_xReadWriteStatuses,
    (* IN  - Function Block not aborted (FALSE) *)
    Abort         := FALSE,
    (* IN  - Formatted Modbus TCP address of the ATV-IMC controller *)
    Addr          := v_addressModbusTcpAtvImc,
    (* IN  - Timeout of 500 ms *)
    Timeout       := 5,
    (* IN  - Type of object to be read: MW --> The Modbus function #3 (read holding registers) is used *)
    ObjType       := ObjectType.MW,
    (* IN  - Object to be read: All addresses given below are addresses on the ATV-IMC controller *)
    (*       %MD150 (%MW300+%MW301) = Copy of the Controller Hardware Version of the ATV-IMC controller    *)
    (*       %MD151 (%MW302+%MW303) = Copy of the Controller Coprocessor Version of the ATV-IMC controller *)
    (*       %MW304                 = Copy of the State of the controller of the ATV-IMC controller        *)
    FirstObj      := 300,
    (* IN  - Number of objects to read: 5 registers (2 DWORDs + 1 WORD) *)
    Quantity      := 5,
    (* IN  - Address of the variables for RECEIVING the values of the status registers of the ATV-IMC controller *)
    Buffer        := ADR(v_wAtvImc_ReadRegisters),
    (* OUT - This output is not used in this program *)
    Done          => ,
    (* OUT - "Busy" output of the ATV-IMC status read operation (this output will directly be used in the program) *)
    Busy          => ,
    (* OUT - These outputs are not used in this program *)
    Aborted       => ,
    Error         => ,
    CommError     => ,
    OperError     => );

(* F_TRIG Function Block for detecting the end of the ATV-IMC status read operation *)
F_TRIG_ReadStatus_End.CLK := READ_VAR_Status.Busy;
F_TRIG_ReadStatus_End();
(* Upon completion of the ATV-IMC status read operation, the read *)
(* values are dispatched into their DWORD and WORD variables.     *)
IF F_TRIG_ReadStatus_End.Q THEN
    v_dwAtvImc_CtrlHWVersion     := WORD_TO_DWORD(v_wAtvImc_ReadRegisters[1]) + SHL( WORD_TO_DWORD(v_wAtvImc_ReadRegisters[2]) , 16 );
    v_dwAtvImc_CtrlCoProcVersion := WORD_TO_DWORD(v_wAtvImc_ReadRegisters[3]) + SHL( WORD_TO_DWORD(v_wAtvImc_ReadRegisters[4]) , 16 );
    v_wAtvImc_State              := v_wAtvImc_ReadRegisters[5];
END_IF


(* For initializations only: Reset to FALSE at first cycle's end *)
v_xIsFirstCycle := FALSE;
