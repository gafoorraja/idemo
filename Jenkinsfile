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
                    sh '''
                        cd quickapp
                        podman build --platform linux/amd64 -t ${APP_NAME}:${BUILD_NUMBER} .
                        podman tag ${APP_NAME}:${BUILD_NUMBER} ${ECR_REPO}:${BUILD_NUMBER}
                        podman tag ${APP_NAME}:${BUILD_NUMBER} ${ECR_REPO}:latest
                    '''
                }
            }
        }

        stage('Push to ECR') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                        export AWS_DEFAULT_REGION=ap-south-1
                        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | podman login --username AWS --password-stdin 385143640720.dkr.ecr.ap-south-1.amazonaws.com
                        podman push ${ECR_REPO}:${BUILD_NUMBER}
                        podman push ${ECR_REPO}:latest
                    '''
                }
            }
        }

        stage('Deploy with Terraform') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                        export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                        export AWS_DEFAULT_REGION=ap-south-1
                        cd terraform
                        terraform init -input=false
                        terraform apply -auto-approve
                    '''
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
    }
}