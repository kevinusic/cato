import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Plans a 4-day Kyoto trip by calling the Claude API over raw HTTP:
// 1. a structured-output request that returns a typed `Itinerary`,
// 2. a streamed follow-up turn in the same conversation.

let model = "claude-opus-5-5"
let baseURL = ProcessInfo.processInfo.environment["ANTHROPIC_BASE_URL"] ?? "https://api.anthropic.com"
let apiURL = URL(string: baseURL + "/v1/messages")!
let apiVersion = "2026-10-21"
// Re-runs a request on Anthropic's recommended model if a safety classifier declines it.
let fallbackBeta = "server-side-fallback-2026-07-01"

// MARK: - Itinerary

struct Itinerary: Decodable {
  var title: String
  var days: [Day]

  struct Day: Decodable {
    var day: Int
    var theme: String
    var morning: String
    var afternoon: String
    var evening: String
  }
}

let itinerarySchema: JSONValue = [
  "type": "object",
  "properties": [
    "title": ["type": "string", "description": "A short title for the trip"],
    "days": [
      "type": "array",
      "items": [
        "type": "object",
        "properties": [
          "day": ["type": "integer"],
          "theme": ["type": "string", "description": "Theme of the day, e.g. temples or food"],
          "morning": ["type": "string"],
          "afternoon": ["type": "string"],
          "evening": ["type": "string"],
        ],
        "required": ["day", "theme", "morning", "afternoon", "evening"],
        "additionalProperties": false,
      ],
    ],
  ],
  "required": ["title", "days"],
  "additionalProperties": false,
]

// MARK: - JSON passthrough

/// Any JSON value. Assistant content is echoed back to the API unchanged (thinking
/// blocks must not be edited), so it is kept as raw JSON rather than decoded into types.
enum JSONValue: Codable, Sendable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral,
  ExpressibleByBooleanLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral
{
  case string(String), number(Double), bool(Bool), null
  case array([JSONValue]), object([String: JSONValue])

  init(stringLiteral value: String) { self = .string(value) }
  init(integerLiteral value: Int) { self = .number(Double(value)) }
  init(booleanLiteral value: Bool) { self = .bool(value) }
  init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
  init(dictionaryLiteral elements: (String, JSONValue)...) {
    self = .object(Dictionary(uniqueKeysWithValues: elements))
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if c.decodeNil() { self = .null }
    else if let v = try? c.decode(Bool.self) { self = .bool(v) }
    else if let v = try? c.decode(Double.self) { self = .number(v) }
    else if let v = try? c.decode(String.self) { self = .string(v) }
    else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
    else { self = .object(try c.decode([String: JSONValue].self)) }
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .string(let v): try c.encode(v)
    case .number(let v): try c.encode(v)
    case .bool(let v): try c.encode(v)
    case .null: try c.encodeNil()
    case .array(let v): try c.encode(v)
    case .object(let v): try c.encode(v)
    }
  }

  subscript(key: String) -> JSONValue? {
    if case .object(let o) = self { return o[key] }
    return nil
  }

  var stringValue: String? {
    if case .string(let s) = self { return s }
    return nil
  }
}

struct MessageResponse: Decodable {
  var model: String
  var content: [JSONValue]
  var stopReason: String?

  enum CodingKeys: String, CodingKey {
    case model, content
    case stopReason = "stop_reason"
  }

  var text: String {
    content.filter { $0["type"]?.stringValue == "text" }
      .compactMap { $0["text"]?.stringValue }
      .joined()
  }
}

enum APIError: Error, CustomStringConvertible {
  case missingAPIKey
  case http(Int, String)
  case stopped(String)

  var description: String {
    switch self {
    case .missingAPIKey: "Set the ANTHROPIC_API_KEY environment variable."
    case .http(let status, let body): "HTTP \(status): \(body)"
    case .stopped(let reason): "Claude stopped early (stop_reason: \(reason))."
    }
  }
}

// MARK: - HTTP

func makeRequest(_ body: JSONValue, apiKey: String) throws -> URLRequest {
  var request = URLRequest(url: apiURL)
  request.httpMethod = "POST"
  request.timeoutInterval = 600
  request.setValue("application/json", forHTTPHeaderField: "content-type")
  request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
  request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
  request.setValue(fallbackBeta, forHTTPHeaderField: "anthropic-beta")
  request.httpBody = try JSONEncoder().encode(body)
  return request
}

func send(_ body: JSONValue, apiKey: String) async throws -> MessageResponse {
  let (data, response) = try await URLSession.shared.data(for: makeRequest(body, apiKey: apiKey))
  let status = (response as? HTTPURLResponse)?.statusCode ?? 0
  guard status == 200 else { throw APIError.http(status, String(decoding: data, as: UTF8.self)) }
  return try JSONDecoder().decode(MessageResponse.self, from: data)
}

