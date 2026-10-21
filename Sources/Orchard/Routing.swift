import Foundation

/// Explicit requests are routed before the language model sees any tools.
enum RequestRouting {
  static func wantsWebSearch(_ prompt: String) -> Bool {
    let pattern =
      #"(?i)^\s*(?:(?:please|can you|could you|would you|will you)\s+)*(?:do\s+(?:a\s+)?(?:web\s+)?search\b|search\b|google\b|look\s+up\b|browse\s+(?:the\s+)?(?:web|internet)\b)|\b(?:search|look\s+up|find)\b.+\b(?:online|on the web|on the internet|with brave|using brave)\b"#
    return prompt.range(of: pattern, options: .regularExpression) != nil
  }

  static func isRetry(_ prompt: String) -> Bool {
    prompt.range(
      of: #"(?i)^\s*(?:please\s+)?(?:try again|retry|search again|try the search again)[.!?]*\s*$"#,
      options: .regularExpression) != nil
  }

  static func webQuery(_ prompt: String) -> String {
    var query = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    let prefixes = [
      #"(?i)^(?:(?:please|can you|could you|would you|will you)\s+)+"#,
      #"(?i)^(?:do\s+(?:a\s+)?(?:web\s+)?search|search(?:\s+(?:the\s+)?(?:web|internet|online))?|look\s+up|google|browse\s+(?:the\s+)?(?:web|internet))\s+(?:for\s+)?"#,
    ]
    for pattern in prefixes {
      query = query.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }
    query = query.replacingOccurrences(
      of: #"(?i)\s+(?:with|using|on)\s+(?:brave(?:\s+search)?|google|the web|the internet)[.!?]*$"#,
      with: "", options: .regularExpression)
    query = query.replacingOccurrences(
      of: #"(?i)\s+online[.!?]*$"#, with: "", options: .regularExpression)
    query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return query.isEmpty ? prompt : query
  }

  static func allowsCalculator(_ prompt: String) -> Bool {
    guard !wantsWebSearch(prompt) else { return false }
    let numbers = prompt.matches(
      of:
        /(?i)\b(?:\d+(?:\.\d+)?|zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\b/
    ).count
    guard numbers >= 2 else { return false }
    return prompt.range(
      of:
        #"(?i)\b(calculate|calculator|multiply|multiplied|divide|divided|subtract|add|sum|plus|minus|times|product|difference|quotient)\b|[+*/×÷]|\d\s*-\s*\d|\d\s*x\s*\d"#,
      options: .regularExpression) != nil
  }

  static func isSearchTool(name: String, description: String) -> Bool {
    let text = name.replacingOccurrences(of: "_", with: " ") + " " + description
    return text.range(of: #"(?i)\b(search|browse|web|internet)\b"#, options: .regularExpression)
      != nil
  }

  static func searchUnavailable(keyPresent: Bool) -> String {
    keyPresent
      ? "Web search is off. Turn on Web search in the sidebar, then send your request again. I haven’t searched online."
      : "Web search isn’t configured yet. Add a Brave Search API key in Settings and enable Web search, or connect a search MCP server. I haven’t searched online."
  }
}

/// Shared across the tools in one response. Throwing ends generation instead of feeding an error loop.
actor ToolBudget {
  private var remaining: Int
  init(limit: Int = 4) { remaining = limit }
  func consume() throws {
    try Task.checkCancellation()
    guard remaining > 0 else {
      throw OrchardError(
        message:
          "Stopped after four tool calls to prevent a tool loop. Please narrow the request or try again."
      )
    }
    remaining -= 1
  }
}
