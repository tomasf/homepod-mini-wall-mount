import Cadova
import Foundation

/// The outer form of the mount, as a function of the distance `y` from the wall.
///
/// Model frame, used by everything unless stated otherwise: X runs along the wall, Y points out from the wall, Z is
/// up, and the top face of the mount is at z = 0.
///
/// The shape is a pocket at the wall that holds the coiled cable, tapering evenly into an arm that ends in the
/// speaker's seat. Viewed along the arm, each cross section is a superellipse hanging from the top face. The lid sits
/// sunk into the top, inside a rim, so that the seam can't be seen from below. The shell is printed standing on the
/// wall face, which makes the exterior narrow steadily on its way up. The interior can overhang, so its taper has to
/// stay within 45° of the arm's axis.
enum ArmProfile {
    static let pocketWidth = 70.0
    /// Within the speaker's flat underside, so that the mount doesn't show around the foot from the side
    static let armWidth = 52.0
    static let wallThickness = 30.4

    /// The hollow's walls and floor, all equally thick
    static let sideWallThickness = 2.4
    static let rearWallThickness = 3.0
    /// The part of the side walls that rises around the lid, leaving the rest as a ledge for it to rest on
    static let rimThickness = 1.2
    static let topChamfer = 0.6

    /// Where the hollow ends. Its floor rises to meet the lid on the way there, as there's no room between the
    /// coil and the screw for the sides to close in.
    static var interiorLength: Double {
        let pilotMargin = 1.0
        return Lid.screwOffset - Lid.screw.thread.minorDiameter / 2 - pilotMargin
    }

    /// Where the width starts narrowing, past the widest part of the coil
    static let widthTaperStart = 30.0

    static var tipRadius: Double { armWidth / 2 }
    static var length: Double { HomePodMini.wallDistance + tipRadius }

    static func halfWidth(at y: Double) -> Double {
        let taper = smoothstep(y, from: widthTaperStart, to: HomePodMini.wallDistance)
        return (armWidth + (pocketWidth - armWidth) * (1 - taper)) / 2 * tipScale(at: y)
    }

    /// The exponents of the side view's curve: along the arm, and across it. A larger first one keeps the pocket
    /// deep further out, and a smaller second one makes the tip end more abruptly.
    static let thicknessCurveExponents = (along: 1.6, across: 0.6)

    /// Total thickness, from the top face down. Seen from the side, the underside is a single curve from the wall to
    /// the tip: level at the wall, and bending up ever more steeply until it meets the top face at the very end.
    static func thickness(at y: Double) -> Double {
        let t = min(max(y / length, 0), 1)
        return wallThickness * pow(1 - pow(t, thicknessCurveExponents.along), thicknessCurveExponents.across)
    }

    /// The opening the lid sits in
    static func pocketHalfWidth(at y: Double) -> Double {
        halfWidth(at: y) - rimThickness
    }

    /// Squarer in the pocket, to leave room for the coil, and softer along the arm
    static func squareness(at y: Double) -> Double {
        2.6 + 1.4 * (1 - smoothstep(y, from: 60, to: 110))
    }

    /// Rounds the plan outline off into the tip
    private static func tipScale(at y: Double) -> Double {
        let tipStart = length - tipRadius
        guard y > tipStart else { return 1 }
        return sqrt(max(1 - pow((y - tipStart) / tipRadius, 2), 0))
    }

