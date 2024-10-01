#!groovy

def ipaddress = ""
def svcport   = 30006
def root_password = ""
def mysql_user = ""
def mysql_passwd = ""

/*

*/

pipeline {

  agent { label 'docker' }

  options {
    timeout(time: 10, unit: 'MINUTES')
  }

  environment {
    RH_VERSION = "8"
    DOCKERHUBCREDS = credentials('DockerHub')
    HELM_VER="v3.15.0"
    KUBECTL_VER="v1.30.1"
    HELM_PROJECT="mysql-galera"
    IMAGE_TAG = "8.0.39"
    MYSQL_ROOT_PASSWORD="Oohiechohr8xooTh"
    MYSQL_USER="admin"
    MYSQL_USER_PASSWORD="LohP4upho0oephah"
  }

  stages {

    stage('Prepare') {
      steps {
        checkout scm
        script {
          currentBuild.description = "Branch: ${GIT_TARGET}"

          if(env.REPOSITORY == "codership/mysql-galera-test") {
            env.TAG = "develop"
          } else {
            env.TAG = env.IMAGE_TAG
          }
        }

        sh "sudo apt-get update; sudo apt-get -y install gawk mysql-client-core-8.0"
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
              --no-cache --pull \
              --build-arg RH_VERSION=${RH_VERSION} \
              --build-arg MYSQL_RPM_VERSION=${MYSQL_RPM_VERSION} \
              -t ${REPOSITORY}:${TAG} -f mysql-galera/image/Dockerfile mysql-galera/image
            docker push ${REPOSITORY}:${TAG}
            '''
      }
    }

    stage('Init Minikube') {
      steps {
        echo "Preparing Minikube..."
        sh "minikube delete"
        sh "minikube start"
      }
    }

    stage('Helm Installation') {
      steps {
        echo "Testing Helm installation..."
        sh "sed -i \"s:@@USERNAME@@:${DOCKERHUBCREDS_USR}:g\" mysql-galera/helm/values.yaml"
        sh "sed -i \"s:@@PASSWORD@@:${DOCKERHUBCREDS_PSW}:g\" mysql-galera/helm/values.yaml"
        sh "sed -i \"s:@@REPOSITORY@@:${REPOSITORY}:g\" mysql-galera/helm/values.yaml"
        sh "sed -i \"s:@@IMAGE_TAG@@:${TAG}:g\" mysql-galera/helm/values.yaml"
        sh "sed -i \"s:@@MYSQL_ROOT_PASSWORD@@:${MYSQL_ROOT_PASSWORD}:g\" mysql-galera/helm/values.yaml"
        sh "sed -i \"s:@@MYSQL_USER@@:${MYSQL_USER}:g\" mysql-galera/helm/values.yaml"
        sh "sed -i \"s:@@MYSQL_USER_PASSWORD@@:${MYSQL_USER_PASSWORD}:g\" mysql-galera/helm/values.yaml"
        sh "cat mysql-galera/helm/values.yaml"
        sh "helm install ${HELM_PROJECT} mysql-galera/helm --namespace ${HELM_PROJECT} --create-namespace"
        echo "Waiting for manifests to deploy..."
        sleep(90)
      }
    }

    stage('Galera Cluster Check'){
      steps {
        echo "Checking Galera Cluster installation"
        timeout(time: 5, unit: 'MINUTES') {
          script {
            while (true) {
              sh "kubectl -n ${HELM_PROJECT} get pods"
              def notReady = sh (
                              script: "kubectl -n ${HELM_PROJECT} get pods | grep '0/1' | wc -l",
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
        script {
          def svc_url = sh (script: "minikube service -n ${HELM_PROJECT} ${HELM_PROJECT}-client --url | tail -n 1 | sed -e 's|http://||g'",
                            returnStdout: true
                            ).trim().split(':')
          ipaddress = svc_url[0]
          svcport   = svc_url[1]
          echo "IP address for Galera Cluster service is " + ipaddress + " on port " + svcport
        }

        script {
          root_password = sh (script: "grep rootpw mysql-galera/helm/values.yaml | awk '{print \$2}'",
                              returnStdout: true
                              ).trim()
          mysql_user = sh (script: "grep '[[:blank:]]name:' mysql-galera/helm/values.yaml | awk '{print \$2}'",
                           returnStdout: true
                           ).trim()
          mysql_passwd = sh (script: "grep 'passwd:' mysql-galera/helm/values.yaml | awk '{print \$2}'",
                             returnStdout: true
                             ).trim()
        }

        echo "Checking wsrep status..."
        script {

          def wsrep_status = sh (script: "mysql -h " + ipaddress + " -P " + svcport + " -uroot -p" + root_password + " -ss -N -e \"SHOW STATUS LIKE 'wsrep_ready'\" 2>/dev/null | tail -n1 | awk '{print \$NF}'",
                                 returnStdout: true
                                 ).trim()
          if(wsrep_status == "ON") {
            echo "OK, WSREP status is ON"
          }else{
            echo "WSREP status is " + wsrep_status
            echo "Error!"
            currentBuild.result = 'FAILURE'
          }
          def cluster_size = sh (script: "mysql -h " + ipaddress + " -P " + svcport + " -uroot -p" + root_password + " -ss -N -e \"SHOW STATUS LIKE 'wsrep_cluster_size'\" 2>/dev/null | tail -n1 | awk '{print \$NF}'",
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

    stage('Cluster test'){
      steps {
        echo "Starting cluster test..."

        echo "Loading data into cluster..."
        sh "cat jenkins/testdb.sql | mysql -h " + ipaddress + " -P " + svcport + " -uroot -p" + root_password

        echo "Reading data from cluster..."
        script {
          def count = sh (script: "mysql -ss -N -h " + ipaddress + " -P " + svcport + " -uroot -p" + root_password + " testdb -e \"SELECT COUNT(*) from myTable\"",
                          returnStdout: true
                          ).trim()
          // test data contains 100 rows!
          if(count.toInteger() == 100) {
            echo "Row count matches!"
          } else {
            echo "Row count does not match!"
            echo "Error!"
            currentBuild.result = 'FAILURE'
          }
          sh "mysql -h " + ipaddress + " -P " + svcport + " -uroot -p" + root_password + " -e \"GRANT ALL PRIVILEGES ON testdb.* to 'admin'@'%'\""
          sh "mysql -h " + ipaddress + " -P " + svcport + " -u" + mysql_user + " -p" + mysql_passwd + " testdb -e \"SELECT * FROM myTable\""
        }
      }
    }

    stage('Helm Uninstall') {
      steps {
        echo "Helm Uninstall"
        sh "helm uninstall ${HELM_PROJECT} --namespace ${HELM_PROJECT}"
      }
    }

    stage('Cleanup') {
      steps {
        sh "minikube delete"
        sh "docker rmi -f ${REPOSITORY}:${TAG} ||:"
      }
    }

  } // stages

  post {
    aborted {
      sh "kubectl -n ${HELM_PROJECT} describe pod ${HELM_PROJECT}-0"
      sh "kubectl -n ${HELM_PROJECT} describe pod ${HELM_PROJECT}-1"
      sh "kubectl -n ${HELM_PROJECT} describe pod ${HELM_PROJECT}-2"
      //
      sh "kubectl -n ${HELM_PROJECT} logs ${HELM_PROJECT}-0"
      sh "kubectl -n ${HELM_PROJECT} logs ${HELM_PROJECT}-1"
      sh "kubectl -n ${HELM_PROJECT} logs ${HELM_PROJECT}-2"
      //
      sh "kubectl -n ${HELM_PROJECT} get secret regcred -o yaml"
    }
  }
}
