// RUN: %target-typecheck-verify-swift

@discardableResult
func withAnimation<Result>(_ body: () throws -> Result) rethrows -> Result {
  try body()
}

func doLater(_ body: @escaping () -> Void) {
  body()
}

func test() {
  var opacities: [Double] = [0, 0.5, 1.0]
  doLater {
    withAnimation {
      opacities.remove(at: 2)
    }
  }
}

@discardableResult
func discardable() -> Int {
  1
}

func testDiscardableResult() {
  doLater {
    withAnimation {
      discardable()
    }
  }
}
