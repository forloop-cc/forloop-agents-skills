# Product Catalog Specification Template

This is the spec the planner produces. The devops agent uses it to create
Products and Prices in Stripe via the API.

**The planner writes a JSON file as the primary data source.** A companion
`.md` file is generated for human review, but the devops agent processes
the JSON directly — no markdown parsing needed.

---

## Storage: S3 (Ephemeral Planner Filesystem)

The planner runs in a Lambda environment with a non-persistent filesystem.
All files must be uploaded to the sprint's S3 bucket for handoff to the devops
and developer agents.

### Planner Uploads (Writing)

1. Write `stripe-product-catalog.json` to `~/.forloop/sprint-{id}/plan/`
2. Optionally write `stripe-product-catalog.md` for user review
3. Upload both to S3: `forloopSyncLocalToS3(sprintId={id})`

### Devops Downloads (Reading)

1. List sprint files: `forloopFileList(sprintId={id})`
2. Download: use the OpenCode file download API or `forloopFileDownload`
3. Parse `stripe-product-catalog.json`

### What Gets Stored

| File | Format | Purpose |
|------|--------|---------|
| `stripe-product-catalog.json` | JSON | **Primary.** Devops reads this to call Stripe API. |
| `stripe-product-catalog.md` | Markdown | **Human-readable.** For user confirmation / review. |
| `stripe-prices.json` | JSON | **Produced by devops.** Contains real Stripe price IDs + env var mapping. |

---

## Primary Format: JSON (`stripe-product-catalog.json`)

This is the file the planner produces and the devops agent processes. Every
field maps directly to a Stripe API parameter.

### JSON Schema

```typescript
// stripe-product-catalog.json
{
  "project": string,          // project name from sprint context
  "stripeMode": "test" | "live",
  "sprintId": number,         // sprint ID for provenance
  "createdAt": string,        // ISO 8601 timestamp
  "products": [
    {
      "name": string,                            // "Pro Plan"
      "type": "one_time" | "recurring",           // determines Stripe Price type
      "description": string,                      // shown on Stripe Checkout
      "metadata": {                               // custom key-value pairs
        "product_type"?: "one_time",
        "product_tier"?: "starter" | "pro" | "enterprise",
        "project"?: string,
        // ... any additional metadata
      },
      "prices": [
        {
          "nickname": string,                    // "Pro Monthly"
          "unit_amount": number,                 // cents! $29.00 = 2900
          "currency": string,                    // "usd", "eur", "gbp", etc.
          "recurring"?: {                       // OMIT for one-time products
            "interval": "month" | "year" | "week" | "day",
            "interval_count"?: number,          // default 1
            "trial_period_days"?: number        // e.g., 14
          }
        }
      ]
    }
  ]
}
```

### Full Example

```json
{
  "project": "my-saas-app",
  "stripeMode": "test",
  "sprintId": 42,
  "createdAt": "2026-08-09T14:00:00Z",
  "products": [
    {
      "name": "Premium Theme",
      "type": "one_time",
      "description": "Premium website theme with lifetime updates",
      "metadata": { "product_type": "one_time", "project": "my-saas-app" },
      "prices": [
        {
          "nickname": "Premium Theme",
          "unit_amount": 4900,
          "currency": "usd"
        }
      ]
    },
    {
      "name": "Setup Service",
      "type": "one_time",
      "description": "Professional account setup and configuration",
      "metadata": { "product_type": "one_time", "project": "my-saas-app" },
      "prices": [
        {
          "nickname": "Setup Service",
          "unit_amount": 19900,
          "currency": "usd"
        }
      ]
    },
    {
      "name": "Starter",
      "type": "recurring",
      "description": "Basic features for individuals",
      "metadata": { "product_tier": "starter", "project": "my-saas-app" },
      "prices": [
        {
          "nickname": "Starter Monthly",
          "unit_amount": 900,
          "currency": "usd",
          "recurring": { "interval": "month" }
        }
      ]
    },
    {
      "name": "Pro",
      "type": "recurring",
      "description": "Advanced features for teams",
      "metadata": { "product_tier": "pro", "project": "my-saas-app" },
      "prices": [
        {
          "nickname": "Pro Monthly",
          "unit_amount": 2900,
          "currency": "usd",
          "recurring": { "interval": "month", "trial_period_days": 14 }
        },
        {
          "nickname": "Pro Yearly",
          "unit_amount": 29000,
          "currency": "usd",
          "recurring": { "interval": "year" }
        }
      ]
    },
    {
      "name": "Enterprise",
      "type": "recurring",
      "description": "Custom solutions for organizations",
      "metadata": { "product_tier": "enterprise", "project": "my-saas-app" },
      "prices": [
        {
          "nickname": "Enterprise Monthly",
          "unit_amount": 9900,
          "currency": "usd",
          "recurring": { "interval": "month" }
        }
      ]
    }
  ]
}
```

