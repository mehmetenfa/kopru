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
    func testNormalizeHost() {
        XCTAssertEqual(SSHSession.normalizeHost("ssh a_b@pc1"), "a_b@pc1")
        XCTAssertEqual(SSHSession.normalizeHost("  a_b@pc1  "), "a_b@pc1")
        XCTAssertEqual(SSHSession.normalizeHost("win-pc"), "win-pc")
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

final class DeviceTests: XCTestCase {
    func testDefaultName() {
        XCTAssertEqual(Device.defaultName(for: "ad@misalpc1"), "misalpc1")
        XCTAssertEqual(Device.defaultName(for: "win-pc"), "win-pc")
    }
    func testRememberAddsMovesToTopAndKeepsName() {
        let t0 = Date(timeIntervalSince1970: 1000), t1 = Date(timeIntervalSince1970: 2000), t2 = Date(timeIntervalSince1970: 3000)
        var l = Device.remembering("ssh a@pc1", in: [], now: t0)          // "ssh " temizlenir
        XCTAssertEqual(l.map(\.host), ["a@pc1"])
        l = Device.remembering("b@pc2", in: l, now: t1)
        XCTAssertEqual(l.map(\.host), ["b@pc2", "a@pc1"])
        l[1].name = "Ofis"                                                // yeniden adlandır
        l = Device.remembering("a@pc1", in: l, now: t2)
        XCTAssertEqual(l.map(\.host), ["a@pc1", "b@pc2"])
        XCTAssertEqual(l[0].name, "Ofis")                                 // ad korunur
        XCTAssertEqual(l.count, 2)                                        // tekrar eklenmez
    }
    func testNeverConnectedSortedLast() {
        let l = Device.sorted([Device(host: "z"), Device(host: "a", lastConnected: Date()), Device(host: "b")])
        XCTAssertEqual(l.map(\.host), ["a", "b", "z"])
    }
    func testCodableRoundTrip() throws {
        let d = [Device(host: "a@pc", name: "Ev", lastConnected: Date(timeIntervalSince1970: 5))]
        XCTAssertEqual(try JSONDecoder().decode([Device].self, from: JSONEncoder().encode(d)), d)
    }
}

final class ConnectionCheckTests: XCTestCase {
    func testTailnetPolicy() {
        let e = ConnectionCheck.explain(stderr: "tailscale: tailnet policy does not permit you to SSH as user \"ssh x\"\nConnection closed by 100.1.2.3 port 22")
        XCTAssertTrue(e.title.contains("izin"))
    }
    func testTailscaleApprovalLink() {
        let s = "# Tailscale SSH requires an additional check.\n# To authenticate, visit: https://login.tailscale.com/a/l1450021f3081a5\n"
        let e = ConnectionCheck.explain(stderr: s, timedOut: true)
        XCTAssertEqual(e.link?.absoluteString, "https://login.tailscale.com/a/l1450021f3081a5")
    }
    func testCommonErrors() {
        XCTAssertTrue(ConnectionCheck.explain(stderr: "u@h: Permission denied (publickey).").title.contains("anahtar"))
        XCTAssertEqual(ConnectionCheck.explain(stderr: "ssh: Could not resolve hostname foo: nodename nor servname provided, or not known").title, "Adres bulunamadı")
        XCTAssertTrue(ConnectionCheck.explain(stderr: "ssh: connect to host 1.2.3.4 port 22: Connection refused").title.contains("SSH sunucusu"))
        XCTAssertTrue(ConnectionCheck.explain(stderr: "ssh: connect to host 1.2.3.4 port 22: Operation timed out").title.contains("ulaşılamıyor"))
        XCTAssertTrue(ConnectionCheck.explain(stderr: "'eval' is not recognized as an internal or external command").title.contains("WSL"))
    }
    func testHostCannotBeAnOption() {
        XCTAssertEqual(SSHSession.normalizeHost("-oProxyCommand=evil"), "")
        XCTAssertEqual(SSHSession.normalizeHost("ssh a@b"), "a@b")
    }
}
