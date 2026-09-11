---
name: stripe-planning
description: >
  Plan Stripe payment integration for ForLoop projects. Covers: gathering
  Stripe API keys and product/pricing requirements from the user, organizing
  a canonical product catalog spec (product/offer/promotion model), and
  breaking the integration into implementable stories (Stripe setup →
  Admin Portal Product Management → Backend → Frontend → Testing). This is a
  PLANNING-ONLY skill.
  Use when: the user wants to add payment features to their ForLoop project,
  mentions "Stripe", "payments", "checkout", "subscriptions", "pricing plans",
  or "billing". Also use when the user provides Stripe API keys.
  DO NOT use when: implementing Stripe code (delegate to developer agent
  with stripe-integration skill), general space planning without payments
  (use sprint-planning), or estimating story points (use story-points).
license: MIT
metadata:
  version: "2.0.0"
  category: planning
  sources:
    - Stripe official skills (docs.stripe.com/skills)
    - ForLoop project-base template (.forloop/template/)
    - ForLoop catalog sync planning docs (docs/user_application_development/01-12)
triggers:
  - "stripe"
  - "payment"
  - "checkout"
  - "subscription"
  - "pricing"
  - "billing"
  - "charge"
  - "credit card"
  - "recurring"
integrations:
  - sprint-planning
  - story-creation
  - story-points
  - template-based-tasks
  - tech-stack-default
---

# Stripe Planning for ForLoop Projects

## Overview

Plan Stripe payment integration at the space/story level. This skill guides the
planner agent through gathering requirements, organizing the product catalog,
and breaking the work into properly-sequenced stories that developer, devops,
and tester agents can execute.

This is a **planning-only** skill. Do not write application code. The developer
agent uses the `stripe-integration` skill to implement the stories you create.

## ⚠️ Stripe Is An OPTIONAL Feature

The Stripe product feature is **NOT a standard part of every ForLoop project**.
It is only needed when the user wants to build an application that **sells
products or services with payment** (one-time purchases, subscriptions, or
both).

- If the user's app does not sell anything → skip this skill entirely. Do not
  propose Stripe, payments, pricing plans, or billing.
- Only plan Stripe stories after the user explicitly asks for payment
  functionality (sells products/services, subscriptions, checkout, billing).
- Do NOT add Stripe stories to a general app plan "just in case".
- Payment requirements may also come later in a project's life — plan them
  only when they arrive, never by default.

## Architecture You Are Planning For (READ FIRST)

The ForLoop platform runs a **server-side catalog sync pipeline**. Do NOT plan
stories around the old devops-driven Stripe bootstrap (devops creates Stripe
Products/Prices → `stripe-prices.json` → `VITE_STRIPE_PRICE_*` env vars). That
flow no longer exists.

What actually happens:

1. **Product authoring happens in the user application admin portal** — the
   primary product-management surface. Admins create/update/archive products as
   **change-sets**, or bulk-import CSV / Excel / JSON source files as **import
   batches**. The user application backend mediates: it calls the ForLoop
   `server_lambda` internal catalog-sync API with a short-lived service token.
2. **The control-plane sync workflow executes server-side**: it normalizes,
   validates, produces a preview diff, then on user confirmation applies
   **Stripe first, user DynamoDB second** — creating/updating/archiving Stripe
   Products, Prices, and Coupons/Promotion Codes, then writing runtime rows
   (`CatalogProduct`, `CatalogOffer`, `CatalogPromotion`, category mappings).
   Runtime rows become visible only when `status=active` and `syncStatus=ready`.
3. **No Stripe IDs are hardwired into the app.** The frontend pricing page
   renders from the runtime catalog API. Checkout posts a **local `offerKey`**;
   the backend resolves `offerKey → stripePriceId` from the runtime catalog.
   The only Stripe value in the frontend build is `VITE_STRIPE_PUBLISHABLE_KEY`
   (delivered via the deploy config API from the sprint secret
   `STRIPE_PUBLISHABLE_KEY`; null for non-Stripe projects).
4. **Sprint space is a readiness/support surface only** — it shows setup
   status, sync jobs, and links into the admin portal. It is not a second
   authoring UI.

Plan stories that match this architecture, not the legacy bootstrap.

## When to Use

