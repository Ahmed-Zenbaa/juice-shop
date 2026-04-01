pipeline {
    agent any

    environment {
        SONARQUBE = 'sonarqube'
        DOCKER_IMAGE = credentials('devsecops-demo-image')
        DOCKER_TAG = "v1.${BUILD_NUMBER}"
        NVD_API_KEY = credentials('nvd-api-key')
        DAST_TARGET_IP = credentials('app-dast-target-ip')
        DEFECTDOJO_TARGET_IP = credentials('defectdojo-target-ip')
        DEFECTDOJO_API_TOKEN = credentials('defectdojo-api-token')
    }

    stages {             

        stage ('Secrets Scan') {
            parallel {
                stage('Gitleaks') {
                   steps { 
                       sh 'gitleaks detect --source . --no-git --report-format json --report-path gitleaks-report.json || true'
                       sh 'echo "done" > gitleaks-status.txt'
                   }
                }
                stage('Detect Secrets Stage') {
                    stages {
                        stage('Wait for Gitleaks Status') {
                            steps {
                                script {
                                    waitUntil {
                                        fileExists 'gitleaks-status.txt'
                                    }
                                }
                            }
                        }
                        stage('Detect Secrets') {
                            steps { 
                               sh 'docker run --rm -v $(pwd):/wrk:rw -w /wrk python:3.11-alpine sh -c \'pip install detect-secrets && detect-secrets scan --all-files --exclude-files "gitleaks-report.json,checkov-secret-report/results_json.json,checkov-secret-report.json" | tee detect-secrets-report.json\''
                            }
                        }
                    }
                }
                stage('Checkov Secrets Stage') {
                    stages {
                        stage('Wait for Gitleaks status') {
                            steps {
                                script {
                                    waitUntil {
                                        fileExists 'gitleaks-status.txt'
                                    }
                                }
                            }
                        }
                        stage('Checkov Secrets') {
                            steps { 
                                sh '''
                                    docker run --rm -v $(pwd):/wrk -w /wrk bridgecrew/checkov:3.2.508  -d . --framework secrets -o json --soft-fail --output-file-path checkov-secret-report --skip-path "*-report.json"
                                    cp checkov-secret-report/results_json.json checkov-secret-report.json
                                '''
                            }
                        }
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
              catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
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
        }

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
                                    docker run -u 0 --rm -e NVD_API_KEY=$NVD_API_KEY -v $(pwd):/wrk -w /wrk owasp/dependency-check:12.2.0 --project "devsecops-demo" --scan . --disableArchive --nvdApiKey $NVD_API_KEY --format "HTML" --format "XML" --out /wrk/dependency-check-report --failOnCVSS 7 || true
                                    cp dependency-check-report/dependency-check-report.html dependency-check-report.html || true
                                    cp dependency-check-report/dependency-check-report.xml dependency-check-report.xml || true
                                '''
                            }
                        }
                    }
                }                
            }
        }

        stage ('Validate Dockerfile') {
            parallel {
                stage('Hadolint') {
                    steps {
                        script{
                            sh 'hadolint Dockerfile > hadolint-report.txt || true'
                            sh 'hadolint Dockerfile-insecure > hadolint-insecure-report.txt || true'
                        }    
                    }
                }
                stage('Checkov Dockerfile') {
                    steps {
                        script{
                            sh 'docker run --rm -v $(pwd):/wrk -w /wrk bridgecrew/checkov:3.2.508  -f Dockerfile --framework dockerfile -o json --soft-fail > checkov-dockerfile-report.json || true'
                            sh '''
                                cp Dockerfile-insecure insecure.dockerfile
                                docker run --rm -v $(pwd):/wrk -w /wrk bridgecrew/checkov:3.2.508  -f insecure.dockerfile --framework dockerfile -o json --soft-fail > checkov-dockerfile-insecure-report.json || true
                            '''
                        }    
                    }
                }
                stage('Conftest') {
                    steps {
                        script{
                            sh 'conftest test Dockerfile > conftest-report.txt || true'
                            sh 'conftest test Dockerfile-insecure > conftest-insecure-report.txt || true'
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

        stage ('Image Scan') {
            parallel {
                stage('Trivy Image') {
                    steps {
                        script{
                            sh 'docker run --rm -v $(pwd):/wrk -w /wrk aquasec/trivy:0.69.3 image ${DOCKER_IMAGE}:${DOCKER_TAG} --format json -o trivy-image-report.json || true'
                        }    
                    }
                }
                stage('Grype') {
                    steps {
                        script{
                            sh 'grype ${DOCKER_IMAGE}:${DOCKER_TAG} -o json --fail-on high > grype-report.json || true'
                        }    
                    }
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

        stage ('IaC manifests Scan') {
            parallel {
                stage('Trivy IaC') {
                    steps {
                        script{
                            sh 'docker run --rm -v $(pwd):/wrk -w /wrk aquasec/trivy:0.69.3 config Infrastructure --format json -o trivy-iac-report.json || true'
                        }    
                    }
                }
                stage('Checkov IaC') {
                    steps {
                        script{
                            sh 'docker run --rm -v $(pwd):/wrk -w /wrk bridgecrew/checkov:3.2.508 -d Infrastructure --framework terraform -o json > checkov-iac-report.json || true'
                        }    
                    }
                }
            }
        }
        
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
                    sh 'docker run --rm --add-host juice.shop.internal:$DAST_TARGET_IP -v $(pwd):/zap/wrk:rw -t zaproxy/zap-stable:2.17.0 zap-full-scan.py -t http://juice.shop.internal -a -r zap-report.html -x zap-report.xml || true '
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
