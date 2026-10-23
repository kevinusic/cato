# cato

Swift examples for `ClaudeForFoundationModels`.

## Examples

Each example is an executable target in this package.

- [`KyotoTrip`](Sources/KyotoTrip/main.swift): plan a 4-day trip to Kyoto with `ClaudeLanguageModel` and `LanguageModelSession`.
- [`KyotoItinerary`](Sources/KyotoItinerary/main.swift): the same trip as a typed `@Generable` itinerary, with session instructions and a streamed follow-up turn.

## Running

Requires Xcode 26 or later (macOS 26 / iOS 26 SDKs). App Attest auth only works on Apple devices, so run from Xcode on a real device or a supported Mac rather than from a plain `swift run` on Linux.

```sh
swift run KyotoTrip
swift run KyotoItinerary
```

## Claude API over HTTP

[`KyotoPlannerAPI/`](KyotoPlannerAPI/README.md) is a separate package. It plans the same trip by calling the Claude API directly from Swift with `URLSession`, with structured output and a streamed follow-up. It doesn't need `ClaudeForFoundationModels` and runs on macOS, iOS and Linux:

```sh
cd KyotoPlannerAPI && ANTHROPIC_API_KEY=sk-ant-... swift run
```
