---
name: storage-planning
description: Plan ForLoop Storage for user-owned files — decide owner/subject/grant model, upload intents and signed URLs, scan/quota/trash, and the Storage integration brief. Use when users upload photos/documents/files, app A stores and app B reads, or a user shares objects/collections; not for sprint S3, account quotas, static assets, Media jobs, or A2A proxies.
license: MIT
compatibility: opencode
metadata:
  audience: planners
  workflow: core-services
---

## What I do

I turn a user-owned file requirement into a ForLoop Storage plan the Developer can build:
who owns the bytes, which subject/connection type carries the call, how the upload and
scan lifecycle works, how sharing/grants/invites work, and what the integration brief
must contain. Storage is a core service; I never design a custom S3 system.

## When to use me

Use me for runtime user content:

- "Users upload photos/documents and see them later."
- "App A stores a file; app B should read the ones the user shares."
- "Let a user share one object or a collection with another app or another ForLoop user."
- "Show upload progress while the file is scanned."
- "Let users trash/restore files and see storage usage."
- "Allow an app background access to a user's shared files with a standing grant."

## Do not use me for

- Sprint S3/project files (`file-management`: plan/task/knowledge/design uploads, doc_folder, `forloopFileUpload`).
- Account or organization storage quotas (`user-management`).
- App static assets (Creator / `frontend/public/`).
- App-owned Media generation jobs (`media` core service).
- App-to-app A2A proxies or peer delegation (`a2a-agent-spec`); Storage is called directly.
- A custom S3 bucket, CloudFront distribution, presigned-URL service, or malware scanner.

## Fail closed before planning

Storage is not plannable until the platform contract exists. Run discovery first, then STOP
and tell the user the integration is not ready if any of these is missing:

- [ ] Storage is returned by `core_services_search` as a `system` service with a pinned `version`.
- [ ] `core_service_get({ agentId, version })` returns a contract with `checksum` (stored manifest) and `generatedChecksum` (matches `contract-artifact.json`).
- [ ] The contract declares an `authMode` that supports delegated user assertions and states the user-subject connection flow.
- [ ] The contract lists the upload, object, collection, shared, share-request, usage, and health operations you plan to use.
- [ ] The contract lists the scopes, states, and error codes you plan to quote.
- [ ] The generated app type `backend/src/generated/<service>-contract.d.ts` (`storage-contract.d.ts` for Storage) and the template Storage module `backend/src/forloop/storage/` exist. They are delivered by the consumer-kit plan; do not plan around their absence.

If any item is missing, do not write an integration brief that pretends it exists. Do not
substitute sprint S3, an app-subject connection, `frontend/public/`, or a custom S3 design.

## 1. Discovery first, never invent

Run `core_services_search({ query: "<the requirement>", directOnly: true })` and
`core_service_get({ agentId, version })`. Quote only what the registry/contract returns:
service name, `serviceCode`, `baseUrl`, `authMode`, scopes, pinned version, stored + generated checksums, tools,
states, errors, price. Never invent a service, endpoint, scope, version, price, state, or
error. If the contract differs from this skill, the contract wins.

## 2. Decide the ownership model

| Requirement | Owner | Route |
|---|---|---|
| User's photos/documents/files they expect to keep or share | `user:<userId>` | Storage |
| App-generated/published static asset (logo, theme image, seed media) | App repo | Creator → `frontend/public/` |
| App-owned media generation job/artifact | App | Media core service |
| Sprint planning/task/knowledge/design file | Sprint | `file-management` (sprint S3) |

Storage supersedes F2 for user-owned object storage. An app is the creator/custodian/actor,
not the owner. Record `createdByApp=<appPublicId>`; never plan app-owned objects in v1.
Per-app areas are `user/<userId>/app/<appPublicId>/...`; an app can only use its own area.

## 3. Identity, connection, and consent

User-owned Storage uses a **delegated user assertion** minted by the platform:
`sub=idp:forloop:<userId>`, `act.sub=<app>`, `appPublicId=<app>`,
`cid=<user-subject connection id>`, env, scopes, contract version, short TTL. The app backend
proves the user with a Login with ForLoop user delegation token, exchanges it with the app
credential, and calls Storage. Never put the user token, refresh token, assertion, or signed
URL in browser JS, logs, stories, or URLs.

- The connection is **user-subject**: the user consents; the app owner does not approve it as an app grant. The app backend presents the app-subject Storage connection id (or a path-less `targetAgentId`) as a hint; it must not require an out-of-band user-subject connection id.
- Pass `subjectType: "user"` to `a2a_request_connection`. If the tool/platform cannot create or return a user-subject request, record `Connection: pending user consent (UI-only)` and stop. Never create or reuse an app-subject request as a workaround.
- An app-subject connection is only for an explicit **standing app grant** the owner approved. It never grants access to a user's own area and is never a substitute for user consent.
- A data grant is separate from both connection layers. A connection is not a grant; a grant is not a connection.

## 4. Upload, scan, and download lifecycle

Plan the flow from the pinned contract; the expected shape is:

1. The app backend creates an upload intent (reserve quota, bind owner/area/key/size/type/checksum, get a short-lived presigned PUT and a one-time completion token).
2. The app/provider uploads bytes directly to S3 via the presigned PUT. Browser-origin uploads are deferred in v1.
3. The app calls complete with the completion token; Storage verifies key/owner/size/type/checksum and creates a pending object.
4. The app polls or re-reads metadata until the scan state is final. No download URL exists before `available`.
5. Download mints a short-lived signed URL on demand. Lists never contain signed URLs.

Never persist a signed URL as data, never log it, never put it in a story or chat, and never
paste it into a docs example. Treat it as a bearer token. Default disposition is attachment;
inline is only the contract's safe media allowlist after a clean scan.

