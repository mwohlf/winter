import com.moowork.gradle.node.NodeExtension

buildscript {
    repositories {
        mavenCentral()
    }
}

// see: https://github.com/hiper2d/spring-kotlin-angular-demo/blob/master/client/build.gradle.kts
//      https://github.com/srs/gradle-node-plugin/issues/127
plugins {
    base
    // see: https://github.com/srs/gradle-node-plugin
    //      https://github.com/srs/gradle-node-plugin/blob/master/docs/node.md
    id("com.moowork.node") version "1.3.1"
    // id("com.palantir.docker") version "0.22.1"
}

configure<NodeExtension> {
    // see: https://stackoverflow.com/questions/58102283/maven-and-ivy-dependency-resolution-fails-with-gradle-6-0
    download = false // can't download atm because it looks for ivy.xml
    distBaseUrl = "https://nodejs.org/dist"
    version = "13.5.0"
    npmVersion = "6.12.1"
    yarnVersion = "1.21.1"
}

tasks.register("greeting") {
    doLast { println("Hello, World! project frontend") }
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
