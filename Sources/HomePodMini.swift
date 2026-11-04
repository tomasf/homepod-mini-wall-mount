import Cadova

/// The speaker, standing on the z = 0 plane with its foot centered on the origin. Used for context only.
struct HomePodMini: Geometry3D {
    static let diameter = 97.9
    static let height = 84.3
    static let footDiameter = 44.0
    static let footThickness = 2.0
    static let cableDiameter = 4.0
    /// 6 ft, as stated by the user. Not measured.
    static let cableLength = 1829.0
    /// Width and thickness. An upper bound rather than a measurement: the plug passed through the 12 × 8 mm channel of
    /// an earlier mount.
    static let plugSize = Vector2D(12, 8)

    /// Where the middle of the speaker should end up, measured from the wall
    static let wallDistance = 120.0

    /// The sphere is truncated by the same amount at the top and at the bottom
    static var sphereHeight: Double { height - footThickness }
    static var flatDiameter: Double { (diameter * diameter - sphereHeight * sphereHeight).squareRoot() }

    var body: any Geometry3D {
        Stack(.z) {
            Cylinder(diameter: Self.footDiameter, height: Self.footThickness)

            Sphere(diameter: Self.diameter)
                .within(z: (-Self.sphereHeight / 2)...(Self.sphereHeight / 2))
        }
    }
}
