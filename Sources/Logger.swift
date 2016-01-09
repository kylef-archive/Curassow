#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

class Logger {
  func currentTime() -> String {
    var t = time(nil)
    let tm = localtime(&t)
    let date = Data(capacity: 64)
    strftime(date.bytes, date.capacity, "%Y-%m-%d %T %z", tm)
    return date.string ?? "unknown"
  }

  func info(message: String) {
    print("[\(currentTime())] [\(getpid())] [INFO] \(message)")
  }

  func critical(message: String) {
    print("[\(currentTime())] [\(getpid())] [CRITICAL] \(message)")
  }
}
