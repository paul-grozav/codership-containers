//
pipeline {
  agent { label 'srcbuild' }
  stages {
    stage ('Prepare') {
      steps {
        checkout scm
        script{
          //
          //commitHash = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
          version = sh(script: "grep appVersion mysql-galera/helm/Chart.yaml | awk '{print \$NF}' | sed -e 's:\"::g'",
                       returnStdout: true).trim()
          directory = "mysql-galera-" + version + "-" + env.RELEASENUM
          tarball = directory + ".tar.gz"
          currentBuild.description = "Branch/rev: $GIT_COMMIT"
        }
        echo "Making Helm release from git: $GIT_COMMIT"
        sh """
            set -x
            cp -a mysql-galera/helm $directory
            pushd $directory
              ./set_values.sh \
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
