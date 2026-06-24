---
name: forloop-skill
description: >
  Manage ForLoop sprints, stories, AI agents, files, organizations, and users directly from opencode.
  Covers token setup, sprint CRUD, story CRUD (with templates), file operations, S3 sync,
  organization management, user profile/quotas, and AI agent queries/triggers.
  Use when: any ForLoop operation is needed via plugin tools.
  DO NOT use when: planning sprints (use sprint-planning), creating tasks
  (use task-tracking), or managing files (use file-management).
license: MIT
metadata:
  version: "2.0.0"
  category: administration
  sources:
    - ForLoop API documentation (forloop.cc)
---

# ForLoop Integration Skill

This skill enables all ForLoop operations via plugin tools. The forLoopPlanner agent uses these tools for every ForLoop interaction.

## Available Tools

### Token Management
- `forloopTokenSet` — Set or update your ForLoop API token. Args: `token: string`, `profile?: string`.
- `forloopTokenGet` — Check if a token is configured. Args: `profile?: string`. Returns masked token or instructions.

### User & Quota Management
- `forloopUserProfile` — Get current user profile (name, email, tier, bio, avatar). No args.
- `forloopUserQuotas` — Check user quota limits (orgs, sprints, storage, free stories). No args.
- `forloopOrganizationQuotas` — Get quota info for a specific organization. Args: `organizationId: number`.

### Organization Management
- `forloopOrganizationList` — List all organizations user belongs to. Args: `ownedOnly?: boolean` (default: `false`).
- `forloopOrganizationGet` — Get details of a specific org. Args: `organizationId: number`.
- `forloopOrganizationCreate` — Create new org. Args: `name: string`, `description?: string`.
- `forloopOrganizationUpdate` — Update org details (owner only). Args: `organizationId: number`, `name?: string`, `description?: string`.
- `forloopOrganizationDelete` — Delete org permanently. Args: `organizationId: number`, `confirm?: boolean` (default: `false`).

### Sprint Management
- `forloopSprintList` — List all accessible sprints. Args: `organizationId?: number`, `includeSystemOrg?: boolean` (default: `true`).
- `forloopSprintGet` — Get sprint details. Args: `sprintId?: number` (auto-detected), `includeStories?: boolean` (default: `true`), `includeFiles?: boolean` (default: `true`).
- `forloopSprintCreate` — Create new sprint. Args: `title: string`, `startDate: string` (ISO YYYY-MM-DD), `endDate: string` (ISO), `description?: string`, `isPrivate?: boolean`, `organizationId?: number`.
- `forloopSprintUpdate` — Update sprint fields. Args: `sprintId: number`, plus any of `title`, `description`, `startDate`, `endDate`, `isPrivate`.
- `forloopSprintDelete` — Delete sprint and all stories. Args: `sprintId: number`, `confirm?: boolean` (default: `false`).

### Story Management
- `forloopStoryTemplate` — Create story from template. **MANDATORY for all non-doc_folder stories.** Args: `templateSlug: string` (`"basic-task"` or `"basic-note"`), `taskTitle: string`, `sprintId?: number` (auto-detected), `description?: string`, `priority?: string` (`low`/`medium`/`high`/`critical`), `points?: number` (0-10), `assigneeAgentKey?: string`, `status?: string`.
- `forloopStoryCreate` — Create story (doc_folder type ONLY). Args: `title: string`, `sprintId?: number`, `type?: string` (`"doc_folder"` or `"schedule"`), `description?: string`, `priority?: string`, `points?: number`, `status?: string`, `assigneeAgentKey?: string`.
- `forloopStoryGet` — Get story details. Args: `storyId: number`, `includeComments?: boolean` (default: `true`). Returns sprint info, status, priority, points, assignee, description, comments with author info and artifacts.
- `forloopStoryUpdate` — Update story fields. Args: `storyId: number`, plus any of `title`, `description`, `status` (`todo`/`in_progress`/`done`/`blocked`), `priority`, `points` (0-10).
- `forloopStoryDelete` — Delete a story. Args: `storyId: number`, `confirm?: boolean` (default: `false`).
- `forloopStoryBreakdown` — Get AI breakdown of a story into subtasks. Args: `storyId: number`.
- `forloopStoryEstimate` — Get AI-powered story point estimate with rationale. Args: `storyId: number`.

### Template Management
- `forloopTemplateList` — List available story templates (Basic Task `basic-task`, Basic Note `basic-note`). No args.

