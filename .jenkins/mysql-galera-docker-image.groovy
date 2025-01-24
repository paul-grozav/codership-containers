#!groovy

pipeline {

  agent { label 'docker' }

  options {
    timeout(time: 10, unit: 'MINUTES')
  }

  environment {
    RH_VERSION = "8"
    DOCKERHUBCREDS = credentials('DockerHub')
    HELM_PROJECT="mysql-galera"
    MYSQL_VERSION = "8.0.40"
    WSREP_VERSION = "26.21"
    RELEASE_REPOSITORY="codership/mysql-galera"
    TEST_REPOSITORY="codership/mysql-galera-test"
  }

  stages {

    stage('Prepare') {
      steps {
        checkout scm
        script {
          currentBuild.description = "Branch: ${GIT_TARGET}"
          env.TAG = env.MYSQL_VERSION
          if (env.RELEASE == "true") {
            env.REPOSITORY=env.RELEASE_REPOSITORY
          } else {
            env.REPOSITORY=env.TEST_REPOSITORY
          }
        }
        sh "sudo apt-get update; sudo apt-get -y install gawk mysql-client-core-8.0"
        sh "docker login --username ${DOCKERHUBCREDS_USR} --password ${DOCKERHUBCREDS_PSW}"
      }
    }

    stage('Info') {
      steps {
        sh "docker version ||:"
      }
    }

    stage('Docker Image') {
      steps {
        sh '''
            MYSQL_RPM_VERSION="$MYSQL_VERSION-$WSREP_VERSION"
            docker build \
              --no-cache --pull \
              --build-arg RH_VERSION=${RH_VERSION} \
              --build-arg MYSQL_RPM_VERSION=${MYSQL_RPM_VERSION} \
              -t ${REPOSITORY}:${TAG} -f mysql-galera/image/Dockerfile mysql-galera/image
            docker push ${REPOSITORY}:${TAG}
            '''
      }
    }

    stage('Cleanup') {
      steps {
        sh "docker rmi -f ${REPOSITORY}:${TAG} ||:"
      }
    }

  } // stages

  post {
    success {
      build job: 'mysql-galera-helm-test', wait: false,
        parameters: [
          booleanParam( name: 'RELEASE', value: env.RELEASE)
          ]
    }
  }
}
