# Examples: Using secrets-sync

This document provides practical examples of using the secrets-sync tool.

## Example 1: Using AWS S3 for Work Secrets

### Initial Setup

```bash
# 1. Install dotfiles-min
git clone https://github.com/ssmiller25/dotfiles-min.git
cd dotfiles-min
bash install.sh

# 2. Configure AWS credentials
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="us-east-1"

# 3. Initialize secrets-sync
secrets-sync init

# 4. Edit config to use your S3 bucket
vim ~/.secrets-profiles.yaml
```

Edit the config:
```yaml
profiles:
  work:
    storage: s3
    bucket: mycompany-dotfiles-secrets
    prefix: users/jdoe/
    files:
      - .ssh/config
      - .ssh/id_rsa
      - .ssh/id_rsa.pub
      - .aws/config
      - .aws/credentials
      - .kube/config

default: work
```

```bash
# 5. Add files (they must exist first)
secrets-sync add ~/.ssh/config work
secrets-sync add ~/.ssh/id_rsa work
secrets-sync add ~/.aws/credentials work

# 6. Push to S3
secrets-sync push --profile work

# Output:
# ℹ Creating archive work...
# ℹ Including 3 file(s):
#   - .ssh/config
#   - .ssh/id_rsa
#   - .aws/credentials
# ✓ Archive created: /tmp/homearchive.XXX.tar.gz
# ℹ Uploading to S3: s3://mycompany-dotfiles-secrets/users/jdoe/
# ✓ Uploaded: .ssh/config
# ✓ Uploaded: .ssh/id_rsa
# ✓ Uploaded: .aws/credentials
# ✓ Secrets pushed successfully
```

### Using in Codespaces

1. Go to your repository → Settings → Secrets and variables → Codespaces
2. Add these secrets:
   ```
   Name: SECRET_STORE
   Value: s3
   
   Name: SECRET_PROFILE
   Value: work
   
   Name: AWS_ACCESS_KEY_ID
   Value: AKIA...
   
   Name: AWS_SECRET_ACCESS_KEY
   Value: ...
   
   Name: AWS_DEFAULT_REGION
   Value: us-east-1
   ```

3. Open a Codespace
4. Secrets automatically sync on startup!

### Daily Usage

```bash
# Update SSH config
vim ~/.ssh/config

# Push changes
secrets-sync push ~/.ssh/config

# In another Codespace, pull latest
secrets-sync pull
```

---

## Example 2: Using GitHub Releases (Free!)

### Setup

```bash
# 1. Install gh CLI and authenticate
gh auth login

# 2. Create a private repo for secrets
gh repo create my-secrets --private

# 3. Initialize secrets-sync
secrets-sync init

# 4. Configure for GitHub
vim ~/.secrets-profiles.yaml
```

Edit config:
```yaml
profiles:
  personal:
    storage: github
    repo: myusername/my-secrets
    tag: dotfiles-v1
    files:
      - .ssh/config
      - .gitconfig
      - .gnupg/gpg.conf

default: personal
```

```bash
# 5. Add and push files
secrets-sync add ~/.ssh/config personal
secrets-sync add ~/.gitconfig personal
secrets-sync push --profile personal
```

### Using in Codespaces

Set these Codespace secrets:
```
SECRET_STORE=github
SECRET_PROFILE=personal
GH_TOKEN=ghp_...
```

---

## Example 3: Multiple Profiles (Work + Personal)

```yaml
profiles:
  work:
    storage: s3
    bucket: company-secrets
    prefix: dotfiles/work/
    files:
      - .ssh/config
      - .ssh/id_rsa_work
      - .aws/credentials
      - .kube/config
  
  personal:
    storage: github
    repo: myuser/personal-secrets
    tag: secrets-v1
    files:
      - .ssh/config
      - .ssh/id_rsa_personal
      - .gitconfig

default: work
```

### Switching Between Profiles

```bash
# Use work profile
export SECRET_PROFILE=work
secrets-sync pull

# Switch to personal
export SECRET_PROFILE=personal
secrets-sync pull

# Or use the switch command
secrets-sync switch personal
```

---

## Example 4: Project-Specific Secrets

For a specific project with its own secrets:

```yaml
profiles:
  project-alpha:
    storage: s3
    bucket: project-alpha-secrets
    prefix: dotfiles/
    files:
      - .env
      - .aws/credentials
      - config/database.yml
      - config/api-keys.json

default: work
```

In the project's `.devcontainer/devcontainer.json`:

```json
{
  "containerEnv": {
    "SECRET_STORE": "s3",
    "SECRET_PROFILE": "project-alpha"
  }
}
```

