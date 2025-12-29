# Secrets Management Setup Guide

This guide walks you through setting up cloud-based secrets management using the new `secrets-sync` tool.

## Prerequisites

Choose your storage backend and install required CLI tools:

### AWS S3
```bash
pip install awscli
aws configure  # Or set AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION
```

### GitHub Releases (Free!)
```bash
# Install gh CLI
# macOS: brew install gh
# Linux: See https://cli.github.com/

gh auth login  # Or set GH_TOKEN
```

### Azure Blob Storage
```bash
curl -L https://aka.ms/InstallAzureCli | bash
# Set AZURE_STORAGE_ACCOUNT and AZURE_STORAGE_KEY
```

### Google Cloud Storage
```bash
curl https://sdk.cloud.google.com | bash
# Set GOOGLE_APPLICATION_CREDENTIALS
```

## Quick Start

### 1. Install dotfiles-min

```bash
git clone https://github.com/ssmiller25/dotfiles-min.git
cd dotfiles-min
bash install.sh
```

This installs:
- `secrets-sync` utility to `~/bin/secrets-sync`
- `ham` utility to `~/bin/ham`
- Shell integration for automatic secret synchronization

### 2. Initialize Configuration

```bash
secrets-sync init
```

This creates `~/.secrets-profiles.yaml` with example profiles.

### 3. Configure Your Profile

Edit `~/.secrets-profiles.yaml`:

#### Option A: AWS S3 (Recommended for most users)

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

default: work
```

#### Option B: GitHub Releases (Free alternative)

```yaml
profiles:
  personal:
    storage: github
    repo: myusername/my-secrets
    tag: secrets-v1
    files:
      - .ssh/config
      - .gitconfig

default: personal
```

### 4. Add Files to Your Profile

```bash
# Add individual files
secrets-sync add ~/.ssh/config work
secrets-sync add ~/.ssh/id_rsa work
secrets-sync add ~/.aws/credentials work

# Or edit the config file directly
vim ~/.secrets-profiles.yaml
```

### 5. Push Secrets to Cloud Storage

```bash
# Push all files in the profile
secrets-sync push --profile work

# Or push a single file
secrets-sync push ~/.ssh/config
```

### 6. Configure Environment Variables

#### For GitHub Codespaces

1. Go to your repository: Settings → Secrets and variables → Codespaces
2. Add secrets:
   ```
   SECRET_STORE=s3
   SECRET_PROFILE=work
   AWS_ACCESS_KEY_ID=AKIA...
   AWS_SECRET_ACCESS_KEY=...
   AWS_DEFAULT_REGION=us-east-1
   ```

#### For Local Devcontainers

Create `.devcontainer/.env`:

```bash
SECRET_STORE=s3
SECRET_PROFILE=work
AWS_ACCESS_KEY_ID=AKIA...
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

**Important:** Add `.devcontainer/.env` to your `.gitignore`!

### 7. Test in a New Environment

When you open a Codespace or devcontainer:

1. The `install.sh` script runs automatically (`postCreateCommand`)
2. Secrets are synced from cloud storage
3. Files are placed in your `$HOME` directory
4. Ready to use!

## Daily Workflow

### Pull Latest Secrets

```bash
secrets-sync pull
```

This happens automatically when you open a new shell (if `SECRET_STORE` and `SECRET_PROFILE` are set).

### Update a Secret

```bash
# Edit the file
vim ~/.ssh/config

# Push changes
secrets-sync push ~/.ssh/config
```

### Switch Between Profiles

```bash
# Switch to a different profile
secrets-sync switch personal

# Pull secrets for new profile
secrets-sync pull
```

## Advanced Usage

### Multiple Profiles

```yaml
profiles:
  work:
    storage: s3
    bucket: company-secrets
    prefix: dotfiles/work/
    files:
      - .ssh/config
      - .aws/credentials
      - .kube/config
  
  personal:
    storage: github
    repo: myuser/secrets
    tag: personal-v1
    files:
      - .ssh/config
      - .gitconfig
  
  project-alpha:
    storage: s3
    bucket: project-alpha-secrets
    prefix: dotfiles/
    files:
      - .env
      - .aws/credentials

default: work
```

Switch between them:

```bash
export SECRET_PROFILE=personal
secrets-sync pull
```

### Migrating from HOMEARCHIVE Environment Variables

If you're already using the HOMEARCHIVE* system:

