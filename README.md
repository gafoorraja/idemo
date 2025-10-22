# AWS CI/CD Demo - Hello World Microservice

This project demonstrates a complete CI/CD pipeline for deploying a containerized Python microservice to AWS App Runner using Jenkins, Terraform, and Podman on macOS.

## 🎯 Project Overview

**Goal**: Automated deployment of a "Hello World" microservice from code commit to production on AWS.

**Tech Stack**:
- **Application**: Python Flask microservice
- **Containerization**: Podman (Docker-compatible)
- **Infrastructure as Code**: Terraform
- **CI/CD**: Jenkins (local installation via Homebrew)
- **Cloud Provider**: AWS (ECR + App Runner)
- **Platform**: macOS Apple Silicon

## 📁 Project Structure

```
.
├── quickapp/              # Python Flask application
│   ├── app.py            # Main application with health endpoints
│   ├── Dockerfile        # Container configuration
│   └── requirements.txt  # Python dependencies
├── terraform/            # Infrastructure as Code
│   ├── main.tf          # Provider and ECR configuration
│   ├── app-runner.tf    # App Runner service and IAM roles
│   ├── variables.tf     # Input variables
│   └── outputs.tf       # Output values (ECR URL, App Runner URL)
├── Jenkinsfile          # CI/CD pipeline definition
└── README.md           # This file
```

## 🚀 Quick Start

### Prerequisites

1. **macOS with Homebrew installed**
2. **Podman installed and running**:
   ```bash
   brew install podman
   podman machine init --cpus 4 --memory 4096 --disk-size 20
   podman machine start
   ```

3. **Jenkins installed via Homebrew**:
   ```bash
   brew install jenkins-lts
   brew services start jenkins-lts
   # Access at http://localhost:8080
   ```

4. **AWS Account with IAM user credentials**:
   - Create IAM user with `AdministratorAccess` (for demo)
   - Configure credentials in `~/.aws/credentials`
   - Region: `ap-south-1` (Mumbai)

5. **Terraform and AWS CLI installed**:
   ```bash
   brew install terraform awscli
   ```

### Initial Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/gafoorraja/idemo.git
   cd idemo
   ```

2. **Configure Jenkins**:
   - Access Jenkins at `http://localhost:8080`
   - Install required plugins: "Pipeline: AWS Steps", "Git", "GitHub Integration"
   - Add AWS credentials (Manage Jenkins → Credentials):
     - Kind: `AWS Credentials`
     - ID: `aws-credentials`
     - Add your AWS Access Key ID and Secret Access Key

3. **Create Jenkins Pipeline Job**:
   - New Item → Pipeline
   - Name: `hello-world-pipeline`
   - Pipeline Definition: "Pipeline script from SCM"
   - SCM: Git
   - Repository URL: `https://github.com/gafoorraja/idemo.git`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`

4. **Run the Pipeline**:
   - Click "Build Now"
   - Jenkins will:
     1. Create ECR repository and App Runner service (via Terraform)
     2. Build the Docker image
     3. Push to ECR
     4. Deploy to App Runner (automatic deployment enabled)

5. **Access Your Application**:
   - Get the App Runner URL from Jenkins console output
   - Visit `https://<your-app-runner-url>/`

## 🏗️ Architecture

```
GitHub Repository
    ↓
Jenkins (Local on macOS)
    ↓
[Stage 1] Terraform → Creates AWS Infrastructure
    ├── ECR Repository (hello-world)
    ├── App Runner Service
    └── IAM Roles & Policies
    ↓
[Stage 2] Build Docker Image (Podman)
    ↓
[Stage 3] Push to ECR
    ↓
[Stage 4] App Runner Auto-Deploy
    └── Live Application (HTTPS)
```

## 🔄 CI/CD Pipeline Stages

The `Jenkinsfile` defines a 4-stage pipeline:

1. **Setup Infrastructure**: 
   - Runs Terraform to create/update ECR and App Runner
   - Uses local state file in `/Users/gafoorraja/Work/demo/terraform`

