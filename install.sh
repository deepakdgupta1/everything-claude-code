#!/usr/bin/env bash
# install.sh — Install claude rules while preserving directory structure.
#
# Usage:
#   ./install.sh [--target <claude|cursor|antigravity>] <language> [<language> ...]
#
# Examples:
#   ./install.sh typescript
#   ./install.sh typescript python golang
#   ./install.sh --target cursor typescript
#   ./install.sh --target cursor typescript python golang
#
# Targets:
#   claude      (default) — Install rules to ~/.claude/rules/
#   cursor      — Install rules, agents, skills, commands, and MCP to ./.cursor/
#   antigravity — Install rules, skills, workflows, and MCP for Antigravity IDE
#
# This script copies rules into the target directory keeping the common/ and
# language-specific subdirectories intact so that:
#   1. Files with the same name in common/ and <language>/ don't overwrite
#      each other.
#   2. Relative references (e.g. ../common/coding-style.md) remain valid.

set -euo pipefail

# Resolve symlinks — needed when invoked as `ecc-install` via npm/bun bin symlink
SCRIPT_PATH="$0"
while [ -L "$SCRIPT_PATH" ]; do
    link_dir="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    # Resolve relative symlinks
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$link_dir/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
RULES_DIR="$SCRIPT_DIR/rules"

# --- Parse --target flag ---
TARGET="claude"
if [[ "${1:-}" == "--target" ]]; then
    if [[ -z "${2:-}" ]]; then
        echo "Error: --target requires a value (claude, cursor, or antigravity)" >&2
        exit 1
    fi
    TARGET="$2"
    shift 2
fi

if [[ "$TARGET" != "claude" && "$TARGET" != "cursor" && "$TARGET" != "antigravity" ]]; then
    echo "Error: unknown target '$TARGET'. Must be 'claude', 'cursor', or 'antigravity'." >&2
    exit 1
fi

