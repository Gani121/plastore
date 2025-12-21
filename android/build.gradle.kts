buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.1.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.22")
        classpath("com.google.gms:google-services:4.4.0") // Firebase plugin
    }
}



allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    // --- THIS BLOCK HAS BEEN UPDATED ---
    // ✅ Automatically apply a default namespace to plugins that don't have one
    afterEvaluate {
        // Only run this logic on projects that are actual Android apps or libraries
        if (project.plugins.hasPlugin("com.android.application") || project.plugins.hasPlugin("com.android.library")) {
            
            // Find the 'android' extension
            val androidExtension = project.extensions.findByName("android")

            if (androidExtension != null) {
                // Use reflection to set namespace.
                // This is necessary because the build environment is resolving the
                // old String-based namespace API, not the modern Property-based API.
                try {
                    // Check if namespace is already set
                    val getNamespaceMethod = androidExtension::class.java.getMethod("getNamespace")
                    val currentNamespace = getNamespaceMethod.invoke(androidExtension) as? String

                    if (currentNamespace.isNullOrEmpty()) {
                        // It's not set, so let's infer and set it.
                        val inferredNamespace = project.group.toString().ifEmpty {
                            "com.example.${project.name.replace("-", "_")}"
                        }.toLowerCase() // Namespaces must be lowercase
                        
                        val setNamespaceMethod = androidExtension::class.java.getMethod("setNamespace", String::class.java)
                        setNamespaceMethod.invoke(androidExtension, inferredNamespace)
                        
                        println("✅ Applied missing namespace (via reflection): $inferredNamespace to ${project.name}")
                    }
                } catch (e: Exception) {
                    // This will catch NoMethodFoundException etc.
                    println("⚠️ Could not set namespace for ${project.name} using reflection: ${e.message}")
                }
            }
        }
    }
    // --- END OF UPDATED BLOCK ---
}

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