2. **Build Image**: 
   - Builds Docker image using Podman
   - Tags with build number and `latest`

3. **Push to ECR**: 
   - Authenticates to AWS ECR
   - Pushes both tagged images

4. **Deploy to App Runner**: 
   - App Runner auto-deploys latest image (configured via Terraform)
   - Waits and verifies deployment status

## 🏃 Local Development & Testing

### Test Application Locally

```bash
cd quickapp
podman build -t hello-world:local .
podman run --rm -p 8080:8080 hello-world:local

# Test endpoints
curl http://localhost:8080/          # Hello World
curl http://localhost:8080/health    # Health check
curl http://localhost:8080/ready     # Readiness check
```

### Test Terraform Locally

```bash
cd terraform
terraform init
terraform plan      # Preview changes
terraform apply     # Apply changes
terraform output    # View outputs (ECR URL, App Runner URL)
```

## 🔧 Jenkins Configuration Details

**Environment Variables** (set in Jenkinsfile):
- `APP_NAME`: hello-world
- `AWS_DEFAULT_REGION`: ap-south-1
- `WORKSPACE_DIR`: /Users/gafoorraja/Work/demo
- `PATH`: Includes `/opt/homebrew/bin` for Terraform, Podman, AWS CLI

**Key Features**:
- Works directly with local files (no GitHub checkout needed in demo)
- Terraform state managed locally in project directory
- Automatic cleanup of Docker images after build

## 📊 AWS Resources Created

### ECR Repository
- **Name**: hello-world
- **Features**: Image scanning, lifecycle policies
- **Lifecycle Rules**:
  - Keep last 10 tagged images
  - Delete untagged images after 1 day

### App Runner Service
- **Name**: hello-world-service
- **Configuration**: 1 vCPU, 2GB RAM
- **Features**:
  - Auto-deployments enabled
  - Health checks on `/health` endpoint
  - Automatic HTTPS with AWS certificate
  - Auto-scaling based on traffic
  - Integrated CloudWatch logging

### IAM Roles
- App Runner service role (ECR access)
- App Runner access role (image pull)
- App Runner instance role (runtime permissions)

## 🎓 Production-Grade Improvements

This section covers what would be needed to make this production-ready (excellent for 90-minute interview discussion).

### 1. Infrastructure & Architecture

**Current State**: Single region, no redundancy
**Production Improvements**:
- Multi-region deployment for disaster recovery
- Blue-green or canary deployment strategy
- Infrastructure deployed across multiple AWS accounts (dev/staging/prod)
- VPC with private subnets for App Runner
- AWS WAF for DDoS protection and rate limiting
- CloudFront CDN in front of App Runner for better performance
- Route53 with health checks and automatic failover

**Terraform State Management**:
- Move from local state to S3 backend with DynamoDB locking
- Separate state files per environment (dev/staging/prod)
- State file encryption at rest
- State file versioning enabled
- Terraform workspaces for environment isolation

```hcl
# Example production backend config
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "app-runner/hello-world/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"
    kms_key_id     = "arn:aws:kms:ap-south-1:xxx:key/xxx"
  }
}
```

**Infrastructure as Code Best Practices**:
- Terraform modules for reusability (ECR module, App Runner module)
- Separate repos for infrastructure and application code
- Terraform Cloud or Terraform Enterprise for team collaboration
- Policy as Code using Sentinel or OPA
- Cost estimation integrated into CI/CD (Infracost)

### 2. Security & Compliance

**Current State**: Basic IAM roles, public container registry
**Production Improvements**:

**Secrets Management**:
- AWS Secrets Manager or HashiCorp Vault for sensitive data
- Rotate secrets automatically (database passwords, API keys)
- Never store secrets in code or environment variables
- Use IAM roles for services (avoid long-lived credentials)