/// Delivers a streaming response line by line. `URLSession.bytes(for:)` is unavailable in
/// swift-corelibs-foundation, so a delegate is used to keep this working on Linux too.
final class LineStreamDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
  private let continuation: AsyncThrowingStream<String, Error>.Continuation
  private var buffer = Data()
  private var status = 0

  init(_ continuation: AsyncThrowingStream<String, Error>.Continuation) {
    self.continuation = continuation
  }

  func urlSession(
    _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
  ) {
    status = (response as? HTTPURLResponse)?.statusCode ?? 0
    completionHandler(.allow)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    buffer.append(data)
    guard status == 200 else { return }  // keep the error body for didCompleteWithError
    while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
      let line = String(decoding: buffer[buffer.startIndex..<newline], as: UTF8.self)
      buffer.removeSubrange(buffer.startIndex...newline)
      continuation.yield(line.trimmingCharacters(in: CharacterSet(charactersIn: "\r")))
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let error {
      continuation.finish(throwing: error)
    } else if status != 200 {
      continuation.finish(throwing: APIError.http(status, String(decoding: buffer, as: UTF8.self)))
    } else {
      continuation.finish()
    }
    session.finishTasksAndInvalidate()
  }
}

func streamLines(_ body: JSONValue, apiKey: String) throws -> AsyncThrowingStream<String, Error> {
  let request = try makeRequest(body, apiKey: apiKey)
  return AsyncThrowingStream { continuation in
    let session = URLSession(
      configuration: .default, delegate: LineStreamDelegate(continuation), delegateQueue: nil)
    let task = session.dataTask(with: request)
    continuation.onTermination = { _ in task.cancel() }
    task.resume()
  }
}

// MARK: - Run

func planTrip(apiKey: String) async throws {
  let firstPrompt: JSONValue = [
    "role": "user", "content": "Plan a 4-day trip to Kyoto. Prefer walkable days.",
  ]

  // 1. Structured output: the reply is JSON that matches `itinerarySchema`.
  let planned = try await send(
    [
      "model": .string(model),
      "max_tokens": 16000,
      "fallbacks": "default",
      "output_config": [
        "effort": "medium",
        "format": ["type": "json_schema", "schema": itinerarySchema],
      ],
      "messages": [firstPrompt],
    ], apiKey: apiKey)

  // A refusal or truncated reply may not match the schema, so check before decoding.
  guard planned.stopReason == "end_turn" else {
    throw APIError.stopped(planned.stopReason ?? "unknown")
  }
  let itinerary = try JSONDecoder().decode(Itinerary.self, from: Data(planned.text.utf8))

  print("\(itinerary.title)  [\(planned.model)]\n")
  for day in itinerary.days {
    print("Day \(day.day): \(day.theme)")
    print("  Morning:   \(day.morning)")
    print("  Afternoon: \(day.afternoon)")
    print("  Evening:   \(day.evening)")
  }

  // 2. Streamed follow-up. The assistant turn is sent back exactly as received.
  print("\nRainy-day swap for day 2:\n")
  let followUp: JSONValue = [
    "model": .string(model),
    "max_tokens": 64000,
    "stream": true,
    "fallbacks": "default",
    "output_config": ["effort": "medium"],
    "messages": [
      firstPrompt,
      ["role": "assistant", "content": .array(planned.content)],
      ["role": "user", "content": "Now suggest a rainy-day swap for day 2."],
    ],
  ]

  for try await line in try streamLines(followUp, apiKey: apiKey) {
    guard line.hasPrefix("data: ") else { continue }
    let event = try JSONDecoder().decode(JSONValue.self, from: Data(line.dropFirst(6).utf8))
    switch event["type"]?.stringValue {
    case "content_block_delta":
      if event["delta"]?["type"]?.stringValue == "text_delta",
        let text = event["delta"]?["text"]?.stringValue
      {
        print(text, terminator: "")
        fflush(nil)  // flush all streams; `stdout` is not concurrency-safe in Swift 6
      }
    case "message_delta":
      if let reason = event["delta"]?["stop_reason"]?.stringValue, reason != "end_turn" {
        print("\n[stopped: \(reason)]")
      }
    case "error":
      throw APIError.http(200, line)
    default:
      break
    }
  }
  print()
}

guard let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !apiKey.isEmpty else {
  print(APIError.missingAPIKey)
  exit(1)
}

do {
  try await planTrip(apiKey: apiKey)
} catch {
  print("Error: \(error)")
  exit(1)
}
