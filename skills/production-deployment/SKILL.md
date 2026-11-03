---
name: production-deployment
description: >
  How a ForLoop user project reaches PRODUCTION in the user's dedicated tenant
  AWS account through the GitHub Actions pipeline. Covers the production trigger
  (merge to main -> prd), the OIDC broker + chained tenant-role authentication,
  the frontend/backend deploy jobs, tenant resource naming and production URLs,
  Terraform state, who actually triggers the deploy (forLoopDevops commits a
  [deploy ...] tag), verification, rollback, and how to explain the flow to the
  user in plain language.
  Use when: a user asks how their app goes live / is deployed to production,
  when planning release or production stories, when you need production URLs or
  resource names, or when troubleshooting a prd deployment.
  DO NOT use when: deploying to the dev environment (feature/develop -> dev),
  or for the shared ForLoop system account (deploymentTarget=shared).
license: MIT
metadata:
  version: "1.0.0"
  category: devops
  sources:
    # Paths relative to the app repo root (this is the development environment).
    - .github/workflows/deploy.yml   # the deploy pipeline
    - docs/KNOWLEDGE.md              # deployment knowledge for the app
    - devops-deploy                  # sibling skill
author: ForLoop
---

# Production Deployment (Tenant AWS Account)

Authoritative, planner-level description of how a user project is deployed to
**production** in the user's isolated tenant AWS account. The execution-side
mirror of this skill lives in the developer plugin
(`forloop-opencode-plugin-developer/skills/production-deployment`). Keep the
facts here in sync.

## What the user needs to hear (plain language)

Use this when a user asks "how does my app get deployed / go live?":

1. **Every space has its own isolated AWS account** — the user's *tenant*
   account. No other customer shares it. It is created once when the
   organization is onboarded (AWS Organizations + a bootstrap StackSet that
   installs the `ForLoopTenantDeployRole`).
2. **Production = merge to `main`.** When work is merged into `main`, the
   project's GitHub Actions pipeline builds and deploys automatically.
3. **The user never touches AWS.** No access keys, no console, no manual steps.
   The pipeline authenticates with a short-lived GitHub OIDC token and assumes a
   scoped role inside the tenant account.
4. **Production URL** is `https://{project}.{tenant}.forloop.cc` and the API is
   `https://api.{tenant}.forloop.cc/prd/{project}`.

## Planning implies this model

- The planner does **not** plan AWS accounts, VPCs, repos, CI/CD pipelines, or
  DNS. All of that already exists (tenant baseline + project-base template).
- The planner **does** create `forLoopDevops` stories for release/deploy work
  and states acceptance criteria in terms of the deployed production URLs.
- Never propose Vercel/Netlify/manual hosting. Deployment is ForLoop-managed on
  AWS in the tenant account.

## The single deployment trigger

There is exactly **one** way to deploy: a commit (or merge) whose message
contains a deploy tag.

```
[deploy frontend] ...   → frontend only
[deploy backend]  ...   → backend only
[deploy all]      ...   → both
[deploy]          ...   → both (bare tag = all)
[skip deploy]     ...   → no deployment (green no-op)
```

Environment is derived from the **branch**, never from the tag:

| Branch                          | Environment |
| ------------------------------- | ----------- |
| `main`                          | `prd`       |
| `develop`, `feature/*`, others  | `dev`       |

**Production specifically means:** the feature branch is PR-merged into `main`
(or a commit is pushed to `main`) with a `[deploy ...]` tag. That fires the
`prd` run, which targets the tenant account.

## Who triggers it

- **forLoopDeveloper** writes code and commits with a **plain** message (no
  deploy tag).
- **forLoopTester** validates locally and must return `PASS`.
- **forLoopDevops** is the **only** agent allowed to add `[deploy]`, `[e2e]`,
  `[teardown]`, `[debug]` tags. It commits the tag, watches the pipeline, and
  reports the production URLs. There is no `[rollback]` workflow tag; rollback
  is a `git revert` followed by `[deploy ...]`.
- Committing the tag **is** the deployment. Agents must never use `curl`,
  `gh api`, `gh workflow run`, `terraform apply`, or `aws s3 cp`.

## Authentication: OIDC broker → chained tenant role

No long-lived AWS credentials exist anywhere.

```
GitHub Actions job
  → mint OIDC token (audience "forloop-deploy")
  → POST {SERVER_LAMBDA_URL}/api/github/deploy/config   (broker)
       ← controlPlaneRoleArn, tenantRoleArn, tenantId, projectName,
         deploymentTarget="tenant", flEnv, frontendUrl, apiUrl
  → assume control-plane role (in ForLoop's account) via OIDC
  → aws sts assume-role  → tenantRoleArn (ForLoopTenantDeployRole, in the
                                           user's tenant account)
  → S3 / ECR / Lambda / CloudFront / Terraform operations
```

`deploymentTarget: "tenant"` selects the dedicated account.

### What is stored in GitHub (and what is not)

The pipeline fetches **config and credentials inside the job** via GitHub OIDC
+ the ForLoop broker. There are **no stored AWS access keys, role ARNs, app
credentials, or `floop_` tokens** in GitHub.

