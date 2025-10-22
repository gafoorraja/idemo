# Deployment Setup Notes

This document tracks step-by-step actions to prepare the environment for the interview task.

## 1) Podman setup on macOS (Apple Silicon)

These steps install Podman, create the Podman VM ("podman machine"), and verify image build/run.

### Prerequisites
- Homebrew installed (`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`)
- macOS Apple Silicon (M1/M2/M3/M4)

### Install Podman
```bash
brew update
brew install podman
# Optional utilities
brew install podman-compose # docker-compose compatible syntax using Podman
# Optional GUI
# brew install --cask podman-desktop
```

### Initialize Podman machine (VM)
The Podman CLI on macOS uses a lightweight VM. Configure CPU/RAM/disk as needed.
```bash
# Create the default machine with reasonable resources
podman machine init \
  --cpus 4 \
  --memory 4096 \
  --disk-size 20

# Start the machine
podman machine start
```

You can reconfigure later with `podman machine stop` then `podman machine rm` and re-run `init`.

### Verify installation
```bash
# Confirm connection and environment
podman info

# Run a simple container
podman run --rm alpine:3.20 uname -a

# Pull and run hello-world style image
podman run --rm hello-world
```

### Quick test image build
Create a minimal container image and run it to validate builds work end-to-end.
```bash
# Create a temp build context
TMPDIR=$(mktemp -d)
cat > "$TMPDIR/Containerfile" <<'EOF'
FROM alpine:3.20
RUN echo "Hello from Podman on macOS!" > /hello.txt
CMD ["/bin/sh", "-lc", "cat /hello.txt && echo OK"]
EOF

# Build image
podman build -t demo/hello:local "$TMPDIR"

# Run the image
podman run --rm demo/hello:local
```

### Optional: Docker-compatible socket for tooling
If you use tools that expect a Docker API (e.g., `docker` CLI, some CI/CD plugins), you can expose the Docker-compatible API from Podman and point `DOCKER_HOST` to it.

```bash
# Ensure the machine is running
podman machine start

# Start the Podman Docker-compatible service in the background (persists for the VM lifecycle)
podman system service -t 0 &

# Discover the socket path and export DOCKER_HOST on macOS host
SOCK=$(podman machine inspect --format '{{ .ConnectionInfo.PodmanSocket.Path }}')
echo "Podman socket: $SOCK"
# For current shell session:
export DOCKER_HOST="unix://$SOCK"

# Verify the docker-compatible API works (docker CLI talks to Podman)
# If you have docker CLI installed, this should return version info via Podman
# docker version
```

Notes:
- The `podman system service` command needs to be active to serve the Docker API. You can manage it via your shell profile or a small launch agent if desired.
- For most workflows, using `podman` CLI directly (without the docker socket) is preferred.

---

## 2) AWS Free Tier setup
The goal is to create a secure, low-cost playground account suitable for Terraform and CI/CD, with strong guardrails and no host-level changes on macOS.

### Create and secure the account (root)
1. Sign up: `https://aws.amazon.com/free/` → create a new account using a dedicated email alias (e.g., `you+aws-sandbox@domain.com`).
2. Choose "Individual" and a debit/credit card. Complete phone verification.
3. Sign in as root (email + password). Immediately:
   - Enable MFA for the root user (Security credentials → Assign MFA device → Virtual MFA app like Authy/1Password).
   - Create a strong, unique root password (store in password manager). Do not use root for daily work.

### Set cost guardrails (Billing)
1. Activate Cost Explorer (Billing → Cost Management → Cost Explorer → Enable).
2. Create Budgets:
   - Monthly cost budget (e.g., USD 5) with email alerts at 50%/80%/100%.
   - Free Tier usage budget (prebuilt) with email alerts.
3. Enable Cost Anomaly Detection (use the preconfigured daily monitor).
4. Turn on Detailed Billing Reports if desired (optional).

