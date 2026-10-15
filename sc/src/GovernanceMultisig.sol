// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title GovernanceMultisig
 * @notice H-06 (R-7 / D-021): gobernanza **M-de-N con timelock** para las operaciones de
 * administración del sistema RWA (roles `DEFAULT_ADMIN_ROLE`, `AGENT_ROLE` y `COMPLIANCE_ROLE`
 * de los contratos).
 *
 * Contexto: hasta ahora los tres roles podían recaer en una sola EOA. El modelo aprobado
 * (D-021) es *multisig 2-de-3 + timelock + custodio de claves*; este contrato implementa el
 * mecanismo on-chain:
 *
 *   1. Varios `owners` (p. ej. 3) con umbral `threshold` (p. ej. 2).
 *   2. Cualquier owner **propone** una llamada (`target`, `value`, `data`).
 *   3. Los owners **aprueban**; al alcanzar el umbral, la propuesta queda ejecutable.
 *   4. Debe transcurrir `delay` (timelock) desde la creación antes de **ejecutar**.
 *   5. Cualquier owner puede **cancelar** mientras no se haya ejecutado.
 *
 * El propio mantenimiento (añadir/quitar owners, umbral y delay) también pasa por una propuesta
 * auto-dirigida (`target == address(this)`), de modo que no hay una vía privilegiada individual.
 * Para que la gobernanza controle un contrato, su rol admin se concede a la dirección de este
 * multisig y la EOA despliega y renuncia (`renounceRole`); ver `RUNBOOK_MIGRACION.md`.
 *
 * Alcance: es un mecanismo de referencia **auditable**; adoptarlo como admin del despliegue
 * canónico y auditarlo externamente sigue siendo un paso operativo (D-024).
 */
