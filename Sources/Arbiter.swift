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


/// Arbiter maintains the worker processes
class Arbiter<Worker : WorkerType> {
  let logger = Logger()
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
      logger.info("Listening at http://\(address) (\(getpid()))")
    }
  }

  func registerSignals() {
    let signals = SignalHandler()
    signals.register(.Interrupt, handleINT)
    signals.register(.Quit, handleQUIT)
    signals.register(.TTIN, handleTTIN)
    signals.register(.TTOU, handleTTOU)
    sharedHandler = signals
    SignalHandler.registerSignals()
  }

  // Main run loop for the master process
  func run() throws {
    registerSignals()
    try createSockets()

    manageWorkers()

    while true {
      sleep()
      manageWorkers()
    }
  }

  func stop(graceful: Bool = true) {
    listeners.forEach { $0.close() }

    if graceful {
      killWorkers(SIGTERM)
    } else {
      killWorkers(SIGQUIT)
    }

    halt()
  }

  func halt(exitStatus: Int32 = 0) {
    logger.info("Shutting down")
    exit(exitStatus)
  }

  func sleep() {
    // Wait's for stuff happening on our signal
    // TODO make signals for worker<>arbiter communcation
    system_sleep(10) // Until method is implemented, don't use CPU too much
  }

  // MARK: Handle Signals

  func handleINT() {
    stop(false)
  }

  func handleQUIT() {
    stop(false)
  }

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
    murderWorkers()
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

  // Murder unused workers, oldest first
  func murderWorkers() {
    let killCount = workers.count - numberOfWorkers
    if killCount > 0 {
      for _ in 0..<killCount {
        if let (pid, _) = workers.popFirst() {
          kill(pid, SIGKILL)
        }
      }
    }
  }

  // Kill all workers with given signal
  func killWorkers(signal: Int32) {
    for pid in workers.keys {
      kill(pid, signal)
    }
  }

  // Spawns a new worker process
  func spawnWorker() {
    let worker = Worker(logger: logger, listeners: listeners, application: application)

    let pid = system_fork()
    if pid != 0 {
      workers[pid] = worker
      return
    }

    let workerPid = getpid()
    worker.run()
    logger.info("Worker exiting (pid: \(workerPid))")
    exit(0)
  }
}
