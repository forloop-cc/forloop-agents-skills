---
name: peer-form-planning
description: >
  Use when the user wants their app's A2A agent to collect structured input
  from the signed-in user during a conversation — booking details, a shipping
  address, dates, preferences, a choice grid — or asks for "a form in chat",
  `/forms`, `formAllowedHosts`, or a form from another app. Plans the peer-form
  stories, the user-facing behaviour, and the text fallback. DO NOT use for
  durable in-app management screens, ordinary page forms, or app-to-app /
  scheduled turns with no human.
license: MIT
metadata:
  version: "1.0.0"
  category: planning
  sources:
    - docs/a2a_user_application/foundation/12_forloop_app_standard.md (§1.8)
    - docs/a2a_user_application/foundation/24_command_bar_profile_panels_and_peer_forms_design.md (§4)
    - forloop-project-base/.forloop/template/docs/peer-forms.md
  integrations: [story-creation, task-tracking, user-communication, core-service-discovery]
triggers: ["form in chat", "peer form", "ask the user for details", "structured input", "booking form", "formAllowedHosts"]
---

# Peer-form planning

## What a peer form is

A peer form is an **app-owned page** that the ForLoop command bar frames in a
sandboxed mini-window during an A2A conversation. The app's agent creates the
form in its own API, calls the `request_form` tool with the form URL, and ends
its turn. The client shows a form card with the title and an **Open form**
action; the panel header carries the peer name, title, and host. When the user
submits, the result returns as a `forloop.form-response` part on the next turn
and the app completes the original request.

It is not a grant, a scope change, a task state, or a replacement for the app
console. The original A2A connection remains the authorization. The form ticket
is a 60-second, **zero-scope** assertion that can only bootstrap the app's own
form session.

## Choose the surface (plan the decision into the story)

| Need | Plan |
|---|---|
| Multi-field conversational input: booking details, address, date range, preference matrix, a choice that is error-prone as prose | **Peer form** |
| One short answer or a quick clarification | **Plain text** question in the agent's answer |
| Durable management (list/edit/cancel bookings), account settings, auth, payments, uploads, long forms the user revisits | **In-app console** at `managementUrl` — not a peer form |
| App-to-app delegation, a scheduled/background job, or any turn with no signed-in human | **Plain text** — `formsEnabled` is false; `request_form` is unavailable |

Ask the user one question to classify the need:

> "Should the app collect these details in one small form inside the chat, or
> is a normal chat question enough?"

- If the answer is "a page I can come back to", plan the console, not a form.
- If the app is only ever called by another app, plan the text fallback and do
  not create a form story.

## Hard platform limits (do not design around them)

- **User-facing only.** The platform sets `formsEnabled=true` only when the
  caller sprint is the user's **personal agent** (`kind='personal_agent'`).
  App-to-app callers get `false`; the app's agent must ask a plain-text
  question. Never plan a form that a peer agent is supposed to fill in — there
  is no human there.
- **No form on a scheduled/background turn.** A background job has nobody to
  fill the panel. Plan text or an app-owned UI the user opens themselves.
- **One open form per turn.** The runtime keeps a single form marker and the
  client shows one active form; the last `request_form` wins. Do not plan
  parallel forms or a multi-step wizard across several open panels. A new step
  after a submit is a new form with a new `requestId`.
- **The personal agent never gets `request_form`.** Only the app's application
  agent creates a form. The personal agent relays the outcome and forwards the
  submitted response to the exact peer.
- **The form is not a grant.** It cannot create or widen an A2A connection,
  request scopes, or replace consent. Consent stays on `/permissions`.
- **Platform origins are blocked.** The resolver rejects the ForLoop client
  origin and the A2A gateway host, even if they are listed in the manifest.
- **`formAllowedHosts` is exact-host only.** Optional, additive, max 8 exact
  hostnames, no wildcard/suffix/IP literal/platform host. A relative
  `/forms/<id>` URL on the API host is preferred and needs no entry.

## What the user experiences

Plan the story around the visible states, not only the happy path:

| State | What the user sees | What the app does |
|---|---|---|
| Form requested | A form card with the title and **Open form**; the panel header shows the peer name, title, and host and opens a sandboxed iframe | Owns the page; no platform credential on it |
| Submitted | The panel closes and the conversation resumes | Reads the submission by `requestId`/`submissionId` and completes the request |
| Cancelled | The panel closes; no response turn | The form expires; an `input-required` peer task is best-effort cancelled |
| Expired | "This form expired" + "Ask the app again" (dismisses) / Dismiss | A normal message can produce a new form with a **new** `requestId` |
| Blocked / no `ready` in 10 s | Open in a new tab + "I submitted it" + Cancel | The new-tab path sends `{ submitted: true }`; the app looks up the latest submission |
| Invalid URL | "This app's form couldn't be opened" + Dismiss | No iframe, no link; the user continues in chat |
| Submit fails | The panel stays open with an error | A repeat submit reuses the same `submissionId`; the app is idempotent |

