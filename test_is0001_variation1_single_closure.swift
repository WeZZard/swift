// Variation 1: Single closure (no nesting) - should work
import Dispatch

func test1() {
    var opacities: [Double] = [0, 0.5, 1.0]
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        opacities.remove(at: 2)
    }
}
