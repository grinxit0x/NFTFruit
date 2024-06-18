// SPDX-License-Identifier: grinxit0x
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../NFTFruit.sol";
import "./Variedad.sol";

contract MainTree is AccessControl {
    bytes32 public constant FARMER_ROLE = keccak256("FARMER_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");
    bytes32 public constant TRANSPORTER_ROLE = keccak256("TRANSPORTER_ROLE");
    bytes32 public constant STORAGE_ROLE = keccak256("STORAGE_ROLE");
    bytes32 public constant PRODUCTION_MANAGER_ROLE = keccak256("PRODUCTION_MANAGER_ROLE");

    NFTFruit private nftContract;
    uint256 public plantingFee = 1 ether;

    uint256 private productionCounter;
    uint256 public treatmentCounter;

    event TreePlanted(uint256 indexed treeId, uint256 timestamp);
    event TreatmentAdded(uint256 indexed treeId, uint256 treatmentId, Treatment treatment);
    event ProductionAdded(uint256 indexed treeId, uint256 productionId, Production production);
    event ProductionTransported(uint256 indexed treeId, uint256 indexed productionId, string details, uint256 timestamp);
    event ProductionStored(uint256 indexed treeId, uint256 indexed productionId, string details, uint256 timestamp);
    event ProductionReduced(uint256 indexed treeId, uint256 indexed productionId, uint256 amount, uint256 timestamp);

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
        mapping(uint256 => Treatment) treatments;
        uint256 numTreatments;
        mapping(uint256 => Production) productions;
        uint256 numProductions;
    }

    mapping(uint256 => Tree) public trees;
    uint256 public numTrees;

    constructor(address _nftContractAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        addCouncilMember(msg.sender);
        nftContract = NFTFruit(_nftContractAddress);
    }

    modifier onlyTreeOwner(uint256 _treeId) {
        require(nftContract.ownerOf(_treeId) == msg.sender, "Caller is not the owner of this tree");
        _;
    }

    function plantTree(
        uint256 _latitude,
        uint256 _longitude,
        uint8 _pol,
        uint8 _parcela,
        string memory _plot,
        string memory _municipality,
        string memory _class,
        uint8 _var
    ) public payable onlyRole(FARMER_ROLE) {
        require(msg.value >= plantingFee, "Insufficient fee to plant a tree");

        numTrees++;
        uint256 treeId = numTrees;
        Tree storage newTree = trees[treeId];
        newTree.plantedAt = block.timestamp;
        newTree.variety = Variedad.VariedadEnum(_var);
        newTree.class = _class;
        newTree.location = Location(_latitude, _longitude, _pol, _parcela, _plot, _municipality);

        // Mint the NFT to the caller
        nftContract.mintNFT(msg.sender, treeId);

        emit TreePlanted(treeId, block.timestamp);
    }

    function setPlantingFee(uint256 _newFee) public onlyRole(DEFAULT_ADMIN_ROLE) {
        plantingFee = _newFee;
    }

    function addTreatment(
        uint256 _treeId,
        uint256 _dose,
        string memory _family,
        string memory _desc,
        string memory _composition,
        string memory _numReg,
        string memory _reason,
        string memory _period
    ) public onlyRole(FARMER_ROLE) onlyTreeOwner(_treeId) {
        require(_treeId > 0 && _treeId <= numTrees, "Tree ID is invalid");
        Tree storage tree = trees[_treeId];
        tree.treatments[tree.numTreatments] = Treatment(
            uint40(block.timestamp),
            _dose,
            _family,
            _desc,
            _composition,
            _numReg,
            _reason,
            _period
        );
        tree.numTreatments++;

        emit TreatmentAdded(_treeId, tree.numTreatments - 1, tree.treatments[tree.numTreatments - 1]);
    }

    function addProduction(uint256 _treeId, uint256 _quantity) public onlyRole(FARMER_ROLE) onlyTreeOwner(_treeId) {
        require(_treeId > 0 && _treeId <= numTrees, "Tree ID is invalid");
        Tree storage tree = trees[_treeId];
        tree.productions[tree.numProductions] = Production(uint40(block.timestamp), _quantity, _quantity);
        tree.numProductions++;

        emit ProductionAdded(_treeId, tree.numProductions - 1, tree.productions[tree.numProductions - 1]);
    }

    function transportProduction(uint256 _treeId, uint256 _productionId, string memory _details) public onlyRole(TRANSPORTER_ROLE) onlyTreeOwner(_treeId) {
        require(_treeId > 0 && _treeId <= numTrees, "Tree ID is invalid");
        Tree storage tree = trees[_treeId];
        require(_productionId < tree.numProductions, "Production ID is invalid");
        emit ProductionTransported(_treeId, _productionId, _details, block.timestamp);
    }

    function storeProduction(uint256 _treeId, uint256 _productionId, string memory _details) public onlyRole(STORAGE_ROLE) onlyTreeOwner(_treeId) {
        require(_treeId > 0 && _treeId <= numTrees, "Tree ID is invalid");
        Tree storage tree = trees[_treeId];
        require(_productionId < tree.numProductions, "Production ID is invalid");
        emit ProductionStored(_treeId, _productionId, _details, block.timestamp);
    }

    function updateTreeLocation(
        uint256 _treeId,
        uint256 _latitude,
        uint256 _longitude,
        uint8 _pol,
        uint8 _parcela,
        string memory _plot,
        string memory _municipality
    ) public onlyRole(FARMER_ROLE) onlyTreeOwner(_treeId) {
        require(_treeId > 0 && _treeId <= numTrees, "Tree ID is invalid");
        Tree storage tree = trees[_treeId];
        tree.location = Location(_latitude, _longitude, _pol, _parcela, _plot, _municipality);
    }

    function updateTreeClass(uint256 _treeId, string memory _class) public onlyRole(FARMER_ROLE) onlyTreeOwner(_treeId) {
        require(_treeId > 0 && _treeId <= numTrees, "Tree ID is invalid");
        Tree storage tree = trees[_treeId];
        tree.class = _class;
    }

    function getTreeLocation(uint256 _treeId) public view returns (Location memory) {
        require(_treeId > 0 && _treeId <= numTrees, "Tree ID is invalid");
        return trees[_treeId].location;
    }

    function getTreeClass(uint256 _treeId) public view returns (string memory) {
        require(_treeId > 0 && _treeId <= numTrees, "Tree ID is invalid");
        return trees[_treeId].class;
    }

    function getTreeVariety(uint256 _treeId) public view returns (Variedad.VariedadEnum) {
        require(_treeId > 0 && _treeId <= numTrees, "Tree ID is invalid");
        return trees[_treeId].variety;
    }

    function getTreeAge(uint256 _treeId) public view returns (uint256) {
        require(_treeId > 0 && _treeId <= numTrees, "Tree ID is invalid");
        return (block.timestamp - trees[_treeId].plantedAt) / 365 days;
    }

    function getProductions(uint256 _treeId) public view returns (Production[] memory) {
        require(_treeId > 0 && _treeId <= numTrees, "Tree ID is invalid");
        Tree storage tree = trees[_treeId];
        Production[] memory productions = new Production[](tree.numProductions);
        for (uint256 i = 0; i < tree.numProductions; i++) {
            productions[i] = tree.productions[i];
        }
        return productions;
    }

    function getProduction(uint256 _treeId, uint256 _productionId) public view returns (Production memory) {
        require(_treeId > 0 && _treeId <= numTrees, "Tree ID is invalid");
        Tree storage tree = trees[_treeId];
        require(_productionId < tree.numProductions, "Production ID is invalid");
        return tree.productions[_productionId];
    }

    function reduceProduction(uint256 _treeId, uint256 _productionId, uint256 _amount) public onlyRole(PRODUCTION_MANAGER_ROLE) {
        require(_treeId > 0 && _treeId <= numTrees, "Tree ID is invalid");
        Tree storage tree = trees[_treeId];
        require(_productionId < tree.numProductions, "Production ID is invalid");
        Production storage production = tree.productions[_productionId];
        require(production.amount >= _amount, "Insufficient production amount");
        production.amount -= _amount;
        emit ProductionReduced(_treeId, _productionId, _amount, block.timestamp);
    }

    function addCouncilMember(address _account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(FARMER_ROLE, _account);
        grantRole(AUDITOR_ROLE, _account);
        grantRole(TRANSPORTER_ROLE, _account);
        grantRole(STORAGE_ROLE, _account);
    }

    function removeCouncilMember(address _account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(FARMER_ROLE, _account);
        revokeRole(AUDITOR_ROLE, _account);
        revokeRole(TRANSPORTER_ROLE, _account);
        revokeRole(STORAGE_ROLE, _account);
    }

    function addProductionManager(address _account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(PRODUCTION_MANAGER_ROLE, _account);
    }

    function removeProductionManager(address _account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(PRODUCTION_MANAGER_ROLE, _account);
    }

    function addFarmer(address _account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(FARMER_ROLE, _account);
    }

    function removeFarmer(address _account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(FARMER_ROLE, _account);
    }

    function addAuditor(address _account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(AUDITOR_ROLE, _account);
    }

    function removeAuditor(address _account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(AUDITOR_ROLE, _account);
    }

    function addTransporter(address _account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(TRANSPORTER_ROLE, _account);
    }

    function removeTransporter(address _account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(TRANSPORTER_ROLE, _account);
    }

    function addStorage(address _account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(STORAGE_ROLE, _account);
    }

    function removeStorage(address _account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(STORAGE_ROLE, _account);
    }

    // Funciones para verificar roles
    function hasDefaultAdminRole(address _account) public view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, _account);
    }

    function hasFarmerRole(address _account) public view returns (bool) {
        return hasRole(FARMER_ROLE, _account);
    }

    function hasAuditorRole(address _account) public view returns (bool) {
        return hasRole(AUDITOR_ROLE, _account);
    }

    function hasTransporterRole(address _account) public view returns (bool) {
        return hasRole(TRANSPORTER_ROLE, _account);
    }

    function hasStorageRole(address _account) public view returns (bool) {
        return hasRole(STORAGE_ROLE, _account);
    }

    function hasProductionManagerRole(address _account) public view returns (bool) {
        return hasRole(PRODUCTION_MANAGER_ROLE, _account);
    }
}
