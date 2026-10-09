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
