# dotfiles-min

A minimal dotfile configuration with two secret management approaches:

1. **🆕 Cloud-based secrets** (Recommended) - Store secrets in S3, GitHub releases, Azure, or GCS with profile support
2. **Legacy HOMEARCHIVE** - Store base64-encoded archives in environment variables

## 🆕 New: Cloud-Based Secrets Management

The new `secrets-sync` tool provides a better way to manage secrets:

✅ **Store secrets in cloud storage** (S3, GitHub releases, Azure, GCS)  
✅ **Use environment variables only for authentication** (not file content)  
✅ **Multiple profiles** (work, personal, project-specific)  
✅ **Easy updates** (change individual files without rebuilding archives)  
✅ **Version control** (cloud storage versioning)  
✅ **Works in Codespaces & Devcontainers**

### Quick Start with Cloud Secrets

```bash
# 1. Install
git clone https://github.com/ssmiller25/dotfiles-min.git
cd dotfiles-min
bash install.sh

# 2. Initialize and configure
secrets-sync init
vim ~/.secrets-profiles.yaml

# 3. Add files and push to cloud
secrets-sync add ~/.ssh/config work
secrets-sync push --profile work

# 4. Set environment variables (authentication only!)
export SECRET_STORE=s3
export SECRET_PROFILE=work
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
```

**📖 See [SECRETS_SETUP_GUIDE.md](SECRETS_SETUP_GUIDE.md) for detailed setup instructions**  
**📋 See [SECRETS_MANAGEMENT_PROPOSAL.md](SECRETS_MANAGEMENT_PROPOSAL.md) for architecture and design**

---

## Legacy: HOMEARCHIVE System

The original system stores base64-encoded tarballs in environment variables. Still supported but not recommended for new setups.

## Features

- **Cloud-based secrets**: Store secrets in S3, GitHub releases, Azure Blob, or Google Cloud Storage
- **Profile system**: Switch between different secret sets (work, personal, project-specific)
- **Legacy support**: Automatically extracts gzipped tarballs from any `HOMEARCHIVE*` environment variables
- Compatible with both **bash** and **zsh**
- Supports multiple archive variables (e.g., `HOMEARCHIVE`, `HOMEARCHIVEWK`, `HOMEARCHIVE_SSH`, etc.)
- Files are extracted directly into your `$HOME` directory

## Setup

### Quick Install (Recommended)

Run the installer script to install both cloud-based secrets management and legacy HOMEARCHIVE support:

```bash
bash /path/to/dotfiles-min/install.sh
```

**What it does:**
- ✅ Installs `secrets-sync` utility to `~/bin/secrets-sync` (for cloud-based secrets)
- ✅ Installs `ham` utility to `~/bin/ham` (Home Archive Manager)
- ✅ Injects secrets-sync integration into `~/.bashrc` and `~/.zshrc`
- ✅ Injects `_homearchive_extract()` function into `~/.bashrc` and `~/.zshrc`
- ✅ Preserves all existing shell configuration (no clobbering)
- ✅ Creates backups of your original shell configs
- ✅ Automatically syncs secrets on shell startup (if configured)
- ✅ Creates and manages `~/.homearchive-manifest` to track extracted files

**Priority order:**
1. If `SECRET_STORE` and `SECRET_PROFILE` are set → uses cloud-based secrets
2. If `HOMEARCHIVE*` variables exist → uses legacy HOMEARCHIVE system
3. Otherwise → waits for configuration

**To uninstall:**
Just restore from backup or manually remove the `dotfiles-min` injection blocks from your shell configs.

### GitHub Codespaces / Devcontainers

This repository is automatically configured for GitHub Codespaces and devcontainer environments!

#### Using Cloud-Based Secrets (Recommended)

**For Codespaces:**
1. Go to repository Settings → Secrets and variables → Codespaces
2. Add secrets:
   ```
   SECRET_STORE=s3
   SECRET_PROFILE=work
   AWS_ACCESS_KEY_ID=...
   AWS_SECRET_ACCESS_KEY=...
   ```
