pipeline {
    agent any

    environment {
        APP_NAME = 'hello-world'
        AWS_DEFAULT_REGION = 'ap-south-1'
        WORKSPACE_DIR = '/Users/gafoorraja/Work/demo'
        PATH = "/opt/homebrew/bin:${env.PATH}"
    }

    stages {
        stage('Setup Infrastructure') {
            steps {
                withAWS(credentials: 'aws-credentials', region: env.AWS_DEFAULT_REGION) {
                    sh '''
                        cd ${WORKSPACE_DIR}/terraform
                        terraform init -input=false
                        terraform plan -out=tfplan
                        terraform apply -auto-approve tfplan
                        
                        # Get ECR repository URL
                        echo "ECR_REPO=$(terraform output -raw ecr_repository_url)" > /tmp/ecr_info.env
                        echo "APP_RUNNER_URL=$(terraform output -raw app_runner_service_url)" > /tmp/app_runner_info.env
                    '''
                }
            }
        }

        stage('Build Image') {
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
                podman rmi ${APP_NAME}:${BUILD_NUMBER} || true
                podman rmi ${ECR_REPO}:${BUILD_NUMBER} || true
                podman rmi ${ECR_REPO}:latest || true
            '''
        }
        success {
            script {
                if (env.APP_RUNNER_URL) {
                    echo "✓ Deployment successful!"
                    echo "Application URL: https://${env.APP_RUNNER_URL}"
                }
            }
        }
    }
}