---

## Example 5: Migrating from HOMEARCHIVE

If you're currently using HOMEARCHIVE:

```bash
# 1. Export existing HOMEARCHIVE variable
echo $HOMEARCHIVE  # Verify it exists

# 2. Initialize secrets-sync
secrets-sync init

# 3. Configure a profile
vim ~/.secrets-profiles.yaml

# 4. Migrate from HOMEARCHIVE to profile
secrets-sync migrate HOMEARCHIVE work

# Output:
# ℹ Migrating from HOMEARCHIVE to profile work
# ℹ Files in archive:
#   • .ssh/config
#   • .ssh/id_rsa
#   • .aws/credentials
# ✓ Added .ssh/config to work
# ✓ Added .ssh/id_rsa to work
# ✓ Added .aws/credentials to work
# ✓ Migration complete
# ℹ Next steps:
#   1. Run: secrets-sync push --profile work
#   2. Remove environment variable: unset HOMEARCHIVE

# 5. Push to cloud storage
secrets-sync push --profile work

# 6. Test in a new shell
unset HOMEARCHIVE
export SECRET_STORE=s3
export SECRET_PROFILE=work
# Open new shell - secrets sync automatically!

# 7. Remove HOMEARCHIVE from your Codespace secrets
```

---

## Example 6: Using Different Files in Different Environments

```yaml
profiles:
  work-laptop:
    storage: s3
    bucket: my-secrets
    prefix: work-laptop/
    files:
      - .ssh/config
      - .ssh/id_rsa_work
      - .aws/credentials
      - .kube/config-prod
  
  work-codespace:
    storage: s3
    bucket: my-secrets
    prefix: work-codespace/
    files:
      - .ssh/config
      - .ssh/id_rsa_work
      - .aws/credentials
      # No kube config - not needed in Codespace
  
  personal-home:
    storage: github
    repo: myuser/secrets
    tag: personal-v1
    files:
      - .ssh/config
      - .ssh/id_rsa_personal
      - .gitconfig

default: work-codespace
```

Set different `SECRET_PROFILE` in each environment.

---

## Example 7: Dry Run Before Pushing

Test what would be uploaded without actually uploading:

```bash
# Dry run
secrets-sync push --profile work --dry-run

# Output:
# ℹ Creating archive work...
# ℹ Including 5 file(s):
#   - .ssh/config
#   - .ssh/id_rsa
#   - .ssh/id_rsa.pub
#   - .aws/credentials
#   - .kube/config
# ✓ Archive created: /tmp/homearchive.XXX.tar.gz
# ℹ Dry run mode - archive created but not uploaded
# ℹ Archive size: 4.2K
# ℹ Would update GitHub variable: work (target: s3)
```

---

## Example 8: Adding Files to Existing Profile

```bash
# Add a single file
secrets-sync add ~/.kube/config work

# Push just that file
secrets-sync push ~/.kube/config

# Or push all files
secrets-sync push --profile work
```

---

## Example 9: Viewing Profile Contents

```bash
# List all profiles
secrets-sync list-profiles

# Output:
# ℹ Available profiles:
#   • work
#   • personal
#   • project-alpha
# 
# ℹ Default profile: work
# ℹ Current profile: work

# Show files in a specific profile
secrets-sync show work

# Output:
# ℹ Profile: work
#   • .ssh/config
#   • .ssh/id_rsa
#   • .aws/credentials
#   • .kube/config
```

---

## Example 10: Debugging Connection Issues

```bash
# Enable debug mode
DEBUG=1 secrets-sync pull --profile work

# Output will show detailed information about:
# - Which profile is being loaded
# - Storage backend being used
# - Files being downloaded
# - Any errors encountered
```

Test credentials manually:

```bash
# For S3
aws s3 ls s3://your-bucket/

# For GitHub
gh auth status

# For Azure
az storage blob list --account-name myaccount --container-name mycontainer

# For GCS
gsutil ls gs://your-bucket/
```

---

## Best Practices

1. **Start with GitHub releases** if you're new - it's free and easy
2. **Use separate profiles** for work and personal
3. **Test in a fresh Codespace** before committing to the workflow
4. **Enable S3 versioning** for backup/recovery
5. **Use private repos** for GitHub releases backend
6. **Set up IAM roles** instead of access keys when possible
7. **Document your setup** for team members
8. **Use dry-run** before pushing to verify changes
9. **Keep sensitive files encrypted** with GPG for extra security
10. **Regular backups** - secrets-sync doesn't replace proper backup strategy
