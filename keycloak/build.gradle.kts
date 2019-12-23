import com.bmuschko.gradle.docker.tasks.image.DockerBuildImage
import com.bmuschko.gradle.docker.tasks.image.Dockerfile
import de.undercouch.gradle.tasks.download.Download
import com.bmuschko.gradle.docker.tasks.container.DockerStartContainer
import com.bmuschko.gradle.docker.tasks.container.DockerStopContainer
import com.bmuschko.gradle.docker.tasks.container.DockerCreateContainer
import com.bmuschko.gradle.docker.tasks.container.DockerRemoveContainer

/*
 * see: https://bmuschko.github.io/gradle-docker-plugin/#remote_api_plugin
 *      https://bmuschko.github.io/gradle-docker-plugin/#custom_task_types
 */

plugins {
    base
    id("com.bmuschko.docker-remote-api") version "6.1.1"
    id("de.undercouch.download") version "4.0.2"
    // kotlin("jvm") version "1.3.61"
}

tasks.register(name = "downloadKeycloak", type = Download::class) {
    src("https://downloads.jboss.org/keycloak/8.0.1/keycloak-8.0.1.zip")
    dest(buildDir)
    overwrite(false)
}

tasks.register(name = "downloadPostgres", type = Download::class) {
    src("https://jdbc.postgresql.org/download/postgresql-42.2.5.jar")
    dest(buildDir)
    overwrite(false)
}

tasks.register(name = "extractKeycloak", type = Copy::class) {
    dependsOn("downloadKeycloak")
    from(zipTree(buildDir.path + "/keycloak-8.0.1.zip"))
    into(buildDir.path + "/docker")
}

tasks.register(name = "copySourcefiles", type = Copy::class) {
    dependsOn("downloadPostgres")
    from("src")
    from(buildDir.path + "/postgresql-42.2.5.jar")
    into(buildDir.path + "/docker")
}

tasks.register(name = "assembleKeycloakImage", type = DockerBuildImage::class) {

}

tasks.register(name = "createDockerfile", type = Dockerfile::class) {
    dependsOn("downloadKeycloak")

    from("openjdk:11-jre")
    runCommand( """apt-get update && \
        apt-get install -y bash && \
        apt-get install -y certbot && \
        apt-get install -y openssl && \
        echo "base image done"  """)
    user("root")
    // the content from the zip file
    addFile("keycloak-8.0.1", "/opt/jboss/keycloak")
    // scripts and config for the bin folder
    addFile("docker-entrypoint.sh", "/opt/jboss/keycloak/bin/")
    addFile("run.conf", "/opt/jboss/keycloak/bin/")
    addFile("create-cert.bash", "/opt/jboss/keycloak/bin/")
    // config settings for the config folder
    addFile("application.keystore", "/opt/jboss/keycloak/standalone/configuration/")
    addFile("keycloak-add-realm.json", "/opt/jboss/keycloak/standalone/configuration/")
    addFile("keycloak-add-user.json", "/opt/jboss/keycloak/standalone/configuration/")

    // add the db driver
    runCommand("mkdir -p /opt/jboss/keycloak/modules/system/layers/keycloak/org/postgresql/main")
    addFile("module.xml", "/opt/jboss/keycloak/modules/system/layers/keycloak/org/postgresql/main/")
    addFile("postgresql-42.2.5.jar", "/opt/jboss/keycloak/modules/system/layers/keycloak/org/postgresql/main/")

    environmentVariable("LANG", "en_US.UTF-8")
    environmentVariable("KEYCLOAK_HTTP_PORT", "80")
    environmentVariable("KEYCLOAK_HTTPS_PORT", "443")
    // values are picked up by the docker-entrypoint.sh script
    environmentVariable("KEYCLOAK_USER", "admin")
    environmentVariable("KEYCLOAK_PASSWORD", "adnsjoeGhd6Rfp")
    // value is picked up by the standalone.sh script called from the entrypoint
    environmentVariable("RUN_CONF", "/opt/jboss/keycloak/bin/run.conf")

    exposePort(80)
    exposePort(443)
    exposePort(9990)

    entryPoint("/opt/jboss/keycloak/bin/docker-entrypoint.sh")
}

tasks.register(name = "useMrPropper", type = DefaultTask::class) {
    dependsOn("clean")
    doFirst {
        println("MrPropper cleaning, removing all artifacts and downloads")
    }
}

tasks.register(name = "buildKeycloakImage", type = DockerBuildImage::class).configure {
    // tagging see: https://github.com/bmuschko/gradle-docker-plugin/issues/784
    images.add("keycloak:8.0.1")
    images.add("keycloak:latest")
}

tasks.register(name = "createKeycloakContainer", type = DockerCreateContainer::class).configure {
    dependsOn("build")
    targetImageId("keycloak:latest")
    containerName.set("keycloak")
    containerId.set("keycloak")
    hostConfig.portBindings.add("80:80")
    hostConfig.portBindings.add("443:443")
    hostConfig.portBindings.add("9990:9990")
    // used as parameter/command for the entrypoint/script
    // this binds the guest machine ports to all interfaces, needed for forwarding the ports to the host machine
    cmd.add("-b")
    cmd.add("0.0.0.0")
}

tasks.register(name = "removeKeycloakContainer", type = DockerRemoveContainer::class).configure {
    dependsOn("stopKeycloakContainer")
    containerId.set("keycloak")
}

tasks.register(name = "runKeycloakContainer", type = DockerStartContainer::class).configure {
    dependsOn("createKeycloakContainer")
    targetContainerId("keycloak")
}

tasks.register(name = "stopKeycloakContainer", type = DockerStopContainer::class).configure {
    targetContainerId("keycloak")
    // todo:
    // onlyIf()
}

/// we hook everything up in the standard assemble and build task from the base module

tasks.named("assemble").configure {
    dependsOn("extractKeycloak")
    dependsOn("copySourcefiles")
    dependsOn("createDockerfile")
}

tasks.named("build").configure {
    dependsOn("buildKeycloakImage")
}

tasks.named("clean").configure {
    dependsOn("removeKeycloakContainer")
}

