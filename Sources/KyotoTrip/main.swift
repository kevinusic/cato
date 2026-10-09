import ClaudeForFoundationModels
import FoundationModels

let model = ClaudeLanguageModel(
  name: .sonnet5,
  auth: .appAttest(clientID: "clid_01NZxm9xae4gmZq3MfHa6C5k")
)

let session = LanguageModelSession(model: model)
let response = try await session.respond(to: "Plan a 4-day trip to Kyoto")
print(response.content)
