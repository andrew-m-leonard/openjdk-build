/*
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import groovy.json.JsonSlurper

node ("master") {
  def jenkinsUrl = "${params.JENKINS_URL}"
  def trssUrl    = "${params.TRSS_URL}"

  def buildFailures = 0
  def testStats = []

  stage("getDiskSpace") {
    def jenkins = Jenkins.getInstance()
    for (slave in hudson.model.Hudson.instance.slaves) {

      FilePath slaveRootPath = slave.getRootPath()

      total = slaveRootPath.getTotalDiskSpace()
      free = slaveRootPath.getUsableDiskSpace()

      available = (100 * free)/total

      System.out.println(slave.getDisplayName() + " free space percentage: " + available + "%")
   
      break
    }

  }

}

