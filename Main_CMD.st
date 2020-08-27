PROGRAM Main_CMD
	(*************************************************************)
    (********************** Observações **************************)
	(* Verifique se o registrador RCB está usando o Canal 1, *****)
	(**** caso estiver, verifique se o CD1 (Command Channel 1) ***)
	(********************** está usando Ethernet. ****************)
	(* Para essa programação funcionar, verifique também o CHCF **)
	(*** (Control Mode Configuration), se está usando perfil de **)
	(**** acesso de IO, após isso configure o registrador TCC ****)
	(********************* para 3-wireControl. *******************)
    (*************************************************************)

VAR
	
	(*************************************************************)
    (*********** Variáveis para Bloco de Comunicação *************)
    (*************************************************************)
	(* Declaração do Bloco de Comunicação com o inversor *)
	ADDM_atv630Add		:	ADDM;
	(* Variável para identificação do primeiro ciclo *)
	b_firstCycle		:	BOOL	:=	TRUE;
	(* Endereço IP do inversor*)
	s_AddressInv		:	STRING	:=	'192.168.100.40';
	(* Endereço para o cabeçalho do Protocolo *)
	s_AddressInvAll		:	STRING;
	(* Endereço obtido pelo bloco de comunicação *)
	s_AddressModbusTcp	:	ADDRESS;
	
	
	(*************************************************************)
    (********************* Bloco de Pulso ************************)
    (*************************************************************)
	BL_Pulse			:	BLINK;
	
	(*************************************************************)
    (************** Variáveis para Bloco de Pulso ****************)
    (*************************************************************)
	t_High				:	TIME	:=	T#100MS; (* 100 MS para borda alta *)
	t_Low				:	TIME	:=	T#100MS; (* 100MS paea borda baixa *)
	b_Enable			:	BOOL	:=	TRUE;	 (* Habilita bloco de pulso *)
	
	(*************************************************************)
    (************* Variáveis para Bloco de Leitura ***************)
    (*************************************************************)
	(*Bloco de Leitura de dados do equipamento*)
	RV_ETAatv630			:	READ_VAR;
	RV_CMDatv630			:	READ_VAR;
	RV_HMISatv630			:	READ_VAR;
	
	(*************************************************************)
    (************* Variáveis para Bloco de Ecrita ****************)
    (*************************************************************)
	SG_WriteSingleCMDatv630	:	SINGLE_WRITE;
	SG_WriteSingleMotorRot		:	SINGLE_WRITE;
	SG_WriteSingleQuickStop		:	SINGLE_WRITE;
	(*************************************************************)
    (********* Variáveis de análise dos Registradores ************)
    (*************************************************************)
	w_DataReadETAatv630			:	WORD; (* Variável para armazenar dados do registrador ETA *)
	w_DataRCMDatv630			:	WORD; (* Variável para obter os dados do registrador CMD *)
	w_DataWCMDatv630			:	WORD; (* Variável para armazenar dados do registrador CMD *)
	w_QuickStop					:	WORD	:=	2; (* Parada Rápida *)
	i_RotMotoratv630			:	INT	:=	1000; (* Variável para controlar velocidade do motor *)
END_VAR
VAR
	(*************************************************************)
    (****************** Variáveis para debug *********************)
    (*************************************************************)
	b_Pronto					:	BOOL;	(* Variável para colocar dispositivo em Estado de Pronto *)
	b_Energia					:	BOOL;	(* Variável para colocar dispositivo em Estado de Pronto *)
	b_Ligar						:	BOOL;	(* Variável para colocar dispositivo em Estado de Pronto *)
	b_Parar						:	BOOL;	(* Variável para colocar dispositivo em Estado de Pronto *)
	b_Limpar					:	BOOL;	(* Variável para colocar dispositivo em Estado de Pronto *)
	i_Velocidade				:	UINT;	(* Variável para colcoar velocidade do motor *)
END_VAR

(* Verifica se já executou alguma vez *)
IF(b_firstCycle)	THEN
	(* 3 Coloca a comunicação por Ethernet *)
	s_AddressInvAll := CONCAT('3{', s_AddressInv);
	(* 248 é o endereco do equipamento da na rede Ethernet ModBus *)
	s_AddressInvAll	:= CONCAT(s_AddressInvAll,'}248');
END_IF

BL_Pulse(
	ENABLE		:=	b_Enable,
	TIMELOW		:=	t_Low,
	TIMEHIGH	:=	t_High, 
	OUT=>
);

