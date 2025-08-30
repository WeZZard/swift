// More complex crash test that matches the original issue more closely

public class ValueStorage {
    private class Data {
        var values: [Int] = []
    }
    
    private var data = Data()
    
    private func withAutoreleasingUnsafeMutableData<R>(_ body: (_ dataPtr: AutoreleasingUnsafeMutablePointer<Data>) throws -> R) rethrows -> R {
        try withUnsafeMutablePointer(to: &data) { pointer in
            try body(AutoreleasingUnsafeMutablePointer(pointer))
        }
    }
    
    public func append(_ value: Int) {
        withAutoreleasingUnsafeMutableData { dataPtr in
            // This line crashes in certain optimization levels
            dataPtr.pointee.values.append(value)
        }
    }
}

// More aggressive stress test
print("Starting complex crash reproduction test...")

// Test with concurrent access
import Dispatch

let storage = ValueStorage()
let group = DispatchGroup()

for threadId in 0..<5 {
    group.enter()
    DispatchQueue.global().async {
        for i in 0..<200 {
            storage.append(threadId * 200 + i)
        }
        group.leave()
    }
}

group.wait()
print("Completed successfully - no crash detected")