### Identity: use IAM Identity Center (recommended)
This avoids long-lived access keys and works well with Terraform via SSO profiles.
1. Go to IAM Identity Center → Enable (if not already).
2. Set up identity source (default is "Identity Center directory"). Keep default unless you have an IdP.
3. Create a Permission Set:
   - Name: `AdministratorAccess-Sandbox`
   - Policies: attach AWS managed `AdministratorAccess`
   - Session duration: 1 hour (or 4–8 hours if preferred)
   - Relay/Tags: leave defaults
4. Create a User:
   - Navigate: IAM Identity Center → Users → Create user
   - Username: your name (e.g., `gafoor`)
   - Email: your email (receives invite)
   - Set a display name; leave groups empty (optional)
   - Send email to user to set password
5. Require MFA:
   - IAM Identity Center → Settings → Authentication → Multi-factor authentication → Require MFA for all users
   - Choose "Authenticator app"; users register device on first login
6. Assign account access:
   - IAM Identity Center → AWS accounts → Assign users or groups
   - Select your AWS account (the sandbox root account listed)
   - Select the user you created
   - Choose permission set `AdministratorAccess-Sandbox`
   - Submit
7. Capture your access portal URL:
   - IAM Identity Center → Dashboard → Copy "AWS access portal URL" (used for `aws sso login`).
8. Validate:
   - Open the access portal URL → login with your new user → complete MFA → verify you can access the sandbox account with Administrator role

Alternative (not recommended for long-term): Create an IAM user with MFA and only create programmatic access keys when strictly necessary. Prefer SSO for least risk.

### Foundational services to pre-create (free/low-cost)
These are commonly needed later and remain within free tier when idle.
1. ECR (Elastic Container Registry):
   - Create a private repo (e.g., `demo/hello-world`). No images pushed yet.
2. S3 for Terraform state (will wire up in section 4):
   - Create an S3 bucket (e.g., `tf-state-<unique-suffix>`). Block public access; enable versioning.
   - Create a DynamoDB table (e.g., `tf-locks`) with partition key `LockID` (String) for state locking.
3. CloudWatch Logs retention (optional): set default retention for new log groups (e.g., 7–30 days) to avoid unbounded storage.
4. Default VPC: keep as-is for quick-start (we can move to dedicated VPC later if needed).

### Validate sign-in and SSO CLI flow (no host mutation yet)
We will use containerized tooling for CLI later, but validate the web SSO works now:
1. From the AWS access portal URL, sign in as your IAM Identity Center user and confirm you can assume the sandbox account with `AdministratorAccess-Sandbox`.
2. Ensure MFA is enforced during sign-in.

### Cost hygiene checklist
- Budgets and free-tier alerts active
- Cost Explorer and Anomaly Detection enabled
- Root MFA enabled; daily use via SSO user only
- No always-on paid services created

## 3) AWS local access (CLI/credentials)
For the interview setup, we'll create a dedicated IAM user with programmatic access keys. This is simpler and more reliable than SSO for containerized workflows.

### Create an IAM user for CLI access
1. AWS Console → IAM → Users → Create user
   - User name: `terraform-ci` 
   - Access type: Programmatic access (create access key)
   - Permissions: attach AWS managed `AdministratorAccess` (sandbox only)
2. On the "Retrieve access keys" step, securely store both values:
   - Access key ID: `AKIA...`
   - Secret access key: `wJalrXU...`

### Containerized AWS CLI with access keys (no host installs)
We'll mount the AWS config to the container user's home directory using a generic approach.

```bash
# Configure credentials (interactive) - works with any container user
podman run --rm -it \
  -v "$HOME/.aws:/root/.aws" \
  --entrypoint sh \
  amazon/aws-cli:latest -lc "aws configure"

# When prompted, enter:
# - Access key ID: YOUR_ACCESS_KEY_ID
# - Secret access key: YOUR_SECRET_ACCESS_KEY
# - Region: ap-south-1
# - Output format: json

# Verify the identity - generic mount
podman run --rm \
  -v "$HOME/.aws:/root/.aws" \
  amazon/aws-cli:latest \
  sts get-caller-identity
```

### Usage pattern
- All AWS commands use the generic mounted credentials:

