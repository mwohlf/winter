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
}

