import Cadova
import Helical
import Testing
@testable import homepod_mini_wall_mount

/// One at a time, as every test builds its own shell and the meshes add up when they run side by side
@Suite(.serialized)
struct FitTests {
    private var seatedLid: any Geometry3D { Lid().seated }

    private func measure<T: Sendable>(_ body: @Sendable (GeometryEvaluator) async -> T) async throws -> T {
        try await ModelFileGenerator.evaluate(environment: { $0.tolerance = 0.2 }, body)
    }

    @Test func `lid and shell do not overlap`() async throws {
        let lid = seatedLid
        let volume = try await measure { evaluator in
            await evaluator.measurements(of: Shell().intersecting { lid }).volume
        }
        #expect(volume < 0.01)
    }

    @Test func `the lid tips in under the lip without extra room`() async throws {
        // The sloping wall end slides along the lip if the lid turns about a point behind the wall, on the line
        // square to the slope through its middle. A flat slope only approximates the arc around that point, which is
        // why the radius is generous: at 30 mm the two part by less than a tenth of a millimetre.
        let radius = 30.0
        let slopeLength = Lid.thickness * 2.squareRoot()
        let slopeMiddle = Vector3D(0, Lid.wallEndOffset + Lid.thickness / 2, -Lid.recess - Lid.thickness / 2)
        let pivot = slopeMiddle + Vector3D(0, -1, 1) * (radius / 2.squareRoot())
        // Turned until the whole slope has slid out from under the lip
        let fullTilt = Angle(radians: slopeLength / radius)
        let tilts = [0.25, 0.5, 0.75, 1].map { fullTilt * $0 }

        let lid = seatedLid
        let volumes = try await measure { evaluator in
            var volumes: [Double] = []
            for tilt in tilts {
                let tipped = lid
                    .translated(-pivot)
                    .rotated(x: tilt)
                    .translated(pivot)
                volumes.append(await evaluator.measurements(of: Shell().intersecting { tipped }).volume)
            }
            return volumes
        }
        #expect(volumes.allSatisfy { $0 < 0.01 })
    }

    @Test func `the lip holds the wall end of the lid down`() async throws {
        let lifted = seatedLid.translated(z: 1)
        let overlap = try await measure { evaluator in
            await evaluator.measurements(of: Shell().intersecting { lifted }).volume
        }
        #expect(overlap > 1)
    }

    @Test func `the lid sits flush inside the rim`() async throws {
        let bounds = try await measure { evaluator in
            await evaluator.bounds(of: Lid().seated)
        }
        let lid = try #require(bounds)
        #expect(abs(lid.maximum.z + Lid.recess) < 0.001)
        #expect(lid.maximum.x <= ArmProfile.pocketHalfWidth(at: 0))
    }

    @Test func `coil fits inside the shell`() async throws {
        let lid = seatedLid
        let coil = MountAssembly().coil
        let (shellOverlap, lidOverlap) = try await measure { evaluator in
            (
                await evaluator.measurements(of: Shell().intersecting { coil }).volume,
                await evaluator.measurements(of: lid.intersecting { coil }).volume
            )
        }
        #expect(shellOverlap < 0.01)
        #expect(lidOverlap < 0.01)
    }

    @Test func `the coil holds the excess cable`() {
        // About 0.1 m from the speaker to the coil, and at least 0.2 m from the coil to an outlet 15 cm above the mount
        let shortestRun = 300.0
        #expect(MountAssembly.coilCapacity >= HomePodMini.cableLength - shortestRun)
    }

    @Test func `the shell's thickness and width change in one continuous slope`() {
        let distances = Array(stride(from: 0.0, through: HomePodMini.wallDistance, by: 1.0))
        for profile in [ArmProfile.thickness(at:), ArmProfile.halfWidth(at:)] {
            let slopes = zip(distances, distances.dropFirst()).map { profile($1) - profile($0) }
            #expect(slopes.allSatisfy { $0 <= 0 })
            // One inflection only: the slope steepens up to a single point and then eases off
            let steepest = slopes.indices.min { slopes[$0] < slopes[$1] }!
            #expect(zip(slopes[..<steepest], slopes[..<steepest].dropFirst()).allSatisfy { $0 >= $1 - 1e-9 })
            #expect(zip(slopes[steepest...], slopes[steepest...].dropFirst()).allSatisfy { $0 <= $1 + 1e-9 })
        }
    }

    @Test func `speaker rests in the seat without digging into the shell`() async throws {
        let (overlap, footBottom) = try await measure { evaluator in
            let speaker = HomePodMini().translated(y: HomePodMini.wallDistance, z: -Shell.footSeatDepth)
            let bounds = await evaluator.bounds(of: speaker)
            return (await evaluator.measurements(of: Shell().intersecting { speaker }).volume, bounds?.minimum.z ?? 0)
        }
        #expect(overlap < 0.01)
        // Sunk into the top face, so that the speaker can't slide off, but no deeper than the foot is thick, so that
        // the sphere stays above it
        #expect(footBottom == -Shell.footSeatDepth)
        #expect(Shell.footSeatDepth <= HomePodMini.footThickness)
    }

    /// Positions and sizes that depend on the tolerance or come from Helical, read the way the geometry reads them
    private struct Layout: Sendable {
        let tolerance: Double
        let endOffset: Double
        let pocketEnd: Double
        let screwOffset: Double
        let interiorLength: Double
        let lidScrewHeadDiameter: Double
        let wallScrewHeadDiameter: Double
    }

