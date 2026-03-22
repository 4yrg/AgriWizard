# GitHub Actions Secrets Setup Guide

## Required Secrets for CI/CD Pipeline

This pipeline requires the following secrets to be configured in GitHub:

### 1. Docker Hub Authentication (Required for image push)

Go to: **https://github.com/4yrg/AgriWizard/settings/secrets/actions**

Add these two secrets:

| Secret Name | Value | How to Get |
|-------------|-------|------------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username | Your Docker Hub account username (e.g., `agriwizard`) |
| `DOCKERHUB_TOKEN` | Docker Hub access token | See steps below |

### 2. How to Create Docker Hub Access Token

1. **Login to Docker Hub**: https://hub.docker.com
2. **Go to Security Settings**: https://hub.docker.com/settings/security
3. **Click "New access token"**
4. **Fill in the form**:
   - Token name: `GitHub Actions AgriWizard`
   - Token permissions: **Read & Write** (required for pushing images)
5. **Click "Generate"**
6. **Copy the token immediately** - it will look like: `dckr_pat_xxxxxxxxxxxxx`
   - ⚠️ **You cannot see it again after closing the popup!**
7. **Add to GitHub Secrets**:
   - Go to: https://github.com/4yrg/AgriWizard/settings/secrets/actions
   - Click "New repository secret"
   - Name: `DOCKERHUB_TOKEN`
   - Value: Paste the token you just copied
   - Click "Add secret"

### 3. SonarCloud Token (Optional - for code quality analysis)

| Secret Name | Value |
|-------------|-------|
| `SONAR_TOKEN` | Your SonarCloud project token |

Get it from: https://sonarcloud.io/account/security

---

## Verifying Your Secrets

After adding secrets, you can verify they're set correctly:

1. Go to: https://github.com/4yrg/AgriWizard/settings/secrets/actions
2. You should see:
   - `DOCKERHUB_USERNAME` ✓
   - `DOCKERHUB_TOKEN` ✓
   - `SONAR_TOKEN` (optional)

---

## Troubleshooting Docker Hub Login Errors

### Error: "unauthorized: incorrect username or password"

**Possible causes:**

1. **Wrong secret name**: Must be exactly `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` (case-sensitive)
2. **Token has no write permissions**: Regenerate token with "Read & Write" permissions
3. **Username typo**: Check for extra spaces or wrong case
4. **Token expired**: Docker Hub tokens don't expire, but you can regenerate if needed

**Solution:**

1. Delete existing secrets from GitHub
2. Generate a new Docker Hub token
3. Re-add both secrets carefully

### Error: "403 Forbidden" or "access denied"

Your Docker Hub account may need to verify email or enable 2FA.

---

## Testing Without Docker Hub Push

The pipeline will still run all other checks even without Docker Hub secrets:

- ✅ Lint & Format Check
- ✅ Trivy Security Scan
- ✅ SonarCloud Analysis
- ✅ Docker Compose Stack Test (builds locally)
- ✅ Gosec Security Analysis

The "Build & Push Docker Images" job will be skipped if secrets are missing.

---

## Quick Setup Checklist

- [ ] Create Docker Hub account (if you don't have one): https://hub.docker.com
- [ ] Generate Docker Hub access token with Read & Write permissions
- [ ] Add `DOCKERHUB_USERNAME` secret to GitHub
- [ ] Add `DOCKERHUB_TOKEN` secret to GitHub
- [ ] (Optional) Add `SONAR_TOKEN` secret to GitHub
- [ ] Push a commit to trigger the pipeline

---

## Security Best Practices

- ✅ Never commit secrets to the repository
- ✅ Use access tokens instead of passwords
- ✅ Rotate tokens periodically
- ✅ Use minimum required permissions
- ✅ Review secret access in GitHub Settings
