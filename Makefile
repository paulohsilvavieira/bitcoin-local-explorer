.DEFAULT_GOAL := help

COMPOSE := docker compose -f docker-compose.yml -f docker-compose.local.yml --env-file local.env

.PHONY: help up down stop restart-node logs ps config reset

help: ## Lista os comandos disponíveis
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

up: ## Builda e sobe a stack local (explorer em http://localhost:9001)
	$(COMPOSE) up -d --build

down: ## Para e remove os containers, preservando os volumes (chain + índice)
	$(COMPOSE) down

stop: ## Só para os containers, sem remover nada
	$(COMPOSE) stop

restart-node: ## Recria o serviço bitcoin-node (usar depois de mudar MINING_INTERVAL/TX_*)
	$(COMPOSE) up -d bitcoin-node

logs: ## Segue os logs de todos os serviços
	$(COMPOSE) logs -f

ps: ## Lista o status dos containers
	$(COMPOSE) ps

config: ## Valida o docker-compose.yml + override local
	$(COMPOSE) config -q && echo "config OK"

reset: ## Apaga TUDO: containers e volumes (chain e índice perdidos, sem volta)
	@echo "Isso apaga bitcoin-data e electrs-data. Ctrl+C pra cancelar, Enter pra confirmar."
	@read _
	$(COMPOSE) down -v
