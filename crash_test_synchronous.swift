// Simple synchronous reproduction test - no threading required
// This reproduces the AutoreleasingUnsafeMutablePointer crash with simple appending

public class ValueStorage {
    private class Data {
        var values: [Int] = []
    }
    
    private var data = Data()
    
    public func append(_ value: Int) {
        withUnsafeMutablePointer(to: &data) { pointer in
            let autoreleasingPtr = AutoreleasingUnsafeMutablePointer<Data>(pointer)
            // This line crashes in optimized builds due to AutoreleasingUnsafeMutablePointer.pointee setter
            autoreleasingPtr.pointee.values.append(value)
        }
    }
    
    public func getCount() -> Int {
        return data.values.count
    }
}

// Simple synchronous test - no concurrency
print("Starting synchronous AutoreleasingUnsafeMutablePointer test...")

let storage = ValueStorage()

// Simple sequential appending that can trigger the crash
for i in 0..<1000 {
    storage.append(i)
    
    // Occasional status to see where it crashes
    if i % 100 == 0 {
        print("Appended \(i) items, total count: \(storage.getCount())")
    }
}

print("Completed successfully: \(storage.getCount()) items")