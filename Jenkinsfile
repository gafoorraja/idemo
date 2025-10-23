pipeline {
    agent any

    parameters {
        choice(name: 'TF_ACTION', choices: ['apply', 'destroy'], description: 'Run Terraform apply (provision/update) or destroy (tear down)')
    }

    environment {
        APP_NAME = 'hello-world'
        AWS_DEFAULT_REGION = 'ap-south-1'
        WORKSPACE_DIR = '/Users/gafoorraja/Work/demo'
        PATH = "/opt/homebrew/bin:${env.PATH}"
        ECR_REPO_NAME = 'hello-world'
    }

    stages {
        stage('Sync Job Parameters') {
            steps {
                script {
                    // Force-create/refresh job parameters so "Build with Parameters" shows up
                    properties([
                        parameters([
                            choice(name: 'TF_ACTION', choices: ['apply', 'destroy'], description: 'Run Terraform apply (provision/update) or destroy (tear down)')
                        ])
                    ])
                }
            }
        }

        stage('Ensure Podman Machine') {
            when {
                expression { params.TF_ACTION == 'apply' }
            }
            steps {
                sh '''
                    set -e
                    echo "Checking Podman machine status..."
                    if ! podman machine list --format json | grep -q '"Running": true'; then
                      echo "Podman machine not running. Starting..."
                      podman machine start
                    else
                      echo "Podman machine is already running."
                    fi
                    podman info | head -n 20 || true
                '''
            }
        }
        stage('Pre-Destroy Cleanup (ECR)') {
            when {
                expression { params.TF_ACTION == 'destroy' }
            }
            steps {
                withAWS(credentials: 'aws-credentials', region: env.AWS_DEFAULT_REGION) {
                    sh '''
                        set -euo pipefail
                        REPO_NAME="${ECR_REPO_NAME}"
                        echo "Preparing to empty ECR repository: ${REPO_NAME} (if it exists)"
                        if aws ecr describe-repositories --repository-names "${REPO_NAME}" >/dev/null 2>&1; then
                          while true; do
                            aws ecr list-images --repository-name "${REPO_NAME}" --query 'imageIds[*]' --output json > /tmp/image_ids.json
                            # If the JSON is an empty array, break
                            if [ "$(tr -d ' \n\r\t' < /tmp/image_ids.json)" = "[]" ]; then
                              echo "ECR repository ${REPO_NAME} already empty."
                              break
                            fi
                            echo "Deleting a batch of images from ${REPO_NAME}..."
                            aws ecr batch-delete-image --repository-name "${REPO_NAME}" --image-ids file:///tmp/image_ids.json || true
                          done
                        else
                          echo "ECR repository ${REPO_NAME} not found. Skipping image cleanup."
                        fi
                    '''
                }
            }
        }

        stage('Setup Infrastructure') {
            steps {
                withAWS(credentials: 'aws-credentials', region: env.AWS_DEFAULT_REGION) {
                    sh '''
                        cd ${WORKSPACE_DIR}/terraform
                        terraform init -input=false
                        if [ "${TF_ACTION}" = "destroy" ]; then
                            echo "Running terraform destroy..."
                            terraform destroy -auto-approve
                        else
                            echo "Running terraform apply..."
                            terraform plan -out=tfplan
                            terraform apply -auto-approve tfplan
                            # Get ECR/App Runner outputs for subsequent stages
                            echo "ECR_REPO=$(terraform output -raw ecr_repository_url)" > /tmp/ecr_info.env
                            echo "APP_RUNNER_URL=$(terraform output -raw app_runner_service_url)" > /tmp/app_runner_info.env
                        fi
                    '''
                }
            }
        }
        
       stage('unit Test case'){
           when {
               expression { params.TF_ACTION == 'apply' }
           }
           steps {
               script {
                   // Run unit tests
                   sh '''
                       cd ${WORKSPACE_DIR}/quickapp
                       pytest > result.log || true
                       tail -n 10 result.log
                   '''
               }
           }
       } 

        stage('Build Image') {
            when {
                expression { params.TF_ACTION == 'apply' }
            }
            steps {
                script {
                    // Load ECR repository URL
                    def ecrInfo = readFile('/tmp/ecr_info.env').trim()
                    env.ECR_REPO = ecrInfo.split('=')[1]
                    
                    sh '''
                        cd ${WORKSPACE_DIR}/quickapp
                        mkdir -p ${HOME}/.local/share/containers
                        podman build --format docker --platform linux/amd64 -t ${APP_NAME}:${BUILD_NUMBER} .
                        podman tag ${APP_NAME}:${BUILD_NUMBER} ${ECR_REPO}:${BUILD_NUMBER}
                        podman tag ${APP_NAME}:${BUILD_NUMBER} ${ECR_REPO}:latest
                    '''
                }
            }
        }

        stage('Push to ECR') {
            when {
                expression { params.TF_ACTION == 'apply' }
            }
            steps {
                withAWS(credentials: 'aws-credentials', region: env.AWS_DEFAULT_REGION) {
                    sh '''
                        # Login to ECR
                        REGISTRY=${ECR_REPO%/*}
                        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | podman login --username AWS --password-stdin ${REGISTRY}
                        
                        # Push images
                        podman push ${ECR_REPO}:${BUILD_NUMBER}
                        podman push ${ECR_REPO}:latest
                    '''
                }
            }
        }

        stage('Deploy to App Runner') {
            when {
                expression { params.TF_ACTION == 'apply' }
            }
            steps {
                script {
                    def appRunnerInfo = readFile('/tmp/app_runner_info.env').trim()
                    env.APP_RUNNER_URL = appRunnerInfo.split('=')[1]
                    
                    echo "Deployment triggered automatically by App Runner"
                    echo "App Runner will pull the latest image from ECR"
                    echo "Application URL: https://${APP_RUNNER_URL}"
                    
                    // Wait for deployment to complete
                    withAWS(credentials: 'aws-credentials', region: env.AWS_DEFAULT_REGION) {
                        sh '''
                            echo "Waiting for App Runner deployment to complete..."
                            sleep 30
                            
                            # Check App Runner service status
                            aws apprunner describe-service \
                                --service-arn $(aws apprunner list-services --query "ServiceSummaryList[?ServiceName=='hello-world-service'].ServiceArn" --output text) \
                                --query "Service.Status" \
                                --output text
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            sh '''
                if [ "${TF_ACTION}" = "apply" ]; then
                  podman rmi ${APP_NAME}:${BUILD_NUMBER} || true
                  if [ -n "${ECR_REPO:-}" ]; then
                    podman rmi ${ECR_REPO}:${BUILD_NUMBER} || true
                    podman rmi ${ECR_REPO}:latest || true
                  fi
                fi
            '''
        }
        success {
            script {
                if (params.TF_ACTION == 'apply' && env.APP_RUNNER_URL) {
                    echo "✓ Deployment successful!"
                    echo "Application URL: https://${env.APP_RUNNER_URL}"
                }
            }
        }
    }
}
