# Product Catalog Specification Template

This is the canonical desired-state catalog the planner produces. It uses the
platform's **Product / Offer / Promotion** model (docs 01 + 04): products own
nested offers, and promotions are a separate temporary-discount layer. The
catalog sync pipeline consumes this shape — there is NO devops agent making
raw Stripe API calls and NO `stripe-prices.json` / `VITE_STRIPE_PRICE_*`
mapping anymore.

**The planner writes a JSON file as the primary data source.** A companion
`.md` file is generated for human review only.

---

## Storage: S3 (Ephemeral Planner Filesystem)

The planner runs in a Lambda environment with a non-persistent filesystem.
All files must be uploaded to the sprint's S3 bucket for handoff.

### Planner Uploads (Writing)

1. Write `stripe-product-catalog.json` to `~/.forloop/sprint-{id}/plan/`
2. Optionally write `stripe-product-catalog.md` for user review
3. Upload both to S3: `forloopSyncLocalToS3(sprintId={id})`

### How The Catalog Reaches Production

1. During implementation, the developer agent (or the user) loads the file
   into the app's **admin portal import workspace**: create an import batch,
   upload the JSON to staging S3 via a presigned PUT URL, and register the file.
2. `POST /admin/catalog/import-batches/:batchId/preview` starts a server-side
   preview job. The control-plane sync pipeline parses/validates the file and
   produces a diff (create / update / archive / skip).
3. The user reviews the preview diff and confirms apply. The pipeline then
   syncs **Stripe first** (Products, Prices, Coupons / Promotion Codes), then
   writes runtime rows (`CatalogProduct`, `CatalogOffer`, `CatalogPromotion`,
   category mappings) into the user's DynamoDB table.
4. Runtime rows become visible only when `status = active` AND
   `syncStatus = ready`.

Small authoring edits (single-product changes) happen directly in the admin
portal as **change-sets** — previewed and applied through the same pipeline.

---

## Canonical Format: JSON (`stripe-product-catalog.json`)

### JSON Schema

```typescript
// stripe-product-catalog.json (canonical doc 04 shape)
{
  "version": 1,
  "catalogKey": string,           // e.g. "sprint-42"
  "projectKey": string,           // project name from sprint context
  "currency": string,             // default currency, e.g. "usd"
  "products": [
    {
      "productKey": string,       // STABLE local key, e.g. "pro-plan"
      "name": string,
      "description": string,
      "primaryCategoryKey": string,        // e.g. "subscriptions"
      "categoryKeys": string[],            // optional multi-category
      "category": "service" | "digital" | "subscription" | "physical" | "membership" | "other",
      "status": "draft" | "active" | "archived",
      "fulfillmentType": "one_time_access" | "subscription_access" | "manual_service" | "shipment" | "custom",
      "metadata": Record<string, string>,  // app-specific sparse fields
      "display": {                         // optional display hints
        "badge": string,
        "featured": boolean,
        "sortOrder": number
      },
      "offers": [
        {
          "offerKey": string,     // STABLE local key, e.g. "pro-monthly"
          "name": string,
          "billingType": "one_time" | "recurring",
          "interval": "month" | "year",    // required when recurring
          "amountCents": number,           // cents! $29.00 = 2900
          "currency": string,
          "trialDays": number,             // optional free trial (recurring only)
          "status": "draft" | "active" | "archived",
          "active": boolean,
          "display": {
            "label": string,
            "badge": string,
            "featured": boolean,
            "sortOrder": number
          }
        }
      ]
    }
  ],
  "promotions": [                          // optional
    {
      "promotionKey": string,   // STABLE local key, e.g. "summer-20"
      "name": string,
      "code": string,           // customer-facing coupon code, e.g. "SUMMER20"
      "discountType": "percent" | "amount",
      "percentOff": number,     // required when percent
      "amountOffCents": number, // required when amount
      "currency": string,       // for amount discounts
      "appliesTo": {
        "productKeys": string[],
        "offerKeys": string[]
      },
      "duration": "once" | "forever" | "repeating",
      "durationInMonths": number,          // for repeating
      "active": boolean
    }
  ]
}
```

### Full Example

