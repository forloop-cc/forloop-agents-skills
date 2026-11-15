---
name: flc-commerce-planning
description: >
  Plan ForLoop FLC app commerce: an app sells virtual products or entitlements
  to ForLoop users, the buyer pays FLC from their USER wallet, and the app is
  credited in its APP wallet only after the app confirms fulfillment. Covers
  discovery, choosing FLC vs Stripe vs both per product, product/entitlement
  modeling, seller enablement, limits, refunds, withdrawals, fail-closed
  prerequisites, and the planner-to-developer story breakdown. This is a
  PLANNING-ONLY skill.
  Use when: the user wants their app to sell virtual products, digital goods,
  or entitlements for FLC; asks for FLC checkout; asks about app earnings,
  app-wallet withdrawal, or mixing FLC and Stripe products.
  DO NOT use when: charging other apps FLC per API call (use
  paid-app-to-app-planning), paying a ForLoop core service (use
  core-service-discovery), or planning Stripe/USD checkout with no FLC product
  (use stripe-planning).
license: MIT
compatibility: opencode
metadata:
  audience: planners
  workflow: app-flc-commerce
  version: "1.0.0"
triggers: app sells virtual products for FLC, FLC checkout, buyer USER wallet to app APP wallet, app commerce, app earnings withdrawal, FLC and Stripe products
---

# FLC Commerce Planning for ForLoop Apps

## Overview

Plan a ForLoop user-built app that sells virtual products to ForLoop users for
FLC. The buyer pays from their **USER wallet**; the app is credited in its
**APP wallet** only after the app confirms fulfillment. ForLoop hosts the buyer
confirmation and moves the money. The app owns its products and entitlement
logic; there is no platform product catalog.

This is a **planning-only** skill. Do not write application code, enable
commerce, accept seller terms, create products, or move money. The developer
agent uses `flc-commerce-integration` to implement the stories you create.

## What I do

I turn an “app sells products for FLC” request into a plan with four separate
parts:

1. **Product and rail decisions** — what is sold, the FLC price, who buys, what
   entitlement is delivered, and whether each product uses FLC, Stripe, or both
   (one rail per product).
2. **Seller setup** — app-owner enablement, seller terms, fulfillment path,
   limits, refund window, and withdrawal expectations. These are owner actions,
   not developer stories.
3. **App implementation stories** — products, entitlement hook, template
   commerce client/routes, signed fulfillment endpoint, store and success
   pages, tests, and the manifest `commerce` block.
4. **Fail-closed gates** — unsupported v1 shapes, missing platform/template
   prerequisites, and no direct ledger access.

The platform charges and settles. The developer never writes ledger entries and
never gets ledger internal credentials.

## When to use me

Use me when the user says any of:

- “My app should sell virtual products / digital goods / skins / credits /
  entitlements for FLC.”
- “Buyers pay with FLC from their ForLoop wallet.”
- “I want my app to earn FLC and withdraw it to my personal wallet.”
- “Add an FLC store, FLC checkout, or FLC purchase flow.”
- “My app sells some products for FLC and some for USD/Stripe.”

## When NOT to use me

Do **not** use me when:

- **Other apps pay this app FLC per API call.** That is seller-side paid
  app-to-app; use `paid-app-to-app-planning`. Its manifest root block is
  `billing`, not `commerce`.
- **This app pays ForLoop for a core service** (Scheduler, Notify, Search,
  Media, Realtime, Storage). That is core-service consumption; use
  `core-service-discovery`.
- **Every product is Stripe/USD only** (cards, subscriptions, pricing pages,
  checkout sessions). Use `stripe-planning`.
- The user wants cash-out, KYC, tax reporting, seller payouts outside ForLoop,
  buyer disputes, carts, multi-product orders, quantities greater than one,
  partial refunds, platform fees, marketplace discovery, reviews, or
  subscriptions paid in FLC. These are not v1; say so and keep them out of the
  plan.

## Fail closed before planning

Stop and tell the user which prerequisite is missing. Do not write a story that
guesses around it.

1. **Platform dev service exists.** `server_lambda_commerce` answers
   `POST /api/commerce/purchase-intents` with an app credential and
   `GET /api/commerce/orders/:orderId`. The approved contract is in
   `docs/forloop-ledger/2026-11-15-app-flc-commerce-design.md` and
   `docs/forloop-ledger/2026-11-15-commerce-platform-foundation.md`.
   Never invent a field, route, status, or error code.
