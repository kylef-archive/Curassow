#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

import fd
import Nest
import Inquiline


public final class SynchronousWorker : WorkerType {
  let configuration: Configuration
  let logger: Logger
  let listeners: [Socket]

  var timeout: Int {
    return configuration.timeout / 2
  }

  let notify: Void -> Void

  let application: RequestType -> ResponseType
  var isAlive: Bool = false
  let parentPid: pid_t

  public init(configuration: Configuration, logger: Logger, listeners: [Listener], notify: Void -> Void, application: Application) {
    self.parentPid = getpid()
    self.logger = logger
    self.listeners = listeners.map { Socket(descriptor: $0.fileNumber) }
    self.configuration = configuration
    self.notify = notify
    self.application = application
  }

  func registerSignals() throws {
    let signals = try SignalHandler()
    signals.register(.Interrupt, handleQuit)
    signals.register(.Quit, handleQuit)
    signals.register(.Terminate, handleTerminate)
    sharedHandler = signals
    SignalHandler.registerSignals()
  }

  public func run() {
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

  func isParentAlive() -> Bool {
    if getppid() != parentPid {
      logger.info("Parent changed, shutting down")
      return false
    }

    return true
  }

  func runOne(listener: Socket) {
    while isAlive {
      sharedHandler?.process()
      notify()
      accept(listener)

      if !isParentAlive() {
        return
      }

      wait()
    }
  }

  func runMultiple(listeners: [Socket]) {
    while isAlive {
      sharedHandler?.process()
      notify()

      let sockets = wait().filter {
        $0.fileNumber != sharedHandler!.pipe.read.fileNumber
      }

      sockets.forEach(accept)

      if !isParentAlive() {
        return
      }
    }
  }

  // MARK: Signal Handling

  func handleQuit() {
    isAlive = false
  }

  func handleTerminate() {
    isAlive = false
  }

  func wait() -> [Socket] {
    let timeout: timeval

    if self.timeout > 0 {
      timeout = timeval(tv_sec: self.timeout, tv_usec: 0)
    } else {
      timeout = timeval(tv_sec: 120, tv_usec: 0)
    }

    let (read, _, _) = select(listeners + [sharedHandler!.pipe.read], [], [], timeout: timeout)
    return read
  }

  func accept(listener: Socket) {
    if let connection = try? listener.accept() {
      let client = Socket(descriptor: connection.fileNumber)
      client.blocking = true
      handle(client)
    }
  }

  func handle(client: Socket) {
    let parser = HTTPParser(reader: client)

    let response: ResponseType

    do {
      let request = try parser.parse()
      response = application(request)
      print("[worker] \(request.method) \(request.path) - \(response.statusLine)")
    } catch let error as HTTPParserError {
      response = error.response()
    } catch {
      print("[worker] Unknown error: \(error)")
      response = Response(.InternalServerError, contentType: "text/plain", content: "Internal Server Error")
    }

    sendResponse(client, response: response)

    client.shutdown()
    client.close()
  }
}


func sendResponse(client: Socket, response: ResponseType) {
  client.send("HTTP/1.1 \(response.statusLine)\r\n")
  client.send("Connection: close\r\n")

  for (key, value) in response.headers {
    if key != "Connection" {
      client.send("\(key): \(value)\r\n")
    }
  }

  client.send("\r\n")

  if let body = response.body {
    var body = body
    while let bytes = body.next() {
      client.send(bytes)
    }
  }
}
