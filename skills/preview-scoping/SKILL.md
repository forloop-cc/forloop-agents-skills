---
name: preview-scoping
description: >
  Use during UI requirements to define and get explicit user approval for an
  app surface inventory before offering an app preview. Owns the inventory table
  (surface, route, type, class, states, story) and the hard rules that make a
  preview scoped and shippable. Do not use for single-page Chrome capture
  previews — those use the Designer's capture mode and need no inventory.
license: MIT
metadata:
  version: "1.0.0"
  category: planning
  sources:
    - ForLoop planner preview flow
    - INVEST criteria (agile modeling)
triggers:
  - "app preview"
  - "design preview"
  - "surface inventory"
  - "screen inventory"
  - "route map"
  - "UI requirements"
integrations:
  - plan-documentation
  - story-creation
  - task-tracking
  - forLoopDesigner
---

# Preview Scoping

## Overview

An app preview is only useful if it covers the screens the team will actually build. This skill defines the **surface inventory** that the Planner owns, gets the user to approve, and hands to the Designer before any `app-preview` work starts.

The rule is simple: **no approved inventory, no app preview**. The Designer returns `BLOCKED` with gaps instead of guessing at screens.

This skill covers **multi-screen user-facing apps only**. A single captured page or one-screen mockup — including the Chrome extension capture flow — uses Designer `mode="capture"` and keeps its existing contract: one page, no inventory, no blocking.

## When to Use

- The user wants a preview of an app with more than one screen.
- UI requirements are being gathered for a new app or a new major flow.
- A plan or task breakdown includes user-facing screens/routes.
- The Designer returned `BLOCKED` and the inventory needs gaps filled.

## When NOT to Use

- Single-page mockups and Chrome extension captures — use `mode="capture"` instead.
- Backend-only work, infrastructure, or non-visual tasks.
- A request where the user only wants copy or component styling on an existing, already-scoped screen.

## Surface Inventory (Planner-owned)

The Planner writes the inventory during requirements, not the Designer. Each row is one surface:

| Surface | Route | Type | Class | States | Story |
|---------|-------|------|-------|--------|-------|
| Home | `/` | page (entry) | `in-preview` | default, loading, empty, error, signed-in, signed-out | #101 |
| App shell / nav | `*` | layout | `in-preview` | signed-in, signed-out | #102 |
| Login | `/login` | page (auth) | `in-preview` | default, error, signed-out, return-to-intended | #103 |
| Projects list | `/projects` | page (data) | `in-preview` | default, loading, empty, error | #104 |
| Project detail | `/projects/:id` | page (data) | `in-preview` | default, loading, not-found, error | #105 |
| Settings | `/settings` | page (data) | `in-preview` | default, loading, error | #106 |
| Checkout | `/checkout` | page | `out-of-scope:later-release` | — | — |
| Health | `/health` | page (ops) | `out-of-scope:operational` | — | — |
| Admin | `/admin` | page (framework) | `out-of-scope:admin-framework` | — | — |

### Class values

- `in-preview` — included in the preview and in the build.
- `out-of-scope:<reason>` — deliberately excluded. The reason is required; examples: `later-release`, `operational`, `admin-framework`, `not-a-user-screen`.
- `needs-story` — real work that has no story yet. It cannot be approved as `in-preview` until a story is assigned.

### Template baseline routes

Every app starts from the project-base router. Include these rows and disposition each one (in-preview or out-of-scope) even if the app will not use it:

```
/
/health
/users
/checkout
/success
/pricing
/auth/forloop/callback
/auth/forloop/launch
/admin
/admin/:resourceKey
```

Add every new route the plan introduces. A route that exists in the template but is missing from the inventory is a gap.

## Hard Rules