**Container Security**:
- Image scanning with Trivy, Snyk, or AWS ECR scanning
- Sign container images (Docker Content Trust, Cosign)
- Use minimal base images (distroless, Alpine)
- Run containers as non-root user (already implemented)
- Regular vulnerability scanning and patching

**Network Security**:
- Private VPC with security groups
- AWS PrivateLink for ECR access (no internet required)
- Network ACLs and WAF rules
- DDoS protection via AWS Shield
- VPN or AWS Direct Connect for on-premise connectivity

**Access Control**:
- Implement principle of least privilege
- Use AWS IAM Identity Center (SSO) instead of IAM users
- MFA enforcement for all human access
- Service accounts with minimal permissions
- Regular access reviews and rotation
- Audit logging with AWS CloudTrail

**Compliance**:
- AWS Config for compliance monitoring
- AWS Security Hub for security posture
- Automated compliance checks in CI/CD (Checkov, tfsec)
- Data encryption at rest and in transit
- GDPR/SOC2/HIPAA compliance as needed

### 3. Observability & Monitoring

**Current State**: Basic CloudWatch logs from App Runner
**Production Improvements**:

**Logging**:
- Centralized logging with ELK stack or CloudWatch Logs Insights
- Structured JSON logging for better parsing
- Log retention policies (30-90 days for active, archive to S3)
- Log aggregation across multiple services
- Log-based metrics and alerts

**Metrics & Monitoring**:
- Custom CloudWatch metrics (business metrics, SLIs)
- Prometheus + Grafana for detailed metrics
- Application Performance Monitoring (APM) - New Relic, Datadog, Dynatrace
- Synthetic monitoring for proactive issue detection
- Real User Monitoring (RUM)

**Tracing**:
- Distributed tracing with AWS X-Ray or Jaeger
- Trace requests across microservices
- Performance bottleneck identification

**Alerting**:
- PagerDuty or Opsgenie integration
- Alert fatigue reduction (proper thresholds, deduplication)
- Runbooks for common alerts
- Escalation policies for critical issues

**Dashboards**:
- Real-time operational dashboards
- Business metrics dashboards
- SLA/SLO tracking
- Cost optimization dashboards

### 4. CI/CD Pipeline Enhancements

**Current State**: Basic 4-stage pipeline
**Production Improvements**:

**Pipeline Stages**:
```
1. Code Checkout & Validation
   - Lint code (pylint, flake8)
   - Security scanning (Bandit, Safety)
   - Dependency vulnerability check
   
2. Build & Test
   - Unit tests (pytest) with code coverage (>80%)
   - Integration tests
   - Contract tests
   - Build Docker image
   
3. Security & Quality Gates
   - SAST (Static Application Security Testing)
   - Container image scanning
   - License compliance check
   - Code quality gates (SonarQube)
   
4. Push Artifacts
   - Push to ECR with immutable tags
   - Sign image
   - Generate SBOM (Software Bill of Materials)
   
5. Deploy to Dev
   - Deploy via Terraform
   - Smoke tests
   
6. Integration Tests
   - API tests
   - End-to-end tests
   - Performance tests
   
7. Deploy to Staging
   - Blue-green deployment
   - Automated acceptance tests
   
8. Manual Approval Gate
   - Required for production
   
9. Deploy to Production
   - Canary deployment (5% → 25% → 100%)
   - Automated rollback on failure
   
10. Post-Deployment
    - Health checks
    - Synthetic monitoring
    - Notification to Slack/Teams
```

**Pipeline Best Practices**:
- Separate Jenkins for production (dedicated infrastructure)
- Pipeline as Code (Jenkinsfile in repo)
- Parallel execution where possible
- Artifact promotion (not rebuild)
- Immutable artifacts with semantic versioning
- GitOps approach (ArgoCD, Flux)
- Pipeline metrics and analytics

**Testing Strategy**:
- Unit tests: 80%+ code coverage
- Integration tests: API contracts
- E2E tests: Critical user journeys
- Performance tests: Load testing with k6 or JMeter
- Security tests: OWASP ZAP, penetration testing
- Chaos engineering: Failure injection tests

