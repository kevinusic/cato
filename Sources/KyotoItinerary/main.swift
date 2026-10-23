import ClaudeForFoundationModels
import FoundationModels

@Generable
struct Itinerary {
  @Guide(description: "A short title for the trip")
  var title: String

  @Guide(description: "One entry per day, in order", .count(4))
  var days: [Day]

  @Generable
  struct Day {
    @Guide(description: "Theme of the day, e.g. temples or food")
    var theme: String
    var morning: String
    var afternoon: String
    var evening: String
  }
}

let model = ClaudeLanguageModel(
  name: .sonnet5,
  auth: .appAttest(clientID: "clid_01NZxm9xae4gmZq3MfHa6C5k")
)

let session = LanguageModelSession(
  model: model,
  instructions: "You are a concise travel planner. Prefer walkable days."
)

// Structured output: the response decodes straight into `Itinerary`.
let itinerary = try await session.respond(
  to: "Plan a 4-day trip to Kyoto",
  generating: Itinerary.self
)
for (index, day) in itinerary.content.days.enumerated() {
  print("Day \(index + 1): \(day.theme)")
  print("  Morning:   \(day.morning)")
  print("  Afternoon: \(day.afternoon)")
  print("  Evening:   \(day.evening)")
}

// Streaming: follow-up turns reuse the same session, so it remembers the plan.
let stream = session.streamResponse(to: "Now suggest a rainy-day swap for day 2")
for try await partial in stream {
  print(partial.content)
}