1. **Entry/root and shell are mandatory for user-facing apps.** The inventory always has a row for `/` (or the app's single entry route) and a row for the shell/nav layout (`*`).
2. **Every template route is dispositioned.** Each baseline route above is either `in-preview` or `out-of-scope:<reason>`. No blanks.
3. **Data screens list empty / error / loading.** If a screen fetches data, those states are in the `States` column. The preview shows the default plus one exemplar non-default state per data screen ("split by state" applies to stories and acceptance criteria, not to inflating frame count).
4. **Auth screens list signed-in / signed-out / return.** Login, gated routes, and auth callbacks record all three. Signed-out access to a protected route must define the redirect and the return path.
5. **Settings get a row if the app has users.** Any user account implies a settings surface (profile, preferences, or account); disposition it explicitly.
6. **Every `in-preview` row has a route and a story.** Route is concrete (`/projects/:id`, `*` for shell). Story is a story ID or a planned story slot that task-tracking will create. A preview frame without a route/story is not approvable.
7. **`/` is always in scope — a redirect is a decision.** "It just redirects" still means the route, the target, and the signed-in/out behaviour are recorded.
8. **One story per screen/route.** The shell/nav gets its own story. Do not bundle multiple screens into one story to reach coverage faster.
9. **No UI story dispatch until coverage is complete.** Every inventory route is covered by a story or explicitly `out-of-scope:<reason>`.
10. **Capture is exempt.** Chrome extension captures and one-screen mockups use `mode="capture"`; do not force an inventory onto them.

## User-Approved Checklist

Present the inventory (or the ≤3-screen inline version) to the user and stop. Do not offer the preview until the user explicitly approves it.

```
App surface inventory approval

- [ ] One entry/root row (`/` or the single entry route)
- [ ] One shell/nav row (`*`)
- [ ] Every template baseline route has a row and a disposition
- [ ] Every out-of-scope row has a reason
- [ ] Every data screen lists loading / empty / error
- [ ] Auth rows list signed-in / signed-out / return-to-intended
- [ ] Settings has a row if the app has users
- [ ] Every in-preview row has a concrete route and a story (or a planned story slot)
- [ ] Every in-preview screen is one story (shell is its own story)
- [ ] Nothing is left `needs-story`

Approve this inventory before I generate the preview?
```

Record the approval in the plan. If the user changes the inventory later, re-approve it and re-dispatch the affected flows.

## Scaling

| Screens | Presentation |
|---------|--------------|
| ≤ 3 | Inline in chat: one compact table or bullet list, then the approval checklist |
| 4–12 | Full inventory table (surface, route, type, class, states, story) |
| 12+ | Group by flow first (e.g. Onboarding, Core app, Billing, Admin); inventory per flow; one Designer dispatch/file per flow |
| > 24 frames | Hard cap: prioritize entry/root + shell + core flow, mark the rest `pending` on a `PARTIAL` response, and finish in follow-up dispatches. Do not silently drop approved rows. |

Split by **flow**, not by arbitrary page count. A flow is a user journey (sign up → verify → onboarding); each flow preview keeps its own entry and shell context.

## Planner Wiring

1. During UI requirements, load this skill and draft the inventory from the requirements + template baseline routes.
2. Include `needs-story` only as a temporary state; resolve it before approval.
3. Present the inventory and wait for explicit approval (see checklist).
4. Offer the app preview only after approval.
5. Dispatch the Designer with `mode="app-preview"`, the approved inventory, and the template baseline routes.
6. On return, record the `fileId`(s), `routeMap`, and `outOfScope` in the plan and task file.
7. Put the `## Screen / Route` block in every UI story; one story per screen/route.
8. Do not dispatch UI stories until every inventory route is covered or explicitly out-of-scope.
9. A Designer `BLOCKED` response means the inventory is incomplete — fix the inventory with the user, do not invent screens or bypass the check.
10. A `PARTIAL` response is a normal outcome: present the covered preview + pending rows, then finish the remaining flows.

## Designer Wiring

- `mode="app-preview"` validates the approved inventory against the hard rules. If the entry/root row, the shell row, the out-of-scope dispositions, or a template route disposition is missing, the Designer returns `BLOCKED` with `gaps` and writes no file.
- The Designer produces one labelled frame per `in-preview` screen (entry/root first, shell/nav included), with the default plus one exemplar state per data screen.
- Above ~6 screens, the Designer splits by flow into separate preview files and returns them in `files[]` with a primary `fileId`.
- `mode="capture"` ignores this skill and keeps the existing single-page contract.

## Pressure Test (Manual, Inline)

This is a documentation-level check, not a CI test.

**Scenario:** "Build an app with four screens only: dashboard, projects, project detail, settings."

**Attempt 1 — incomplete inventory**

Rows supplied: dashboard, projects, project detail, settings. No `/` root, no shell/nav, no template-route dispositions, no out-of-scope rows.

Expected Designer response:

```json
{
  "status": "BLOCKED",
  "mode": "app-preview",
  "gaps": [
    "missing entry/root row for /",
    "missing shell/nav row (*)",
    "template route /health has no disposition",
    "template route /checkout has no disposition",
    "template route /admin has no disposition",
    "no out-of-scope rows"
  ],
  "designNotes": []
}
```

No preview file is written.

**Attempt 2 — corrected inventory**

Add: Home `/` (in-preview, entry), shell/nav `*` (in-preview), `/health` + `/checkout` + `/success` + `/pricing` + `/admin` + `/admin/:resourceKey` as `out-of-scope:<reason>` (or in-preview with stories), auth routes dispositioned, settings states listed.

Expected Designer response: `status: "SUCCESS"` (or `PARTIAL` if over the cap) with `fileId`, `screens[]`, `routeMap[]`, `outOfScope[]`, and one frame per in-preview screen.

**Attempt 3 — capture unchanged**

The same page name dispatched with `mode="capture"` returns the existing capture shape (`status`, `fileId`, `fileName`, `url`, `page`, `sections`, `designNotes`) and a single page file. It is never `BLOCKED` for a missing inventory.

## Anti-Patterns

| # | Don't | Do Instead |
|---|-------|------------|
| 1 | Skip the inventory because "there are only four screens" | Four screens still need root, shell, and template dispositions |
| 2 | Let the Designer infer the missing routes | Send back `BLOCKED` gaps; fix the inventory with the user |
| 3 | Add out-of-scope rows after the preview | Disposition every route before approval |
| 4 | Force an inventory onto a Chrome capture | Use `mode="capture"` with no inventory |
| 5 | Treat the preview file as the route source of truth | The approved inventory + `routeMap` are the source of truth |
| 6 | Leave `/` out because it "just redirects" | Record `/`, its target, and the signed-in/out behaviour |
| 7 | Bundle five screens into one story | One story per screen/route; shell is its own story |
| 8 | Create UI stories before route coverage | Cover every route or mark it `out-of-scope` first |
| 9 | Drop pending rows on a `PARTIAL` response | Present `pending`, then finish the remaining flows |
| 10 | Put states only in acceptance criteria | Also list them in the inventory and the story's Screen/Route block |

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "The user only asked for four screens" | The app still has a root, shell, auth, and template routes; scope them explicitly |
| "The Designer can make reasonable assumptions" | Guessed screens are rework; `BLOCKED` is the feature |
| "We'll add out-of-scope later" | Later means the preview misleads the team now |
| "One story can cover the whole flow" | It hides route/state gaps and breaks acceptance criteria |
| "The preview is just a mockup, routes don't matter" | The story brief and Developer dispatch use those routes |
| "Capture needs the same rigor" | Capture is one page; it keeps the unchanged contract |
| "PARTIAL means failure" | `PARTIAL` is a controlled stop with the approved scope and a pending list |

## Quality Gates

- [ ] Inventory has an entry/root row and a shell/nav row
- [ ] Every template baseline route has a disposition
- [ ] Every out-of-scope row has a reason
- [ ] Every data screen lists loading / empty / error
- [ ] Auth rows list signed-in / signed-out / return
- [ ] Settings row exists if the app has users
- [ ] Every in-preview row has a concrete route and a story
- [ ] No row is left `needs-story`
- [ ] User explicitly approved the inventory before the preview
- [ ] Designer dispatch includes `mode="app-preview"` + the approved inventory + baseline routes
- [ ] Returned `fileId`(s), `routeMap`, and `outOfScope` are recorded
- [ ] Every UI story has a `## Screen / Route` block
- [ ] Every inventory route is covered by a story or explicitly out-of-scope
- [ ] Capture requests were not blocked by this workflow
