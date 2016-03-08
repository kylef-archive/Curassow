import Spectre
import Curassow


func testConfiguration() {
  describe("Configuration") {
    let configuration = Configuration()

    $0.it("doesn't have any default addresses") {
      try expect(configuration.addresses.count) == 0
    }

    $0.it("defaults the timeout to 30 seconds") {
      try expect(configuration.timeout) == 30
    }

    $0.it("defaults the backlog to 2048 connections") {
      try expect(configuration.backlog) == 2048
    }
  }
}
