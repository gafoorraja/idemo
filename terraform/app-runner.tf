# IAM role for App Runner to access ECR
resource "aws_iam_role" "app_runner_service_role" {
  name = "app-runner-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
      }
    ]
  })
}

# Attach necessary policies to the role
resource "aws_iam_role_policy_attachment" "app_runner_service_role_policy" {
  role       = aws_iam_role.app_runner_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# Create App Runner access role
resource "aws_iam_role" "app_runner_access_role" {
  name = "app-runner-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "tasks.apprunner.amazonaws.com",
            "build.apprunner.amazonaws.com"
          ]
        }
      }
    ]
  })
}

# Allow App Runner to pull from ECR
resource "aws_iam_role_policy" "app_runner_ecr_policy" {
  name = "app-runner-ecr-policy"
  role = aws_iam_role.app_runner_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeImages"
        ]
        Resource = aws_ecr_repository.hello_world.arn
      }
    ]
  })
}

# App Runner service
resource "aws_apprunner_service" "hello_world" {
  service_name = "hello-world-service"

  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.app_runner_access_role.arn
    }

    image_repository {
      image_configuration {
        port = "8080"  # Port your application listens on
        runtime_environment_variables = {
          "ENV" = var.environment
        }
      }
      image_identifier      = "${aws_ecr_repository.hello_world.repository_url}:latest"
      image_repository_type = "ECR"
    }

    auto_deployments_enabled = true
  }

  instance_configuration {
    cpu    = "1024"  # 1 vCPU
    memory = "2048"  # 2 GB

    instance_role_arn = aws_iam_role.app_runner_instance_role.arn
  }

  health_check_configuration {
    path                = "/health"  # Your health check endpoint
    protocol            = "HTTP"
    healthy_threshold   = 2
    interval            = 5
    timeout             = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "hello-world-service"
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.app_runner_service_role_policy
  ]
}

# IAM role for App Runner service instance
resource "aws_iam_role" "app_runner_instance_role" {
  name = "app-runner-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "tasks.apprunner.amazonaws.com"
        }
      }
    ]
  })
}

# Basic execution policy for the instance role
resource "aws_iam_role_policy_attachment" "app_runner_instance_role_policy" {
  role       = aws_iam_role.app_runner_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}