#!groovy

pipeline {
    agent { label 'docker' }

    environment {
        image = "codership/mysql-galera-test"
        RH_VERSION = "9"
        TAG="develop"
        DOCKERHUBCREDS = credentials('DockerHub')
    }

    stages {
        stage('Prepare'){
            steps {
                checkout scm
                script {
                    currentBuild.description = "Branch: " + scm.branches[0].name
                }
            }
        }
        stage('Docker Build') {

              steps {
                sh '''
                    cd mysql-galera/image
                    docker build \
                        --build-arg RH_VERSION=${RH_VERSION} \
                        --build-arg MYSQL_RPM_VERSION=${MYSQL_RPM_VERSION} \
                        -t $image:${TAG} -f Dockerfile .
                    '''
                }

        }
        stage('Docker Push') {
            steps {
                sh '''

                    docker login --username ${DOCKERHUBCREDS_USR} --password ${DOCKERHUBCREDS_PSW}
                    docker push $image:${TAG}
                   '''
            }
        }
        stage('Cleanup') {
            steps {
                sh 'docker rmi -f $image:${TAG}'
            }
        }
    }
}
