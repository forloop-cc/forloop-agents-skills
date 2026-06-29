---
name: tech-stack-default
description: >
  Default development and deployment tech stack for all ForLoop projects.
  Loaded automatically during planning sessions. Agent assumes this stack
  unless explicitly told otherwise by the user.
  DO NOT ask users to confirm tech stack during planning — assume these defaults.
license: MIT
metadata:
  version: "1.0.0"
  category: planning
  sources:
    - ForLoop project-base template
---

# ForLoop Default Tech Stack

## Overview

All ForLoop projects use this standardized tech stack. When planning stories, assume these technologies — do not ask users to confirm or choose alternatives unless they explicitly state a different requirement.

## Project Repository

When a sprint is created with a project name, a GitHub repository is **automatically created** by the ForLoop platform. The repo is seeded with the ForLoop project-base template (`.forloop/template/`), which includes the full frontend, backend, infrastructure, and CI/CD scaffolding.

### Repository Naming Convention

```
sprint-{sprint_id}-project-{project-name}
```

**Example:** Sprint #14 with project name "abc" creates repo:
```
sprint-14-project-abc
```

### What's Included (from project-base template)

| Directory | Contents |
|-----------|----------|
| `frontend/` | React + Vite SPA with TypeScript, TailwindCSS, React Router |
| `backend/` | Lambda Docker container (Express + MVC + TypeScript) with DynamoDB |
| `infra/` | Terraform modules for backend, frontend assets, and ECR repository |
| `scripts/` | Deployment helper scripts (bash) |
| `config/` | Project and tenant configuration files |
| `.github/workflows/` | CI/CD pipelines (lint, test, deploy, release) |
| `forloop.json` | ForLoop project metadata (projectName, sprintId, organizationId, flEnv) |
| `Makefile` | Developer convenience commands |
| `.env.example` | Environment variable template |

### What This Means for Planning

- **Do NOT plan repo creation** — it happens automatically when the sprint is created
- **Do NOT ask users "where is the repo?"** — it's at `github.com/.../sprint-{id}-project-{name}`
- **Do NOT plan GitHub Actions setup** — CI/CD workflows are pre-baked
- **Do NOT plan project scaffolding** — frontend, backend, and infra are ready to use
- **Stories should focus on building features** on top of the existing scaffolding, not setting up the project

### Pre-Configured Features

The template repo comes with:
- ✅ Frontend with `/`, `/health`, `/users` routes
- ✅ Backend with Express MVC architecture, health check and users CRUD endpoint
- ✅ DynamoDB single-table design ready
- ✅ API Gateway HTTP API with catch-all routing
- ✅ Docker container image for Lambda deployment
- ✅ ECR repository managed via Terraform
- ✅ Terraform infrastructure modules
- ✅ GitHub Actions CI/CD (lint, test, Docker build, deploy, release)
- ✅ OIDC authentication to AWS
- ✅ CloudFront + S3 frontend hosting
- ✅ Makefile for common commands (`make dev`, `make build`, `make test`, `make deploy`)

## Story Templates

When creating stories in ForLoop, always use templates. Templates ensure consistent structure, proper metadata, and correct canvas rendering. Stories have a `templateId` field linking to the Template table.

### Available Templates

#### `basic-task` (Template Slug: `basic-task`)

**Story Type:** `task`

**When to use:** ALL implementation tasks created from plan breakdown. This includes features, bug fixes, refactoring, deployment, CI/CD, testing, and any work that requires code changes.

**Fields defined by this template:**

| Field ID | Label | Type | Component | Required | Notes |
|----------|-------|------|-----------|----------|-------|
| `taskTitle` | Task Title | short-text | input | Yes | Story title |
| `description` | Description | long-text | textarea | Yes | Story description with acceptance criteria |
| `assignee` | Assignee | user-select | dropdown | No | Assigned user |
| `status` | Status | select | dropdown | No | `todo`, `in_progress`, `done`, `blocked` |
| `priority` | Priority | select | dropdown | No | `low`, `medium`, `high`, `critical` |
| `points` | Points | range | slider | No | Integer 0-10 |
| `dueDate` | Due Date | date | datepicker | No | Optional deadline |
| `tags` | Tags | multi-select | tag-input | No | Labels for categorization |

**Usage:**
```
forloopStoryTemplate(
  templateSlug=basic-task,
  taskTitle="Implement user registration API",
  description="As a user, I want to register via email...",
  sprintId=14,
  priority=high,
  points=5,
  assigneeAgentKey=forLoopDeveloper
)
```

#### `basic-note` (Template Slug: `basic-note`)

**Story Type:** `story`

