// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "cato",
  platforms: [.macOS(.v26), .iOS(.v26)],
  dependencies: [
    // TODO: replace with the real location of the ClaudeForFoundationModels package.
    .package(url: "https://example.com/ClaudeForFoundationModels.git", from: "0.1.0")
  ],
  targets: [
    .executableTarget(
      name: "KyotoTrip",
      dependencies: [
        .product(name: "ClaudeForFoundationModels", package: "ClaudeForFoundationModels")
      ]
    ),
    .executableTarget(
      name: "KyotoItinerary",
      dependencies: [
        .product(name: "ClaudeForFoundationModels", package: "ClaudeForFoundationModels")
      ]
    ),
  ]
)
