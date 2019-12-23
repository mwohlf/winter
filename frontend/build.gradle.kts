import com.moowork.gradle.node.NodeExtension
import com.moowork.gradle.node.yarn.YarnTask
import com.moowork.gradle.node.yarn.YarnInstallTask
import com.palantir.gradle.docker.DockerExtension

// see: https://github.com/hiper2d/spring-kotlin-angular-demo/blob/master/client/build.gradle.kts
//      https://github.com/srs/gradle-node-plugin/issues/127
plugins {
    base
    // see: https://github.com/srs/gradle-node-plugin
    //      https://github.com/srs/gradle-node-plugin/blob/master/docs/node.md
    //      https://github.com/hiper2d/spring-kotlin-angular-demo/blob/master/client/build.gradle.kts
    id("com.moowork.node") version "1.3.1"
    id("com.palantir.docker") version "0.22.1"
}

configure<NodeExtension> {
    download = false // can't download atm because it looks for ivy.xml
    // see: https://stackoverflow.com/questions/58102283/maven-and-ivy-dependency-resolution-fails-with-gradle-6-0
    distBaseUrl = "https://nodejs.org/dist"
    version = "13.5.0"
    npmVersion = "6.12.1"
    yarnVersion = "1.21.1"
}


tasks.register(name = "startLocal", type = YarnTask::class) {
    dependsOn("yarn_install") // setting up the node_modules directory
    // 'yarn start' is configured in package.json and executes 'ng serve'
    args = listOf("start")
    doFirst {
        println("yarnStart running")
    }
}

tasks.register(name = "useMrPropper", type = DefaultTask::class) {
    dependsOn("clean")
    doFirst {
        println("MrPropper cleaning, removing all artifacts")
    }
    delete("node_modules")
    delete(".gradle") // this doesn't work on windows i guess
    delete("yarn.lock")
}


