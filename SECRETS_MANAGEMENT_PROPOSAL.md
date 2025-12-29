# Secrets Management Proposal

## Problem Statement

The current dotfiles-min solution stores secret files as base64-encoded tarballs in environment variables (HOMEARCHIVE*). While functional, this approach has several limitations:

1. **Large environment variable size**: Secret files are stored as long base64 strings in environment variables
2. **Difficult to manage**: Updating secrets requires re-encoding and re-setting entire environment variables
3. **No versioning**: Changes to secrets are not tracked or versioned
4. **Limited portability**: Large environment variables can hit size limits in some environments
5. **Poor secret rotation**: Rotating individual secrets requires rebuilding entire archives

## Proposed Solution: Cloud-Based Secret Storage with Profile Support

### Overview

Instead of storing file content in environment variables, store secrets in cloud storage (S3, Azure Blob, GCS) or GitHub releases, and use **environment variables only for authentication credentials**. This provides:

- ✅ **Better secret management**: Files stored in versioned cloud storage
- ✅ **Easy updates**: Change individual files without affecting others
- ✅ **Profile support**: Switch between different secret sets (work, personal, project-specific)
- ✅ **Smaller environment variables**: Only credentials, not file content
- ✅ **Works in Codespaces & Devcontainers**: Standard cloud CLI tools available

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Codespace / Devcontainer Environment                        │
│                                                              │
│  ┌──────────────────────┐                                   │
│  │ Environment Variables │ (Authentication Only)            │
│  │ - SECRET_STORE=s3    │                                   │
│  │ - SECRET_PROFILE=work│                                   │
│  │ - AWS_ACCESS_KEY_ID  │                                   │
│  │ - AWS_SECRET_KEY     │                                   │
│  └──────────────────────┘                                   │
│           │                                                  │
│           ▼                                                  │
│  ┌──────────────────────┐                                   │
│  │ secrets-sync tool    │                                   │
│  │ - Reads profile      │                                   │
│  │ - Authenticates      │                                   │
│  │ - Downloads secrets  │                                   │
│  └──────────────────────┘                                   │
│           │                                                  │
└───────────┼──────────────────────────────────────────────────┘
            │
            ▼
  ┌─────────────────────┐
  │ Cloud Storage       │
  │                     │
  │ work/               │
  │  ├── .ssh/          │
  │  ├── .aws/          │
  │  └── .kube/         │
  │                     │
  │ personal/           │
  │  ├── .ssh/          │
  │  └── .gitconfig     │
  │                     │
  │ project-x/          │
  │  └── .env           │
  └─────────────────────┘
```

### Supported Storage Backends

1. **AWS S3** - Most common, excellent SDK support
2. **Azure Blob Storage** - For Azure-heavy environments
3. **Google Cloud Storage** - For GCP environments
4. **GitHub Releases** - Free, built-in, great for open-source
5. **SFTP/SSH** - For self-hosted solutions
6. **Local fallback** - For testing or offline scenarios

### Profile-Based Configuration

Profiles allow switching between different secret sets (e.g., work, personal, project-specific).

**Configuration file**: `~/.secrets-profiles.yaml`

```yaml
profiles:
  work:
    storage: s3
    bucket: my-company-secrets
    prefix: dotfiles/work/
    files:
      - .ssh/config
      - .ssh/id_rsa
      - .ssh/id_rsa.pub
      - .aws/config
      - .aws/credentials
      - .kube/config
    
  personal:
    storage: s3
    bucket: my-personal-secrets
    prefix: dotfiles/personal/
    files:
      - .ssh/config
      - .ssh/id_rsa_personal
      - .gitconfig
      - .gnupg/gpg.conf
    
  project-x:
    storage: github-release
    repo: myorg/project-x
    tag: secrets-v1
    files:
      - .env
      - .aws/credentials
      - config/app.yaml

# Default profile to use if SECRET_PROFILE not set
default: work
```

### Environment Variables (Authentication Only)

```bash
# Required: Storage backend selection and profile
export SECRET_STORE=s3           # or: azure, gcs, github, sftp, local
export SECRET_PROFILE=work       # Profile name from config

# AWS S3 Authentication
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=us-east-1

# Azure Blob Authentication
export AZURE_STORAGE_ACCOUNT=myaccount
export AZURE_STORAGE_KEY=...

# GCS Authentication
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json

# GitHub Authentication (uses gh CLI)
export GH_TOKEN=ghp_...

# SFTP Authentication
export SFTP_HOST=secrets.example.com
export SFTP_USER=myuser
export SFTP_KEY=/path/to/ssh/key
```

### Implementation Components

#### 1. `secrets-sync` - Main Secret Synchronization Tool

```bash
# Initialize profiles configuration
secrets-sync init

# Sync secrets for current/specified profile
secrets-sync pull [--profile work]

# Push local changes back to storage
secrets-sync push [--profile work] [--file .ssh/config]

# List available profiles
secrets-sync list-profiles

# Show what files are in a profile
secrets-sync show [--profile work]

# Switch active profile
secrets-sync switch personal

# Encrypt secrets before upload (optional)
secrets-sync push --encrypt --key-env SECRET_ENCRYPTION_KEY
```

#### 2. Updated Shell Integration

The `.bashrc`/`.zshrc` injection will:

1. Check for `SECRET_STORE` and `SECRET_PROFILE` environment variables
2. If present, run `secrets-sync pull` automatically
3. Extract secrets to `$HOME`
4. Fall back to HOMEARCHIVE* variables if secrets-sync not configured

#### 3. Integration with `ham` utility

Extend `ham` to support remote storage:

```bash
# Push to cloud storage instead of GitHub variables
ham push --profile work --storage s3