- The user is building an app that **sells products/services with payment**
- User says they want to accept payments in their ForLoop project
- User provides Stripe API keys or mentions they have a Stripe account
- User asks for "checkout", "subscriptions", "pricing plans", "billing"

**Payment features are OPTIONAL.** Not every ForLoop project needs Stripe.
Only load this skill when the user explicitly requests payment functionality.
Do NOT propose Stripe integration unless the user asks for it.

## When NOT to Use

- Writing Stripe code → delegate to `forLoopDeveloper` with `stripe-integration` skill
- General space planning without payments → use `sprint-planning`
- Estimating story points → use `story-points` skill

## What the Planner Needs From the User

Before creating any stories, gather the following. Ask targeted questions
(natural text, not the structured `question` tool) and wait for the user's
response before proceeding.

### Phase A: Stripe Account & Keys

**First**, determine if the user has a Stripe account. If not, guide them
through registration at https://stripe.com/register (free, takes ~5 minutes).
See `references/keys-from-user.md` for a complete walkthrough script including
Dashboard navigation paths, test mode setup, and key formats.

| What to Ask | Why |
|-------------|-----|
| Do you have a Stripe account? | If no, guide to stripe.com/register |
| Do you have your Stripe **secret key** and **publishable key**? | Secret key for the sync pipeline; publishable key for Stripe.js |
| Are you using test mode or live mode? | Determines `sk_test_` vs `sk_live_` |

**Key formats the platform accepts:** `STRIPE_SECRET_KEY` MUST be a full
Stripe **secret key** starting with `sk_`. Restricted keys (`rk_`) are NOT
supported — the sync pipeline creates/updates Products, Prices, Coupons, and
Promotion Codes, which restricted keys cannot do. Never ask the user for an
`rk_` key.

**How keys flow through the system:**

```
User provides keys → Planner stores via PUT /api/opencode/sprints/:id/secrets/:key
                              │
User asks "how are my    ←── Planner explains: ←── server_lambda encrypts
keys protected?"          "server_lambda handles  and stores the secret
                           all storage — the     (server-side only)
                           project Lambda never
                           touches AWS directly."
                                                        │
                                            The user app backend fetches
                                            secrets from the server_lambda
                                            API at cold start
```

See `references/secret-flow.md` for the full lifecycle diagram and the
planner's talking points for security questions.

**Important:** The planner never stores or logs keys. Note only that "keys are
available" in the knowledge file. Key gathering guide: `references/keys-from-user.md`.

### Secret Key Names (CONTRACT WITH DEVELOPER)

The planner MUST store secrets using these exact key names. The developer agent
will retrieve them using the same names. These names are the **contract** between
agents — changing them breaks the integration.

| Secret Key Name | What to Store |
|-----------------|---------------|
| `STRIPE_SECRET_KEY` | The user's Stripe **secret key** (`sk_test_...` / `sk_live_...`). Full access required by the catalog sync pipeline. |
| `STRIPE_WEBHOOK_SECRET` | The webhook signing secret (`whsec_...`) — collected after webhook endpoint is created |

**Store via:**
```
PUT /api/opencode/sprints/{sprintId}/secrets/STRIPE_SECRET_KEY
PUT /api/opencode/sprints/{sprintId}/secrets/STRIPE_WEBHOOK_SECRET
```

**Do NOT:** add prefixes, suffixes, environment suffixes (dev/prd), or rename these keys.

### Phase B: Product Catalog (Product / Offer / Promotion model)

The core of Stripe planning. The platform models the catalog with **three
entities** — do not collapse everything into "a Stripe price with an env var":

- **Product** = what the user sells (`productKey`, name, description, category, status)
- **Offer** = how that product is billed (one-time or recurring monthly/yearly, `amountCents`, currency, trial)
- **Promotion** = temporary discount layer on top of offers (percent/amount off, coupon code)

**Step 1 — Identify what they sell:**

| Question | Purpose |
|----------|---------|
| Do you sell one-time products (items bought once)? | E.g., "e-book for $9.99", "t-shirt for $25" |
| Do you sell subscription services (recurring billing)? | E.g., "Pro plan $29/month", "weekly coaching" |
| Or both? | Many businesses mix both: a setup fee (one-time) + monthly plan (recurring) |

**Step 2 — For each product/plan, elicit:**