### 5. Deployment Strategies

**Current State**: Direct deployment with auto-deploy
**Production Options**:

**Blue-Green Deployment**:
- Run two identical environments (blue = current, green = new)
- Switch traffic instantly via DNS/load balancer
- Easy rollback
- Higher cost (double infrastructure)

**Canary Deployment**:
- Gradually shift traffic (5% → 25% → 50% → 100%)
- Monitor metrics at each stage
- Automatic rollback on error rate increase
- AWS App Runner native support or ALB weighted targets

**Rolling Deployment**:
- Update instances gradually
- No downtime
- Slower rollback
- Good for stateless apps

**Feature Flags**:
- LaunchDarkly, Split.io, or custom solution
- Deploy code without activating features
- A/B testing capabilities
- Instant rollback without redeployment

### 6. Scaling Considerations

**Current State**: App Runner auto-scales (basic)
**Production Improvements**:

**Horizontal Scaling**:
- App Runner auto-scaling configuration (min/max instances)
- Proper metrics for scaling (CPU, memory, request count, custom metrics)
- Scale-up fast, scale-down slow (avoid thrashing)
- Scheduled scaling for predictable traffic

**Database Scaling**:
- RDS with read replicas
- Aurora Serverless for variable workloads
- Database connection pooling
- Caching layer (Redis, Memcached)
- DynamoDB with on-demand or provisioned capacity

**Performance Optimization**:
- CDN for static assets (CloudFront)
- API Gateway caching
- Application-level caching
- Database query optimization
- Asynchronous processing (SQS, SNS)

**Global Scale**:
- Multi-region deployment
- Global Accelerator for traffic routing
- Edge computing (Lambda@Edge)
- Data replication strategy

### 7. Cost Optimization

**Current State**: Pay-as-you-go with no optimization
**Production Strategies**:

**Compute Optimization**:
- Right-sizing instances based on metrics
- Spot instances for non-critical workloads
- Savings Plans or Reserved Instances for steady-state
- Auto-scaling policies to match demand
- Serverless for sporadic workloads

**Storage Optimization**:
- S3 lifecycle policies (Glacier for archives)
- ECR lifecycle policies (already implemented)
- EBS volume optimization (gp3 vs gp2)
- Data deduplication and compression

**Monitoring & Optimization**:
- AWS Cost Explorer and Budgets
- Third-party tools (CloudHealth, Cloudability)
- Tagging strategy for cost allocation
- Regular cost reviews and optimization sprints
- Show-back/charge-back to teams

### 8. Disaster Recovery & Business Continuity

**Current State**: No DR plan
**Production Requirements**:

**Backup Strategy**:
- Automated backups (RDS, EBS snapshots)
- Cross-region replication
- Point-in-time recovery
- Backup retention policy (30-90 days)
- Regular backup restoration testing

**Disaster Recovery**:
- RTO (Recovery Time Objective): < 1 hour
- RPO (Recovery Point Objective): < 5 minutes
- DR site in different region
- Regular DR drills (quarterly)
- Documented runbooks

**High Availability**:
- Multi-AZ deployment
- Health checks and auto-healing
- Circuit breakers and retries
- Rate limiting and throttling
- Graceful degradation

### 9. Governance & Operations

**Organizational Structure**:
- Clear ownership (RACI matrix)
- On-call rotation
- Incident management process
- Post-mortem culture (blameless)
- SLA/SLO definitions

**Documentation**:
- Architecture Decision Records (ADRs)
- API documentation (OpenAPI/Swagger)
- Runbooks for common operations
- Disaster recovery procedures
- Onboarding documentation

**Change Management**:
- Change Advisory Board (CAB) for major changes
- Deployment windows for production
- Feature flag strategy
- Gradual rollouts with monitoring

