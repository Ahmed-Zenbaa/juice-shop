pipeline {
    agent any

    environment {
        SONARQUBE = 'sonarqube'
        DOCKER_IMAGE = 'docker.io/ahmedzenbaa/devsecops-demo'
        DOCKER_TAG = "v1.${BUILD_NUMBER}"
    }

    stages {

        stage ('Secrets Scan') {
            parallel {
                stage('Gitleaks') {
                   steps { 
                       sh 'gitleaks detect --source . --no-git --report-format json --report-path gitleaks-report.json || true' 
                   }
                }
                stage('Detect Secrets') {
                   steps { 
                       sh 'docker run --rm -v $(pwd):/wrk:rw -w /wrk python:3.11-alpine sh -c \'pip install detect-secrets && ls && detect-secrets scan --all-files | tee detect-secrets-report.json\''
                   }
                }
            }
        }
        
        stage ('SAST') {
            parallel {
                stage('semgrep') {
                    steps {
                        sh 'semgrep --config p/nodejsscan --config p/javascript --config p/owasp-top-ten --config p/secrets --json . > semgrep-report.json'
                    }
                }
                stage('Sonarqube') {
                    steps {
                        withSonarQubeEnv("${env.SONARQUBE}") {
                            sh '''
                                sonar-scanner \
                                  -Dsonar.projectKey=devsecops \
                                  -Dsonar.projectName="DevSecOps" \
                                  -Dsonar.projectVersion=1.0 \
                                  -Dsonar.sources=. \
                                  -Dsonar.exclusions=**/node_modules/**,**/venv/** \
                                  -Dsonar.host.url=$SONAR_HOST_URL \
                                  -Dsonar.login=$SONAR_AUTH_TOKEN
                            '''
                        }
                    }
                }
            }
        }

        stage('Sonarqube Quality Gate') {
          steps {
            timeout(time: 5, unit: 'MINUTES') {
            script {
                    def qualityGate = waitForQualityGate()
                    if (qualityGate.status != 'OK') {
                         echo "Quality Gate failed with status: ${qualityGate.status}. Skipping failure as per configuration."
                      } else {
                         echo "Quality Gate passed."
                     }
                   }
               }
            }
        }

        stage ('SCA') {
            parallel {
                stage('NPM Audit') {
                    steps {
                        sh 'npm audit --audit-level=high > npm-audit-report.txt || true'
                    }
                }

                stage('OWASP Dependency Check') {
                    steps {
                        sh 'dependency-check.sh --project "devsecops-demo" --scan . --format "HTML,JSON" --out dependency-check-report --failOnCVSS 7 || true'
                    }
                }                
            }
        }

        stage ('Validate Dockerfile') {
            parallel {
                stage('Hadolint') {
                    steps {
                        script{
                            sh 'hadolint Dockerfile || true'
                            sh 'hadolint Dockerfile-insecure || true'
                        }    
                    }
                }
                stage('Conftest') {
                    steps {
                        script{
                            sh 'conftest test Dockerfile || true'
                            sh 'conftest test Dockerfile-insecure || true'
                        }    
                    }
                }
            }
        }

        stage('Image Build & Tag') {
            steps {
                script{
                    sh """
                        docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                        docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest
                    """
                }    
            }
        }
        
        stage('Image Scan') {
            steps {
                script{
                    sh 'grype ${DOCKER_IMAGE}:${DOCKER_TAG} -o json --fail-on high > grype-report.json || true'
                }    
            }
        }

        stage('Docker Login & Push') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'docker-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        sh """
                            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" docker.io --password-stdin
                            docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
                            docker push ${DOCKER_IMAGE}:latest
                            docker logout
                        """
                    }
                }
            }
        }
        stage('K8s Deploy') {
            steps {
                withKubeConfig(credentialsId: 'kubeconfig') {
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
                    sh 'docker run --rm --add-host juice.shop.internal:192.168.49.2 -v $(pwd):/zap/wrk:rw -t zaproxy/zap-stable:2.17.0 zap-full-scan.py -t http://juice.shop.internal -a -r zap-report.html || true '
                }    
            }
        }
        // stage('Archive Results') {
        //     steps {
        //          archiveArtifacts artifacts: 'gitleaks-report.json, detect-secrets-report.json, semgrep-report.json, npm-audit-report.txt, grype-report.json, zap-report.html', fingerprint: true

        //     }
        // }
        stage('Archive Results') {
            post {
                always {
                    // Archive whatever files are present, even if some are missing
                    script {
                        def files = [
                            'gitleaks-report.json',
                            'detect-secrets-report.json',
                            'semgrep-report.json',
                            'npm-audit-report.txt',
                            'grype-report.json',
                            'zap-report.html'
                        ]

                        def existingFiles = files.findAll { file -> fileExists(file) }

                        if (existingFiles) {
                            archiveArtifacts artifacts: existingFiles.join(', '), fingerprint: true
                        } else {
                            echo "No artifacts found to archive."
                        }
                    }
                }
            }
        }
        
        stage('Clean UP') {
            post {
                always {
                    cleanWs()
                }
            }
        }
     }     
}
