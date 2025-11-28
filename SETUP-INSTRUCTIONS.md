# Docker CI/CD Setup Instructions

## What Was Created

1. **Dockerfile** (`JavaApp/Dockerfile`) - Multi-stage build for Spring Boot app
2. **GitHub Actions Workflow** (`.github/workflows/build-and-push.yml`) - Auto-builds on push
3. **.dockerignore** - Optimizes Docker build

## Setup Steps

### 1. Add Docker Hub Secrets to GitHub

Go to: https://github.com/Tydisis/Jaylens-Repo/settings/secrets/actions

Add these secrets:
- `DOCKER_USERNAME` - Your Docker Hub username
- `DOCKER_PASSWORD` - Your Docker Hub password or access token

### 2. Test Locally (Optional)

```bash
cd ~/Downloads/store/JavaApp
docker build -t spring-boot-app .
docker run -p 8080:8080 spring-boot-app
```

### 3. Push to GitHub

```bash
cd ~/Downloads/store
git add .
git commit -m "Add Docker CI/CD pipeline"
git push
```

### 4. Watch the Build

- Go to: https://github.com/Tydisis/Jaylens-Repo/actions
- You'll see the workflow running on your ARC runners
- Check runner pods: `kubectl get pods -n arc-runners -w`

## How It Works

1. You push code to GitHub
2. GitHub Actions triggers on the ARC runner
3. Runner builds Docker image
4. Image is pushed to Docker Hub with tags:
   - `latest` (always current)
   - `<commit-sha>` (specific version)

## Pull and Run Your Image

```bash
docker pull <your-dockerhub-username>/spring-boot-app:latest
docker run -p 8080:8080 <your-dockerhub-username>/spring-boot-app:latest
```

## Alternative: Push to Amazon ECR

If you want to use ECR instead of Docker Hub, replace the login step with:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::ACCOUNT:role/ROLE
    aws-region: us-east-1

- name: Login to Amazon ECR
  uses: aws-actions/amazon-ecr-login@v2

- name: Build and push
  uses: docker/build-push-action@v5
  with:
    context: ./JavaApp
    push: true
    tags: ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/spring-boot-app:latest
```