### Planner: How to Write This File

```typescript
// Planner agent writes:
const catalog = {
  project: "my-saas-app",
  stripeMode: "test",
  sprintId: 42,
  createdAt: new Date().toISOString(),
  products: [
    // Populated from user answers
  ],
}

// 1. Write locally (ephemeral — must upload)
writeFile("~/.forloop/sprint-42/plan/stripe-product-catalog.json", JSON.stringify(catalog, null, 2))

// 2. Upload to S3 for persistence
forloopSyncLocalToS3({ sprintId: 42 })

// 3. (Optional) Generate markdown for user review
//    and upload similarly
```

### Devops: How to Read and Use This File

```javascript
// Devops agent (Story 0b) reads the file and creates Stripe objects:

// 1. Download from S3
//    Use forloopFileList(sprintId=42) → find "stripe-product-catalog.json"
//    Download via OpenCode file API

// 2. Parse and iterate
const catalog = JSON.parse(fileContents)

for (const product of catalog.products) {
  // CREATE PRODUCT IN STRIPE
  const stripeProduct = await stripe.products.create({
    name: product.name,
    description: product.description,
    metadata: product.metadata,
  })

  for (const price of product.prices) {
    // CREATE PRICE IN STRIPE
    const priceParams = {
      product: stripeProduct.id,
      unit_amount: price.unit_amount,
      currency: price.currency,
      nickname: price.nickname,
    }

    // For recurring: add the recurring block
    // For one-time: omit it — Stripe auto-detects
    if (price.recurring) {
      priceParams.recurring = price.recurring
    }

    const stripePrice = await stripe.prices.create(priceParams)

    // Record the real Stripe ID back onto the price object
    price.stripePriceId = stripePrice.id
    price.stripeProductId = stripeProduct.id
  }
}

// 3. Produce stripe-prices.json with real IDs
const output = {
  project: catalog.project,
  stripeMode: catalog.stripeMode,
  createdAt: new Date().toISOString(),
  products: catalog.products.map(p => ({
    name: p.name,
    type: p.type,
    stripeProductId: p.prices[0].stripeProductId,
    prices: p.prices.map(pr => ({
      nickname: pr.nickname,
      stripePriceId: pr.stripePriceId,
      unit_amount: pr.unit_amount,
      currency: pr.currency,
      ...(pr.recurring ? { recurring: pr.recurring } : {}),
    })),
  })),
  // Map each Stripe price ID to the GitHub Variable name
  // that deploy.yml will pass to Vite
  envVarMapping: {
    "VITE_STRIPE_PRICE_PREMIUM_THEME": "price_aaa001",
    "VITE_STRIPE_PRICE_SETUP_SERVICE": "price_bbb002",
    "VITE_STRIPE_PRICE_STARTER": "price_bbb003",
    "VITE_STRIPE_PRICE_PRO": "price_ccc003",
    "VITE_STRIPE_PRICE_ENTERPRISE": "price_eee005",
  },
}

// 4. Upload stripe-prices.json to S3
writeFile("~/.forloop/sprint-42/stripe-prices.json", JSON.stringify(output, null, 2))
forloopSyncLocalToS3({ sprintId: 42 })

console.log("Created products and prices. Set these GitHub Variables:")
for (const [varName, priceId] of Object.entries(output.envVarMapping)) {
  console.log(`  ${varName} = ${priceId}`)
}
```

### Devops Agent Output: `stripe-prices.json`

```json
{
  "project": "my-saas-app",
  "stripeMode": "test",
  "createdAt": "2026-08-09T14:15:00Z",
  "products": [
    {
      "name": "Premium Theme",
      "type": "one_time",
      "stripeProductId": "prod_abc111",
      "prices": [
        {
          "nickname": "Premium Theme",
          "stripePriceId": "price_aaa001",
          "unit_amount": 4900,
          "currency": "usd"
        }
      ]
    },
    {
      "name": "Pro",
      "type": "recurring",
      "stripeProductId": "prod_ghi333",
      "prices": [
        {
          "nickname": "Pro Monthly",
          "stripePriceId": "price_ccc003",
          "unit_amount": 2900,
          "currency": "usd",
          "recurring": { "interval": "month" }
        }
      ]
    }
  ],
  "envVarMapping": {
    "VITE_STRIPE_PRICE_PREMIUM_THEME": "price_aaa001",
    "VITE_STRIPE_PRICE_SETUP_SERVICE": "price_bbb002",
    "VITE_STRIPE_PRICE_STARTER": "price_bbb003",
    "VITE_STRIPE_PRICE_PRO": "price_ccc003",
    "VITE_STRIPE_PRICE_ENTERPRISE": "price_eee005"
  }
}
```

