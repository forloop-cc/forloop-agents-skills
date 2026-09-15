---
name: admin-panel-planning
description: >
  Planning guide for the reusable Admin Resource Framework that ships with
  every ForLoop user application that has a backend. Load when the user
  requests admin screens, CMS features, resource management (products,
  orders, articles, FAQs, user roles, settings), management dashboards, or
  "how do I manage X in my app" features. Products/promotions are
  pre-registered; everything else is added declaratively via one registry
  file.
license: MIT
metadata:
  version: "1.0.0"
  category: planning
  sources:
    - ForLoop project-base template (backend/src/admin, frontend/src/admin)
    - Platform doc 18 (Reusable Admin Panel Framework)
---

# Admin Panel Planning (Admin Resource Framework)

## Overview

Every ForLoop user application with a backend ships a **reusable,
registry-driven admin panel**. It can manage products/promotions (through
the ForLoop sync pipeline) AND any other resource the app owns (plain CRUD
on the app's own DynamoDB table).

- The panel lives at `/admin` in the app (token login).
- Adding a managed resource = appending ONE entry to
  `backend/src/admin/adminResources.ts`. Routes, API, sidebar, list page,
  and forms are generated.
- **Do NOT plan bespoke admin pages or one-off admin routes.**

## When to load this skill

Load when the user requests any of:

- "Add an admin panel / management screen / CMS for …"
- "I want to manage X (products, articles, orders, users, settings) in my app"
- "Back-office / dashboard for editing data"
- Extending the existing admin panel (new resource, custom action)

**Not needed:** apps without a backend have no admin panel; pure
storefront/content features that regular users see are normal frontend
stories (not admin).

## Resource decision checklist

For every management surface the user wants, capture:

1. **Resource identity**
   - `key` (URL slug, e.g. `articles`), `label` (sidebar name)
2. **Fields** — name, label, type (`text | textarea | number | boolean |
   select | date`), required?, listColumn?
3. **Mode** (the critical decision)
   - `direct` — app-owned data → immediate CRUD on the app's DynamoDB
     (default for everything that is NOT Stripe-backed)
   - `changeSet` — ForLoop-synced entities (Stripe products/promotions) →
     draft → preview → apply pipeline. Only for catalog resources.
4. **Permissions** — scope names, e.g. `articles.manage`; grant via
   `ADMIN_SCOPES` env (comma separated).
5. **Operations** — create/update/archive/delete flags (archive preferred
   over hard delete).
6. **Extension needs** (rare) — custom actions, normalize/validate hooks,
   custom renderers.

## Story templates

### Register a resource (standard story)

```
Title: Register <resource> in the admin panel

Description:
## Goal
Manage <resource> from the app's admin panel using the Admin Resource
Framework — no bespoke routes or pages.

## Scope
- [ ] Registry entry in backend/src/admin/adminResources.ts (mode direct,
      fields <list>, permissions <scope>, operations <list>)
- [ ] Verified via GET /admin/resources descriptor (field schema + operations)
- [ ] CRUD round-trip test (create → list → update → archive)

## Acceptance Criteria
1. Given an admin token with <scope>, When GET /admin/resources, Then the
   resource descriptor appears with the declared fields
2. Given POST /admin/<resource>, When a record is created, Then it persists
   in the app DynamoDB table and appears in GET /admin/<resource>
3. Given PATCH /admin/<resource>/:id, When fields change, Then the record is
   updated
4. Given DELETE /admin/<resource>/:id, When called, Then the record is
   archived (archivedAt set), not hard-deleted

Points: 2
Assignee: forLoopDeveloper
```

### Customize a resource workflow (only when extension points are needed)

Use `extensions.actions` / `extensions.hooks` / renderer keys — never a new
route. 2-3 points, `forLoopDeveloper`.

## Anti-patterns

| ❌ Don't | ✅ Do Instead |
|----------|--------------|
| Plan bespoke admin pages for every resource | Add a registry entry — UI/API come for free |
| Plan admin panels for apps without a backend | Skip; framework lives in the backend template |
| Plan `changeSet` mode for app-owned data | `direct` mode (changeSet is for ForLoop-synced catalog) |
| Plan hard-delete-first resource lifecycles | Archive by default; hard delete only via `operations.delete` |
| Plan new admin routes/controllers | Generic router only |
| Plan to store the admin token in the repo | Token login screen + localStorage; backend validates via `ADMIN_API_TOKEN` (static) or ForLoop `floop_` token introspection (v2: token owner must have sprint access + `admin:panel`/`catalog:admin` scope) |

## Relationship to stripe-planning

Products (`products`) and promotions (`promotions`) are pre-registered
changeSet resources. Stripe Phase 1 admin stories simply verify that wiring
against this framework. Plan non-catalog management with THIS skill.
