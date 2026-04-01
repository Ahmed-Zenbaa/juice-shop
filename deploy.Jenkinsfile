pipeline {
    agent any

    environment {
        SONARQUBE = 'sonarqube'
        DOCKER_IMAGE = credentials('devsecops-demo-image')
        DOCKER_TAG = "v1.${BUILD_NUMBER}"
        NVD_API_KEY = credentials('nvd-api-key')
        TARGET_IP = credentials('app-dast-target-ip')
        DEFECTDOJO_API_TOKEN = credentials('defectdojo-api-token')
    }

    stages {             

        stage('Infrastructure Deploy') {
            steps {
                script {
                    sh 'echo "Running Terraform Apply Commands..."'
                }
            }
        }
        
        stage('K8s Deploy') {
            steps {
                withKubeConfig(credentialsId: 'jenkins-kubeconfig') {
                    sh """
                        kubectl set image deployments.apps/juice-shop juice-shop=${DOCKER_IMAGE}:${DOCKER_TAG}
                        kubectl rollout status deployments.apps/juice-shop
                    """
                }
            }
        }

        stage('DAST - OWASP ZAP') {
            steps {
                script{
                    sh 'sleep 60'
                    sh 'docker run --rm --add-host juice.shop.internal:$TARGET_IP -v $(pwd):/zap/wrk:rw -t zaproxy/zap-stable:2.17.0 zap-full-scan.py -t http://juice.shop.internal -a -r zap-report.html -x zap-report.xml || true '
                }    
            }
        }
        
    }
    post {
        always {
            // Archive whatever files are present, even if some are missing
            script {
                def files = [
                    'gitleaks-report.json',
                    'detect-secrets-report.json',
                    'checkov-secret-report.json',
                    'semgrep-report.json',
                    'npm-audit-report.json',
                    'dependency-check-report.html',
                    'dependency-check-report.xml',
                    'hadolint-report.txt',
                    'hadolint-insecure-report.txt',
                    'checkov-dockerfile-report.json',
                    'checkov-dockerfile-insecure-report.json',
                    'conftest-report.txt',
                    'conftest-insecure-report.txt',
                    'trivy-image-report.json',
                    'grype-report.json',
                    'trivy-iac-report.json',
                    'checkov-iac-report.json',
                    'zap-report.html',
                    'zap-report.xml'
                ]

                def existingFiles = files.findAll { file -> fileExists(file) }

                if (existingFiles) {
                    archiveArtifacts artifacts: existingFiles.join(', '), fingerprint: true
                } else {
                    echo "No artifacts found to archive."
                }
            }
            
            echo "Uploading some artifacts to Defectdojo..."
            sh '''
            #!/bin/bash
            export DEFECTDOJO_API_TOKEN="$DEFECTDOJO_API_TOKEN"
            python3 -m venv venv
            source venv/bin/activate
            pip install --upgrade pip
            pip install requests
            python3 defectdojo-upload.py
            deactivate
            '''
            
            echo "Pipeline finished (success/failure). Cleaning up workspace..."
            cleanWs()
        }
    }
}
