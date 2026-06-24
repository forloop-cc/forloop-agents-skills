# ForLoop Agents & Skills

A collection of specialized AI agents and reusable skills that deeply integrate with the [ForLoop](https://forloop.cc) platform — an AI-powered platform that runs on **Loop Engineering**: a continuous cycle of Plan → Code → Review → Deploy → Learn. Each phase tightens with every iteration as AI agents and humans work together to ship faster. These agents and skills give your AI coding assistant direct access to ForLoop sprints, stories, files, AI developer agents, and team coordination tools.

> **OpenCode users:** For the best experience, install the [ForLoop opencode plugin](https://github.com/forloop-cc/forloop-opencode-plugin-planner) first — it provides native tools that are faster and more reliable than CLI commands. The plugin installer also sets up these agents and skills automatically.

## What is This?

**Agents** are AI personas with defined roles, temperature, and permissions — they act as specialized team members like a sprint planner or story evaluator. **Skills** are markdown playbooks agents load on-demand to handle specific tasks correctly, from sprint planning to file management.

Together they enable your AI coding assistant to:

- **Plan sprints** — define goals, estimate stories, assign work across your team
- **Create and track stories** — generate structured stories from natural language, with status tracking
- **Trigger AI development** — dispatch ForLoop's AI developer agents to implement stories automatically
- **Manage files** — upload, download, and sync project files with S3-backed sprint storage
- **Coordinate teams** — manage organizations, users, permissions, and shared knowledge bases
- **Everything in one platform** — planning, coding, testing, and deployment all happen within ForLoop's cloud environment

These capabilities come from ForLoop's platform, exposed through either the plugin's native tools (`@forLoopPlanner`) or the standalone CLI (`@ForLoopPlannerCLI`). The agents decide which to use and load the corresponding skill automatically.

### Getting a ForLoop API Token

All ForLoop operations authenticate with an API token. To get one:

1. Go to [forloop.cc/profile?tab=api-tokens](https://forloop.cc/profile?tab=api-tokens)
2. Click **Create New Token**
3. Select scopes: `sprint:read`, `sprint:write`, `story:read`, `story:write`, `agent:query`, `profile:read`
4. Copy the token (it starts with `floop_`)

Set the token by telling your agent _"set my API token"_ and pasting it when prompted. Tokens are stored securely at `~/.config/forloop/tokens.json` with restricted permissions.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/forloop-cc/forloop-agents-skills/main/install.sh | bash
```

The installer clones this repo and symlinks everything into the right discovery paths.

| Flag | Target | Agents in | Skills in |
|------|--------|-----------|-----------|
| (default) | opencode | `~/.config/opencode/agents/` | `~/.config/opencode/skills/` |
| `--claude` | Claude Code | — | `~/.claude/skills/` |
| `--codex` | Codex | — | `~/.agents/skills/` |
| `--all` | All three | opencode only | all three platforms |

Agents use opencode-specific frontmatter (permissions, mode, temperature). Skills are platform-agnostic markdown and work everywhere.

### Manual Install

```bash
git clone https://github.com/forloop-cc/forloop-agents-skills.git ~/.config/forloop/agents-skills

# opencode
ln -sf ~/.config/forloop/agents-skills/agents/*.md ~/.config/opencode/agents/
ln -sfn ~/.config/forloop/agents-skills/skills/*/ ~/.config/opencode/skills/

# Claude Code
ln -sfn ~/.config/forloop/agents-skills/skills/*/ ~/.claude/skills/

# Codex
ln -sfn ~/.config/forloop/agents-skills/skills/*/ ~/.agents/skills/
```

## Agents

### ForLoop Planner (`@forLoopPlanner`)

Planning-only sprint specialist. Uses ForLoop plugin tools to gather context, confirm requirements, produce plan documents, and create actionable stories. Requires the ForLoop opencode plugin.

- **Type:** Primary agent (switchable with TAB)
- **Temperature:** 0.3 — focused and deterministic
- **Best for:** Sprint setup, story creation, task breakdown, sprint reviews, team coordination
- **Dependency:** [ForLoop opencode plugin](https://github.com/forloop-cc/forloop-opencode-plugin-planner)

Try saying: _"Set up sprint 15 for our API redesign, starting next Monday, two weeks"_

### ForLoop Planner CLI (`@ForLoopPlannerCLI`)

A standalone agent that uses the `forloop` CLI binary to interact with the ForLoop platform. No opencode plugin required — just install the CLI, authenticate, and it works on any AI coding platform with bash access. Ideal for users who prefer CLI workflows or don't have the plugin installed.

- **Type:** Primary agent (switchable with TAB)
- **Temperature:** 0.3 — focused and deterministic
- **Best for:** Standalone CLI workflows, environments without the opencode plugin, CI/CD automation
- **Dependency:** [@forloop-cc/forloop-cli](https://www.npmjs.com/package/@forloop-cc/forloop-cli) (`npm install -g @forloop-cc/forloop-cli`), then `forloop auth login --api-key floop_xxxxx`

Try saying: _"Create sprint 15 for our API redesign, starting June 15, two weeks"_

### Story Evaluator (`@forLoopStoryEvaluator`)

Subagent that evaluates task complexity and produces ready-to-create story payloads for the Planner to execute.

- **Type:** Subagent (invoked by Planner or via `@` mention)
- **Temperature:** 0.2 — highly deterministic for accuracy
- **Best for:** Point estimation, story breakdown, complexity analysis, structuring tasks
- **Permissions:** Full tool access with external directory access to `~/.forloop/`

Try saying: _"@forLoopStoryEvaluator break down our authentication feature and estimate the stories"_

## Skills

Skills are organized by category. Agents load them automatically when they detect a matching trigger.

### Planning (10 skills)

The core planning workflow — from sprint setup through execution.

| Skill | Description |
|-------|-------------|
| **sprint-planning** | Create actionable sprints with well-defined goals, capacity planning, and appropriately sized stories. Integrates with `~/.forloop/sprint-{id}/` for persistent context. |
| **story-creation** | Well-structured user stories following INVEST principles with Gherkin Given/When/Then acceptance criteria. Planning-only — does not implement features. |
| **story-points** | Systematic estimation using complexity, effort, uncertainty, and risk. Fibonacci scale: 0, 1, 2, 3, 5, 8, 10. Stories above 5 points should be split. |
| **task-tracking** | Generate actionable task lists from plan documents. Estimates points, applies templates, creates stories in ForLoop, and maintains synchronized task files. |
| **template-based-tasks** | Transform natural language into structured ForLoop stories using Basic Task and Basic Note templates. Ensures consistent metadata for AI agents and collaboration. |
| **plan-documentation** | Create and maintain sprint plan documents with user confirmation. Stored in `~/.forloop/sprint-{id}/plan/`, synced to S3 for team access. |
| **agent-auto-assignment** | Automatically match stories to the right AI agent based on story type and intent. Classifies work as planning, development, or deployment. |
| **forloop-context** | Session startup — loads knowledge, plans, and tasks from `~/.forloop/` for continuity. Resolves sprint ID from manifest, env var, or git branch. |
| **tech-stack-default** | Standardized ForLoop tech stack defaults (React 18 + Vite, Lambda Node.js 20, DynamoDB, Terraform). Assumed automatically during planning — never asks for confirmation. |
| **knowledge-management** | Capture project learnings and technical decisions automatically. Syncs to S3 for team-wide access. |

### Administration (4 skills)

User, file, and core platform management.

| Skill | Description |
|-------|-------------|
| **forloop-skill** | Core ForLoop integration using plugin tools — token setup, sprint CRUD, story CRUD, AI agent queries. Used by `@forLoopPlanner`. |
| **forloop-cli** | Core ForLoop integration using the `forloop` CLI binary — authentication, sprint CRUD, story CRUD, file ops, sync, and developer triggers via bash. Used by `@ForLoopPlannerCLI`. |
| **file-management** | Complete file lifecycle in ForLoop sprints: presigned upload, folder organization, list, download, and delete. S3-backed with immediate upload pattern. |
| **user-management** | User profiles, storage quotas, organization creation/update/deletion, and member administration. |

### Quality (1 skill)

| Skill | Description |
|-------|-------------|
| **verification-before-completion** | No completion claims without fresh verification evidence. Applies to all planning operations — file uploads, story creation, S3 sync, sprint updates. |

### Sync (1 skill)

| Skill | Description |
|-------|-------------|
| **aivy-documents-sync** | Keep `~/.forloop/` documents synced with Sprint S3. Runs at session start and after file changes. |

## Requirements

### ForLoop Plugin

The plugin-based planner (`@forLoopPlanner`) and several skills require the [ForLoop opencode plugin](https://github.com/forloop-cc/forloop-opencode-plugin-planner):

- `forloop-skill`, `sprint-planning`, `story-creation`, `story-points`
- `task-tracking`, `template-based-tasks`, `plan-documentation`
- `file-management`, `user-management`, `agent-auto-assignment`
- `aivy-documents-sync`, `forloop-context`

### ForLoop CLI

The CLI-based planner (`@ForLoopPlannerCLI`) uses the `forloop-cli` skill and requires the `forloop` CLI binary:

```bash
npm install -g @forloop-cc/forloop-cli
forloop auth login --api-key floop_xxxxx
```

Get your API token at [forloop.cc/profile?tab=api-tokens](https://forloop.cc/profile?tab=api-tokens).

### Standalone (no plugin or CLI needed)

These skills work independently on any AI coding platform:

- `knowledge-management` — capture learnings to local files
- `verification-before-completion` — evidence-first completion check
- `tech-stack-default` — reference stack (adaptable to any platform)

### Storage

Skills that persist data expect a `~/.forloop/sprint-{id}/` directory structure:

```
~/.forloop/
└── sprint-{id}/
    ├── plan/      ← plan-documentation, sprint-planning
    ├── task/      ← task-tracking
    ├── knowledge/ ← knowledge-management
    └── files/     ← file-management, aivy-documents-sync
```

## How It Works

These agents and skills are **directory-based configurations** — they're not plugins or packages. AI platforms discover them by scanning specific directories:

| Platform | Agents discovered from | Skills discovered from |
|----------|------------------------|------------------------|
| opencode | `.opencode/agents/*.md` | `.opencode/skills/<name>/SKILL.md` |
| Claude Code | — | `.claude/skills/<name>/SKILL.md` |
| Codex | — | `.agents/skills/<name>/SKILL.md` |

The installer creates symlinks from those discovery paths to this repo. When an AI platform starts, it scans these directories and makes agents available for selection and skills available for on-demand loading.

Agents reference skills in their system prompts, and the platform's native skill tool lets agents load a skill's full content when a task matches its triggers.

## Uninstall

```bash
# Remove symlinks
rm -rf ~/.config/opencode/agents/forLoopPlanner.md \
       ~/.config/opencode/agents/forLoopStoryEvaluator.md \
       ~/.config/opencode/skills/forloop-skill \
       ~/.config/opencode/skills/sprint-planning \
       ~/.claude/skills/forloop-skill \
       ~/.agents/skills/forloop-skill
# (repeat for all symlinked skills)

# Delete the cloned repo
rm -rf ~/.config/forloop/agents-skills
```

## Updating

```bash
cd ~/.config/forloop/agents-skills && git pull origin main
```

Symlinks survive updates — they point into the repo directory. Just pull and restart your AI platform.

## Contributing

Skills are markdown with YAML frontmatter. Each `SKILL.md` needs:

```yaml
---
name: my-skill
description: Clear description of when to use this skill
version: 1.0.0
category: planning | administration | quality
---
```

Agents are markdown with opencode frontmatter:

```yaml
---
description: What the agent does
mode: primary | subagent
model: optional-model-override
temperature: 0.0-1.0
---
```

Add new skills by creating `skills/<name>/SKILL.md`. Add new agents by creating `agents/<name>.md`. See existing files for examples.

## License

MIT — see [LICENSE](LICENSE)
