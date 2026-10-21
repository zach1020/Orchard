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

@Test func searchIntentNeverEnablesCalculator() {
  for prompt in [
    "Search RuneScape online", "Do a search for RuneScape with Brave",
    "Can you search the web for RuneScape?", "Look up RuneScape", "Search for 137 times 29 online",
  ] {
    #expect(RequestRouting.wantsWebSearch(prompt))
    #expect(!RequestRouting.allowsCalculator(prompt))
  }
  #expect(!RequestRouting.wantsWebSearch("Explain binary search"))
  #expect(!RequestRouting.allowsCalculator("Add a reminder for tomorrow"))
  #expect(RequestRouting.allowsCalculator("What is two plus two?"))
  #expect(RequestRouting.allowsCalculator("Multiply 137 by 29"))
}

@MainActor @Test func disabledSearchExplainsInsteadOfCallingTools() {
  let defaults = UserDefaults(suiteName: "OrchardTests.\(UUID())")!
  let model = ChatModel(loadCredentials: false, preferences: defaults)
  model.available = true
  model.searchKey = "test-key-never-sent"
  model.input = "Do a search for RuneScape with Brave"
  model.send()
  #expect(model.messages.last?.text.contains("Web search is off") == true)
  #expect(model.generation == nil)
  #expect(!model.events.contains { $0.title == "Calculator" })
  model.searchKey = ""
  model.input = "Search RuneScape online"
  model.send()
  #expect(model.messages.last?.text.contains("isn’t configured") == true)
}

@MainActor @Test func calculatorDoesNotLeakIntoTheNextRequest() {
  let model = ChatModel(
    loadCredentials: false, preferences: UserDefaults(suiteName: "OrchardTests.\(UUID())")!)
  #expect(
    model.tools(for: "Multiply 137 by 29", budget: ToolBudget()).contains { $0.name == "calculate" }
  )
  #expect(
    !model.tools(for: "Search RuneScape online", budget: ToolBudget()).contains {
      $0.name == "calculate"
    })
  #expect(
    !model.tools(for: "Tell me about RuneScape", budget: ToolBudget()).contains {
      $0.name == "calculate"
    })
  model.searchKey = "test-key-never-sent"
  model.searchEnabled = true
  #expect(
    model.tools(for: "Search RuneScape online", budget: ToolBudget()).map(\.name) == ["search_web"])
}

@Test func repeatedToolCallsStopBeforeExecutingAgain() async throws {
  let recorder = Recorder()
  let budget = ToolBudget()
  let tool = CalculatorTool(budget: budget, log: { _, result in await recorder.add(result) })
  for _ in 0..<4 { _ = try await tool.call(arguments: .init(operation: "add", a: 1, b: 2)) }
  await #expect(throws: OrchardError.self) {
    try await tool.call(arguments: .init(operation: "add", a: 1, b: 2))
  }
  #expect(await recorder.count == 4)
}

@MainActor @Test(.enabled(if: ProcessInfo.processInfo.environment["ORCHARD_LIVE_TEST"] == "1"))
func liveSearchRouteUsesSearchEvidenceWithoutCalculator() async throws {
  let recorder = Recorder()
  let model = ChatModel(
    loadCredentials: false, preferences: UserDefaults(suiteName: "OrchardTests.\(UUID())")!,
    search: { query, _ in
      await recorder.add(query)
      return [
        .init(
          title: "RuneScape", url: "https://www.runescape.com/",
          description: "RuneScape is a fantasy MMORPG. This is its official homepage.")
      ]
    })
  model.searchKey = "fixture-no-network"
  model.searchEnabled = true
  model.input = "Do a search for RuneScape with Brave"
  model.send()
  await model.generation?.value
  #expect(await recorder.count == 1)
  #expect(await recorder.entries.first == "RuneScape")
  #expect(model.sources.first?.url == "https://www.runescape.com/")
  #expect(!model.events.contains { $0.title == "Calculator" })
  #expect(model.error == nil)
  #expect(model.messages.last?.text.lowercased().contains("runescape") == true)
  print("LIVE SEARCH ROUTE (fixture results): \(model.messages.last?.text ?? "")")
}

@Test func webQueriesExcludeTheProviderAndCommands() {
  #expect(RequestRouting.webQuery("Do a search for RuneScape with Brave") == "RuneScape")
  #expect(RequestRouting.webQuery("Search RuneScape online") == "RuneScape")
  #expect(
    RequestRouting.webQuery("Can you search the web for RuneScape using Brave?") == "RuneScape")
  #expect(
    RequestRouting.webQuery("Search for Brave browser extensions") == "Brave browser extensions")
}

@MainActor @Test func retryPreservesTheDisabledSearchIntent() {
  let model = ChatModel(
    loadCredentials: false, preferences: UserDefaults(suiteName: "OrchardTests.\(UUID())")!)
  model.available = true
  model.searchKey = "test-key-never-sent"
  model.input = "Do a search for RuneScape with Brave"
  model.send()
  model.input = "try again"
  model.send()
  #expect(model.messages.last?.text.contains("Web search is off") == true)
  #expect(model.generation == nil)
  #expect(model.lastSearchPrompt == "Do a search for RuneScape with Brave")
  model.newChat()
  #expect(model.lastSearchPrompt == nil)
}
