buildscript {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    dependencies {
        // Use 8.9.1 instead (8.10.2 might not be released yet)
        classpath("com.android.tools.build:gradle:8.9.1")
        classpath("org.jetbrains.kotlin.android:org.jetbrains.kotlin.android.gradle.plugin:2.1.0")
        classpath("com.google.gms:google-services:4.4.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.application") || project.plugins.hasPlugin("com.android.library")) {
            
            val androidExtension = project.extensions.findByName("android")

            if (androidExtension != null) {
                try {
                    val getNamespaceMethod = androidExtension::class.java.getMethod("getNamespace")
                    val currentNamespace = getNamespaceMethod.invoke(androidExtension) as? String

                    if (currentNamespace.isNullOrEmpty()) {
                        val inferredNamespace = project.group.toString().ifEmpty {
                            "com.example.${project.name.replace("-", "_")}"
                        }.toLowerCase()
                        
                        val setNamespaceMethod = androidExtension::class.java.getMethod("setNamespace", String::class.java)
                        setNamespaceMethod.invoke(androidExtension, inferredNamespace)
                        
                        println("✅ Applied missing namespace: $inferredNamespace to ${project.name}")
                    }
                } catch (e: Exception) {
                    println("⚠️ Could not set namespace for ${project.name}: ${e.message}")
                }
            }
        }
    }
}

// REMOVE OR COMMENT OUT THESE LINES - They're causing the conflict
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}