## 5. Sharing and grants

| Mode | Who acts | Identity | Notes |
|---|---|---|---|
| Interactive app grant | The user uses app B now | User assertion for B | Bound to `(owner, granteeApp=B)`; read-only |
| Standing app grant | App B with no user online | App assertion | Explicit owner warning, optional expiry, audit; only granted resources |
| User grant/invite | Another ForLoop user (Alice) | Alice's user assertion/console | Single-use invite, first authenticated acceptor, 7 days, no re-share |
| Object grant | Any grantee | Either | Fixed to one immutable object |
| Collection grant | Any grantee | Either | Dynamic membership while active; moving an object out ends collection access |

Apps may request; only the owner approves/revokes in the Storage console. Plan the console as
a **link-only management surface**: the planner never approves, mints, or revokes a grant.
App B calls Storage directly; never plan app A as a byte proxy. A grantee cannot re-share.
Revocation is immediate for new requests; issued URLs expire within 60 seconds.

## 6. Scan, quota, trash, and console

- Scan states and errors come from the contract. Plan pending/available/quarantined/scan_failed handling; no fail-open.
- Quota is free in v1: 5 GB and 100,000 objects per user. Reserve at intent, reconcile at complete. Storage is not billed per call; do not run the paid wallet pre-check unless the registry publishes a price.
- Trash holds bytes for 30 days, revokes direct object grants, and removes the object from its collection. Restore returns it to Unfiled and does not reactivate grants.
- The console is a user-vault: Overview, Files, Collections, Shared by me, Shared with me, Requests, Invites, Usage, Docs. It is not an app selector and cannot mint connections.

## 7. Integration brief extension

Use the planner's standard brief plus these fields. Copy values from the pinned contract; do
not copy this template as if it were contract text.

```
- Ownership: owner `user:<userId>`; creator app `<appPublicId>`; area `user/<userId>/app/<appPublicId>/...`
- Subject type: `user` (delegated user assertion) | `app` (standing grant only)
- Connection type: `user-subject` `<connection id or pending user consent>` | `app-subject` `<standing connection id>`
- Grant type: `interactive app` | `standing app` | `user invite` | `object` | `collection` (read-only)
- Upload operations: `<contract operations for intent → presigned PUT → complete → poll>`
- Scan/quota/trash: `<contract states/errors>; free 5 GB / 100,000 objects; 30-day trash; restore to Unfiled`
- Payer: `user` (free in v1; no app-wallet charge unless the registry publishes a price)
- Management URL: `<Storage user-vault console URL from the service; link only>`
- Conformance: owner=user; grant matrix; pending scan; quarantine; quota; trash/restore; revoked grant
```

## 8. Story split

Plan these stories (combine only when the brief is genuinely small):

1. **Connection + consent**: Login with ForLoop user token storage (server-side), user-subject connection, delegated exchange, `connection_required`/connect prompt, fail-closed errors.
2. **App A upload**: upload intent, direct presigned PUT, complete, poll scan, list/download, signed-URL handling.
3. **App B access**: user connection for interactive access; app connection for standing; shared list; download; no A→B proxy.
4. **Sharing**: object/collection grant requests, invite flow or console deep link, standing-grant warning/expiry, revocation.
5. **Lifecycle**: scan states, quota, trash/restore, purge/404/410 behavior.
6. **Tester negative cases**: ungranted, foreign object, revoked grant, pending scan, quarantined, quota exceeded, app-subject on own area.

Assign implementation to `forLoopDeveloper`, validation to `forLoopTester`, deploy/smoke to
`forLoopDevops`. The Developer must load `storage-integration`; the Tester must prove the
negative grant matrix.

## Checklist

- [ ] `core_services_search` returned Storage; `core_service_get` returned the pinned contract + stored/generated checksums.
- [ ] The brief quotes only contract endpoints, scopes, states, and errors.
- [ ] Owner is the user; `createdByApp` is recorded; no app-owned v1 object.
- [ ] The connection is user-subject; app-subject appears only for an explicit standing grant.
- [ ] The upload flow has intent → direct PUT → complete → scan poll → short-lived download.
- [ ] No signed URL or token is in a story, chat, log, or persisted field.
- [ ] The brief names a grant/invite mode and the negative cases.
- [ ] The console is link-only; the planner does not approve/mint.
- [ ] Sprint S3/`forloopFileUpload`, `frontend/public/`, custom buckets, and A2A proxies are excluded.

## Example

User: "Let people upload photos and share some with app B."

Plan: run `core-service-discovery`; Storage is the user-owned file service. Load this skill.
Confirm the pinned contract; plan a user-subject connection and delegated exchange; App A
creates an upload intent, PUTs directly, completes, polls until available; App B gets an
interactive app grant or a standing grant; the console link is where the user approves;
stories split connection, A upload, B access, sharing, lifecycle, tester negatives. Do not
plan `file-management`, a custom S3 bucket, or app A proxying bytes.

## Rules

- Storage is user-owned by default; the app is the creator/custodian/actor, never the owner.
- Never use sprint S3 (`forloopFileUpload`), `frontend/public/`, or a custom bucket for runtime user content.
- Never use an app-subject connection for user-owned data or an own user area.
- Never put `X-Forloop-Subject` or `X-A2A-User-Authorization` on Storage `/v1`; Storage uses the platform delegated assertion.
- Never invent a service, endpoint, scope, version, price, state, or error.
- Never approve, mint, or revoke a grant/invite; link to the user-vault console.
- Never persist or print a signed URL, upload token, completion token, user token, or assertion.
- Never route this to `file-management`, `user-management`, Creator static assets, Media jobs, or an app-to-app proxy.
- If the contract, delegated exchange, generated type, or template module is missing, fail closed and say so plainly.
