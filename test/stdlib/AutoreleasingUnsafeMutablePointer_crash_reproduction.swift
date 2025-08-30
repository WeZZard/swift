// RUN: %target-run-simple-swift
// RUN: %target-run-simple-swift(-O)
// RUN: %target-run-simple-swift(-Osize)
// REQUIRES: executable_test
// REQUIRES: objc_interop

// This test reproduces a crash that occurs when using AutoreleasingUnsafeMutablePointer
// with withUnsafeMutablePointer in release builds, especially with AddressSanitizer.

import StdlibUnittest
import ObjectiveC

var AutoreleasingCrashTests = TestSuite("AutoreleasingUnsafeMutablePointer_Crash")

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
            // This line crashes occasionally in release builds
            dataPtr.pointee.values.append(value)
        }
    }
}

AutoreleasingCrashTests.test("basic_usage_should_not_crash") {
    let storage = ValueStorage()
    storage.append(1)
    storage.append(2)
    storage.append(3)
}

AutoreleasingCrashTests.test("stress_test_multiple_appends") {
    let storage = ValueStorage()
    
    // Stress test to increase likelihood of crash
    for i in 0..<1000 {
        autoreleasepool {
            storage.append(i)
        }
    }
}

AutoreleasingCrashTests.test("concurrent_access_stress_test") {
    let storage = ValueStorage()
    
    // Test concurrent access which might trigger the race condition
    let group = DispatchGroup()
    
    for _ in 0..<10 {
        group.enter()
        DispatchQueue.global().async {
            for i in 0..<100 {
                autoreleasepool {
                    storage.append(i)
                }
            }
            group.leave()
        }
    }
    
    group.wait()
}

// Test the specific pattern that causes issues
AutoreleasingCrashTests.test("autorelease_pool_timing_issue") {
    class TestData {
        var counter: Int = 0
        
        deinit {
            // This should help detect premature deallocation
            print("TestData deallocated with counter: \(counter)")
        }
    }
    
    func testWithAutoreleasingPointer(_ data: inout TestData) {
        withUnsafeMutablePointer(to: &data) { pointer in
            let autoreleasingPtr = AutoreleasingUnsafeMutablePointer(pointer)
            
            // This access pattern triggers the issue
            autoreleasepool {
                autoreleasingPtr.pointee.counter += 1
                // The autorelease pool drain here might deallocate the object
                // before the operation completes
            }
        }
    }
    
    var testData = TestData()
    
    for _ in 0..<100 {
        testWithAutoreleasingPointer(&testData)
    }
    
    expectEqual(testData.counter, 100)
}

runAllTests()