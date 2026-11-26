# TwinEU Interoperable Marketplace Backend

This repository provides the production deployment package for the TwinEU Data Marketplace Backend. It functions as the core transaction and orchestration engine, acting as a secure bridge between web frontends, a local Proof-of-Authority (PoA) blockchain, the TwinEU Federated Catalog, and the local Data Space Connector.

All core services (FastAPI Backend, Hyperledger Besu Blockchain, and Hardhat Smart Contract Deployer) are provided as optimized, pre-compiled Docker images to ensure immediate interoperability without exposing underlying source code.

## Architecture & Features

* **Database Persistence:** PostgreSQL 15.
* **Web3 Monetization Layer:** Pre-configured Hyperledger Besu (IBFT 2.0 Consensus) instance that executes dynamic price transfers and generates immutable access receipts.
* **Federated Catalog Integration:** A dynamic proxy mapping to the TwinEU Middleware with JWT Machine-to-Machine (M2M) authentication, eliminating siloed databases.
* **Data Space Connector Proxy:** A memory-safe streaming parser that securely extracts Base64 payloads from the local DSP Connector and delivers physical files to consumers.
* **Zero-Trust Orchestration:** Decoupled execution integration passing orchestration parameters (CPU, RAM, Execution Frameworks) directly to the Services Workbench.

---

## Deployment Instructions

### Prerequisites

* Docker and Docker Compose (v2+).
* Access to the TwinEU Container Registry to pull the compiled images.
* Network access to the TwinEU Central Middleware and your Local DSP Connector.

### 1. Environment Configuration

The backend requires connection parameters for the IDSA Middleware and the local PostgreSQL database.

1. Copy the template configuration file:
   ```bash
   cp .env.example .env

```

2. Edit the `.env` file and populate the required variables:
* **`DB_USER` / `DB_PASSWORD` / `DB_NAME**`: Credentials for the PostgreSQL database container.
* **`BANK_PRIVATE_KEY`**: The funding wallet used to issue initial ETH to new user wallets on the local blockchain.
* **`MARKETPLACE_PUBLIC_URL`**: The public-facing IP or Domain Name where this backend is hosted (e.g., `http://192.168.2.66:8000`).
* **`MIDDLEWARE_USER` / `MIDDLEWARE_PASS**`: Your organization's service account credentials for authenticating with the TwinEU Data Space.
* **`MIDDLEWARE_*_URL`**: The endpoints for authentication, catalog fetching, and data subscriptions on the TwinEU Middleware.



### 2. Start the Stack

Boot the infrastructure using the production compose file. This automatically uses your pre-built images and orchestrates the network:

```bash
docker compose -f docker-compose.prod.yaml --env-file .env up -d
# Or using the included Makefile:
make up

```

**Boot Sequence:**

1. The **`blockchain`** container initiates the Besu validator node (`twineu-besu-node`).
2. The **`contract-deployer`** container (`twineu-deployer`) detects the active blockchain and automatically deploys the `DataMarketplace.sol` smart contract, saving the cryptographic ABI to a shared Docker volume.
3. The **`db`** container (`twineu-postgres`) spins up PostgreSQL.
4. The **`backend`** container (`twineu-marketplace-backend`) boots, establishes connections to PostgreSQL and the IDSA Middleware, reads the shared ABI, and exposes the REST API on port `8000`.

To monitor the startup process and verify that the smart contract deployed successfully:

```bash
docker compose -f docker-compose.prod.yaml logs -f contract-deployer backend

```

---

## API Reference & Usage

### 1. User & Identity Management

* **`POST /api/auth/login`**: Authenticates a user against the TwinEU IAM and validates Marketplace-specific roles.
```bash
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "your_username", "password": "your_password"}'

```


* **`GET /api/me`**: Returns the logged-in user's active IAM roles, Wallet Address, and live Web3 ETH balance.
```bash
curl -X GET http://localhost:8000/api/me \
  -H "Authorization: Bearer <ACCESS_TOKEN>"

```



### 2. Web3 Wallet Management

* **`POST /api/wallet/init`**: Generates a secure, passphrase-encrypted Web3 wallet for a new user and triggers background funding from the Bank.
```bash
curl -X POST http://localhost:8000/api/wallet/init \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"passphrase": "your_secure_passphrase"}'

```


* **`POST /api/wallet/fund`**: A faucet endpoint for users to request additional testnet ETH if their balance drops below 5 ETH.

### 3. Discovery & Purchasing

* **`GET /api/catalog/page/{page}`**: Proxies discovery queries to the Federated Catalog. Implements a 5-minute memory cache and injects standard platform pricing for missing metadata.
```bash
curl -X GET "http://localhost:8000/api/catalog/page/0" \
  -H "Authorization: Bearer <ACCESS_TOKEN>"

```


* **`POST /api/buy`**: Submits a shopping cart for execution. Validates real-time prices against the IDSA Middleware, processes transactions sequentially to prevent Web3 Nonce collisions, and generates immutable receipts.
```bash
curl -X POST http://localhost:8000/api/buy \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "passphrase": "your_secure_passphrase",
    "items": [
      {
        "asset_id": "asset-uuid-here",
        "price": 0.1,
        "token_uri": "https://twineu.example/catalog/asset-uuid-here"
      }
    ]
  }'

```


