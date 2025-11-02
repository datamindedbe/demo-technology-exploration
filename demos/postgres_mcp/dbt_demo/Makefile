.PHONY: help install deps run test docs clean

help: ## Show this help message
	@echo "Employee Analytics DBT Project"
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Install DBT and dependencies
	uv venv venv
	uv pip install -r requirements.txt --python venv/bin/python

deps: ## Install DBT packages
	cd dbt && ../venv/bin/dbt deps

run: ## Run all DBT models
	cd dbt && ../venv/bin/dbt run

test: ## Run all DBT tests
	cd dbt && ../venv/bin/dbt test

docs: ## Generate and serve DBT documentation
	cd dbt && ../venv/bin/dbt docs generate && ../venv/bin/dbt docs serve

clean: ## Clean DBT artifacts
	cd dbt && ../venv/bin/dbt clean

run-staging: ## Run only staging models
	cd dbt && ../venv/bin/dbt run --models staging

run-intermediate: ## Run intermediate models
	cd dbt && ../venv/bin/dbt run --models intermediate

run-marts: ## Run mart models
	cd dbt && ../venv/bin/dbt run --models marts

full-refresh: ## Run with full refresh
	cd dbt && ../venv/bin/dbt run --full-refresh

compile: ## Compile DBT models
	cd dbt && ../venv/bin/dbt compile

parse: ## Parse DBT project
	cd dbt && ../venv/bin/dbt parse

seed: ## Run DBT seeds
	@echo "Creating database if it doesn't exist..."
	@cd .. && docker-compose exec -T postgres psql -U user -d postgres -c "CREATE DATABASE employee_db;" 2>/dev/null || true
	@echo "Running DBT seeds..."
	cd dbt && ../venv/bin/dbt seed

snapshot: ## Run DBT snapshots
	cd dbt && ../venv/bin/dbt snapshot

lint: ## Lint SQL files (requires sqlfluff)
	sqlfluff lint dbt/models/

format: ## Format SQL files (requires sqlfluff)
	sqlfluff fix dbt/models/
