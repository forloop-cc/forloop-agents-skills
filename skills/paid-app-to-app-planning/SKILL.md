---
name: paid-app-to-app-planning
description: >
  Plan ForLoop paid app-to-app capabilities where this app charges other apps
  FLC per API call. Use when the user asks to monetize an app API, make another
  app pay FLC to call it, add a paid capability, or set caller prices/caps.
  Covers target manifest pricing, caller policy/allowlist, owner-only
  connection/SpendGrant/wallet actions, caller integration work, and the prd
  global-flag gate. NOT for Stripe end-user checkout/subscriptions (use
  stripe-planning) or for paying a ForLoop core service (use
  core-service-discovery).
license: MIT
compatibility: opencode
metadata:
  audience: planners
  workflow: a2a-billing
  version: "1.0.0"
triggers: user wants other apps to pay FLC per API call, paid app-to-app, monetize app API, caller allowlist, SpendGrant
---

## What I do

I turn a seller-side monetization request into an implementable plan with three
separate workstreams:

1. **Target (seller) work** — declare the paid capability and price in
   `forloop-manifest.json`, expose the exact static endpoint, deploy, and verify
   provisioning.
2. **Owner actions** — target paid settings, caller connection, caller
   `SpendGrant`, and caller wallet funding. These are owner/UI actions; the
   planner and developer cannot mint them.
3. **Caller work** — only if another app must consume the capability: paid
   proxy/A2A integration, idempotency, error handling, and live verification.

The platform charges and settles automatically. The developer does not write
ledger or payment code for this feature.

## When to use me

Use me when the user says any of:

- "Make other apps pay FLC to call my API."
- "Charge 10 FLC per call for this endpoint."
- "Monetize my app's tool/agent."
- "Add a paid capability / paid app-to-app integration."
- "Set caller prices, allowlists, budgets, or spend caps."

Do **not** use me when:

- The user pays ForLoop for a core service (Scheduler, Notify, Search, Media,
  Realtime). That is core-service consumption; use `core-service-discovery`.
- The user wants end users to pay by Stripe, checkout, subscription, or pricing
  page. Use `stripe-planning`.
- The app only exposes a normal free A2A agent/API. Use
  `a2a-agent-card-dev` for planning; the developer's `a2a-agent-spec` authors
  the manifest.

## How to use me

### 1. Confirm this is seller-side paid app-to-app

Ask for the missing decisions; do not invent prices or limits:

- Which app is the **target** (earns FLC)?
- Which exact capabilities/tools are paid, and which static endpoint serves each?
- Price per successful call in integer FLC.
- Caller policy: `allowlist` (recommended for production) or `deny`; `any` only
  for a deliberately public app.
- Which caller apps are allowed, if using an allowlist?
- For each caller: per-call maximum, total budget, capability allowlist, and grant
  expiry.
- Which side funds the caller APP wallet, and who is the owner contact?
- Is this for dev now, or also prd? Prd paid app-to-app is globally off until a
  separate platform enablement review.

If the user only wants their own app to charge **end users**, stop: this is not
the paid app-to-app feature. Plan Stripe instead.

### 2. Verify the target surface is eligible

Use sprint context (`forloopSpaceSprintGet`) to check that the app has an A2A
manifest and that each paid route already exists or is in scope. Confirm the
target app public id from the app space/`forloop.json`; never invent it. Then
make the developer task explicit:

- Add a root `billing` block beside `tools` in `forloop-manifest.json`.
- Each capability names an existing `toolId` and one of that tool's exact
  `endpoints`; only exact static paths are supported in v1. No `{id}` or `:id`
  paid paths.
- `capabilityId` is the `toolId`; the proxy path, A2A metadata, and
  `SpendGrant.capabilityIds` use it. Plan one paid endpoint per tool in v1.
- `serviceCode` must be `app.<targetPublicId>.<toolId>`.
- The manifest's root `auth` block (a sibling of `application`, not nested)
  declares the scope callers need (for example `paid:summarize`). The paid
  caller is an app identity, so paid v1 requires `mode:"app"`; a `mode:"user"`
  paid target is not supported by the app-subject paid path.
- `unit` is `call`; `priceFLC` is a positive integer; `perUnits` is 1;
  `rounding` is `ceil`.
- `billing.enabled:false` or no `billing` block means no paid provisioning and
  all existing capabilities disabled. It is not an "ignore prices" switch.
- Bump the manifest `version` when price/capability changes.
- Keep the production API base in `application.baseUrl` and add
  `application.baseUrls.{dev,prd}`; the proxy resolves the per-environment
  entry first. Without a dev entry, a dev canary calls the prd base.
- Run `node scripts/validate-manifest.mjs` and commit the manifest with the
  route change.

Do not ask the developer to hand-write a price in code; the manifest is the
price authority.

### 3. Separate owner actions from stories