* **`GET /api/purchases`**: Retrieves a user's successful purchase history with blockchain transaction hashes and receipt IDs.

### 4. Data Delivery & Streaming

* **`GET /api/download/{asset_id}/{filename}`**: Safely streams a purchased dataset from the Data Space Connector to the consumer. Bypasses base64 memory bloat using a custom chunked parser.
```javascript
// Frontend Integration Example
const response = await fetch(`http://localhost:8000/api/download/${assetId}/${filename}`, {
  headers: { 'Authorization': `Bearer ${token}` }
});
const blob = await response.blob();
const url = window.URL.createObjectURL(blob);
const a = document.createElement('a');
a.href = url;
a.download = filename;
a.click();

```



### 5. Services Workbench Integration

* **`GET /api/workbench/validate`**: Internal validation endpoint used by the Services Workbench to verify cryptographic ownership and return internal artifact URLs.
* **`POST /api/deployments/{asset_id}`**: Dispatches deployment manifests directly to the Services Workbench.
```bash
curl -X POST http://localhost:8000/api/deployments/asset-uuid-here \
  -H "Authorization: Bearer <ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "artifact_type": "AI_MODEL",
    "parameters": {
      "framework": "onnx",
      "resources": {
        "cpu": "500m",
        "memory": "1024Mi"
      }
    }
  }'

```


* **`GET /api/deployments/`**: Retrieves the status of all active Kubernetes workloads deployed by the user.
* **`GET /api/deployments/{deployment_id}`**: Fetches details for a specific deployment.
* **`DELETE /api/deployments/{deployment_id}`**: Terminates an active workload on the Workbench.

### 6. Dashboards

* **`GET /api/dashboard/provider`**: Aggregates total sales and generates a 30-day earnings trend for data providers.
* **`GET /api/dashboard/provider/offerings`**: Merges IDSA catalog metadata with local PostgreSQL financial metrics (times sold, ETH generated) for provider UI tables.
* **`GET /api/dashboard/consumer`**: Aggregates purchase metrics and expenditure trends for buyers.

---

## Maintenance & System Administration

### 1. Manual Inventory Synchronization

In the event of network disruption where the local database misses a provider's acceptance webhooks from the Middleware, system administrators can force a manual alignment.
This script cross-references `data_consumed` and `my_subscriptions` from the Federated Catalog and updates local state.

Execute this directly inside the running backend container:

```bash
docker exec -it twineu-marketplace-backend python sync_inventory.py

```

### 2. Blockchain Node Identity Configuration

By default, the `blockchain` service mounts a local static private key (`./blockchain/key`) to authorize the local `genesis.json` PoA validator. If migrating this component to a shared TwinEU testnet or production network, this local volume mount should be replaced with a secure injection pipeline (e.g., AWS Secrets Manager or HashiCorp Vault) to protect the validator identity.

## Advanced Configuration (Production Setup)

### Generating a New Blockchain Network from Scratch
If you need to deploy a completely fresh, cryptographically unique blockchain network for a true production environment, you must generate a new Node Validator Key and a new Bank Wallet Key, and bind them in the Genesis block.

**Step 1: Generate the Validator (The Engine)**
The validator key proves the Besu server's identity. From the project root, run the official Besu generator:
```bash
cd blockchain/
docker run --rm -v $(pwd):/opt/besu/data hyperledger/besu:23.10 operator generate-blockchain-config --config-file=/opt/besu/data/ibftConfigFile.json --to=/opt/besu/data/networkFiles --private-key-file-name=key

```

Move the newly generated configuration files to the active directory, replacing the default sandbox files:

```bash
cp networkFiles/genesis.json ./genesis.json
cp networkFiles/keys/*/key ./key
rm -rf networkFiles/

```

**Step 2: Generate the Bank (The Money)**
Generate a new standard Ethereum wallet to fund user accounts using Python:

```python
from eth_account import Account
import secrets
priv = "0x" + secrets.token_hex(32)
acct = Account.from_key(priv)
print(f"BANK_PRIVATE_KEY={priv}\nBANK_ADDRESS={acct.address}")

```

Update your `.env` file with the newly generated `BANK_PRIVATE_KEY` and `BANK_ADDRESS`.

**Step 3: Pre-Fund the Bank in the Genesis Block**
The new blockchain must allocate initial funds to your new Bank address at Block #0. Open `./blockchain/genesis.json`, find the `"alloc"` block, and replace the default address with your new `BANK_ADDRESS`:

```json
  "alloc" : {
    "0x<YOUR_NEW_BANK_ADDRESS_HERE>" : {
      "balance" : "0x200000000000000000000000000000000000000000000000000000000000000"
    }
  }

```

**Step 4: Wipe and Restart (The Nuke Command)**
Because the Genesis block and Validator key have changed, the old database is incompatible. You must wipe the Docker volumes before booting up:

```bash
make down-clean
make up

```
