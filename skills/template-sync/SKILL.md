---
name: template-sync
description: >
  Pull the latest forloop-project-base template into an existing project repo.
  Use at the start of a development session, or when asked to "update the
  project from the template", "sync the template", or "get the latest"
  scaffolding. The tool never overwrites an existing root file.
license: MIT
metadata:
  version: "1.0.0"
  category: development
  sources:
    - ForLoop project-base template
---

# Template Sync

Project repos are generated from `forloop-cc/forloop-project-base` as a one-time snapshot and drift from it over time. `forloopTemplateSync` brings the repo up to the latest template **safely**.

## When to run

- At the **start of a development session**, on a clean tree, before starting the task.
- On demand when asked to update the project from the template.
- **Under the ECS developer runner:** the template is pre-synced before the agent starts and the added/changed/removed files are injected into the prompt as a `## Template sync` section. Call this tool only as a **fallback** when that section is absent.

## What it does (and does not)

| The tool does automatically (conflict-free) | The agent decides |
|---|---|
| Refresh `.forloop/template/**` to the latest | Any file the template changed that **already exists** at the root |
| Add template files that are **missing** at the root | — |
| Stamp `.version`; commit the result | — |

It **never overwrites an existing project file at the root** (only `.version` and `.forloop/template/**` are managed) — clobbering is impossible by construction.

## How to use it

1. Ensure the working tree is clean (commit or stash). The tool refuses a dirty tree unless `force` is passed.
2. Call `forloopTemplateSync` (`check: true` first if you only want the plan).
3. Read the report.

## Deciding on the reported files

The report lists `updated` files (template changed; a root copy exists). For each, apply it only if it is a *shared scaffold improvement*:

- **Normally safe to apply:** `.github/**`, `infra/**`, `scripts/**`, `Makefile` — platform plumbing apps rarely customize.
- **Usually leave alone:** `backend/src/**`, `frontend/src/**`, `tests/**`, `playwright.config.ts`, `.env.example` — app-owned; apply only when clearly not a rewrite of the user's logic.

To apply one file:

```bash
git show template/main:.forloop/template/<path> > <path>
```

Then run the relevant tests before committing.

## Failure handling

- **Dirty tree** → commit/stash first (or `force` when intentional).
- **Fetch fails / no credentials** → the tool retries once with the plugin's GitHub token when present; if it still fails, report it and do not retry blindly.
- **A run failed** → it rolls back the working tree; re-run once the cause is fixed. Re-runs are idempotent (version-gated).
