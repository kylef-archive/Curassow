import Curassow
import Inquiline


serve { _ in
  Response(.ok, contentType: "text/plain", content: "Hello World\n")
}
