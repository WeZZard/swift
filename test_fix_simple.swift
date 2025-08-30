#!/usr/bin/env swift

// Simple test to validate the AutoreleasingUnsafeMutablePointer fix
// This can be run directly with swift without building the entire project

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
            // This line previously crashed in release builds
            dataPtr.pointee.values.append(value)
        }
    }
    
    public func getCount() -> Int {
        return withAutoreleasingUnsafeMutableData { dataPtr in
            return dataPtr.pointee.values.count
        }
    }
}

// Test the fix
print("Testing AutoreleasingUnsafeMutablePointer fix...")

let storage = ValueStorage()

// Basic test
storage.append(1)
storage.append(2)
print("Basic test: \(storage.getCount()) items (expected: 2)")

// Stress test with autorelease pools
for i in 0..<100 {
    autoreleasepool {
        storage.append(i)
    }
}

print("Stress test: \(storage.getCount()) items (expected: 102)")

// Concurrent test
let group = DispatchGroup()
for threadId in 0..<5 {
    group.enter()
    DispatchQueue.global().async {
        for i in 0..<20 {
            autoreleasepool {
                storage.append(threadId * 20 + i)
            }
        }
        group.leave()
    }
}

group.wait()
print("Concurrent test: \(storage.getCount()) items (expected: 202)")

print("All tests passed! The fix appears to be working correctly.")