2. **App template ships the commerce module.** The repository template has
   `backend/src/commerce/` (`flcCommerceClient`, `purchaseService`,
   `commerceController`, `productService`, `entitlementService`, `fulfillment`,
   `fulfillmentAuth`, `fulfillmentEvent`), the three commerce models,
   `backend/src/routes/commerce.ts`, and `docs/FLC_COMMERCE.md`. If the module is
   absent, Plan 3 has not landed; stop.
3. **Manifest `commerce` block is valid.** The template validator accepts:
   `{ "enabled": true, "endpoint": "/api/commerce/fulfillment" }`.
   `endpoint` is a path on the app’s own verified origin, never a full URL.
4. **Buyers can sign in with ForLoop.** The app uses the template ForLoop Login
   flow and its backend knows the buyer’s ForLoop user id. If not, plan ForLoop
   Login first; the purchase flow must never accept a payer id from the browser.
5. **The target is dev.** Prd is not planned, configured, or deployed without
   explicit approval. There is no `APP_COMMERCE_ENABLED` feature flag;
   availability is deployment timing plus per-app opt-in, and admin suspension
   is the kill switch.

If any item above is missing, write a short blocked note in the plan and return
to the user. Do not create stories that reference a nonexistent module or API.

## Discovery questions

Ask these as natural text, not the structured `question` tool. Wait for the
answers before writing stories.

| Question | What to record |
|---|---|
| What products are sold? | Names, stable `productId` values, descriptions, optional image URLs. |
| What is the FLC price of each product? | A positive integer per product. No decimals, tiers, or usage pricing in v1. |
| Who buys: an end user or another app? | v1 buyers are ForLoop users. “Another app buys” is paid app-to-app, not this skill; stop and reroute. |
| What is delivered, and how is the entitlement represented? | `CommerceEntitlement` with `ACTIVE`/`REVOKED`, an external reference, and the app feature it unlocks. |
| What is the refund window? | 0–30 days; default 14. Full-order refunds only. |
| What are the per-order and per-user limits? | Per-order max and UTC-day per-user cap. Defaults: 50,000 FLC per order and 200,000 FLC per user per day. The app may set lower limits. |
| Does the app also sell Stripe/USD products? | One rail per product. Mixed catalogs are allowed; mixed orders are not. |
| Does the owner want to withdraw app earnings to their personal wallet? | Yes/no. Withdrawal is owner-only, any available APP balance, `APP_WITHDRAWAL`. |
| What is the fulfillment path? | Default `/api/commerce/fulfillment`. It must be a path on the app’s verified origin. |
| Is the app personal or organization-owned? | Enablement and withdrawal are owner-only, including org-owned apps. |
| Is this dev only for now? | Prd requires explicit approval after dev E2E and security validation. |

## Choose the rail per product

**One product uses one payment rail. An order cannot mix rails.**

| Decision | Use when | Plan with |
|---|---|---|
| **FLC only** | Virtual product, one-time purchase, buyer is a ForLoop user, price is integer FLC. | This skill. |
| **Stripe only** | Cards, USD, subscriptions, trials, promotions, or any fiat pricing. | `stripe-planning` (and `stripe-integration` on the build side). |
| **Both, per product** | The app sells some FLC products and some Stripe products. Each product still has exactly one rail. | Load both skills. Put FLC products here and Stripe products in `stripe-planning`; do not dual-price a product. |

Rules:

- FLC commerce is one-time, quantity one, virtual goods only. Subscriptions,
  recurring billing, carts, quantities greater than one, physical shipping, and
  partial refunds are v1 non-goals.
- If a product must be sold for both FLC and USD, model it as two distinct
  products on two rails, never one product with two prices.
- If the user is unsure which rail fits, ask one direct question: “Should the
  buyer pay with FLC from their ForLoop wallet, or with a card through Stripe?”
  Do not choose for them.

## Product and entitlement model

The app owns its product records and entitlement logic. The platform stores an
order snapshot at purchase-intent time; later product edits do not change an
existing order.

App records:

- `CommerceProduct`: `productId` (unique per app), `name`, `description`,
  `priceFLC`, `active`, optional `imageUrl`, `metadata`, timestamps. Soft-delete
  by setting `active=false`; existing orders and entitlements remain valid.
- `CommercePurchase`: a local mirror keyed by the platform `orderId`; buyer,
  product, status, entitlement reference.
- `CommerceEntitlement`: buyer, product, order, status (`ACTIVE`/`REVOKED`),
  external reference, timestamps.

