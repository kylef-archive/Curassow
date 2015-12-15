import PackageDescription


let package = Package(
  name: "Curassow",
  dependencies: [
    .Package(url: "https://github.com/nestproject/Nest.git", majorVersion: 0, minor: 2),
    .Package(url: "https://github.com/nestproject/Inquiline.git", majorVersion: 0, minor: 2),
    .Package(url: "https://github.com/kylef/Commander.git", majorVersion: 0, minor: 4),
  ]
)
