import Spectre
import Commander
import Curassow


func testAddress() {
  describe("Address") {
    $0.describe("CustomStringConvertible") {
      $0.it("shows hostname:port description for IP addresses") {
        let address = Address.ip(hostname: "127.0.0.1", port: 80)

        try expect(address.description) == "127.0.0.1:80"
      }

      $0.it("shows description for UNIX addresses") {
        let address = Address.unix(path: "/tmp/curassow")

        try expect(address.description) == "unix:/tmp/curassow"
      }
    }

    $0.describe("ArgumentConvertible") {
      $0.it("can be converted from a host:port") {
        let parser = ArgumentParser(arguments: ["127.0.0.1:80"])
        let address = try Address(parser: parser)

        try expect(address) == .ip(hostname: "127.0.0.1", port: 80)
      }

      $0.it("can be converted from a host:port") {
        let parser = ArgumentParser(arguments: ["unix:/tmp/curassow"])
        let address = try Address(parser: parser)

        try expect(address) == .unix(path: "/tmp/curassow")
      }
    }
  }
}
