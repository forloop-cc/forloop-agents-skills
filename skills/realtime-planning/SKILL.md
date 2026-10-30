---
name: realtime-planning
description: Plan a ForLoop Realtime integration for a user app — decide the channel, audience, test-vs-live mode, webhook sink, and cost, then write the realtime-specific integration brief the developer builds from
license: MIT
compatibility: opencode
metadata:
  audience: planners
  workflow: core-services
---

## What I do

I turn "the app needs live updates / push / realtime" into a planned ForLoop
Realtime integration. I use the generic `core-service-discovery` skill for the
registry search, cost and consent flow, then I make the realtime-specific
decisions the brief needs: channel, audience model, mode, retention, event
catalog, and delivery sink.

## When to use me

Use me while planning when the requirement implies realtime delivery:

- "Update every open tab when an order changes"
- "Show new messages without refreshing"
- "Notify my backend when a record changes" (webhook-style)
- "Live dashboard / activity feed / presence-style updates"

Do **not** use me for model streaming in the app's own chat (that is the A2A
streaming host) or for a custom WebSocket build. Realtime replaces the custom
WebSocket + replay + signer/retry/DLQ stack.

## How to use me

### 1. Run the generic discovery first

Follow `core-service-discovery`: `core_services_search({ query, directOnly: true })`,
then `core_service_get` for the pinned contract. Realtime is a `system`
service; present capability, per-success price, scopes, pinned version, data
flow, and what it replaces, exactly as that skill requires.

### 2. Confirm the environment

Realtime is deployed in **dev** and **prd** (`1.0.2`).

| | dev | prd |
|---|---|---|
| Billing | **enabled** — 10 FLC / 1,000 published live events, ceil | **off** |
| Test-mode events | never billed | never billed |

State the environment you are planning for. Never promise a charge where
billing is off, and never claim "free" in dev for live events.

### 3. Make the realtime decisions (these go in the brief)

**Channel.** One channel per app + environment + mode. Not per user, not per
order. Limits: 50 live + 10 test channels per app.

- `mode`: **start with `test`**. Test mode is isolated, free, and immutable
  after the first event — a test channel is never "promoted"; plan a separate
  `live` channel for production.
- `allowedOrigins`: exact browser origins only; **empty means no browser
  origin is accepted**. Ask for the real origins, not a wildcard.
- `retentionHours`: 24 default, max 168. Replay is gap recovery, not storage.
- `eventCatalog` + `strictCatalog`: list every event name up front
  (`^[a-z0-9][a-z0-9._-]{0,127}$`) so a typo fails at publish, not silently.

**Audience** (pick one and put it in the brief — do not leave it implicit):

- Customer tabs only — event dimensions `{ userId }`; token `{ userId }`.
  Simplest; recommend it unless staff/ops need the feed.
- Customer + tenant staff — events carry `groups: ["tenant:<id>"]`; customer
  token `{ userId, groups }`; staff token `{ groups }` **without `userId`**
  (the exact-match rule otherwise filters every customer event).
- Global ops — add `"ops"` to event groups; ops token `{ groups: ["ops"] }`.

Never mix group-targeted and group-less events on one channel for two
audiences — plan a second channel instead.

**Sink.** Choose one and name it in the brief:

- **Direct HTTPS receiver** — when the app backend has a public HTTPS host.
  The verification challenge is path-scoped
  (`<baseUrl>/.well-known/forloop-scheduler-verify`); a root-level webhook host
  is cleanest.
- **Platform Webhook inbox** — when the app has no public receiver. Needs a
  second app-subject connection to Webhook (`webhook.inboxes:read/write`,
  `webhook.requests:read`). Inbox retention 7 days, `maxRequests` default 100
  — plan the polling cadence.
- No sink — browser only.

**Not needed:** a custom WebSocket server, connection-state store, replay log,
or webhook signer/retry/DLQ. Realtime owns those.

### 4. Cost and wallet (before the brief)

Realtime bills **published live events**, once per event — not per connected
tab and not per delivery. Replay reads and webhook deliveries are not billed.
Estimate live events/month, then run:

```
a2a_check_wallet({ agentId: "<realtime agentId>", quantity: <estimated live events> })
```

Surface available balance, the 10 FLC/1,000 unit price, the estimate, and any
shortfall. A shortfall must be topped up **before the Developer starts**
(otherwise the first publish fails with `402 insufficient_balance`). The
planner never moves funds.

### 5. Request the connection (user action)

Run `core_service_integration_request` with exactly these scopes:

- `realtime.channels:read` — channel list/get, endpoint and subscription reads
- `realtime.channels:write` — channel create/patch, endpoints, subscriptions
- `realtime.events:read` — replay, deliveries, usage
- `realtime.events:write` — publish, delivery retry
- `realtime.streams:write` — viewer-token mint and revoke

Give the user the returned link and four steps verbatim (open **Aivy Actions →
App Connections (Beta) → Connect**, choose **This app**, click **Connect**, copy
the **Connection ID**). Never say it is "recorded" or "pending in the UI" —
nothing exists until they click Connect. If they cannot, write
`Connection: to be created during implementation` in the brief and continue.

If the app also needs the platform inbox, note that it needs a **second**
app-subject connection to Webhook — plan it as a separate owner action.

### 6. Write the realtime-specific brief

Use the `core-service-discovery` brief verbatim and add this section:

```
## Realtime integration — <channel name>
- base URL: https://realtime.app.<env>.forloop.cc
- mode: test | live  (start test; live is a separate channel)
- channel: to be created during implementation (name: <name>; retention <24-168>h)
- allowedOrigins: <exact origins>
- event catalog: <event names>; strictCatalog: true
- audience: <customer-only | customer+staff | ops> — event dimensions <…>; viewer token <…>
- delivery sink: <direct <baseUrl> <path> | platform inbox <name> | none>
- billing: 10 FLC / 1,000 published live events (ceil); test events free;
  env billing <on|off>
- the app template ships: backend/src/forloop/realtime/,
  frontend/src/lib/realtime/, backend/scripts/ensureRealtimeChannel.ts,
  registerRealtimeWebhook.ts, registerRealtimeWebhookInbox.ts (reuse if present)
- acceptance: <event visible in a second tab; reconnect replays the gap without
  duplicates; cross-user isolation holds; sink signature verifies; test events
  do not bill>
```

Do not name the channel id, endpoint id, or signing secret — the Developer
creates those during implementation and stores secrets in SSM.

## Rules

- Use `core-service-discovery` for the registry, cost, consent, and brief — this
  skill only adds the realtime decisions.
- Never invent an endpoint, scope, version, price, or channel id.
- Always decide the **audience**, **mode**, and **sink** in the plan; leaving
  them to the Developer causes rework.
- Start in `test`; never plan to "promote" a test channel or reuse it in prd.
- Never let an unfunded live integration reach runtime (run `a2a_check_wallet`).
- Never create a connection, grant, channel, endpoint, or credential — the user
  clicks Connect and the Developer builds.
- Never use curl or construct URLs; use the planner tools.
