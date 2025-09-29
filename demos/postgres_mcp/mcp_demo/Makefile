.PHONY: help install setup test test-db dev clean clean-all status

help: ## Show this help message
	@echo "MCP PostgreSQL Server"
	@echo "===================="
	@echo ""
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Complete project setup (virtual environment + dependencies)
	@echo "🚀 Setting up MCP PostgreSQL Server..."
	@echo "Creating virtual environment with uv..."
	uv venv
	@echo "Installing dependencies..."
	uv pip install -r requirements.txt
	@echo "✅ Setup complete! Activate with: source venv/bin/activate"

install: ## Install Python dependencies (requires existing venv)
	@echo "📦 Installing dependencies..."
	@if [ ! -d "venv" ]; then echo "❌ Virtual environment not found. Run 'make setup' first."; exit 1; fi
	uv pip install -r requirements.txt
	@echo "✅ Dependencies installed"

test-db: ## Test PostgreSQL database connectivity
	@echo "🔍 Testing database connectivity..."
	@if [ ! -d "venv" ]; then echo "❌ Virtual environment not found. Run 'make setup' first."; exit 1; fi
	uv run python test_db.py

test: ## Test the MCP server
	@echo "🧪 Testing MCP server..."
	@if [ ! -d "venv" ]; then echo "❌ Virtual environment not found. Run 'make setup' first."; exit 1; fi
	@echo "Starting server (press Ctrl+C to stop)..."
	uv run python server.py

clean: ## Clean up generated files
	@echo "🧹 Cleaning up..."
	rm -rf __pycache__
	rm -rf .pytest_cache
	rm -f test_db.py
	find . -name "*.pyc" -delete
	@echo "✅ Cleanup complete"

clean-all: ## Clean up everything including virtual environment
	@echo "🧹 Deep cleaning..."
	rm -rf __pycache__
	rm -rf .pytest_cache
	rm -rf venv
	rm -f test_db.py
	find . -name "*.pyc" -delete
	@echo "✅ Deep cleanup complete"

status: ## Show current status
	@echo "📊 Status:"
	@echo "=========="
	@echo "Working directory: $(shell pwd)"
	@echo "Python version: $(shell python3 --version 2>&1)"
	@echo "uv version: $(shell uv --version 2>&1 || echo "❌ uv not installed")"
	@echo "Virtual environment: $(shell [ -d "venv" ] && echo "✅ venv exists" || echo "❌ missing - run 'make setup'")"
	@echo "Dependencies: $(shell [ -f requirements.txt ] && echo "✅ requirements.txt exists" || echo "❌ missing")"
	@echo "Server file: $(shell [ -f server.py ] && echo "✅ server.py exists" || echo "❌ missing")"
	@if [ -d "venv" ]; then echo "Virtual env Python: $(shell uv run python --version 2>&1)"; fi