| What to Ask | Examples |
|-------------|----------|
| Product name + stable key | "Pro Plan" → productKey `pro-plan` |
| One-time or recurring? | One-time purchase vs. monthly/yearly subscription |
| Price and currency | $49 USD, €29 EUR, ¥2900 JPY |
| Multiple billing intervals? | Monthly AND annual for the same product → two offers |
| Any trial period (recurring only)? | "14-day free trial" |
| Any temporary promotions / coupon codes? | "SUMMER20 — 20% off first 3 months" |
| Any usage-based pricing? | "Pay per API call" — out of scope for V1; note it |

**Step 3 — Classify into the canonical model** (one product → one or more
offers; promotions separate):

| Entity | Stable Key Pattern | Checkout Mode |
|--------|--------------------|---------------|
| One-time product → one-time offer | `billingType: one_time` | `mode: payment` |
| Subscription product → recurring offer(s) | `billingType: recurring`, `interval: month\|year` | `mode: subscription` |

Organize the answers into a **canonical product catalog spec**. See
`references/product-catalog-spec.md` for the full schema (doc 04 canonical
format: `products[]` with nested `offers[]`, optional `promotions[]`).

### Phase C: Checkout Flow

| What to Ask | Notes |
|-------------|-------|
| Stripe-hosted Checkout (redirect) or embedded? | Template ships hosted redirect (simpler); embedded is a later enhancement |
| What happens after payment? | Success URL (thank-you page), cancel URL (back to pricing) |
| Need to collect customer info beyond email? | Shipping address? Tax ID? |
| Any post-purchase actions? | Grant access, send email, provision account |

The checkout contract is `offerKey`-based: the frontend links to
`/checkout?offerKey=pro-monthly` and the backend resolves the Stripe price ID
server side. Never plan around client-supplied raw price IDs.

### Phase D: Environment & Infrastructure

| What to Ask | Notes |
|-------------|-------|
| Tenant ID and project name? | Already known from space context, confirm |
| Dev vs. production webhook URLs? | `api.{tenant}.forloop.cc/{env}/{project}/webhooks/stripe` |
| Admin portal access? | The app's `/admin/catalog` page — confirm an admin token policy exists |

## Product Catalog Specification

After gathering requirements, you produce a canonical desired-state catalog.
This file is the **desired state** — the sync pipeline compares it against
Stripe + the runtime DynamoDB and produces a preview diff (create/update/
archive/skip). It is NOT hand-fed to Stripe by a devops agent.

**The planner writes `stripe-product-catalog.json` as the primary format** using
the canonical schema from `references/product-catalog-spec.md` (products with
nested offers; optional promotions). A companion `.md` file is generated for
user review.

**How the catalog gets applied** (plan the handoff correctly):

- The canonical JSON is uploaded into the sprint space files (`forloopSyncLocalToS3(sprintId={id})`) as the keeper copy.
- The **admin portal import workspace** is where it enters the pipeline in practice: the user (or the developer agent during implementation) creates an import batch, uploads the JSON (or CSV/Excel) to staging S3 via a presigned URL, registers it, requests a preview, reviews the diff, and confirms apply.
- Alternatively, small authoring edits happen directly in the admin portal as change-sets (create/update/archive), also previewed then applied through the same pipeline.

**The planner filesystem is ephemeral (Lambda-based).** After writing files
locally, always upload to S3 via `forloopSyncLocalToS3(sprintId={id})`.

### Catalog JSON (canonical shape — see reference for the full schema)

```json
{
  "version": 1,
  "catalogKey": "sprint-42",
  "projectKey": "my-saas-app",
  "currency": "usd",
  "products": [
    {
      "productKey": "pro-plan",
      "name": "Pro Plan",
      "description": "Full access to all Pro features",
      "status": "active",
      "category": "subscription",
      "offers": [
        { "offerKey": "pro-monthly", "name": "Pro Monthly", "billingType": "recurring", "interval": "month", "amountCents": 2900, "currency": "usd", "trialDays": 14 },
        { "offerKey": "pro-yearly", "name": "Pro Yearly", "billingType": "recurring", "interval": "year", "amountCents": 29000, "currency": "usd" }
      ]
    },
    {
      "productKey": "setup-service",
      "name": "One-Time Setup",
      "description": "Professional setup and configuration",
      "status": "active",
      "category": "service",
      "offers": [
        { "offerKey": "setup-once", "name": "Setup Service", "billingType": "one_time", "amountCents": 49900, "currency": "usd" }
      ]
    }
  ],
  "promotions": [
    {
      "promotionKey": "summer-20",
      "name": "Summer 20",
      "code": "SUMMER20",
      "discountType": "percent",
      "percentOff": 20,
      "duration": "once",
      "active": true,
      "appliesTo": { "offerKeys": ["pro-monthly", "pro-yearly"] }
    }
  ]
}
```

