import Foundation
import Inquiline

struct Application {
    private var routes: [Route: (Request, Route) -> Response] = [:]
    
    mutating func addRoute(route: Route, handler: (Request, Route) -> Response) {
        self.routes[route] = handler
    }
    
    private func routeForURL(url: NSURL) -> (Route, ((Request, Route) -> Response))? {
        return self.routes.filter { $0.0 ~= url }
            .first
    }
    
    func start() {
        serve {
            guard let request = $0 as? Request else { return Response(.BadRequest) }
            guard let url = request.url else { return Response(.BadRequest) }
            guard let (route, handler) = self.routeForURL(url) else { return Response(.NotFound) }
            guard route.methods == nil || route.methods?.indexOf(request.method) != nil else {
                return Response(.MethodNotAllowed)
            }
            
            return handler(request, route)
        }
    }
}

extension Request {
    var url: NSURL! { return NSURL(string: self.path) }
}