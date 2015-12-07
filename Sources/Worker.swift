#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

import Nest
import Inquiline


protocol WorkerType {
  init(logger: Logger, listeners: [Socket], application: RequestType -> ResponseType)
  func run()
}


final class SyncronousWorker : WorkerType {
  let logger: Logger
  let listeners: [Socket]
  let timeout: Double = 0.5
  let application: RequestType -> ResponseType
  var isAlive: Bool = false

  init(logger: Logger, listeners: [Socket], application: RequestType -> ResponseType) {
    self.logger = logger
    self.listeners = listeners
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
    // TODO communicate with arbiter
  }

  func wait() -> [Socket] {
    let timeout = timeval(tv_sec: 10, tv_usec: 0)
    let (read, _, _) = select(listeners, [], [], timeout: timeout)
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
}
