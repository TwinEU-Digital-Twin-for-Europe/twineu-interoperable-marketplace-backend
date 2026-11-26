.PHONY: help up down down-clean restart logs sync-inventory

# Load environment variables from .env if it exists
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Default target
help:
	@echo "TwinEU Marketplace Backend (Consortium Release)"
	@echo ""
	@echo "Available commands:"
	@echo "  up              Start the Marketplace stack (Detached)"
	@echo "  down            Stop the stack and remove containers (Preserves Data)"
	@echo "  down-clean      Stop the stack and WIPE all volumes (DB and Blockchain state)"
	@echo "  restart         Restart all running containers"
	@echo "  logs            Follow the logs for the backend and blockchain"
	@echo "  sync-inventory  Force sync local DB with the IDSA Federated Catalog"

# ==========================================
# CONSORTIUM DEPLOYMENT OPERATIONS
# ==========================================
up:
	docker compose -f docker-compose.prod.yaml --env-file .env up -d

down:
	docker compose -f docker-compose.prod.yaml down

down-clean:
	@echo "WARNING: This will destroy the Postgres database and Blockchain state."
	docker compose -f docker-compose.prod.yaml down -v

restart:
	docker compose -f docker-compose.prod.yaml restart

logs:
	docker compose -f docker-compose.prod.yaml logs -f backend contract-deployer blockchain

sync-inventory:
	docker exec -it twineu-marketplace-backend python sync_inventory.py