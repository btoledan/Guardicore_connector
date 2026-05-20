// ProxyJumpTests.swift — SSHKitTests
// Validates ProxyJumpChain argv construction for 1-, 2-, and 3-hop topologies.

import XCTest
@testable import SSHKit

final class ProxyJumpTests: XCTestCase {

    // MARK: - Fixtures

    private let bastionHop = ProxyJumpHop(user: "ec2-user", host: "bastion.example.com", port: 22)
    private let midHop     = ProxyJumpHop(user: "admin",    host: "jump2.example.com",   port: 2222)
    private let targetDesc = SSHSessionDescriptor(
        name:     "target",
        host:     "10.0.1.50",
        port:     22,
        username: "deploy"
    )

    // MARK: - jumpString

    func test_hop_jumpString_standardPort_omitsPort() {
        let hop = ProxyJumpHop(user: "admin", host: "jump.example.com", port: 22)
        XCTAssertEqual(hop.jumpString, "admin@jump.example.com")
    }

    func test_hop_jumpString_nonStandardPort_includesPort() {
        let hop = ProxyJumpHop(user: "admin", host: "jump.example.com", port: 2222)
        XCTAssertEqual(hop.jumpString, "admin@jump.example.com:2222")
    }

    func test_hop_jumpString_aliasPreferred() {
        let hop = ProxyJumpHop(sshConfigAlias: "bastion-prod", user: "ec2-user",
                               host: "bastion.prod.example.com", port: 22)
        XCTAssertEqual(hop.jumpString, "bastion-prod")
    }

    // MARK: - proxyJumpArgument

    func test_emptyChain_proxyJumpArgument_isNil() {
        let chain = ProxyJumpChain()
        XCTAssertNil(chain.proxyJumpArgument)
    }

    func test_singleHop_proxyJumpArgument() {
        let chain = ProxyJumpChain(hops: [bastionHop])
        XCTAssertEqual(chain.proxyJumpArgument, "ec2-user@bastion.example.com")
    }

    func test_twoHop_proxyJumpArgument_commaJoined() {
        let chain = ProxyJumpChain(hops: [bastionHop, midHop])
        XCTAssertEqual(chain.proxyJumpArgument, "ec2-user@bastion.example.com,admin@jump2.example.com:2222")
    }

    // MARK: - sshArgv (direct / 1-hop / 2-hop)

    func test_directConnection_argv_noJFlag() {
        let chain = ProxyJumpChain()
        let argv  = chain.sshArgv(for: targetDesc)
        XCTAssertFalse(argv.contains("-J"), "Direct connection should not have -J flag")
        XCTAssert(argv.contains("deploy@10.0.1.50"))
    }

    func test_singleHop_argv_hasJFlag() {
        let chain = ProxyJumpChain(hops: [bastionHop])
        let argv  = chain.sshArgv(for: targetDesc)
        XCTAssertTrue(argv.contains("-J"))
        let jIdx  = try! XCTUnwrap(argv.firstIndex(of: "-J"))
        XCTAssertEqual(argv[jIdx + 1], "ec2-user@bastion.example.com")
        XCTAssert(argv.contains("deploy@10.0.1.50"))
    }

    func test_twoHop_argv_hasJFlagWithComma() {
        let chain = ProxyJumpChain(hops: [bastionHop, midHop])
        let argv  = chain.sshArgv(for: targetDesc)
        let jIdx  = try! XCTUnwrap(argv.firstIndex(of: "-J"))
        XCTAssert(argv[jIdx + 1].contains(","), "Two-hop -J value must contain comma")
    }

    func test_argv_nonStandardTargetPort_hasPFlag() {
        let desc  = SSHSessionDescriptor(name: "t", host: "10.0.1.50", port: 2222, username: "admin")
        let chain = ProxyJumpChain()
        let argv  = chain.sshArgv(for: desc)
        XCTAssert(argv.contains("-p"))
        let pIdx  = try! XCTUnwrap(argv.firstIndex(of: "-p"))
        XCTAssertEqual(argv[pIdx + 1], "2222")
    }

    func test_argv_standardPort_noPFlag() {
        let chain = ProxyJumpChain()
        let argv  = chain.sshArgv(for: targetDesc)
        XCTAssertFalse(argv.contains("-p"))
    }

    func test_argv_x11Forwarding_hasXFlag() {
        var desc = targetDesc
        desc = SSHSessionDescriptor(name: "t", host: "10.0.1.50", port: 22, username: "admin",
                                    x11Forwarding: true)
        let argv = ProxyJumpChain().sshArgv(for: desc)
        XCTAssert(argv.contains("-X"))
    }

    func test_argv_agentForwarding_hasAFlag() {
        let desc = SSHSessionDescriptor(name: "t", host: "10.0.1.50", port: 22, username: "admin",
                                        agentForwarding: true)
        let argv = ProxyJumpChain().sshArgv(for: desc)
        XCTAssert(argv.contains("-A"))
    }

    func test_argv_identityFile_hasIFlag() {
        let desc = SSHSessionDescriptor(name: "t", host: "10.0.1.50", port: 22, username: "admin",
                                        identityFile: "/Users/me/.ssh/id_ed25519")
        let argv = ProxyJumpChain().sshArgv(for: desc)
        XCTAssert(argv.contains("-i"))
        let iIdx = try! XCTUnwrap(argv.firstIndex(of: "-i"))
        XCTAssert(argv[iIdx + 1].hasSuffix("id_ed25519"))
    }

    // MARK: - Tunnel argv

    func test_tunnelArgv_hasNFlag() {
        let tunnel = TunnelDescriptor(localPort: 8080, remoteHost: "localhost", remotePort: 80)
        let chain  = ProxyJumpChain()
        let argv   = chain.tunnelArgv(for: targetDesc, tunnels: [tunnel])
        XCTAssert(argv.contains("-N"))
        XCTAssert(argv.contains("-L"))
    }

    func test_tunnelOneLiner_containsSSHFlags() {
        let tunnel = TunnelDescriptor(
            label: "web",
            kind:  .local,
            localBindAddress: "127.0.0.1",
            localPort: 8080,
            remoteHost: "webserver",
            remotePort: 80
        )
        let liner = tunnel.oneLiner(sshTarget: "admin@jump.example.com")
        XCTAssert(liner.hasPrefix("ssh"))
        XCTAssert(liner.contains("-L"))
        XCTAssert(liner.contains("8080"))
        XCTAssert(liner.contains("-N"))
    }

    // MARK: - Hop test argv

    func test_testArgv_noChain_directTestConnection() {
        let hop  = ProxyJumpHop(user: "admin", host: "jump.example.com", port: 22)
        let chain = ProxyJumpChain()
        let argv  = chain.testArgv(through: [], testing: hop)
        XCTAssert(argv.contains("-W"))
        XCTAssert(argv.contains("admin@jump.example.com"))
    }

    func test_testArgv_withPreviousHop_hasJFlag() {
        let chain = ProxyJumpChain()
        let argv  = chain.testArgv(through: [bastionHop], testing: midHop)
        XCTAssert(argv.contains("-J"), "Testing through a previous hop should add -J")
    }

    // MARK: - SSH one-liner

    func test_sshOneLiner_format() {
        let desc  = SSHSessionDescriptor(name: "t", host: "myserver.com", port: 22, username: "admin")
        let chain = ProxyJumpChain(hops: [bastionHop])
        let liner = desc.sshOneLiner(chain: chain)
        XCTAssert(liner.hasPrefix("/usr/bin/ssh"))
        XCTAssert(liner.contains("admin@myserver.com"))
        XCTAssert(liner.contains("-J"))
    }
}
