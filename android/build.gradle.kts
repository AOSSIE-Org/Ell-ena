allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir = rootProject.layout.buildDirectory.dir("../../build")

rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    layout.buildDirectory.set(newBuildDir.map { it.dir(name) })
    evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}