**When to use:** Documentation items, research notes, planning artifacts, and non-implementation stories. NOT for task breakdown from plans.

**Fields defined by this template:**

| Field ID | Label | Type | Component | Required | Notes |
|----------|-------|------|-----------|----------|-------|
| `taskTitle` | Note Title | short-text | input | Yes | Story title |
| `description` | Description | long-text | textarea | Yes | Note content |

**Usage:**
```
forloopStoryTemplate(
  templateSlug=basic-note,
  taskTitle="Document API design decisions",
  description="Record the decisions made about...",
  sprintId=14,
  priority=medium,
  points=2
)
```

### Template Selection Rules

| Scenario | Template Slug |
|----------|---------------|
| Breaking down a plan into tasks | `basic-task` |
| Feature implementation | `basic-task` |
| Bug fix | `basic-task` |
| Refactoring | `basic-task` |
| Deployment/infrastructure | `basic-task` |
| CI/CD pipeline work | `basic-task` |
| Testing tasks | `basic-task` |
| Planning/breakdown tasks | `basic-task` |
| Standalone research note | `basic-note` |
| Documentation (not from plan) | `basic-note` |

### Task Creation Rule

**ALL task stories created from plan breakdown MUST use `templateSlug=basic-task`.** This is not optional. The `basic-task` template provides the full field set needed for implementation work: status tracking, priority, points, assignee, due date, and tags.

### Story Fields (API Schema)

When creating stories via the API (`POST /api/opencode/stories`), these fields are available:

| Field | Type | Required | Default | Notes |
|-------|------|----------|---------|-------|
| `title` | string | Yes | - | Story title |
| `description` | string | No | null | Story description |
| `sprintId` | number | Yes | - | Target sprint ID |
| `type` | enum | No | `story` | `story`, `task`, `bug`, `doc_folder` |
| `priority` | enum | No | `medium` | `low`, `medium`, `high`, `critical` |
| `points` | number | No | null | Integer 0-10 |
| `status` | enum | No | `todo` | `todo`, `in_progress`, `done`, `blocked` |
| `templateId` | number | No | null | FK to Template table |
| `assigneeType` | enum | No | `user` | `user` or `agent` |
| `assigneeAgentKey` | string | No | null | Required when `assigneeType=agent` |
| `metadata` | object | No | null | Template field values as JSON |

## Frontend

| Layer | Technology | Version |
|-------|-----------|---------|
| Framework | React + TypeScript | 18.x |
| Build Tool | Vite | 5.x |
| Routing | React Router DOM | 6.x |
| Styling | TailwindCSS + PostCSS | 3.x |
| Testing | Vitest | 1.x |
| API Client | Custom `fetch()` wrapper (`api-client.ts`) | - |
| Path Alias | `@` → `./src` | - |

### Frontend Architecture

- **Folder structure**: `src/components/`, `src/pages/`, `src/hooks/`, `src/lib/`, `src/types/`, `src/styles/`
- **API communication**: `useApi<T>(path)` generic hook + domain-specific hooks (e.g., `useUsers()`)
- **Config**: `lib/config.ts` resolves Vite env vars, computes API base URL
- **Layout**: Wrapper component with header/footer
- **Build**: `tsc + vite build` → outputs to `dist/`
- **Assets**: Hashed filenames for cache-busting

### Frontend Gotchas

- Vite env vars use `VITE_*` prefix (e.g., `VITE_API_BASE_URL`)
- `@` path alias maps to `./src`
- TailwindCSS configured via `postcss.config.js`
- Dev server proxies API to backend for local development

## Backend

| Layer | Technology | Version |
|-------|-----------|---------|
| Runtime | AWS Lambda (Docker container) | Node.js 20.x |
| Framework | Express.js | 4.x |
| Serverless Adapter | @codegenie/serverless-express | 4.x |
| Database | DynamoDB | - |
| ORM | dynamodb-onetable | 2.x |
| Container | AWS ECR (per project) | - |
| Testing | Jest + ts-jest + supertest | 29.x |
| Types | @types/aws-lambda, @types/express | - |

### Backend Architecture

- **Single Lambda function** handles ALL routes via Express.js — no per-route Lambdas
- **MVC pattern**: `routes/` → `controllers/` → `services/` → `models/`
- **Entry point**: `src/lambda.ts` — wraps Express app via serverless-express for Lambda
- **App setup**: `src/app.ts` — Express app with CORS, JSON parsing, route registration, error handling
- **API Gateway**: HTTP API (v2) with catch-all routes `ANY /{env}/{project}/{proxy+}`
- **Database**: Single-table DynamoDB design with `pk`/`sk` pattern
- **Models**: `dynamodb-onetable` with ULID auto-generation, `#` separator
- **Container**: Multi-stage Dockerfile (Node 20 Alpine build → Lambda runtime image)
- **Build**: `tsc` compiles TypeScript to `dist/` — Docker builds the container image

