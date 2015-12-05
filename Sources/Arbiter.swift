#if os(Linux)
import Glibc

private let system_fork = Glibc.fork
private let system_sleep = Glibc.sleep
#else
import Darwin.C

private let system_sleep = Darwin.sleep

@_silgen_name("fork") private func system_fork() -> Int32
#endif

import Nest


enum Address : CustomStringConvertible {
  case IP(hostname: String, port: UInt16)

  func socket() throws -> Socket {
    switch self {
    case let IP(hostname, port):
      let socket = try Socket()
      try socket.bind(hostname, port: port)
      try socket.listen(20)
      // TODO: Set socket non blocking
      return socket
    }
  }

  var description: String {
    switch self {
    case let IP(hostname, port):
      return "\(hostname):\(port)"
    }
  }
}

protocol SignalHandler {
  func handleTTIN()
  func handleTTOU()
}

/// Global arbiter is unfortunately required so we can handle signals
var arbiter: SignalHandler!


/// Arbiter maintains the worker processes
class Arbiter<Worker : WorkerType> : SignalHandler {
  var listeners: [Socket] = []
  var workers: [pid_t: Worker] = [:]

  var numberOfWorkers: Int
  let addresses: [Address]

  let application: RequestType -> ResponseType

  init(application: RequestType -> ResponseType, workers: Int, addresses: [Address]) {
    self.application = application
    self.numberOfWorkers = workers
    self.addresses = addresses
  }

  func createSockets() throws {
    for address in addresses {
      listeners.append(try address.socket())
      print("[arbiter] Listening on \(address)")
    }
  }

  func registerSignals() throws {
    arbiter = self

    signal(SIGTTIN) { _ in
      arbiter.handleTTIN()
    }

    signal(SIGTTOU) { _ in
      arbiter.handleTTOU()
    }
  }

  // Main run loop for the master process
  func run() throws {
    try registerSignals()
    try createSockets()

    manageWorkers()

    while true {
      sleep()
      manageWorkers()
    }
  }

  func sleep() {
    // Wait's for stuff happening on our signal
    // TODO make signals for worker<>arbiter communcation
    system_sleep(10) // Until method is implemented, don't use CPU too much
  }

  // MARK: Handle Signals

  /// Increases the amount of workers by one
  func handleTTIN() {
    ++numberOfWorkers
    manageWorkers()
  }

  /// Decreases the amount of workers by one
  func handleTTOU() {
    if numberOfWorkers > 1 {
      --numberOfWorkers
      manageWorkers()
    }
  }

  // MARK: Worker

  // Maintain number of workers by spawning or killing as required.
  func manageWorkers() {
    spawnWorkers()
    killWorkers()
  }

  // Spawn workers until we have enough
  func spawnWorkers() {
    let neededWorkers = numberOfWorkers - workers.count
    if neededWorkers > 0 {
      for _ in 0..<neededWorkers {
        spawnWorker()
      }
    }
  }

  // Kill unused workers, oldest first
  func killWorkers() {
    // TODO
  }

  // Spawns a new worker process
  func spawnWorker() {
    let worker = Worker(listeners: listeners, application: application)

    let pid = system_fork()
    if pid != 0 {
      workers[pid] = worker
      print("[arbiter] Started worker process \(pid)")
      return
    }

    worker.run()
  }
}