### Key planning rules

- **1 product → many offers**, not "1 product → 1 price". Monthly + yearly
  variants of the same product are offers of one product.
- Stable local keys (`productKey`, `offerKey`, `promotionKey`) are the identity
  contract; Stripe IDs are an implementation detail resolved at apply time.
- Permanent price changes create a NEW Stripe price (and archive the old
  offer); temporary discounts are Promotions, never mutations of the base price.
- Split into separate products only when the business meaning differs (e.g.
  lifetime license vs. subscription).

## Story Breakdown

Break Stripe integration into these phases. Each phase becomes one or more
stories, assigned to the appropriate agent, in dependency order.

### Story Dependency Map

```
Phase 0: Setup (Planner + Developer)
    │
    ├── Story 0a: Store Stripe keys via secrets API (Planner)
    ├── Story 0b: Write canonical product catalog spec (Planner)
    └── Story 0c: Verify admin portal catalog readiness (Developer)
         │
Phase 1: Product Management via Admin Portal (Developer)
    │
    ├── Story 1a: Wire/verify admin catalog authoring (change-sets) in the template
    ├── Story 1b: Wire/verify bulk import workspace (import batches) in the admin portal
    ├── Story 1c: Load the planner's catalog through preview → confirm apply
    └── Story 1d: Admin sync jobs/retry views
         │
Phase 2: Backend Runtime Surfaces (Developer)
    │
    ├── Story 2a: runtime catalog read APIs (products/offers/promotions)
    ├── Story 2b: checkout by offerKey (server-side price resolution) + payment record
    ├── Story 2c: Stripe webhook (raw body + signature verification)
    └── Story 2d: stripeService fetching secret/webhook secret from server_lambda
         │
Phase 3: Frontend (Developer)
    │
    ├── Story 3a: dynamic pricing page from runtime catalog
    ├── Story 3b: checkout page via ?offerKey=
    └── Story 3c: success page + Stripe.js bootstrap (publishable key)
         │
Phase 4: Infrastructure (Devops)
    │
    └── Story 4a: Lambda env vars (SERVER_LAMBDA_URL, FORLOOP_SPRINT_ID, FORLOOP_API_TOKEN,
                   ADMIN_API_TOKEN) + publishable-key via deploy config API (sprint secret)
         │
Phase 5: Testing (Tester)
    │
    ├── Story 5a: Backend unit tests (checkout offerKey resolution, webhook verification)
    ├── Story 5b: E2E test stubs (offerKey checkout)
    └── Story 5c: Post-deploy verification with Stripe test mode
```

### Story Templates

Use `forloopStoryTemplate` with `templateSlug="basic-task"` for all stories.

#### Phase 0 Stories (Planner)

**Story 0a: Store Stripe keys in space secrets via server_lambda API**

```
Title: Store Stripe API keys (secret + publishable + webhook) in space secrets via ForLoop secrets API

Description:
As a planner, I want the user's Stripe secret key (sk_...), publishable key
(pk_...), and webhook signing secret stored securely via the server_lambda
secrets API, so that the catalog sync pipeline, the deploy-time config API,
and the project Lambda can retrieve them at runtime.

Acceptance Criteria:
- Given the user's Stripe test keys are available
- When planner calls PUT /api/opencode/sprints/{id}/secrets/STRIPE_SECRET_KEY
- Then the secret is stored server-side (server_lambda handles encryption/storage)
- And the stored value starts with sk_ (full secret key, NOT rk_)
- And PUT /api/opencode/sprints/{id}/secrets/STRIPE_PUBLISHABLE_KEY also
      succeeds with the pk_ value (public key — still stored in sprint
      secrets, never committed to the repo; the deploy config API reads it
      from SSM at deploy time)
- And PUT /api/opencode/sprints/{id}/secrets/STRIPE_WEBHOOK_SECRET also succeeds
- And secrets:write scope is present on the API token
- And keys are NOT committed to any git repository

Points: 1
Priority: high
Assignee: forLoopPlanner
```