These are **not** developer stories. Put them in the plan as explicit owner
actions with a named owner:

- **Target settings:** first successful provisioning auto-sets
  `paidCallsEnabled=true` **and** the manifest `callerPolicy` only if the owner
  has never touched paid settings. If the owner has touched them, the owner must
  explicitly enable the target and set the caller policy/allowlist. Do not
  assume deploy turns it on. A metering failure disables all capabilities
  (`PAID_CAPABILITY_PROVISIONING_FAILED`); there is no fallback price.
- **Connection:** the caller app owner requests an active app-subject
  `A2AConnection` to the target with the required scope; the target owner
  approves it if approval is pending.
- **SpendGrant:** the caller app owner creates the grant for payer
  `APP:<callerPublicId>` → target, with capability ids, per-call max, total
  budget, and expiry.
- **Wallet:** the caller app owner funds the caller APP wallet. An empty wallet
  fails with `402 insufficient_balance` before the target is called.
- **Target policy:** the target owner must allow the caller. The allowlist is a
  list of caller app public ids (for example `app-a`); `any` is only for a
  deliberately public app.

If any owner action is missing, block the caller story; do not let the developer
guess a connection or grant.

### 4. Write the smallest story set

Example story set:

- **Developer — target paid capability:** add the `billing` block, exact
  endpoint, manifest version bump, validation, and deploy. Acceptance:
  provisioning succeeds; `PaidCapability` is enabled with the expected
  method/path and catalog version.
- **Owner — target settings and caller access:** confirm the target is enabled
  (or explicitly enable it), set policy/allowlist, create the caller connection,
  create the `SpendGrant`, and fund the caller wallet.
- **Developer — caller integration (only if in scope):** call the paid proxy or
  paid A2A send on the platform API base from the deploy environment
  (`FORLOOP_PLATFORM_URL`), not the target's base URL or the caller's tenant
  API, with the app credential and `Idempotency-Key`; take `<targetPublicId>`
  from the approved connection/grant/brief; handle 402/403/404/405/409/503; do
  not log the credential.
- **Tester — paid canary:** verify the target settings, connection, grant,
  wallet funding, one successful call, `PaidCall=settled`, both wallet changes,
  and one `PAID_TRANSFER`. Confirm a failed target call releases the hold and
  does not transfer. A charge is per **successful** call; a non-2xx target
  response releases the hold and transfers nothing. v1 has no refunds.

If the target endpoint does not exist yet, add a normal endpoint story first;
the paid manifest story depends on it.

### 5. Set environment expectations

- Dev has paid app-to-app enabled.
- Prd stays globally off until a separate platform review; deploying a paid
  target to prd does not make it charge yet.
- Enabling prd can activate every already-provisioned billing target whose paid
  settings were never touched. Plan a target audit and explicit per-target
  opt-in; never treat the global flag as a single-app switch.

### 6. Do not promise unsupported billing

- v1 is a fixed price per successful call. Do not plan per-token, per-byte,
  tiered, or usage-metered app-to-app pricing.
- v1 has no refunds. A failed target call releases the hold; a settled call is
  final. Do not plan an automatic refund or a manual wallet adjustment as the
  normal path.
- The target is paid only through the platform proxy/A2A path. A direct call to
  the target's base URL is not charged.

## Rules

- This skill is planning-only. Do not deploy, run curl, create connections,
  create grants, move funds, or edit the manifest yourself.
- Use `forloopStoryTemplate`/`forloopStoryUpdate` for stories and
  `forloopSpaceSprintGet` for sprint context. Never invent a sprint, app, or
  public id.
- Do not confuse seller-side paid app-to-app with paying a core service or with
  Stripe end-user checkout. If the user's intent is ambiguous, ask one direct
  question before planning.
- Never write a hardcoded API URL into a story. The platform supplies the base
  URL and app credential through the deploy environment.
- Contract changes (manifest, endpoint, scope) must land in the same developer
  story/commit.
- Explicitly record the owner actions and the prd global-flag gate in the plan;
  they are the usual reasons a paid launch silently does nothing.

## Checklist

- [ ] Target app public id, capabilities, exact static endpoints, and integer
      prices confirmed.
- [ ] Caller policy/allowlist and per-caller caps/budget/expiry confirmed.
- [ ] Manifest `billing` block and `serviceCode` rules included in a developer
      story.
- [ ] Target settings owner action called out, including the
      already-touched-settings case.
- [ ] Caller connection, SpendGrant, and wallet funding assigned to the owner.
- [ ] Caller proxy/A2A integration story includes idempotency and 402/403/409/503
      handling.
- [ ] Tester story covers provisioning, both wallets, `PaidCall`, and
      `PAID_TRANSFER`.
- [ ] Prd remains off until a separate global enablement review and target audit.
- [ ] No refunds, per-token pricing, or direct ledger code promised.
