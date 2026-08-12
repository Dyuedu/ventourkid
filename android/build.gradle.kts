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

// Force Java/Kotlin 17 for all Flutter plugins that still ship Java 1.8
// (map4d_map, flutter_webrtc, …). Avoid evaluationDependsOn+afterEvaluate conflict.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { androidExt ->
            try {
                val compileOptions =
                    androidExt.javaClass.getMethod("getCompileOptions").invoke(androidExt)
                val setSource =
                    compileOptions.javaClass.methods.first { it.name == "setSourceCompatibility" }
                val setTarget =
                    compileOptions.javaClass.methods.first { it.name == "setTargetCompatibility" }
                setSource.invoke(compileOptions, JavaVersion.VERSION_17)
                setTarget.invoke(compileOptions, JavaVersion.VERSION_17)
            } catch (_: Exception) {
                // ignore non-Android modules
            }
        }
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
