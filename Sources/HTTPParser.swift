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
    func error(status: Status, message: String) -> ResponseType {
      return Response(status, contentType: "text/plain", content: message)
    }

    switch self {
    case let .BadSyntax(syntax):
      return error(.BadRequest, message: "Bad Syntax (\(syntax))")
    case let .BadVersion(version):
      return error(.BadRequest, message: "Bad Version (\(version))")
    case .Incomplete:
      return error(.BadRequest, message: "Incomplete HTTP Request")
    case .Internal:
      return error(.InternalServerError, message: "Internal Server Error")
    }
  }
}


class HTTPParser {
  let reader: Unreader

  init(reader: Readable) {
    self.reader = Unreader(reader: reader)
  }

  func readUntil(bytes: [Int8]) throws -> [Int8] {
    if bytes.isEmpty {
      return []
    }

    var buffer: [Int8] = []
    while true {
      let read = try reader.read(8192)
      if read.isEmpty {
        return []
      }

      buffer += read
      if let (top, bottom) = buffer.find(bytes) {
        reader.unread(bottom)
        return top
      }
    }
  }

  // Read the socket until we find \r\n\r\n
  func readHeaders() throws -> String {
    let crln: [CChar] = [13, 10, 13, 10]
    let buffer = try readUntil(crln)

    if buffer.isEmpty {
      throw HTTPParserError.Incomplete
    }

    if let headers = String.fromCString(buffer + [0]) {
      return headers
    }

    print("[worker] Failed to decode data from client")
    throw HTTPParserError.Internal
  }

  func parse() throws -> RequestType {
    let top = try readHeaders()
    var components = top.split("\r\n")
    let requestLine = components.removeFirst()
    components.removeLast()
    let requestComponents = requestLine.split(" ")
    if requestComponents.count != 3 {
      throw HTTPParserError.BadSyntax(requestLine)
    }

    let method = requestComponents[0]
    let path = requestComponents[1]
    let version = requestComponents[2]

    if !version.hasPrefix("HTTP/1") {
      throw HTTPParserError.BadVersion(version)
    }

    let headers = parseHeaders(components)
    let contentSize = headers.filter { $0.0.lowercaseString == "content-length" }.flatMap { Int($0.1) }.first
    let payload = ReaderPayload(reader: reader, contentSize: contentSize)
    return Request(method: method, path: path, headers: headers, content: payload)
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


class ReaderPayload : PayloadType, PayloadConvertible, GeneratorType {
  let reader: Readable
  var buffer: [UInt8] = []
  let bufferSize: Int = 8192
  var remainingSize: Int?

  init(reader: Readable, contentSize: Int? = nil) {
    self.reader = reader
    self.remainingSize = contentSize
  }

  func next() -> [UInt8]? {
    if !buffer.isEmpty {
      if let remainingSize = remainingSize {
        self.remainingSize = remainingSize - self.buffer.count
      }

      let buffer = self.buffer
      self.buffer = []
      return buffer
    }

    if let remainingSize = remainingSize where remainingSize < 0 {
      return nil
    }

    let size = min(remainingSize ?? bufferSize, bufferSize)
    if let bytes = try? reader.read(size) {
      if let remainingSize = remainingSize {
        self.remainingSize = remainingSize - bytes.count
      }

      return bytes.map { UInt8($0) }
    }

    return nil
  }

  func toPayload() -> PayloadType {
    return self
  }
}