```bash
# Run AWS commands - works with any container user
podman run --rm \
  -v "$HOME/.aws:/root/.aws" \
  amazon/aws-cli:latest \
  s3 ls

# Terraform will use the same mount pattern (added in section 4)
```

### Security notes
- These keys are for interview/demo purposes only
- Delete the IAM user and keys when finished
- For production, use least-privilege policies and rotate keys regularly

## 4) Hello World Application
Simple Python microservice with health endpoints for the interview demo.

### Application Structure
```
quickapp/
├── app.py              # Flask application with health endpoints
├── requirements.txt    # Python dependencies
├── Dockerfile         # Container configuration
└── .dockerignore      # Docker ignore patterns
```

### Application Features
- **Health endpoints**: `/health` and `/ready` for load balancers
- **Main endpoint**: `/` returns hello world message
- **Containerized**: Ready for ECR and App Runner deployment
- **Security**: Non-root user, health checks, proper timeouts

### Test locally
```bash
cd quickapp

# Build and run locally
podman build -t hello-world:local .
podman run --rm -p 8080:8080 hello-world:local

# Test endpoints
curl http://localhost:8080/
curl http://localhost:8080/health
curl http://localhost:8080/ready
```

## 5) Terraform Infrastructure
For the interview demo, we'll use local state files to avoid AWS costs. This is perfectly valid for development and demo purposes.

### Containerized Terraform setup (no host installs)
We'll use a Terraform container with your AWS credentials and local state files.

```bash
# Navigate to terraform directory
cd terraform

# Initialize Terraform (downloads providers)
podman run --rm \
  -v "$(pwd):/workspace" \
  -v "$HOME/.aws:/root/.aws" \
  -w /workspace \
  hashicorp/terraform:latest \
  init

# Plan infrastructure (shows what will be created)
podman run --rm \
  -v "$(pwd):/workspace" \
  -v "$HOME/.aws:/root/.aws" \
  -w /workspace \
  hashicorp/terraform:latest \
  plan

# Apply infrastructure (creates ECR repository)
podman run --rm \
  -v "$(pwd):/workspace" \
  -v "$HOME/.aws:/root/.aws" \
  -w /workspace \
  hashicorp/terraform:latest \
  apply -auto-approve

# Show outputs (ECR repository URL)
podman run --rm \
  -v "$(pwd):/workspace" \
  -v "$HOME/.aws:/root/.aws" \
  -w /workspace \
  hashicorp/terraform:latest \
  output
```

### Infrastructure Created
- **ECR Repository**: `hello-world` with lifecycle policies
- **Image Scanning**: Enabled for security
- **Cost Optimization**: Lifecycle rules to clean up old images

### Local state benefits
- ✅ No AWS costs for S3/DynamoDB
- ✅ Simple setup for demo
- ✅ State files stored in your project directory
- ✅ Easy to share/backup for interview

## 6) App Runner Deployment
Deploy the application using AWS App Runner, a fully managed service for containerized applications.

### Push Container Image to ECR
```bash
# Build the image for AMD64 architecture (for AWS App Runner compatibility)
cd quickapp
podman build --platform linux/amd64 -t hello-world:latest .

# Tag the image for ECR
podman tag hello-world:latest $(terraform output -raw ecr_repository_url):latest

# Login to ECR
aws ecr get-login-password --region ap-south-1 | podman login --username AWS --password-stdin $(terraform output -raw ecr_repository_url)

# Push the image
podman push $(terraform output -raw ecr_repository_url):latest
```

### Deploy with App Runner using Terraform
```bash
# Apply the App Runner configuration
podman run --rm \
  -v "$(pwd):/workspace" \
  -v "$HOME/.aws:/root/.aws" \
  -w /workspace \
  hashicorp/terraform:latest \
  apply -auto-approve

# Get the App Runner service URL
podman run --rm \
  -v "$(pwd):/workspace" \
  -v "$HOME/.aws:/root/.aws" \
  -w /workspace \
  hashicorp/terraform:latest \
  output app_runner_service_url
```

