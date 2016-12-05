import PackageDescription


let package = Package(
  name: "Curassow",
  targets: [
    Target(name: "example", dependencies: ["Curassow"]),
  ],
  dependencies: [
    .Package(url: "https://github.com/nestproject/Nest.git", majorVersion: 0, minor: 4),
    .Package(url: "https://github.com/nestproject/Inquiline.git", majorVersion: 0, minor: 4),
    .Package(url: "https://github.com/kylef/Commander.git", majorVersion: 0, minor: 6),
    .Package(url: "https://github.com/kylef/fd.git", majorVersion: 0, minor: 2),
    .Package(url: "https://github.com/kylef/Spectre.git", majorVersion: 0, minor: 7),
  ]
)
