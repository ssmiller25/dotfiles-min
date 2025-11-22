# dotfiles-min

A minimal dotfile configuration that automatically extracts archived home directory files from environment variables.

## Features

- Automatically extracts gzipped tarballs from any `HOMEARCHIVE*` environment variables
- Compatible with both **bash** and **zsh**
- Supports multiple archive variables (e.g., `HOMEARCHIVE`, `HOMEARCHIVEWK`, `HOMEARCHIVE_SSH`, etc.)
- Files are extracted directly into your `$HOME` directory

## Setup

### 1. Source the profile in your shell

**For Bash** - Add to `~/.bashrc` or `~/.bash_profile`:
```bash
source /path/to/dotfiles-min/.profile
```

**For Zsh** - Add to `~/.zshrc`:
```zsh
source /path/to/dotfiles-min/.profile
```

### 2. Create and encode your archives

To create a gzipped archive of files you want in your home directory:

```bash
# Example: Archive SSH and AWS config files
find .ssh .aws -type f | grep -v -e pub -e known_hosts -e secrets -e private | tar -czf homeconfig.tar.gz -T -

# Encode to base64 (use -w 0 on Linux, -b 0 on macOS)
cat homeconfig.tar.gz | base64 -w 0 > homeconfig.txt  # Linux
# or
cat homeconfig.tar.gz | base64 -b 0 > homeconfig.txt  # macOS
```

### 3. Set environment variables

Copy the contents of `homeconfig.txt` and set it as an environment variable starting with `HOMEARCHIVE`:

```bash
export HOMEARCHIVE="<base64-encoded-content>"
export HOMEARCHIVEWK="<another-base64-encoded-content>"
export HOMEARCHIVE_SSH="<ssh-specific-content>"
```

You can set these in:
- CI/CD environment variables (GitHub Actions, GitLab CI, etc.)
- Container environment variables (Docker, Kubernetes)
- Cloud shell configurations
- Your shell profile (for non-sensitive data)

## How It Works

When you source `.profile`, it:
1. Scans for all environment variables starting with `HOMEARCHIVE`
2. Decodes each variable from base64
3. Extracts the gzipped tarball contents into `$HOME`
4. Reports success or failure for each archive

## Examples

### Multiple Archives

```bash
# Work-specific configuration
export HOMEARCHIVE="H4sIAAAAAAAA..."

# Personal SSH keys
export HOMEARCHIVE_SSH="H4sIAAAAAAAA..."

# AWS credentials
export HOMEARCHIVE_AWS="H4sIAAAAAAAA..."
```

### Creating Different Archives

```bash
# SSH keys only
tar -czf ssh.tar.gz -C ~ .ssh
cat ssh.tar.gz | base64 -w 0 > ssh.txt

# AWS configuration
tar -czf aws.tar.gz -C ~ .aws
cat aws.tar.gz | base64 -w 0 > aws.txt

# Git configuration
tar -czf git.tar.gz -C ~ .gitconfig .gitignore_global
cat git.tar.gz | base64 -w 0 > git.txt
```

## Security Notes

- Never commit actual archive contents to version control
- Use CI/CD secret management for sensitive data
- Consider file permissions in your archives (they are preserved during extraction)
- The profile script runs extraction every time it's sourced