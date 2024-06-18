// SPDX-License-Identifier: grinxit0x
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../NFTFruit.sol";
import "./Variedad.sol";

contract MainTree is AccessControl, ReentrancyGuard {
    // Role constants for access control
    bytes32 public constant FARMER_ROLE = keccak256("FARMER_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");
    bytes32 public constant TRANSPORTER_ROLE = keccak256("TRANSPORTER_ROLE");
    bytes32 public constant STORAGE_ROLE = keccak256("STORAGE_ROLE");
    bytes32 public constant PRODUCTION_MANAGER_ROLE =
        keccak256("PRODUCTION_MANAGER_ROLE");

    NFTFruit private nftContract; // NFT contract instance
    uint256 public plantingFee = 1 ether; // Fee for planting a tree

    // Event declarations
    event TreePlanted(uint256 indexed treeId, uint256 timestamp);
    event TreatmentAdded(
        uint256 indexed treeId,
        uint256 treatmentId,
        Treatment treatment
    );
    event ProductionAdded(
        uint256 indexed treeId,
        uint256 productionId,
        Production production
    );
    event ProductionTransported(
        uint256 indexed treeId,
        uint256 indexed productionId,
        string details,
        uint256 timestamp
    );
    event ProductionStored(
        uint256 indexed treeId,
        uint256 indexed productionId,
        string details,
        uint256 timestamp
    );
    event ProductionReduced(
        uint256 indexed treeId,
        uint256 indexed productionId,
        uint256 amount,
        uint256 timestamp
    );

    // Struct definitions for Location, Production, and Treatment
    struct Location {
        uint256 latitude;
        uint256 longitude;
        uint8 pol;
        uint8 parcela;
        string plot;
        string municipality;
    }

    struct Production {
        uint40 date;
        uint256 amount;
        uint256 totalAmount;
    }

    struct Treatment {
        uint40 date;
        uint256 dose;
        string family;
        string desc;
        string composition;
        string numReg;
        string reason;
        string period;
    }

    struct Tree {
        uint256 plantedAt;
        Variedad.VariedadEnum variety;
        string class;
        Location location;
        uint256 numTreatments;
        uint256 numProductions;
        mapping(uint256 => Treatment) treatments;
        mapping(uint256 => Production) productions;
    }

    mapping(uint256 => Tree) public trees; // Mapping of tree ID to Tree struct
    uint256 public numTrees; // Counter for the number of trees

    // Constructor to initialize the contract with the NFT contract address and set up roles
    constructor(address _nftContractAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        addCouncilMember(msg.sender);
        nftContract = NFTFruit(_nftContractAddress);
    }

    // Modifier to check if the caller is the owner of the tree
    modifier onlyTreeOwner(uint256 _treeId) {
        require(
            nftContract.ownerOf(_treeId) == msg.sender,
            "Caller is not the owner of this tree"
        );
        _;
    }

    // Function to plant a tree, which mints an NFT and assigns it to the caller
    function plantTree(
        uint256 _latitude,
        uint256 _longitude,
        uint8 _pol,
        uint8 _parcela,
        string calldata _plot,
        string calldata _municipality,
        string calldata _class,
        uint8 _var
    ) external payable onlyRole(FARMER_ROLE) nonReentrant {
        require(msg.value >= plantingFee, "Insufficient fee to plant a tree");

        // Increment the tree counter and get the new tree ID
        uint256 treeId = ++numTrees;

        // Directly assign storage variables
        Tree storage newTree = trees[treeId];
        newTree.plantedAt = block.timestamp;
        newTree.variety = Variedad.VariedadEnum(_var);
        newTree.class = _class;
        newTree.location = Location(
            _latitude,
            _longitude,
            _pol,
            _parcela,
            _plot,
            _municipality
        );

        // Mint the NFT to the caller
        nftContract.mintNFT(msg.sender, treeId);

        emit TreePlanted(treeId, block.timestamp);
    }

    // Function to set the planting fee, callable by admin
    function setPlantingFee(uint256 _newFee)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        plantingFee = _newFee;
    }

    // Function to add a treatment to a tree
    function addTreatment(uint256 _treeId, Treatment calldata _treatment)
        external
        onlyRole(FARMER_ROLE)
        onlyTreeOwner(_treeId)
    {
        _validateTreeId(_treeId);

        // Access storage once for `Tree`
        Tree storage tree = trees[_treeId];
        uint256 treatmentId = tree.numTreatments;

        // Store the treatment directly
        Treatment storage newTreatment = tree.treatments[treatmentId];
        newTreatment.date = _treatment.date;
        newTreatment.dose = _treatment.dose;
        newTreatment.family = _treatment.family;
        newTreatment.desc = _treatment.desc;
        newTreatment.composition = _treatment.composition;
        newTreatment.numReg = _treatment.numReg;
        newTreatment.reason = _treatment.reason;
        newTreatment.period = _treatment.period;

        // Increment the treatment counter
        tree.numTreatments++;

        emit TreatmentAdded(_treeId, treatmentId, newTreatment);
    }

    // Function to add production to a tree
    function addProduction(uint256 _treeId, uint256 _quantity)
        external
        onlyRole(FARMER_ROLE)
        onlyTreeOwner(_treeId)
    {
        _validateTreeId(_treeId);

        // Access storage once for `Tree`
        Tree storage tree = trees[_treeId];
        uint256 productionId = tree.numProductions;

        // Store the production directly
        Production storage newProduction = tree.productions[productionId];
        newProduction.date = uint40(block.timestamp);
        newProduction.amount = _quantity;
        newProduction.totalAmount = _quantity;

        // Increment the production counter
        tree.numProductions++;

        emit ProductionAdded(_treeId, productionId, newProduction);
    }

    // Function to log the transport of a production
    function transportProduction(
        uint256 _treeId,
        uint256 _productionId,
        string calldata _details
    ) external onlyRole(TRANSPORTER_ROLE) onlyTreeOwner(_treeId) {
        _validateTreeAndProductionIds(_treeId, _productionId);
        emit ProductionTransported(
            _treeId,
            _productionId,
            _details,
            block.timestamp
        );
    }

    // Function to log the storage of a production
    function storeProduction(
        uint256 _treeId,
        uint256 _productionId,
        string calldata _details
    ) external onlyRole(STORAGE_ROLE) onlyTreeOwner(_treeId) {
        _validateTreeAndProductionIds(_treeId, _productionId);
        emit ProductionStored(
            _treeId,
            _productionId,
            _details,
            block.timestamp
        );
    }

    // Function to update the location of a tree
    function updateTreeLocation(
        uint256 _treeId,
        uint256 _latitude,
        uint256 _longitude,
        uint8 _pol,
        uint8 _parcela,
        string calldata _plot,
        string calldata _municipality
    ) external onlyRole(FARMER_ROLE) onlyTreeOwner(_treeId) {
        _validateTreeId(_treeId);

        // Access storage once and minimize storage writes
        Location storage location = trees[_treeId].location;
        location.latitude = _latitude;
        location.longitude = _longitude;
        location.pol = _pol;
        location.parcela = _parcela;
        location.plot = _plot;
        location.municipality = _municipality;
    }

    // Function to update the class of a tree
    function updateTreeClass(uint256 _treeId, string calldata _class)
        external
        onlyRole(FARMER_ROLE)
        onlyTreeOwner(_treeId)
    {
        _validateTreeId(_treeId);

        // Access storage once and minimize storage writes
        trees[_treeId].class = _class;
    }

    // Function to get the location of a tree
    function getTreeLocation(uint256 _treeId)
        external
        view
        returns (Location memory)
    {
        _validateTreeId(_treeId);
        return trees[_treeId].location;
    }

    // Function to get the class of a tree
    function getTreeClass(uint256 _treeId)
        external
        view
        returns (string memory)
    {
        _validateTreeId(_treeId);
        return trees[_treeId].class;
    }

    // Function to get the variety of a tree
    function getTreeVariety(uint256 _treeId)
        external
        view
        returns (Variedad.VariedadEnum)
    {
        _validateTreeId(_treeId);
        return trees[_treeId].variety;
    }

    // Function to get the age of a tree
    function getTreeAge(uint256 _treeId) external view returns (uint256) {
        _validateTreeId(_treeId);
        return (block.timestamp - trees[_treeId].plantedAt) / 365 days;
    }

    // Function to get all productions of a tree
    function getProductions(uint256 _treeId)
        external
        view
        returns (Production[] memory)
    {
        _validateTreeId(_treeId);

        Tree storage tree = trees[_treeId];
        Production[] memory productions = new Production[](tree.numProductions);
        for (uint256 i = 0; i < tree.numProductions; i++) {
            productions[i] = tree.productions[i];
        }
        return productions;
    }

    // Function to get a specific production of a tree
    function getProduction(uint256 _treeId, uint256 _productionId)
        external
        view
        returns (Production memory)
    {
        _validateTreeAndProductionIds(_treeId, _productionId);
        return trees[_treeId].productions[_productionId];
    }

    // Function to reduce the amount of a specific production
    function reduceProduction(
        uint256 _treeId,
        uint256 _productionId,
        uint256 _amount
    ) external onlyRole(PRODUCTION_MANAGER_ROLE) {
        _validateTreeAndProductionIds(_treeId, _productionId);

        Production storage production = trees[_treeId].productions[
            _productionId
        ];
        uint256 currentAmount = production.amount; // Load once into memory
        require(currentAmount >= _amount, "Insufficient production amount");

        unchecked {
            production.amount = currentAmount - _amount; // Safe subtraction
        }
        emit ProductionReduced(
            _treeId,
            _productionId,
            _amount,
            block.timestamp
        );
    }

    // Function to add a council member with multiple roles
    function addCouncilMember(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        grantRole(FARMER_ROLE, _account);
        grantRole(AUDITOR_ROLE, _account);
        grantRole(TRANSPORTER_ROLE, _account);
        grantRole(STORAGE_ROLE, _account);
    }

    // Function to remove a council member and revoke multiple roles
    function removeCouncilMember(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        revokeRole(FARMER_ROLE, _account);
        revokeRole(AUDITOR_ROLE, _account);
        revokeRole(TRANSPORTER_ROLE, _account);
        revokeRole(STORAGE_ROLE, _account);
    }

    // Function to add a production manager
    function addProductionManager(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        grantRole(PRODUCTION_MANAGER_ROLE, _account);
    }

    // Function to remove a production manager
    function removeProductionManager(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        revokeRole(PRODUCTION_MANAGER_ROLE, _account);
    }

    // Function to add a farmer
    function addFarmer(address _account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(FARMER_ROLE, _account);
    }

    // Function to remove a farmer
    function removeFarmer(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        revokeRole(FARMER_ROLE, _account);
    }

    // Function to add an auditor
    function addAuditor(address _account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(AUDITOR_ROLE, _account);
    }

    // Function to remove an auditor
    function removeAuditor(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        revokeRole(AUDITOR_ROLE, _account);
    }

    // Function to add a transporter
    function addTransporter(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        grantRole(TRANSPORTER_ROLE, _account);
    }

    // Function to remove a transporter
    function removeTransporter(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        revokeRole(TRANSPORTER_ROLE, _account);
    }

    // Function to add a storage role
    function addStorage(address _account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(STORAGE_ROLE, _account);
    }

    // Function to remove a storage role
    function removeStorage(address _account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        revokeRole(STORAGE_ROLE, _account);
    }

    // Function to transfer contract balance to the admin
    function transferFunds(address payable _to, uint256 _amount)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        require(_amount <= address(this).balance, "Insufficient balance");
        _to.transfer(_amount);
    }

    // Helper function to validate tree ID
    function _validateTreeId(uint256 _treeId) internal view {
        require(_treeId > 0 && _treeId <= numTrees, "Tree ID is invalid");
    }

    // Helper function to validate tree and production IDs
    function _validateTreeAndProductionIds(
        uint256 _treeId,
        uint256 _productionId
    ) internal view {
        _validateTreeId(_treeId);
        require(
            _productionId < trees[_treeId].numProductions,
            "Production ID is invalid"
        );
    }

    // Functions to check roles
    function hasDefaultAdminRole(address _account)
        external
        view
        returns (bool)
    {
        return hasRole(DEFAULT_ADMIN_ROLE, _account);
    }

    function hasFarmerRole(address _account) external view returns (bool) {
        return hasRole(FARMER_ROLE, _account);
    }

    function hasAuditorRole(address _account) external view returns (bool) {
        return hasRole(AUDITOR_ROLE, _account);
    }

    function hasTransporterRole(address _account) external view returns (bool) {
        return hasRole(TRANSPORTER_ROLE, _account);
    }

    function hasStorageRole(address _account) external view returns (bool) {
        return hasRole(STORAGE_ROLE, _account);
    }

    function hasProductionManagerRole(address _account)
        external
        view
        returns (bool)
    {
        return hasRole(PRODUCTION_MANAGER_ROLE, _account);
    }
}
