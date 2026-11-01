import XCTest
@testable import KopruCore

final class SSHConfigTests: XCTestCase {
    func testParsesAliasesAndSkipsWildcards() {
        let cfg = "Host *\n  User x\nHost win-pc office\n  HostName 1.2.3.4\nhost laptop\n"
        XCTAssertEqual(SSHConfig.parseAliases(cfg), ["win-pc", "office", "laptop"])
    }
}
