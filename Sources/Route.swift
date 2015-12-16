import Foundation

struct Route {
    let url: NSURL
    let methods: [String]?
    
    private var urlParameterIndices: [Int] {
        let patternComponents = self.url.absoluteString.componentsSeparatedByString("/")
        return patternComponents.enumerate()
            .filter { $0.1.hasPrefix(":") }
            .map { $0.0 }
    }
    
    init(path: String, methods: [String]) {
        self.url = NSURL(string: path)!
        self.methods = methods
    }
}

extension Route: StringLiteralConvertible {
    typealias ExtendedGraphemeClusterLiteralType = StringLiteralType
    typealias UnicodeScalarLiteralType = StringLiteralType
    
    init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
        self.url = NSURL(string: "\(value)")!
        self.methods = nil
    }
    
    init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
        self.url = NSURL(string: "\(value)")!
        self.methods = nil
    }
    
    init(stringLiteral value: StringLiteralType) {
        self.url = NSURL(string: "\(value)")!
        self.methods = nil
    }
}

extension Route: Hashable, Equatable {
    var hashValue: Int { return self.url.hashValue }
}

func ==(lhs: Route, rhs: Route) -> Bool {
    return lhs.url == rhs.url
}

func ~=(lhs: Route, rhs: NSURL) -> Bool {
    let patternComponents = lhs.url.absoluteString.componentsSeparatedByString("/")
    let matchableComponents = rhs.absoluteString.componentsSeparatedByString("/")
    
    let trimmedPattern = patternComponents.enumerate()
        .filter { lhs.urlParameterIndices.indexOf($0.0) == nil }
        .map { $0.1 }
    let trimmedMatchable = matchableComponents.enumerate()
        .filter { lhs.urlParameterIndices.indexOf($0.0) == nil }
        .map { $0.1 }
   
    return trimmedPattern == trimmedMatchable
}

extension String {
    private var parameters: [String: String] {
        var params: [String: String] = [:]
        self.componentsSeparatedByString("&").forEach {
            let pair = $0.componentsSeparatedByString("=")
            let val = (pair.count == 2) ? pair.last! : ""
            params[pair.first!] = val
        }
        return params
    }
}

extension NSURL {
    var queryParameters: [String: String] {
        return self.query?.parameters ?? [:]
    }
    
    var fragmentParameters: [String: String] {
        return self.fragment?.parameters ?? [:]
    }
    
    func urlParameters(forRoute route: Route) -> [String: String] {
        let patternComponents = route.url.absoluteString.componentsSeparatedByString("/")
        let matchableComponents = self.absoluteString.componentsSeparatedByString("/")
        
        var params: [String: String] = [:]
        route.urlParameterIndices.forEach {
            let key = patternComponents[$0].substringFromIndex(patternComponents[$0].startIndex.advancedBy(1))
            params[key] = matchableComponents[$0]
        }
        
        return params
    }
}