| Value | Where it comes from |
| --- | --- |
| AWS roles / account, tenant/project, `flEnv`, URLs, `sprintId` | Broker (`POST /api/github/deploy/config`) |
| App credential, `floop_` API token, agent secrets, OIDC client | Broker + `agent-secrets/ensure`, fetched **per job** (never a job output) |
| Stripe publishable key, Realtime connection/base/contract | Broker |
| Broker URL (`serverLambdaApi`) | `forloop.json` (preferred); `SERVER_LAMBDA_URL*` repo vars are fallback only |
| Dev-only E2E story fixtures | **Stored exceptions:** `E2E_STORY170_HOST_AUTH_TOKEN` (secret), `E2E_SCHEDULER_SIGNING_SECRET` (secret), the two meeting-id vars |
| Optional app vars | `STRIPE_PRICE_*` (frontend fallback), `FORLOOP_REALTIME_*` / `APP_ORIGIN` (only when Realtime is connected), `SCHEDULER_ENDPOINT_ID` / `SCHEDULER_SIGNING_SECRET_PARAMETER_NAME` (Scheduler wiring) — not deploy credentials |

The two secrets are **test fixtures, not deploy credentials**. The host token is
a user session for the fixture host; the Scheduler secret is the app endpoint's
HMAC key. The seed is an **operator step** (preferred path: sign in to the app
and use the app's own session token) — it is not "blocked on CI SSM access".
Missing fixtures make the affected live assertions self-skip; they are not a
deploy or CI failure.

## What the pipeline does

Jobs in `.github/workflows/deploy.yml`:

1. `parse-deploy-request` — parse `[deploy ...]` / `[teardown ...]`, detect env
   from branch (`main` → `prd`).
2. `ci-checks` — shellcheck, lint, typecheck, build, unit tests. **Blocks the
   deploy on failure.**
3. `fetch-deploy-config` — mint OIDC, call the broker, get roles + URLs.
4. `deploy-frontend` — build Vite with `VITE_FL_ENV/VITE_DEPLOY_ENV/VITE_MODE/
   VITE_TENANT_ID/VITE_PROJECT_NAME/VITE_API_URL`, sync `frontend/dist/` to S3,
   invalidate CloudFront, then curl the production URL until HTTP 200.
5. `deploy-backend` — **two-phase Terraform** (push/dispatch only):
   - apply #1 creates the **ECR repo + DynamoDB table** (only when the ECR repo
     is missing; re-running it can destroy the live Lambda),
   - `docker buildx build --platform linux/amd64 --provenance=false --sbom=false
     --output type=docker` + push to ECR (`{env}-{sha}` tag, retried 3× with
     backoff on 429/transient errors),
   - apply #2 creates the **Lambda (Image package) + API Gateway routes**,
   - health check `GET {apiUrl}/health` until 200,
   - ingest `forloop-manifest.json` (409 = newer stored contract wins).
   A PR run skips this job (CI still validates the backend).
6. `api-tests` — required contract tests; `tests/api/run.sh` runs with its real
   exit code, so a failing assertion fails the job (never `continue-on-error`).
7. `notify-deployment` — on PR events, tell the ForLoop server only when at
   least one deploy succeeded (the job uses `always()`).

**Green no-ops vs red:** no `[deploy]`/`[teardown]` tag, teardown of resources
that were never provisioned, and E2E fixtures that self-skip are intentionally
green. A red job must be a real build/test/deploy/configuration failure. Do not
"fix" a no-op by adding `continue-on-error`.

## Production resource naming (tenant, `env=prd`)

| Resource             | Pattern                                          | Example                            |
| -------------------- | ------------------------------------------------ | ---------------------------------- |
| Lambda               | `fl-{tenant}-{project}-{env}`                    | `fl-acme-myapp-prd`                |
| DynamoDB table       | `fl-{tenant}-{project}-{env}`                    | `fl-acme-myapp-prd`                |
| ECR repository       | `fl-{accountId}-{tenant}-{project}-{env}`        | `fl-123456789012-acme-myapp-prd`   |
| S3 frontend bucket   | `fl-{accountId}-{tenant}-frontend-{env}`         | `fl-123456789012-acme-frontend-prd`|
| Lambda IAM role      | `fl-{tenant}-{project}-{env}-lambda-role`        | `fl-acme-myapp-prd-lambda-role`    |
| CloudWatch log group | `/aws/lambda/fl-{tenant}-{project}-{env}`        | `/aws/lambda/fl-acme-myapp-prd`    |

**Production URLs (tenant):**

| Resource | URL                                                        |
| -------- | ---------------------------------------------------------- |
| Frontend | `https://{project}.{tenant}.forloop.cc`                     |
| API      | `https://api.{tenant}.forloop.cc/prd/{project}`             |
| S3 path  | `s3://fl-{accountId}-{tenant}-frontend-prd/prd/{project}/`  |

**Terraform state:**

```
s3://fl-{accountId}-{tenant}-tf-state/project/prd/{project}/terraform.tfstate
```

