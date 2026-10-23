// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "KyotoPlannerAPI",
  platforms: [.macOS(.v13), .iOS(.v16)],
  targets: [
    .executableTarget(name: "KyotoPlannerAPI")
  ]
)
