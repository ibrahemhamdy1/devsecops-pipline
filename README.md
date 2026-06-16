# Laravel DevSecOps

Production-grade Laravel 11 application with a full GitHub Actions DevSecOps pipeline.
**46 files · 1,002-line pipeline · 14 stages · 0 AWS dependencies**

---

## Push to GitHub (first time)

```bash
# Option A — using the included bundle (offline, no internet needed to clone)
git clone laravel-devsecops.bundle laravel-devsecops
cd laravel-devsecops
git remote add origin https://github.com/YOUR_ORG/YOUR_REPO.git
git push -u origin main

# Option B — using the helper script
chmod +x push-to-github.sh
./push-to-github.sh https://github.com/YOUR_ORG/YOUR_REPO.git
```

---

## Run Locally (requires Docker)

```bash
# 1. Start the stack (app + MySQL 8 + Redis 7 + queue worker + scheduler)
make up

# 2. Test every endpoint
make api-test

# 3. Run tests (inside the running container)
make test

# 4. Run tests in isolated CI mode (no MySQL/Redis needed — SQLite only)
make test-ci
```

---

## API

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/health` | Liveness — `{"status":"ok"}` |
| GET | `/api/health/detailed` | DB + cache health |
| GET | `/api/tasks?status=pending` | List tasks (paginated) |
| POST | `/api/tasks` | Create task |
| GET | `/api/tasks/{id}` | Get task |
| PUT | `/api/tasks/{id}` | Update task |
| DELETE | `/api/tasks/{id}` | Soft delete |

**Create a task:**
```bash
curl -X POST http://localhost:8080/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Ship it","status":"pending","priority":"high"}'
```

---

## Pipeline Stages

```
validate → build → test → sast → sca → quality-gate
→ package → image-security → deploy-dev → smoke
→ staging → integration → deploy-prod → verify
```

| # | Stage | Jobs | Blocks |
|---|---|---|---|
| 1 | Validate | composer validate, Hadolint, helm lint | Yes |
| 2 | Build | composer install + vendor upload | Yes |
| 3 | Test | Pest unit, Pest feature, coverage ≥ 80% | Yes |
| 4 | SAST | PHPStan L8, Pint, Semgrep (PHP+OWASP), Gitleaks | Yes |
| 5 | SCA | composer audit (CVE), license check | Yes |
| 6 | Quality | SonarQube quality gate | Yes |
| 7 | Package | Docker build → push GHCR (provenance + SBOM) | main/tag only |
| 8 | Image Security | Trivy CRITICAL/HIGH, Cosign keyless sign | Yes |
| 9 | Deploy Dev | Helm → dev namespace, DB migrate | Yes |
| 10 | Smoke | health + tasks + detailed health | Yes |
| 11 | Deploy Staging | Helm → staging namespace, DB migrate | Yes |
| 12 | Integration | API tests, OWASP ZAP DAST, k6 load test | Yes |
| 13 | Deploy Prod | **Manual gate** → Helm prod, DB migrate | Yes |
| 14 | Verify | Prod smoke (5 retries), rollback job | Yes |

---

## Required GitHub Secrets

Go to **Settings → Secrets and variables → Actions → Secrets**

| Secret | How to get it |
|---|---|
| `SONAR_TOKEN` | SonarQube → My Account → Security → Generate token |
| `NVD_API_KEY` | https://nvd.nist.gov/developers/request-an-api-key |
| `SNYK_TOKEN` | https://app.snyk.io/account |
| `SEMGREP_APP_TOKEN` | https://semgrep.dev (optional) |
| `GITLEAKS_LICENSE` | Gitleaks Enterprise only — omit for OSS |
| `KUBECONFIG_DEV` | `base64 -w0 ~/.kube/config` (dev cluster) |
| `KUBECONFIG_STAGING` | `base64 -w0 ~/.kube/config` (staging cluster) |
| `KUBECONFIG_PROD` | `base64 -w0 ~/.kube/config` (prod cluster) |
| `DEV_APP_KEY` | `php artisan key:generate --show` |
| `STAGING_APP_KEY` | `php artisan key:generate --show` |
| `PROD_APP_KEY` | `php artisan key:generate --show` |
| `DEV_DB_USERNAME` / `DEV_DB_PASSWORD` | Your dev DB credentials |
| `STAGING_DB_USERNAME` / `STAGING_DB_PASSWORD` | Your staging DB credentials |
| `PROD_DB_USERNAME` / `PROD_DB_PASSWORD` | Your prod DB credentials |
| `STAGING_API_TOKEN` | Bearer token for k6 auth (if your API uses auth) |

## Required GitHub Variables

Go to **Settings → Secrets and variables → Actions → Variables**

| Variable | Example |
|---|---|
| `SONAR_HOST_URL` | `https://sonar.yourdomain.com` |
| `APP_DOMAIN` | `app.yourdomain.com` |
| `DEV_DB_HOST` | `db-dev.internal` |
| `DEV_DB_DATABASE` | `laravel_dev` |
| `STAGING_DB_HOST` | `db-staging.internal` |
| `STAGING_DB_DATABASE` | `laravel_staging` |
| `PROD_DB_HOST` | `db-prod.internal` |
| `PROD_DB_DATABASE` | `laravel_prod` |

## GitHub Environments

Go to **Settings → Environments** and create:

| Environment | Required Reviewers | Notes |
|---|---|---|
| `dev` | None | Auto-deploys on every push to main |
| `staging` | None | Auto-deploys after dev smoke passes |
| `production` | **Add your team** | This is the manual gate — pipeline pauses here |

---

## Stack

| Layer | Technology |
|---|---|
| App | Laravel 11, PHP 8.3 |
| DB (local) | MySQL 8.0 |
| DB (CI) | SQLite in-memory |
| Cache / Queue | Redis 7 |
| Tests | Pest PHP, PHPUnit, Xdebug coverage |
| SAST | PHPStan L8, Laravel Pint, Semgrep, Gitleaks |
| SCA | composer audit, composer-license-checker |
| Quality | SonarQube, JaCoCo-style clover reports |
| Registry | GHCR (GitHub Container Registry) — no cloud account needed |
| Image signing | Cosign keyless (Sigstore/Fulcio) — no private key needed |
| Image scan | Trivy (CRITICAL/HIGH blocking) |
| DAST | OWASP ZAP baseline scan on staging |
| Load test | k6 (p95 < 500ms threshold) |
| Container | Nginx + PHP-FPM via supervisord |
| Orchestration | Helm → any K8s cluster |

---

## Makefile Commands

```bash
make help           # list all commands
make up             # start full docker compose stack
make down           # stop and remove containers
make test           # run tests inside running container
make test-ci        # run tests in isolated container (no services)
make test-coverage  # run tests with coverage report
make analyse        # PHPStan level 8
make format         # fix code style with Pint
make format-check   # check style without fixing
make audit          # composer security audit
make build          # build production Docker image locally
make migrate        # run migrations
make migrate-fresh  # drop all + migrate + seed
make seed           # seed database
make api-test       # quick curl tests against localhost:8080
make shell          # open shell in app container
make logs           # tail app logs
```