**Story 0b: Write the canonical product catalog spec**

```
Title: Write the canonical product catalog spec (product/offer/promotion)

Description:
As a planner, I want the catalog captured in the canonical desired-state format
(products with nested offers, optional promotions, stable keys), so that it can
be loaded through the admin portal import pipeline for preview and apply.

Acceptance Criteria:
- Given the user's product/pricing answers
- When planner writes stripe-product-catalog.json (doc 04 schema)
- Then every product has a stable productKey and at least one offer with offerKey
- And offers carry billingType (one_time|recurring), amountCents, currency
- And recurring offers carry interval (month|year)
- And promotions (if any) are separate entities with discountType + appliesTo
- And a human-readable stripe-product-catalog.md is generated for review
- And both files are uploaded to the sprint S3 bucket

Points: 2
Priority: high
Assignee: forLoopPlanner
```

#### Phase 1 Stories (Developer) — Admin Portal Product Management

**Story 1a: Admin catalog authoring (change-sets)**

```
Title: Wire the admin portal catalog authoring flow (change-sets)

Description:
As an admin, I want to create/update/archive products in the app's admin
portal as change-sets, so that Stripe and the runtime catalog are updated
through the server-side sync pipeline (preview then apply) instead of
direct Stripe calls.

Acceptance Criteria:
- Given the project-base template's /admin/catalog backend routes
- When an admin creates/updates/archives a product
- Then a change-set (draft) is recorded (never a direct Stripe mutation)
- And POST /admin/catalog/preview starts a server-side preview job
- And POST /admin/catalog/apply confirms the previewed job
- And the backend authenticates to server_lambda with the short-lived service token
- And the X-Actor headers carry the real admin identity

Points: 3
Priority: high
Assignee: forLoopDeveloper
Dependencies: Story 0a (secret) — and 0c (client registration readiness)
```

**Story 1b: Bulk import workspace**

```
Title: Bulk import workspace in the admin portal (import batches)

Description:
As an admin, I want to upload CSV/Excel/JSON product sources into an import
batch, register them, and request a preview through the sync pipeline, so the
planner's catalog file (or a spreadsheet) becomes the runtime catalog.

Acceptance Criteria:
- Given /admin/catalog/import-batches routes in the template backend
- When an admin creates a batch and uploads a source file
- Then the backend requests a presigned PUT URL from server_lambda staging
- And the file is uploaded straight to S3 from the browser, then registered with checksum
- And POST /import-batches/:id/preview queues a preview job
- And the batch shows its files, manifest version, and preview/apply job ids

Points: 3
Priority: high
Assignee: forLoopDeveloper
Dependencies: Story 1a
```

**Story 1c: First catalog load (planner catalog → applied)**

```
Title: Load the planned catalog: preview, review, and confirm apply

Description:
As the project owner, I want the planned stripe-product-catalog.json imported
through the admin portal (JSON import batch), previewed, and applied, so
Stripe and the runtime DynamoDB catalog reflect the plan.

Acceptance Criteria:
- Given the planner's stripe-product-catalog.json (sprint S3)
- When an import batch is created with the JSON file and previewed
- Then the preview shows create/update/archive/skip counts
- And no real mutations happen before confirmation
- When apply is confirmed
- Then Stripe products/prices are created first, runtime rows second
- And completed sync items show status=active + syncStatus=ready

Points: 2
Priority: high
Assignee: forLoopDeveloper
Dependencies: Stories 1a, 1b
```

**Story 1d: Sync jobs visibility in the admin portal**

```
Title: Sync jobs list/detail/retry views in the admin portal

Description:
As an admin, I want to see sync job status, item-level results, and retry
failed items from the admin portal, so product-management outcomes are
visible where authoring happens.

Acceptance Criteria:
- Given /admin/catalog/jobs and /jobs/:id/items
- Then the admin portal lists jobs with status and counts
- And item-level stripe/db status and errors are visible
- And retry is offered only for failed retryable items

Points: 2
Priority: medium
Assignee: forLoopDeveloper
Dependencies: Story 1a
```

