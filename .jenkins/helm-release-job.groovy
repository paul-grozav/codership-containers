//
pipeline {
  agent { label 'srcbuild' }
  environment {
    RELEASE_REPOSITORY="codership/mysql-galera"
    TEST_REPOSITORY="codership/mysql-galera-test"
  }
  stages {
    stage ('Prepare') {
      steps {
        checkout scm
        script{
          //
          //commitHash = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
          version = sh(script: "grep appVersion mysql-galera/helm/Chart.yaml | awk '{print \$NF}' | sed -e 's:\"::g'",
                       returnStdout: true).trim()

          if (env.RELEASE == "true") {
            name = "mysql-galera"
            env.REPOSITORY=env.RELEASE_REPOSITORY
          } else {
            name = "mysql-galera-test"
            env.REPOSITORY=env.TEST_REPOSITORY
          }

          directory = name + "-" + version + "-" + env.RELEASENUM
          tarball = directory + ".tgz"
          currentBuild.description = "Branch: $GIT_BRANCH\nRev: $GIT_COMMIT"
        }
        echo "Making Helm release from git: $GIT_COMMIT"
        sh """
            set -x
            cp -a mysql-galera/helm $directory
            pushd $directory
              ./set_values.sh \
                    --repo   "$REPOSITORY" \
                    --rootpw "@@SET_ME@@" \
                    --dbuser "@@SET_ME@@" \
                    --userpw "@@SET_ME@@"
              rm -vf values.tmpl set_values.sh
            popd
            """
      }
    }
    stage ('Make tarball') {
      steps {
        script {
          sh """
              set -x
              /usr/bin/tar -czf $tarball $directory
              """
        }
      }
    }
    stage ('Finish') {
      steps {
        archiveArtifacts artifacts: tarball
      }
    }
  }
}
