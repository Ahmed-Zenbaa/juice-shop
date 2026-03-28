pipeline {
    agent any

    environment {
        DOCKER_IMAGE = credentials('devsecops-demo-image')
        DOCKER_TAG = "latest"
        NVD_API_KEY = credentials('nvd-api-key')
        TARGET_IP = credentials('app-dast-target-ip')
    }

    stages {             

        stage ('SCA') {
            parallel {
                stage('NPM Audit') {
                    steps {
                        sh 'npm audit --json --audit-level=high > npm-audit-report.json || true'
                    }
                }

                stage('OWASP Dependency Check Stage') {
                    stages {
                        stage('Build') {
                            steps {
                                sh 'docker run --rm -v $(pwd):/wrk:rw -w /wrk node:24-alpine sh -c \'apk add --no-cache git && npm i -g typescript ts-node && npm install --omit=dev\''
                            }
                        }
                        stage('OWASP Dependency Check') {
                            steps {
                                sh '''
                                    docker run -u 0 --rm -e NVD_API_KEY=$NVD_API_KEY -v $(pwd):/wrk -w /wrk owasp/dependency-check:12.2.0 --project "devsecops-demo" --scan . --disableArchive --nvdApiKey $NVD_API_KEY --format "XML" --out /wrk/dependency-check-report --failOnCVSS 7 || true
                                    cp dependency-check-report/dependency-check-report.xml dependency-check-report.xml || true
                                '''
                            }
                        }
                    }
                }                
            }
        }


        stage ('Image Scan') {
            parallel {
                stage('Trivy Image') {
                    steps {
                        script{
                            sh 'docker run --rm -v $(pwd):/wrk -w /wrk aquasec/trivy:0.69.3 image ${DOCKER_IMAGE}:${DOCKER_TAG} -o trivy-image-report.json --severity HIGH,CRITICAL || true'
                        }    
                    }
                }
            }
        }

        stage('DAST - OWASP ZAP') {
            steps {
                script{
                    sh 'sleep 60'
                    sh 'docker run --rm --add-host juice.shop.internal:$TARGET_IP -v $(pwd):/zap/wrk:rw -t zaproxy/zap-stable:2.17.0 zap-full-scan.py -t http://juice.shop.internal -a -x zap-report.xml || true '
                }    
            }
        }
        
    }
    post {
        always {
            // Archive whatever files are present, even if some are missing
            script {
                def files = [
                    'npm-audit-report.json',
                    'dependency-check-report.xml',
                    'trivy-image-report.json',
                    'zap-report.xml'
                ]

                def existingFiles = files.findAll { file -> fileExists(file) }

                if (existingFiles) {
                    archiveArtifacts artifacts: existingFiles.join(', '), fingerprint: true
                } else {
                    echo "No artifacts found to archive."
                }
            }
            echo "Pipeline finished (success/failure). Cleaning up workspace..."
            cleanWs()
        }
    }
}
