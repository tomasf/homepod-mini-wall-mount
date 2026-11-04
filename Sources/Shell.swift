import Cadova
import Helical

/// The part that's screwed to the wall and that the speaker stands on, in the model frame. The lid sits sunk into its
/// top, covering the coil and the wall screws.
struct Shell: Geometry3D {
    /// The foot stands in a shallow recess that keeps the speaker from sliding off
    static let footSeatDepth = 2.0

    // Two screws high up in the wall face: the bottom edge of the shell presses against the wall and acts as the pivot,
    // so they carry the load in tension over the height of the flared root.
    static let wallScrewSpacing = 50.0
    static let wallScrewDepth = 14.0
    static let wallScrewTilt = 15°
    static let wallScrew = Bolt.phillipsCountersunkTapping(.st4p2, length: 25)
    /// How far from the wall the wide end of the countersink is
    static let wallScrewSeat = 5.0
    static let wallScrewBossDiameter = 14.0
    static let wallScrewBossLength = 6.5
    /// The bosses end in a 45° cone over this length, rather than all at once
    static let wallScrewBossTaper = 3.0

    /// Deep enough for a 3.5 × 13 mm screw, measured from the top face
    static let lidScrewPilotEnd = 14.0

    /// Where the pocket for the lid ends at the top face: a clearance beyond the lid, and further by as much as the
    /// lid's slope rises over its recess
    static var pocketEnd: Double {
        @Environment(\.tolerance) var tolerance
        return Lid.endOffset + tolerance + Lid.recess
    }

    var body: any Geometry3D {
        @Environment(\.tolerance) var tolerance

        let margin = 1.0
        let wallScrewHeadClearanceLength = 8.0

        ArmProfile.exterior
            .subtracting {
                ArmProfile.interior
            }
            .adding {
                // Bosses that bury the wall screw heads
                Stack(.z) {
                    Cylinder(diameter: Self.wallScrewBossDiameter, height: Self.wallScrewBossLength - Self.wallScrewBossTaper)
                    Cylinder(
                        bottomDiameter: Self.wallScrewBossDiameter,
                        topDiameter: Self.wallScrewBossDiameter - Self.wallScrewBossTaper * 2,
                        height: Self.wallScrewBossTaper
                    )
                }
                .wallScrewPlaced()
                .symmetry(over: .x)
                .intersecting {
                    ArmProfile.exterior
                }
            }
            .subtracting {
                // Where the lid goes. Both ends slope at 45°: the far one so that it doesn't overhang as printed, and
                // the one at the wall leaving a lip that the lid hooks under.
                ArmProfile.plan(from: -margin, to: Self.pocketEnd + margin, halfWidth: ArmProfile.pocketHalfWidth(at:))
                    .extruded(height: Lid.underside + margin)
                    .translated(z: -Lid.underside)
                    .intersecting {
                        Polygon([
                            [Lid.wallEndOffset - tolerance, -Lid.underside],
                            [Self.pocketEnd - Lid.underside, -Lid.underside],
                            [Self.pocketEnd + margin, margin],
                            [Lid.wallEndOffset - tolerance + Lid.underside + margin, margin],
                        ])
                        .extrudedAcrossArm(width: ArmProfile.pocketWidth + margin * 2)
                    }

                // The cable's way up through the lip, matching the notch in the lid
                Box(x: Lid.cableNotchWidth, y: Lid.cableNotchDepth + margin, z: Lid.underside + margin)
                    .aligned(at: .centerX)
                    .translated(y: -margin, z: -Lid.underside)

                // The seat for the speaker's foot. Flattened where it would overhang as printed, so that it bridges.
                Cylinder(diameter: HomePodMini.footDiameter + tolerance * 2, height: Self.footSeatDepth + margin)
                    .overhangSafe(.bridge)
                    .definingNaturalUpDirection(.positiveY)
                    .translated(y: HomePodMini.wallDistance, z: -Self.footSeatDepth)

                // Wall screws, with the head clearance cut short of the far side of the hollow. They stand close to
                // upright as printed, so they're kept round.
                Self.wallScrew.clearanceHole(depth: Self.wallScrewSeat + margin, entry: .recessedHead)
                    .within(z: (-wallScrewHeadClearanceLength)...)
                    .withTolerance(tolerance * 2)
                    .withCircularOverhangMethod(.none)
                    .flipped(along: .z)
                    .translated(z: Self.wallScrewSeat)
                    .wallScrewPlaced()
                    .symmetry(over: .x)

                // Pilot hole for the lid screw, horizontal as printed. Bridged rather than pointed, so that the thread
                // bites evenly all round.
                Lid.screw.tappingHole(depth: Self.lidScrewPilotEnd)
                    .withCircularOverhangMethod(.bridge)
                    .definingNaturalUpDirection(.positiveY)
                    .flipped(along: .z)
                    .translated(y: Lid.screwOffset)
            }
    }
}

fileprivate extension Geometry3D {
    /// Takes geometry built along +Z, with z = 0 at the wall, to the wall screw's position and tilt
    func wallScrewPlaced() -> any Geometry3D {
        rotated(x: Shell.wallScrewTilt - 90°)
            .translated(x: Shell.wallScrewSpacing / 2, z: -Shell.wallScrewDepth)
    }
}
