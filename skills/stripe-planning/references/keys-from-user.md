# How to Guide User Through Stripe Account & Key Setup

This is the planner's guide for walking the user through Stripe setup. The
planner does NOT perform any of these actions — it explains them to the
user and collects the resulting keys (or confirms they exist).

## Stage 1: Does the User Have a Stripe Account?

### If NO — Guide Them to Register

```
First, you'll need a Stripe account. Here's how:

1. Go to https://stripe.com/register
2. Fill in: email, full name, country, password
3. Click "Create account"
4. You'll land in the Stripe Dashboard

It's free — Stripe only charges per-transaction fees (2.9% + $0.30
for US cards). No monthly fee.
```

**Important:** For development, the user should stay in **test mode**.
Test mode lets them simulate payments without real money. No bank
account or business verification is needed for test mode.

### If YES — Confirm Test Mode

```
Great! Are you in test mode? You can check in the Stripe Dashboard:

- Look at the top bar. It should say "Test mode" with a toggle.
- If it says "Live mode", flip the toggle to "Test mode".

We'll build everything in test mode first. We switch to live mode
only before production launch.
```

## Stage 2: Get Test API Keys

### Navigate to API Keys

```
To find your API keys:

1. In the Stripe Dashboard, click "Developers" in the left sidebar
2. Click "API keys" in the submenu
3. You'll see two keys in a table:

   ┌────────────────────┬─────────────────────────┐
   │ Publishable key     │ pk_test_xxxxxxxxxxxxxx  │ ← Starts with pk_test_
   │ Secret key          │ sk_test_xxxxxxxxxxxxxx  │ ← Starts with sk_test_
   └────────────────────┴─────────────────────────┘

4. Click "Reveal test key" next to the Secret key
5. Copy both keys
```

### Direct URL (for test mode)

```
Go directly to: https://dashboard.stripe.com/test/apikeys
```

### What the Planner Asks

```
Please share:
1. Your test publishable key (pk_test_...)
2. Your test secret key     (sk_test_...)

⚠️  We'll store the secret key securely in AWS — never committed to git.
```

### Key Format Validation (Planner Checks)