Plan product management through the existing Admin Resource Framework
(`backend/src/admin/adminResources.ts`), not a bespoke admin page. Product IDs
are stable; price changes affect new intents only.

## What the platform does vs what the app does

Platform (`server_lambda_commerce`):

- Seller enablement, seller terms, limits, refund window, fulfillment path.
- Purchase intents, the ForLoop-hosted checkout, and checkout tokens.
- Reservation, signed fulfillment call, settlement commit, retries, and
  `SETTLEMENT_FAILED` recovery.
- Full-order refunds and owner withdrawals through the ledger.
- Order records, daily spend accounting, admin suspension/force-refund.
- Emits `order.fulfill` and `order.refunded` to the app.

App (developer stories):

- Product records and product management.
- A purchase route that starts a purchase intent with the buyer’s ForLoop user
  id, the stored product snapshot, and an idempotency key.
- The signed fulfillment endpoint and the app-specific entitlement
  grant/revoke hook.
- The store, checkout redirect, success/error pages, and entitlement gates.
- Tests and the manifest `commerce` block.

The app must never write ledger entries, call ledger internal operations, or
receive ledger internal credentials. `server_lambda_commerce` is the only
ledger internal caller for these operations.

## Plan the owner actions separately

These are **not** developer stories. Put them in the plan with a named owner
(usually the app owner) and a completion check:

- Enable commerce for the app and accept the seller terms.
- Set the fulfillment path, per-order max, daily user cap, and refund window.
- Confirm the products and FLC prices the app will store.
- Fund the buyer’s wallet only for canary testing; do not build a platform
  top-up flow in the app.
- Confirm whether the owner wants withdrawals to their personal USER wallet.
- For org-owned apps, confirm the owner authority before planning withdrawal.
- Know the kill switch: a platform admin can suspend commerce for the app;
  suspension blocks new purchases but existing orders can still fulfill or
  refund.

Do not plan a platform product catalog, a seller onboarding UI, or a
marketplace. The app dashboard is the platform surface for order and earning
visibility; the app admin portal is for the app’s own products.

## Story breakdown

Create these stories with `forloopStoryTemplate` (`templateSlug: "basic-task"`)
and link each to the sprint context from `forloopSpaceSprintGet`. Use
`forloopStoryUpdate` to add the acceptance criteria below. Story points are
starting estimates; adjust with `story-points`.

1. **Enable app commerce and configure limits** — owner action, with a
   developer checklist item for the manifest `commerce` block. Acceptance:
   settings exist; seller terms accepted; `maxOrderFLC`, `dailyUserCapFLC`,
   `refundWindowDays`, and `fulfillmentPath` are set; disabling commerce blocks
   new intents but not refunds.
2. **Add app-side FLC product storage and app-admin product management** —
   developer. Acceptance: `CommerceProduct` records, active filtering, soft
   delete, admin CRUD through the Admin Resource Framework, and tests.
3. **Add the template commerce client and purchase routes** — developer.
   Acceptance: template module synced, not forked; `POST /api/commerce/purchases`
   reads the buyer from the ForLoop session, loads the stored product, sends
   `x-api-token` and `Idempotency-Key` to `POST /api/commerce/purchase-intents`,
   and returns the checkout URL; duplicate keys replay the same order.
4. **Add the fulfillment endpoint and entitlement hook** — developer.
   Acceptance: `POST /api/commerce/fulfillment` verifies the signed assertion
   (issuer, audience, environment, scope, signature, expiry), grants the
   entitlement idempotently, returns `{ externalOrderId, entitlementId }`, and
   handles `order.refunded` by revoking idempotently and returning
   `{ ok: true }`.
5. **Add store, checkout redirect, success page, and entitlement gating** —
   developer. Acceptance: active products render with FLC prices and “Buy with
   FLC”; purchase starts the intent and redirects to `checkoutUrl`; success
   verifies the order with the backend, never query parameters; cancel/error
   states exist; gated content requires an `ACTIVE` entitlement.
6. **Add tests and publish the manifest `commerce` block** — developer/tester.
   Acceptance: product, purchase, fulfillment, refund, idempotency, signature
   rejection, entitlement gate, and frontend state tests pass; the manifest
   validates and deploys; the dev canary E2E passes.

Do not create a story for “create products in the platform catalog.” No such
catalog exists.

## Limits, refunds, and withdrawals

Limits:

