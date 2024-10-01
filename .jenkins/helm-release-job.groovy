//
version = "8.0.39"
directory = "mysql-galera-" + version
tarball = directory + ".tar.gz"
//
pipeline {
  agent { label 'srcbuild' }
  stages {
    stage ('Prepare') {
      steps {
        echo "Making Helm release from git:" + env.GIT_BRANCH
        script{
          version = sh(script: "grep appVersion mysql-galera/helm/Chart.yaml | awk '{print \$NF}' | sed -e 's:\"::g'",
                       returnStdout: true)
        }
        sh """
            set -x
            cp -a mysql-galera/helm $directory
            pushd $directory
              ./set_values.sh \
                    --rootpw "@@SET_ME@@" \
                    --dbuser "@@SET_ME@@" \
                    --userpw "@@SET_ME@@"
              rm -vf values.tmpl set_test_values.sh
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