**Relaying to the user:** say the app opened a form, not that the planner or
the personal agent built it. Never paste the form URL. Do not claim it was
submitted before the follow-up turn completes.

Good:

> "The app will open a short booking form in the conversation. Fill it in and
> the app will finish the booking; if the form can't open, you can open it in a
> new tab and tell the app you submitted it."

> "The form expired. Ask the app again and it will send a fresh one."

Bad:

> "Here is the form URL…" (the planner never has a usable URL)

> "Your booking is confirmed." (only the app's follow-up result can say that)

## How the request appears in the conversation

The app's agent returns a `forloop.form-request` data part. The platform
normalizes it, resolves the URL against the app's manifest, and stores it on the
outbound task. The client shows the form card/panel. The user's personal agent
sees the peer result and tells the user the app opened a form; it does not paste
the URL or claim submission. After the user submits, the follow-up turn carries
a `forloop.form-response` part (`requestId`, optional `submissionId`, or
`submitted: true`) to the **same peer**.

This is the behaviour the Developer must build. Put it in the story's
acceptance criteria rather than describing it only in prose.

## Plan the work — story breakdown

Use `forloopStoryTemplate` with `templateSlug="basic-task"`, assign code stories
to `forLoopDeveloper`, and keep each story ≤5 points. A typical peer-form
feature is 3–5 stories.

### 1. Contract and manifest

- Agent-callable operations: `POST /forms` (create) and
  `GET /forms/:id/submission` (read) in `tools[]`.
- Manifest `formAllowedHosts` only if the form host differs from every
  `application.baseUrl` / `baseUrls` host. Relative `/forms/<id>` is preferred.
  If a different form host is used, its `/forms/session` and submit routes must
  live on that host (or be proxied there); the agent endpoints stay on the API
  host.
- Bump the manifest version; record the contract diff as compatible.
- State the chosen surface (peer form vs text vs console) and why.

### 2. Backend form API and ticket

- `POST /forms` — acting-user auth via `app_request`; returns `{formId, url}`.
- `GET /forms/:id` — serves the form HTML with the form CSP.
- `POST /forms/session` — verifies `fl_form_ticket`, checks `aud`, `env`, `sub`,
  `cid === form:<requestId>`, and empty scopes; returns a short-lived bearer
  JSON session, not a cookie.
- `POST /forms/:id/submit` — bearer session + origin/CSRF check; idempotent by
  form id; returns `{submissionId}`.
- `GET /forms/:id/submission` — acting-user auth; returns the stored values.
- Persistence: user, title, expiry, status, submission; no user id from the
  body/query.

### 3. Form page and CSP

- Same-origin page with `<form data-request-id="...">`.
- CSP: `frame-ancestors <platform client origin>; form-action 'self';
  connect-src 'self'; base-uri 'none'`; `Referrer-Policy: no-referrer`. Never
  reuse the console CSP (`frame-ancestors 'none'`).
- The page strips `fl_form_ticket` with `history.replaceState`, exchanges it for
  a session, and posts `forloop:form:ready` / `height` / `submitted` /
  `cancelled` / `error` to `fl_parent_origin` — never `*`.
- No top navigation, popups, downloads, third-party scripts, platform
  credentials, or grant/scope UI.

### 4. Agent behaviour and follow-up

- Create the form through `app_request`, call `request_form` with a stable
  `requestId` (8–128 chars, the app's form id), a short title, and an expiry
  (60–3600 s), then end the turn.
- On the follow-up `forloop.form-response`, read the submission through
  `app_request` and complete the original request. `submitted: true` means
  "look up the latest submission by `requestId`".
- If `formsEnabled` is false, ask a plain-text question and never call
  `request_form`.
- Do not paste the form URL, render the form in chat, or claim submission.

### 5. Verification

- URL resolution rejects platform origins, non-`https`, credentials, fragments,
  non-443 ports, IP literals, wildcards, and non-allow-listed hosts.
- Ticket claims: `aud`, `env`, `sub`, `cid`, empty scopes; expired/tampered
  ticket rejected; no ticket in logs.
- Submit idempotency: repeat returns the same `submissionId`; a race does not
  create two submissions.
- Expiry, cancel, blocked frame, invalid URL, submit failure, and `submitted:
  true` fallback are all visible and recoverable.
- Manual E2E covers form card → sandboxed panel → submit → conversation
  continues; cancel; expiry; blocked frame; third-party host; platform host
  rejected; mobile width.

## Integration brief for the Developer story

Copy this into the story's `## Integration brief` and set
`assigneeAgentKey="forLoopDeveloper"`:

```text
Peer form: yes. Required skill: forloop-peer-forms.
Surface: peer form for <fields> because <why text/console is insufficient>.
Host: relative /forms/<id> on the app API host (or formAllowedHosts: <exact host>).
Agent tools: POST /forms (create), GET /forms/{formId}/submission (read).
Browser routes: GET /forms/:id, POST /forms/session, POST /forms/:id/submit.
Ticket: fl_form_ticket -> aud/env/sub/cid=form:<requestId>, scopes empty; exchange
for a short-lived bearer JSON session; strip the ticket before ready.
Page: CSP frame-ancestors <platform origin>, form-action 'self',
connect-src 'self', base-uri 'none'; postMessage ready/height/submitted/
cancelled/error to fl_parent_origin only; no top navigation/popups/third-party
scripts/platform credentials.
Follow-up: forloop.form-response -> read submission by requestId/submissionId;
submitted:true = latest submission by requestId; complete the original request.
Fallback: formsEnabled=false -> plain-text question; no request_form.
```

## Acceptance criteria to copy into the story

```text
1. Given the app's agent needs structured input and the caller is the user's
   personal agent, when it creates and requests a form, then the command bar
   shows a form card with the title and an **Open form** action, and the panel
   header shows the app name, title, and host while the form loads in a
   sandboxed iframe.
2. Given the user submits the form, when the follow-up forloop.form-response
   arrives, then the app reads the submission by requestId/submissionId and
   completes the original request in the conversation.
3. Given the user cancels or the form expires, when they return to the chat,
   then no form-response is sent, the panel is closed/expired, and asking again
   sends a normal message that can produce a new form with a new requestId.
4. Given the caller is another app (formsEnabled=false), when the app needs
   input, then it asks a plain-text question and never calls request_form.
5. Given the app returns a platform-origin or non-allow-listed form URL, when
   the client receives it, then it refuses to frame it, shows the couldn't-open
   state, and the user can dismiss and continue in chat.
6. Given the iframe never signals ready or cannot be framed, when 10 seconds
   pass, then the user can open the form in a new tab, press "I submitted it"
   (submitted:true), or cancel.
```

## App-to-app and no-human limitation

- `formsEnabled` is **true only for a user-facing personal-agent caller**. The
  platform sets `false` for app-to-app turns, so a peer app cannot ask the other
  app's agent to fill a form.
- A scheduled/background turn has no signed-in human; do not plan a form for
  it. Plan a text question or an app-owned screen.
- The personal agent has no `request_form` and cannot render a form. It only
  relays that the peer app opened one and forwards the submitted response to the
  exact peer.
- If the user asks for "a form another app sends to my agent", explain the
  limitation and plan the text fallback or an app console.

## What not to plan

- A form for consent, permissions, OAuth, payment-card entry, or secrets.
- A form served by the platform, a CDN, or a host outside the app's declared
  base hosts / `formAllowedHosts`.
- A page that navigates the top window, opens popups/downloads, loads
  third-party scripts, or relies on third-party cookies.
- A "wizard" of multiple simultaneously open forms.
- A form as the authorization for an app action, or a scope-widening flow.
- Code in the plan document — the Developer implements it. The plan states the
  contract and acceptance criteria.

## Checklist

- [ ] The surface decision is recorded (peer form vs plain text vs console).
- [ ] The caller is user-facing; the app-to-app/scheduled fallback is stated.
- [ ] Manifest `formAllowedHosts` and agent `tools[]` are specified.
- [ ] All five form endpoints and the ticket claims are in the brief.
- [ ] The page CSP, postMessage protocol, and sandbox rules are acceptance
      criteria.
- [ ] Follow-up handling covers `submissionId` and `submitted: true`.
- [ ] Expiry, cancel, blocked frame, invalid URL, submit failure, and retry are
      covered.
- [ ] The Developer story names `forloop-peer-forms` as a required skill (and
      `a2a-agent-spec` for the manifest change).
- [ ] Stories are assigned to `forLoopDeveloper`, sized ≤5 points, and created
      with `forloopStoryTemplate`.
- [ ] The user-facing wording follows `user-communication` and never includes a
      form URL or a premature "submitted" claim.
