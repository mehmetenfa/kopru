import XCTest
@testable import KopruCore

final class EngineTests: XCTestCase {
    func testShellQuote() {
        XCTAssertEqual(SSHSession.shq("a b"), "'a b'")
        XCTAssertEqual(SSHSession.shq("it's"), "'it'\\''s'")
    }
    func testShellQuoteASCII() {
        XCTAssertEqual(SSHSession.shqASCII("/tmp/a b"), "'/tmp/a b'")
        XCTAssertEqual(SSHSession.shqASCII("klasör"), #"'klas'$'\303'$'\266''r'"#)
        XCTAssertTrue(SSHSession.shqASCII("İü şç").allSatisfy { $0.isASCII })
    }
    func testUniqueName() {
        let taken: Set<String> = ["a.txt", "a (2).txt", "b"]
        XCTAssertEqual(uniqueName("c.txt") { taken.contains($0) }, "c.txt")
        XCTAssertEqual(uniqueName("a.txt") { taken.contains($0) }, "a (3).txt")
        XCTAssertEqual(uniqueName("b") { taken.contains($0) }, "b (2)")
    }
    func testSpeedMeter() {
        var m = SpeedMeter(window: 6)
        _ = m.add(0, at: 0)
        XCTAssertEqual(m.add(10_000_000, at: 1), 10_000_000, accuracy: 1)
        XCTAssertEqual(m.add(30_000_000, at: 2), 15_000_000, accuracy: 1)
    }
    func testSpaceCheck() {
        XCTAssertNoThrow(try SpaceCheck.require(needed: 1_000, free: 10_000_000_000, where: "Mac"))
        XCTAssertThrowsError(try SpaceCheck.require(needed: 50_000_000_000, free: 29_000_000_000, where: "Mac"))
    }
    func testProgressText() {
        XCTAssertEqual(TransferProgress.duration(45), "45 sn")
        XCTAssertEqual(TransferProgress.duration(720), "12 dk")
        XCTAssertEqual(TransferProgress.duration(3900), "1 sa 5 dk")
        XCTAssertEqual(TransferProgress(phase: .transferring, bytesDone: 50, bytesTotal: 100).fraction, 0.5)
    }
}
