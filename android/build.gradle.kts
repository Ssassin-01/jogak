allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val rootProjectBuildDir = rootProject.layout.buildDirectory
rootProjectBuildDir.set(rootProject.layout.projectDirectory.dir("../build"))

subprojects {
    project.layout.buildDirectory.set(rootProjectBuildDir.dir(project.name))
    
    // 🔥 타이밍 에러(already evaluated)를 피하는 안전한 이름표 부착 방식
    if (project.name == "isar_flutter_libs") {
        project.pluginManager.withPlugin("com.android.library") {
            try {
                val androidExt = project.extensions.findByName("android")
                androidExt?.javaClass?.methods?.find { it.name == "setNamespace" }?.invoke(androidExt, "dev.isar.isar_flutter_libs")
            } catch (e: Exception) {
                // 무시
            }
        }
    }

    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}