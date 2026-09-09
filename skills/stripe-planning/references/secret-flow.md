# How Stripe Keys Flow Through the System

The server_lambda is the **sole intermediary** for all secret operations. No
agent or user project Lambda ever touches AWS SSM directly. The server_lambda
owns the SSM client and IAM permissions.

```
┌─────────────────────────────────────────────────────────────────────┐
│                        server_lambda                                │
│                                                                     │
│  API endpoints:                                                     │
│  PUT  /api/opencode/sprints/:id/secrets/:key  ← stores key         │
│  GET  /api/opencode/sprints/:id/secrets       ← retrieves keys     │
│  DELETE /api/opencode/sprints/:id/secrets/:key ← deletes key       │
│                                                                     │
│  └──> sprintSecretsService.ts                                      │
│         └──> SSM Parameter Store                                   │
│                /{prefix}/sprints/{id}/secrets/{KEY}  (SecureString) │
│                                                                     │
│  Auth: X-API-Token header (scoped to secrets:read / secrets:write) │
└─────────────────────────────────────────────────────────────────────┘
          ▲                                      ▲
          │ PUT /sprints/42/secrets/STRIPE_KEY    │ GET /sprints/42/secrets
          │                                      │
   ┌──────┴──────┐                        ┌─────┴─────────────┐
   │   PLANNER    │                        │  USER PROJECT      │
   │   Agent      │                        │  Lambda            │
   │              │                        │                    │
   │ Stores user's│                        │ Reads key at       │
   │ Stripe key   │                        │ cold start to      │
   │ via forloop- │                        │ init Stripe client │
   │ Secrets-     │                        │                    │
   │ Store tool   │                        └────────────────────┘
   └──────────────┘
```

## Step 1: Planner Stores the Key

The planner agent uses the OpenCode plugin's secret storage tool to send the
user's Stripe key to the server_lambda:

```
Planner calls:
  PUT /api/opencode/sprints/{sprintId}/secrets/STRIPE_SECRET_KEY
  Authorization: X-API-Token: {token_with_secrets_write_scope}
  Body: { "value": "sk_test_xxxxxxxxxxxxxx", "description": "Stripe test secret key" }
```

The server_lambda:
1. Validates the API token has `secrets:write` scope
2. Encrypts the value and stores it in SSM at `/forloop/{env}/sprints/{id}/secrets/STRIPE_SECRET_KEY`
3. Records metadata (key name, description) in the `SprintSecret` PostgreSQL table
4. Logs an audit event (`secret.created`)

**What the planner needs to know:**

- The key name must be UPPER_SNAKE_CASE: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`
- The key description is optional but recommended (e.g., "Stripe test secret key")
- Multiple keys can be stored (one call per key)
- The planner needs an API token with `secrets:write` scope (auto-created by the platform)

## Step 2: Developer Agent Implements Retrieval

The developer agent writes `backend/src/services/stripeService.ts` in the
**user project** that retrieves keys from the server_lambda at cold start:

```typescript
// ─── Written by: Developer Agent ───
// File: backend/src/services/stripeService.ts

import Stripe from 'stripe'

const SERVER_API = process.env.SERVER_LAMBDA_URL
const SPRINT_ID = process.env.FORLOOP_SPRINT_ID
const API_TOKEN = process.env.FORLOOP_API_TOKEN

let _stripe: Stripe | null = null
let _secretsCache: Record<string, string> | null = null

async function fetchSecrets(): Promise<Record<string, string>> {
  if (_secretsCache) return _secretsCache

  const response = await fetch(
    `${SERVER_API}/api/opencode/sprints/${SPRINT_ID}/secrets`,
    {
      headers: {
        'X-API-Token': API_TOKEN || '',
        'Content-Type': 'application/json',
      },
    }
  )

  if (!response.ok) {
    throw new Error(
      `[stripe] Failed to fetch secrets: HTTP ${response.status}`
    )
  }

  const body = await response.json()
  _secretsCache = body.secrets || {}
  return _secretsCache
}

export async function getStripeClient(): Promise<Stripe> {
  if (!_stripe) {
    const secrets = await fetchSecrets()
    const secretKey = secrets['STRIPE_SECRET_KEY']
    if (!secretKey) {
      throw new Error(
        '[stripe] STRIPE_SECRET_KEY not found in sprint secrets. ' +
        'Did the planner store it?'
      )
    }
    // Full secret key required (sk_); restricted keys are rejected.
    if (!/^sk_/.test(secretKey)) {
      throw new Error('[stripe] STRIPE_SECRET_KEY must start with sk_')
    }
    _stripe = new Stripe(secretKey, {
      apiVersion: '2026-07-29.dahlia',
    })
  }
  return _stripe
}

