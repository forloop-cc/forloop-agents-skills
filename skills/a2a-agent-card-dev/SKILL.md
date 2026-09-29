---
name: a2a-agent-card-dev
description: >
  Governs how the development team authors and maintains the app's
  forloop-manifest.json and its derived A2A Agent Card (Agent Bridge).
  Use when: any story adds or changes app endpoints/capabilities (the manifest
  MUST be updated in the same change), when validating a manifest against the
  schema, when the agent card needs public-exposure review, or at build-complete
  finalization. DO NOT use when: changes touch no app surface (docs-only,
  tests-only, internal refactors without API changes).
license: MIT
metadata:
  version: "1.1.0"
  category: development
  sources:
    - docs/a2a_user_application/01_agent2agent_protocol_communication_plan.md (§6.7, §6.9)
    - docs/a2a_user_application/02_a2a_implementation_plan.md (Step 7.3)
    - docs/a2a_user_application/09_a2a_zero_touch_enablement_plan.md (ingest → auto-enable)
    - forloop-project-base/.forloop/template/forloop-manifest.example.json (canonical shape)
    - forloop-project-base/.forloop/template/scripts/validate-manifest.mjs (enforced rules)
triggers: story adds/changes app endpoints, manifest validation, build-complete
---

# ForLoop A2A Agent Card Development

## Goal

Keep the app's public A2A Agent Card honest and current. The card is **derived
server-side** — never hand-edited — from one source of technical truth:
`forloop-manifest.json` in the sprint repo. This skill makes sure every
capability change lands in the manifest at build time.

**Do not confuse the two artifacts.** "Agent Card" here means the ForLoop card
the server derives from your manifest. It is **not** the A2A protocol card
document: fields like `protocolVersion`, `capabilities`, `defaultInputModes`,
`securitySchemes`, a root-level `agent` object, or tools with `method`/`path`/
`inputSchema`/`outputSchema` are protocol-card shapes. Written into
`forloop-manifest.json` they are either rejected (`application.name` missing ⇒
the whole file is refused, leaving `manifest: null`) or silently dropped, and
the agent ends up with no contract. Start from
`forloop-manifest.example.json` and run `node scripts/validate-manifest.mjs`.

## Manifest schema (field contract)

```jsonc
{
  "version": "1.0.0",                        // optional string (NOT "schemaVersion" — that key is dropped)
  "application": {
    "name": "My App",                      // REQUIRED string
    "description": "What the app does",    // optional
    "baseUrl": "https://app.example.com",  // the app's real API base
    "auth": {}                             // optional auth config object
  },
  "agentPersona": {
    "instructions": "How the agent serves callers" // optional
  },
  "tools": [
    {
      "id": "create_order",                // REQUIRED, unique, snake_case or kebab-case
      "name": "Create order",              // REQUIRED human name
      "description": "Creates an order…",  // REQUIRED what/when
      "whenToUse": "Customer asked to…",
      "tags": ["orders", "write"],
      "examples": ["Create an order for item X"],
      "input": { "type": "object", "properties": { } },   // JSON schema
      "output": { "type": "object", "properties": { } },
      "endpoints": ["POST /api/orders"],
      "preconditions": ["User authenticated"],
      "errorHandling": "409 → order already exists, return its id",
      "idempotent": true,
      "internal": false,                   // TRUE = never exposed on the card
      "constraints": "max 10 items per order"
    }
  ]
}
```

## Update rules (REQUIRED)

1. **Every story that adds or changes app endpoints MUST update `tools[]` in
   the same change.** The manifest is build-time knowledge capture — a PR that
   changes the API but not the manifest is incomplete.
2. **Never edit card JSON manually.** The Agent Card is merged server-side from
   the manifest (technical) + DB cosmetics (`docs/a2a_user_application/01` D12
   §6.7). User-edited name/description/tags/publicSkills override the manifest
   and survive ingest — do not fight them.
3. **Mark internal-only tools** with `"internal": true` so the card and
   `publicSkills` can exclude them (auth, healthchecks, admin).

## Public-exposure guidance

- Default posture: a tool is public unless it is internal.
- Write `constraints` from business rules discovered during development.
- The repo is the source of truth **only for capability**; cosmetics live in
  the ForLoop UI (Agent Bridge settings). A UI edit wins over the manifest.

## Validation checklist (before build-complete)

- [ ] `node scripts/validate-manifest.mjs` prints **PASS** (same rules the
      platform enforces — CI and the deploy pipeline both run it)
- [ ] `application.baseUrl` is the real deployed public URL, no `{placeholders}`
- [ ] `agentPersona.instructions` is one **string** (an array is dropped)
- [ ] `application.name` present; `tools[]` ids unique
- [ ] Every public API endpoint used by stories has a matching tool entry
- [ ] Tool `input`/`output` are valid JSON schemas
- [ ] `examples` cover the main happy path
- [ ] Internal tools flagged `internal: true`
- [ ] `version` bumped when tool behavior changes materially
- [ ] No duplicate endpoints mapped to different tools unintentionally

## Ingest + drift

- **Primary: the deploy pipeline.** The workflow step reads the manifest from
  the exact commit being deployed (`git show "$GITHUB_SHA:forloop-manifest.json"`),
  validates it, then `PUT /api/opencode/sprints/:id/a2a-manifest` with
  `sourceCommitSha` + `sourceCommitTimestamp`. A rejected manifest (400) fails
  the deploy with the platform's reason; an older commit is refused with 409 and
  the newer stored manifest is kept — so a re-run can never regress the contract.
- **Also:** GitHub push webhook on `forloop-manifest.json` (best-effort — its
  failures are logged, not surfaced), build-complete Step Function step, and the
  Agent Bridge UI paste box.
- `manifestSha` drift warnings appear in the UI when the last ingested hash
  differs — fix by re-deploying (preferred) or re-uploading the manifest.

## Finalization gate (planner)

At build-complete: run the validation checklist, confirm the manifest diff
matches the stories shipped, and remind the owner that card cosmetics (name,
description, tags, publicSkills) belong in the Agent Bridge settings UI.