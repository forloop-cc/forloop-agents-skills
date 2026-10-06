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
    - forloop-project-base/.forloop/template/.github/workflows/deploy.yml
    - forloop-project-base/.forloop/template/docs/KNOWLEDGE.md
    - forloop-opencode-plugin-developer/skills/devops-deploy
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
[skip deploy]     ...   → no deployment
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
  `[teardown]`, `[debug]`, `[rollback]` tags. It commits the tag, watches the
  pipeline, and reports the production URLs.
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

`deploymentTarget: "tenant"` selects the dedicated account. Required repo
variables: `SERVER_LAMBDA_URL` or `SERVER_LAMBDA_URL_DEV` / `SERVER_LAMBDA_URL_PRD`.

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
5. `deploy-backend` — **two-phase Terraform**:
   - apply #1 creates the **ECR repo + DynamoDB table**,
   - `docker build` + push to ECR (`{env}-{sha}` tag),
   - apply #2 creates the **Lambda (Image package) + API Gateway routes**,
   - health check `GET {apiUrl}/health` until 200.
6. `api-tests` — curl-based API contract tests.
7. `notify-deployment` — on PR events, tell the ForLoop server.

## Production resource naming (tenant, `env=prd`)

| Resource             | Pattern                                          | Example                            |
| -------------------- | ------------------------------------------------ | ---------------------------------- |
| Lambda               | `fl-{tenant}-{project}-{env}`                    | `fl-acme-myapp-prd`                |
| DynamoDB table       | `fl-{tenant}-{project}-{env}`                    | `fl-acme-myapp-prd`                |
| ECR repository       | `fl-{accountId}-{tenant}-{project}`              | `fl-123456789012-acme-myapp`       |
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
- API contract tests pass.
- E2E: trigger with `[e2e all]` (or targeted `[e2e frontend]` / `[e2e backend]`).

## Rollback

- **Code:** `git revert` the offending merge on `main`, then commit again with a
  `[deploy ...]` tag (re-deploys the previous code).
- **Infra:** `[rollback infra]` reverts the Lambda image pointer / ECS task
  definition; Terraform state can be reverted to a previous revision.

## Common production failure modes

| Symptom                         | Likely cause / where to look                                  |
| ------------------------------- | ------------------------------------------------------------- |
| `Missing SERVER_LAMBDA_URL`     | Repo variable not set (`SERVER_LAMBDA_URL_PRD`).              |
| Broker `401/403`                | OIDC audience/trust misconfigured for the repo.               |
| `Broker response missing tenantRoleArn` | Tenant not onboarded / `deploymentTarget` wrong.     |
| Frontend not updating           | CloudFront invalidation missing or wrong S3 path.             |
| Backend 502                     | Lambda crash — check CloudWatch `/aws/lambda/fl-...-prd`.     |
| `repository does not exist` ECR | First Terraform apply (ECR creation) hasn't run yet.          |
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
