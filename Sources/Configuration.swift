public struct Configuration {
  public var addresses: [Address] = []

  /// Workers silent for more than this many seconds are killed and restarted
  public var timeout: Int = 30

  /// The maximum number of pending connections
  public var backlog: Int32 = 2048

  /// The maximum number of simulatenous clients.
  /// This setting does not apply to all worker types.
  public var workerConnections: Int = 1000

  public init() {}
}
