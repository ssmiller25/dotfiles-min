# dotfiles-min

A minimal dotfile configuration that automatically extracts archived home directory files from environment variables.

## Features

- Automatically extracts gzipped tarballs from any `HOMEARCHIVE*` environment variables
- Compatible with both **bash** and **zsh**
- Supports multiple archive variables (e.g., `HOMEARCHIVE`, `HOMEARCHIVEWK`, `HOMEARCHIVE_SSH`, etc.)
- Files are extracted directly into your `$HOME` directory

## Setup

### GitHub Codespaces / Devcontainers

This repository is automatically configured for GitHub Codespaces and devcontainer environments! The `.devcontainer/devcontainer.json` configuration will automatically source `.bashrc` or `.zshrc` on startup (depending on your shell), which in turn sources `.profile` to extract your HOMEARCHIVE* variables.

Just set your `HOMEARCHIVE*` variables as Codespace secrets or repository variables, and they'll be extracted automatically when your environment starts. Works with both bash and zsh.

### Manual Setup (Other Environments)

**For Bash** - Add to `~/.bashrc` or `~/.bash_profile`:
```bash
source /path/to/dotfiles-min/.bashrc
```

**For Zsh** - Add to `~/.zshrc`:
```zsh
source /path/to/dotfiles-min/.zshrc
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
4. **Auto-discovers** files in each archive and updates `.homearchive-manifest`
5. Reports success or failure for each archive

### Auto-Discovery Feature

The profile automatically maintains the manifest file:
- **First run**: Extracts files and creates manifest entries
- **Subsequent runs**: Updates manifest if archive contents change
- **No manual setup needed**: If you already have HOMEARCHIVE variables set, just source the profile

This means you can start using existing HOMEARCHIVE variables immediately, and the manifest will be populated automatically!

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

## Managing Archives with `ham` 🍖

The **ham** (Home Archive Manager) tool simplifies managing your HOMEARCHIVE variables. No more manual tar/base64 commands!

### Quick Start

```bash
# 1. Initialize the manifest
./ham init

# 2. Add files to an archive
./ham add ~/.ssh/config HOMEARCHIVE_SSH
./ham add ~/.ssh/id_rsa HOMEARCHIVE_SSH
./ham add ~/.aws/credentials HOMEARCHIVE_AWS

# 3. View what's configured
./ham list

# 4. Update a file and push to GitHub
vim ~/.ssh/config
./ham update ~/.ssh/config --repo your-org/your-repo
```

### Commands

- **`ham init`** - Create the manifest file
- **`ham add <file> [archive]`** - Add a file to an archive
- **`ham list [archive]`** - List all archives or files in a specific archive
- **`ham update <file>`** - Update the archive containing the file and push to GitHub
  - `--repo OWNER/REPO` - Update repository variable (default, auto-detects current repo)
  - `--env ENV_NAME` - Update environment variable
  - `--codespace` - Update codespace variable
  - `--dry-run` - Preview changes without uploading
- **`ham create <archive> [output]`** - Create archive file manually

### How It Works

1. The manifest file (`.homearchive-manifest`) tracks which files belong to which archive
2. The manifest is **automatically populated** when you source `.profile` with HOMEARCHIVE variables set
3. When you update a file, `ham` automatically:
   - Finds which archive contains it
   - Recreates the entire archive with current files
   - Encodes it to base64
   - Updates the GitHub variable using `gh` CLI

### Example Workflows

**If you already have HOMEARCHIVE variables set:**

```bash
# Just source the profile - manifest is auto-populated!
source /path/to/dotfiles-min/.profile

# View what was discovered
./ham list

# Update a file and push changes
vim ~/.ssh/config
./ham update ~/.ssh/config
```

**Starting from scratch:**

```bash
# Initial setup
./ham init
./ham add ~/.ssh/config HOMEARCHIVE_SSH
./ham add ~/.ssh/id_rsa HOMEARCHIVE_SSH
./ham add ~/.gitconfig HOMEARCHIVE

# Later, after editing your SSH config
vim ~/.ssh/config
./ham update ~/.ssh/config

# The entire HOMEARCHIVE_SSH archive is recreated and pushed to GitHub
```

### Installing `ham` in Your PATH

For easy access from anywhere:

```bash
# Option 1: Symlink to a directory in your PATH
ln -s /path/to/dotfiles-min/ham ~/.local/bin/ham

# Option 2: Add to your shell profile
echo 'export PATH="/path/to/dotfiles-min:$PATH"' >> ~/.bashrc
```

## Security Notes

- Never commit actual archive contents to version control
- Use CI/CD secret management for sensitive data
- Consider file permissions in your archives (they are preserved during extraction)
- The profile script runs extraction every time it's sourced
- The manifest file is safe to commit (it only contains file paths, not contents)