#### Phase 2 Stories (Developer) — Backend Runtime

**Story 2a: Ready-only runtime catalog APIs**

```
Title: Runtime catalog read APIs from the user DynamoDB table

Description:
As a shopper, I want the app to serve catalog data backed by the synced
runtime rows, so the frontend never ships hardcoded prices.

Acceptance Criteria:
- Given GET /catalog/products (+ filters categoryKey, featured)
- Then only rows with status=active AND syncStatus=ready are returned
- And GET /catalog/products/:productKey returns offers/assets for one product
- And GET /catalog/promotions/active returns active ready promotions
- And archived or partially-synced rows are never exposed

Points: 2
Priority: high
Assignee: forLoopDeveloper
Dependencies: Story 1c (rows must exist)
```

**Story 2b: Checkout by offerKey**

```
Title: POST /payments/checkout accepts offerKey and resolves the Stripe price server side

Description:
As a shopper, I want checkout to use the app's stable offer identifiers, so the
frontend never holds raw Stripe price IDs.

Acceptance Criteria:
- Given POST /payments/checkout with { offerKey, successUrl, cancelUrl }
- Then the backend resolves offerKey → CatalogOffer.stripePriceId
- And inactive or not-ready offers are rejected
- And checkout mode is derived from the resolved price (payment vs subscription)
- And the response returns the hosted Checkout URL

Points: 3
Priority: high
Assignee: forLoopDeveloper
Dependencies: Stories 2a, 2d
```

**Story 2c: Stripe webhook with raw body verification**

```
Title: Stripe webhook route with raw body and signature verification

Description:
As an operator, I want verified Stripe webhook events to drive local payment
state, so payments are recorded from Stripe truth, not redirect signals.

Acceptance Criteria:
- Given POST /webhooks/stripe mounted with express.raw() BEFORE express.json()
- When checkout.session.completed arrives with a valid Stripe-Signature
- Then stripe.webhooks.constructEvent() verifies it and a payment record is upserted
- And invalid signatures return 400
- And checkout.session.expired marks the payment expired

Points: 3
Priority: high
Assignee: forLoopDeveloper
Dependencies: Story 2b (payment model)
```

**Story 2d: Stripe client bootstrap from sprint secrets**

```
Title: stripeService fetches STRIPE_SECRET_KEY / STRIPE_WEBHOOK_SECRET from server_lambda

Description:
As a developer, I want the backend Stripe client built from the sprint secrets
API at cold start, so no Stripe secret exists in code or build artifacts.

Acceptance Criteria:
- Given SERVER_LAMBDA_URL, FORLOOP_SPRINT_ID, FORLOOP_API_TOKEN (secrets:read)
- When stripeService initializes
- Then it fetches sprint secrets over HTTPS and caches them in memory
- And getStripeClient() builds the SDK client from STRIPE_SECRET_KEY (sk_)
- And getWebhookSecret() returns STRIPE_WEBHOOK_SECRET

Points: 2
Priority: high
Assignee: forLoopDeveloper
Dependencies: Story 0a
```

#### Phase 3 Stories (Developer) — Frontend

**Story 3a: Dynamic pricing page**

```
Title: Pricing page renders the runtime catalog (no static price cards)

Description:
As a shopper, I want pricing rendered from the synced catalog with category
grouping and one-time/monthly/yearly offers, so the storefront always matches
the catalog.

Acceptance Criteria:
- Given GET /catalog/products
- Then the pricing page renders products, offers (amount, interval, trial), badges
- And active promotions are displayed where applicable
- And NO VITE_STRIPE_PRICE_* env vars are read (removed from the template)
- And archived/not-ready items never render

Points: 3
Priority: high
Assignee: forLoopDeveloper
Dependencies: Story 2a
```

**Story 3b: Checkout page (offerKey)**

```
Title: /checkout?offerKey=… page that posts offerKey to the backend

Description:
As a shopper, I want to reach Stripe-hosted checkout from a pricing card, so
the app never handles card data.

Acceptance Criteria:
- Given /checkout?offerKey=pro-monthly
- Then POST /payments/checkout sends { offerKey, successUrl, cancelUrl }
- And the user is redirected to the returned hosted checkout URL
- And the session_id template in successUrl resolves after return
- And a missing/invalid offerKey produces a clear error

Points: 2
Priority: high
Assignee: forLoopDeveloper
Dependencies: Stories 3a, 2b
```

