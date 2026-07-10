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
    // Workaround: some older Flutter plugins (e.g. flutter_p2p_connection)
    // declare `package` in their AndroidManifest instead of a Gradle
    // `namespace`, which AGP 8 requires. Inject the namespace from the manifest
    // when it is missing. Registered BEFORE evaluationDependsOn so it is not
    // attached to an already-evaluated project.
    afterEvaluate {
        val android = extensions.findByName("android") ?: return@afterEvaluate
        try {
            val getNamespace = android.javaClass.getMethod("getNamespace")
            if (getNamespace.invoke(android) == null) {
                val manifest = file("src/main/AndroidManifest.xml")
                if (manifest.exists()) {
                    val match =
                        Regex("package=\"([^\"]+)\"").find(manifest.readText())
                    if (match != null) {
                        android.javaClass
                            .getMethod("setNamespace", String::class.java)
                            .invoke(android, match.groupValues[1])
                    }
                }
            }
        } catch (_: Exception) {
        }
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