### File Management
- `forloopFileList` — List files in a sprint. Args: `sprintId: number`.
- `forloopFileUpload` — Upload file to S3. Args: `filePath: string`, `sprintId: number`, `description?: string`, `folder?: string`, `storyId?: number` (for doc_folder linking).
- `forloopFileDelete` — Delete file from sprint. Args: `fileId: number`, `confirm?: boolean` (default: `false`).
- `forloopFileDownloadUrl` — Get presigned download URL for a file. Args: `fileId: number`.
- `forloopFileDownload` — Download a file to the local sandbox. Args: `fileId: number`, `destPath?: string`.

### Doc Folder & Sync
- `forloopCreateDocFolder` — Create a document folder story. Args: `sprintId?: number`, `title: string`, `description?: string`, `permissions?: string` (`public`/`team`/`private`, default: `team`).
- `forloopSyncAivyFolder` — Ensure doc_folder exists. Creates it if missing. Args: `sprintId?: number` (auto-detected), `title?: string` (default: `"forloop Aivy doc"`).
- `forloopAivyDocGet` — Get doc_folder story ID for linking uploads. Args: `sprintId?: number`, `title?: string` (default: `"forloop Aivy doc"`).
- `forloopSyncS3ToLocal` — Download sprint files from S3 to `~/.forloop/sprint-{id}/`. Args: `sprintId?: number`, `syncKnowledge?: boolean` (default: `true`), `syncPlans?: boolean` (default: `true`), `syncTasks?: boolean` (default: `true`), `overwrite?: boolean` (default: `false`).
- `forloopSyncLocalToS3` — Upload local file to S3. Args: `filePath: string`, `sprintId?: number`, `action?: string` (`"upsert"` or `"delete"`), `folder?: string` (auto-inferred), `storyId?: number`.

### Schedule Management
- `forloopScheduleCreate` — Schedule a meeting. Args: `sprintId?: number`, `title: string`, `description?: string`, `startAt: string` (ISO datetime), `endAt: string` (ISO datetime), `timezone?: string` (default: `"UTC"`), `videoUrl?: string`.
- `forloopScheduleUpdate` — Update a scheduled meeting. Args: `storyId: number`, plus any of `title`, `description`, `startAt`, `endAt`, `videoUrl`.

### AI Agent Integration
- `forloopAgentQuery` — Send natural language query to AI agent. Args: `query: string`, `agentKey?: string` (default: `"forLoopTaskSupervisor"`), `sprintId?: number`, `enableMutations?: boolean` (default: `false`).
- `forloopAgentSuggest` — Get AI suggestions. Args: `type: string` (`"breakdown"`/`"estimate"`/`"acceptance_criteria"`/`"test_cases"`/`"related"`/`"sprint_planning"`), `sprintId?: number`, `storyId?: number`, `query?: string`.
- `forloopAiDeveloperSprint` — Trigger developer agent via Step Functions. Args: `sprintId: number`, `message?: string`.
- `forloopDeveloperStatus` — Check running developer task. Args: `sprintId?: number`. Returns SFN status, elapsed time, branch, story progress (done/in-progress/total), errors.
- `forloopAiAgentList` — List available AI agents. No args.
- `forloopSprintAiAgentsUpdate` — Enable/disable agents for sprint. Args: `enabledAgentKeys: string[]`, `sprintId?: number`.
- `forloopAgentHistory` — View conversation history. Args: `sprintId?: number`, `limit?: number` (1-200, default: 50).
- `forloopAgentClear` — Clear conversation history. Args: `sprintId?: number`, `confirm?: boolean` (default: `false`).

---

## Setup

