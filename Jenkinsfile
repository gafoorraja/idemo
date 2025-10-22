pipeline {
    agent any

    environment {
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
                        mkdir -p ${HOME}/.local/share/containers
                        podman build --format docker --platform linux/amd64 -t ${APP_NAME}:${BUILD_NUMBER} .
                    '''
                }
            }
        }
    }

    post {
        always {
            sh '''
                podman rmi ${APP_NAME}:${BUILD_NUMBER} || true
            '''
        }
    }
}