### App Runner Features
- **Fully Managed**: No infrastructure to manage
- **Auto Scaling**: Automatically scales based on traffic
- **HTTPS Endpoints**: Automatic SSL/TLS certificates
- **Health Checks**: Built-in health monitoring
- **Cost Effective**: Pay only for what you use
- **Logging**: Integrated with CloudWatch Logs

### Infrastructure Created
- **IAM Roles**: Service and instance roles for App Runner
- **App Runner Service**: Running your containerized application
- **Auto Deployments**: Enabled for continuous deployment
- **Health Checks**: Configured to use your `/health` endpoint

## 7) Jenkins CI/CD Pipeline
Setting up Jenkins using containers to automate the build and deployment process.

### Container Setup
```bash
# Create directories for Jenkins data
mkdir -p jenkins/data
chmod 777 jenkins/data  # Ensure Jenkins can write to the directory

# Create a network for Jenkins and its agents
podman network create jenkins

# Start Jenkins container
podman run --name jenkins --restart=unless-stopped \
  --detach \
  --network jenkins \
  --env JENKINS_OPTS="--httpPort=8081" \
  --env JAVA_OPTS="-Xmx512m -Dhudson.footerURL=https://github.com/your-repo" \
  -v "$(pwd)/jenkins/data:/var/jenkins_home" \
  -v "$HOME/.aws:/root/.aws" \
  -v "/var/run/docker.sock:/var/run/docker.sock" \
  -p 8081:8081 \
  -p 50000:50000 \
  jenkins/jenkins:lts

# Get the initial admin password
podman exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

### Access Jenkins
1. Open `http://localhost:8081` in your browser
2. Enter the initial admin password from above
3. Install suggested plugins
4. Create first admin user
5. Configure Jenkins URL

### Required Plugins
Install these plugins via Manage Jenkins → Plugins:
- AWS Pipeline Steps
- Docker Pipeline
- Pipeline
- Git
- GitHub Integration
- Terraform

### Configure Credentials
1. Add AWS credentials:
   - Kind: AWS Credentials
   - ID: `aws-credentials`
   - Access Key ID and Secret Access Key from earlier setup

2. Add GitHub credentials (if using private repo):
   - Kind: Username with password
   - ID: `github-credentials`

### Create Pipeline
1. New Item → Pipeline
2. Configure Pipeline:
   - Name: `hello-world-pipeline`
   - Pipeline script from SCM
   - SCM: Git
   - Repository URL: Your repository URL
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`

### Pipeline Configuration
Create `Jenkinsfile` in your repository:
```groovy
pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'ap-south-1'
        ECR_REPO = '385143640720.dkr.ecr.ap-south-1.amazonaws.com/hello-world'
        APP_NAME = 'hello-world'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Image') {
            steps {
                script {
                    sh """
                        cd quickapp
                        podman build --platform linux/amd64 -t ${APP_NAME}:${BUILD_NUMBER} .
                        podman tag ${APP_NAME}:${BUILD_NUMBER} ${ECR_REPO}:${BUILD_NUMBER}
                        podman tag ${APP_NAME}:${BUILD_NUMBER} ${ECR_REPO}:latest
                    """
                }
            }
        }

        stage('Push to ECR') {
            steps {
                withAWS(credentials: 'aws-credentials', region: env.AWS_DEFAULT_REGION) {
                    sh """
                        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | podman login --username AWS --password-stdin ${ECR_REPO}
                        podman push ${ECR_REPO}:${BUILD_NUMBER}
                        podman push ${ECR_REPO}:latest
                    """
                }
            }
        }

        stage('Deploy with Terraform') {
            steps {
                withAWS(credentials: 'aws-credentials', region: env.AWS_DEFAULT_REGION) {
                    sh """
                        cd terraform
                        terraform init
                        terraform apply -auto-approve
                    """
                }
            }
        }
    }

    post {
        always {
            sh """
                podman rmi ${APP_NAME}:${BUILD_NUMBER} || true
                podman rmi ${ECR_REPO}:${BUILD_NUMBER} || true
                podman rmi ${ECR_REPO}:latest || true
            """
        }
    }
}
