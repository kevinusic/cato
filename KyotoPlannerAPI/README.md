# KyotoPlannerAPI

Plans a 4-day trip to Kyoto by calling the Claude API directly over HTTP from Swift, with no SDK. Swift has no official Anthropic SDK, so this uses `URLSession` against `POST /v1/messages`, and it runs on macOS, iOS and Linux.

It makes two requests:

1. **Structured output:** `output_config.format` with a JSON schema, so the reply decodes straight into an `Itinerary` struct. Arrays can't be length-constrained in the schema, so the prompt asks for four days.
2. **Streamed follow-up:** asks for a rainy-day swap for day 2 and prints the text as it arrives. The first reply is sent back exactly as received, thinking blocks included, which the API requires.

Request settings:

- **Model:** `claude-opus-5-5`, with effort set explicitly to `medium`. Thinking is always on for this model; effort controls how much it does.
- **Refusal fallback:** `fallbacks: "default"` (beta `server-side-fallback-2026-07-01`). If a safety classifier declines a request, the API re-runs it on Anthropic's recommended model in the same call. The program prints which model answered. Remove the `fallbacks` keys and the `anthropic-beta` header to turn this off.

## Running

```sh
export ANTHROPIC_API_KEY=sk-ant-...
swift run
```

Set `ANTHROPIC_BASE_URL` to point at a proxy or mock server instead of `https://api.anthropic.com`.

This package is separate from the root `cato` package, so it builds without the `ClaudeForFoundationModels` dependency.