(v1 fallback bucket `fl-{tenant}-tf-state` is also probed.)

## Verification after a production deploy

- Frontend returns HTTP 200 at the production URL.
- `GET https://api.{tenant}.forloop.cc/prd/{project}/health` returns HTTP 200.
- API contract tests pass (required).
- `forloop-manifest.json` is ingested after the backend verify (409 = newer
  stored contract wins; not a deploy failure).
- E2E: trigger with `[e2e all]` (or targeted `[e2e frontend]` / `[e2e backend]` /
  `[e2e story]`). The suite has 5 test job definitions (smoke, health, api,
  realtime, story); `e2e-story` runs a `[1,2,3]` shard matrix with Playwright
  `--shard=<index>/<total>`. Every job has a **10-minute cap** — sharding is
  what keeps a large story suite inside it. Missing optional fixtures self-skip
  and stay green; only a real assertion failure is red.

## Rollback

There is no `[rollback]` trigger in the parser. Roll back by reverting and
deploying again:

- **Code:** `git revert` the offending merge on `main`, then commit with
  `[deploy ...]` (re-deploys the previous code).
- **Infra:** revert the Terraform change (it is in git) and commit `[deploy ...]`.
- Verify health and the ingested manifest version after the rollback deploy.

## Fresh clone and app-specific wiring

- **Clone hygiene:** run `.forloop/template/POST_CLONE.md` before the first
  deploy — rewrite the manifest identity/`baseUrl`, set `flEnv` explicitly,
  re-grant every connection (ids are sprint+env-specific), fund the wallet, and
  reset source-app ids/URLs/seeds/E2E fixtures.
- **Core services:** Notify's canonical send route is `POST /v1/notifications`
  (there is no `/v1/messages`); Scheduler must be registered + verified before
  use; paid calls debit the app wallet. Cross-reference `core-service-discovery`
  for the planning decision and let the Developer own the app-side wiring.

## Common production failure modes

| Symptom                         | Likely cause / where to look                                  |
| ------------------------------- | ------------------------------------------------------------- |
| `Missing SERVER_LAMBDA_URL`     | `forloop.json` has no `serverLambdaApi` and no fallback var.  |
| Broker `401/403`                | OIDC audience/trust misconfigured for the repo.               |
| `Broker response missing tenantRoleArn` | Tenant not onboarded / `deploymentTarget` wrong.     |
| Frontend not updating           | CloudFront invalidation missing or wrong S3 path.             |
| Backend 502                     | Lambda crash — check CloudWatch `/aws/lambda/fl-...-prd`.     |
| `repository does not exist` ECR | First Terraform apply (ECR creation) hasn't run yet.          |
| `image manifest ... is not supported` | Image lacks `--platform linux/amd64 --provenance=false --sbom=false`. |
| `Skip output ... may contain secret` | Secret passed as a job output; the job re-fetches it instead. |
| 403 bare `{"message":"Forbidden"}` | Dev source-IP allowlist, not auth.                          |
| Release/tag 403 | `permissions: contents: write` missing.                        |
| API 404 but direct invoke works | `basePath` missing in the Lambda handler.                     |

Use the `deploy-failure-diagnosis` skill (developer side) for the full matrix.

## Anti-patterns

| Don't                                          | Do instead                                        |
| ---------------------------------------------- | ------------------------------------------------- |
| Tell the user "deploy from the AWS console"    | Explain main → prd automatic pipeline             |
| Plan repo/CI/CD/account setup                  | It's pre-provisioned; plan features + deploy stories |
| Use CLI/terraform/aws commands to deploy       | Commit a `[deploy ...]` tag (forLoopDevops only)  |
| Hardcode account IDs or role ARNs              | The broker returns them; derive account via STS   |
| Invent prod URLs                               | Use the exact `frontendUrl`/`apiUrl` from the deploy report |
| Confuse `flEnv` (domain suffix) with `ENV`     | See "flEnv vs ENV" below                          |
| Treat a skipped/benign job as a failure       | No-tag pushes, "nothing to tear down", and self-skipping E2E fixtures are explicitly green |

## flEnv vs ENV (do not confuse)

- `flEnv` (`dev`|`prd`) — ForLoop platform environment; controls the domain
  suffix (`.dev.forloop.cc` vs `.forloop.cc`).
- `ENV` (`dev`|`prd`) — AWS deployment environment; controls the project prefix
  (`-dev`), Lambda/S3 names, and the API path segment. Derived from the branch.

A **production** frontend is `https://{project}.{tenant}.forloop.cc` and its API
is `https://api.{tenant}.forloop.cc/prd/{project}` only when `flEnv=prd` and
`ENV=prd`. If `flEnv=dev`, insert `.dev` before `forloop.cc`.

## Related skills

- `devops-deploy` (developer) — full GitHub Actions workflow + failure matrix
- `multi-tenant-deployment` (developer) — tenant vs shared routing
- `tech-stack-default` — stack, naming, and available AWS services
- `deploy-failure-diagnosis` (developer) — classify/fix pipeline failures
