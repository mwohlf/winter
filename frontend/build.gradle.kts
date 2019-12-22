import com.moowork.gradle.node.NodeExtension
import com.moowork.gradle.node.npm.NpmTask
import com.palantir.gradle.docker.DockerExtension

// see: https://github.com/hiper2d/spring-kotlin-angular-demo/blob/master/client/build.gradle.kts
plugins {
    // see: https://github.com/srs/gradle-node-plugin
    id("com.moowork.node") version "1.3.1"
    id("com.palantir.docker") version "0.22.1"
}

configure<NodeExtension> {
    version = "13.4.0"
    npmVersion = "6.12.1"
    yarnVersion = "1.21.1"
    download = true
}

/*
tasks.withType<Jar> {
    dependsOn("yarn_run_build")
}

val jar by tasks.getting(Jar::class) {
    from("dist/todo-ui")
    into("static")
}
*/