**Story 3c: Success page + Stripe.js bootstrap**

```
Title: Success page polls payment status; Stripe.js initializes from the publishable key

Description:
As a customer, I want payment confirmation after returning from Stripe, with
Stripe.js initialized from deployment config.

Acceptance Criteria:
- Given /success?session_id=xxx
- Then GET /payments/status/:sessionId shows paid/pending/failed states
- And src/lib/stripe.ts loads Stripe.js from VITE_STRIPE_PUBLISHABLE_KEY only
- And no other Stripe IDs appear in frontend build config

Points: 2
Priority: medium
Assignee: forLoopDeveloper
Dependencies: Story 3b
```

#### Phase 4 Stories (Devops)

**Story 4a: Runtime + build env configuration**

```
Title: Configure Lambda env vars and the publishable-key delivery

Description:
As a devops engineer, I want the backend to reach server_lambda and the
frontend to bootstrap Stripe.js, without any Stripe secret in CI or the repo.

Acceptance Criteria:
- Given infra/project/main.tf
- Then SERVER_LAMBDA_URL, FORLOOP_SPRINT_ID, FORLOOP_API_TOKEN
      (scopes secrets:read + catalog:admin, sensitive) are set on the Lambda
- And FORLOOP_API_TOKEN comes from the deploy config API (broker-minted
      system token bound to the sprint owner), NOT from repo GitHub Actions
      secrets — the user repo needs zero repo secrets for ForLoop
- And ADMIN_API_TOKEN (+ ADMIN_CATALOG_SCOPES) protects /admin/catalog
- And the sprint secrets hold STRIPE_PUBLISHABLE_KEY (the public pk_ value,
      stored like STRIPE_SECRET_KEY — not committed to forloop.json)
- And deploy.yml passes only VITE_STRIPE_PUBLISHABLE_KEY (from the deploy
      config API, which reads the sprint secret at deploy time; empty/null
      when the project has no Stripe integration)
- And no VITE_STRIPE_PRICE_* variables remain in CI or the frontend

Points: 2
Priority: high
Assignee: forLoopDevops
Dependencies: Story 0a
```

#### Phase 5 Stories (Tester)

**Story 5a: Backend unit tests**

```
Title: Unit tests for offerKey checkout resolution and webhook verification

Description:
As a tester, I want backend unit tests that prove offerKey resolves against
ready catalog rows and webhook signatures are verified, so regressions to the
legacy priceId flow are caught.

Acceptance Criteria:
- Given a CatalogOffer row (ready) the checkout resolves its stripePriceId
- And inactive/not-ready offers are rejected
- And constructEvent is called for webhook verification (mock SDK)
- And invalid signatures produce 400

Points: 3
Priority: medium
Assignee: forLoopTester
Dependencies: Phase 2 stories
```

**Story 5b: E2E stubs**

```
Title: Playwright E2E stub for offerKey checkout

Description:
As a tester, I want an E2E stub at tests/e2e/story_stripe_checkout.spec.ts that
posts an offerKey and expects a hosted Stripe URL, so post-deploy verification
covers the real contract.

Acceptance Criteria:
- Given a deployed backend, POST /payments/checkout with a known offerKey
- Then result.data.url points at https://checkout.stripe.com
- And a missing offerKey returns 400

Points: 2
Priority: medium
Assignee: forLoopTester
Dependencies: Phase 2+3 stories
```

**Story 5c: Post-deploy verification**

```
Title: Post-deploy E2E verification in Stripe test mode

Description:
As a tester, I want the deployed app verified end-to-end with Stripe test
cards, including webhook processing.

Acceptance Criteria:
- Given the deployed frontend/backend URLs
- Then the pricing page renders synced offers
- And checkout redirects to Stripe (test card 4242 4242 4242 4242)
- And the webhook records the payment locally
- And the admin portal shows the completed sync job

Points: 3
Priority: medium
Assignee: forLoopTester
Dependencies: All prior phases
```

## Summarized Story List