**Compliance & Audit**:
- Regular security audits
- Penetration testing
- Compliance certifications (SOC2, ISO 27001)
- Audit trail of all changes
- Data residency compliance

### 10. Migration Path: Local Jenkins → Production Jenkins

**Current**: Jenkins running locally on macOS via Homebrew

**Production Options**:

**Option A: Jenkins on EC2**:
- Auto-scaling group for HA
- EBS volumes for persistence
- Application Load Balancer
- CloudWatch monitoring

**Option B: Jenkins on ECS/Fargate**:
- Containerized Jenkins
- EFS for shared storage
- Spot instances for agents
- Cost-effective for variable workloads

**Option C: Managed Solutions**:
- CloudBees CI (Enterprise Jenkins)
- AWS CodePipeline + CodeBuild
- GitHub Actions
- GitLab CI/CD
- CircleCI, Travis CI

**Jenkins Production Best Practices**:
- Dedicated Jenkins controllers and agents
- Immutable agents (containers)
- Pipeline library for shared code
- Credentials plugin with HashiCorp Vault
- Blue Ocean UI for better visualization
- Backup strategy for jobs and configuration

### 11. Alternative Architectures to Consider

**Kubernetes-based** (for more control):
- EKS (Elastic Kubernetes Service)
- Helm charts for application deployment
- Istio/Linkerd for service mesh
- ArgoCD for GitOps
- More complex but more flexible

**Serverless** (for cost optimization):
- AWS Lambda + API Gateway
- DynamoDB for state
- S3 for static assets
- EventBridge for event-driven architecture
- Significantly lower cost for sporadic traffic

**Hybrid Approach**:
- App Runner for main application
- Lambda for background jobs
- SQS/SNS for async processing
- Step Functions for workflows

## 🎤 Interview Discussion Topics

Based on the 90-minute format, here are key talking points:

### First 30 Minutes: Current Setup Walkthrough
1. Architecture overview and design decisions
2. Why App Runner vs ECS/EKS/Lambda?
3. Local vs cloud Jenkins trade-offs
4. Terraform state management approach
5. CI/CD pipeline stages explanation

### Middle 30 Minutes: Production Readiness
1. Security improvements needed
2. Observability strategy
3. Deployment strategies (blue-green, canary)
4. Scaling considerations
5. Cost optimization approaches

### Final 30 Minutes: Scale & Advanced Topics
1. Multi-region deployment strategy
2. Disaster recovery plan
3. Microservices architecture considerations
4. Team structure and ownership model
5. Migration from monolith to microservices

### Key Strengths to Highlight
✅ Working end-to-end pipeline (from commit to production)
✅ Infrastructure as Code (reproducible)
✅ Container-based (portable)
✅ Automated deployment (no manual steps)
✅ Health checks and monitoring basics

### Areas for Discussion (Be Honest)
⚠️ Local state file (not production-ready)
⚠️ No automated testing in pipeline
⚠️ Single region deployment
⚠️ Basic security (no secrets management)
⚠️ Limited observability

**Pro Tip**: Frame these as "next steps" or "in production, I would..." to show awareness of production requirements.

## 🧹 Cleanup

To avoid AWS charges after the interview:

```bash
# Destroy all AWS resources
cd terraform
terraform destroy -auto-approve

# Stop Jenkins
brew services stop jenkins-lts

# Stop Podman machine
podman machine stop
```

## 📚 Additional Resources

- [AWS App Runner Documentation](https://docs.aws.amazon.com/apprunner/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [Podman Documentation](https://docs.podman.io/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

## 📝 Notes

- **Cost**: This setup uses AWS Free Tier eligible services where possible. App Runner charges are ~$0.0008/GB-hour for idle and $0.064/vCPU-hour + $0.007/GB-hour when active.
- **Region**: Using `ap-south-1` (Mumbai) - adjust in `terraform/variables.tf` if needed
- **State**: Terraform state is stored locally for demo purposes. Production should use S3 backend.

---

**Good luck with your interview! 🚀**


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
