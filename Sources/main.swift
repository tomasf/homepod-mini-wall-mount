import Cadova
import Prepress

await Project {
    Metadata(title: "HomePod mini wall mount")

    Environment {
        $0.tolerance = 0.2
        $0.circularOverhangMethod = .teardrop
    }

    // Both parts taken from the assembly, stood up in their print orientations and laid out on one plate
    await Model("Print plate") {
        MountAssembly()
            .onPlatter()
    }

    await Model("Assembly") {
        MountAssembly()
    }
}