- Default per-order max: 50,000 FLC. The app may set a lower value.
- Default per-user daily cap: 200,000 FLC, UTC day. The app may set a lower
  value; the cap is enforced atomically by Postgres.
- The platform rejects an order above the limit; the app must show a clear
  error and not retry blindly.
- Insufficient buyer FLC is not an app error: checkout shows the shortfall and
  links to the existing Stripe FLC top-up, then the buyer returns to the same
  unexpired checkout intent.

Refunds:

- Full-order refunds only. No partial refunds in v1.
- Owner-initiated within the configured window (default 14 days, 0–30 allowed),
  or platform-admin override.
- `DEBIT APP / CREDIT USER` as `APP_REFUND`.
- Hard stop on insufficient APP balance: if the APP wallet cannot cover the
  refund, the order becomes `REFUND_FAILED` and remains retryable after the
  owner funds the APP wallet.
- After a successful refund, the platform sends `order.refunded`; the app must
  revoke the entitlement idempotently. A refund event failure never rolls back
  the buyer’s refund; the app must reconcile.

Withdrawals:

- Owner-only, including org-owned apps.
- The owner may transfer any available APP balance to their personal USER
  wallet as `APP_WITHDRAWAL`; no negative APP balance.
- Withdrawals are audited; the platform alerts above the 100,000 FLC
  large-withdrawal threshold.
- No cash-out, KYC, tax reporting, or seller payouts outside ForLoop in v1.

## What the developer must not do

- Never write ledger entries, call ledger internal operations, or handle ledger
  credentials.
- Never accept a payer user id, price, seller id, or product snapshot from the
  browser as authoritative.
- Never use the app credential in the browser.
- Never treat a 409 as fulfillment success; a replay must return 2xx with the
  same result.
- Never trust query parameters on the success page; verify the order with the
  backend.
- Never build a platform product catalog, a cart, subscriptions, partial
  refunds, or a marketplace.
- Never add `APP_COMMERCE_ENABLED` or any equivalent feature flag.

## Example

Example brief for a small app:

```text
App: Neon Skins
Buyer: ForLoop user signed in with ForLoop Login
Products:
- Neon skin, productId "skin-001", 500 FLC, virtual entitlement, FLC rail
- Pro pack, productId "pro-pack", USD 9.99 one-time, Stripe rail
Refund window: 14 days
Limits: 50,000 FLC per order / 200,000 FLC per user per day
Withdrawal: owner wants to move available APP FLC to their personal USER wallet
Fulfillment path: /api/commerce/fulfillment
Target: dev first; prd only after explicit approval
```

Example story acceptance criteria:

```text
Title: Add the fulfillment endpoint and entitlement hook

Given the platform posts order.fulfill with a valid signed assertion
When the app verifies issuer, audience, environment, scope, signature, and expiry
Then it grants the entitlement idempotently and returns
     { "externalOrderId": "<id>", "entitlementId": "<id>" }
And a duplicate order.fulfill returns the same entitlement without granting twice
And an invalid, expired, wrong-audience, wrong-environment, or wrong-scope
     assertion is rejected
And order.refunded revokes idempotently and returns { "ok": true }
```

## Checklist

- [ ] Products, stable productIds, integer FLC prices, and entitlement meaning
      confirmed.
- [ ] Buyer is a ForLoop user (not another app).
- [ ] Rail chosen per product: FLC only, Stripe only, or both per product; no
      mixed-rail order.
- [ ] Stripe products handed to `stripe-planning`; paid app-to-app requests
      rerouted to `paid-app-to-app-planning`.
- [ ] Refund window, per-order max, and daily cap confirmed.
- [ ] Withdrawal intent and owner authority confirmed.
- [ ] Fulfillment path is a path on the app’s verified origin.
- [ ] Platform and template prerequisites verified; no invented endpoints or
      fields.
- [ ] Owner actions separated from developer stories.
- [ ] Six-story breakdown created with acceptance criteria.
- [ ] No `APP_COMMERCE_ENABLED` flag, no platform catalog, no direct ledger
      writes, and no prd work without explicit approval.

## Knowledge capture

Record in `~/.forloop/sprint-{id}/knowledge/`:

- The rail decision per product and why.
- Product ids, names, FLC prices, and entitlement definitions.
- Refund window, per-order max, and daily cap.
- Fulfillment path and the app route that gates the entitlement.
- Owner enablement/terms/withdrawal decisions.
- The platform/template versions used and the dev canary evidence.
