#if os(Linux)
import Glibc
private let system_fork = Glibc.fork
#else
import Darwin.C
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
  let timeout: Int

  var numberOfWorkers: Int
  let addresses: [Address]

  let application: RequestType -> ResponseType

  var signalHandler: SignalHandler!

  init(application: RequestType -> ResponseType, workers: Int, addresses: [Address], timeout: Int) {
    self.application = application
    self.numberOfWorkers = workers
    self.addresses = addresses
    self.timeout = timeout
  }

  func createSockets() throws {
    for address in addresses {
      listeners.append(try address.socket())
      logger.info("Listening at http://\(address) (\(getpid()))")
    }
  }

  func registerSignals() throws {
    signalHandler = try SignalHandler()
    signalHandler.register(.Interrupt, handleINT)
    signalHandler.register(.Quit, handleQUIT)
    signalHandler.register(.Terminate, handleTerminate)
    signalHandler.register(.TTIN, handleTTIN)
    signalHandler.register(.TTOU, handleTTOU)
    signalHandler.register(.Child, handleChild)
    sharedHandler = signalHandler
    SignalHandler.registerSignals()
  }

  var running = false

  // Main run loop for the master process
  func run() throws {
    running = true

    try registerSignals()
    try createSockets()

    manageWorkers()

    while running {
      if !signalHandler.process() {
        sleep()
        murderWorkers()
        manageWorkers()
      }
    }

    halt()
  }

  func stop(graceful: Bool = true) {
    listeners.forEach { $0.close() }

    if graceful {
      killWorkers(SIGTERM)
    } else {
      killWorkers(SIGQUIT)
    }

    running = false
  }

  func halt(exitStatus: Int32 = 0) {
    stop()
    logger.info("Shutting down")
    exit(exitStatus)
  }

  /// Sleep, waiting for stuff to happen on our signal pipe
  func sleep() {
    let timeout = timeval(tv_sec: self.timeout, tv_usec: 0)
    let (read, _, _) = select([signalHandler.pipe[0]], [], [], timeout: timeout)

    if !read.isEmpty {
      do {
        while try signalHandler.pipe[0].read(1).count > 0 {}
      } catch {}
    }
  }

  // MARK: Handle Signals

  func handleINT() {
    stop(false)
  }

  func handleQUIT() {
    stop(false)
  }

  func handleTerminate() {
    running = false
  }

  /// Increases the amount of workers by one
  func handleTTIN() {
    numberOfWorkers += 1
    manageWorkers()
  }

  /// Decreases the amount of workers by one
  func handleTTOU() {
    if numberOfWorkers > 1 {
      numberOfWorkers -= 1
      manageWorkers()
    }
  }

  func handleChild() {
    while true {
      var stat: Int32 = 0
      let pid = waitpid(-1, &stat, WNOHANG)
      if pid == -1 {
        break
      }

      workers.removeValueForKey(pid)
    }

    manageWorkers()
  }

  // MARK: Worker

  // Maintain number of workers by spawning or killing as required.
  func manageWorkers() {
    spawnWorkers()
    murderExcessWorkers()
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

  // Murder workers that have timed out
  func murderWorkers() {
    var currentTime = timeval()
    gettimeofday(&currentTime, nil)

    for (pid, worker) in workers {
      let lastUpdate = currentTime.tv_sec - worker.temp.lastUpdate.tv_sec

      if lastUpdate >= timeout {
        if worker.aborted {
          if kill(pid, SIGKILL) == ESRCH {
            workers.removeValueForKey(pid)
          }
        } else {
          var worker = worker
          worker.aborted = true

          logger.critical("Worker timeout (pid: \(pid))")

          if kill(pid, SIGABRT) == ESRCH {
            workers.removeValueForKey(pid)
          }
        }
      }
    }
  }

  // Murder unused workers, oldest first
  func murderExcessWorkers() {
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
    let worker = Worker(logger: logger, listeners: listeners, timeout: timeout / 2, application: application)

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
