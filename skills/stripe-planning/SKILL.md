---
name: stripe-planning
description: >
  Plan Stripe payment integration for ForLoop projects. Covers: gathering
  Stripe API keys and product/pricing requirements from the user, organizing
  a product catalog spec, breaking the integration into implementable
  stories (Stripe setup → Backend → Frontend → Testing), and producing
  plan deliverables. This is a PLANNING-ONLY skill.
  Use when: the user wants to add payment features to their ForLoop project,
  mentions "Stripe", "payments", "checkout", "subscriptions", "pricing plans",
  or "billing". Also use when the user provides Stripe API keys.
  DO NOT use when: implementing Stripe code (delegate to developer agent
  with stripe-integration skill), general space planning without payments
  (use sprint-planning), or estimating story points (use story-points).
license: MIT
metadata:
  version: "1.0.0"
  category: planning
  sources:
    - Stripe official skills (docs.stripe.com/skills)
    - ForLoop project-base template (.forloop/template/)
    - AWS SSM Parameter Store
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

## When to Use

- User says they want to accept payments in their ForLoop project
- User provides Stripe API keys or mentions they have a Stripe account
- User asks for "checkout", "subscriptions", "pricing plans", "billing"
- Planning a project that involves paid features, plans, or e-commerce

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
Dashboard navigation paths, test mode setup, and restricted key creation.

| What to Ask | Why |
|-------------|-----|
| Do you have a Stripe account? | If no, guide to stripe.com/register |
| Do you have your Stripe **secret key** and **publishable key**? | Required for backend (secret) and frontend (publishable) |
| Are you using test mode or live mode? | Determines `sk_test_` vs `sk_live_` |
| Do you have a **restricted API key** with minimal permissions? | Better than full secret key; Stripe best practice |

**How keys flow through the system:** The planner must understand this chain
so it can explain key security to the user and create the right stories:

```
User provides keys → Planner stores via PUT /api/opencode/sprints/:id/secrets/:key
                              │
User asks "how are my    ←── Planner explains: ←── server_lambda encrypts
keys protected?"          "server_lambda handles  and stores in SSM
                           all SSM — the project   (SecureString)
                           Lambda never touches
                           AWS directly."
                                                       │
                                           Developer writes code to fetch
                                           from server_lambda API at
                                           Lambda cold start
```

See `references/secret-flow.md` for the full SSM create/retrieve lifecycle
diagram and the planner's talking points for security questions.

**Important:** The planner never stores or logs keys. Note only that "keys are
available" in the knowledge file. Key gathering guide: `references/keys-from-user.md`.
SSM flow reference: `references/secret-flow.md`.

### Secret Key Names (CONTRACT WITH DEVELOPER)

The planner MUST store secrets using these exact key names. The developer agent
will retrieve them using the same names. These names are the **contract** between
agents — changing them breaks the integration.

| Secret Key Name | What to Store |
|-----------------|---------------|
| `STRIPE_SECRET_KEY` | The user's Stripe secret key (`sk_test_...`) or restricted key (`rk_test_...`) |
| `STRIPE_WEBHOOK_SECRET` | The webhook signing secret (`whsec_...`) — collected after webhook endpoint is created |

**Store via:**
```
PUT /api/opencode/sprints/{sprintId}/secrets/STRIPE_SECRET_KEY
PUT /api/opencode/sprints/{sprintId}/secrets/STRIPE_WEBHOOK_SECRET
```

**Do NOT:** add prefixes, suffixes, environment suffixes (dev/prd), or rename these keys.
The developer agent's `stripeService.ts` looks for exactly `STRIPE_SECRET_KEY`.

### Phase B: Product Catalog

This is the core of Stripe planning. The user may sell **physical/digital
products** (one-time purchase), **services/subscriptions** (recurring), or
both. Ask about each category separately.

**Step 1 — Identify what they sell:**

| Question | Purpose |
|----------|---------|
| Do you sell one-time products (items bought once)? | E.g., "e-book for $9.99", "t-shirt for $25" |
| Do you sell subscription services (recurring billing)? | E.g., "Pro plan $29/month", "weekly coaching" |
| Or both? | Many businesses mix both: a setup fee (one-time) + monthly plan (recurring) |

**Step 2 — For each item/plan, elicit these fields:**