# Pull from cloud storage
ham pull --profile work

# List remote profiles
ham profiles

# Add file to profile
ham add ~/.ssh/config --profile work
```

### Migration Path

For existing users with HOMEARCHIVE* variables:

```bash
# 1. Export existing archives to profile
secrets-sync migrate --from-env HOMEARCHIVE --to-profile work

# 2. Upload to cloud storage
secrets-sync push --profile work

# 3. (Optional) Remove HOMEARCHIVE* environment variables
# 4. Set new authentication variables instead
```

### Security Considerations

1. **Encryption at Rest**: All cloud storage backends support encryption
2. **Encryption in Transit**: Use HTTPS/TLS for all transfers
3. **Optional Client-Side Encryption**: Add `--encrypt` flag for additional encryption layer
4. **Access Control**: Use IAM roles/policies to restrict access
5. **Audit Logging**: Cloud providers offer audit logs for access tracking
6. **Key Rotation**: Easier to rotate individual files without rebuilding archives
7. **Secrets never in Git**: Files are pulled from remote, never committed

### Setup Instructions

#### For GitHub Codespaces

1. **Set repository secrets** (Settings → Secrets → Codespaces):
   ```
   SECRET_STORE=s3
   SECRET_PROFILE=work
   AWS_ACCESS_KEY_ID=...
   AWS_SECRET_ACCESS_KEY=...
   ```

2. **Update devcontainer.json** (already handles postCreateCommand):
   ```json
   {
     "postCreateCommand": "bash install.sh"
   }
   ```

3. **Secrets are automatically synced** on Codespace creation

#### For Local Devcontainers

1. **Create `.devcontainer/.env`** (gitignored):
   ```
   SECRET_STORE=s3
   SECRET_PROFILE=work
   AWS_ACCESS_KEY_ID=...
   AWS_SECRET_ACCESS_KEY=...
   ```

2. **Update devcontainer.json**:
   ```json
   {
     "runArgs": ["--env-file", ".devcontainer/.env"],
     "postCreateCommand": "bash install.sh"
   }
   ```

### Advantages Over Current System

| Feature | Current (HOMEARCHIVE*) | Proposed (Cloud Storage) |
|---------|------------------------|--------------------------|
| Secret Size Limit | Limited by env var size | Unlimited |
| Update Individual File | Must rebuild entire archive | Update single file |
| Version Control | None | Cloud storage versioning |
| Multiple Profiles | Multiple env vars | Clean profile system |
| Audit Trail | None | Cloud provider logs |
| Secret Rotation | Difficult | Easy |
| Collaboration | Share env vars | Share cloud access |
| Cost | Free | Minimal (S3 free tier: 5GB) |

### Backward Compatibility

The system will maintain backward compatibility:

1. If `HOMEARCHIVE*` variables exist, use them (current behavior)
2. If `SECRET_STORE` is set, use new secrets-sync system
3. Both can coexist for gradual migration

### Implementation Priority

1. **Phase 1** (High Priority):
   - Create `secrets-sync` tool with S3 support
   - Profile configuration system
   - Shell integration for auto-sync
   - Migration tool from HOMEARCHIVE*

2. **Phase 2** (Medium Priority):
   - Add GitHub releases support (free alternative)
   - Add Azure/GCS support
   - Encryption layer
   - Enhanced `ham` integration

3. **Phase 3** (Nice to Have):
   - SFTP support
   - GUI for profile management
   - Advanced conflict resolution
   - Backup/restore capabilities

### Example Usage Workflow

```bash
# Initial setup (one-time)
secrets-sync init
secrets-sync add-profile work --storage s3 --bucket my-secrets

# Add files to profile
secrets-sync add ~/.ssh/config --profile work
secrets-sync add ~/.aws/credentials --profile work

# Push to cloud
secrets-sync push --profile work

# In a new Codespace/devcontainer
# (Environment variables already set)
secrets-sync pull  # Automatically pulls 'work' profile

# Update a secret
vim ~/.ssh/config
secrets-sync push ~/.ssh/config  # Only updates this file

# Switch profiles
secrets-sync switch personal
secrets-sync pull  # Downloads personal profile secrets
```

### Recommended Storage Solution

**For most users**: **AWS S3** with IAM roles
- Free tier: 5GB storage, 20,000 GET requests, 2,000 PUT requests/month
- Excellent tooling (aws-cli, boto3)
- Works in all environments
- Encryption at rest by default
- Versioning support

**For open-source/free**: **GitHub Releases**
- Completely free
- No additional credentials beyond gh CLI
- Good for non-sensitive or encrypted secrets
- Built into GitHub workflow

### Questions for User

1. **Preferred storage backend**: S3, Azure, GCS, GitHub, or self-hosted?
2. **Encryption requirements**: Client-side encryption needed?
3. **Migration timeline**: Immediate or gradual migration from HOMEARCHIVE*?
4. **Profile requirements**: How many profiles needed? (work, personal, etc.)
5. **Sharing needs**: Will profiles be shared with team members?

---

## Next Steps

1. Review and approve proposal
2. Choose storage backend(s) to implement
3. Implement Phase 1 components
4. Test in Codespaces and devcontainer
5. Document migration process
6. Roll out to users