The `envVarMapping` is used by:
- **Devops**: sets these as GitHub Actions Variables
- **Developer**: cross-references with `PricingPage.tsx` to confirm all env vars are wired

---

## Secondary Format: Markdown (`stripe-product-catalog.md`)

Generated from the JSON for human review. Produced optionally — not used by
the devops agent for processing.

```markdown
# Stripe Product Catalog — my-saas-app

> Generated by ForLoop Planner on 2026-08-09
> Sprint: 42
> Stripe Mode: test

---

## Section 1: One-Time Products

### Product: Premium Theme
- **Type:** One-time purchase
- **Description:** Premium website theme with lifetime updates

#### Prices
| Nickname | Amount (cents) | Currency |
|----------|---------------|----------|
| Premium Theme | 4900 | usd |

---

## Section 2: Recurring Subscriptions

### Product: Pro
- **Type:** Recurring subscription
- **Description:** Advanced features for teams

#### Prices
| Nickname | Interval | Amount (cents) | Currency | Trial (days) |
|----------|----------|----------------|----------|-------------|
| Pro Monthly | month | 2900 | usd | 14 |
| Pro Yearly | year | 29000 | usd | — |
```

---

## Stripe Entity Model (For Reference)

```
Product                          (the "what" — a plan, tier, or item)
  ├── name: string               (display name, e.g. "Pro Plan")
  ├── description: string        (shown on checkout)
  ├── metadata: { ... }          (custom key-value pairs)
  └── Price(s)                   (the "how much")
        ├── currency: string     (usd, eur, gbp, etc.)
        ├── unit_amount: number  (in cents! $29.00 = 2900)
        ├── recurring?: {        (omit for one-time prices)
        │     interval: "month" | "year" | "week" | "day"
        │     interval_count?: number (default 1)
        │     trial_period_days?: number
        │   }
        └── nickname: string
```

---

## Rules for the Planner

### Do

- Create ONE Product per plan/tier OR one-time item
- Add multiple Prices to the same Product ONLY for variants (monthly/yearly, different currencies)
- **Separate one-time products from recurring plans** in the catalog
- **Classify each item as `"one_time"` or `"recurring"` before writing** — this determines the Stripe Price type
- Include metadata fields that help identify the product context (`product_type: "one_time"` or `product_tier: "starter"`)
- Confirm amounts and currencies with the user before finalizing
- **Write the JSON file AND upload to S3** — the planner filesystem is ephemeral
- **Upload via `forloopSyncLocalToS3(sprintId={id})`** after writing the file

### Don't

- Put different tiers (Starter + Pro + Enterprise) on the same Product
- Put one-time and recurring items on the same Product — they require different Price types
- Invent prices — only use what the user tells you
- Guess currency — confirm with the user
- Set up tax configurations — this requires the user's tax advisor
- Hardcode `txcd_` tax codes — the user must confirm these
- Assume all items are subscriptions — always ask if the user also sells one-off products
- Skip the S3 upload — the devops agent cannot read from the planner's local filesystem

---

## Currency and Amount Conventions

- Amounts are in **cents** (Stripe API convention): $29.00 = 2900
- Supported currencies: usd, eur, gbp, cad, aud, jpy, sgd, etc.
- JPY is zero-decimal: ¥2900 = 2900 (not 290000)
- Always clarify: "$29" can mean USD, CAD, AUD, etc.

---

## Env Var Naming Convention

The devops agent maps each Stripe price to a `VITE_*` env var. The naming
convention is:

```
VITE_STRIPE_PRICE_{UPPER_SNAKE_PRODUCT_NAME}
```

| Product Name | Env Var |
|-------------|---------|
| Premium Theme | `VITE_STRIPE_PRICE_PREMIUM_THEME` |
| Setup Service | `VITE_STRIPE_PRICE_SETUP_SERVICE` |
| Starter | `VITE_STRIPE_PRICE_STARTER` |
| Pro | `VITE_STRIPE_PRICE_PRO` |
| Enterprise | `VITE_STRIPE_PRICE_ENTERPRISE` |

For products with multiple prices (e.g., Pro Monthly + Pro Yearly), the
primary price uses the base name. Additional variants get suffixes:
`VITE_STRIPE_PRICE_PRO_YEARLY`.

The `envVarMapping` in `stripe-prices.json` is the single source of truth for
this mapping. The devops agent generates it, the developer agent uses it to
confirm the `PricingPage.tsx` env vars are correct.
