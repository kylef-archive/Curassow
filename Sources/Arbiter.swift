#if os(Linux)
import Glibc
private let system_fork = Glibc.fork
#else
import Darwin.C
@_silgen_name("fork") private func system_fork() -> Int32
#endif

import fd
import Nest


/// Arbiter maintains the worker processes
public final class Arbiter<Worker : WorkerType> {
  let configuration: Configuration
  let logger = Logger()
  var listeners: [Socket] = []
  var workers: [pid_t: WorkerProcess] = [:]

  var numberOfWorkers: Int

  let application: RequestType -> ResponseType

  var signalHandler: SignalHandler!

  public init(configuration: Configuration, workers: Int, application: Application) {
    self.configuration = configuration
    self.numberOfWorkers = workers
    self.application = application
  }

  func createSockets() throws {
    for address in configuration.addresses {
      listeners.append(try address.socket(configuration.backlog))
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
  @noreturn public func run(daemonize daemonize: Bool = false) throws {
    running = true

    try registerSignals()
    try createSockets()

    if daemonize {
      let devnull = open("/dev/null", O_RDWR)
      if devnull == -1 {
        throw SocketError()
      }

      if system_fork() != 0 {
        exit(0)
      }

      setsid()

      for descriptor in Int32(0)..<Int32(3) {
        dup2(devnull, descriptor)
      }
    }

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

  @noreturn func halt(exitStatus: Int32 = 0) {
    stop()
    logger.info("Shutting down")
    exit(exitStatus)
  }

  /// Sleep, waiting for stuff to happen on our signal pipe
  func sleep() {
    let timeout: timeval

    if configuration.timeout > 0 {
      timeout = timeval(tv_sec: configuration.timeout, tv_usec: 0)
    } else {
      timeout = timeval(tv_sec: 30, tv_usec: 0)
    }

    let result = try? select(reads: [signalHandler.pipe.read], timeout: timeout)
    let read = result?.reads ?? []

    if !read.isEmpty {
      do {
        while try signalHandler.pipe.read.read(1).count > 0 {}
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
    if configuration.timeout == 0 { return }

    var currentTime = timeval()
    gettimeofday(&currentTime, nil)

    for (pid, worker) in workers {
      let lastUpdate = currentTime.tv_sec - worker.temp.lastUpdate.tv_sec

      if lastUpdate >= configuration.timeout {
        if worker.aborted {
          if kill(pid, SIGKILL) == ESRCH {
            workers.removeValueForKey(pid)
          }
        } else {
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
    let workerProcess = WorkerProcess()
    let worker = Worker(configuration: configuration, logger: logger, listeners: listeners, notify: workerProcess.notify, application: application)

    let pid = system_fork()
    if pid != 0 {
      workers[pid] = workerProcess
      return
    }

    SignalHandler.reset()

    let workerPid = getpid()
    worker.run()
    logger.info("Worker exiting (pid: \(workerPid))")
    exit(0)
  }
}