```bash
# Migrate existing archive to a profile
secrets-sync migrate HOMEARCHIVE work

# Push to cloud storage
secrets-sync push --profile work

# Optional: Remove old environment variable
unset HOMEARCHIVE
```

### Dry Run (Preview Changes)

```bash
# See what would be uploaded without actually uploading
secrets-sync push --profile work --dry-run
```

### Using Different Storage for Different Profiles

```yaml
profiles:
  work:
    storage: s3
    bucket: company-secrets
    # ...
  
  personal:
    storage: github
    repo: myuser/secrets
    # ...
```

Each profile can use a different storage backend!

## Security Best Practices

### 1. Use IAM Roles When Possible

For AWS, use IAM roles instead of access keys:

```yaml
# In Codespaces, attach an IAM role to the environment
# No need for AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY
```

### 2. Encrypt Sensitive Secrets

For extra security, encrypt files before uploading:

```bash
# Encrypt a file before adding to profile
gpg --encrypt --recipient your@email.com ~/.ssh/id_rsa

# Add encrypted version
secrets-sync add ~/.ssh/id_rsa.gpg work
```

### 3. Use Separate Profiles for Different Trust Levels

```yaml
profiles:
  public:  # Less sensitive configs
    storage: github
    # ...
  
  private:  # More sensitive credentials
    storage: s3
    # ...
```

### 4. Set Up S3 Bucket Policies

Restrict access to your secrets bucket:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT:user/YOUR_USER"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::my-secrets-bucket/*"
    }
  ]
}
```

### 5. Enable S3 Versioning

Keep history of your secrets:

```bash
aws s3api put-bucket-versioning \
  --bucket my-secrets-bucket \
  --versioning-configuration Status=Enabled
```

### 6. Use GitHub Private Repositories

If using GitHub releases, use a private repository:

```bash
gh repo create my-secrets --private
```

## Troubleshooting

### Secrets not syncing in Codespace

1. Check environment variables are set:
   ```bash
   echo $SECRET_STORE
   echo $SECRET_PROFILE
   ```

2. Check CLI tools are installed:
   ```bash
   which aws  # or gh, az, gsutil
   ```

3. Check credentials are valid:
   ```bash
   aws s3 ls  # or: gh auth status
   ```

4. Run manually for debugging:
   ```bash
   DEBUG=1 secrets-sync pull
   ```

### Permission denied errors

Check file permissions in your profile. Files maintain their permissions when uploaded/downloaded.

```bash
# Fix SSH key permissions
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

### AWS S3 access denied

1. Verify bucket exists and you have access:
   ```bash
   aws s3 ls s3://my-bucket-name/
   ```

2. Check IAM permissions include `s3:GetObject` and `s3:PutObject`

### GitHub authentication issues

```bash
# Re-authenticate
gh auth login

# Or set token
export GH_TOKEN=ghp_...
```

## Storage Costs

### AWS S3
- **Free tier**: 5GB storage, 20,000 GET requests, 2,000 PUT requests/month
- **Cost after free tier**: ~$0.023/GB/month
- **Typical usage**: <1GB = essentially free

### GitHub Releases
- **Free**: Unlimited for public and private repos
- **Limitation**: Assets limited to 2GB per file, 10GB per release

### Azure Blob Storage
- **Free tier**: Not available
- **Cost**: ~$0.018/GB/month (Hot tier)

### Google Cloud Storage
- **Free tier**: 5GB/month
- **Cost after**: ~$0.020/GB/month (Standard)

## Comparison with HOMEARCHIVE

| Feature | HOMEARCHIVE* | secrets-sync |
|---------|-------------|--------------|
| Storage | Environment variables | Cloud storage |
| Size limit | Limited by env var | Unlimited (practical) |
| Update file | Rebuild archive | Update single file |
| Versioning | None | Cloud provider versioning |
| Audit trail | None | Cloud provider logs |
| Multiple profiles | Multiple env vars | Clean config system |
| Cost | Free | Mostly free (S3 free tier) |

## Getting Help

- **View available commands**: `secrets-sync help`
- **Debug mode**: `DEBUG=1 secrets-sync pull`
- **List profiles**: `secrets-sync list-profiles`
- **Show profile files**: `secrets-sync show work`

## Next Steps

1. ✅ Complete this setup guide
2. Set up profiles for your use cases (work, personal, etc.)
3. Configure environment variables in Codespaces/devcontainer
4. Test in a fresh environment
5. (Optional) Migrate from HOMEARCHIVE* if currently using it
6. Share this setup with your team!
