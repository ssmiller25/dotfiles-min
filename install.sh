#!/bin/bash
# dotfiles-min installer
# Safely injects HOMEARCHIVE extraction functionality into existing shell configs
# Does NOT replace or clobber existing shell configuration files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INJECTION_MARKER="# === dotfiles-min homearchive injection ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Ensure HOME/bin is in PATH (tight pattern match, not just substring)
ensure_bin_in_path() {
    local shell_config="$1"
    local shell_name="$2"

    if [ ! -f "$shell_config" ]; then
        return 0
    fi

    # Match an actual export line, not comments or unrelated strings
    if grep -qE '^[[:space:]]*export[[:space:]]+PATH=.*\$HOME/bin' "$shell_config" 2>/dev/null; then
        return 0
    fi

    cat >> "$shell_config" << 'PATHEOF'

# Ensure $HOME/bin is in PATH
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    export PATH="$HOME/bin:$PATH"
fi
PATHEOF

    log_info "Ensured $HOME/bin is in PATH for $shell_name"
}

# ---------------------------------------------------------------------------
# generate_homearchive_function
#
# Produces the shell function that will be injected into ~/.bashrc / ~/.zshrc.
# Key improvements:
#   • Uses eval for cross-shell indirect expansion (bash & zsh)
#   • printf '%s' instead of echo -n (robust with base64 binary data)
#   • mkdir-based manifest locking to prevent concurrent-corruption
#   • Safer temp-directory handling
# ---------------------------------------------------------------------------
generate_homearchive_function() {
    cat << 'FUNC_EOF'
# Extract files from HOMEARCHIVE* environment variables
# This function is automatically sourced by your shell config
_homearchive_extract() {
    local MANIFEST_FILE="${HOME}/.homearchive-manifest"
    local ORIGINAL_DIR="$PWD"

    # ---- Manifest locking (mkdir is atomic, works on macOS & Linux) ----
    _manifest_lock() {
        local lock_dir="${MANIFEST_FILE}.lock"
        local i=0
        while ! mkdir "$lock_dir" 2>/dev/null; do
            sleep 0.1
            i=$((i + 1))
            if [ "$i" -ge 50 ]; then
                echo "Warning: Could not acquire manifest lock after 5s" >&2
                return 1
            fi
        done
        return 0
    }

    _manifest_unlock() {
        rmdir "${MANIFEST_FILE}.lock" 2>/dev/null || true
    }
    # -----------------------------------------------------------------

    # Initialise manifest if it doesn't exist
    _manifest_lock || return 1
    if [ ! -f "$MANIFEST_FILE" ]; then
        cat > "$MANIFEST_FILE" << 'EOF'
# HOMEARCHIVE Manifest
# Format: ARCHIVE_NAME:file1:file2:file3
# Lines starting with # are comments
# File paths are relative to $HOME
# Auto-populated by homearchive extraction
EOF
    fi
    _manifest_unlock

    # Discover HOMEARCHIVE* variables (bash compgen first, env fallback)
    local homearchive_vars
    if command -v compgen >/dev/null 2>&1; then
        homearchive_vars=$(compgen -e | grep "^HOMEARCHIVE" || true)
    else
        homearchive_vars=$(env | grep "^HOMEARCHIVE" | cut -d= -f1 || true)
    fi

    # Process each HOMEARCHIVE* variable
    for var_name in $homearchive_vars; do
        # Cross-shell indirect expansion (bash, zsh, and POSIX fallback)
        local var_value
        if [ -n "${ZSH_VERSION:-}" ]; then
            var_value="${(P)var_name}"
        elif [ -n "${BASH_VERSION:-}" ]; then
            var_value="${!var_name:-}"
        else
            eval "var_value=\${$var_name:-}"
        fi

        # Skip empty variables
        if [ -z "${var_value:-}" ]; then
            continue
        fi

        echo "Extracting $var_name to $HOME..."
        cd "$HOME" || continue

        # Extract into a temporary directory first so we can list files
        local temp_extract
        temp_extract=$(mktemp -d /tmp/homearchive.XXXXXX)

        # Use printf instead of echo for binary-safe output
        if printf '%s' "$var_value" | base64 -d 2>/dev/null | tar -xzf - -C "$temp_extract" 2>/dev/null; then
            # List extracted files (relative paths)
            local extracted_files
            extracted_files=$(cd "$temp_extract" && find . -type f | sed 's|^\./||' | sort)

            # Move files to $HOME
            (cd "$temp_extract" && tar -cf - .) | (cd "$HOME" && tar -xf -)
            echo "Successfully extracted $var_name"

            # Update manifest (locked)
            if [ -n "$extracted_files" ]; then
                _manifest_lock || continue

                local file_list
                file_list=$(printf '%s' "$extracted_files" | tr '\n' ':' | sed 's/:$//')

                if grep -q "^${var_name}:" "$MANIFEST_FILE" 2>/dev/null; then
                    # Archive already known – update if the file list changed
                    local manifest_files
                    manifest_files=$(grep "^${var_name}:" "$MANIFEST_FILE" | cut -d: -f2- | tr ':' '\n' | sort)

                    if [ "$extracted_files" != "$manifest_files" ]; then
                        echo "Updating manifest for $var_name (file list changed)"
                        grep -v "^${var_name}:" "$MANIFEST_FILE" > "${MANIFEST_FILE}.tmp" 2>/dev/null || true
                        printf '%s:%s\n' "$var_name" "$file_list" >> "${MANIFEST_FILE}.tmp"
                        mv "${MANIFEST_FILE}.tmp" "$MANIFEST_FILE"
                    fi
                else
                    # Brand-new archive
                    echo "Adding $var_name to manifest"
                    printf '%s:%s\n' "$var_name" "$file_list" >> "$MANIFEST_FILE"
                fi

                _manifest_unlock
            fi
        else
            echo "Warning: Failed to extract $var_name" >&2
        fi

        # Clean up temp directory
        rm -rf "$temp_extract"
    done

    cd "$ORIGINAL_DIR" || true
}

# Only run extraction once per session
if [ -z "${HOMEARCHIVE_EXTRACTED:-}" ]; then
    _homearchive_extract
    HOMEARCHIVE_EXTRACTED=1
fi
FUNC_EOF
}

