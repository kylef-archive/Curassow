final class Configuration {
  let addresses: [Address]

  /// Workers silent for more than this many seconds are killed and restarted
  let timeout: Int

  let backlog: Int32

  init(addresses: [Address] = [], timeout: Int = 30, backlog: Int32 = 2048) {
    self.addresses = addresses
    self.timeout = timeout
    self.backlog = backlog
  }
}