| What to Ask | Examples |
|-------------|----------|
| **Product/plan name** | "Pro Plan", "E-Book Bundle", "Premium Theme" |
| **One-time or recurring?** | One-time purchase vs. monthly/yearly/weekly subscription |
| **Price and currency** | $49 USD, €29 EUR, ¥2900 JPY |
| **Any trial period (recurring only)?** | "14-day free trial" |
| **Multiple billing intervals (recurring only)?** | Monthly AND annual for same plan |
| **Any usage-based pricing?** | "Pay per API call" — routes to Metronome, not Stripe Prices |

**Step 3 — Classify and organize:**

Divide the catalog into two groups. The devops agent creates each as
the appropriate Stripe Price type:

| Group | Stripe Price Type | Checkout Mode |
|-------|------------------|---------------|
| One-time products | Price with NO `recurring` field | `mode: payment` |
| Subscription services | Price WITH `recurring: { interval }` | `mode: subscription` |

The backend auto-detects the correct mode by fetching the Price from Stripe
(`stripe.prices.retrieve()`) before creating the Checkout Session.

Organize the answers into a **product catalog spec**. See
`references/product-catalog-spec.md` for the full template.

### Phase C: Checkout Flow

| What to Ask | Notes |
|-------------|-------|
| Stripe-hosted Checkout (redirect) or embedded? | Hosted is simpler, embedded more customizable |
| What happens after payment? | Success URL (thank-you page), cancel URL (back to pricing) |
| Need to collect customer info beyond email? | Shipping address? Tax ID? |
| Any post-purchase actions? | Grant access, send email, provision account |

### Phase D: Environment & Infrastructure

| What to Ask | Notes |
|-------------|-------|
| Tenant ID and project name? | Already known from space context, confirm |
| Dev vs. production webhook URLs? | `api.{tenant}.forloop.cc/{env}/{project}/webhooks/stripe` |

## Product Catalog Specification

After gathering requirements, produce a product catalog spec. This is the single
source of truth that the devops agent uses to create Products and Prices in
Stripe via the API.

**The planner writes `stripe-product-catalog.json` as the primary format.** The
devops agent parses this JSON directly — no markdown parsing. A companion `.md`
file is generated for user review.

**The planner filesystem is ephemeral (Lambda-based).** After writing files
locally, upload to S3 via `forloopSyncLocalToS3(sprintId={id})`. The devops
agent downloads them from S3.

### Structure of a Product Catalog (JSON)

```json
{
  "project": "my-saas-app",
  "stripeMode": "test",
  "sprintId": 42,
  "createdAt": "2026-08-09T14:00:00Z",
  "products": [
    {
      "name": "Pro Plan",
      "type": "recurring",
      "description": "Full access to all Pro features",
      "metadata": { "product_tier": "pro" },
      "prices": [
        { "nickname": "Pro Monthly", "unit_amount": 2900, "currency": "usd",
          "recurring": { "interval": "month", "trial_period_days": 14 } },
        { "nickname": "Pro Yearly", "unit_amount": 29000, "currency": "usd",
          "recurring": { "interval": "year" } }
      ]
    },
    {
      "name": "One-Time Setup",
      "type": "one_time",
      "description": "Professional setup and configuration",
      "metadata": { "product_type": "one_time" },
      "prices": [
        { "nickname": "Setup Service", "unit_amount": 49900, "currency": "usd" }
      ]
    }
  ]
}
```

### Stripe Entity Relationship

```
Product (the "what": "Pro Plan")
  └── Price (the "how much": $29/mo, $290/yr, €25/mo)
        └── Checkout Session (the "who buys": customer + payment method)
              └── PaymentIntent (settlement)
```

**Key rule for the planner:** One Product per plan/ tier. Multiple Prices on the
same Product only for variants of the same plan (monthly vs. yearly, different
currencies). Do NOT put different tiers on the same Product.

### Spec Format

Create the catalog JSON file at
`~/.forloop/sprint-{id}/plan/stripe-product-catalog.json`. Also generate a
human-readable `stripe-product-catalog.md` for user review.

**Upload both to S3** — the planner filesystem is ephemeral:

```
forloopSyncLocalToS3(sprintId={id})
```

See `references/product-catalog-spec.md` for the complete JSON schema, markdown
template, and devops agent processing instructions.

## Story Breakdown

Break Stripe integration into these phases. Each phase becomes one or more
stories, assigned to the appropriate agent. Stories must be created in
dependency order.

### Story Dependency Map

