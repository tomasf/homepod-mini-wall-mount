import Cadova
import Prepress

/// Everything in place on the wall. The shell and the lid are its printable components; the rest is there to look at.
struct MountAssembly: Geometry3D {
    /// How the excess cable is expected to lie around the spool: radius of each column and layers in it.
    /// Fewer layers on the outside, where the wall screw bosses take up the depth.
    static let coilColumns: [(radius: Double, layers: Int)] = [(22, 4), (26, 4), (30, 2)]

    /// Each piece is a part of its own, so that it can be shown or hidden on its own in a viewer. The printed ones
    /// are components, which the print plate takes from here.
    var body: any Geometry3D {
        // Printed standing on its wall face. Three walls fill its sides completely, for an even surface.
        Shell()
            .inComponent(name: "Shell", upDirection: .forward, color: .white, settings: .wallCount(3))

        // Printed top face down
        Lid().seated
            .inComponent(name: "Lid", upDirection: .down, color: .white)

        HomePodMini()
            .translated(y: HomePodMini.wallDistance, z: -Shell.footSeatDepth)
            .inPart(name: "HomePod mini", semantic: .context, color: .gray)

        coil
            .inPart(name: "Coiled cable", semantic: .context, color: .darkGray)

        cableRuns
            .inPart(name: "Cable", semantic: .context, color: .darkGray)

        Box(x: 160, y: 2, z: 200)
            .aligned(at: .centerX, .maxY)
            .translated(z: -60)
            .inPart(name: "Wall", semantic: .context, color: .lightGray)
    }

    @GeometryBuilder3D
    var coil: any Geometry3D {
        let diameter = HomePodMini.cableDiameter

        for column in Self.coilColumns {
            for layer in 0..<column.layers {
                Circle(diameter: diameter)
                    .translated(x: column.radius)
                    .revolved()
                    .translated(y: Spool.centerOffset, z: -Lid.underside - diameter * (Double(layer) + 0.5) - 0.2)
            }
        }
    }

    /// The cable from the speaker down to the coil, and from the coil up along the wall
    var cableRuns: any Geometry3D {
        // The height of the exit from the speaker is an estimate
        let exit = HomePodMini.wallDistance - 33
        let hole = Lid.cableHoleOffset
        let coilEntry = Vector3D(24, Spool.centerOffset, -9)
        let fromSpeaker = BezierPath3D(startPoint: [0, exit, 7])
            .addingCubicCurve(controlPoint1: [0, exit - 6, 7], controlPoint2: [0, hole + 3, 2.5], end: [0, hole, -1.6])
            .addingCubicCurve(controlPoint1: [0, hole - 5, -8.5], controlPoint2: [0, hole - 9, -9], end: [0, hole - 12, -9])
            // Around the outside of the spool and into the coil
            .addingCubicCurve(
                controlPoint1: [14, coilEntry.y + 25, -9],
                controlPoint2: [coilEntry.x + 3, coilEntry.y + 12, -9],
                end: coilEntry
            )

        let toWall = BezierPath3D(startPoint: [14, 15, -9])
            .addingCubicCurve(controlPoint1: [4, 11, -9], controlPoint2: [0, 5, -9], end: [0, 4, 2])
            .addingLine(to: [0, 4, 60])

        return Circle(diameter: HomePodMini.cableDiameter)
            .swept(along: fromSpeaker, pointing: .positiveY, toward: .direction(.positiveZ))
            .adding {
                Circle(diameter: HomePodMini.cableDiameter)
                    .swept(along: toWall, pointing: .positiveY, toward: .direction(.positiveY))
            }
    }

    /// The length of cable the coil holds
    static var coilCapacity: Double {
        coilColumns.reduce(0) { $0 + Double($1.layers) * 2 * .pi * $1.radius }
    }
}