### Backend Folder Structure

```
backend/
├── Dockerfile              # Lambda container image (multi-stage)
├── .dockerignore
├── src/
│   ├── lambda.ts           # Lambda handler entry point
│   ├── app.ts              # Express app + serverless adapter
│   ├── routes/             # API route definitions
│   ├── controllers/        # Request handlers
│   ├── services/           # Business logic (DB, external APIs)
│   ├── models/             # Data models and DynamoDB schemas
│   ├── middleware/         # Auth, validation, error handling
│   ├── config/             # Environment configuration
│   └── types/              # TypeScript type definitions
└── package.json
```

### Backend Gotchas

- Runtime env vars: `TENANT_ID`, `PROJECT_ID`, `ENV`, `AWS_REGION`
- DynamoDB table name: `fl-{TENANT_ID}-{PROJECT_ID}-{ENV}`
- OneTable model uses `pk`/`sk` with `#` separator (e.g., `user#${id}`)
- Lambda name does NOT have `-api` suffix: `fl-{tenant}-{project}-{env}`
- Structured JSON logger in `lib/logger.ts`
- ECR repository: `fl-{account_id}-{tenant}-{project}` (managed by Terraform)
- Image tags: `{env}-{commit-sha}`
- Terraform `ignore_changes = [image_uri]` on Lambda — CI updates image outside Terraform

## Infrastructure

| Layer | Technology | Version |
|-------|-----------|---------|
| IaC | Terraform | >= 1.6 |
| Cloud | AWS Provider | >= 5.0 |
| State | S3 backend | - |

### Terraform Architecture

- **State**: S3 remote state, keyed by `project/{env}/{project}/terraform.tfstate`
- **Remote state data source**: Reads tenant baseline outputs (API Gateway ID, bucket names)
- **Conditional deployment**: `count = var.deploy_* ? 1 : 0` — checks if resources exist first
- **Naming convention**: `fl-{tenant}-{project}-{env}` for Lambda, DynamoDB, IAM
- **Tagging**: `ForLoopTenantId`, `ForLoopProjectId`, `ForLoopEnv`, `ForLoopMode`, `ManagedBy`

### Modules

| Module | Creates |
|--------|---------|
| `project-backend` | ECR repo, Lambda (Docker image), DynamoDB, CloudWatch log group, API Gateway v2 routes, Lambda permission, IAM role, ECR lifecycle policy |
| `project-frontend-assets` | Uploads frontend dist files to S3 with MIME types and AES256 encryption |

### IAM

- Lambda execution role with CloudWatch Logs and DynamoDB access policies
- Role naming: `fl-{tenant}-{project}-{env}-lambda-role`
- ECR permissions: `ecr:*` on `arn:aws:ecr:*:*:repository/fl-*` (create, push, pull, lifecycle)
- Tenant deploy role (StackSet): includes ECR repo management and image push/pull permissions

## Available AWS Services

ForLoop projects have access to a **curated set of AWS services**. The tenant deploy role is scoped to these services only — do NOT plan stories that require services outside this list.

### Available (Project-Level)

| Service | Capabilities | Resource Scope |
|---------|-------------|----------------|
| **S3** | Read/write/delete objects, list buckets | `fl-*` buckets |
| **CloudFront** | Create invalidations, read distribution config | Pre-provisioned distribution |
| **Lambda** | Create/update/delete functions, manage permissions, tags | `fl-*` functions only |
| **DynamoDB** | Create/update/delete tables, manage backups, TTL | `fl-*` tables only |
| **API Gateway v2** | Manage integrations and routes on existing HTTP APIs | Existing APIs only |
| **CloudWatch Logs** | Create/delete log groups, set retention, tags | All log groups |
| **SSM Parameter Store** | Create/read/delete parameters (SecureString, String) | `fl-*` parameters only |
| **IAM** | Create/manage Lambda execution roles | `fl-*-lambda-role` only |
| **ECR** | Create/delete repositories, push/pull images, lifecycle policies | `fl-*` repositories only |

### Available (Baseline — Pre-Provisioned by Control Plane)

These services are **already provisioned** when an organization is created. Projects consume them but do NOT create or manage them:

