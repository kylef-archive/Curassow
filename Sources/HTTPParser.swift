#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

import Nest
import Inquiline


enum HTTPParserError : ErrorType {
  case BadSyntax(String)
  case BadVersion(String)
  case Internal

  func response() -> ResponseType {
    switch self {
    case let .BadSyntax(syntax):
      return Response(.BadRequest, contentType: "text/plain", body: "Bad Syntax (\(syntax))")
    case let .BadVersion(version):
      return Response(.BadRequest, contentType: "text/plain", body: "Bad Version (\(version))")
    case .Internal:
      return Response(.InternalServerError, contentType: "text/plain", body: "Internal Server Error")
    }
  }
}

class HTTPParser {
  let socket: Socket

  init(socket: Socket) {
    self.socket = socket
  }

  // Read the socket until we find \r\n\r\n
  // returning string before and chars after
  func readUntil() throws -> (String, [CChar]) {
    var buffer: [CChar] = []

    while true {
      if let bytes = try? socket.read(512) {
        if bytes.isEmpty {
          throw HTTPParserError.Internal
        }

        buffer += bytes

        let crln: [CChar] = [13, 10, 13, 10]
        if let (top, bottom) = buffer.find(crln) {
          if let headers = String.fromCString(top + [0]) {
            return (headers, bottom)
          }

          print("[worker] Failed to decode data from client")
          throw HTTPParserError.Internal
        }

        // TODO bail if server never sends us \r\n\r\n
      }
    }
  }

  func readBody(maxLength maxLength: Int? = nil) throws -> [CChar] {
    let length = maxLength ?? Int.max
    var buffer: [CChar] = []

    while buffer.count < length {
      let bytes = try socket.read(min(512, length-buffer.count))
      if bytes.isEmpty {
        break
      }

      buffer += bytes
    }

    return buffer
  }

  func parse() throws -> RequestType {
    let (top, startOfBody) = try readUntil()
    var components = top.split("\r\n")
    let requestLine = components.removeFirst()
    components.removeLast()
    let requestComponents = requestLine.split(" ")
    if requestComponents.count != 3 {
      throw HTTPParserError.BadSyntax(requestLine)
    }

    let method = requestComponents[0]
    // TODO path should be un-quoted
    let path = requestComponents[1]
    let version = requestComponents[2]

    if !version.hasPrefix("HTTP/1") {
      throw HTTPParserError.BadVersion(version)
    }

    var request = Request(method: method, path: path, headers: parseHeaders(components))
    let contentLength = request.contentLength
    let remainingContentLength = contentLength.map({ $0-startOfBody.count })
    let bodyBytes = startOfBody + (try readBody(maxLength: remainingContentLength))
    request.body = parseBody(bodyBytes, contentLength: contentLength)

    return request
  }

  func parseHeaders(headers: [String]) -> [Header] {
    return headers.map { $0.split(":", maxSeparator: 1) }.flatMap {
      if $0.count == 2 {
        if $0[1].characters.first == " " {
          let value = String($0[1].characters[$0[1].startIndex.successor()..<$0[1].endIndex])
          return ($0[0], value)
        }
        return ($0[0], $0[1])
      }

      return nil
    }
  }

  func parseBody(bytes: [CChar], contentLength: Int?) -> String? {
    let length = contentLength ?? Int.max
    let trimmedBytes = length<bytes.count ? Array(bytes[0..<length]) : bytes

    return bytes.count > 0 ? String.fromCString(trimmedBytes+[0]) : nil
  }
}


extension CollectionType where Generator.Element == CChar {
  func find(characters: [CChar]) -> ([CChar], [CChar])? {
    var lhs: [CChar] = []
    var rhs = Array(self)

    while !rhs.isEmpty {
      let character = rhs.removeAtIndex(0)
      lhs.append(character)
      if lhs.hasSuffix(characters) {
        return (lhs, rhs)
      }
    }

    return nil
  }

  func hasSuffix(characters: [CChar]) -> Bool {
    let chars = Array(self)
    if chars.count >= characters.count {
      let index = chars.count - characters.count
      return Array(chars[index..<chars.count]) == characters
    }

    return false
  }
}


extension String {
  func split(separator: String, maxSeparator: Int = Int.max) -> [String] {
    let scanner = Scanner(self)
    var components: [String] = []
    var scans = 0

    while !scanner.isEmpty && scans <= maxSeparator {
      components.append(scanner.scan(until: separator))
      ++scans
    }

    return components
  }
}


class Scanner {
  var content: String

  init(_ content: String) {
    self.content = content
  }

  var isEmpty: Bool {
    return content.characters.count == 0
  }

  func scan(until until: String) -> String {
    if until.isEmpty {
      return ""
    }

    var characters: [Character] = []

    while !content.isEmpty {
      let character = content.characters.first!
      content = String(content.characters.dropFirst())

      characters.append(character)

      if content.hasPrefix(until) {
        let index = content.characters.startIndex.advancedBy(until.characters.count)
        content = String(content.characters[index..<content.characters.endIndex])
        break
      }
    }

    return String(characters)
  }
}

extension String {
  func hasPrefix(prefix: String) -> Bool {
    let characters = utf16
    let prefixCharacters = prefix.utf16
    let start = characters.startIndex
    let prefixStart = prefixCharacters.startIndex

    if characters.count < prefixCharacters.count {
      return false
    }

    for var idx = 0; idx < prefixCharacters.count; idx++ {
      if characters[start.advancedBy(idx)] != prefixCharacters[prefixStart.advancedBy(idx)] {
        return false
      }
    }

    return true
  }
}
