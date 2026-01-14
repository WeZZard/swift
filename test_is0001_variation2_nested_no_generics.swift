// Variation 2: Nested closures without generics - should work
import Dispatch

func noGenericWrapper(_ body: () -> Void) {
    body()
}

func test2() {
    var opacities: [Double] = [0, 0.5, 1.0]
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        noGenericWrapper {
            opacities.remove(at: 2)
        }
    }
}
