// SPDX-License-Identifier: grinxit0x
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./helpers/MainTree.sol";
import "./ProductionTokenERC20.sol";

contract Distributor is AccessControl {
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    MainTree private mainTreeContract;
    ProductionTokenERC20 private productionToken;

    struct AcquiredProduction {
        uint256 treeId;
        uint256 productionId;
        uint256 amount;
        uint256 pricePerUnit;
    }

    mapping(address => AcquiredProduction[]) public distributorInventory;

    event ProductionAcquired(uint256 indexed treeId, uint256 indexed productionId, address indexed distributor, uint256 amount, uint256 timestamp);
    event ProductionListedForSale(uint256 indexed treeId, uint256 indexed productionId, address indexed distributor, uint256 amount, uint256 pricePerUnit, uint256 timestamp);
    event ProductionSold(uint256 indexed treeId, uint256 indexed productionId, address indexed buyer, uint256 amount, uint256 pricePerUnit, uint256 timestamp);

    constructor(address _mainTreeAddress, address _productionTokenAddress) {
        mainTreeContract = MainTree(_mainTreeAddress);
        productionToken = ProductionTokenERC20(_productionTokenAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DISTRIBUTOR_ROLE, msg.sender);
    }

    function acquireProduction(uint256 _treeId, uint256 _productionId, uint256 _amount) public onlyRole(DISTRIBUTOR_ROLE) {
        // Ensure the tree and production exist and have sufficient amount
        require(_treeId > 0 && _treeId <= mainTreeContract.numTrees(), "Tree ID is invalid");
        require(_productionId < mainTreeContract.getProductions(_treeId).length, "Production ID is invalid");

        MainTree.Production memory production = mainTreeContract.getProduction(_treeId, _productionId);
        require(production.amount >= _amount, "Insufficient production amount");

        // Reduce the production amount in MainTree contract
        mainTreeContract.reduceProduction(_treeId, _productionId, _amount);

        // Mint the production tokens to the distributor
        productionToken.mint(msg.sender, _amount);

        // Add the acquired production to the distributor's inventory
        distributorInventory[msg.sender].push(AcquiredProduction({
            treeId: _treeId,
            productionId: _productionId,
            amount: _amount,
            pricePerUnit: 0
        }));

        emit ProductionAcquired(_treeId, _productionId, msg.sender, _amount, block.timestamp);
    }

    function listProductionForSale(uint256 _inventoryIndex, uint256 _pricePerUnit) public onlyRole(DISTRIBUTOR_ROLE) {
        AcquiredProduction storage production = distributorInventory[msg.sender][_inventoryIndex];
        production.pricePerUnit = _pricePerUnit;

        emit ProductionListedForSale(production.treeId, production.productionId, msg.sender, production.amount, _pricePerUnit, block.timestamp);
    }

    function buyProduction(address _distributor, uint256 _inventoryIndex, uint256 _amount) public payable {
        AcquiredProduction storage production = distributorInventory[_distributor][_inventoryIndex];
        require(production.pricePerUnit > 0, "Production not for sale");
        require(production.amount >= _amount, "Insufficient production amount");
        require(msg.value == _amount * production.pricePerUnit, "Incorrect payment amount");

        // Transfer the payment to the distributor
        payable(_distributor).transfer(msg.value);

        // Reduce the production amount in distributor's inventory
        production.amount -= _amount;

        // Transfer the production tokens to the buyer
        productionToken.transferFrom(_distributor, msg.sender, _amount);

        emit ProductionSold(production.treeId, production.productionId, msg.sender, _amount, production.pricePerUnit, block.timestamp);
    }

    function addDistributor(address _account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(DISTRIBUTOR_ROLE, _account);
    }

    function removeDistributor(address _account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(DISTRIBUTOR_ROLE, _account);
    }
}
