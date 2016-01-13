#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

import Nest
import Inquiline


protocol WorkerType {
  /// Initialises the worker
  init(logger: Logger, listeners: [Socket], timeout: Int, application: RequestType -> ResponseType)

  var temp: WorkerTemp { get }

  /// Indicates when the worker has been aborted, mostly used by the arbiter
  var aborted: Bool { get set }

  /// Runs the worker
  func run()
}


func getenv(key: String, `default`: String) -> String {
  let result = getenv(key)
  if result != nil {
    if let value = String.fromCString(result) {
      return value
    }
  }

  return `default`
}


class WorkerTemp {
  let descriptor: Int32
  var state: mode_t = 0

  init() {

    var tempdir = getenv("TMPDIR", default: "/tmp/")
#if !os(Linux)
    if !tempdir.hasSuffix("/") {
      tempdir += "/"
    }
#endif

    let template = "\(tempdir)/curassow.XXXXXXXX"
    var templateChars = Array(template.utf8).map { Int8($0) } + [0]
    descriptor = withUnsafeMutablePointer(&templateChars[0]) { buffer -> Int32 in
      return mkstemp(buffer)
    }

    if descriptor == -1 {
      fatalError("mkstemp(\(template)) failed")
    }

    // Find the filename
#if os(Linux)
    let filename = Data(capacity: Int(PATH_MAX))
    let size = readlink("/proc/self/fd/\(descriptor)", filename.bytes, filename.capacity)
    filename.bytes[size] = 0
#else
    let filename = Data(capacity: Int(MAXPATHLEN))
    if fcntl(descriptor, F_GETPATH, filename.bytes) == -1 {
      fatalError("fcntl failed")
    }
#endif

    // Unlink, so once last close is done, it gets deleted
    unlink(filename.string!)
  }

  deinit {
    close(descriptor)
  }

  func notify() {
    if state == 1 {
      state = 0
    } else {
      state = 1
    }

    fchmod(descriptor, state)
  }

  var lastUpdate: timespec {
    var stats = stat()
    fstat(descriptor, &stats)
#if os(Linux)
    return stats.st_ctim
#else
    return stats.st_ctimespec
#endif
  }
}
