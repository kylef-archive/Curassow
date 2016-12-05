#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

var sharedHandler: SignalHandler?

class SignalHandler {
  enum Signal {
    case interrupt
    case quit
    case ttin
    case ttou
    case terminate
    case child
  }

  class func registerSignals() {
    signal(SIGTERM) { _ in sharedHandler?.handle(.terminate) }
    signal(SIGINT) { _ in sharedHandler?.handle(.interrupt) }
    signal(SIGQUIT) { _ in sharedHandler?.handle(.quit) }
    signal(SIGTTIN) { _ in sharedHandler?.handle(.ttin) }
    signal(SIGTTOU) { _ in sharedHandler?.handle(.ttou) }
    signal(SIGCHLD) { _ in sharedHandler?.handle(.child) }
  }

  class func reset() {
    signal(SIGTERM, SIG_DFL)
    signal(SIGINT, SIG_DFL)
    signal(SIGQUIT, SIG_DFL)
    signal(SIGTTIN, SIG_DFL)
    signal(SIGTTOU, SIG_DFL)
    signal(SIGCHLD, SIG_DFL)
  }

  let pipe: (read: Socket, write: Socket)
  var signalQueue: [Signal] = []

  init() throws {
    pipe = try Socket.pipe()
    pipe.read.closeOnExec = true
    pipe.read.blocking = false
    pipe.write.closeOnExec = true
    pipe.write.blocking = false
  }

  // Wake up the process by writing to the pipe
  func wakeup() {
    pipe.write.send(".")
  }

  func handle(_ signal: Signal) {
    signalQueue.append(signal)
    wakeup()
  }

  var callbacks: [Signal: () -> ()] = [:]
  func register(_ signal: Signal, _ callback: @escaping () -> ()) {
    callbacks[signal] = callback
  }

  func process() -> Bool {
    let result = !signalQueue.isEmpty

    if !signalQueue.isEmpty {
      if let handler = callbacks[signalQueue.removeFirst()] {
        handler()
      }
    }

    return result
  }
}
