import Nest
import Inquiline


protocol WorkerType {
  init(listeners: [Socket], application: RequestType -> ResponseType)
  func run()
}


final class SyncronousWorker : WorkerType {
  let listeners: [Socket]
  let timeout: Double = 0.5
  let application: RequestType -> ResponseType
  var isAlive: Bool = false

  init(listeners: [Socket], application: RequestType -> ResponseType) {
    self.listeners = listeners
    self.application = application
  }

  func run() {
    isAlive = true

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
    fatalError("Currasow Syncronous worker cannot yet handle multiple listeners")
  }

  func notify() {
    // TODO communicate with arbiter
  }

  func wait() -> [Socket] {
    return []
  }

  func accept(listener: Socket) {
    if let client = try? listener.accept() {
      // TODO: Set socket non blocking
      handle(client)
    }
  }

  func handle(client: Socket) {
    let parser = HTTPParser(socket: client)
    if let request = try? parser.parse() {
      handle(client, request: request)
    }

    client.close()
  }

  func handle(client: Socket, request: RequestType) {
    let response = application(request)

    client.send("HTTP/1.1 \(response.statusLine)\r\n")

    client.send("Connection: Close\r\n")
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

    print("[worker] \(request.method) \(request.path) - \(response.statusLine)")
  }
}