| # | Title | Agent | Points | Depends On |
|---|-------|-------|--------|------------|
| 0a | Store Stripe keys (sk_ only) via secrets API | Planner | 1 | — |
| 0b | Canonical product catalog spec | Planner | 2 | — |
| 1a | Admin catalog authoring (change-sets) | Developer | 3 | 0a |
| 1b | Bulk import workspace (import batches) | Developer | 3 | 1a |
| 1c | First catalog load: preview → apply | Developer | 2 | 1a, 1b |
| 1d | Admin sync jobs/retry views | Developer | 2 | 1a |
| 2a | Runtime catalog read APIs | Developer | 2 | 1c |
| 2b | Checkout by offerKey | Developer | 3 | 2a, 2d |
| 2c | Webhook raw body + verification | Developer | 3 | 2b |
| 2d | stripeService (secrets via server_lambda) | Developer | 2 | 0a |
| 3a | Dynamic pricing page | Developer | 3 | 2a |
| 3b | Checkout page (?offerKey=) | Developer | 2 | 3a, 2b |
| 3c | Success page + Stripe.js bootstrap | Developer | 2 | 3b |
| 4a | Lambda env vars + publishable-key via deploy config API | Devops | 2 | 0a |
| 5a | Backend unit tests | Tester | 3 | Phase 2 |
| 5b | E2E stubs (offerKey) | Tester | 2 | Phase 2+3 |
| 5c | Post-deploy verification | Tester | 3 | All |

**Total estimated story points: ~37**

## Plan Deliverables

**Only produce these files when the user explicitly requests payment features.**
Do NOT create Stripe plan files for projects without payment requirements.

After gathering requirements and getting user confirmation, produce these files
in `~/.forloop/sprint-{id}/plan/`:

| File | Content |
|------|---------|
| `stripe-product-catalog.json` | **Primary.** Canonical desired-state catalog (doc 04 schema) for the sync pipeline |
| `stripe-product-catalog.md` | Human-readable markdown for user review |
| `stripe-story-breakdown.md` | Story list with dependencies and point estimates |

Upload all files to the space S3 bucket via `forloopSyncLocalToS3(sprintId={id})`.

**Critical:** The planner filesystem is not persistent (Lambda ephemeral storage).
Always upload files to S3 after writing them.

### Admin Portal Is The Primary Product Surface

Plan around this from the start — it is NOT a post-sync add-on:

- **Admin portal** = authoring + import + preview + apply surface (change-sets
  and import batches, see
  `docs/user_application_development/09-stripe_catalog_admin_mutation_flow.md`
  and `docs/user_application_development/12-stripe_catalog_sprint_space_product_management.md`).
- **User backend** = the orchestration client; it mediates to `server_lambda`
  with a short-lived service token (scopes `catalog.preview/apply/read/retry`),
  never exposing secrets or Stripe to the browser.
- **server_lambda + control plane** = the actual sync engine: preview first,
  then Stripe apply, then user-DynamoDB apply.
- **Sprint space** = readiness and support: versions show setup checks (Stripe
  secret, token scopes), sync job monitoring, and deep links into the admin
  portal. Never plan a second authoring UI there.
- Delete = archive (never hard delete). Preview always precedes Stripe-backed
  changes.

## Knowledge Capture

Record these decisions in `~/.forloop/sprint-{id}/knowledge/`:

- Stripe mode (test/live)
- Key storage method (server_lambda secrets API; secret key is `sk_`, NOT `rk_`)
- Canonical catalog keys (productKeys/offerKeys/promotionKeys)
- Checkout approach (hosted redirect; `offerKey` contract)
- Currency and pricing model
- Webhook URL pattern

## References

- [Guide User Through Stripe Account & Key Setup](references/keys-from-user.md) — Dashboard navigation, registration, key formats (sk_ required)
- [SSM Secret Flow (Create → Store → Retrieve)](references/secret-flow.md) — How keys flow from user to Lambda
- [Product Catalog Spec Template](references/product-catalog-spec.md) — Canonical catalog spec format (doc 04)
- [Stripe Integration Developer Skill](https://github.com/forloop/forloop-opencode-plugin-developer/blob/main/skills/stripe-integration/SKILL.md) — What the developer agent sees
- [Stripe Official Skills](https://docs.stripe.com/skills) — Always read before planning