### 1. Create API Token
1. Go to [forloop.cc/profile?tab=api-tokens](https://forloop.cc/profile?tab=api-tokens)
2. Click "Create New Token", select scopes
3. Recommended scopes: `sprint:read`, `sprint:write`, `story:read`, `story:write`, `agent:query`, `profile:read`
4. Copy the token (starts with `floop_`)

### 2. Configure Token
```
forloopTokenSet(token="floop_abc123...")
```
Or store manually in `~/.config/forloop/tokens.json`:
```json
{
  "default": "floop_abc123...",
  "lastUpdated": "2026-03-23T00:00:00.000Z"
}
```

## Context Resolution

The plugin auto-detects sprint context from:
1. **Environment variable**: `FORLOOP_SPRINT_ID`
2. **Git branch**: Branches named `sprint-123` are auto-detected
3. **Manifest**: `~/.forloop/manifest.json` with `activeSprintId`

## Core Workflow Patterns

### Session Startup
```
forloopTokenGet()                                         → verify auth
forloopSyncAivyFolder(sprintId=N)                         → ensure doc_folder
forloopSyncS3ToLocal(sprintId=N)                          → pull latest files
forloopSprintGet(sprintId=N, includeStories=true)         → load sprint context
forloopAgentHistory(sprintId=N, limit=50)                 → load conversation history
forloopDeveloperStatus(sprintId=N)                        → check if developer running
forloopStoryGet(storyId=<each-done>, includeComments=true)→ read developer comments
```

### Sprint Creation
```
forloopOrganizationList()                                 → check orgs
forloopSprintCreate(title="...", startDate="...", endDate="...", organizationId=N)
```

### Story Creation (Always Use Template)
```
forloopSyncAivyFolder(sprintId=N)                         → ensure doc_folder
forloopStoryTemplate(                                     → MANDATORY for tasks
  templateSlug="basic-task",
  taskTitle="Implement feature X",
  sprintId=N,
  priority="high",
  points=5,
  assigneeAgentKey="forLoopDeveloper")
```
**Never use `forloopStoryCreate` without a template** unless the type is `doc_folder`.

### Upload Workflow (Ensure → Get → Upload → Verify)
```
forloopSyncAivyFolder(sprintId=N)
forloopAivyDocGet(sprintId=N)                             → returns docFolderId
forloopSyncLocalToS3(
  filePath="~/.forloop/sprint-N/plan/sprint-plan.md",
  sprintId=N,
  folder="project/plans",
  storyId=docFolderId)
forloopFileList(sprintId=N)                               → verify
```

### Trigger Development
```
forloopAiDeveloperSprint(sprintId=N, message="Implement all stories")
forloopDeveloperStatus(sprintId=N)                        → check progress
```

## Examples

### List sprints
```
forloopSprintList()
forloopSprintList(organizationId=2)
```

### Get sprint with stories
```
forloopSprintGet(sprintId=123, includeStories=true, includeFiles=true)
```

### Create an implementation story (with template)
```
forloopStoryTemplate(templateSlug="basic-task", taskTitle="Implement login API", sprintId=123, priority="high", points=5, assigneeAgentKey="forLoopDeveloper", description="POST /api/auth/login with JWT")
```

### Create a documentation story
```
forloopStoryTemplate(templateSlug="basic-note", taskTitle="Auth architecture notes", sprintId=123)
```

### Create a document folder
```
forloopStoryCreate(title="Project Documents", type="doc_folder", sprintId=123)
```

### Check developer task status
```
forloopDeveloperStatus(sprintId=123)
```

### View conversation history
```
forloopAgentHistory(sprintId=123, limit=50)
```

### Get story details with developer comments
```
forloopStoryGet(storyId=456, includeComments=true)
```

## Environment Variables

- `FORLOOP_API_URL` — API endpoint (default: `https://api.forloop.cc`)
- `FORLOOP_ENV` — Environment selector (`production` or `development`)
- `FORLOOP_ALLOW_DEV` — Set to `true` to allow dev API usage
- `FORLOOP_SPRINT_ID` — Default sprint ID
- `FORLOOP_TOKEN_SET` — Set to `"true"` when token is configured

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "No API token configured" | Run `forloopTokenSet(token="floop_...")` |
| "No sprint ID provided" | Set `FORLOOP_SPRINT_ID` or use `sprint-XXX` branch |
| "Insufficient permissions" | Create new token with required scopes |
| "Quota exceeded" | Check quotas: `forloopUserQuotas()` |

## Compliance

**API token must be configured before using any ForLoop tools.** Never hardcode tokens in files.

## Anti-Patterns

| # | Don't | Do Instead |
|---|-------|-----------|
| 1 | Hardcode API tokens in config files | Use `forloopTokenSet` or `~/.config/forloop/tokens.json` |
| 2 | Create stories without templates | Always use `forloopStoryTemplate` with `templateSlug` |
| 3 | Use `forloopStoryCreate` for tasks | Task stories MUST use `forloopStoryTemplate` |
| 4 | Upload files without doc_folder | Ensure → get → upload → verify pattern |
| 5 | Use multiple conflicting sprint ID methods | Use one method: env var, git branch, or explicit ID |
| 6 | Share tokens in chat or commit them | Tokens start with `floop_` — treat as secrets |

## Quality Gates

- [ ] Token configured via `forloopTokenSet`
- [ ] Token has required scopes for intended operations
- [ ] Sprint context resolved (env var, git branch, or manifest)
- [ ] API URL correct for environment (`FORLOOP_ENV`)
- [ ] Doc folder created before any upload
- [ ] All task stories created via template (`forloopStoryTemplate`)
