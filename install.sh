#!/usr/bin/env bash
set -euo pipefail

# ForLoop Agents & Skills Installer
# https://github.com/forloop-cc/forloop-agents-skills
#
# Clones the repo and symlinks agents/skills into platform discovery paths.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/forloop-cc/forloop-agents-skills/main/install.sh | bash
#   bash install.sh --claude --codex
#   bash install.sh --all

# ── Platform & colors ────────────────────────────────────────────────────────
PLATFORM="$(uname -s)"
case "$PLATFORM" in
    Darwin*)    PLATFORM_LABEL="macOS";;
    Linux*)     PLATFORM_LABEL="Linux";;
    CYGWIN*|MINGW*|MSYS*) PLATFORM_LABEL="Windows";;
    *)          PLATFORM_LABEL="Unknown";;
esac

if [ "$PLATFORM_LABEL" = "Windows" ] && [ -z "$WT_SESSION" ] && [ -z "$ConEmuPID" ]; then
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
else
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
fi

# ── Configuration ────────────────────────────────────────────────────────────
REPO="https://github.com/forloop-cc/forloop-agents-skills.git"
BRANCH="${FORLOOP_BRANCH:-main}"
INSTALL_DIR="$HOME/.config/forloop/agents-skills"

USE_OPENCODE=false
USE_CLAUDE=false
USE_CODEX=false
NON_INTERACTIVE=false
FORCE=false

print_header() { echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════╗\n║    ForLoop Agents & Skills Installer     ║\n╚══════════════════════════════════════════╝${NC}\n"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_info()    { echo -e "${BLUE}ℹ${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error()   { echo -e "${RED}✗${NC} $1" >&2; }
print_step()    { echo -e "\n${CYAN}${BOLD}▶${NC} $1\n"; }

show_help() {
    cat << 'HELPEOF'
Usage: install.sh [OPTIONS]

Clones the repo and symlinks agents/skills into platform discovery paths.

Options:
  --opencode   Symlink for opencode (~/.config/opencode/)
  --claude     Symlink for Claude Code (~/.claude/skills/)
  --codex      Symlink for Codex (~/.agents/skills/)
  --all        Symlink for all platforms
  -f, --force  Overwrite existing installation
  -h, --help   Show this help

Examples:
  curl -fsSL .../install.sh | bash               # Interactive (defaults to opencode)
  bash install.sh --opencode --force             # opencode only, overwrite
  bash install.sh --all                          # All platforms
HELPEOF
}

# ── Dependency checks ────────────────────────────────────────────────────────

check_git() {
    if ! command -v git &>/dev/null; then
        print_error "git is required but not installed"
        case "$PLATFORM_LABEL" in
            macOS)   echo "  brew install git" ;;
            Linux)   echo "  sudo apt-get install git" ;;
            Windows) echo "  https://git-scm.com/download/win" ;;
        esac
        return 1
    fi
    return 0
}

# ── Clone ────────────────────────────────────────────────────────────────────

clone_repo() {
    print_step "Cloning repository..."

    if [ -d "$INSTALL_DIR" ] && [ "$FORCE" = true ]; then
        print_warning "Removing existing installation..."
        rm -rf "$INSTALL_DIR"
    elif [ -d "$INSTALL_DIR" ]; then
        print_info "Already installed at $INSTALL_DIR"
        print_info "Updating..."
        cd "$INSTALL_DIR"
        git fetch origin "$BRANCH" 2>&1
        git checkout "$BRANCH" 2>/dev/null || true
        git pull origin "$BRANCH" 2>&1
        cd - > /dev/null
        return 0
    fi

    mkdir -p "$(dirname "$INSTALL_DIR")"
    if ! git clone --depth 1 --branch "$BRANCH" "$REPO" "$INSTALL_DIR" 2>&1; then
        print_error "Failed to clone repository"
        exit 1
    fi
    print_success "Repository cloned to: $INSTALL_DIR"
}

# ── Symlinks ─────────────────────────────────────────────────────────────────