    private func layout() async throws -> Layout {
        try await measure { evaluator in
            @Environment(\.tolerance) var tolerance
            // A modelled screw is made smaller by the tolerance, so its head measures that much under nominal
            let lidScrewHead = (await evaluator.bounds(of: Lid.screw)?.size.x ?? 0) + tolerance
            let wallScrewHead = (await evaluator.bounds(of: Shell.wallScrew)?.size.x ?? 0) + tolerance
            return Layout(
                tolerance: tolerance,
                endOffset: Lid.endOffset,
                pocketEnd: Shell.pocketEnd,
                screwOffset: Lid.screwOffset,
                interiorLength: ArmProfile.interiorLength,
                lidScrewHeadDiameter: lidScrewHead,
                wallScrewHeadDiameter: wallScrewHead
            )
        }
    }

    @Test func `the lid ends before the seat, with room around its screw`() async throws {
        let layout = try await layout()
        let tolerance = layout.tolerance
        let seatRearEdge = HomePodMini.wallDistance - HomePodMini.footDiameter / 2 - tolerance
        #expect(layout.pocketEnd + Lid.seatMargin <= seatRearEdge + 0.001)

        // At the top face, where the head is widest, and at the underside, where the lid is shortest
        let headRadius = (layout.lidScrewHeadDiameter + tolerance * 2) / 2
        #expect(layout.screwOffset + headRadius + 2 <= layout.endOffset)
        #expect(
            layout.screwOffset + Lid.clearanceDiameter(of: Lid.screw, tolerance: tolerance) / 2 + Lid.screwMargin
                <= layout.endOffset - Lid.thickness + 0.001
        )

        let cableHoleEnd = Lid.cableHoleOffset + HomePodMini.plugSize.y / 2 + tolerance
        #expect(cableHoleEnd + 1.5 <= layout.screwOffset - headRadius)
    }

    @Test func `the screws fit in the plate, the bosses and the solid arm`() async throws {
        let layout = try await layout()
        // DIN 7982 heads, as Helical has them
        #expect(abs(layout.lidScrewHeadDiameter - 6.8) < 0.05)
        #expect(abs(layout.wallScrewHeadDiameter - 8.1) < 0.05)

        #expect(Lid.screw.headShape.height < Lid.thickness)
        #expect(layout.wallScrewHeadDiameter + layout.tolerance * 2 + 2 * 2 <= Shell.wallScrewBossDiameter)
        #expect(Shell.lidScrewPilotEnd <= ArmProfile.thickness(at: layout.screwOffset) - 1.2)
        #expect(layout.screwOffset - Lid.screw.thread.minorDiameter / 2 > layout.interiorLength)
        // The 3.5 × 13 mm screw has room to bottom out, measured from the top of the head
        #expect(Shell.lidScrewPilotEnd - Lid.recess > Lid.screw.length)
    }

    @Test func `a screwdriver reaches the wall screws`() async throws {
        let shaftDiameter = 6.0
        let shaftLength = 30.0
        let overlap = try await measure { evaluator in
            let shaft = Cylinder(diameter: shaftDiameter, height: shaftLength)
                .translated(z: Shell.wallScrewSeat)
                .rotated(x: Shell.wallScrewTilt - 90°)
                .translated(x: Shell.wallScrewSpacing / 2, z: -Shell.wallScrewDepth)
            return await evaluator.measurements(of: Shell().intersecting { shaft }).volume
        }
        #expect(overlap < 0.01)
    }

    @Test func `the tip stays within the speaker's flat underside`() {
        #expect(abs(HomePodMini.flatDiameter - 53) < 0.5)
        #expect(ArmProfile.armWidth < HomePodMini.flatDiameter)
        #expect(ArmProfile.armWidth >= HomePodMini.footDiameter + 8)
    }

    @Test func `the arm tapers evenly into the tip`() {
        let widths = stride(from: 0.0, through: HomePodMini.wallDistance, by: 2.0).map { ArmProfile.halfWidth(at: $0) * 2 }
        #expect(zip(widths, widths.dropFirst()).allSatisfy { $0 >= $1 })
        #expect(abs(widths.last! - ArmProfile.armWidth) < 0.01)
    }

    @Test func `cable runs clear of lid and shell`() async throws {
        let lid = seatedLid
        let cable = MountAssembly().cableRuns
        let (shellOverlap, lidOverlap) = try await measure { evaluator in
            (
                await evaluator.measurements(of: Shell().intersecting { cable }).volume,
                await evaluator.measurements(of: lid.intersecting { cable }).volume
            )
        }
        #expect(shellOverlap < 0.01)
        #expect(lidOverlap < 0.01)
    }

    @Test func `parts are one piece each`() async throws {
        let (shell, lid) = try await measure { evaluator in
            (await evaluator.components(of: Shell()).count, await evaluator.components(of: Lid()).count)
        }
        #expect(shell == 1)
        #expect(lid == 1)
    }

    @Test func `speaker center sits 120 mm out`() async throws {
        // The seat fits the foot there and nowhere else: a millimetre either way runs it into the seat's edge
        let offsets = [-1.0, 1.0]
        let overlaps = try await measure { evaluator in
            var overlaps: [Double] = []
            for offset in offsets {
                let speaker = HomePodMini()
                    .translated(y: HomePodMini.wallDistance + offset, z: -Shell.footSeatDepth)
                overlaps.append(await evaluator.measurements(of: Shell().intersecting { speaker }).volume)
            }
            return overlaps
        }
        #expect(HomePodMini.wallDistance == 120)
        #expect(overlaps.allSatisfy { $0 > 1 })
    }
}
