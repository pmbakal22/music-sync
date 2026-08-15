allprojects {
    repositories {
        google()
        mavenCentral()
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

// Fallback namespace for older plugins required by AGP 8+
subprojects {
    fun fixNamespace() {
        if (plugins.hasPlugin("com.android.library") || plugins.hasPlugin("com.android.application")) {
            val androidExt = extensions.findByName("android")
            if (androidExt != null) {
                try {
                    val getNamespace = androidExt.javaClass.getMethod("getNamespace")
                    if (getNamespace.invoke(androidExt) == null) {
                        val setNamespace = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                        val fallbackNamespace = "com.spotify.sdk.${project.name.replace('-', '_')}"
                        setNamespace.invoke(androidExt, fallbackNamespace)
                        println("Fixing missing namespace for project ${project.name} -> $fallbackNamespace")
                    }
                } catch (e: Exception) {
                }
            }
        }
    }

    if (state.executed) {
        fixNamespace()
    } else {
        afterEvaluate {
            fixNamespace()
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
