// SSHConfigParserTests.swift — SSHKitTests
// Golden-file round-trip and structured parsing validation.

import XCTest
@testable import SSHKit

final class SSHConfigParserTests: XCTestCase {

    // MARK: - Fixture URL

    private var fixtureURL: URL {
        Bundle(for: type(of: self)).resourceURL!
            .appendingPathComponent("Fixtures/ssh_config_complex")
    }

    // MARK: - Round-trip

    func test_roundTrip_preservesFileByteForByte() throws {
        let original = try String(contentsOf: fixtureURL, encoding: .utf8)
        let config   = SSHConfigParser.parse(string: original)
        let output   = SSHConfigWriter.serialize(config)
        XCTAssertEqual(output, original,
                       "serialize(parse(x)) must equal x — round-trip broken")
    }

    // MARK: - Block count

    func test_parse_findsAllHostBlocks() throws {
        let config = try SSHConfigParser.parse(at: fixtureURL)
        // Fixture has: bastion-prod, app-server, db-primary, openshift-api,
        //              lab-*, lab-node1, lab-node2, deep-target, *  = 9 Host blocks
        XCTAssertEqual(config.blocks.count, 9)
    }

    // MARK: - Preamble

    func test_parse_globalOptionsInPreamble() throws {
        let config = try SSHConfigParser.parse(at: fixtureURL)
        let serverAlive = config.preambleLines
            .first(where: { $0.contains("ServerAliveInterval") })
        XCTAssertNotNil(serverAlive, "Global ServerAliveInterval should appear in preamble")
    }

    // MARK: - Block lookup

    func test_block_byAlias_isCaseInsensitive() throws {
        let config = try SSHConfigParser.parse(at: fixtureURL)
        XCTAssertNotNil(config.block(forAlias: "BASTION-PROD"))
        XCTAssertNotNil(config.block(forAlias: "bastion-prod"))
    }

    func test_block_keyLookup() throws {
        let config = try SSHConfigParser.parse(at: fixtureURL)
        let block  = try XCTUnwrap(config.block(forAlias: "app-server"))
        XCTAssertEqual(block["hostname"], "10.0.1.50")
        XCTAssertEqual(block["user"],     "deploy")
        XCTAssertEqual(block["ProxyJump"], "bastion-prod")
    }

    // MARK: - ProxyJump field

    func test_deepTarget_multiHopProxyJump() throws {
        let config  = try SSHConfigParser.parse(at: fixtureURL)
        let block   = try XCTUnwrap(config.block(forAlias: "deep-target"))
        let pj      = try XCTUnwrap(block["ProxyJump"])
        XCTAssert(pj.contains(","), "Multi-hop ProxyJump should have comma separator")
    }

    // MARK: - Mutation & round-trip after edit

    func test_set_key_updatesRawLines() throws {
        var config = try SSHConfigParser.parse(at: fixtureURL)
        let idx    = config.blocks.firstIndex { $0.hostPattern == "bastion-prod" }!
        config.blocks[idx].set(key: "Port", value: "2222")

        XCTAssertEqual(config.blocks[idx]["Port"], "2222")
        let raw = config.blocks[idx].rawLines.first { $0.contains("Port") }
        XCTAssertNotNil(raw)
        XCTAssert(raw!.contains("2222"), "rawLines should reflect updated port")
    }

    func test_remove_key_removesFromRawLines() throws {
        var config = try SSHConfigParser.parse(at: fixtureURL)
        let idx    = config.blocks.firstIndex { $0.hostPattern == "openshift-api" }!
        config.blocks[idx].remove(key: "StrictHostKeyChecking")

        XCTAssertNil(config.blocks[idx]["StrictHostKeyChecking"])
        let hasLine = config.blocks[idx].rawLines.contains { $0.lowercased().contains("stricthostkeychecking") }
        XCTAssertFalse(hasLine, "rawLines should not contain removed key")
    }

    // MARK: - Upsert

    func test_upsert_newBlock_appendsToBlocks() throws {
        var config = try SSHConfigParser.parse(at: fixtureURL)
        let original = config.blocks.count
        let newBlock = SSHConfigWriter.makeHostBlock(
            pattern:  "new-host",
            hostname: "new.example.com",
            user:     "newuser"
        )
        config.upsert(block: newBlock)
        XCTAssertEqual(config.blocks.count, original + 1)
    }

    func test_upsert_existingAlias_replacesBlock() throws {
        var config = try SSHConfigParser.parse(at: fixtureURL)
        let original = config.blocks.count
        let updated  = SSHConfigWriter.makeHostBlock(
            pattern:  "bastion-prod",
            hostname: "new.bastion.example.com",
            user:     "admin"
        )
        config.upsert(block: updated)
        XCTAssertEqual(config.blocks.count, original, "Replace should not increase count")
        XCTAssertEqual(config.block(forAlias: "bastion-prod")?["HostName"], "new.bastion.example.com")
    }

    // MARK: - Empty file

    func test_parse_emptyString_returnsEmptyConfig() {
        let config = SSHConfigParser.parse(string: "")
        XCTAssertTrue(config.blocks.isEmpty)
        XCTAssertTrue(config.preambleLines.isEmpty)
    }

    // MARK: - Comments

    func test_parse_inlineComments_preserved() throws {
        let fixture = """
Host myhost
    # This is a comment
    HostName example.com
    User admin
"""
        let config = SSHConfigParser.parse(string: fixture)
        XCTAssertEqual(config.blocks.count, 1)
        let hasComment = config.blocks[0].rawLines.contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
        XCTAssertTrue(hasComment, "Comments inside blocks should be preserved in rawLines")
    }

    // MARK: - Non-existent file

    func test_parse_missingFile_returnsEmpty() throws {
        let missing = URL(fileURLWithPath: "/tmp/helmsman_nonexistent_\(UUID().uuidString)")
        let config  = try SSHConfigParser.parse(at: missing)
        XCTAssertTrue(config.blocks.isEmpty)
    }
}