| Service | Role |
|---------|------|
| **Route53** | DNS hosted zones (e.g., `{tenant}.forloop.cc`, `api.{tenant}.forloop.cc`) |
| **ACM** | SSL/TLS certificates for CloudFront and API Gateway domains |
| **CloudFront** | Distributions per tenant (dev/prd) |
| **S3** | Frontend buckets (`fl-{account}-{tenant}-frontend-{env}`) |
| **API Gateway** | HTTP API with custom domain names |
| **IAM** | Deploy roles via StackSet |

### NOT Available

Do NOT plan stories requiring these services — they are **not** available to tenant projects:

| Service | Reason |
|---------|--------|
| VPC, EC2, ECS, EKS | Serverless-only platform |
| RDS, ElastiCache | Use DynamoDB |
| SNS, SQS, EventBridge, Step Functions | Use Lambda direct invocation |
| KMS | SSM uses AWS-managed encryption |
| SES, SNS | Not provisioned |
| S3 bucket creation | Buckets are pre-provisioned by baseline |
| API Gateway creation | HTTP API is pre-provisioned by baseline |
| Route53 record creation | DNS managed by Control Plane |
| ACM certificate creation | Certs managed by Control Plane |

### Planning Rule

**When planning backend or infrastructure stories, only use services from the "Available" list.** If a user requests functionality that requires an unavailable service, suggest an alternative using available services (e.g., DynamoDB Streams instead of SQS, SSM instead of KMS for secrets, Lambda direct invocation instead of Step Functions).

## Multi-Tenancy

| Mode | Frontend URL | API URL | S3 Path |
|------|-------------|---------|---------|
| **tenant** (dedicated) | `https://{project}.{tenant}.forloop.cc` | `https://api.{tenant}.forloop.cc/{env}/{project}/*` | `{env}/{project}/` |
| **shared** (system) | `https://{tenant}--{project}[-dev].system.forloop.cc` | `https://api.system.forloop.cc/{env}/{tenant}/{project}/*` | `{env}/{tenant}/{project}/` |

### Naming Conventions

| Resource | Pattern |
|----------|---------|
| Lambda | `fl-{tenant}-{project}-{env}` |
| DynamoDB table | `fl-{tenant}-{project}-{env}` |
| ECR repository | `fl-{account-id}-{tenant}-{project}` |
| S3 bucket (frontend) | `fl-{account-id}-{tenant}-frontend-{env}` |
| IAM role | `fl-{tenant}-{project}-{env}-lambda-role` |

## CI/CD

| Layer | Technology |
|-------|-----------|
| Platform | GitHub Actions |
| Auth | GitHub OIDC → AWS IAM role assumption (chained: control-plane → tenant role) |
| OIDC audience | `forloop-deploy` |
| Triggers | Commit message parsing: `[deploy frontend]`, `[deploy backend]`, `[deploy all]`, `[skip deploy]` |
| Environment | `main` branch → `prd`, all other branches → `dev` |

### Deploy Pipeline

1. Commit message parsed for `[deploy <resource>]` tag
2. Environment detected from branch name
3. OIDC token minted, deploy config fetched from ForLoop broker
4. Chained AWS role assumption (control-plane → tenant)
5. **Frontend**: Build with Vite env vars → sync to S3 (immutable assets + no-cache index.html) → CloudFront invalidation → health check
6. **Backend**: Terraform apply (creates ECR repo + Lambda shell) → Docker build → push to ECR → `aws lambda update-function-code --image-uri` → health check
7. PR deployment notifications sent to ForLoop server

### Frontend Deploy Cache Strategy

- **Assets** (`*.js`, `*.css`, images): `Cache-Control: max-age=31536000,immutable`
- **index.html**: `Cache-Control: no-cache,no-store,must-revalidate`

### Backend Deploy

The backend deploys as a Docker container image to AWS Lambda via ECR:

1. **Terraform**: Creates ECR repository (`fl-{account}-{tenant}-{project}`) and Lambda function (empty `image_uri`)
2. **Docker build**: `docker build -t {ECR_URI} backend/`
3. **Push**: `docker push {ECR_URI}`
4. **Update Lambda**: `aws lambda update-function-code --function-name fl-{tenant}-{project}-{env} --image-uri {ECR_URI}`

ECR lifecycle policy retains the last 10 images per environment. Lambda has `ignore_changes = [image_uri]` so CI updates don't cause Terraform drift.

## Development Workflow

### Makefile Commands

| Command | Description |
|---------|-------------|
| `make install` | Install all dependencies (frontend + backend) |
| `make build` | Build all (frontend + backend) |
| `make dev` | Start frontend dev server with API proxy |
| `make test` | Run all tests (frontend vitest + backend jest) |
| `make lint` | Run ESLint on frontend and backend |
| `make typecheck` | Run TypeScript type checks |
| `make deploy` | Deploy to tenant (frontend + backend) |
| `make clean` | Remove build artifacts |

