#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

import Nest
import Inquiline


enum HTTPParserError : Error {
  case badSyntax(String)
  case badVersion(String)
  case incomplete
  case `internal`

  func response() -> ResponseType {
    func error(_ status: Status, message: String) -> ResponseType {
      return Response(status, contentType: "text/plain", content: message)
    }

    switch self {
    case let .badSyntax(syntax):
      return error(.badRequest, message: "Bad Syntax (\(syntax))")
    case let .badVersion(version):
      return error(.badRequest, message: "Bad Version (\(version))")
    case .incomplete:
      return error(.badRequest, message: "Incomplete HTTP Request")
    case .internal:
      return error(.internalServerError, message: "Internal Server Error")
    }
  }
}


class HTTPParser {
  let reader: Unreader

  init(reader: Readable) {
    self.reader = Unreader(reader: reader)
  }

  func readUntil(_ bytes: [Int8]) throws -> [Int8] {
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
      throw HTTPParserError.incomplete
    }

    if let headers = String(validatingUTF8: (buffer + [0])) {
      return headers
    }

    print("[worker] Failed to decode data from client")
    throw HTTPParserError.internal
  }

  func parse() throws -> RequestType {
    let top = try readHeaders()
    var components = top.split(separator: "\r\n")
    let requestLine = components.removeFirst()
    components.removeLast()
    let requestComponents = requestLine.split(separator: " ")
    if requestComponents.count != 3 {
      throw HTTPParserError.badSyntax(requestLine)
    }

    let method = requestComponents[0]
    let path = requestComponents[1]
    let version = requestComponents[2]

    if !version.hasPrefix("HTTP/1") {
      throw HTTPParserError.badVersion(version)
    }

    let headers = parseHeaders(components)
    let contentSize = headers.filter { $0.0.lowercased() == "content-length" }.flatMap { Int($0.1) }.first
    let payload = ReaderPayload(reader: reader, contentSize: contentSize)
    return Request(method: method, path: path, headers: headers, content: payload)
  }

  func parseHeaders(_ headers: [String]) -> [Header] {
    return headers.map { $0.split(separator: ":", maxSeparator: 1) }.flatMap {
      if $0.count == 2 {
        let key = $0[0]
        var value = $0[1]

        if value.hasPrefix(" ") {
          value.remove(at: value.startIndex)
          return (key, value)
        }

        return (key, value)
      }

      return nil
    }
  }
}


extension Collection where Iterator.Element == CChar {
  fileprivate func find(_ characters: [CChar]) -> ([CChar], [CChar])? {
    var lhs: [CChar] = []
    var rhs = Array(self)

    while !rhs.isEmpty {
      let character = rhs.remove(at: 0)
      lhs.append(character)
      if lhs.hasSuffix(characters) {
        return (lhs, rhs)
      }
    }

    return nil
  }

  fileprivate func hasSuffix(_ characters: [CChar]) -> Bool {
    let chars = Array(self)
    if chars.count >= characters.count {
      let index = chars.count - characters.count
      return Array(chars[index..<chars.count]) == characters
    }

    return false
  }
}


extension String {
  fileprivate func split(separator: String, maxSeparator: Int = Int.max) -> [String] {
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


fileprivate class Scanner {
  var content: String

  init(_ content: String) {
    self.content = content
  }

  var isEmpty: Bool {
    return content.characters.count == 0
  }

  func scan(until: String) -> String {
    if until.isEmpty {
      return ""
    }

    var characters: [Character] = []

    while !content.isEmpty {
      let character = content.characters.first!
      content = String(content.characters.dropFirst())

      characters.append(character)

      if content.hasPrefix(until) {
        let index = content.characters.index(content.characters.startIndex, offsetBy: until.characters.count)
        content = String(content.characters[index..<content.characters.endIndex])
        break
      }
    }

    return String(characters)
  }
}

extension String {
  func hasPrefix(_ prefix: String) -> Bool {
    let characters = utf16
    let prefixCharacters = prefix.utf16
    let start = characters.startIndex
    let prefixStart = prefixCharacters.startIndex

    if characters.count < prefixCharacters.count {
      return false
    }

    for idx in 0..<prefixCharacters.count {
      let charactersIndex = characters.index(start, offsetBy: idx)
      let prefixIndex = characters.index(prefixStart, offsetBy: idx)

      if characters[charactersIndex] != prefixCharacters[prefixIndex] {
        return false
      }
    }

    return true
  }
}


class ReaderPayload : PayloadType, PayloadConvertible, IteratorProtocol {
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

    if let remainingSize = remainingSize, remainingSize < 0 {
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
