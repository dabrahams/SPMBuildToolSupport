import Foundation
import LibWithRsrcFromLocalTgt

print(resourcesGeneratedByLocalTarget.path(forResource: "Test1.out", ofType: nil) ?? "** Not Found **")
