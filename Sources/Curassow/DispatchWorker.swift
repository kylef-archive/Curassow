import Dispatch
import fd
import Nest
import Inquiline


final public class DispatchWorker :  WorkerType {
  let configuration: Configuration
  let logger: Logger
  let listeners: [Socket]
  let notify: (Void) -> Void
  let application: (RequestType) -> ResponseType

  public init(configuration: Configuration, logger: Logger, listeners: [Listener], notify: @escaping (Void) -> Void, application: @escaping Application) {
    self.logger = logger
    self.listeners = listeners.map { Socket(descriptor: $0.fileNumber) }
    self.configuration = configuration
    self.notify = notify
    self.application = application
  }

  public func run() {
    logger.info("Booting worker process with pid: \(getpid())")

    let timerSource = configureTimer()
    timerSource.resume()

    listeners.forEach(registerSocketHandler)

    // Gracefully shutdown
    signal(SIGTERM, SIG_IGN)
    let terminateSignal = DispatchSource.makeSignalSource(signal: SIGTERM, queue: DispatchQueue.main)
    terminateSignal.setEventHandler { [unowned self] in
        self.exitWorker()
    }
    terminateSignal.resume()

    // Quick shutdown
    signal(SIGQUIT, SIG_IGN)
    let quitSignal = DispatchSource.makeSignalSource(signal: SIGQUIT, queue: DispatchQueue.main)
    quitSignal.setEventHandler { [unowned self] in
      self.exitWorker()
    }
    quitSignal.resume()

    signal(SIGINT, SIG_IGN)
    let interruptSignal = DispatchSource.makeSignalSource(signal: SIGINT, queue: DispatchQueue.main)
    interruptSignal.setEventHandler { [unowned self] in
      self.exitWorker()
    }
    interruptSignal.resume()

    dispatchMain()
  }

  func exitWorker() {
    logger.info("Worker exiting (pid: \(getpid()))")
    exit(0)
  }

  func registerSocketHandler(socket: Socket) {
    socket.consume { [unowned self] (source, socket) in
      if let connection = try? socket.accept() {
        let clientSocket = Socket(descriptor: connection.fileNumber)
        // TODO: Handle socket asyncronously, use GCD to observe data

        clientSocket.blocking = true
        self.handle(client: clientSocket)
      }
    }
  }

  func configureTimer() -> DispatchSourceTimer {
    let timer = DispatchSource.makeTimerSource()
    timer.scheduleRepeating(deadline: .now(), interval: .seconds(configuration.timeout / 2))

    timer.setEventHandler { [unowned self] in
      self.notify()
    }

    return timer
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
      response = Response(.internalServerError, contentType: "text/plain", content: "Internal Server Error")
    }

    sendResponse(client, response: response)

    client.shutdown()
    client.close()
  }
}


extension Socket {
  func consume(closure: @escaping (DispatchSourceRead, Socket) -> ()) {
    let source = DispatchSource.makeReadSource(fileDescriptor: fileNumber)

    source.setEventHandler { [unowned self] in
      closure(source, self)
    }

    source.setCancelHandler { [unowned self] in
      self.close()
    }

    source.resume()
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
