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
  case Incomplete
  case Internal

  func response() -> ResponseType {
    switch self {
    case let .BadSyntax(syntax):
      return Response(.BadRequest, contentType: "text/plain", content: "Bad Syntax (\(syntax))")
    case let .BadVersion(version):
      return Response(.BadRequest, contentType: "text/plain", content: "Bad Version (\(version))")
    case .Incomplete:
      return Response(.BadRequest, contentType: "text/plain", content: "Incomplete HTTP Request")
    case .Internal:
      return Response(.InternalServerError, contentType: "text/plain", content: "Internal Server Error")
    }
  }
}

class HTTPParser {
  let socket: Socket

  init(socket: Socket) {
    self.socket = socket
  }

  // Repeatedly read the socket, calling the predicate with the accumulated
  // buffer to determine how many bytes to attempt to read next.
  // Stops reading and returns the buffer when the predicate returns 0.
  func readWhile(predicate: [CChar] -> Int) throws -> [CChar] {
    var buffer: [CChar] = []

    while true {
      let nextSize = predicate(buffer)
      guard nextSize > 0 else { break }

      let bytes = try socket.read(nextSize)
      guard !bytes.isEmpty else { break }

      buffer += bytes
    }

    return buffer
  }

  // Read the socket until we find \r\n\r\n
  // returning string before and chars after
  func readHeaders() throws -> (String, [CChar]) {
    var findResult: (top: [CChar], bottom: [CChar])?

    let crln: [CChar] = [13, 10, 13, 10]
    try readWhile({ bytes in
      if let (top, bottom) = bytes.find(crln) {
        findResult = (top, bottom)
        return 0
      } else {
        return 512
      }
    })

    guard let result = findResult else { throw HTTPParserError.Incomplete }

    guard let headers = String.fromCString(result.top + [0]) else {
      print("[worker] Failed to decode data from client")
        throw HTTPParserError.Internal
    }

    return (headers, result.bottom)
  }

  func readBody(maxLength maxLength: Int) throws -> [CChar] {
    return try readWhile({ bytes in min(maxLength-bytes.count, 512) })
  }

  func parse() throws -> RequestType {
    let (top, startOfBody) = try readHeaders()
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

    if let contentLength = request.contentLength {
      let remainingContentLength = contentLength - startOfBody.count
      let bodyBytes = startOfBody + (try readBody(maxLength: remainingContentLength))
      let bodyString = try parseBody(bodyBytes, contentLength: contentLength)
      request.content = bodyString
    }

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

  func parseBody(bytes: [CChar], contentLength: Int) throws -> String {
    guard bytes.count >= contentLength else { throw HTTPParserError.Incomplete }

    let trimmedBytes = contentLength<bytes.count ? Array(bytes[0..<contentLength]) : bytes

    guard let bodyString = String.fromCString(trimmedBytes + [0]) else {
      print("[worker] Failed to decode message body from client")
      throw HTTPParserError.Internal
    }
    return bodyString
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
      scans += 1
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

    for idx in 0..<prefixCharacters.count {
      if characters[start.advancedBy(idx)] != prefixCharacters[prefixStart.advancedBy(idx)] {
        return false
      }
    }

    return true
  }
}