### Environment Variables

**Build time (Vite):**
- `VITE_API_BASE_URL` — Backend API URL
- `VITE_*` — Any custom frontend config

**Runtime (Lambda):**
- `TENANT_ID` — Tenant identifier
- `PROJECT_ID` — Project identifier
- `ENV` — Environment (`dev` or `prd`)
- `AWS_REGION` — AWS region (default: `ap-southeast-1`)

### Local Development

```bash
# Frontend dev server (proxies API to backend)
cd frontend && npm run dev

# Backend local testing (requires AWS credentials)
cd backend && npm test
```

## Story Planning Guidelines

When creating stories for this stack, follow these patterns:

### Frontend Stories

- Component creation with TypeScript interfaces
- Custom hooks for API integration
- TailwindCSS styling (no CSS-in-JS)
- Vitest tests for hooks and config
- Route additions via React Router

### Backend Stories

- Express routes in `src/routes/` (route registration)
- Controllers in `src/controllers/` (request handling, validation)
- Services in `src/services/` (business logic, DB operations)
- Models in `src/models/` (DynamoDB schemas via `dynamodb-onetable`)
- Middleware in `src/middleware/` (auth, validation, error handling)
- Jest + supertest tests for controllers and services
- Structured logging for all operations
- Docker image deployment via ECR (CI/CD handles this automatically)

### Infrastructure Stories

- Terraform module additions/changes
- IAM policy updates
- DynamoDB table/index changes
- API Gateway route updates

### Deployment Stories

- CI/CD workflow changes (GitHub Actions)
- Deploy script modifications
- CloudFront configuration
- Environment variable additions
- ECR lifecycle policy changes

## Development Team

ForLoop provides 5 AI agents for implementing stories. All agents are dispatched by the forLoopTaskSupervisor. Four agents follow a sequential code pipeline; the Creator follows a different workflow (file generation → commit → auto-deploy).

### Pipeline Overview

```
Code pipeline (Phase 1 → Phase 2 per-story, then batch Phase 3 → Phase 4):
  forLoopDeveloper (code + TDD + lint + commit)
    → forLoopTester (local validation: lint, typecheck, unit tests, lambda compat, E2E stubs)

After ALL stories pass Phase 2:
  forLoopDevops (batched deploy via [deploy] tag → GitHub Actions)
    → forLoopTester (post-deploy E2E verification against live endpoints)

File generation workflow (dispatched by Supervisor, no pipeline phases):
  forLoopCreator (generate files → commit to frontend/public/ → auto-deploy via Vite → CI/CD)
    → Developer agent uses files for integration (e.g., <img src="/images/logo.svg" />)
```

Creator can be dispatched before, after, or alongside code pipeline stories. Creator stories complete when files are generated, committed, and auto-deployed via Vite → CI/CD. They do not go through Phase 2 (local validation) or Phase 3-4 (deploy + E2E) because they produce static assets, not application code.

---

### forLoopDeveloper — Code Implementation

**Capabilities:**
- Backend: Lambda + Express + DynamoDB (serverless-http adapter, MVC pattern)
- Frontend: React/Vite SPA → S3 + CloudFront (TypeScript, TailwindCSS, React Router)
- Full TDD cycle: Red → Green → Refactor with Jest (backend) or Vitest (frontend)
- Multi-tenant deployment: shared (system org) or dedicated (tenant account)

**Workflow:**
1. Fetch story context (requirements, acceptance criteria, attachments)
2. Study templates (`backend/README.md`, `frontend/README.md`, `KNOWLEDGE.md`)
3. Copy template files if missing, install deps
4. TDD: write failing test → implement → refactor (80%+ coverage)
5. Run lint + typecheck on both backend and frontend
6. Create E2E test stub at `tests/e2e/story_{storyId}.spec.ts` (Playwright, pipeline-only)
7. Commit with plain message (NO `[deploy]` or `[e2e]` tags)
8. Report to supervisor with file list, test results, commit SHA

**Output:**
- Source files under `backend/src/` (routes, controllers, services, models, middleware)
- Source files under `frontend/src/` (components, pages, hooks, lib)
- Test files (Jest for backend, Vitest for frontend)
- E2E stubs at `tests/e2e/story_{storyId}.spec.ts`

**Constraints:**
- Never adds `[deploy]`, `[e2e]`, `[teardown]`, `[debug]`, or `[rollback]` tags to commits
- Lambda-compatible only (stateless, cold-start friendly, max 50MB zipped)
- Static frontend only (no SSR unless Lambda@Edge)
- Does not mark stories COMPLETED — supervisor does after Phase 2 validation
- Does not create PRs or merge

