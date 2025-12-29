#!/bin/bash
# dotfiles-min installer
# Safely injects HOMEARCHIVE extraction functionality into existing shell configs
# Does NOT replace or clobber existing shell configuration files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMEARCHIVE_FUNC_NAME="_homearchive_extract"
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

# Generate the homearchive extraction function
generate_homearchive_function() {
    cat << 'FUNC_EOF'
# Extract files from HOMEARCHIVE* environment variables
# This function is automatically sourced by your shell config
_homearchive_extract() {
    local MANIFEST_FILE="${HOME}/.homearchive-manifest"
    local ORIGINAL_DIR="$PWD"
    
    # Initialize manifest if it doesn't exist
    if [ ! -f "$MANIFEST_FILE" ]; then
        cat > "$MANIFEST_FILE" << 'EOF'
# HOMEARCHIVE Manifest
# Format: ARCHIVE_NAME:file1:file2:file3
# Lines starting with # are comments
# File paths are relative to $HOME
# Auto-populated by homearchive extraction
EOF
    fi
    
    # Get list of HOMEARCHIVE* variables
    local homearchive_vars
    if command -v compgen &>/dev/null; then
        # Bash
        homearchive_vars=$(compgen -e | grep "^HOMEARCHIVE" || true)
    else
        # Fallback (zsh, sh, etc.)
        homearchive_vars=$(env | grep "^HOMEARCHIVE" | cut -d= -f1 || true)
    fi
    
    # Process each HOMEARCHIVE* variable
    for var_name in $homearchive_vars; do
        # Get the value using indirect expansion
        local var_value
        if [ -n "${!var_name:-}" ]; then
            var_value="${!var_name}"
        else
            continue
        fi
        
        # Only process if variable has content
        if [ -n "$var_value" ]; then
            echo "Extracting $var_name to $HOME..."
            cd "$HOME" || continue
            
            # Extract to temporary location first to list files
            local temp_extract
            temp_extract=$(mktemp -d /tmp/homearchive.XXXXXX)
            
            if echo -n "$var_value" | base64 -d | tar -xzf - -C "$temp_extract" 2>/dev/null; then
                # Get list of extracted files (relative to temp dir)
                local extracted_files
                extracted_files=$(cd "$temp_extract" && find . -type f | sed 's|^\./||' | sort)
                
                # Move files to home directory
                cd "$temp_extract" && tar -cf - . | (cd "$HOME" && tar -xf -)
                echo "Successfully extracted $var_name"
                
                # Update manifest
                if [ -n "$extracted_files" ]; then
                    # Check if this archive is already in manifest
                    if grep -q "^${var_name}:" "$MANIFEST_FILE" 2>/dev/null; then
                        # Archive exists, verify files match
                        local manifest_files
                        manifest_files=$(grep "^${var_name}:" "$MANIFEST_FILE" | cut -d: -f2- | tr ':' '\n' | sort)
                        
                        # Compare file lists
                        if [ "$extracted_files" != "$manifest_files" ]; then
                            echo "Updating manifest for $var_name (file list changed)"
                            # Remove old entry
                            grep -v "^${var_name}:" "$MANIFEST_FILE" > "${MANIFEST_FILE}.tmp" 2>/dev/null || true
                            mv "${MANIFEST_FILE}.tmp" "$MANIFEST_FILE"
                            # Add new entry
                            echo "${var_name}:$(echo "$extracted_files" | tr '\n' ':' | sed 's/:$//')" >> "$MANIFEST_FILE"
                        fi
                    else
                        # New archive, add to manifest
                        echo "Adding $var_name to manifest"
                        echo "${var_name}:$(echo "$extracted_files" | tr '\n' ':' | sed 's/:$//')" >> "$MANIFEST_FILE"
                    fi
                fi
            else
                echo "Warning: Failed to extract $var_name" >&2
            fi
            
            # Cleanup temp directory
            rm -rf "$temp_extract"
        fi
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
        log_warn "$shell_name config not found at $shell_config - skipping"
        return 0
    fi
    
    # Check if already injected
    if grep -q "$INJECTION_MARKER" "$shell_config" 2>/dev/null; then
        log_info "$shell_name already has injection - skipping"
        return 0
    fi
    
    # Back up the original file
    cp "$shell_config" "${shell_config}.backup.$(date +%s)"
    log_info "Backed up $shell_name to ${shell_config}.backup.*"
    
    # Create injection block
    cat >> "$shell_config" << 'INJECT_EOF'

# === dotfiles-min homearchive injection ===
# Auto-generated by install.sh - do not edit this block manually
INJECT_EOF
    
    generate_homearchive_function >> "$shell_config"
    
    log_info "Injected HOMEARCHIVE extraction into $shell_name"
}

# Main installation routine
main() {
    log_info "dotfiles-min installer starting..."
    log_info "Script location: $SCRIPT_DIR"
    
    # Check if running in home directory context
    if [ "$HOME" = "/" ]; then
        log_error "Cannot install with HOME=/. Invalid environment."
        return 1
    fi
    
    log_info "Home directory: $HOME"
    
    # Copy ham utility to ~/.local/bin
    if [ -f "$SCRIPT_DIR/ham" ]; then
        mkdir -p "$HOME/.local/bin"
        cp "$SCRIPT_DIR/ham" "$HOME/.local/bin/ham"
        chmod +x "$HOME/.local/bin/ham"
        log_info "Copied ham utility to ~/.local/bin/ham"
    else
        log_warn "ham utility not found at $SCRIPT_DIR/ham - skipping"
    fi
    
    # Copy README.md to home directory
    if [ -f "$SCRIPT_DIR/README.md" ]; then
        if [ -f "$HOME/README.md" ]; then
            local readme_backup="$HOME/README.md.backup.$(date +%s)"
            log_warn "README.md already exists in home directory - will be overwritten"
            cp "$HOME/README.md" "$readme_backup"
            log_info "Backed up existing README.md to $readme_backup"
        fi
        cp "$SCRIPT_DIR/README.md" "$HOME/README.md"
        log_info "Copied README.md to $HOME/README.md"
    else
        log_warn "README.md not found at $SCRIPT_DIR/README.md - skipping"
    fi
    
    # Inject into bash
    inject_into_shell_config "$HOME/.bashrc" "Bash"
    
    # Inject into zsh
    inject_into_shell_config "$HOME/.zshrc" "Zsh"
    
    # Optional: run extraction immediately if HOMEARCHIVE* vars are present
    if env | grep -q "^HOMEARCHIVE"; then
        log_info "HOMEARCHIVE* variables detected - running extraction..."
        
        # Source the function from the appropriate shell config
        if [ -n "$ZSH_VERSION" ]; then
            # Running in zsh
            source "$HOME/.zshrc"
        else
            # Running in bash
            source "$HOME/.bashrc"
        fi
        
        # Call the extraction function if it exists
        if declare -f _homearchive_extract >/dev/null 2>&1; then
            _homearchive_extract
        fi
    else
        log_info "No HOMEARCHIVE* variables detected - extraction will run on next shell startup"
    fi
    
    log_info "Installation complete!"
    log_info ""
    log_info "What was installed:"
    log_info "  • Added _homearchive_extract() function to ~/.bashrc"
    log_info "  • Added _homearchive_extract() function to ~/.zshrc"
    log_info "  • Created ~/.homearchive-manifest (will be auto-populated)"
    log_info "  • Copied ham utility to ~/.local/bin/ham"
    log_info "  • Copied README.md to ~/README.md"
    log_info ""
    log_info "To use ham from anywhere, ensure ~/.local/bin is in your PATH:"
    log_info "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    log_info ""
    log_info "To remove:"
    log_info "  1. Restore from backup: cp ~/.bashrc.backup.* ~/.bashrc"
    log_info "  2. Or manually delete the 'dotfiles-min homearchive injection' block"
    log_info "  3. Remove installed files: rm -f ~/.local/bin/ham"
    log_info "  4. For README.md, restore from backup if it existed: cp ~/README.md.backup.* ~/README.md"
    log_info "     Or remove if you didn't have one: rm -f ~/README.md"
    log_info ""
    log_info "Your original shell configs were backed up:"
    ls -la "$HOME"/.bashrc.backup.* "$HOME"/.zshrc.backup.* 2>/dev/null || log_info "  (no backups found yet)"
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
