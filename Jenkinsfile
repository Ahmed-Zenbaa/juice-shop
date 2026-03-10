pipeline {
    agent any

    environment {
        SONARQUBE = 'sonarqube'
        DOCKER_IMAGE = 'docker.io/ahmedzenbaa/devsecops-demo'
        DOCKER_TAG = 'latest'
    }

    stages {

        stage('SAST') {
            steps {
                sh 'semgrep --config p/nodejsscan --config p/javascript --config p/owasp-top-ten --config p/secrets --json . > semgrep-result.json'
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

        stage('Quality Gate') {
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
        stage('Secrets Check') {
           steps { 
               sh 'gitleaks detect --source . --no-git --report-format json --report-path gitleaks-report.json || true'
               
           }
        }

        stage('SCA') {
            steps {
                sh 'npm audit --audit-level=high > audit-result.txt || true'
            }
        }
        stage('Archive Results') {
            steps {
                 archiveArtifacts artifacts: 'semgrep-result.json,gitleaks-report.json,audit-result.txt', fingerprint: true

            }
        }
        
        stage('Validate Dockerfile') {
            steps {
                script{
                    sh 'hadolint Dockerfile || true'
                    sh 'conftest test Dockerfile || true'

                    sh 'hadolint Dockerfile-insecure || true'
                    sh 'conftest test Dockerfile-insecure || true'
                   
                }    
            }
        }
        stage('Build') {
            steps {
                script{
                    sh 'docker build -f Dockerfile-insecure -t ${DOCKER_IMAGE}:${DOCKER_TAG} .'
                }    
            }
        }
        stage('Image Scan') {
            steps {
                script{
                    sh 'grype ${DOCKER_IMAGE}:${DOCKER_TAG} --fail-on high || true'
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
                            docker logout
                        """
                    }
                }
            }
        }
     }
}
