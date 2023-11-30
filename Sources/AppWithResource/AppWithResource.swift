import Foundation
import LibWithResourceGeneratedByLocalTarget

@main
struct AppWithResource {

  static func main() throws {
    print(resourcesGeneratedByLocalTarget.path(forResource: "Test1.out", ofType: nil) ?? "** Not Found **")
  }

}