```json
{
  "version": 1,
  "catalogKey": "sprint-42",
  "projectKey": "my-saas-app",
  "currency": "usd",
  "products": [
    {
      "productKey": "premium-theme",
      "name": "Premium Theme",
      "description": "Premium website theme with lifetime updates",
      "primaryCategoryKey": "templates",
      "categoryKeys": ["templates", "featured"],
      "category": "digital",
      "status": "active",
      "fulfillmentType": "one_time_access",
      "metadata": { "product_type": "one_time" },
      "display": { "featured": true, "sortOrder": 10 },
      "offers": [
        {
          "offerKey": "premium-theme-once",
          "name": "Premium Theme",
          "billingType": "one_time",
          "amountCents": 4900,
          "currency": "usd",
          "status": "active",
          "active": true
        }
      ]
    },
    {
      "productKey": "pro-plan",
      "name": "Pro",
      "description": "Advanced features for teams",
      "primaryCategoryKey": "subscriptions",
      "categoryKeys": ["subscriptions", "b2b"],
      "category": "subscription",
      "status": "active",
      "fulfillmentType": "subscription_access",
      "display": { "badge": "POPULAR", "featured": true, "sortOrder": 20 },
      "offers": [
        {
          "offerKey": "pro-monthly",
          "name": "Pro Monthly",
          "billingType": "recurring",
          "interval": "month",
          "amountCents": 2900,
          "currency": "usd",
          "trialDays": 14,
          "status": "active",
          "active": true,
          "display": { "sortOrder": 1 }
        },
        {
          "offerKey": "pro-yearly",
          "name": "Pro Yearly",
          "billingType": "recurring",
          "interval": "year",
          "amountCents": 29000,
          "currency": "usd",
          "status": "active",
          "active": true,
          "display": { "badge": "BEST VALUE", "sortOrder": 0 }
        }
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
      "appliesTo": { "offerKeys": ["pro-monthly", "pro-yearly"] },
      "duration": "once",
      "active": true
    }
  ]
}
```

---

## Entity Model (For Reference)

```
Product (the "what")
  ├── productKey  — stable local identity (never changes)
  ├── name / description / category / status
  ├── metadata / display      — app-specific sparse fields
  └── offers[]                — the "how much / how billed"
        ├── offerKey         — stable local identity
        ├── billingType      — one_time | recurring
        ├── interval         — month | year (recurring only)
        ├── amountCents / currency
        └── trialDays (optional)

Promotions (the "temporary discount")  — a separate top-level entity
  ├── promotionKey          — stable local identity
  ├── code                  — coupon code users enter
  ├── discountType          — percent | amount
  ├── appliesTo             — productKeys / offerKeys
  └── duration              — once | forever | repeating
```

**Stripe mapping decided by the platform** (doc 01 §3): one CatalogProduct →
one Stripe Product; one CatalogOffer → one Stripe Price; one CatalogPromotion →
one Stripe Coupon / Promotion Code. The planner never maps Stripe IDs — the
sync pipeline resolves them at apply time.

---

## Rules for the Planner

### Do

- Give every product/offer/promotion a **stable local key** (kebab-case). Keys
  are the identity contract that survives Stripe ID rotation.
- Add multiple offers to the same product ONLY for billing variants
  (monthly vs yearly) or genuinely same-product variants.
- Separate one-time items from recurring subscriptions by billingType on the
  offer, not by inventing a second product for every price point.
- Split products only when the business meaning differs (lifetime license vs.
  subscription access).
- Keep temporary discounts as **promotions**, never as a mutation of the base
  price.
- Confirm amounts and currencies with the user before finalizing.
- Write the JSON **and upload to S3** — the planner filesystem is ephemeral.

### Don't

- Do NOT put different tiers (Starter + Pro + Enterprise) under the same product.
- Do NOT record Stripe IDs (`prod_`, `price_`) in the spec — they don't exist
  yet and the pipeline owns them.
- Do NOT invent `VITE_STRIPE_PRICE_*` env var names — the legacy price-ID env
  mapping is removed from the platform and the template.
- Do NOT invent prices — only use what the user tells you.
- Do NOT guess currency — confirm with the user.
- Do NOT skip the S3 upload — downstream agents cannot read the planner's
  local filesystem.

---

## Currency and Amount Conventions

- Amounts are in **cents**: $29.00 = 2900
- JPY is zero-decimal: ¥2900 = 2900 (not 290000)
- Supported currencies: usd, eur, gbp, cad, aud, jpy, sgd, etc.
- Always clarify: "$29" can mean USD, CAD, AUD, etc.