contract GovernanceMultisig {
    /// @dev Máximo de owners para acotar el bucle de ejecución/consulta (H-20: escala acotada).
    uint256 public constant MAX_OWNERS = 10;

    address[] private _owners;
    mapping(address => bool) public isOwner;

    /// @dev Número de aprobaciones necesarias para ejecutar.
    uint256 public threshold;

    /// @dev Retardo mínimo entre la propuesta y su ejecución.
    uint256 public delay;

    struct Proposal {
        address target;
        uint256 value;
        bytes data;
        uint256 readyAt;
        uint256 approvals;
        bool executed;
        bool cancelled;
        // ¿Qué owner aprobó esta propuesta?
        mapping(address => bool) approved;
    }

    mapping(uint256 => Proposal) private _proposals;

    /// @dev Identificador de la última propuesta creada (1-based; 0 = inexistente).
    uint256 public proposalCount;

    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event ThresholdUpdated(uint256 threshold);
    event DelayUpdated(uint256 delay);
    event ProposalCreated(
        uint256 indexed id, address indexed proposer, address indexed target, uint256 value, bytes data, uint256 readyAt
    );
    event ProposalApproved(uint256 indexed id, address indexed owner, uint256 approvals);
    event ProposalCancelled(uint256 indexed id, address indexed owner);
    event ProposalExecuted(uint256 indexed id, address indexed executor);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    /// @dev Las operaciones de mantenimiento solo se ejecutan a través de una propuesta aprobada
    /// (el `target` es este mismo contrato y `msg.sender` es el propio multisig).
    modifier onlySelf() {
        require(msg.sender == address(this), "Only via governance");
        _;
    }

    /**
     * @param initialOwners Owners iniciales (sin duplicados ni `address(0)`)
     * @param initialThreshold Aprobaciones necesarias (1..owners.length)
     * @param initialDelay Retardo del timelock en segundos
     */
    constructor(address[] memory initialOwners, uint256 initialThreshold, uint256 initialDelay) {
        require(initialOwners.length > 0, "Owners required");
        require(initialOwners.length <= MAX_OWNERS, "Too many owners");
        require(initialThreshold > 0 && initialThreshold <= initialOwners.length, "Invalid threshold");

        for (uint256 i = 0; i < initialOwners.length; i++) {
            address owner = initialOwners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Duplicate owner");
            isOwner[owner] = true;
            _owners.push(owner);
        }

        threshold = initialThreshold;
        delay = initialDelay;
    }

    /// @dev Lista de owners.
    function getOwners() external view returns (address[] memory) {
        return _owners;
    }

    /// @dev Número de owners.
    function ownerCount() external view returns (uint256) {
        return _owners.length;
    }

    /**
     * @dev Añade un owner. Solo por gobernanza (propuesta auto-dirigida).
     */
    function addOwner(address owner) external onlySelf {
        require(owner != address(0), "Invalid owner");
        require(!isOwner[owner], "Duplicate owner");
        require(_owners.length < MAX_OWNERS, "Too many owners");
        isOwner[owner] = true;
        _owners.push(owner);
        emit OwnerAdded(owner);
    }

    /**
     * @dev Quita un owner. No puede dejar el número de owners por debajo del umbral.
     */
    function removeOwner(address owner) external onlySelf {
        require(isOwner[owner], "Not an owner");
        require(_owners.length - 1 >= threshold, "Threshold exceeds owners");

        isOwner[owner] = false;
        uint256 length = _owners.length;
        for (uint256 i = 0; i < length; i++) {
            if (_owners[i] == owner) {
                _owners[i] = _owners[length - 1];
                _owners.pop();
                break;
            }
        }
        emit OwnerRemoved(owner);
    }

    /**
     * @dev Actualiza el umbral (1..ownerCount).
     */
    function setThreshold(uint256 newThreshold) external onlySelf {
        require(newThreshold > 0 && newThreshold <= _owners.length, "Invalid threshold");
        threshold = newThreshold;
        emit ThresholdUpdated(newThreshold);
    }

    /**
     * @dev Actualiza el retardo del timelock.
     */
    function setDelay(uint256 newDelay) external onlySelf {
        delay = newDelay;
        emit DelayUpdated(newDelay);
    }

    /**
     * @dev Crea una propuesta. Queda ejecutable tras `delay` y con `threshold` aprobaciones.
     * @return id Identificador de la propuesta (1-based)
     */
    function propose(address target, uint256 value, bytes calldata data) external onlyOwner returns (uint256 id) {
        require(target != address(0), "Invalid target");

        id = ++proposalCount;
        Proposal storage proposal = _proposals[id];
        proposal.target = target;
        proposal.value = value;
        proposal.data = data;
        proposal.readyAt = block.timestamp + delay;

        emit ProposalCreated(id, msg.sender, target, value, data, proposal.readyAt);
    }

    /**
     * @dev Aprueba una propuesta. Cada owner cuenta una sola vez.
     */
    function approve(uint256 id) external onlyOwner {
        Proposal storage proposal = _proposals[id];
        require(proposal.target != address(0), "Proposal does not exist");
        require(!proposal.executed && !proposal.cancelled, "Proposal closed");
        require(!proposal.approved[msg.sender], "Already approved");

        proposal.approved[msg.sender] = true;
        proposal.approvals++;
        emit ProposalApproved(id, msg.sender, proposal.approvals);
    }

    /**
     * @dev Ejecuta una propuesta aprobada una vez vencido el timelock.
     */
    function execute(uint256 id) external onlyOwner {
        Proposal storage proposal = _proposals[id];
        require(proposal.target != address(0), "Proposal does not exist");
        require(!proposal.executed && !proposal.cancelled, "Proposal closed");
        require(proposal.approvals >= threshold, "Not enough approvals");
        require(block.timestamp >= proposal.readyAt, "Timelock not expired");

        // Checks-effects-interactions: se marca como ejecutada antes de la llamada externa.
        proposal.executed = true;

        // Se propaga el motivo del revert interno (si lo hay) para conservar el diagnostico.
        (bool success, bytes memory returndata) = proposal.target.call{value: proposal.value}(proposal.data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
                }
            }
            revert("Execution failed");
        }

        emit ProposalExecuted(id, msg.sender);
    }

    /**
     * @dev Cancela una propuesta no ejecutada (cualquier owner).
     */
    function cancel(uint256 id) external onlyOwner {
        Proposal storage proposal = _proposals[id];
        require(proposal.target != address(0), "Proposal does not exist");
        require(!proposal.executed && !proposal.cancelled, "Proposal closed");

        proposal.cancelled = true;
        emit ProposalCancelled(id, msg.sender);
    }

    /**
     * @dev Consulta el estado de una propuesta.
     */
    function getProposal(uint256 id)
        external
        view
        returns (
            address target,
            uint256 value,
            bytes memory data,
            uint256 readyAt,
            uint256 approvals,
            bool executed,
            bool cancelled
        )
    {
        Proposal storage proposal = _proposals[id];
        return (
            proposal.target,
            proposal.value,
            proposal.data,
            proposal.readyAt,
            proposal.approvals,
            proposal.executed,
            proposal.cancelled
        );
    }

    /// @dev ¿Aprobó `owner` la propuesta `id`?
    function hasApproved(uint256 id, address owner) external view returns (bool) {
        return _proposals[id].approved[owner];
    }

    /// @dev Recibe fondos para propuestas con `value > 0`.
    receive() external payable {}
}
