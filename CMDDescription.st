(************************************************************)
(***** Registrador CMD no ATV6xx são registradores para *****)
(** Prepara o Inversor o inversor para partir e colocar o ***)
(******************* Motor para rodar ***********************)
(************************************************************)
FUNCTION CMDDescription : BOOL
VAR_INPUT
    b_Ready     :   BOOL; (* Coloca o inversor em prontidão para Acionamento do Motor *)
    b_Power     :   BOOL; (* Seleciona Alimentação para o motor *)
	b_QuickStop	:	BOOL; (* Parada Rápida *)
	b_Run		:	BOOL; (* Acionamneto do Motor *)
	b_Clear		:	BOOL; (* Comando de Rearm do Motor *)
	b_Stop		:	BOOL; (* Comando de para do Motor( Será utilizada parada configurada no registrador STT ). *)
END_VAR
VAR_IN_OUT
	w_CMDWord	:	WORD; (* Palavra do conteúdo do Registrador lido / Mudança das posições conforme configuração dos bits *)
END_VAR
VAR
END_VAR

w_CMDWord.0		:=	b_Run;
w_CMDWord.1		:=	b_Power;
w_CMDWord.2		:=	b_QuickStop;
w_CMDWord.3 	:=	b_Ready;
w_CMDWord.7		:=	b_Clear;
w_CMDWord.8		:=	b_Stop;