import Foundation
import LibWithResource

@main
struct AppWithResource {

  static func main() throws {
    print(resourceBundle.path(forResource: "Test1.out", ofType: nil) ?? "** Not Found **")
  }

}
