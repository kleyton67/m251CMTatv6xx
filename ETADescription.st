FUNCTION ETADescription : BOOL
VAR_INPUT
	w_ETARegister	:	WORD;	(* Palavra de entrada para a função *)
END_VAR
VAR
END_VAR
VAR_OUTPUT
	b_PowerReady	:	BOOL;	(* Dispositivo alimentado *)
	b_Ready			:	BOOL;	(* Dispositivo pronto para Ligar Motor *)
	b_Enable		:	BOOL;	(* Dispositivo em Execução *)
	b_Fail			:	BOOL;	(* Detectado falha no dispositivo *)
	b_Voltage_On	:	BOOL;	(* Alimentação conectada (TRUE) / Não comentada (FALSE) *)
	b_QuickStop		:	BOOL;	(* Motor parado usando método rápido *)
	b_PowerBlocked	:	BOOL;	(* Alimentação Bloqueada *)
	b_Warning		:	BOOL;	(* Detectado Alertas *)
	b_CmtFieldBus	:	BOOL;	(* Referência via fieldbus *)
	b_RefSpeed		:	BOOL;	(* Referência de velocidade quando motor está rodando *)
	b_LimitActive	:	BOOL;	(* 0 - A referência  do motor esta dentro dos limites LSB e HSP / 1 - Limite estrapolado *)
	b_StopKey		:	BOOL;	(* Botão de parada na IHM *)
	b_Direction		:	BOOL;	(* 0 - Rotação com direção para frente / 1 - Rotação com direção para trás *)
END_VAR

(*************************************************************)
(*** Identificação dos bits para Erros a partir do Reg ETA ***)
(*************************************************************)
b_PowerReady	:=	w_ETARegister.0;
b_Ready			:=	w_ETARegister.1;
b_Enable		:=	w_ETARegister.2;
b_Fail			:=	w_ETARegister.3;
b_Voltage_On	:=	w_ETARegister.4;
b_QuickStop		:=	w_ETARegister.5;
b_PowerBlocked	:=	w_ETARegister.6;
b_Warning		:=	w_ETARegister.7;
b_CmtFieldBus	:=	w_ETARegister.9;
b_RefSpeed		:=	w_ETARegister.10;
b_LimitActive	:=	w_ETARegister.11;
b_StopKey		:=	w_ETARegister.14;
b_Direction		:=	w_ETARegister.15;