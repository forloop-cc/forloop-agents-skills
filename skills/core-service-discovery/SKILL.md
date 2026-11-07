---
name: core-service-discovery
description: Discover directly-integrable ForLoop core services while planning an app, present cost and scopes, and record the agreed integration as an integration brief
license: MIT
compatibility: opencode
metadata:
  audience: planners
  workflow: core-services
---

## What I do

While planning an app, I find ForLoop core services that already provide a capability the app needs (scheduling, notifications, payments, and so on), then turn the chosen service into an integration brief the development agent can build against.

## When to use me

Use me while planning an app, when a requirement implies a capability a core service may provide. Examples:

- "Send the user an email when the job finishes" → notifications
- "Run this every Monday at 09:00" → scheduling
- "Charge the customer once the order ships" → payments

Do not use me to design a brand-new service, or to integrate a public third-party API. Those are outside the core-service path.

## How to use me

### 1. Search the registry with the requirement

Use the planner tool — never curl and never construct a URL:

```
core_services_search({ query: "<the requirement sentence>", directOnly: true })
```

Search is tokenized, so pass the requirement itself rather than a single keyword. Add `tool: "<tool id>"` when you already know the operation you need.

### 2. Read the contract for each viable candidate

```
core_service_get({ agentId: "<agentId>", version: "<pinned version>" })
```

`version` is optional; when omitted the tool resolves the current registry version. The response includes the OpenAPI document, the tool index, and the version status/deprecation/sunset dates.

### 3. Rank the candidates

Rank candidates by fit to the requirement. For each candidate you present, quote what the tools actually returned:

- `name`, `description`, `kind` (`system` = ForLoop core service, `user` = user app)
- `serviceCode`, `baseUrl`
- `tools` (id, name, and `whenToUse`/description)
- `scopes`, `authMode`
- `version`, `versionStatus`, `sunsetAt`
- `billingPrice`, `billingUnit`, `billingCurrency` (or `price TBD`)

Do not paraphrase scopes or tools, and do not add a capability the listing does not claim.

### 4. Present the decision to the user

For each viable candidate, present:

- **Capability** — what it does for this requirement
- **Per-success price** — from the registry (`billingPrice`); otherwise write `price TBD`
- **Requested scopes** — exactly those needed for the planned calls
- **Pinned version** — the `version` from the registry/contract
- **Data flow** — what data leaves the app, where it goes, and what comes back
- **What it replaces** — the code or infrastructure the app no longer needs to build

### 4b. Check the app wallet before build (paid services)

A paid service debits the app wallet (`APP:<sprint publicId>`), not the user's
personal wallet. Before writing the brief or dispatching the Developer, call:

```
a2a_check_wallet({ agentId: "<agentId>", quantity: <expected billable units> })
```

Quote the available balance, the unit price, the estimate, and the shortfall it
returns. If `shortfall > 0`, tell the user to top up the app wallet **before the
Developer starts** (otherwise the first call fails with `402
insufficient_balance`). If the tool reports `price TBD`, say the cost is not yet
published rather than inventing one.

This tool is read-only. Never claim you funded, reserved, or moved credits — the
planner cannot move funds.

### 5. Wait for agreement, then create and open the request

Create nothing until the user agrees. On agreement, call:

```
a2a_request_connection({
  agentId: "<agentId>",
  scopes: [<exactly the agreed scopes>],
  reason: "<why the app needs it>"
})
```

This persists (or idempotently reuses) a **pending app-subject connection
request** and returns the request id, the stored scopes, and the approval link.
It is not a grant and never handles credentials. Dropped scopes mean the target
manifest no longer declares them; surface that instead of widening the request.

Then bring the panel forward:

```
a2a_open_connection_request({ requestId: "<request id>" })
```

This emits a socket action that opens the owner's **App Connections** panel
focused on the request. (`a2a_open_connection_request` also accepts
`agentId` + `scopes` and creates/reuses the request itself when no id is known.)

Branch on the result:

- **`socket delivered: yes` / "App Connections opened"** → the panel is already
  open on the request. Tell the user to click **Approve**. Do not paste the link
  and do not repeat manual steps.
- **`socket delivered: no`** → the client was offline. Give the user the returned
  `link` (it opens the same focused panel) and the step to click **Approve**.

Never ask the user to copy/paste a connection id. The planner cannot approve the
request: approval is an **owner-only** action in the UI (collaborators can view
the request but cannot approve it).

When the user says they approved, verify with:

```
a2a_check_connections({})
```

Use the **real connection id and granted scopes** it reports — a pending request
is not a grant. If the request is still pending, say it is waiting for the app
owner and do not write a connection id into the brief. If it was denied or
expired, ask before creating a new request. Never say a request does not exist
after `a2a_open_connection_request` succeeds, and never claim the planner
approved it.

If the owner cannot complete the approval, write `Connection: pending owner
approval` in the brief and continue. Do not block the plan and do not ask again.
After approval, confirm the spend cap with `a2a_check_wallet` and tell the app
owner to set it in the platform UI: **Credits → select the app wallet → Spend
cap** (cumulative wallet cap; leave unset for unlimited). The planner cannot set
it and must not claim a different location. Never read, print, or store
credentials.

### 6. Write the integration brief into the story

Use this template verbatim:

```
## Integration brief — <serviceCode>
- service: <name> (<agentId>), kind: <system|user>, contract version: <version>
- base URL: <baseUrl>
- scopes: <list>
- connection: <real connection id from a2a_check_connections, or "pending owner approval">
- endpoints: <method + path per tool>
- auth: app credential (flc_app_) → POST /api/opencode/a2a/connections/:id/assertion → Authorization: Bearer <assertion>
- errors: invalid_credential | revoked | expired | insufficient_scope | not_direct_integrable | app_not_found | contract_version_required | contract_version_not_found | contract_version_retired
- cost: <billingPrice / billingUnit>; spend cap: <amount or "unlimited"> (cumulative; owner sets it on Credits → app wallet → Spend cap)
- wallet: <available balance> / <estimate>; <"funded" or "top up X FLC before implementation">
- acceptance: <observable behaviour>
- docs: contract <version> via core_service_get({ agentId, version })
```

## Rules

- Propose only services returned by `core_services_search`; never invent a service.
- Never invent an endpoint, scope, version, base URL, or price. Quote the registry and the pinned contract.
- Always surface cost and scopes before asking for agreement.
- For a paid service, run `a2a_check_wallet` and surface the balance, estimate, and shortfall before the brief/Developer dispatch. Never let an unfunded integration reach runtime (`402 insufficient_balance`).
- Never create a connection, grant, or spend cap before the user agrees — the planner can request and read connections but never approve or mint a grant.
- `a2a_request_connection` DOES persist a pending request; say so accurately. Approval is the app owner's action, and only `a2a_check_connections` confirms the resulting grant.
- Never ask the user to copy/paste a connection id; read it back with `a2a_check_connections` after they approve.
- Never use curl, wget, or construct API URLs directly.
- Never handle, log, or store credentials.
- If no listed service fits, say so plainly and plan to build the capability instead.
