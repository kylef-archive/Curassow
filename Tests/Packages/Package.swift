import PackageDescription


let package = Package(
  name: "CurassowTests",
  dependencies: [
    .Package(url: "https://github.com/kylef/Spectre.git", majorVersion: 0, minor: 6),
  ]
)
