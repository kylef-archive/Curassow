import Glibc
import Nest


enum Address {
  case IP(address: String, port: UInt16)

  func socket() throws -> Socket {
    let socket = try Socket()
    try socket.bind("0.0.0.0", port: 8000)
    try socket.listen(20)
    // TODO: Set socket non blocking
    return socket
  }
}


/// Arbiter maintains the worker processes
class Arbiter<Worker : WorkerType> {
  var listeners: [Socket] = []
  var workers: [pid_t: Worker] = [:]

  let numberOfWorkers: Int
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
      print("[arbiter] Listening on port 8000")
    }
  }

  // Main run loop for the master process
  func run() throws {
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
    Glibc.sleep(10) // Until method is implemented, don't use CPU too much
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
    for _ in 0..<neededWorkers {
      spawnWorker()
    }
  }

  // Kill unused workers, oldest first
  func killWorkers() {
    // TODO
  }

  // Spawns a new worker process
  func spawnWorker() {
    let worker = Worker(listeners: listeners, application: application)

    let pid = fork()
    if pid != 0 {
      workers[pid] = worker
      print("[arbiter] Started worker process \(pid)")
      return
    }

    worker.run()
  }
}