```
Phase 0: Stripe Setup (Planner + Devops)
    │
    ├── Story 0a: Store Stripe keys via server_lambda secrets API (Planner)
    └── Story 0b: Create Products & Prices in Stripe (Devops)
         │
Phase 1: Backend (Developer)
    │
    ├── Story 1a: Create stripeService.ts (fetch secrets from server_lambda API)
    ├── Story 1b: Create payment model + service (DynamoDB)
    ├── Story 1c: Create payment controller + routes
    ├── Story 1d: Create webhook controller + raw body route
    └── Story 1e: Update app.ts for webhook pre-json handling
         │
Phase 2: Frontend (Developer)
    │
    ├── Story 2a: Add Stripe.js + React Stripe deps
    ├── Story 2b: Create checkout page (Stripe-hosted redirect)
    ├── Story 2c: Add checkout route to App.tsx
    └── Story 2d: Create success/cancel pages
         │
Phase 3: Infrastructure (Devops)
    │
    ├── Story 3a: Add server_lambda API env vars to Terraform (SERVER_LAMBDA_URL, FORLOOP_SPRINT_ID, FORLOOP_API_TOKEN)
    └── Story 3b: Add Stripe build-time env vars to deploy.yml (publishable key + price IDs)
         │
Phase 4: Testing (Tester)
    │
    ├── Story 4a: Write backend unit tests (mock Stripe client)
    ├── Story 4b: Write E2E test stubs for checkout flow
    └── Story 4c: Post-deploy E2E verification with Stripe test mode
```

### Story Templates

Use `forloopStoryTemplate` with `templateSlug="basic-task"` for all stories.
Here are the recommended story descriptions for each phase:

#### Phase 0 Stories (Planner)

**Story 0a: Store Stripe keys in space secrets via server_lambda API**

```
Title: Store Stripe API keys in space secrets via ForLoop secrets API

Description:
As a planner, I want the user's Stripe secret key and webhook signing
secret stored securely via the server_lambda secrets API, so that the
project Lambda can retrieve them at runtime without direct AWS SSM access.

Acceptance Criteria:
- Given the user's Stripe test keys are available
- When planner calls PUT /api/opencode/sprints/{id}/secrets/STRIPE_SECRET_KEY
- Then the secret is stored encrypted in SSM (server_lambda handles this)
- And PUT /api/opencode/sprints/{id}/secrets/STRIPE_WEBHOOK_SECRET also succeeds
- And secrets:write scope is present on the API token
- And keys are NOT committed to any git repository

Points: 1
Priority: high
Assignee: forLoopPlanner
```

#### Phase 0 Stories (Devops)

**Story 0b: Create Stripe Products and Prices**

```
Title: Create Stripe Products and Prices from product catalog spec

Description:
As a project owner, I want Products and Prices created in Stripe matching
the product catalog specification, so that the checkout flow can reference
real price IDs.

Acceptance Criteria:
- Given the product catalog JSON at plan/stripe-product-catalog.json
- When devops reads the file from space S3
- Then each product is created in Stripe with correct name/description/metadata
- And each price is created with correct unit_amount, currency, and interval (recurring only)
- And one-time products have NO recurring field (Stripe creates payment mode)
- And recurring products have the recurring block (Stripe creates subscription mode)
- And real Stripe price IDs are recorded in stripe-prices.json with env var mapping
- And stripe-prices.json is uploaded to the space S3 bucket

Points: 3
Priority: high
Assignee: forLoopDevops
Dependencies: Story 0a (keys must exist first)
```

#### Phase 1 Stories (Developer)

**Story 1a: Create Stripe service (fetch secrets from server_lambda API)**

```
Title: Create stripeService.ts that retrieves keys from server_lambda secrets API

Description:
As a developer, I want the Stripe Node.js SDK installed and a service that
fetches the secret key from the server_lambda secrets API at cold start,
so that the backend can make Stripe API calls without needing direct SSM access.

Acceptance Criteria:
- Given the backend directory
- When npm install is run
- Then package.json stripe dependency is installed (pre-configured in template)
- And src/services/stripeService.ts exports getStripeClient() as an async function
- And the service fetches secrets from SERVER_LAMBDA_URL/api/opencode/sprints/{id}/secrets
- And secrets are cached in memory after first fetch (singleton pattern)
- And the client uses the latest Stripe API version (check Stripe skill doc)

Points: 2
Priority: high
Assignee: forLoopDeveloper
```

**Story 1b: Create payment model and service**

