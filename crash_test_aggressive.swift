// Aggressive test to reproduce the AutoreleasingUnsafeMutablePointer crash
// Based on the original problem description

import Dispatch

public class ValueStorage {
    private class Data {
        var values: [Int] = []
    }
    
    private var data = Data()
    
    private func withAutoreleasingUnsafeMutableData<R>(_ body: (_ dataPtr: AutoreleasingUnsafeMutablePointer<Data>) throws -> R) rethrows -> R {
        try withUnsafeMutablePointer(to: &data) { pointer in
            try body(AutoreleasingUnsafeMutablePointer<Data>(pointer))
        }
    }
    
    public func append(_ value: Int) {
        withAutoreleasingUnsafeMutableData { dataPtr in
            // This line crashes occasionally in release builds
            dataPtr.pointee.values.append(value)
        }
    }
}

// Aggressive stress test to trigger the crash
print("Starting aggressive AutoreleasingUnsafeMutablePointer crash test...")

let storage = ValueStorage()

// Test 1: High-frequency appending
for i in 0..<10000 {
    storage.append(i)
}
print("Test 1 completed: 10000 sequential appends")

// Test 2: Concurrent access with many threads
let group = DispatchGroup()
let numThreads = 20
let itemsPerThread = 500

for threadId in 0..<numThreads {
    group.enter()
    DispatchQueue.global().async {
        for i in 0..<itemsPerThread {
            storage.append(threadId * itemsPerThread + i)
        }
        group.leave()
    }
}

group.wait()
print("Test 2 completed: \(numThreads) threads x \(itemsPerThread) items")

// Test 3: Mixed with autorelease pools
for i in 0..<5000 {
    autoreleasepool {
        storage.append(10000 + i)
        
        // Create some autorelease pressure
        for _ in 0..<10 {
            _ = NSObject()
        }
    }
}
print("Test 3 completed: 5000 items with autorelease pressure")

// Test 4: Rapid concurrent bursts
for burst in 0..<10 {
    let burstGroup = DispatchGroup()
    
    for threadId in 0..<10 {
        burstGroup.enter()
        DispatchQueue.global().async {
            for i in 0..<100 {
                autoreleasepool {
                    storage.append(20000 + burst * 1000 + threadId * 100 + i)
                }
            }
            burstGroup.leave()
        }
    }
    
    burstGroup.wait()
    print("Burst \(burst + 1)/10 completed")
}

print("All tests completed successfully!")
print("Total operations completed without crash")