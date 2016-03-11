#if os(OSX)
import Darwin
import Dispatch
import Nest
import Inquiline


final public class DispatchWorker :  WorkerType {
  let configuration: Configuration
  let logger: Logger
  let listeners: [Socket]
  let notify: Void -> Void
  let application: RequestType -> ResponseType

  public init(configuration: Configuration, logger: Logger, listeners: [Socket], notify: Void -> Void, application: Application) {
    self.logger = logger
    self.listeners = listeners
    self.configuration = configuration
    self.notify = notify
    self.application = application
  }

  public func run() {
    logger.info("Booting worker process with pid: \(getpid())")

    let timerSource = configureTimer()
    dispatch_resume(timerSource)

    listeners.forEach(registerSocketHandler)

    // Gracefully shutdown
    signal(SIGTERM, SIG_IGN)
    let terminateSignal = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, UInt(SIGTERM), 0, dispatch_get_main_queue())
    dispatch_source_set_event_handler(terminateSignal) { [unowned self] in
      self.exitWorker()
    }
    dispatch_resume(terminateSignal)

    // Quick shutdown
    signal(SIGQUIT, SIG_IGN)
    let quitSignal = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, UInt(SIGQUIT), 0, dispatch_get_main_queue())
    dispatch_source_set_event_handler(quitSignal) { [unowned self] in
      self.exitWorker()
    }
    dispatch_resume(quitSignal)

    signal(SIGINT, SIG_IGN)
    let interruptSignal = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, UInt(SIGINT), 0, dispatch_get_main_queue())
    dispatch_source_set_event_handler(interruptSignal) { [unowned self] in
      self.exitWorker()
    }
    dispatch_resume(interruptSignal)

    dispatch_main()
  }

  func exitWorker() {
    logger.info("Worker exiting (pid: \(getpid()))")
    exit(0)
  }

  func registerSocketHandler(socket: Socket) {
    socket.consume { [unowned self] (source, socket) in
      if let clientSocket = try? socket.accept() {
        // TODO: Handle socket asyncronously, use GCD to observe data

        clientSocket.blocking = true
        self.handle(clientSocket)
      }
    }
  }

  func configureTimer() -> dispatch_source_t {
    let source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue())
    dispatch_source_set_timer(source, 0, UInt64(configuration.timeout) / 2 * NSEC_PER_SEC, 0)
    dispatch_source_set_event_handler(source) { [unowned self] in
      self.notify()
    }

    return source
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


extension Socket {
  func consume(closure: (dispatch_source_t, Socket) -> ()) {
    let source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt(descriptor), 0, dispatch_get_main_queue())

    dispatch_source_set_event_handler(source) { [unowned self] in
      closure(source, self)
    }

    dispatch_source_set_cancel_handler(source) {
      self.close()
    }

    dispatch_resume(source)
  }
/*
  func consumeData(closure: (Socket, Data) -> ()) {
    consume { source, socket in
      let estimated = Int(dispatch_source_get_data(source))
      let data = self.read(estimated)
      closure(socket, data)
    }
  }
*/
}
#endif
