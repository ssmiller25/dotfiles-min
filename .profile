# Process all HOMEARCHIVE* environment variables
# Each variable should contain a base64 encoded gzipped tarball
# Files will be extracted into $HOME directory

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
        echo -n "$var_value" | base64 -d | tar -xzf - 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "Successfully extracted $var_name"
        else
            echo "Warning: Failed to extract $var_name" >&2
        fi
    fi
done