```
Title: Create payment DynamoDB model and paymentService.ts

Description:
As a developer, I want payment records stored in DynamoDB using the
existing OneTable single-table design, so that completed payments are
persisted and queryable.

Acceptance Criteria:
- Given the existing DynamoDB table (pk/sk single-table)
- When paymentService.create() is called with checkout session data
- Then a payment record is stored with pk=payment#{id}, sk=payment#
- And the record includes stripeId, amount, currency, status, customerEmail
- And paymentService.findByStripeId() retrieves the payment
- And paymentService.updateStatus() updates the payment status

Points: 3
Priority: high
Assignee: forLoopDeveloper
Dependencies: Story 1a
```

**Story 1c: Create payment controller and routes**

```
Title: Create payment controller and /payments routes

Description:
As a developer, I want POST /payments/checkout and GET /payments/status/:id
endpoints, so that the frontend can create Stripe Checkout Sessions and
check payment status.

Acceptance Criteria:
- Given a valid priceId, successUrl, and cancelUrl
- When POST /payments/checkout is called
- Then a Stripe Checkout Session is created
- And the response returns { success: true, data: { url: "https://checkout.stripe.com/..." } }
- When GET /payments/status/:sessionId is called
- Then the response returns the session payment_status

Points: 2
Priority: high
Assignee: forLoopDeveloper
Dependencies: Story 1a
```

**Story 1d: Create Stripe webhook handler with raw body**

```
Title: Create Stripe webhook controller and route with raw body handling

Description:
As a developer, I want Stripe webhook events (.checkout.session.completed,
etc.) verified and processed, so that payments are recorded in DynamoDB
when Stripe confirms them.

Acceptance Criteria:
- Given a Stripe webhook POST with valid Stripe-Signature header
- When the webhook endpoint receives the raw body
- Then stripe.webhooks.constructEvent() verifies the signature
- And checkout.session.completed events persist payment records via paymentService
- And invalid signatures return 400
- And the route uses express.raw() before express.json()

Points: 3
Priority: high
Assignee: forLoopDeveloper
Dependencies: Stories 1a, 1b
```

**Story 1e: Update app.ts for webhook ordering**

```
Title: Update app.ts to mount webhook route before express.json()

Description:
As a developer, I want the Stripe webhook route mounted before
express.json() middleware, so that the raw body is preserved for
signature verification while all other routes use JSON parsing.

Acceptance Criteria:
- Given the Express app in src/app.ts
- When the app is created
- Then /webhooks/stripe is mounted with express.raw() before express.json()
- And /payments routes are mounted on the router after express.json()
- And health and user routes continue to work normally

Points: 1
Priority: high
Assignee: forLoopDeveloper
Dependencies: Stories 1c, 1d
```

#### Phase 2 Stories (Developer)

**Story 2a: Add frontend Stripe dependencies**

```
Title: Add @stripe/react-stripe-js and @stripe/stripe-js dependencies

Description:
As a developer, I want Stripe.js and React Stripe.js installed in the
frontend, so that the checkout page can use Stripe Elements.

Acceptance Criteria:
- Given the frontend directory
- When npm install is run
- Then package.json @stripe/react-stripe-js and @stripe/stripe-js deps are installed (pre-configured in template)
- And src/lib/stripe.ts exports getStripe() that calls loadStripe()
- And getStripe() reads VITE_STRIPE_PUBLISHABLE_KEY from env

Points: 1
Priority: medium
Assignee: forLoopDeveloper
```

**Story 2b: Create checkout page**

```
Title: Create checkout page with Stripe hosted checkout flow

Description:
As a shopper, I want to click "Subscribe" on the pricing page and be
redirected to Stripe's secure checkout, so that I can enter my payment
details safely.

Acceptance Criteria:
- Given a user visits /checkout
- When they click the checkout button
- Then POST /payments/checkout is called with the appropriate priceId
- And the user is redirected to the Stripe Checkout URL
- And on the success URL, the session_id query param is preserved
- And errors are displayed to the user if checkout creation fails

Points: 3
Priority: medium
Assignee: forLoopDeveloper
Dependencies: Story 2a, and Story 1c (backend /payments/checkout must exist)
```

**Story 2c: Add checkout route to App.tsx**

```
Title: Add /checkout route to React Router

Description:
As a developer, I want the checkout page accessible at /checkout, so that
pricing pages can link to it.

Acceptance Criteria:
- Given the React Router in App.tsx
- When navigating to /checkout
- Then the CheckoutPage component renders

Points: 1
Priority: medium
Assignee: forLoopDeveloper
Dependencies: Story 2b
```

