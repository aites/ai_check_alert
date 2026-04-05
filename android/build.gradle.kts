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
subprojects {
    project.evaluationDependsOn(":app")
}

// Temporary compatibility patch for AGP 8 + isar_flutter_libs 3.1.0+1.
// AGP 8 forbids `package` in library AndroidManifest; remove it before build.
val patchIsarFlutterLibsManifest by tasks.registering {
    doLast {
        val pubCacheDir = file("${System.getProperty("user.home")}/.pub-cache/hosted/pub.dev")
        if (!pubCacheDir.exists()) return@doLast

        val manifests = fileTree(pubCacheDir) {
            include("isar_flutter_libs-*/android/src/main/AndroidManifest.xml")
        }

        manifests.files.forEach { manifest ->
            val original = manifest.readText()
            val patched = original.replace(" package=\"dev.isar.isar_flutter_libs\"", "")
            if (patched != original) {
                manifest.writeText(patched)
                println("Patched isar manifest: ${manifest.absolutePath}")
            }
        }
    }
}

subprojects {
    tasks.matching { it.name == "preBuild" }.configureEach {
        dependsOn(rootProject.tasks.named("patchIsarFlutterLibsManifest"))
    }
}

// AGP 8+ requires every Android module to declare a namespace.
// Some third-party Flutter plugins still omit it, so we provide a safe fallback.
subprojects {
    pluginManager.withPlugin("com.android.library") {
        val androidExt = extensions.findByName("android") ?: return@withPlugin
        val getNamespace = androidExt.javaClass.methods.find {
            it.name == "getNamespace" && it.parameterCount == 0
        } ?: return@withPlugin
        val setNamespace = androidExt.javaClass.methods.find {
            it.name == "setNamespace" &&
                it.parameterCount == 1 &&
                it.parameterTypes[0] == String::class.java
        } ?: return@withPlugin

        val currentNamespace = getNamespace.invoke(androidExt) as? String
        if (currentNamespace.isNullOrBlank()) {
            val fallbackNamespace = "com.generated.${project.name.replace('-', '_')}"
            setNamespace.invoke(androidExt, fallbackNamespace)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
