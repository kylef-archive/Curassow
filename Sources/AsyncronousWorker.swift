#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

import Nest
import Inquiline


public final class AsynchronousWorker : WorkerType {
  let logger: Logger
  let configuration: Configuration
  let listeners: [Socket]
  let application: RequestType -> ResponseType
  let notify: Void -> Void

  var isAlive = false

  var clients: [AsynchronousClient] = []

  public init(configuration: Configuration, logger: Logger, listeners: [Socket], notify: Void -> Void, application: Application) {
    self.logger = logger
    self.listeners = listeners
    self.configuration = configuration
    self.notify = notify
    self.application = application
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

    while isAlive {
      let (listeners, clients) = wait()
      listeners.forEach(accept)

      clients.forEach(process)
    }
  }

  func wait() -> (listeners: [Socket], clients: [AsynchronousClient]) {
    let timeout: timeval

    if configuration.timeout > 0 {
      timeout = timeval(tv_sec: configuration.timeout / 2, tv_usec: 0)
    } else {
      timeout = timeval(tv_sec: 120, tv_usec: 0)
    }

    let sockets = listeners + clients.map { $0.socket }
    let (read, _, _) = select(sockets, [], [], timeout: timeout)

    let acceptable = read.filter { listeners.contains($0) }
    let readable = clients.filter { read.contains($0.socket) }
    return (acceptable, readable)
  }

  func accept(listener: Socket) {
    if let socket = try? listener.accept() {
      socket.blocking = false
      let client = AsynchronousClient(socket: socket)
      clients.append(client)
    }
  }

  func process(client: AsynchronousClient) {
    let response: ResponseType?

    do {
      if let request = try client.parser.parse() {
        response = application(request)
        print("[worker] \(request.method) \(request.path) - \(response!.statusLine)")
      } else {
        response = nil
      }
    } catch let error as HTTPParserError {
      response = error.response()
    } catch {
      print("[worker] Unknown error: \(error)")
      response = Response(.InternalServerError, contentType: "text/plain", body: "Internal Server Error")
    }

    if let response = response {
      sendResponse(client.socket, response: response)

      client.socket.shutdown()
      client.socket.close()
    }
  }

  // MARK: Signal Handling

  func registerSignals() throws {
    let signals = try SignalHandler()
    signals.register(.Interrupt, handleQuit)
    signals.register(.Quit, handleQuit)
    signals.register(.Terminate, handleTerminate)
    sharedHandler = signals
    SignalHandler.registerSignals()
  }

  /// Quit shutdown
  func handleQuit() {
    isAlive = false
  }

  /// Gracefully shutdown
  func handleTerminate() {
    isAlive = false
  }
}


class AsynchronousClient {
  let socket: Socket
  var parser: AsyncHTTPParser

  init(socket: Socket) {
    self.socket = socket
    self.parser = AsyncHTTPParser(socket: socket)
  }
}