link_opencode() {
    print_step "Linking for opencode..."

    local agents_dir="$HOME/.config/opencode/agents"
    local skills_dir="$HOME/.config/opencode/skills"

    mkdir -p "$agents_dir" "$skills_dir"

    for agent in "$INSTALL_DIR/agents/"*.md; do
        [ -f "$agent" ] || continue
        local name
        name="$(basename "$agent")"
        ln -sf "$agent" "$agents_dir/$name"
        print_success "Agent linked: $name"
    done

    for skill_dir in "$INSTALL_DIR/skills/"*/; do
        [ -d "$skill_dir" ] || continue
        local name
        name="$(basename "$skill_dir")"
        ln -sfn "$skill_dir" "$skills_dir/$name"
        print_success "Skill linked: $name"
    done
}

link_claude() {
    print_step "Linking for Claude Code..."
    local skills_dir="$HOME/.claude/skills"
    mkdir -p "$skills_dir"

    for skill_dir in "$INSTALL_DIR/skills/"*/; do
        [ -d "$skill_dir" ] || continue
        local name
        name="$(basename "$skill_dir")"
        ln -sfn "$skill_dir" "$skills_dir/$name"
        print_success "Skill linked: $name"
    done
}

link_codex() {
    print_step "Linking for Codex..."
    local skills_dir="$HOME/.agents/skills"
    mkdir -p "$skills_dir"

    for skill_dir in "$INSTALL_DIR/skills/"*/; do
        [ -d "$skill_dir" ] || continue
        local name
        name="$(basename "$skill_dir")"
        ln -sfn "$skill_dir" "$skills_dir/$name"
        print_success "Skill linked: $name"
    done
}

# ── Summary ──────────────────────────────────────────────────────────────────

show_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}========================================${NC}"
    echo -e "${GREEN}${BOLD}  Installation Complete!${NC}"
    echo -e "${GREEN}${BOLD}========================================${NC}"
    echo ""
    echo "  Location: $INSTALL_DIR"
    [ "$USE_OPENCODE" = true ] && echo "  opencode: agents + skills linked"
    [ "$USE_CLAUDE" = true ] && echo "  Claude:   skills linked"
    [ "$USE_CODEX" = true ] && echo "  Codex:    skills linked"
    echo ""
    echo "  Docs: https://github.com/forloop-cc/forloop-agents-skills"
    echo ""
}

# ── Main ─────────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --opencode) USE_OPENCODE=true; shift ;;
        --claude)   USE_CLAUDE=true; shift ;;
        --codex)    USE_CODEX=true; shift ;;
        --all)      USE_OPENCODE=true; USE_CLAUDE=true; USE_CODEX=true; shift ;;
        -f|--force) FORCE=true; shift ;;
        -h|--help)  show_help; exit 0 ;;
        *)          print_error "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

# Detect non-interactive mode
if [ ! -t 0 ]; then
    NON_INTERACTIVE=true
    if [ "$USE_OPENCODE" = false ] && [ "$USE_CLAUDE" = false ] && [ "$USE_CODEX" = false ]; then
        print_info "Non-interactive mode, defaulting to opencode"
        USE_OPENCODE=true
    fi
fi

print_header

# Interactive: prompt if no platform selected
if [ "$USE_OPENCODE" = false ] && [ "$USE_CLAUDE" = false ] && [ "$USE_CODEX" = false ]; then
    echo -e "${BOLD}Which platform(s) should agents/skills be linked to?${NC}"
    echo "  1) opencode (recommended)"
    echo "  2) Claude Code"
    echo "  3) All platforms"
    echo "  4) Cancel"
    read -p "Select [1-4]: " -r; echo
    case "$REPLY" in
        1) USE_OPENCODE=true ;;
        2) USE_CLAUDE=true ;;
        3) USE_OPENCODE=true; USE_CLAUDE=true; USE_CODEX=true ;;
        *) print_info "Installation cancelled"; exit 0 ;;
    esac
fi

check_git || exit 1
clone_repo

[ "$USE_OPENCODE" = true ] && link_opencode
[ "$USE_CLAUDE" = true ] && link_claude
[ "$USE_CODEX" = true ] && link_codex

show_summary