# Inject function into a shell config file
inject_into_shell_config() {
    local shell_config="$1"
    local shell_name="$2"

    if [ ! -f "$shell_config" ]; then
        log_warn "$shell_name config not found at $shell_config – skipping"
        return 0
    fi

    # Skip if already injected
    if grep -qF "$INJECTION_MARKER" "$shell_config" 2>/dev/null; then
        log_info "$shell_name already has injection – skipping"
        return 0
    fi

    # Human-readable backup timestamp
    local backup_file="${shell_config}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$shell_config" "$backup_file"
    log_info "Backed up $shell_name to $backup_file"

    # Write injection block
    cat >> "$shell_config" << 'INJECT_EOF'

# === dotfiles-min homearchive injection ===
# Auto-generated by install.sh – do not edit this block manually
INJECT_EOF

    generate_homearchive_function >> "$shell_config"

    log_info "Injected HOMEARCHIVE extraction into $shell_name"
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
main() {
    log_info "dotfiles-min installer starting…"
    log_info "Script location: $SCRIPT_DIR"

    if [ "$HOME" = "/" ]; then
        log_error "Cannot install with HOME=/. Invalid environment."
        return 1
    fi

    log_info "Home directory: $HOME"

    local ham_installed=false

    # ---- Copy ham utility to ~/bin ----
    if [ -f "$SCRIPT_DIR/ham" ]; then
        mkdir -p "$HOME/bin"
        if cp "$SCRIPT_DIR/ham" "$HOME/bin/ham" && chmod +x "$HOME/bin/ham"; then
            log_info "Copied ham utility to ~/bin/ham"
            ham_installed=true
        else
            log_error "Failed to copy ham utility to ~/bin/ham"
        fi
    else
        log_warn "ham utility not found at $SCRIPT_DIR/ham – skipping"
    fi

    # ---- Inject into shell configs ----
    inject_into_shell_config "$HOME/.bashrc" "Bash"
    inject_into_shell_config "$HOME/.zshrc"  "Zsh"

    # ---- Ensure ~/bin is in PATH ----
    ensure_bin_in_path "$HOME/.bashrc" "Bash"
    ensure_bin_in_path "$HOME/.zshrc"  "Zsh"

    # ---- Write installation info (instead of overwriting README) ----
    local info_file="$HOME/.dotfiles-min-installed.txt"
    cat > "$info_file" << INFOEOF
dotfiles-min was installed on $(date '+%Y-%m-%d %H:%M:%S')
Installation source : $SCRIPT_DIR
Shell configs        : ~/.bashrc, ~/.zshrc
Utility              : ~/bin/ham
Manifest             : ~/.homearchive-manifest

Run 'ham --help' to learn how to manage your archives.
INFOEOF
    log_info "Created installation info: $info_file"

    # ---- Optional: run extraction immediately if HOMEARCHIVE* vars are set ----
    if env | grep -q "^HOMEARCHIVE"; then
        log_info "HOMEARCHIVE* variables detected – running extraction…"

        # Choose the right config file based on the running shell
        if [ -n "${BASH_VERSION:-}" ]; then
            # shellcheck disable=SC1090
            source "$HOME/.bashrc"
        elif [ -n "${ZSH_VERSION:-}" ]; then
            # shellcheck disable=SC1090
            source "$HOME/.zshrc"
        fi

        if declare -f _homearchive_extract >/dev/null 2>&1; then
            _homearchive_extract
        fi
    else
        log_info "No HOMEARCHIVE* variables detected – extraction will run on next shell startup"
    fi

    # ---- Summary ----
    log_info "Installation complete!"
    log_info ""
    log_info "What was installed:"
    log_info "  • Added _homearchive_extract() function to ~/.bashrc"
    log_info "  • Added _homearchive_extract() function to ~/.zshrc"
    log_info "  • Created ~/.homearchive-manifest (auto-populated on first extraction)"
    log_info "  • Added \$HOME/bin to PATH in ~/.bashrc and ~/.zshrc"
    if [ "$ham_installed" = true ]; then
        log_info "  • Copied ham utility to ~/bin/ham"
    fi
    log_info "  • Installation info written to $info_file"
    log_info ""
    if [ "$ham_installed" = true ]; then
        log_info "ham is available after restarting your shell (or run: export PATH=\"\$HOME/bin:\$PATH\")"
    fi
    log_info ""
    log_info "To remove:"
    log_info "  • Restore shell configs from their .backup.* copies"
    log_info "  • Or manually delete the 'dotfiles-min homearchive injection' block"
    if [ "$ham_installed" = true ]; then
        log_info "  • rm -f ~/bin/ham"
    fi
    log_info "  • rm -f $info_file"
    log_info ""
    log_info "Backups:"
    ls -la "$HOME"/.bashrc.backup.* "$HOME"/.zshrc.backup.* 2>/dev/null || log_info "  (no backups created yet)"
}

# Run main if executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
