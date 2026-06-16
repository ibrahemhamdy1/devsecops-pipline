# ============================================================
# Makefile — Laravel DevSecOps
# ============================================================

.PHONY: help up down install test test-coverage analyse format build shell migrate seed logs

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

##── Local Dev (docker compose) ──────────────────────────────

up: ## Start full stack (app + MySQL + Redis)
	docker compose up -d --build
	@echo "Waiting for app to be healthy..."
	@sleep 5
	docker compose exec app php artisan migrate --seed
	@echo ""
	@echo "App running at: http://localhost:8080"
	@echo "API health:     http://localhost:8080/api/health"
	@echo "Tasks API:      http://localhost:8080/api/tasks"

down: ## Stop all containers
	docker compose down -v

logs: ## Tail app logs
	docker compose logs -f app

shell: ## Open shell in app container
	docker compose exec app sh

##── Dependencies ─────────────────────────────────────────────

install: ## Install PHP dependencies
	docker compose exec app composer install

##── Testing ──────────────────────────────────────────────────

test: ## Run full test suite
	docker compose exec app php artisan test

test-unit: ## Run unit tests only
	docker compose exec app php artisan test --testsuite=Unit

test-feature: ## Run feature tests only
	docker compose exec app php artisan test --testsuite=Feature

test-coverage: ## Run tests with coverage (requires Xdebug)
	docker compose exec -e XDEBUG_MODE=coverage app php artisan test --coverage --min=80

test-ci: ## Run tests in isolated CI container (SQLite only, no docker compose needed)
	docker build -f Dockerfile.test -t laravel-test .
	docker run --rm \
		-e APP_ENV=testing \
		-e APP_KEY=base64:aSampleKeyFor32CharsExactlyHere= \
		-e DB_CONNECTION=sqlite \
		-e DB_DATABASE=":memory:" \
		-e CACHE_STORE=array \
		-e SESSION_DRIVER=array \
		-e QUEUE_CONNECTION=sync \
		laravel-test \
		sh -c "composer install --no-interaction && php artisan test"

##── Static Analysis ──────────────────────────────────────────

analyse: ## Run PHPStan analysis
	docker compose exec app vendor/bin/phpstan analyse --no-progress

format: ## Fix code style with Pint
	docker compose exec app vendor/bin/pint

format-check: ## Check code style without fixing
	docker compose exec app vendor/bin/pint --test

audit: ## Run composer security audit
	docker compose exec app composer audit

##── Database ─────────────────────────────────────────────────

migrate: ## Run database migrations
	docker compose exec app php artisan migrate

migrate-fresh: ## Drop all tables and re-run migrations
	docker compose exec app php artisan migrate:fresh --seed

seed: ## Seed the database
	docker compose exec app php artisan db:seed

##── Build ────────────────────────────────────────────────────

build: ## Build production Docker image
	docker build \
		--target production \
		--build-arg VCS_REF=$$(git rev-parse --short HEAD) \
		--build-arg BUILD_DATE=$$(date -u +%Y-%m-%dT%H:%M:%SZ) \
		-t laravel-devsecops:local \
		.

##── API Quick Tests ──────────────────────────────────────────

api-test: ## Quick curl tests against local stack
	@echo "=== Health ==="
	@curl -s http://localhost:8080/api/health | python3 -m json.tool
	@echo "\n=== Create Task ==="
	@curl -s -X POST http://localhost:8080/api/tasks \
		-H "Content-Type: application/json" \
		-d '{"title":"Test via Makefile","status":"pending","priority":"high"}' \
		| python3 -m json.tool
	@echo "\n=== List Tasks ==="
	@curl -s http://localhost:8080/api/tasks | python3 -m json.tool