3. Open Codespace - secrets sync automatically!

**For Local Devcontainers:**
1. Copy `.devcontainer/.env.example` to `.devcontainer/.env`
2. Fill in your credentials
3. Build devcontainer - secrets sync automatically!

#### Using Legacy HOMEARCHIVE

Set `HOMEARCHIVE*` variables as Codespace secrets or in `.devcontainer/.env` and they'll be extracted automatically.

**See [SECRETS_SETUP_GUIDE.md](SECRETS_SETUP_GUIDE.md) for detailed instructions.**

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

### 4. Run the installer

```bash
bash install.sh
```

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

The installer automatically copies `ham` to `~/bin/ham`, which is added to your PATH.

For manual installation:

```bash
# Option 1: Symlink to a directory in your PATH
ln -s /path/to/dotfiles-min/ham ~/.local/bin/ham

# Option 2: Add to your shell profile
echo 'export PATH="/path/to/dotfiles-min:$PATH"' >> ~/.bashrc
```

## Cloud-Based Secrets with `secrets-sync` 🆕

The new `secrets-sync` tool provides a modern alternative to HOMEARCHIVE for managing secrets.

### Why Use secrets-sync?

- ☁️ **Cloud storage**: Secrets stored in S3, GitHub releases, Azure, or GCS
- 🔐 **Better security**: Only auth credentials in env vars, not file content
- 📁 **Profiles**: Easy switching between work, personal, project-specific secrets
- 🔄 **Easy updates**: Change individual files without rebuilding archives
- 📊 **Versioning**: Cloud storage provides version history
- 🚀 **Modern**: Built for cloud-native workflows

### Quick Example

```bash
# Initialize
secrets-sync init

# Configure profile (edit ~/.secrets-profiles.yaml)
# Add your S3 bucket, GitHub repo, etc.

# Add files
secrets-sync add ~/.ssh/config work
secrets-sync add ~/.aws/credentials work

# Push to cloud
secrets-sync push --profile work

# In a new environment (Codespace/devcontainer)
# Set: SECRET_STORE=s3, SECRET_PROFILE=work, AWS credentials
# Secrets sync automatically!
```

### Available Commands

- **`secrets-sync init`** - Initialize configuration
- **`secrets-sync add-profile [name]`** - Add a new profile interactively
- **`secrets-sync add <file> [profile]`** - Add a file to a profile
- **`secrets-sync push [--profile]`** - Upload secrets to cloud
- **`secrets-sync pull [--profile]`** - Download secrets from cloud
- **`secrets-sync list-profiles`** - List all profiles
- **`secrets-sync show [profile]`** - Show files in a profile
- **`secrets-sync switch <profile>`** - Switch active profile
- **`secrets-sync migrate <env> <profile>`** - Migrate from HOMEARCHIVE

### Supported Storage Backends

- **AWS S3** - Most common (free tier: 5GB)
- **GitHub Releases** - Completely free
- **Azure Blob Storage** - For Azure environments
- **Google Cloud Storage** - For GCP environments

**📖 Full documentation: [SECRETS_SETUP_GUIDE.md](SECRETS_SETUP_GUIDE.md)**

## Security Notes

### For Cloud-Based Secrets (secrets-sync)

- ✅ **Use IAM roles** when possible instead of access keys
- ✅ **Enable S3 versioning** for history and recovery
- ✅ **Use private GitHub repos** for GitHub releases backend
- ✅ **Separate profiles** for different trust levels
- ✅ **Encrypt sensitive files** with GPG before uploading (optional)
- ✅ **Set up bucket policies** to restrict access
- ⚠️ Only auth credentials in environment variables, not file content

### For Legacy HOMEARCHIVE

- Never commit actual archive contents to version control
- Use CI/CD secret management for sensitive data
- Consider file permissions in your archives (they are preserved during extraction)
- The profile script runs extraction every time it's sourced
- The manifest file is safe to commit (it only contains file paths, not contents)