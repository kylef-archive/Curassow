#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

import Nest
import Inquiline


protocol WorkerType {
  init(logger: Logger, listeners: [Socket], timeout: Int, application: RequestType -> ResponseType)
  var temp: WorkerTemp { get }
  func run()
  var aborted: Bool { get set }
}


func getenv(key: String, `default`: String) -> String {
  let result = getenv(key)
  if result != nil {
    if let value = String.fromCString(result) {
      return value
    }
  }

  return `default`
}


class WorkerTemp {
  let descriptor: Int32
  var state: mode_t = 0

  init() {

    var tempdir = getenv("TMPDIR", default: "/tmp/")
#if !os(Linux)
    if !tempdir.hasSuffix("/") {
      tempdir += "/"
    }
#endif

    let template = "\(tempdir)/curassow.XXXXXXXX"
    var templateChars = Array(template.utf8).map { Int8($0) } + [0]
    descriptor = withUnsafeMutablePointer(&templateChars[0]) { buffer -> Int32 in
      return mkstemp(buffer)
    }

    if descriptor == -1 {
      fatalError("mkstemp(\(template)) failed")
    }

    // Find the filename
#if os(Linux)
    let filename = Data(capacity: Int(PATH_MAX))
    let size = readlink("/proc/self/fd/\(descriptor)", filename.bytes, filename.capacity)
    filename.bytes[size] = 0
#else
    let filename = Data(capacity: Int(MAXPATHLEN))
    if fcntl(descriptor, F_GETPATH, filename.bytes) == -1 {
      fatalError("fcntl failed")
    }
#endif

    // Unlink, so once last close is done, it gets deleted
    unlink(filename.string!)
  }

  deinit {
    close(descriptor)
  }

  func notify() {
    if state == 1 {
      state = 0
    } else {
      state = 1
    }

    fchmod(descriptor, state)
  }

  var lastUpdate: timespec {
    var stats = stat()
    fstat(descriptor, &stats)
#if os(Linux)
    return stats.st_ctim
#else
    return stats.st_ctimespec
#endif
  }
}


final class SyncronousWorker : WorkerType {
  let logger: Logger
  let listeners: [Socket]
  let timeout: Int
  let application: RequestType -> ResponseType
  var isAlive: Bool = false
  let temp: WorkerTemp
  var aborted: Bool = false

  init(logger: Logger, listeners: [Socket], timeout: Int, application: RequestType -> ResponseType) {
    self.logger = logger
    self.listeners = listeners
    self.timeout = timeout
    self.application = application

    temp = WorkerTemp()
  }

  func registerSignals() throws {
    let signals = try SignalHandler()
    signals.register(.Interrupt, handleQuit)
    signals.register(.Quit, handleQuit)
    signals.register(.Terminate, handleTerminate)
    sharedHandler = signals
    SignalHandler.registerSignals()
  }

  func run() {
    logger.info("Booting worker process with pid: \(getpid())")

    do {
      try registerSignals()
    } catch {
      logger.info("Failed to boot \(error)")
      return
    }
    isAlive = true

    listeners.forEach { $0.blocking = false }

    if listeners.count == 1 {
      runOne(listeners.first!)
    } else {
      runMultiple(listeners)
    }
  }

  func runOne(listener: Socket) {
    while isAlive {
      sharedHandler?.process()
      notify()
      accept(listener)
      wait()
    }
  }

  func runMultiple(listeners: [Socket]) {
    // TODO multiple listners
    fatalError("Curassow Syncronous worker cannot yet handle multiple listeners")
  }

  // MARK: Signal Handling

  func handleQuit() {
    isAlive = false
  }

  func handleTerminate() {
    isAlive = false
  }

  func notify() {
    temp.notify()
  }

  func wait() -> [Socket] {
    let timeout = timeval(tv_sec: self.timeout, tv_usec: 0)
    let (read, _, _) = select(listeners + [sharedHandler!.pipe[0]], [], [], timeout: timeout)
    return read
  }

  func accept(listener: Socket) {
    if let client = try? listener.accept() {
      client.blocking = true
      handle(client)
    }
  }

  func handle(client: Socket) {
    let parser = HTTPParser(socket: client)

    let response: ResponseType

    do {
      let request = try parser.parse()
      response = application(request)
      print("[worker] \(request.method) \(request.path) - \(response.statusLine)")
    } catch let error as HTTPParserError {
      response = error.response()
    } catch {
      print("[worker] Unknown error: \(error)")
      response = Response(.InternalServerError, contentType: "text/plain", body: "Internal Server Error")
    }

    sendResponse(client, response: response)

    client.shutdown()
    client.close()
  }
}


func sendResponse(client: Socket, response: ResponseType) {
  client.send("HTTP/1.1 \(response.statusLine)\r\n")

  client.send("Connection: close\r\n")
  var hasLength = false

  for (key, value) in response.headers {
    if key != "Connection" {
      client.send("\(key): \(value)\r\n")
    }

    if key == "Content-Length" {
      hasLength = true
    }
  }

  if !hasLength {
      if let body = response.body {
      // TODO body shouldn't be a string
      client.send("Content-Length: \(body.characters.count)\r\n")
    } else {
      client.send("Content-Length: 0\r\n")
    }
  }

  client.send("\r\n")

  if let body = response.body {
    client.send(body)
  }
}
