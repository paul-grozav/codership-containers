#!groovy

pipeline {

  agent { label 'docker' }

  environment {
    image = "codership/mysql-galera-test"
    RH_VERSION = "9"
    TAG="${GIT_TARGET}"
    DOCKERHUBCREDS = credentials('DockerHub')
    HELM_VER="v3.15.0"
    KUBECTL_VER="v1.30.1"
    HELM_PROJECT="mysql-galera"
  }

  stages {

    stage('Prepare') {
      steps {
        checkout scm
        script {
          currentBuild.description = "Branch: ${GIT_TARGET}"
        }
        sh '''
            if [[ ! -x /usr/local/bin/helm ]]; then
              wget https://get.helm.sh/helm-${HELM_VER}-linux-amd64.tar.gz
              tar -xf helm-${HELM_VER}-linux-amd64.tar.gz --strip-components=1
              sudo chmod +x ./helm
              sudo mv -vf ./helm /usr/local/bin
            fi
           '''
        sh '''
            if [[ ! -x /usr/local/bin/kubectl ]]; then
              wget https://dl.k8s.io/release/${KUBECTL_VER}/bin/linux/amd64/kubectl
              sudo chmod +x ./kubectl
              sudo mv -vf ./kubectl /usr/local/bin
            fi
           '''
        sh '''
            if [[ ! -x /usr/local/bin/minikube ]]; then
              wget https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 -O minikube
              sudo chmod +x minikube
              sudo mv -vf minikube /usr/local/bin
            fi
           '''
        sh "docker login --username ${DOCKERHUBCREDS_USR} --password ${DOCKERHUBCREDS_PSW}"
      }
    }

    stage('Info') {
      steps {
        sh "docker version ||:"
        sh "helm version ||:"
        sh "kubectl version ||:"
        sh "minikube version ||:"
      }
    }

    stage('Docker Image') {
      steps {
        sh '''
            docker build \
              --build-arg RH_VERSION=${RH_VERSION} \
              --build-arg MYSQL_RPM_VERSION=${MYSQL_RPM_VERSION} \
              -t $image:${TAG} -f mysql-galera/image/Dockerfile mysql-galera/image
            docker push $image:${TAG}
            '''
      }
    }

    stage('Init Minikube') {
      steps {
        echo "Preparing Minikube..."
        sh "minikube delete"
        sh "minikube start"
        sh '''
          kubectl create secret docker-registry regcred \
            --docker-username=${DOCKERHUBCREDS_USR} \
            --docker-password=${DOCKERHUBCREDS_PSW}
           '''
      }
    }

    stage('Helm Installation') {
      steps {
        echo "Testing Helm installation..."
        sh "helm install mysql-galera-${TAG} mysql-galera/helm"
        echo "Waiting a bit for manifests to deploy..."
        sleep(60)
      }
    }

    stage('Galera Cluster Test'){
      steps {
        echo "Checking Galera Cluster installation"
        timeout(time: 5, unit: 'MINUTES') {
          script {
            while (true) {
              sh "kubectl get pods"
              def notReady = sh (
                              script: "kubectl get pods | grep '0/1' | wc -l",
                              returnStdout: true
                              ).trim()
              if(notReady.toInteger() == 0) {
                break
              } else {
                echo notReady + " pods are not ready yet..."
              }
              sleep(30)
            }
          }
        }
        echo "Checking wsrep status..."
        script {
          def root_password = sh (script: "grep rootpw mysql-galera/helm/values.yaml | awk '{print \$NF}'",
                                  returnStdout: true
                                 ).trim()
          def wsrep_status = sh (script: "kubectl exec -ti mysql-galera-${TAG}-0 -- mysql -uroot -pOohiechohr8xooTh -ss -N -e \"SHOW STATUS LIKE 'wsrep_ready'\" 2>/dev/null | tail -n1 | awk '{print \$NF}'",
                                 returnStdout: true
                                 ).trim()
          if(wsrep_status == "ON") {
            echo "OK, WSREP status is ON"
          }else{
            echo "WSREP status is " + wsrep_status
            echo "Error!"
            currentBuild.result = 'FAILURE'
          }
          def cluster_size = sh (script: "kubectl exec -ti mysql-galera-${TAG}-0 -- mysql -uroot -pOohiechohr8xooTh -ss -N -e \"SHOW STATUS LIKE 'wsrep_cluster_size'\" 2>/dev/null | tail -n1 | awk '{print \$NF}'",
                                 returnStdout: true
                                 ).trim()
          if(cluster_size.toInteger() == 3){
            echo "OK, all nodes a joined!"
          } else {
            echo "WSREP cluster size is " + cluster_size
            echo "Error!"
            currentBuild.result = 'FAILURE'
          }
        }
      }
    }

    stage('Helm Uninstall') {
      steps {
        echo "Helm Uninstall"
        sh "helm uninstall mysql-galera-${GIT_TARGET}"
      }
    }

  } // stages

  post {
    always {
      sh "minikube delete"
      sh 'docker rmi -f $image:${TAG}'
    }
  }

}