**Story 2d: Create success page and pricing return flow**

```
Title: Create payment success page and pricing return flow

Description:
As a customer, I want to see a confirmation page after successful payment
or return to pricing if I cancel, so that I know the transaction status.

Acceptance Criteria:
- Given a user returns from Stripe with session_id=xxx
- When /success?session_id=xxx loads
- Then the page calls GET /payments/status/:sessionId
- And displays "Payment successful" or "Payment pending" based on status
- Given a user cancels on the Stripe checkout page
- Then Stripe redirects them back to /pricing
- And the pricing page lets them choose another plan

Points: 2
Priority: medium
Assignee: forLoopDeveloper
Dependencies: Story 2c, and Story 1c (backend status endpoint)
```

#### Phase 3 Stories (Devops)

**Story 3a: Add server_lambda API env vars to Terraform**

```
Title: Add server_lambda API environment variables to Terraform lambda_environment

Description:
As a devops engineer, I want SERVER_LAMBDA_URL, FORLOOP_SPRINT_ID, and
FORLOOP_API_TOKEN passed to the Lambda via Terraform, so the backend can
fetch secrets from the server_lambda's secrets API at runtime.

Acceptance Criteria:
- Given infra/project/main.tf
- When lambda_environment is configured
- Then SERVER_LAMBDA_URL is set (points to the ForLoop server Lambda)
- And FORLOOP_SPRINT_ID is set to the current space ID
- And FORLOOP_API_TOKEN is set (with secrets:read scope) and marked sensitive=true
- And no SSM IAM policy is needed (server_lambda handles SSM access)

Points: 2
Priority: high
Assignee: forLoopDevops
```

**Story 3b: Add Stripe build-time env vars to CI/CD**

```
Title: Add VITE_STRIPE_PUBLISHABLE_KEY and VITE_STRIPE_PRICE_* to frontend build

Description:
As a devops engineer, I want the Stripe publishable key and all real Stripe
price IDs set as Vite build-time environment variables in deploy.yml, so
the frontend PricingPage can reference real Stripe price IDs after build.

Acceptance Criteria:
- Given the deploy.yml workflow
- When the frontend build step runs
- Then VITE_STRIPE_PUBLISHABLE_KEY is set from GitHub Action Variables
- And VITE_STRIPE_PRICE_* vars are set for each product/plan from stripe-prices.json
- And the built frontend PricingPage shows the correct priceId per plan
- And products without a configured priceId are hidden
- And GitHub Variables are used (not Secrets — price IDs are not sensitive)

Points: 1
Priority: medium
Assignee: forLoopDevops
```

#### Phase 4 Stories (Tester)

**Story 4a: Write backend unit tests**

```
Title: Write backend unit tests for Stripe services and controllers

Description:
As a tester, I want unit tests for stripeService, paymentController, and
stripeWebhookController, so that Stripe integration logic is verified
before deployment.

Acceptance Criteria:
- Given Stripe SDK is mocked with jest.mock('stripe')
- When paymentController.createCheckoutSession() runs
- Then a mocked checkout session URL is returned
- When stripeWebhookController handles a valid event
- Then constructEvent is called and payment is recorded
- When signature is invalid
- Then 400 is returned
- And test coverage for Stripe files is >= 80%

Points: 3
Priority: medium
Assignee: forLoopTester
Dependencies: Phase 1 stories
```

**Story 4b: Write E2E test stubs**

```
Title: Write Playwright E2E test stubs for checkout flow

Description:
As a tester, I want E2E test stubs at tests/e2e/story_stripe_checkout.spec.ts,
so that the post-deploy verification can validate the checkout flow.

Acceptance Criteria:
- Given a deployed backend with DEPLOYED_API_URL
- When the stub creates a checkout session via POST /payments/checkout
- Then response.status is 200 and response.data.url is non-null
- And the test verifies the returned URL points to Stripe's checkout domain
- And the file name matches the existing story_*.spec.ts Playwright pattern

Points: 2
Priority: medium
Assignee: forLoopTester
Dependencies: Phase 1 and 2 stories
```

**Story 4c: Post-deploy E2E verification**

