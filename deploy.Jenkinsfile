pipeline {
    agent any

    environment {
        SONARQUBE = 'sonarqube'
        DOCKER_IMAGE = credentials('devsecops-demo-image')
        #DOCKER_TAG = "v1.${BUILD_NUMBER}"
        DOCKER_TAG = "v1.13"
        NVD_API_KEY = credentials('nvd-api-key')
        TARGET_IP = credentials('app-dast-target-ip')
        DEFECTDOJO_API_TOKEN = credentials('defectdojo-api-token')
    }

    stages {             
     
        stage ('Image Scan') {
            parallel {
                stage('Trivy Image') {
                    steps {
                        script{
                            sh 'docker run --rm -v $(pwd):/wrk -w /wrk aquasec/trivy:0.69.3 image ${DOCKER_IMAGE}:${DOCKER_TAG} --format json -o trivy-image-report.json || true'
                        }    
                    }
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
            export DEFECTDOJO_API_TOKEN="$DEFECTDOJO_API_TOKEN"
            python3 -m venv venv
            . venv/bin/activate
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
