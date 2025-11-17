.PHONY: all setup env test clean demo airbyte mindsdb stop

# Default target
all: setup

# Setup environment
setup: env
	@echo "Setup complete. Activate the virtual environment with 'source .venv/bin/activate'"

# Create virtual environment and install dependencies
env: .venv/bin/activate
.venv/bin/activate: requirements.txt
	python3 -m venv .venv
	./.venv/bin/pip install -r requirements.txt
	touch .venv/bin/activate

# Run tests
test:
	export PGPASSWORD=inventory; ./.venv/bin/python -m pytest -q -sv

# Run only the Airbyte sync demo (Postgres + data load)
airbyte:
	@echo "Starting Postgres (postgres-inv)..."
	docker compose up --build -d postgres-inv
	@echo "Waiting for Postgres to report ready..."
	@until docker compose exec -T postgres-inv pg_isready -U postgres >/dev/null 2>&1; do sleep 1; done
	@echo "Running the Google Drive → Postgres sync..."
	docker compose run --rm app python demo.py
	@echo "Sync complete. Postgres remains up so you can inspect the data."

# Start MindsDB and link it to the Postgres inventory database
mindsdb:
	@echo "Starting Postgres and MindsDB services..."
	docker compose up --build -d postgres-inv mindsdb
	@echo "Waiting a moment for services to boot..."
	@sleep 5
	@echo "Configuring MindsDB to use the Postgres inventory data..."
	docker compose run --rm app python src/setup_mindsdb.py
	@echo "MindsDB is ready. Connect via http://localhost:47334 or the MySQL API on 47335."

# Clean up
clean:
	@echo "Cleaning up..."
	docker compose down 
	rm -rf .venv
	rm -rf .pytest_cache
	find . -type d -name "__pycache__" -exec rm -r {} +
	@echo "Cleanup complete."

# Run the full demo application
demo: airbyte

# Stop all services
stop:
	@echo "Stopping all services..."
	docker compose down
