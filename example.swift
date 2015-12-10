import Curassow
import Inquiline


serve { _ in
  Response(.Ok, contentType: "text/plain", body: "Hello World")
}
