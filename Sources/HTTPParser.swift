import Nest
import Inquiline


enum HTTPParserError : ErrorType {

}

class HTTPParser {
  let socket: Socket

  init(socket: Socket) {
    self.socket = socket
  }

  func parse() throws -> RequestType {
    // TODO build parser
    return Request(method: "GET", path: "/")
  }
}