    private static func smoothstep(_ value: Double, from lower: Double, to upper: Double) -> Double {
        let t = min(max((value - lower) / (upper - lower), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// A cross section in a plane perpendicular to the arm. Its X is the model's X and its Y is the depth below the top
    /// face, starting at `top`. `headroom` extends it straight up, for making clean cuts.
    static func crossSection(
        halfWidth: Double,
        depth: Double,
        squareness: Double,
        top: Double = 0,
        headroom: Double = 0
    ) -> any Geometry2D {
        let pointCount = 160
        let exponent = 2 / squareness
        let curve = (0...pointCount).map { index in
            let angle = Double(index) / Double(pointCount) * 180°
            let x = halfWidth * pow(abs(cos(angle)), exponent) * (cos(angle) < 0 ? -1 : 1)
            return Vector2D(x, top + depth * pow(abs(sin(angle)), exponent))
        }

        let closure = headroom > 0
            ? [Vector2D(-halfWidth, top - headroom), Vector2D(halfWidth, top - headroom)]
            : []
        return Polygon(curve + closure)
    }

    /// Lofts the cross sections along the arm from the wall outward, and stands the result in the model frame.
    ///
    /// The loft resamples every section to the segmentation's `minSize` and adds rings until it deviates less than
    /// a micrometre from the blend between them, which at the default segmentation takes gigabytes of memory. This is
    /// still far finer than a printer can reproduce.
    static func lofted(
        at distances: [Double],
        section: @escaping @Sendable (Double) -> any Geometry2D
    ) -> any Geometry3D {
        Loft {
            for y in distances {
                Loft.Section(at: y) {
                    section(y)
                }
            }
        }
        .withSegmentation(minAngle: 2°, minSize: 0.5)
        .rotated(x: -90°)
    }

    /// The outside, lofted from the wall to just short of the tip, where the sections shrink to nothing
    @GeometryBuilder3D
    static var exterior: any Geometry3D {
        let stationSpacing = 2.0
        let tipStationAngle = 2°
        let tipStationCount = 44
        let steps = Int((length - tipRadius) / stationSpacing)
        let bodyStations = (0...steps).map { Double($0) * (length - tipRadius) / Double(steps) }
        let tipStations = (1...tipStationCount).map {
            length - tipRadius + tipRadius * sin(Double($0) * tipStationAngle)
        }

        // The chamfer along the top edge is cut from the exact plan outline. The outline starts behind the wall to
        // keep the wall face unchamfered.
        let capHeight = 1.0
        let margin = 2.0

        lofted(at: bodyStations + tipStations) { y in
            crossSection(halfWidth: halfWidth(at: y), depth: thickness(at: y), squareness: squareness(at: y))
        }
        .intersecting {
            // Unlike the other modifiers, intersecting keeps only what's inside every child, so these are combined
            // first
            Union {
                plan(from: -margin, to: length, halfWidth: halfWidth(at:))
                    .extruded(height: capHeight, topEdge: .chamfer(depth: topChamfer))
                    .translated(z: -capHeight)

                Box(x: pocketWidth + margin, y: length + margin * 2, z: wallThickness + margin)
                    .aligned(at: .centerX, .maxZ)
                    .translated(y: -margin, z: -capHeight)
            }
        }
    }

    /// How far the hollow widens at 45° from the rear wall before reaching its full size, so that the layers don't go
    /// from the solid rear wall to thin walls all at once as printed
    static let rearWallFlare = 10.0

    /// The hollow of the shell, under the lid. Toward the far end its floor rises to meet the lid, a little less
    /// steeply than the 45° it could overhang as printed, as the loft cuts corners between its sections.
    ///
    /// Each section is also kept within the outside's section shrunk by the wall thickness, so that the walls are
    /// equally thick all the way round. Each printed layer is one of these sections, and walls that vary in thickness
    /// make the slicer fill the space between their perimeters with short strokes that start and stop against the
    /// outside, which shows on it as a ragged line.
    @GeometryBuilder3D
    static var interior: any Geometry3D {
        let minimumDepth = 0.1
        let headroom = 1.0
        let stationSpacing = 2.0
        let floorRise = tan(40°)
        let flareEnd = rearWallThickness + rearWallFlare
        let steps = Int((interiorLength - flareEnd) / stationSpacing)
        let stations = [rearWallThickness] + (0...steps).map {
            flareEnd + Double($0) * (interiorLength - flareEnd) / Double(steps)
        }

        lofted(at: stations) { y in
            let inset = max(flareEnd - y, 0)
            let ramp = (interiorLength - y) * floorRise
            // As wide and deep as the outside, so that it only shapes the hollow at the flare and the ramp
            return crossSection(
                halfWidth: halfWidth(at: y) - inset,
                depth: max(min(thickness(at: y) - inset, ramp), minimumDepth),
                squareness: squareness(at: y),
                top: Lid.underside,
                headroom: headroom
            )
            .intersecting {
                crossSection(halfWidth: halfWidth(at: y), depth: thickness(at: y), squareness: squareness(at: y))
                    .offset(amount: -sideWallThickness, style: .round)
            }
        }
    }

    /// A plan outline from `start` to `end` along the arm, symmetric around the arm's axis. Stations are 1 mm apart
    /// along the arm and closer together around the rounded tip.
    static func plan(from start: Double, to end: Double, halfWidth: (Double) -> Double) -> any Geometry2D {
        let tipStart = length - tipRadius
        let bodyEnd = min(end, tipStart)
        let stationSpacing = 1.0
        let tipStationAngle = 2°
        var stations = Array(stride(from: start, to: bodyEnd, by: stationSpacing)) + [bodyEnd]
        if end > tipStart {
            let tipStationCount = Int(90° / tipStationAngle)
            stations += (1...tipStationCount)
                .map { tipStart + tipRadius * sin(Double($0) * tipStationAngle) }
                .filter { $0 < end } + [end]
        }
        let right = stations.map { Vector2D(halfWidth($0), $0) }
        let left = stations.reversed().filter { halfWidth($0) > 1e-9 }.map { Vector2D(-halfWidth($0), $0) }
        return Polygon(right + left)
    }
}

extension Geometry2D {
    /// Extrudes a side view of the arm across it: the profile's X becomes the model's Y and its Y becomes Z, centered
    /// on the arm's axis
    func extrudedAcrossArm(width: Double) -> any Geometry3D {
        extruded(height: width)
            .aligned(at: .centerZ)
            .rotated(x: 90°)
            .rotated(z: 90°)
    }
}
