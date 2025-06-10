Contrato Inteligente de Subasta Segura
Descripción General
Este contrato inteligente implementa una subasta segura y transparente en Ethereum.
La duración de la subasta es fija de 7 días (10080 minutos). Si se realiza una oferta válida en los últimos 10 minutos, la subasta se extiende automáticamente 10 minutos, hasta un máximo de 7 días adicionales.

El contrato permite a los participantes ofertar, retirar excesos de depósito y asegura que solo el propietario pueda finalizar la subasta y devolver los depósitos a los no ganadores (con una comisión del 2%). Todas las acciones importantes quedan registradas mediante eventos.

Funcionalidades Principales
Duración fija de subasta: 7 días (10080 minutos), con extensión automática si hay ofertas en los últimos 10 minutos.
Ofertar: Solo se aceptan ofertas válidas (al menos 5% superiores a la oferta más alta actual).
Reembolso parcial: Los participantes pueden retirar el exceso depositado sobre su última oferta válida durante la subasta.
Devolución de depósitos: Al finalizar la subasta, el propietario puede devolver los depósitos a los no ganadores, descontando una comisión del 2%.
Retiro de emergencia: El propietario puede recuperar todos los fondos del contrato en caso de emergencia.
Eventos: Todas las acciones importantes emiten eventos para transparencia.
Variables Principales
Variable	Tipo	Visibilidad	Descripción
owner	address	public	Dirección del propietario del contrato
auctionEndTime	uint	public	Momento en que finaliza la subasta
maxExtensionTime	uint	public	Máxima extensión permitida (10080 minutos = 7 días)
extendedTime	uint	public	Tiempo total que se ha extendido la subasta
highestBidder	address	public	Dirección del mayor postor actual
highestBid	uint	public	Monto de la oferta más alta actual
bidHistory	Bid[]	public	Array de todas las ofertas (dirección y monto)
deposits	mapping	public	Depósitos de ETH por dirección
lastBid	mapping	public	Última oferta de cada dirección
bidIndex	mapping	private	Índice de cada postor en bidHistory
hasBid	mapping	private	Indica si una dirección ya ofertó
lastBidTime	mapping	public	Última vez que un usuario ofertó
ended	bool	public	Verdadero si la subasta terminó
fundsWithdrawn	bool	private	Verdadero si el owner retiró el monto ganador
cancelled	bool	public	Verdadero si la subasta fue cancelada
Funciones Principales
Constructor
Inicializa la subasta con duración fija de 7 días.
Define al deployer como propietario.
Ofertar
Permite a los usuarios (excepto el owner) ofertar.
La oferta debe ser al menos 5% mayor que la actual.
Las ofertas en los últimos 10 minutos extienden la subasta 10 minutos (máximo 7 días).
Emite el evento NewBid.
Parámetros:

msg.value: Monto de ETH enviado con la oferta.
Reembolso Parcial
Permite a los postores retirar el exceso depositado sobre su última oferta válida durante la subasta.
Emite el evento PartialWithdrawal.
Devolver Depósitos a No Ganadores
Solo el owner puede llamarla al finalizar la subasta.
Devuelve los depósitos a los no ganadores, descontando una comisión del 2%.
Emite los eventos DepositWithdrawn y FeeTransferred.
Finalizar Subasta
Permite al owner finalizar la subasta manualmente antes del tiempo programado.
Emite el evento AuctionEnded.
Retirar Oferta Ganadora
Permite al owner retirar la oferta ganadora después de finalizar la subasta.
Cancelar Subasta
Permite al owner cancelar la subasta si no hay ofertas.
Emite el evento AuctionCancelled.
Retirar Depósito tras Cancelación
Permite a los usuarios retirar su depósito si la subasta fue cancelada.
Emite el evento DepositWithdrawnOnCancel.
Retiro de Emergencia
Permite al owner recuperar todos los ETH del contrato en caso de emergencia.
Emite el evento EmergencyWithdrawal.
Obtener Número de Ofertas
Devuelve la cantidad de ofertas realizadas en la subasta.
Obtener Historial de Ofertas (Paginado)
Devuelve una página del historial de ofertas para paginación.
Parámetros:
offset: Índice de inicio
limit: Cantidad de ofertas a devolver
Obtener Ganador
Devuelve la dirección del mayor postor y el monto de la oferta ganadora.
Eventos
Evento	Descripción
NewBid	Se emite cuando se realiza una nueva oferta
AuctionEnded	Se emite cuando finaliza la subasta
PartialWithdrawal	Se emite cuando un usuario retira exceso de depósito
DepositWithdrawn	Se emite cuando un no-ganador recibe su reembolso
AuctionCancelled	Se emite cuando la subasta es cancelada
FeeTransferred	Se emite cuando el owner recibe la comisión del 2%
DepositWithdrawnOnCancel	Se emite cuando un usuario retira su depósito tras cancelación
EmergencyWithdrawal	Se emite cuando el owner recupera todos los fondos
Seguridad y Buenas Prácticas
Todas las funciones críticas usan modificadores para restringir acceso y asegurar el estado correcto de la subasta.
Todas las transferencias de ETH usan call y verifican el éxito.
Los cambios de estado se realizan antes de llamadas externas para evitar reentradas.
Todas las acciones importantes emiten eventos para transparencia.
El contrato es robusto ante errores y casos límite.
