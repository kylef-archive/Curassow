#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

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

  public init(configuration: Configuration, logger: Logger, listeners: [Socket], notify: Void -> Void, application: Application) {
    self.logger = logger
    self.listeners = listeners
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

  func runOne(listener: Socket) {
    while isAlive {
      sharedHandler?.process()
      notify()
      accept(listener)
      wait()
    }
  }

  func runMultiple(listeners: [Socket]) {
    while isAlive {
      sharedHandler?.process()
      notify()

      let sockets = wait().filter {
        $0.descriptor != sharedHandler!.pipe[0].descriptor
      }

      sockets.forEach(accept)
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
      client.send("Content-Length: \(body.utf8.count)\r\n")
    } else {
      client.send("Content-Length: 0\r\n")
    }
  }

  client.send("\r\n")

  if let body = response.body {
    client.send(body)
  }
}
