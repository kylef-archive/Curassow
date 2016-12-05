#if os(Linux)
import Glibc
#else
import Darwin.C
#endif


public final class Logger {
  func currentTime() -> String {
    var t = time(nil)
    let tm = localtime(&t)
    var buffer = [Int8](repeating: 0, count: 64)
    strftime(&buffer, 64, "%Y-%m-%d %T %z", tm)
    return String(cString: buffer)
  }

  public func info(_ message: String) {
    print("[\(currentTime())] [\(getpid())] [INFO] \(message)")
  }

  public func critical(_ message: String) {
    print("[\(currentTime())] [\(getpid())] [CRITICAL] \(message)")
  }
}
