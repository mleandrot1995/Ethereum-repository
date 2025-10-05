// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title KipuBank 
 * @author Leandro Toloza
 * @notice Boveda de Ethers que permite depositar y transferir ETH con un limite de banco. Tiene un umbral de retiro que no cambia (inmutable) . Contiene patrones de seguridad y emite eventos
 */
contract KipuBank {
	/*///////////////////////
						Errors
	///////////////////////*/
    
    ///@notice El retiro solicitado excede el límite por transacción.
    ///@param Requerido Monto solicitado a retirar.
    ///@param LimitePorTransaccion Límite permitido por transacción.
    error ExcedeLimitePorTransaccion(uint256 Requerido, uint256 LimitePorTransaccion);

    ///@notice Falló la transferencia
    ///@param Recepctor Quien recibe envio.
    ///@param Cantidad Monto en wei.
    error TransferenciaFallida(address Recepctor, uint256 Cantidad);

    ///@notice Reentrada detectada.
    error Reentrada();

	///@notice erro cuando se intenta depositar cero (0) wei
	error CantidadIgualACero();
    ///@notice El depósito supera el límite del banco.
    ///@param Requerido Monto a depositar.
    ///@param Remanente Capacidad restante del banco.
    error ExcedeCapacidadPorBanco(uint256 Requerido, uint256 Remanente);

    /// @notice El retiro solicitado excede el saldo del usuario.
    /// @param Requerido Monto solicitado a retirar.
    /// @param Disponible Saldo disponible del usuario.
    error ExcedeBalance(uint256 Requerido, uint256 Disponible);

	/*///////////////////////
						Events
	////////////////////////*/

    /// @notice Emite cada deposito ejecutado
    /// @param BalanceResultante Saldo actualizado
    /// @param DepositoTotalGlobal Total acumulado depositado
    /// @param Cuenta Direccion de quien deposita
    /// @param Cantidad  Monto depositado

    event Depositado(
        address Cuenta,
        uint256 Cantidad,
        uint256 BalanceResultante,
        uint256 DepositoTotalGlobal
    );

    /// @notice Emite cada retiro ejecutado
    /// @param Cuenta Direccion de quien retiro
    /// @param Cantidad  Monto retirado
    /// @param BalanceResultante Saldo actualizado
    event Retiro(address Cuenta, uint256 Cantidad, uint256 BalanceResultante);

	/*////////////////////////
				Variables de Estado
	////////////////////////*/

    /// @notice Limite de depositos del banco
    uint256 public immutable LimitePorBanco;

    /// @notice Limite de retiro por transaccion.
    uint256 public immutable LimiteRetiroPorTransaccion;

    /// @notice Saldos por usuario.
    mapping(address => uint256) private _balances;

    /// @notice Numero total de depositos realizados
    uint256 public NumeroDeDepositos;

    /// @notice Numero total de retiros realizados
    uint256 public NumeroDeRetiros;

    /// @notice Total depositado 
    uint256 public TotalDepositado;

    /// @notice Flag contra reentradas en deonde 0 es libre y 1 es ocupada
    uint256 private _bloqueado;

    /*///////////////////////////////////
            Modificadores
    ///////////////////////////////////*/

    /// @notice Evita reentradas en funciones sensibles.
    modifier SinReentradas() {
        if (_bloqueado == 1) revert Reentrada();
        _bloqueado = 1;
        _;
        _bloqueado = 0;
    }

    /*/////////////////////////
            constructor
    /////////////////////////*/

    /**
     * @notice Inserta un nuevo banco con tope y un limite por retiro
     * @param _LimiteRetiroPorTransaccion Limite retro por transaccion
     * @param _LimitePorBanco Límite de depositos por banco
     */
    constructor(uint256 _LimitePorBanco, uint256 _LimiteRetiroPorTransaccion) {
        require(_LimitePorBanco > 0, "bankCap=0");
        LimitePorBanco = _LimitePorBanco;
        LimiteRetiroPorTransaccion = _LimiteRetiroPorTransaccion;
    }

    /*/////////////////////////
            external
    /////////////////////////*/

    /**
     * @notice Deposita ETH en la boveda
     */
    function Deposito() external payable {
        _deposito(msg.sender, msg.value);
    }

    /**
     * @notice Retiro de tla boveda depende del limite por transaccion
     * @param Cantidad Monto a retirar
     */
    function RetiroSaldo(uint256 Cantidad) external SinReentradas{
        if (Cantidad == 0) revert CantidadIgualACero();
        if (Cantidad > LimiteRetiroPorTransaccion) {
            revert ExcedeLimitePorTransaccion(Cantidad, LimiteRetiroPorTransaccion);
        }

        uint256 bal = _balances[msg.sender];
        if (Cantidad > bal) revert ExcedeBalance(Cantidad, bal);

        // EFFECTS
        unchecked {
            _balances[msg.sender] = bal - Cantidad;
        }
        NumeroDeRetiros += 1;

        // INTERACTIONS
        _safeSend(msg.sender, Cantidad);

        emit Retiro(msg.sender, Cantidad, _balances[msg.sender]);
    }

    /**
     * @notice Muestra saldo
     * @param Cuenta Dirección
     */
    function SaldoDeCuenta(address Cuenta) external view returns (uint256) {
        return _balances[Cuenta];
    }

    /**
     * @notice Capacidad de deposito restante
     */
    function CapacidadDeDepositoRestante() external view returns (uint256) {
        uint256 SaldoDepositado = TotalDepositado;
        return SaldoDepositado >= LimitePorBanco ? 0 : LimitePorBanco - SaldoDepositado;
    }

    /*/////////////////////////
         Receive&Fallback
    /////////////////////////*/

    /// @notice Permite depositar enviando ETH al contrato.
    receive() external payable {
        _deposito(msg.sender, msg.value);
    }

/*/////////////////////////
        private
/////////////////////////*/

    /**
     * @notice Lógica privada de depósito. Cumple con CEI.
     * @param Destinatario  Dirección acreditada.
     * @param Cantidad Monto en wei.
     */
    function _deposito(address Destinatario, uint256 Cantidad) private {
        if (Cantidad == 0) revert CantidadIgualACero();

        uint256 remanente = _CapacidadRemanente(); // LimitePorBanco - TotalDepositado (nunca baja)
        if (Cantidad > remanente) revert ExcedeCapacidadPorBanco(Cantidad, remanente);

        // EFFECTS
        _balances[Destinatario] += Cantidad;
        TotalDepositado += Cantidad;        // métrica acumulada (no baja en retiros)
        NumeroDeDepositos += 1;

        emit Depositado(Destinatario, Cantidad, _balances[Destinatario], TotalDepositado);
    }

    function _safeSend(address Receptor, uint256 Cantidad) private {
        (bool ok, ) = Receptor.call{value: Cantidad}("");
        if (!ok) revert TransferenciaFallida(Receptor, Cantidad);
    }

    function _CapacidadRemanente() private view returns (uint256) {
        uint256 SaldoDepositado = TotalDepositado;
        return SaldoDepositado >= LimitePorBanco ? 0 : LimitePorBanco - SaldoDepositado;
    }
}
