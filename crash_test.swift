import Foundation

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

// Stress test to trigger the crash
print("Starting crash reproduction test...")
let storage = ValueStorage()

for i in 0..<1000 {
    autoreleasepool {
        storage.append(i)
    }
}

print("Completed successfully - no crash detected")