# --- Usage ---
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 [--target <claude|cursor|antigravity>] <language> [<language> ...]"
    echo ""
    echo "Targets:"
    echo "  claude      (default) — Install rules to ~/.claude/rules/"
    echo "  cursor      — Install rules, agents, skills, commands, and MCP to ./.cursor/"
    echo "  antigravity — Install rules, skills, workflows, and MCP for Antigravity IDE"
    echo ""
    echo "Available languages:"
    for dir in "$RULES_DIR"/*/; do
        name="$(basename "$dir")"
        [[ "$name" == "common" ]] && continue
        echo "  - $name"
    done
    exit 1
fi

# --- Claude target (existing behavior) ---
if [[ "$TARGET" == "claude" ]]; then
    DEST_DIR="${CLAUDE_RULES_DIR:-$HOME/.claude/rules}"

    # Warn if destination already exists (user may have local customizations)
    if [[ -d "$DEST_DIR" ]] && [[ "$(ls -A "$DEST_DIR" 2>/dev/null)" ]]; then
        echo "Note: $DEST_DIR/ already exists. Existing files will be overwritten."
        echo "      Back up any local customizations before proceeding."
    fi

    # Always install common rules
    echo "Installing common rules -> $DEST_DIR/common/"
    mkdir -p "$DEST_DIR/common"
    cp -r "$RULES_DIR/common/." "$DEST_DIR/common/"

    # Install each requested language
    for lang in "$@"; do
        # Validate language name to prevent path traversal
        if [[ ! "$lang" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo "Error: invalid language name '$lang'. Only alphanumeric, dash, and underscore allowed." >&2
            continue
        fi
        lang_dir="$RULES_DIR/$lang"
        if [[ ! -d "$lang_dir" ]]; then
            echo "Warning: rules/$lang/ does not exist, skipping." >&2
            continue
        fi
        echo "Installing $lang rules -> $DEST_DIR/$lang/"
        mkdir -p "$DEST_DIR/$lang"
        cp -r "$lang_dir/." "$DEST_DIR/$lang/"
    done

    echo "Done. Rules installed to $DEST_DIR/"
fi

# --- Cursor target ---
if [[ "$TARGET" == "cursor" ]]; then
    DEST_DIR=".cursor"
    CURSOR_SRC="$SCRIPT_DIR/.cursor"

    echo "Installing Cursor configs to $DEST_DIR/"

    # --- Rules ---
    echo "Installing common rules -> $DEST_DIR/rules/"
    mkdir -p "$DEST_DIR/rules"
    # Copy common rules (flattened names like common-coding-style.md)
    if [[ -d "$CURSOR_SRC/rules" ]]; then
        for f in "$CURSOR_SRC/rules"/common-*.md; do
            [[ -f "$f" ]] && cp "$f" "$DEST_DIR/rules/"
        done
    fi

    # Install language-specific rules
    for lang in "$@"; do
        # Validate language name to prevent path traversal
        if [[ ! "$lang" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo "Error: invalid language name '$lang'. Only alphanumeric, dash, and underscore allowed." >&2
            continue
        fi
        if [[ -d "$CURSOR_SRC/rules" ]]; then
            found=false
            for f in "$CURSOR_SRC/rules"/${lang}-*.md; do
                if [[ -f "$f" ]]; then
                    cp "$f" "$DEST_DIR/rules/"
                    found=true
                fi
            done
            if $found; then
                echo "Installing $lang rules -> $DEST_DIR/rules/"
            else
                echo "Warning: no Cursor rules for '$lang' found, skipping." >&2
            fi
        fi
    done

    # --- Agents ---
    if [[ -d "$CURSOR_SRC/agents" ]]; then
        echo "Installing agents -> $DEST_DIR/agents/"
        mkdir -p "$DEST_DIR/agents"
        cp -r "$CURSOR_SRC/agents/." "$DEST_DIR/agents/"
    fi

    # --- Skills ---
    if [[ -d "$CURSOR_SRC/skills" ]]; then
        echo "Installing skills -> $DEST_DIR/skills/"
        mkdir -p "$DEST_DIR/skills"
        cp -r "$CURSOR_SRC/skills/." "$DEST_DIR/skills/"
    fi

    # --- Commands ---
    if [[ -d "$CURSOR_SRC/commands" ]]; then
        echo "Installing commands -> $DEST_DIR/commands/"
        mkdir -p "$DEST_DIR/commands"
        cp -r "$CURSOR_SRC/commands/." "$DEST_DIR/commands/"
    fi

    # --- MCP Config ---
    if [[ -f "$CURSOR_SRC/mcp.json" ]]; then
        echo "Installing MCP config -> $DEST_DIR/mcp.json"
        cp "$CURSOR_SRC/mcp.json" "$DEST_DIR/mcp.json"
    fi

    echo "Done. Cursor configs installed to $DEST_DIR/"
fi

# --- Antigravity target ---
if [[ "$TARGET" == "antigravity" ]]; then
    DEST_DIR=".agent"

    echo "Installing Antigravity configs to $DEST_DIR/"

    # --- Skills (identical format) ---
    if [[ -d "$SCRIPT_DIR/skills" ]]; then
        echo "Installing skills -> $DEST_DIR/skills/"
        mkdir -p "$DEST_DIR/skills"
        cp -r "$SCRIPT_DIR/skills/." "$DEST_DIR/skills/"
    fi

    # --- Rules (common → consolidated, language-specific → individual files) ---
    echo "Installing common rules -> $DEST_DIR/rules/"
    mkdir -p "$DEST_DIR/rules"
    for f in "$RULES_DIR/common/"*.md; do
        [ -f "$f" ] && cp "$f" "$DEST_DIR/rules/common-$(basename "$f")"
    done

    for lang in "$@"; do
        if [[ ! "$lang" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo "Error: invalid language name '$lang'." >&2
            continue
        fi
        lang_dir="$RULES_DIR/$lang"
        if [[ ! -d "$lang_dir" ]]; then
            echo "Warning: rules/$lang/ does not exist, skipping." >&2
            continue
        fi
        echo "Installing $lang rules -> $DEST_DIR/rules/"
        for f in "$lang_dir/"*.md; do
            [ -f "$f" ] && cp "$f" "$DEST_DIR/rules/${lang}-$(basename "$f")"
        done
    done

    # --- Commands → Workflows ---
    if [[ -d "$SCRIPT_DIR/commands" ]]; then
        echo "Installing commands as workflows -> $DEST_DIR/workflows/"
        mkdir -p "$DEST_DIR/workflows"
        cp -r "$SCRIPT_DIR/commands/." "$DEST_DIR/workflows/"
    fi

    # --- Contexts → Rules (always-on) ---
    if [[ -d "$SCRIPT_DIR/contexts" ]]; then
        echo "Installing contexts as rules -> $DEST_DIR/rules/"
        for f in "$SCRIPT_DIR/contexts/"*.md; do
            [ -f "$f" ] && cp "$f" "$DEST_DIR/rules/context-$(basename "$f")"
        done
    fi

    # --- Agents → Skills (decomposed for IDE use) ---
    if [[ -d "$SCRIPT_DIR/agents" ]]; then
        echo "Installing agents as skills -> $DEST_DIR/skills/"
        for f in "$SCRIPT_DIR/agents/"*.md; do
            agent_name="$(basename "$f" .md)"
            mkdir -p "$DEST_DIR/skills/$agent_name"
            cp "$f" "$DEST_DIR/skills/$agent_name/SKILL.md"
        done
    fi

    # --- Agents → agy CLI plans (for programmatic use) ---
    if [[ -d "$SCRIPT_DIR/agents" ]]; then
        echo "Generating agy plans -> $DEST_DIR/plans/"
        mkdir -p "$DEST_DIR/plans"
        for f in "$SCRIPT_DIR/agents/"*.md; do
            agent_name="$(basename "$f" .md)"
            plan_file="$DEST_DIR/plans/${agent_name}.yaml"
            
            # Extract fields using awk
            agent_desc="$(awk -F': ' '/^description:/ {print $2; exit}' "$f")"
            agent_model="$(awk -F': ' '/^model:/ {print $2; exit}' "$f")"
            agent_tools="$(awk -F'tools:[ ]*' '/^tools:/ {print $2; exit}' "$f")"
            
            # Map model
            if [[ "$agent_model" == "opus" ]]; then
                mapped_model="claude-opus-4-5"
            elif [[ "$agent_model" == "sonnet" ]]; then
                mapped_model="claude-sonnet-4-5"
            else
                mapped_model="gemini-3-pro"
            fi
            
            cat > "$plan_file" <<EOF
roles:
  ${agent_name}:
    description: "${agent_desc:-${agent_name} agent}"
    model: "${mapped_model}"
EOF
            
            # Parse and write tools array
            if [[ -n "$agent_tools" && "$agent_tools" != "[]" ]]; then
                echo "    tools:" >> "$plan_file"
                clean_tools="$(echo "$agent_tools" | sed 's/\[//g; s/\]//g; s/"//g; s/ //g')"
                IFS=',' read -ra TOOL_ARR <<< "$clean_tools"
                for t in "${TOOL_ARR[@]}"; do
                    t_lower="$(echo "$t" | tr '[:upper:]' '[:lower:]')"
                    echo "      - $t_lower" >> "$plan_file"
                done
            fi
            
            # Write prompt (everything after the second '---')
            echo "    prompt: |" >> "$plan_file"
            awk '/^---$/{count++; next} count>=2{print "      " $0}' "$f" >> "$plan_file"
        done
    fi

    # --- MCP Config ---
    if [[ -f "$SCRIPT_DIR/mcp-configs/mcp-servers.json" ]]; then
        echo "Installing MCP config -> ~/.gemini/antigravity/mcp_config.json"
        mkdir -p ~/.gemini/antigravity
        cp "$SCRIPT_DIR/mcp-configs/mcp-servers.json" ~/.gemini/antigravity/mcp_config.json
    fi

    echo "Done. Antigravity configs installed to $DEST_DIR/"
fi