**Assign when:** Story title includes: implement, develop, build, feature, bug fix, refactor, API, endpoint, component, page, hook, route

---

### forLoopTester — Quality Assurance

**Capabilities:**
- **Phase 2 (per-story, local):** Lint, typecheck, unit tests, Lambda compatibility scan, E2E stub filling
- **Phase 4 (batched, post-deploy):** Download E2E artifacts from GitHub Actions, smoke tests, failure classification
- Fix infrastructure issues directly (imports, mocks, ESLint); escalate business logic bugs to supervisor
- API contract test entries for `tests/api/test-manifest.json`

**Workflow (Phase 2):**
1. Read `KNOWLEDGE.md`
2. Run lint + typecheck (backend + frontend)
3. Run unit tests (Jest + Vitest)
4. Lambda compatibility scan (native modules, handler path, filesystem writes)
5. Fill E2E test stubs with real assertions from acceptance criteria
6. Fill API contract tests in `tests/api/test-manifest.json`
7. Fix issues — max 3 rounds, then report FAIL

**Workflow (Phase 4):**
1. Receive DevOps deployment report (endpoints, pipeline URLs)
2. Smoke test endpoints (curl + lambdaInvoke)
3. Download E2E artifacts from GitHub Actions run
4. Classify failures (502/503 → infra, 403/401 → auth, assertion mismatch → code)
5. Fix code bugs directly; delegate infra issues to DevOps
6. Max 2 re-verify loops

**Output:**
- Phase 2: `{ validationResult: "PASS" | "FAIL", checks: { lint, typecheck, unitTests, lambdaCompat, e2eStubs } }`
- Phase 4: `{ verdict: "PASS" | "FAIL", testsRun, testsPassed, remainingFailures }`

**Constraints:**
- No Playwright in Lambda — E2E tests run in GitHub Actions pipeline only
- Never constructs URLs — uses exact endpoints from DevOps report
- Max 3 Phase 2 fix rounds, max 2 Phase 4 re-verify loops

**Assign when:** Story title includes: test, testing, QA, validate, validation, lint, typecheck, spec, coverage, assertion, E2E

---

### forLoopDevops — Deployment & Infrastructure

**Capabilities:**
- **Phase 3 (batched deploy):** Commit with `[deploy frontend]`/`[deploy backend]`/`[deploy all]` tag → GitHub Actions pipeline → monitor → report endpoints
- **E2E triggering:** Commit with `[e2e backend]`/`[e2e frontend]`/`[e2e story]`/`[e2e all]` tag
- **Teardown:** Commit with `[teardown frontend]`/`[teardown backend]`/`[teardown all]` tag (requires sprintId)
- **Rollback:** `[rollback last]`, `[rollback sprint N]`, `[rollback story N]`, `[rollback infra]`
- **Debug:** `[debug]`, `[debug logs]`, `[debug teardown]` — diagnostics without deployment

**Workflow:**
1. Read pipeline docs (`KNOWLEDGE.md`, `deploy.yml`)
2. Copy missing template files (`.github/`, `infra/`, `scripts/`)
3. Build locally (`npm install && npm run build`)
4. Commit with appropriate `[deploy]` tag — this IS the deployment
5. Monitor pipeline: `ghRunList` → `ghRunWatch`
6. On failure: classify (build-error, test-error, terraform-error, lambda-health, frontend-health, ecr-error), fix, recommit — max 3 retries
7. After deploy success: commit `[e2e ...]` tag to trigger E2E verification — max 2 E2E retries
8. Report pipeline URLs + resource URLs to supervisor

**Output:**
```json
{ "status": "SUCCESS", "pipelineUrl": "...", "e2ePipelineUrl": "...",
  "environment": "dev", "resources": { "frontendUrl": "...", "apiUrl": "..." } }
```

**Constraints:**
- Commit IS deploy — no CLI tools (`curl`, `gh api`, `terraform apply`, `aws s3 cp`)
- Only agent authorized to add `[deploy]`, `[e2e]`, `[teardown]`, `[debug]`, `[rollback]` tags
- Environment derived from branch: `main` → `prd`, everything else → `dev`
- Never modifies `.github/workflows/` or `scripts/`
- Teardown only when `FORLOOP_SPRINT_ID` is set and scoped to current sprint's project

**Assign when:** Story title includes: deploy, deployment, AWS, infrastructure, CI/CD, pipeline, secrets, environment, release, terraform, cloudformation, S3, CloudFront, DynamoDB, IAM, teardown, rollback

---

### forLoopCreator — File & Media Generation

