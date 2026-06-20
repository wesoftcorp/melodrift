import com.android.build.gradle.AppExtension

val android = project.extensions.getByType(AppExtension::class.java)

android.apply {
    flavorDimensions("flavor-type")

    productFlavors {
        create("devFoss") {
            dimension = "flavor-type"
            applicationId = "com.melodrift.dev.foss"
            resValue(type = "string", name = "app_name", value = "Melodrift Dev FOSS")
        }
        create("prodFoss") {
            dimension = "flavor-type"
            applicationId = "com.melodrift.foss"
            resValue(type = "string", name = "app_name", value = "Melodrift FOSS")
        }
        create("devFull") {
            dimension = "flavor-type"
            applicationId = "com.melodrift.dev"
            resValue(type = "string", name = "app_name", value = "Melodrift Dev")
        }
        create("prodFull") {
            dimension = "flavor-type"
            applicationId = "com.melodrift"
            resValue(type = "string", name = "app_name", value = "Melodrift")
        }
    }

    buildFeatures.resValues = true
}