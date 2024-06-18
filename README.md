Sure, here is the complete `README.md` content with the deployment and role assignment instructions properly formatted:

```markdown
# Blockchain-Based Fruit Tree Management System

This repository contains a set of smart contracts developed in Solidity for a blockchain-based fruit tree management system. The system leverages the Ethereum blockchain to manage the lifecycle of fruit trees, including planting, treatment, production, and distribution, while ensuring transparency and traceability.

## Overview

The fruit tree management system includes several key components:

- **NFTFruit.sol**: Manages the creation and ownership of NFTs representing individual fruit trees.
- **MainTree.sol**: Handles the planting, treatment, and production of fruit trees, integrating with the NFT contract.
- **Variedad.sol**: Defines the different varieties of fruit trees and their thresholds.
- **Distributor.sol**: Manages the distribution of fruit tree products.
- **ProductionTokenERC20.sol**: ERC20 token contract for managing production-related tokens.
- **DateTime.sol**: Utility library for date and time calculations.

## Contracts

### NFTFruit.sol

This contract manages NFTs representing individual fruit trees. Each tree is minted as an NFT when planted, ensuring unique ownership and traceability.

### MainTree.sol

This contract manages the core lifecycle of fruit trees, including planting, treatment, and production. Key features include:

- **Planting Trees**: Plant a new tree by providing location details and variety. This action mints an NFT for the tree.
- **Adding Treatments**: Record treatments applied to trees.
- **Recording Production**: Track production details for each tree.

### Variedad.sol

This contract defines the different varieties of fruit trees and manages thresholds and updates for each variety.

### Distributor.sol

This contract manages the distribution of fruit tree products. Distributors can acquire production, list it for sale, and handle transactions with buyers.

### ProductionTokenERC20.sol

This contract is an ERC20 token contract for managing production-related tokens. Distributors can mint and transfer tokens representing tree production.

### DateTime.sol

This utility library provides functions for date and time calculations, which are used across the system to handle timestamps and date-based logic.

## Deployment

To deploy the system, follow these steps:

1. Deploy the `NFTFruit.sol` contract.
2. Deploy the `MainTree.sol` contract, passing the address of the deployed `NFTFruit` contract.
3. Deploy the `Variedad.sol` contract.
4. Deploy the `ProductionTokenERC20.sol` contract.
5. Deploy the `Distributor.sol` contract, passing the addresses of the `MainTree` and `ProductionTokenERC20` contracts.

## Role Management

To ensure proper functioning, roles must be assigned using the `grantRole` function. Here’s how to do it:

1. **Admin Setup**: The admin has the default admin role and can grant other roles.
   ```solidity
   mainTreeContract.grantRole(DEFAULT_ADMIN_ROLE, adminAddress);
   ```

2. **Farmer Role**: Required for planting trees and adding treatments.
   ```solidity
   mainTreeContract.grantRole(FARMER_ROLE, farmerAddress);
   ```

3. **Transporter Role**: Required for transporting production.
   ```solidity
   mainTreeContract.grantRole(TRANSPORTER_ROLE, transporterAddress);
   ```

4. **Storage Role**: Required for storing production.
   ```solidity
   mainTreeContract.grantRole(STORAGE_ROLE, storageAddress);
   ```

5. **Production Manager Role**: Required for managing production quantities.
   ```solidity
   mainTreeContract.grantRole(PRODUCTION_MANAGER_ROLE, productionManagerAddress);
   ```

6. **NFTFruit Contract Trust**: Ensure the NFTFruit contract trusts the MainTree contract for minting NFTs.
   ```solidity
   nftFruitContract.grantRole(MINTER_ROLE, mainTreeContractAddress);
   ```

## Usage

After deploying the contracts and assigning roles, you can interact with them using a web3 interface (such as Remix or a custom dApp). Key interactions include:

- **Planting a Tree**: Call `plantTree` on the `MainTree` contract, providing the necessary details and paying the required fee.
  ```solidity
  mainTreeContract.plantTree(latitude, longitude, pol, parcela, plot, municipality, class, variety, { value: plantingFee });
  ```
  Ensure the caller has the `FARMER_ROLE`.

- **Adding a Treatment**: Call `addTreatment` on the `MainTree` contract, providing treatment details.
  ```solidity
  mainTreeContract.addTreatment(treeId, treatment);
  ```
  Ensure the caller has the `FARMER_ROLE` and owns the tree.

- **Recording Production**: Call `addProduction` on the `MainTree` contract, providing production details.
  ```solidity
  mainTreeContract.addProduction(treeId, quantity);
  ```
  Ensure the caller has the `FARMER_ROLE` and owns the tree.

- **Distributing Products**: Call `acquireProduction` and `listProductionForSale` on the `Distributor` contract to manage distribution.
  ```solidity
  distributorContract.acquireProduction(treeId, productionId, amount);
  distributorContract.listProductionForSale(inventoryIndex, pricePerUnit);
  ```

## Contributing

Contributions are welcome! Please fork the repository and submit pull requests with your improvements.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
```

This `README.md` provides a comprehensive guide for deploying and using the contracts, including the necessary steps to assign roles and ensure the contracts function correctly.