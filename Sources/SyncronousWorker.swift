#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

import Nest
import Inquiline


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
    var collection: [Int8] = []
    var mutable = response.body
    while let next = mutable?.next() {
        collection.append(next)
    }
    client.send("Content-Length: \(collection.count)\r\n")
    client.send("\r\n")
    client.send(BytesPayload(bytes: collection))
  } else if let body = response.body {
    client.send(body)
  }
}