ADDM_atv630Add(
	(*************************  IN/OUT *****************************)
	(* IN_OU Endereço do TCP ModBus *)
	AddrTable	:=	s_AddressModbusTcp,
	(* Varia o Bloco para reconectar novamente *)
	Execute		:=	BL_Pulse.OUT,
	(* Cabeçalho de Endereco para conexão com o equipamento *)
	Addr		:=	s_AddressInvAll,
	(***************************** OUT ******************************)
	(* Informa se a operação ocorreu com sucesso *)
	Done		=>,
	(* Informa se houve erro na comunicação *)
	Error		=>,
	(* Byte para indicar problemas na comunicação *)
	CommError	=>
	);
	
w_DataRCMDatv630 := 0;
	
SG_WriteSingleCMDatv630(
	(* Pronto para executar o Bloco *)
	Execute		:=	ADDM_atv630Add.Done AND NOT ADDM_atv630Add.Error,
	(* Bloco tem de ser executado *)
	Abort		:=	FALSE,
	(* Endereço do bloco ADDM_ModbusTCP_ATVIMC para conexão *)
	Addr		:=	s_AddressModbusTcp,
	(* Tempo Máximo de espera(500ms) *)
	Timeout		:=	5,
	(* Tipo de objeto a ser escrito *)
	ObjType		:=	ObjectType.MW,
	(* Endereco do Objeto a ser escrito *)
	FirstObj	:=	8501,
	(* Palavra a ser escrita *)
	theWord    := w_DataWCMDatv630,
	(* Término da exeução da atividade *)
	Done       => ,
	(* Bloco ainda está ocupado *)
	Busy       => ,
	(* Execução encerrada com exceções *)
	Aborted    => ,
	(* Erro detectados *)
	Error      => ,
	(* Palavra com erros detectados *)
	CommError  => ,
	(* Erros da operação *)
	OperError  =>
	);
	
CMDDescription(
	b_Ready		:=	b_Pronto,
	b_Power		:=	b_Energia,
	b_QuickStop	:=	FALSE,
	b_Run		:=	b_Ligar,
	b_Clear		:= 	b_Limpar,
	b_Stop		:=	FALSE,
	w_CMDWord	:=	w_DataWCMDatv630
	);

SG_WriteSingleCMDatv630(
	(* Pronto para executar o Bloco *)
	Execute		:=	ADDM_atv630Add.Done AND NOT ADDM_atv630Add.Error,
	(* Bloco tem de ser executado *)
	Abort		:=	FALSE,
	(* Endereço do bloco ADDM_ModbusTCP_ATVIMC para conexão *)
	Addr		:=	s_AddressModbusTcp,
	(* Tempo Máximo de espera(500ms) *)
	Timeout		:=	5,
	(* Tipo de objeto a ser escrito *)
	ObjType		:=	ObjectType.MW,
	(* Endereco do Objeto a ser escrito *)
	FirstObj	:=	8501,
	(* Palavra a ser escrita *)
	theWord    := w_DataWCMDatv630,
	(* Término da exeução da atividade *)
	Done       => ,
	(* Bloco ainda está ocupado *)
	Busy       => ,
	(* Execução encerrada com exceções *)
	Aborted    => ,
	(* Erro detectados *)
	Error      => ,
	(* Palavra com erros detectados *)
	CommError  => ,
	(* Erros da operação *)
	OperError  =>
	);
	
SG_WriteSingleMotorRot(
	(* Pronto para executar o Bloco *)
	Execute		:=	SG_WriteSingleCMDatv630.Done AND NOT SG_WriteSingleMotorRot.Error AND
			SG_WriteSingleCMDatv630.Done AND NOT SG_WriteSingleCMDatv630.Error,
	(* Bloco tem de ser executado *)
	Abort		:=	FALSE,
	(* Endereço do bloco ADDM_ModbusTCP_ATVIMC para conexão *)
	Addr		:=	s_AddressModbusTcp,
	(* Tempo Máximo de espera(500ms) *)
	Timeout		:=	5,
	(* Tipo de objeto a ser escrito *)
	ObjType		:=	ObjectType.MW,
	(* Endereco do Objeto a ser escrito *)
	FirstObj	:=	8602,
	(* Palavra a ser escrita *)
	theWord    := i_RotMotoratv630,
	(* Término da exeução da atividade *)
	Done       => ,
	(* Bloco ainda está ocupado *)
	Busy       => ,
	(* Execução encerrada com exceções *)
	Aborted    => ,
	(* Erro detectados *)
	Error      => ,
	(* Palavra com erros detectados *)
	CommError  => ,
	(* Erros da operação *)
	OperError  =>
	);

