import Glibc
import Nest
import Inquiline


enum HTTPParserError : ErrorType {
  case BadSyntax(String)
  case BadVersion(String)

  func response() -> ResponseType {
    switch self {
    case let .BadSyntax(syntax):
      return Response(.BadRequest, contentType: "plain/text", body: "Bad Syntax (\(syntax))")
    case let .BadVersion(version):
      return Response(.BadRequest, contentType: "plain/text", body: "Bad Version (\(version))")
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
          continue
        }

        buffer += bytes

        let crln: [CChar] = [13, 10, 13, 10]
        if let (top, bottom) = buffer.find(crln) {
          if let headers = String.fromCString(strdup(top)) {
            return (headers, bottom)
          }

          fatalError("Cannot convert buffer to string")
        }

        // TODO bail if server never sends us \r\n\r\n
      }
    }
  }

  func parse() throws -> RequestType {
    // TODO body
    let (top, _) = try readUntil()
    var components = top.split("\r\n")
    let requestLine = components.removeFirst()
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

    return Request(method: method, path: path)
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
  func split(separator: String) -> [String] {
    let scanner = Scanner(self)
    var components: [String] = []

    while !scanner.isEmpty {
      components.append(scanner.scan(until: separator))
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
