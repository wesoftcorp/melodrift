allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // Force all subprojects (including Flutter plugins) to use the same Kotlin version.
    // Plugins like speech_to_text pin old Kotlin versions (e.g. 1.7.10) which clash
    // with the project-level Kotlin 2.3.20 compiler.
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "org.jetbrains.kotlin") {
                useVersion("2.1.20")
                because("Force consistent Kotlin version across all sub-projects")
            }
        }
    }


}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            project.extensions.configure<com.android.build.gradle.BaseExtension>("android") {
                compileSdkVersion(36)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
