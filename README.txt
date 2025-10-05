KipuBank — Bóveda de ETH

Bóveda simple de ETH nativo donde cada usuario mantiene su saldo personal.
Incluye:

Capacidad por Banco
Limite por transacción
Eventos y errores personalizados 
Protección anti-reentradas.
Contadores globales de depósitos y retiros.

Como interactuar con el contrato:

Variables inmutables:
LimitePorBanco: tope global de depósitos (wei).
LimiteRetiroPorTransaccion: límite por retiro (wei).

Mapeo de saldos: balances por usuario.

Funciones públicas/externas (nombres pueden variar según tu contrato):
deposit() (payable) / Deposito(): deposita ETH a tu bóveda.
RetiroSaldo(uint256 Cantidad): retira con umbral por tx.
SaldoDeCuenta(address): consulta de saldo.
CapacidadDeDepositoRestante(): capacidad restante del banco.
receive() permite depositar enviando ETH directo al contrato.

Eventos: Depositado y Retiro.

Errores personalizados para todas las validaciones.
