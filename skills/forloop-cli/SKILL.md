---
name: forloop-cli
description: Use the forloop CLI binary for all ForLoop operations. Covers authentication, sprint management, story CRUD, file operations, sync, and developer triggers via bash commands with JSON output. Use when any ForLoop operation is needed — do NOT use plugin tools.
version: 1.0.0
category: administration
---

# ForLoop CLI Skill

The `forloop` CLI binary is the primary interface for all ForLoop operations. This skill documents every command the planner needs.

## Installation

### Via npm (recommended)

```bash
npm install -g @forloop-cc/forloop-cli
```

### Via Homebrew (macOS)

```bash
brew install forloop-cc/tap/forloop
```

### Verify installation

```bash
forloop --version
forloop --help
```

### Authentication

After installing, authenticate with your ForLoop API token:

```bash
forloop auth login --api-key floop_xxxxx
```

Get your token at [forloop.cc/profile?tab=api-tokens](https://forloop.cc/profile?tab=api-tokens). Tokens start with `floop_`.
Required scopes: `sprint:read`, `sprint:write`, `story:read`, `story:write`, `agent:query`, `profile:read`.

### Check authentication status

```bash
forloop auth status
```

### Update to latest version

```bash
npm install -g @forloop-cc/forloop-cli@latest
```

### Uninstall

```bash
npm uninstall -g @forloop-cc/forloop-cli
brew uninstall forloop  # if installed via Homebrew
```

---

## Command Pattern

Always use these flags with every command:
- `--output json` — machine-parseable output (parse with `jq`)
- `--non-interactive` — prevents prompts (required in agent context)

Parse responses:
```bash
RESULT=$(forloop sprint get --output json --non-interactive 2>&1)
if [ $? -ne 0 ]; then
  echo "Error: $RESULT"
  exit 1
fi
echo "$RESULT" | jq '.title'
```

### Exit Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Proceed |
| 3 | Not authenticated | Tell user to run `forloop auth login` |
| 4 | Quota exceeded | Tell user their tier limit is reached |
| Other | General error | Show error message, ask user |

### Sprint ID Auto-Detection

The CLI auto-detects sprint ID from `FORLOOP_SPRINT_ID` env var or git branch name (e.g., `sprint-14`). Most commands work without explicit `--id` or `--sprint`.

---

## Authentication

### Check auth status
```bash
forloop auth status
```
Output is plain text (no JSON). Shows "Not authenticated" if no token is set. Always exits 0.

### Authenticate (only if the user asks to set a token)
The user must run this themselves:
```bash
forloop auth login --api-key floop_xxxxx
```
Never ask the user for their token — direct them to run the command above.

---

## Sprint Commands

### List all sprints
```bash
forloop sprint list --output json --non-interactive
# Optional: filter by org or include system organization sprints
forloop sprint list --org-id 2 --output json --non-interactive
forloop sprint list --include-system-org --output json --non-interactive
```
Returns: `[{ "id": 14, "title": "...", "status": "active", ... }]`

### Get sprint details
```bash
forloop sprint get --output json --non-interactive               # auto-detects sprint
forloop sprint get --id 14 --output json --non-interactive       # explicit
forloop sprint get --id 14 --no-files --output json --non-interactive  # stories only
```
Returns sprint with title, status, dates, and embedded stories array. Stories and files included by default.

### Create a sprint
```bash
forloop sprint create \
  --title "Sprint 15: API Redesign" \
  --start-date 2026-06-15 \
  --end-date 2026-06-28 \
  --output json --non-interactive

# Optional flags:
#   --description "Focus on..."
#   --private
#   --org-id 2
```
Returns: `{ "id": 15, "title": "...", ... }`

### Update a sprint
```bash
forloop sprint update --id 14 --title "Updated Title" --output json --non-interactive
# Partial updates: only pass flags you want to change
```

### Delete a sprint (with confirmation)
```bash
forloop sprint delete --id 14 --confirm --output json --non-interactive
```
Requires `--confirm`. Warn the user before running this.

---

## Story Commands

### List stories (via sprint get)
Stories are embedded in sprint output. Use `forloop sprint get --output json` to get all stories.

### Create a story from a template (basic-task or basic-note)
```bash
forloop story create \
  --title "Implement login API endpoint" \
  --type basic-task \
  --sprint 14 \
  --priority high \
  --points 3 \
  --assignee-agent forLoopDeveloper \
  --description "Create POST /api/auth/login with JWT response" \
  --output json --non-interactive
```
`--type` options: `basic-task` (for implementation work), `basic-note` (for documentation/advisory).

### Create a document folder
```bash
forloop story create \
  --title "Project Documents" \
  --sprint 14 \
  --output json --non-interactive
```
Omit `--type` to create a doc_folder (the default when no type is specified).

### Create a schedule/meeting
Schedule-meeting stories are not directly creatable via the CLI. Use a `basic-note` to document schedule details, or create via the web app.

### Get story details
```bash
forloop story get --id 78 --output json --non-interactive
forloop story get --id 78 --no-comments --output json --non-interactive   # skip comments
```
Returns: `{ "id": 78, "title": "...", "status": "todo", "comments": [...], ... }`

### Update story status/fields
```bash
forloop story update --id 78 --status done --output json --non-interactive
forloop story update --id 78 --priority critical --points 5 --output json --non-interactive
```

### Delete a story (with confirmation)
```bash
forloop story delete --id 78 --confirm --output json --non-interactive
```

---

## Template Commands

### List available templates
```bash
forloop template list --output json --non-interactive
```
Returns: `[{ "id": 1, "name": "Basic Task", "slug": "basic-task", "description": "..." }]`

---

## File Commands

### List files in a sprint
```bash
forloop file list --sprint 14 --output json --non-interactive
```

### Upload a file to a sprint
```bash
forloop file upload --path ./requirements.md --sprint 14 --output json --non-interactive
# Optional: --description "Requirements doc" --folder project/docs --story-id 101
```

### Delete a file (with confirmation)
```bash
forloop file delete --id 42 --confirm --output json --non-interactive
```

### Get a file download URL
```bash
forloop file download --id 42 --output json --non-interactive
```
Returns: `{ "url": "https://presigned-url..." }`

### Create a document folder (for file organization)
```bash
forloop folder create --title "Planning Docs" --sprint 14 --output json --non-interactive
```

---

## Sync Commands

### Ensure doc folder exists for sync
```bash
forloop sync aivy-folder --output json --non-interactive
forloop sync aivy-folder --sprint 14 --title "forloop Aivy doc" --output json --non-interactive
```

### Get doc folder ID
```bash
forloop sync aivy-doc-get --output json --non-interactive
forloop sync aivy-doc-get --sprint 14 --output json --non-interactive
```
Returns JSON: `{ "docFolderId": 101, "exists": true }`. Parse with `jq -r '.docFolderId'`.

### Download sprint files from S3 to local
```bash
forloop sync s3-to-local --output json --non-interactive
forloop sync s3-to-local --sprint 14 --output json --non-interactive
```
Downloads knowledge/, plan/, task/ files to `~/.forloop/sprint-{id}/`.

### Upload local files to S3
```bash
forloop sync local-to-s3 --path ~/.forloop/sprint-14/plan/sprint-plan.md --output json --non-interactive
# Optional: --sprint 14 --folder project/plans --story-id 101
```
Auto-infers remote folder from path:
- `plan/` → `project/plans`
- `task/` → `project/tasks`
- `knowledge/` → `project/knowledge`

---

## User & Organization Commands

### Get user profile
```bash
forloop user profile --output json --non-interactive
```

### Check quotas
```bash
forloop user quotas --output json --non-interactive
forloop org quotas --org-id 2 --output json --non-interactive
```

### List organizations
```bash
forloop org list --output json --non-interactive
forloop org list --owned-only --output json --non-interactive
```

### Organization CRUD
```bash
forloop org get --id 2 --output json --non-interactive
forloop org create --name "Engineering" --output json --non-interactive
forloop org update --id 2 --name "New Name" --output json --non-interactive
forloop org delete --id 2 --confirm --output json --non-interactive
```

---

## Developer Agent Commands

### Check developer sprint status
```bash
forloop agent developer-status --output json --non-interactive
forloop agent developer-status --sprint 14 --output json --non-interactive
```
Returns: `{ "status": "RUNNING", "elapsed": "5m", "stories": { "done": 3, "in_progress": 2, "total": 8 } }`

### Trigger developer agent
```bash
forloop agent developer-sprint --sprint 14 --message "Implement remaining stories" --output json --non-interactive
```

### View agent conversation history
```bash
forloop agent history --output json --non-interactive
forloop agent history --sprint 14 --limit 50 --output json --non-interactive
```

---

## Workflow Patterns

### Session startup (always do this first)
```bash
# 1. Verify auth
forloop auth status

# 2. Sync from S3 to get latest files
forloop sync aivy-folder --output json --non-interactive
forloop sync s3-to-local --output json --non-interactive

# 3. Load sprint context
forloop sprint get --output json --non-interactive | jq '.stories'
```

### Sprint creation pattern
```bash
# 1. Check org first
forloop org list --output json --non-interactive | jq '.[].id'

# 2. Create sprint
forloop sprint create --title "..." --start-date YYYY-MM-DD --end-date YYYY-MM-DD --org-id N --output json --non-interactive

# 3. Verify
forloop sprint get --output json --non-interactive | jq '{id, title, startDate}'
```

### Story creation pattern
```bash
# 1. Ensure doc folder for sync
forloop sync aivy-folder --output json --non-interactive
DOC_ID=$(forloop sync aivy-doc-get --output json --non-interactive | jq -r '.docFolderId')

# 2. Create stories from template
forloop story create --title "..." --type basic-task --sprint N --priority medium --points 3 --output json --non-interactive

# 3. Verify
forloop sprint get --output json --non-interactive | jq '.stories[] | {id, title, status}'
```

### Upload workflow
```bash
# 1. Write local file
echo "content" > ~/.forloop/sprint-14/plan/sprint-plan.md

# 2. Upload to S3 (linked to doc folder)
forloop sync local-to-s3 --path ~/.forloop/sprint-14/plan/sprint-plan.md --story-id $DOC_ID --output json --non-interactive

# 3. Verify
forloop file list --sprint 14 --output json --non-interactive | jq '.[] | select(.originalName | contains("sprint-plan"))'
```

---

## Important Rules

1. **Always use `--output json` and `--non-interactive`** — the agent is non-interactive
2. **Check exit codes** — non-zero means something went wrong (exit code 3 = auth error on API, 4 = quota)
3. **Never ask the user for their token** — direct them to run `forloop auth login`
4. **Use `jq` for JSON parsing** — `jq '.[].id'`, `jq -r '.title'`, `jq 'length'`
5. **Delete commands require `--confirm`** — warn the user before running
6. **Sprint ID auto-detection is reliable** — prefer auto-detection over explicit `--id`
7. **Test `forloop` is installed** at startup: `which forloop || echo "CLI not installed"`
8. **Auth status is text-only** — `forloop auth status` outputs plain text, always exits 0
