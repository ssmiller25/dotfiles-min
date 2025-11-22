# Process all HOMEARCHIVE* environment variables
# Each variable should contain a base64 encoded gzipped tarball
# Files will be extracted into $HOME directory

PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
MANIFEST_FILE="${PROFILE_DIR}/.homearchive-manifest"

# Initialize manifest if it doesn't exist
if [ ! -f "$MANIFEST_FILE" ]; then
    cat > "$MANIFEST_FILE" << 'EOF'
# HOMEARCHIVE Manifest
# Format: ARCHIVE_NAME:file1:file2:file3
# Lines starting with # are comments
# File paths are relative to $HOME
# Auto-populated by .profile on first run
EOF
fi

# Get list of HOMEARCHIVE* variables (bash and zsh compatible)
if [ -n "$BASH_VERSION" ]; then
    # Bash implementation
    homearchive_vars=$(compgen -e | grep "^HOMEARCHIVE")
elif [ -n "$ZSH_VERSION" ]; then
    # Zsh implementation
    homearchive_vars=$(print -l ${(k)parameters} | grep "^HOMEARCHIVE")
else
    # Fallback for other POSIX shells
    homearchive_vars=$(env | grep "^HOMEARCHIVE" | cut -d= -f1)
fi

# Process each HOMEARCHIVE* variable
for var_name in $homearchive_vars; do
    # Get the value using indirect expansion (works in both bash and zsh)
    if [ -n "$BASH_VERSION" ]; then
        var_value="${!var_name}"
    elif [ -n "$ZSH_VERSION" ]; then
        var_value="${(P)var_name}"
    else
        var_value=$(eval echo \$${var_name})
    fi
    
    # Only process if variable has content
    if [ -n "$var_value" ]; then
        echo "Extracting $var_name to $HOME..."
        cd "$HOME" || continue
        
        # Extract to temporary location first to list files
        temp_extract=$(mktemp -d /tmp/homearchive.XXXXXX)
        echo -n "$var_value" | base64 -d | tar -xzf - -C "$temp_extract" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            # Get list of extracted files (relative to temp dir)
            extracted_files=$(cd "$temp_extract" && find . -type f | sed 's|^\./||' | sort)
            
            # Move files to home directory
            cd "$temp_extract" && tar -cf - . | (cd "$HOME" && tar -xf -)
            echo "Successfully extracted $var_name"
            
            # Update manifest (it should exist from initialization above)
            if [ -n "$extracted_files" ]; then
                # Check if this archive is already in manifest
                if grep -q "^${var_name}:" "$MANIFEST_FILE" 2>/dev/null; then
                    # Archive exists, verify files match
                    manifest_files=$(grep "^${var_name}:" "$MANIFEST_FILE" | cut -d: -f2- | tr ':' '\n' | sort)
                    
                    # Compare file lists
                    if [ "$extracted_files" != "$manifest_files" ]; then
                        echo "Updating manifest for $var_name (file list changed)"
                        # Remove old entry (portable way without -i)
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
