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
rk_test_... →  Restricted API key (test)   ✓ (preferred)
```

If a live key is provided, ask: "This appears to be a live key (sk_live_).
Are you sure you want to use live mode now? We strongly recommend starting
with test mode keys (sk_test_) during development."

## Stage 3: (Recommended) Create a Restricted API Key

Secret keys (`sk_`) have full access to the Stripe account. A restricted
API key (`rk_`) is safer — it can only do what you permit.

### Guide the User

```
For better security, let's create a restricted API key instead of
using the full secret key:

1. On the API keys page, click "Create restricted key"
2. Give it a name: "ForLoop Dev Access"
3. Under "Permissions", select these specific permissions:

   Core Resources:
   ☑ Products — Read
   ☑ Prices — Read
   ☑ Checkout Sessions — Write
   ☑ Customers — Write
   ☑ Webhook Endpoints — Read & Write
   ☑ Events — Read

4. Click "Create key"
5. Copy the key (starts with rk_test_)
```

The planner should explain the permission choices:

| Permission | Why Needed |
|------------|-----------|
| Products — Read | To fetch product/price details |
| Checkout Sessions — Write | To create checkout sessions |
| Customers — Write | To create customer records (optional) |
| Webhook Endpoints — Read & Write | To set up webhook URL (devops phase) |
| Events — Read | To verify webhook event delivery |

## Stage 4: (Later) Webhook Signing Secret

This comes AFTER the devops agent creates the webhook endpoint. The planner
creates a Phase 0b story for this.

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
Planner:  (Validates format silently, records "keys available" in
           knowledge file, DOES NOT store the key values)
  ↓
Planner:  "For better security, would you like to create a restricted
           API key with limited permissions?"
  ↓
User:     Yes/No (if yes, guide through restricted key creation)
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
| Create restricted key | API keys page → "Create restricted key" | https://dashboard.stripe.com/test/apikeys/create |
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
- Key type: {Secret key | Restricted API key}
- Permissions: {Products Read, Checkout Sessions Write, etc.}

### Keys (status only — values NOT stored)
- [x] Test publishable key (pk_test_)
- [x] Test secret key (sk_test_) OR [x] Restricted key (rk_test_)
- [ ] Webhook signing secret (will be collected after deploy)
- [ ] Live keys (will be collected before production launch)

### Key Storage
- Secret key → AWS SSM Parameter Store at /stripe/dev/secret-key (SecureString)
- Publishable key → GitHub Actions Variable: STRIPE_PUBLISHABLE_KEY
- Webhook secret → AWS SSM at /stripe/dev/webhook-secret (SecureString)
```

## Security Boundaries for the Planner

The planner is a planning agent. It MUST follow these boundaries:

| Action | Planner | Devops Agent |
|--------|---------|-------------|
| Ask user for keys | ✅ Yes | — |
| Validate key format (prefix check) | ✅ Yes | — |
| Record "keys confirmed" in knowledge | ✅ Yes | — |
| Create SSM parameters (aws ssm put-parameter) | ❌ Never | ✅ Yes (Story 0a) |
| Test keys against Stripe API | ❌ Never | ✅ (story implementation) |
| Store key values anywhere | ❌ Never | ❌ Never (use SSM) |
| Create .env file with keys | ❌ Never | ❌ Never (use SSM) |
| Log key values in conversation | ❌ Never | — |
| Set GitHub Actions variables | ❌ Never | ✅ (Story 3c) |
