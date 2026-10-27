// swift-tools-version:5.0
import PackageDescription

let package = Package(
	name: "SwiftDefaultApps",
	platforms: [.macOS("13.0")],
	products: [
		.executable(name: "SwiftDefaultApps", targets: ["SWDA-App"]),
		.executable(name: "CLI", targets: ["SWDA-CLI"])
	],
	dependencies: [
		.package(url: "https://github.com/Lord-Kamina/SwiftCLI", from: Version("2.0.3+swift5"))
	],
	targets: [
		.target(
			name: "SWDA-Common",
			path: "Sources",
			sources: ["Common Sources/"]
		),
		.target(
			name: "DummyApp",
			path: "Sources",
			sources: ["DummyApp/"]
		),
		.target(
			name: "SWDA-CLI",
			dependencies: ["SwiftCLI", "SWDA-Common", "DummyApp"],
			path: "Sources",
			sources: ["CLI Components/"]
		),
		.target(
			name: "SWDA-App",
			dependencies: ["SWDA-Common", "DummyApp"],
			path: "Sources",
			sources: ["App Sources/"]
		)
	],
	swiftLanguageVersions: [.v4, .v4_2, .v5]
)
