// Variation 4: Workaround with explicit type annotation
import Dispatch

func withAnimation<Result>(_ body: () throws -> Result) rethrows -> Result {
    try body()
}

func test4() {
    var opacities: [Double] = [0, 0.5, 1.0]
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        withAnimation {
            let _: Double = opacities.remove(at: 2)
        }
    }
}