**Dispatched by Supervisor, follows a different workflow from the code pipeline.** Creator completes when files are generated, committed, and auto-deployed via `frontend/public/` → Vite → CI/CD. Its output is then used by the Developer agent for frontend integration. Creator does not go through Phase 2 (local validation) or Phase 3-4 (deploy + E2E) because it generates static assets, not application code.

**Capabilities:**

| File Type | Skill Used | Tech | Output Format |
|-----------|-----------|------|---------------|
| Documents (.docx) | `minimax-docx` | OpenXML SDK (.NET), C# | Editable Word documents |
| PDFs | `minimax-pdf` | ReportLab, Playwright | Print-ready PDFs |
| Spreadsheets (.xlsx) | `minimax-xlsx` | XML unpack/edit/pack, Python | Excel spreadsheets |
| Presentations (.pptx) | `pptx-generator` | PptxGenJS | Slide decks |
| Music / Audio (.mp3) | `mmx-cli` | MiniMax API | Audio tracks, playlists |
| Images (.png) | `mmx-cli` | MiniMax API | Generated artwork, album covers |
| Video (.mp4) | `mmx-cli` | MiniMax API | Generated video |
| Speech / TTS | `mmx-cli` | MiniMax API | Voice narration |
| Stickers / GIFs | `gif-sticker-maker` | MiniMax image+video API | Animated stickers |
| Text / Chat | `mmx-cli` | MiniMax API | Text generation |
| Web Search | `mmx-cli` | MiniMax API | Search results |

**Workflow:**
1. Load the appropriate skill based on file type (MANDATORY — never generate without skill)
2. Check prerequisites (mmx CLI, .NET SDK, Python packages, ffmpeg)
3. Fetch story context (requirements, acceptance criteria)
4. Generate files — place ALL under `{repoPath}/frontend/public/`
5. Run quality gates (file opens without errors, content matches requirements, no placeholders)
6. Commit generated files with `githubCommit`
7. Return structured JSON report with file paths, types, and integration instructions
8. Post story comment with artifacts list

**File Placement (CRITICAL):**

| File Type | Directory under `frontend/public/` | Served at |
|-----------|----------------------------------|-----------|
| Documents (.docx, .pdf) | `documents/` | `/documents/report.docx` |
| Presentations (.pptx) | `presentations/` | `/presentations/deck.pptx` |
| Spreadsheets (.xlsx) | `documents/` | `/documents/budget.xlsx` |
| Images (.png, .jpg, .svg) | `images/` | `/images/logo.svg` |
| Audio (.mp3, .wav) | `audio/` | `/audio/track.mp3` |
| Video (.mp4) | `video/` | `/video/demo.mp4` |
| GIF/Stickers | `images/` | `/images/sticker.gif` |
| Fonts (.woff2, .ttf) | `fonts/` | `/fonts/custom.woff2` |
| Seed data (.json) | `data/` | `/data/tracks.json` |
| Runnable scripts (.ts) | `scripts/` (repo root) | Not served — executed at build time |

**Deployment flow:** Creator → `frontend/public/` → Vite copies to `dist/` → CI/CD syncs to S3 + CloudFront. No custom CI/CD steps needed. All `frontend/public/` files are auto-deployed.

**Output (structured JSON report):**
```json
{
  "status": "SUCCESS" | "PARTIAL" | "FAILED",
  "skillUsed": "mmx-cli",
  "files": [
    { "path": "frontend/public/audio/track-01.mp3", "type": "audio/mpeg",
      "size": 3200000, "description": "Lo-fi chill beat, 90 BPM" }
  ],
  "integration": {
    "vitePublic": true,
    "importPath": "Served at /audio/track-01.mp3",
    "frontendUsage": "Audio source: `/audio/track-01.mp3`",
    "ciDeploy": "Deployed automatically via Vite → dist → S3 + CloudFront"
  },
  "qualityChecks": ["All files open without errors"]
}
```

**Constraints:**
- NEVER asks questions — makes creative decisions based on context
- All files MUST go under `frontend/public/` for auto-deployment
- Sandboxed ECS runtime — no S3 permissions, no direct deployment
- Prerequisites vary by file type (mmx CLI, .NET SDK, Python, ffmpeg) — checks and fallbacks documented
- Fallback on auth failure: generate metadata-only output (placeholder URLs, skeleton data)

**Assign when:** Story title includes: generate, create document, report, proposal, contract, memo, letter, resume, thesis, document, PDF, docx, spreadsheet, Excel, xlsx, csv, financial model, budget, presentation, slides, PowerPoint, PPT, PPTX, deck, music, song, audio, lyrics, playlist, album cover, album art, artwork, logo, image, video, text-to-speech, TTS, voice, narration, voiceover, sticker, GIF, cartoon, emoji, expression pack, avatar, template, format, reformat

