#if os(Linux)
import Glibc
#else
import Darwin
#endif
import Curassow
import Inquiline


serve { _ in
  Response(.Ok, contentType: "text/plain", content: "Hello World")
}