```
Title: Post-deploy E2E verification of Stripe checkout flow

Description:
As a tester, I want to verify the deployed checkout flow end-to-end using
Stripe test mode, so that payment collection is confirmed to work in
production-like conditions.

Acceptance Criteria:
- Given the deployed frontend and backend URLs
- When E2E tests run via [e2e story] commit tag
- Then the checkout page loads and displays the checkout button
- And clicking checkout redirects to Stripe (stripe.com domain)
- And test uses Stripe test card numbers (4242 4242 4242 4242)
- And webhook endpoint receives and processes the test event

Points: 3
Priority: medium
Assignee: forLoopTester
Dependencies: All Phase 1, 2, and 3 stories
```

## Summarized Story List

| # | Title | Agent | Points | Depends On |
|---|-------|-------|--------|------------|
| 0a | Store Stripe keys via secrets API | Planner | 1 | — |
| 0b | Create Products & Prices in Stripe | Devops | 3 | 0a |
| 1a | Create stripeService.ts (server_lambda API) | Developer | 2 | — |
| 1b | Payment model + service (DynamoDB) | Developer | 3 | 1a |
| 1c | Payment controller + routes | Developer | 2 | 1a |
| 1d | Webhook controller + raw body route | Developer | 3 | 1a, 1b |
| 1e | Update app.ts for webhook ordering | Developer | 1 | 1c, 1d |
| 2a | Frontend Stripe.js dependencies | Developer | 1 | — |
| 2b | Checkout page | Developer | 3 | 2a, 1c |
| 2c | Add /checkout route to App.tsx | Developer | 1 | 2b |
| 2d | Success page + pricing return flow | Developer | 2 | 2c, 1c |
| 3a | Terraform lambda_environment (API vars) | Devops | 2 | 0a |
| 3b | Stripe build-time env vars (publishable key + price IDs) in deploy.yml | Devops | 1 | — |
| 4a | Backend unit tests | Tester | 3 | Phase 1 |
| 4b | E2E test stubs | Tester | 2 | Phase 1+2 |
| 4c | Post-deploy E2E verification | Tester | 3 | All |

**Total estimated story points: ~31**

### Simplified Story List (Minimal Viable Stripe)

For projects needing only basic one-time payments (no subscriptions, no multi-plan):

| # | Title | Agent | Points |
|---|-------|-------|--------|
| 0a | Store Stripe keys via secrets API | Planner | 1 |
| 0b | Create Products & Prices in Stripe | Devops | 3 |
| 1a | Create stripeService.ts (server_lambda API) | Developer | 2 |
| 1b | Payment model + service (DynamoDB) | Developer | 3 |
| 1c | Payment controller + routes | Developer | 2 |
| 1d | Webhook controller + raw body route | Developer | 3 |
| 1e | Update app.ts for webhook ordering | Developer | 1 |
| 2a-2d | Frontend checkout (combined) | Developer | 5 |
| 3a-3b | API env vars + Stripe build-time vars | Devops | 3 |
| 4a-4b | Testing (combined) | Tester | 3 |

**Minimal total: ~26 points**

## Plan Deliverables

**Only produce these files when the user explicitly requests payment features.**
Do NOT create Stripe plan files for projects without payment requirements.

After gathering requirements and getting user confirmation, produce these files
in `~/.forloop/sprint-{id}/plan/`:

| File | Content |
|------|---------|
| `stripe-product-catalog.json` | **Primary.** Structured JSON for devops agent Stripe API calls |
| `stripe-product-catalog.md` | Human-readable markdown for user review |
| `stripe-story-breakdown.md` | Story list with dependencies and point estimates |

Upload all three to the space S3 bucket via `forloopSyncLocalToS3(sprintId={id})`.

**Critical:** The planner filesystem is not persistent (Lambda ephemeral storage).
Always upload files to S3 after writing them. The devops agent reads them from S3.

## Knowledge Capture

Record these decisions in `~/.forloop/sprint-{id}/knowledge/`:

- Stripe mode (test/live)
- Key storage method (server_lambda secrets API)
- Checkout approach (hosted vs embedded)
- Currency and pricing model
- Webhook URL pattern

## References

- [Guide User Through Stripe Account & Key Setup](references/keys-from-user.md) — Dashboard navigation, registration, key formats
- [SSM Secret Flow (Create → Store → Retrieve)](references/secret-flow.md) — How keys flow from user to Lambda
- [Product Catalog Spec Template](references/product-catalog-spec.md) — Full catalog spec format
- [Stripe Integration Developer Skill](https://github.com/forloop/forloop-opencode-plugin-developer/blob/main/skills/stripe-integration/SKILL.md) — What the developer agent sees
- [Stripe Official Skills](https://docs.stripe.com/skills) — Always read before planning
