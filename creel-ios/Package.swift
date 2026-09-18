// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "CreelCore", platforms: [.macOS(.v13)],
  products: [.library(name: "CreelCore", targets: ["CreelCore"])],
  targets: [
    .target(
      name: "CreelCore", path: "Creel",
      exclude: ["CreelApp.swift", "Services.swift", "MediaViews.swift"], sources: ["Models.swift"]),
    .testTarget(name: "CreelCoreTests", dependencies: ["CreelCore"], path: "Tests"),
  ])
