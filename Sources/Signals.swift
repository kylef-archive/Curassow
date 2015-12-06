#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

var sharedHandler: SignalHandler?

class SignalHandler {
  enum Signal {
    case Interrupt
    case Quit
    case TTIN
    case TTOU
  }

  class func registerSignals() {
    signal(SIGINT) { _ in sharedHandler?.handle(.Interrupt) }
    signal(SIGQUIT) { _ in sharedHandler?.handle(.Quit) }
    signal(SIGTTIN) { _ in sharedHandler?.handle(.TTIN) }
    signal(SIGTTOU) { _ in sharedHandler?.handle(.TTOU) }
  }

  func handle(signal: Signal) {
    if let handler = callbacks[signal] {
      handler()
    }
  }

  var callbacks: [Signal: () -> ()] = [:]
  func register(signal: Signal, _ callback: () -> ()) {
    callbacks[signal] = callback
  }
}
