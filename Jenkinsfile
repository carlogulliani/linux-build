/**
properties([
  parameters([
    string(defaultValue: '1.0', description: 'Current version number', name: 'VERSION'),
    text(defaultValue: '', description: 'A list of changes', name: 'CHANGES'),
    choice(choices: 'all\njessie-minimal-rock64\njessie-openmediavault-rock64\nstretch-minimal-rock64\nxenial-i3-rock64\nxenial-mate-rock64\nxenial-minimal-rock64\nlinux-virtual', description: 'What makefile image to target', name: 'MAKE_TARGET')
    booleanParam(defaultValue: true, description: 'Whether to upload to Github for release or not', name: 'GITHUB_UPLOAD'),
    booleanParam(defaultValue: false, description: 'If build should be marked as pre-release', name: 'GITHUB_PRERELEASE'),
    string(defaultValue: 'ayufan-rock64', description: 'GitHub username or organization', name: 'GITHUB_USER'),
    string(defaultValue: 'linux-build', description: 'GitHub repository', name: 'GITHUB_REPO'),
  ])
])
*/

node('docker && linux-build') {
  try {
    timestamps {
      wrap([$class: 'AnsiColorBuildWrapper', colorMapName: 'xterm']) {
        stage('Environment') {
          checkout scm

          def environment = docker.image('ayufan/rock64-dockerfiles:x86_64')
          //def startDate = new Date().parse('dd/MM/yyyy HH:mm:ss')

          environment.inside("--privileged -u 0:0") {
            withEnv([
              "USE_CCACHE=true",
              "RELEASE_NAME=$VERSION",
              "RELEASE=$BUILD_NUMBER"
            ]) {
                stage('Prepare') {
                  // notifyBuild("STARTED")
                  sh '''#!/bin/bash
                    set -xe
                    export CCACHE_DIR=$WORKSPACE/ccache
                    ccache -M 0 -F 0
                    git clean -ffdx -e ccache
                  '''
                }

                stage('Sources') {
                  sh '''#!/bin/bash
                    set -xe

                    export HOME=$WORKSPACE
                    export USER=jenkins

                    repo init -u https://github.com/ayufan-rock64/linux-manifests -b default --depth=1 --no-clone-bundle
                    repo sync -j 20 -c --force-sync
                  '''
                }
              
              withEnv([
                "PATCH=$PATCH"
              ]) {
                  stage('Apply patches') {
                    if (params.PATCH) {
                      sh '''#!/bin/bash
                          set -xe
                          wget -O ./kernel/arch/arm64/boot/dts/rockchip/rk3328.dtsi https://raw.githubusercontent.com/ilyamordasov/linux-build/master/kernel/arch/arm64/boot/dts/rockchip/rk3328.dtsi
                          wget -O ./kernel/arch/arm64/boot/dts/rockchip/rk3328-rock64.dts https://raw.githubusercontent.com/ilyamordasov/linux-build/master/kernel/arch/arm64/boot/dts/rockchip/rk3328-rock64.dts
                      '''
                    }
                 }
              }

                stage('U-boot') {
                  sh '''#!/bin/bash
                    set -xe
                    export CCACHE_DIR=$WORKSPACE/ccache
                    make u-boot-build
                  '''
                }

                stage('Kernel') {
                  sh '''#!/bin/bash
                    set -xe
                    export CCACHE_DIR=$WORKSPACE/ccache
                    make kernel-build KERNEL_DIR=kernel
                    make kernel-build KERNEL_DIR=kernel-mainline
                  '''
                }

                stage('Images') {
                  sh '''#!/bin/bash
                    set -xe
                    export CCACHE_DIR=$WORKSPACE/ccache
                    make -j$(nproc) $MAKE_TARGET
                  '''
                }

                stage('Copy images') {
                  sh '''#1/bin/bash
                    for file in *.xz; do
                      cp $(basename "$file") /home/im/Desktop/rock64/firmware/tags/$(basename "$file")
                    done
                  '''
                }
            }

            withEnv([
              "VERSION=$VERSION",
              "CHANGES=$CHANGES",
              "GITHUB_PRERELEASE=$GITHUB_PRERELEASE",
              "GITHUB_USER=$GITHUB_USER",
              "GITHUB_REPO=$GITHUB_REPO"
            ]) {
              stage('Freeze') {
                sh '''#!/bin/bash
                  # use -ve, otherwise we could leak GITHUB_TOKEN...
                  set -ve
                  shopt -s nullglob

                  export HOME=$WORKSPACE
                  export USER=jenkins

                  repo manifest -r -o manifest.xml
                '''
              }

              stage('Tagging') {
                sh '''#!/bin/bash
                  # use -ve, otherwise we could leak GITHUB_TOKEN...
                  set -ve
                  repo forall -g tagged -e -c git tag "$GITHUB_USER/$GITHUB_REPO/$VERSION"
                '''

                if (params.GITHUB_UPLOAD) {
                  retry(2) {
                    sh '''#!/bin/bash
                      # use -ve, otherwise we could leak GITHUB_TOKEN...
                      set -ve
                      echo "machine github.com login user password $GITHUB_TOKEN" > ~/.netrc
                      repo forall -g tagged -e -c git push ilyamordasov "$GITHUB_USER/$GITHUB_REPO/$VERSION" -f
                      rm ~/.netrc
                    '''
                  }
                } else {
                   echo 'Flagged as an no tagging release job'
                }
              }

              stage('Release') {
                if (params.GITHUB_UPLOAD) {
                  sh '''#!/bin/bash
                    set -xe
                    shopt -s nullglob

                    github-release release \
                        --tag "${VERSION}" \
                        --name "$VERSION: $BUILD_TAG" \
                        --description "${CHANGES}\n\n${BUILD_URL}" \
                        --draft

                    github-release upload \
                        --tag "${VERSION}" \
                        --name "manifest.xml" \
                        --file "manifest.xml"

                    for file in *.xz *.deb; do
                      github-release upload \
                          --tag "${VERSION}" \
                          --name "$(basename "$file")" \
                          --file "$file" &
                    done

                    wait

                    if [[ "$GITHUB_PRERELEASE" == "true" ]]; then
                      github-release edit \
                        --tag "${VERSION}" \
                        --name "$VERSION: $BUILD_TAG" \
                        --description "${CHANGES}\n\n${BUILD_URL}" \
                        --pre-release
                    else
                      github-release edit \
                        --tag "${VERSION}" \
                        --name "$VERSION: $BUILD_TAG" \
                        --description "${CHANGES}\n\n${BUILD_URL}"
                    fi
                  '''
                } else {
                   echo 'Flagged as an no upload release job'
                }
              }
            }
          }
        }
      }
    }
  } catch (e) {
    // If there was an exception thrown, the build failed
    currentBuild.result = "Failed"
    throw e
  } finally {
    // Success or failure, always send notifications
    notifyBuild(currentBuild.result)
  }
}

def notifyBuild(String buildStatus = 'STARTED') {
  //def endDate = new Date()
  //def tookTime = groovy.time.TimeCategory.minus(endDate,startDate).toString()

  // build status of null means successful
  buildStatus =  buildStatus ?: 'Success'
 
  // Default values
  def colorName = 'RED'
  def colorCode = '#FF0000'
  def buildUrl = "http://jenkins.gotdns.ch"
  // def buildUrl = ${env.BUILD_URL}
  // buildUrl = buildUrl.replace("localhost", "jenkins.gotdns.ch")
  def subject = "${env.JOB_NAME} - #${env.BUILD_NUMBER} ${buildStatus}"
  def summary = "${subject} (<${env.BUILD_URL}|Open>)"
 
  // Override default values based on build status
  if (buildStatus == 'STARTED') {
    color = 'YELLOW'
    colorCode = '#FFFF00'
  } else if (buildStatus == 'Success') {
    color = 'GREEN'
    colorCode = '#36a64f'
  } else {
    color = 'RED'
    colorCode = '#FF0000'
  }
 
  // Send notifications
  slackSend (color: colorCode, message: summary)
}
