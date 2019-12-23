import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

/*
 * see: https://docs.gradle.org/6.0.1/dsl/
 *      https://github.com/sdeleuze/spring-boot-kotlin-demo/blob/master/build.gradle.kts
 */

repositories {
    google()
    jcenter()
    maven { url = uri("https://jitpack.io") }
}

plugins {
    java
    kotlin("jvm") version "1.3.61"
}

tasks.register(name = "useMrPropper", type = DefaultTask::class) {
    dependsOn("clean")
    doFirst {
        println("MrPropper cleaning, removing all artifacts")
    }
    delete(".gradle") // this doesn't work on windows i guess
}
