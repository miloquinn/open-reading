allprojects {
    repositories {
        google()
        mavenCentral()
        maven(url = "https://jitpack.io")
    }
}

// 仅为主项目设置构建目录，避免跨驱动器问题
subprojects {
    // 只为 app 模块设置自定义构建目录
    if (project.name == "app") {
        val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build/app").get()
        project.layout.buildDirectory.value(newBuildDir)
    }
    // 其他子项目（包括插件）使用默认构建目录
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Configure Java version for all subprojects
subprojects {
    plugins.withType<JavaPlugin> {
        configure<JavaPluginExtension> {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
