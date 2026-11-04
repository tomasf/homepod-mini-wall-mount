import Cadova
import Helical

/// The cover over the coiled cable, sunk into the top of the shell from the wall to just behind the speaker, with the
/// cable spool underneath.
///
/// Modelled as printed: the visible top face is at z = 0 and on the bed, with the underside and spool growing upward.
/// Y is the same as in the model frame. `MountAssembly` flips it into place.
struct Lid: Geometry3D {
    static let thickness = 3.2
    /// How far the top face sits below the shell's, so that it can't stand proud of it however the parts print
    static let recess = 0.2
    /// How far the underside sits below the shell's top face, in the model frame
    static var underside: Double { thickness + recess }
    /// Takes up the flare of the first layers, which would otherwise keep the lid from going down into the shell
    static let edgeChamfer = 0.6

    /// How much of the shell's top is left between the end of the lid's pocket and the speaker's seat
    static let seatMargin = 1.5

    /// Where the top face ends, as close to the speaker's seat as the margin allows. The end slopes back toward the
    /// wall at 45°, matching the shell, which can't overhang.
    static var endOffset: Double {
        @Environment(\.tolerance) var tolerance
        let seatRearEdge = HomePodMini.wallDistance - HomePodMini.footDiameter / 2 - tolerance
        return seatRearEdge - seatMargin - tolerance - recess
    }

    /// Where the underside starts at the wall end. From there the end slopes out from the wall at 45°, so that it
    /// hooks under a matching lip on the shell. The lid is tipped in under the lip and then lowered at the far end,
    /// which needs no room beyond the clearance, so the wall end needs no screw.
    static let wallEndOffset = 1.0

    /// Below where the cable leaves the speaker, about where the sphere starts covering the lid from above
    static var cableHoleOffset: Double { HomePodMini.wallDistance - 45 }
    static let cableNotchWidth = 5.0
    static let cableNotchDepth = 8.0

    static let screw = Bolt.phillipsCountersunkTapping(.st3p5, length: 13)
    /// How much of the lid is left around the screw at the underside, where the sloping end leaves it shortest
    static let screwMargin = 1.5

    /// As far out as the end of the lid allows, where the speaker covers it best
    static var screwOffset: Double {
        @Environment(\.tolerance) var tolerance
        return endOffset - thickness - clearanceDiameter(of: screw, tolerance: tolerance) / 2 - screwMargin
    }

    /// Screw holes get twice the clearance on their diameter, like the ones in the first print that fitted well
    static func clearanceDiameter(of screw: Bolt, tolerance: Double) -> Double {
        screw.thread.majorDiameter + tolerance * 2
    }

    /// The lid in its place in the shell, in the model frame
    var seated: any Geometry3D {
        rotated(y: 180°)
            .translated(z: -Self.recess)
    }

    var body: any Geometry3D {
        @Environment(\.tolerance) var tolerance

        let margin = 1.0
        let cableHoleCornerRadius = 2.0
        let cableNotchCornerRadius = 2.4

        // The lid goes straight down into place, so it can follow the pocket with the same clearance all round
        ArmProfile.plan(from: 0, to: Self.endOffset + margin) { ArmProfile.pocketHalfWidth(at: $0) - tolerance }
            .subtracting {
                // Where the cable goes down from the speaker. Only as large as the plug needs, turned across the arm
                // to leave room for the screw.
                Rectangle(HomePodMini.plugSize + tolerance * 2)
                    .aligned(at: .center)
                    .rounded(radius: cableHoleCornerRadius)
                    .translated(y: Self.cableHoleOffset)

                // Where the cable comes back up along the wall. Open toward the wall, so the plug doesn't have to fit.
                Rectangle(x: Self.cableNotchWidth, y: Self.cableNotchDepth * 2)
                    .aligned(at: .centerX)
                    .translated(y: -Self.cableNotchDepth)
                    .rounded(radius: cableNotchCornerRadius)
            }
            .extruded(height: Self.thickness, bottomEdge: .chamfer(depth: Self.edgeChamfer))
            .intersecting {
                // The sloping ends, as seen from the side with the top face at the bottom
                Polygon([
                    [Self.wallEndOffset + Self.thickness + margin, -margin],
                    [Self.endOffset + margin, -margin],
                    [Self.endOffset - Self.thickness - margin, Self.thickness + margin],
                    [Self.wallEndOffset - margin, Self.thickness + margin],
                ])
                .extrudedAcrossArm(width: ArmProfile.pocketWidth + margin * 2)
            }
            .adding {
                Spool()
                    .translated(y: Spool.centerOffset, z: Self.thickness)
            }
            .subtracting {
                // Countersunk screw, with the head flush with the top face
                Self.screw.clearanceHole(depth: Self.thickness, entry: .recessedHead)
                    .withTolerance(tolerance * 2)
                    .translated(y: Self.screwOffset)
            }
    }
}

/// The core the excess cable is wound around, built upward from the underside of the lid. Three arcs with barbed tips
/// hold the coil while the lid is off. The undersides of the barbs are 45°.
struct Spool: Geometry3D {
    static let coreDiameter = 39.0
    static let wallThickness = 2.0
    static let height = 19.5
    static let barbDepth = 3.0
    static let baseHeight = 2.0
    static let arcSweep = 75°

    /// How far the spool reaches into the lid plate, to fuse with it into a single solid
    static let rootDepth = 1.0

    /// Leaves room for the coil between the spool and the rear wall
    static let centerOffset = 37.0

    var body: any Geometry3D {
        let outerRadius = Self.coreDiameter / 2
        let innerRadius = outerRadius - Self.wallThickness
        let profile = Polygon([
            [innerRadius, -Self.rootDepth],
            [outerRadius, -Self.rootDepth],
            [outerRadius, Self.height - Self.barbDepth],
            [outerRadius + Self.barbDepth, Self.height],
            [innerRadius, Self.height],
        ])

        profile
            .revolved(in: 0°..<Self.arcSweep)
            .rotated(z: 15°)
            .repeated(around: .z, count: 3)
            .adding {
                Cylinder(diameter: Self.coreDiameter, height: Self.baseHeight + Self.rootDepth)
                    .subtracting {
                        Cylinder(diameter: innerRadius * 2, height: Self.baseHeight + Self.rootDepth)
                    }
                    .translated(z: -Self.rootDepth)
            }
    }
}