---

### Creator Story Patterns

| User asks for | Stories to create | Agent assignment |
|---------------|-------------------|-----------------|
| "Generate a weekly report" | 1 story: Generate report | Creator (file-only) |
| "Build an audio player" | 1 story: Implement audio player | Developer |
| "Add music to the app" | 2 stories: (a) Generate music tracks (b) Integrate audio player | Creator + Developer |
| "Generate PDF summary + embed in dashboard" | 2 stories: (a) Generate PDF (b) Embed PDF viewer | Creator + Developer |
| "Create an image gallery" | 1 story: Implement image gallery | Developer |
| "Generate artwork for the gallery" | 1 story: Generate images | Creator |

**Rule:** If a request involves BOTH file generation AND code integration, split into two stories — Creator handles assets, Developer handles integration. Set Developer story to depend on Creator story.

### Multi-Agent Story Patterns

Some features require coordination across agents:

| Pattern | Stories | Dependencies |
|---------|---------|-------------|
| **Asset + Integration** | Creator (assets) → Developer (integration) | Developer depends on Creator |
| **Feature + Tests** | Developer (implement) → Tester (validate) | Tester depends on Developer |
| **Feature + Deploy** | Developer + Tester → Devops (deploy) → Tester (verify) | Sequential pipeline |
| **Full-stack feature** | Developer (backend + frontend in same story) | Single story |

**Anti-pattern:** Do NOT create a single story that says "Generate music and build audio player UI" — this is two different agents, two different workflows, two different completion criteria. Always split.

### Agent Quick Reference

| Agent | Pipeline | Completes when | Typical points |
|-------|----------|---------------|----------------|
| forLoopDeveloper | Phase 1 → Phase 2 | Tester reports PASS | 2-5 |
| forLoopTester | Phase 2 or Phase 4 | Returns PASS verdict | 1-3 |
| forLoopDevops | Phase 3 | Returns deploy success + endpoints | 2-3 |
| forLoopCreator | File generation workflow | Files generated, committed, auto-deployed via public/ | 1-3 |
| | (dispatched by Supervisor) | → used by Developer agent for integration | |

## Anti-Patterns

| ❌ Don't | ✅ Do Instead |
|----------|--------------|
| Ask user "what framework should we use?" | Assume React + Vite + TypeScript |
| Propose server-side rendering (Next.js/Remix) | Assume client-side SPA with Vite |
| Suggest per-route Lambda functions | Assume single Lambda with Express routing |
| Propose REST API (OpenAPI/Swagger) | Assume HTTP API v2 with Express middleware |
| Suggest Prisma/Sequelize/TypeORM | Use `dynamodb-onetable` |
| Propose PostgreSQL/MySQL | Use DynamoDB single-table design |
| Suggest REST API Gateway (v1) | Use HTTP API Gateway (v2) |
| Propose webpack/parcel | Use Vite for frontend, TypeScript compiler for backend |
| Ask "where should we deploy?" | Assume AWS (Lambda, S3, CloudFront, DynamoDB, ECR) |
| Suggest zip-based Lambda deployment | Use Docker container images via ECR |
| Propose GitHub Actions without OIDC | Use OIDC → IAM role assumption |
| Suggest manual AWS console changes | Use Terraform for all infrastructure |
| Plan VPC, EC2, ECS, EKS, RDS, SNS, SQS, Step Functions | Use only available services (see Available AWS Services section) |
| Plan S3 bucket or API Gateway creation | Use pre-provisioned baseline resources |
| Plan Route53 or ACM changes | DNS and certs are managed by Control Plane |
| Assign "generate weekly report" story to Developer | Assign to Creator — file generation, not code |
| Create one story for "generate music + build audio player" | Split into two: Creator (assets) + Developer (integration) |
| Assign Creator stories to the 4-phase pipeline | Creator follows a different workflow — no Phase 2-4 needed for static assets |
| Plan Creator output anywhere but `frontend/public/` | ALL Creator files go under `frontend/public/` for auto-deploy via Vite |
| Assign every story to Developer by default | Classify by task type: generation → Creator, infrastructure → Devops, testing → Tester |
| Estimate Creator stories at 5+ points | Creator stories are typically 1-3 points — file generation is fast |
| Ignore Creator's structured JSON report | Use file paths from report when creating Developer integration stories |

## Compliance

**All planning must assume this tech stack and agent team.** Do not ask users to confirm or choose alternatives unless they explicitly state a different requirement. Stories should be written assuming these technologies are in use. Assign each story to the correct agent based on the task type and agent capabilities described above.
