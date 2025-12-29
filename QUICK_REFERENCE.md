# Quick Reference: secrets-sync Commands

## Setup & Configuration

```bash
# Initialize configuration
secrets-sync init

# Add a profile interactively
secrets-sync add-profile

# Edit config manually
vim ~/.secrets-profiles.yaml
```

## Managing Files

```bash
# Add a file to a profile
secrets-sync add ~/.ssh/config work

# Add multiple files
secrets-sync add ~/.ssh/id_rsa work
secrets-sync add ~/.aws/credentials work
```

## Syncing Secrets

```bash
# Push all files in current profile
secrets-sync push

# Push all files in specific profile
secrets-sync push --profile work

# Push a single file
secrets-sync push ~/.ssh/config

# Pull all files
secrets-sync pull

# Pull from specific profile
secrets-sync pull --profile personal
```

## Viewing Information

```bash
# List all profiles
secrets-sync list-profiles

# Show files in a profile
secrets-sync show work

# Show files in current profile
secrets-sync show
```

## Profile Management

```bash
# Switch active profile
secrets-sync switch personal

# This sets SECRET_PROFILE for current session
# To make permanent: export SECRET_PROFILE=personal
```

## Migration

```bash
# Migrate from HOMEARCHIVE
secrets-sync migrate HOMEARCHIVE work

# Then push to cloud
secrets-sync push --profile work
```

## Environment Variables

### Required
```bash
export SECRET_STORE=s3        # or: github, azure, gcs
export SECRET_PROFILE=work    # profile name from config
```

### AWS S3
```bash
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=us-east-1
```

### GitHub Releases
```bash
export GH_TOKEN=ghp_...
# Or: gh auth login
```

### Azure Blob
```bash
export AZURE_STORAGE_ACCOUNT=myaccount
export AZURE_STORAGE_KEY=...
```

### Google Cloud Storage
```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
```

## Example Config File

`~/.secrets-profiles.yaml`:

```yaml
profiles:
  work:
    storage: s3
    bucket: company-secrets
    prefix: dotfiles/work/
    files:
      - .ssh/config
      - .ssh/id_rsa
      - .aws/credentials
  
  personal:
    storage: github
    repo: myuser/my-secrets
    tag: secrets-v1
    files:
      - .ssh/config
      - .gitconfig

default: work
```

## Codespaces Setup

### Set Repository Secrets
1. Go to: Settings → Secrets and variables → Codespaces
2. Add:
   - `SECRET_STORE=s3`
   - `SECRET_PROFILE=work`
   - `AWS_ACCESS_KEY_ID=...`
   - `AWS_SECRET_ACCESS_KEY=...`
   - `AWS_DEFAULT_REGION=...`

### Devcontainer Setup
Create `.devcontainer/.env`:
```bash
SECRET_STORE=s3
SECRET_PROFILE=work
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_DEFAULT_REGION=us-east-1
```

Update `.devcontainer/devcontainer.json`:
```json
{
  "runArgs": ["--env-file", ".devcontainer/.env"],
  "postCreateCommand": "bash install.sh"
}
```

**Don't forget to add `.devcontainer/.env` to `.gitignore`!**

## Troubleshooting

```bash
# Enable debug mode
DEBUG=1 secrets-sync pull

# Test cloud credentials
aws s3 ls                    # S3
gh auth status              # GitHub
az storage blob list ...    # Azure
gsutil ls gs://bucket/      # GCS

# Verify config
cat ~/.secrets-profiles.yaml

# Check environment
echo $SECRET_STORE
echo $SECRET_PROFILE
```

## Common Workflows

### Initial Setup Workflow
```bash
# 1. Install
bash install.sh

# 2. Initialize
secrets-sync init

# 3. Configure
vim ~/.secrets-profiles.yaml

# 4. Add files
secrets-sync add ~/.ssh/config work
secrets-sync add ~/.aws/credentials work

# 5. Push to cloud
secrets-sync push --profile work

# 6. Set environment variables
export SECRET_STORE=s3
export SECRET_PROFILE=work
```

### Daily Update Workflow
```bash
# 1. Edit file
vim ~/.ssh/config

# 2. Push changes
secrets-sync push ~/.ssh/config

# Done! Other environments will get updates on next pull
```

### New Environment Workflow
```bash
# Environment variables already set in Codespaces/devcontainer
# Secrets sync automatically on shell startup

# Or manually:
secrets-sync pull
```

### Multi-Profile Workflow
```bash
# Use work profile
export SECRET_PROFILE=work
secrets-sync pull

# Switch to personal
export SECRET_PROFILE=personal
secrets-sync pull

# Or use switch command
secrets-sync switch personal
```

## Storage Backend Features

| Backend | Free | Size Limit | Version History | Best For |
|---------|------|------------|-----------------|----------|
| **AWS S3** | 5GB free tier | Unlimited | Yes | Most users |
| **GitHub** | Yes | 2GB/file | Yes | Open source |
| **Azure** | No | Unlimited | Yes | Azure users |
| **GCS** | 5GB free tier | Unlimited | Yes | GCP users |

## Help

```bash
# Show help
secrets-sync help

# Show version
secrets-sync version
```

## Quick Tips

- 💡 Start with GitHub releases if unsure (it's free!)
- 💡 Use `secrets-sync show` to verify what's in a profile
- 💡 Enable S3 versioning for backup
- 💡 Use separate profiles for work/personal
- 💡 Test in a fresh Codespace before committing
- 💡 Keep `.devcontainer/.env` in `.gitignore`
- 💡 Use private GitHub repos for secret storage
- 💡 Set up IAM roles instead of access keys when possible