SG_WriteSingleQuickStop(
		(* Pronto para executar o Bloco *)
	Execute		:=	ADDM_atv630Add.Done AND NOT ADDM_atv630Add.Error AND
			SG_WriteSingleCMDatv630.Done AND NOT SG_WriteSingleCMDatv630.Error,
	(* Bloco tem de ser executado *)
	Abort		:=	FALSE,
	(* Endereço do bloco ADDM_ModbusTCP_ATVIMC para conexão *)
	Addr		:=	s_AddressModbusTcp,
	(* Tempo Máximo de espera(500ms) *)
	Timeout		:=	5,
	(* Tipo de objeto a ser escrito *)
	ObjType		:=	ObjectType.MW,
	(* Endereco do Objeto a ser escrito *)
	FirstObj	:=	8651,
	(* Palavra a ser escrita *)
	theWord    := w_QuickStop,
	(* Término da exeução da atividade *)
	Done       => ,
	(* Bloco ainda está ocupado *)
	Busy       => ,
	(* Execução encerrada com exceções *)
	Aborted    => ,
	(* Erro detectados *)
	Error      => ,
	(* Palavra com erros detectados *)
	CommError  => ,
	(* Erros da operação *)
	OperError  =>
	);

RV_CMDatv630(
(*************************  IN/OUT *****************************)
(* Verifica se está pronto para leitura *)
Execute		:= ADDM_atv630Add.Done AND NOT ADDM_atv630Add.Error AND
			SG_WriteSingleQuickStop.Done AND NOT SG_WriteSingleQuickStop.Error,
(***************************** IN *******************************)
(* Saída repentina da FB *)
Abort		:=	FALSE,
(* Endereço ModBus para conexão *)
Addr		:=	s_AddressModbusTcp,
(* Tempo Máximo de espera(500ms) *)
Timeout		:=	5,
(* Tipo de Objeto a ser lido *)
ObjType		:=	ObjectType.MW,
(* Início do Objeto a ser lido *)
FirstObj	:=	8501,
(* Quantidade de Endereços lido a partir do primeiro *)
Quantity	:=	1,
(* Aramzenamento do Dado lido remotamente *)
Buffer		:= ADR(w_DataRCMDatv630),
(***************************** OUT ******************************)
(* Conclusão da atividade *)
Done		=>,
(* Bloco ocupado *)
Busy		=>,
(* Execução encerrada com erros *)
Aborted		=>,
(* Erro na operação de leitura da informação *)
Error		=>,
(* Erros detectados na comunicação *)
CommError	=>,
(* Erros detectados na operação *)
OperError	=>	
);

RV_ETAatv630(
(*************************  IN/OUT *****************************)
(* Verifica se está pronto para leitura *)
Execute		:= ADDM_atv630Add.Done AND NOT ADDM_atv630Add.Error,
(***************************** IN *******************************)
(* Saída rependtina da FB *)
Abort		:=	FALSE,
(* Endereço ModBus para conexão *)
Addr		:=	s_AddressModbusTcp,
(* Tempo Máximo de espera(500ms) *)
Timeout		:=	5,
(* Tipo de Objeto a ser lido *)
ObjType		:=	ObjectType.MW,
(* Início do Objeto a ser lido *)
FirstObj	:=	3201,
(* Quantidade de Endereços lido a partir do primeiro *)
Quantity	:=	1,
(* Aramzenamento do Dado lido remotamente *)
Buffer		:= ADR(w_DataReadETAatv630),
(***************************** OUT ******************************)
(* Conclusão da atividade *)
Done		=>,
(* Bloco ocupado *)
Busy		=>,
(* Execução encerrada com erros *)
Aborted		=>,
(* Erro na operação de leitura da informação *)
Error		=>,
(* Erros detectados na comunicação *)
CommError	=>,
(* Erros detectados na operação *)
OperError	=>	
);



IF((NOT RV_ETAatv630.Busy AND RV_ETAatv630.Done AND NOT RV_ETAatv630.Error) OR TRUE) THEN
ETADescription(
(***************************** IN *******************************)
(* Entrada da palavra obtida do Registrador *)
w_ETARegister	:=	w_DataReadETAatv630,
(***************************** OUT ******************************)
b_PowerReady	=>,
b_Ready			=>,
b_Enable		=>,
b_Fail			=>,
b_Voltage_On	=>,
b_QuickStop		=>,
b_PowerBlocked	=>,
b_Warning		=>,
b_CmtFieldBus	=>,
b_RefSpeed		=>,
b_LimitActive	=>,
b_StopKey		=>,
b_Direction		=>);
END_IF

	
b_firstCycle := FALSE;