export async function getWebhookSecret(): Promise<string> {
  const secrets = await fetchSecrets()
  return secrets['STRIPE_WEBHOOK_SECRET'] || ''
}

export function resetStripeClient(): void {
  _stripe = null
  _secretsCache = null
}
```

**What the developer agent needs to know:**

- `SERVER_LAMBDA_URL` env var is already available in the project template (set by Terraform)
- `FORLOOP_SPRINT_ID` and `FORLOOP_API_TOKEN` must be set as Lambda environment variables
- The API token needs `secrets:read` scope
- Secrets are cached in memory after first fetch (same as the SSM singleton pattern)
- No AWS SDK imports needed — just `fetch()`

## Step 3: DevOps Agent Configures Lambda Env Vars

The devops agent (Story 3a) adds these env vars to the project Lambda via
Terraform. This replaces the old SSM IAM policy and SSM path vars.

**Instead of** (OLD — direct SSM access):
```hcl
lambda_environment = merge(var.lambda_environment, {
  STRIPE_SSM_PATH = "/stripe/${var.env}"
  # plus ssm:GetParameter IAM policy
})
```

**Use** (NEW — server_lambda API):
```hcl
lambda_environment = merge(var.lambda_environment, {
  TENANT_ID         = var.tenant_id
  PROJECT_ID        = var.project_id
  ENV               = var.env
  SERVER_LAMBDA_URL = var.server_lambda_url
  FORLOOP_SPRINT_ID = var.sprint_id
  FORLOOP_API_TOKEN = var.forloop_api_token    # sensitive!
})
```

**Benefit:** No AWS SSM IAM permissions needed on the project Lambda. The
server_lambda already has them. The project Lambda only needs outbound HTTPS
to call the server_lambda API.

## Why This Design

| Direct SSM (OLD) | Server Lambda API (NEW) |
|------------------|-------------------------|
| Project Lambda needs `ssm:GetParameter` IAM policy | No IAM policy needed |
| Secrets read at cold start from SSM | Secrets fetched at cold start from API |
| Audit logging must be implemented in each project | Audit logging centralised in server_lambda |
| Key rotation requires updating SSM parameters | Key rotation via same API — `PUT /sprints/:id/secrets/:key` |
| Each project has its own SSM paths | All secrets managed through one API |

## Environment Separation

The server_lambda already handles environment separation via `SPRINT_SECRETS_SSM_PREFIX`:

| Environment | SSM Prefix | Effective Path |
|------------|-----------|----------------|
| dev | `/forloop/dev` | `/forloop/dev/sprints/{id}/secrets/STRIPE_SECRET_KEY` |
| prd | `/forloop/prd` | `/forloop/prd/sprints/{id}/secrets/STRIPE_SECRET_KEY` |

The project Lambda doesn't need to know about environments for secret lookup —
it just calls the same API endpoint regardless of environment.

## Quick Reference: Which Agent Does What

| Task | Agent | Tool/API |
|------|-------|----------|
| Store Stripe secret key | Planner | `PUT /api/opencode/sprints/:id/secrets/STRIPE_SECRET_KEY` via forloop plugin |
| Store webhook secret | Planner | `PUT /api/opencode/sprints/:id/secrets/STRIPE_WEBHOOK_SECRET` via forloop plugin |
| Set publishable key on frontend | Devops | Commit `stripePublishableKey` to `forloop.json` (delivered via deploy config API; GitHub Variable fallback) |
| Write Stripe service that fetches from API | Developer | `stripeService.ts` (fetch from server_lambda) |
| Configure Lambda env vars for API access | Devops | Terraform `lambda_environment` |
| Write backend code (controllers, webhooks) | Developer | Stripe SDK + server_lambda secrets |

## Stripe Key Names Convention

Use these exact key names when storing via the API:

| Key Name | Purpose | Sensitive? |
|----------|---------|-----------|
| `STRIPE_SECRET_KEY` | Stripe **secret key** (`sk_` — full access; restricted `rk_` keys are NOT supported) | Yes (server-side storage) |
| `STRIPE_WEBHOOK_SECRET` | Webhook signing secret (`whsec_`) | Yes (server-side storage) |
| `STRIPE_PUBLISHABLE_KEY` | Publishable key (frontend) | No (`stripePublishableKey` in `forloop.json`, NOT via secrets API) |
