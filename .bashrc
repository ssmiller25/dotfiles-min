# Source .profile to extract HOMEARCHIVE* variables
PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$PROFILE_DIR/.profile" ]; then
    source "$PROFILE_DIR/.profile"
fi
