// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Orchard", platforms: [.macOS(.v26)],
  products: [.executable(name: "Orchard", targets: ["Orchard"])],
  dependencies: [
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0")
  ],
  targets: [
    .executableTarget(
      name: "Orchard", dependencies: [.product(name: "MCP", package: "swift-sdk")],
      resources: [.process("Resources")]),
    .testTarget(name: "OrchardTests", dependencies: ["Orchard"]),
  ])
