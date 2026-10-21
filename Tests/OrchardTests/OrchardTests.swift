import Foundation
import FoundationModels
import MCP
import Testing

@testable import Orchard

@Test func calculatorHandlesInvalidOperations() throws {
  #expect(try CalculatorTool.evaluate("multiply", 137, 29) == 3973)
  #expect(throws: OrchardError.self) { try CalculatorTool.evaluate("divide", 2, 0) }
  #expect(throws: OrchardError.self) { try CalculatorTool.evaluate("power", 2, 5) }
  #expect(throws: OrchardError.self) {
    try CalculatorTool.evaluate("multiply", .greatestFiniteMagnitude, 2)
  }
}
@Test func searchParsesResultsAndRejectsMalformedData() throws {
  let data = Data(
    #"{"web":{"results":[{"title":"Apple","url":"https://apple.com","description":"Official site"}]}}"#
      .utf8)
  #expect(try WebSearch.parse(data).first?.url == "https://apple.com")
  #expect(try WebSearch.parse(Data("{}".utf8)).isEmpty)
  #expect(throws: (any Error).self) { try WebSearch.parse(Data("<html>error</html>".utf8)) }
}
@Test func mcpArgumentsMustBeObjects() throws {
  #expect(try MCPBridgeTool.decode(#"{"a":137,"b":29}"#).count == 2)
  #expect(throws: (any Error).self) { try MCPBridgeTool.decode("[1,2]") }
  #expect(throws: (any Error).self) { try MCPBridgeTool.decode("not JSON") }
}
actor Recorder {
  var entries: [String] = []
  func add(_ value: String) { entries.append(value) }
  var count: Int { entries.count }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["ORCHARD_LIVE_TEST"] == "1"))
func liveModelUsesCalculator() async throws {
  #expect(SystemLanguageModel.default.isAvailable)
  let recorder = Recorder()
  let tool = CalculatorTool(log: { name, result in await recorder.add(name + result) })
  let session = LanguageModelSession(
    tools: [tool],
    instructions: "Always use calculate for arithmetic. Answer concisely with the result.")
  let response = try await session.respond(to: "Use calculate to multiply 137 by 29.")
  #expect(await recorder.count > 0)
  #expect(response.content.contains("3973") || response.content.contains("3,973"))
  print("LIVE MODEL: \(response.content)")
}

@Test func stdioMCPHandshakeAndToolCall() async throws {
  let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent()
  let process = Process()
  let input = Pipe()
  let output = Pipe()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
  process.arguments = [root.appendingPathComponent("Examples/calculator_server.py").path]
  process.standardInput = input
  process.standardOutput = output
  process.standardError = FileHandle.nullDevice
  try process.run()
  defer { if process.isRunning { process.terminate() } }
  let client = Client(name: "OrchardTests", version: "1")
  try await client.connect(
    transport: StdioTransport(
      input: .init(rawValue: output.fileHandleForReading.fileDescriptor),
      output: .init(rawValue: input.fileHandleForWriting.fileDescriptor)))
  let (tools, _) = try await client.listTools()
  #expect(tools.first?.name == "multiply_numbers")
  let tool = MCPBridgeTool(
    name: "test_mcp", description: "test", originalName: "multiply_numbers", client: client,
    approve: { _, _ in true }, log: { _, _ in })
  let result = try await tool.call(arguments: .init(json: #"{"a":137,"b":29}"#))
  #expect(result.contains("3973"))
  let declined = MCPBridgeTool(
    name: "test_decline", description: "test", originalName: "multiply_numbers", client: client,
    approve: { _, _ in false }, log: { _, _ in })
  #expect(try await declined.call(arguments: .init(json: "{}")).contains("declined"))
  await client.disconnect()
}
