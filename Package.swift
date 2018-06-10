// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "SwiftyLinkerKit",
    products: [
      .library   (name: "SwiftyLinkerKit", targets: [ "SwiftyLinkerKit" ]),
    ],
    dependencies: [
        .package(url: "https://github.com/uraimo/SwiftyGPIO.git",
                 from: "1.0.0"),
        .package(url: "https://github.com/AlwaysRightInstitute/SwiftyTM1637.git",
                 from: "0.1.2")
    ],
    targets: [
        .target(
            name: "SwiftyLinkerKit",
            dependencies: [ "SwiftyTM1637", "SwiftyGPIO" ])
    ]
)