When the user provides keys, verify the format **silently** (don't log them):

```
sk_test_... →  Secret key (test mode)    ✓
pk_test_... →  Publishable key (test mode) ✓
sk_live_... →  Secret key (LIVE mode)      ⚠️  Warn: this is a live key!
rk_test_... →  Restricted key             ✗  NOT supported — ask for the full sk_ secret key
whsec_...   →  Webhook signing secret     ✓ (collected later, after deploy)
```

If a live key is provided, ask: "This appears to be a live key (sk_live_).
Are you sure you want to use live mode now? We strongly recommend starting
with test mode keys (sk_test_) during development."

If a restricted key (`rk_`) is provided, explain why it won't work and ask
for the full secret key instead:

```
The ForLoop catalog sync pipeline needs the FULL secret key (sk_), not a
restricted key. The platform creates and manages Products, Prices, Coupons,
and Promotion Codes in your Stripe account on your behalf, which restricted
keys can't do. Your key is stored encrypted server-side and only used for
that synchronization and for backend checkout/webhook operations.
```

## Stage 3: Full Secret Key Only (No Restricted Keys)

**Important platform rule:** `STRIPE_SECRET_KEY` must be a standard secret key
starting with `sk_`. Restricted API keys (`rk_`) are rejected by the platform.
Skip any guidance that suggests creating a restricted key.

Why the full key is required:

- The server-side catalog sync creates/updates/archives Stripe Products,
  Prices, Coupons, and Promotion Codes — full access on those resources.
- The backend creates Checkout Sessions and verifies webhooks.
- The key never reaches the browser and never appears in build artifacts; it
  lives in the sprint secrets store only.

| Operation | Who Needs It |
|-----------|-------------|
| Product/Price/Coupon management (catalog sync) | Control plane via `server_lambda` secrets |
| Checkout Session creation | User app backend (fetches secret at cold start) |
| Webhook signature verification | User app backend (`STRIPE_WEBHOOK_SECRET`) |
| Stripe.js bootstrap | Publishable key only (frontend build var) |

## Stage 4: (Later) Webhook Signing Secret

This comes AFTER the webhook endpoint is created (devops/developer phase).

```
After we deploy and register the webhook endpoint, you'll need to
get the webhook signing secret:

1. Go to Dashboard → Developers → Webhooks
2. Click on the webhook endpoint for your project
3. Click "Reveal" under "Signing secret"
4. Share the value (starts with whsec_)
```

## Conversation Flow Summary

```
Planner:  "Do you have a Stripe account?"
  ↓
User:     "No" → Planner gives registration link + 5-min walkthrough
User:     "Yes"
  ↓
Planner:  "Are you in test mode? (Dashboard top bar)"
  ↓
User:     "Yes"
  ↓
Planner:  "Go to Developers → API keys, share your test publishable
           key (pk_test_) and test secret key (sk_test_)"
  ↓
User:     Shares keys
  ↓
Planner:  (Validates format silently — sk_ required, rk_ rejected;
           records "keys available" in knowledge file, DOES NOT
           store the key values)
  ↓
Planner:  Key gathering complete. Proceed to product catalog planning.
```

## Stripe Dashboard Navigation Quick Reference

For the planner to guide users precisely:

| What | Navigation Path | Direct URL |
|------|----------------|------------|
| Test API keys | Developers → API keys | https://dashboard.stripe.com/test/apikeys |
| Live API keys | Developers → API keys (toggle to live) | https://dashboard.stripe.com/apikeys |
| Products | More → Product catalog | https://dashboard.stripe.com/test/products |
| Webhooks | Developers → Webhooks | https://dashboard.stripe.com/test/webhooks |
| Events (logs) | Developers → Events | https://dashboard.stripe.com/test/events |
| Tax settings | Settings → Tax | https://dashboard.stripe.com/settings/tax |
| Team access | Settings → Team | https://dashboard.stripe.com/settings/team |

## Test Cards for Development

Tell the user about Stripe's test cards — they don't need real cards:

```
For testing, Stripe provides special card numbers:

- 4242 4242 4242 4242  → Successful payment
- 4000 0000 0000 0002  → Declined payment
- 4000 0025 0000 3155  → Requires 3D Secure auth

Expiry: any future date (e.g., 12/34)
CVC: any 3 digits (e.g., 123)
ZIP: any 5 digits (e.g., 12345)

Full list: https://stripe.com/docs/testing
```

## What the Planner Records in Knowledge

After key gathering, add this to `~/.forloop/sprint-{id}/knowledge/`:

```markdown
## Stripe Configuration — {Date}

### Account
- Stripe account: Confirmed (test mode)
- Key type: Full secret key (sk_) — required by the catalog sync pipeline

### Keys (status only — values NOT stored)
- [x] Test publishable key (pk_test_)
- [x] Test secret key (sk_test_)
- [ ] Webhook signing secret (will be collected after deploy)
- [ ] Live keys (will be collected before production launch)

### Key Storage
- Secret key → sprint secrets via server_lambda (server-side encrypted)
- Publishable key → `stripePublishableKey` in the repo's `forloop.json` (public; delivered at deploy through the deploy config API)
- Webhook secret → sprint secrets via server_lambda
```

## Security Boundaries for the Planner

The planner is a planning agent. It MUST follow these boundaries:

| Action | Planner | Devops/Developer Agents |
|--------|---------|-------------|
| Ask user for keys | ✅ Yes | — |
| Validate key format (sk_ prefix check) | ✅ Yes | ✅ (server enforces `sk_`) |
| Record "keys confirmed" in knowledge | ✅ Yes | — |
| Store keys via secrets API | ✅ Yes (PUT /api/opencode/sprints/:id/secrets/:key) | — |
| Test keys against Stripe API | ❌ Never | ✅ (story implementation) |
| Store key values in files/git | ❌ Never | ❌ Never |
| Create .env file with keys | ❌ Never | ❌ Never |
| Log key values in conversation | ❌ Never | — |