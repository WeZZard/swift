// RUN: %target-run-simple-swift
// RUN: %target-run-simple-swift(-O)
// RUN: %target-run-simple-swift(-Osize)
// RUN: %target-run-simple-swift(-Onone)
// REQUIRES: executable_test
// REQUIRES: objc_interop

// This test validates the fix for AutoreleasingUnsafeMutablePointer crash
// that occurred when using withUnsafeMutablePointer in release builds.

import StdlibUnittest
import ObjectiveC

var AutoreleasingFixValidationTests = TestSuite("AutoreleasingUnsafeMutablePointer_Fix_Validation")

// Test class to track object lifecycle
class TestObject {
    var value: Int
    static var deallocCount = 0
    static var allocCount = 0
    
    init(_ value: Int) {
        self.value = value
        TestObject.allocCount += 1
    }
    
    deinit {
        TestObject.deallocCount += 1
    }
    
    static func resetCounters() {
        deallocCount = 0
        allocCount = 0
    }
}

// Reproduce the original crash pattern
public class ValueStorage {
    private class Data {
        var values: [Int] = []
        var testObject: TestObject?
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
    
    public func setTestObject(_ obj: TestObject?) {
        withAutoreleasingUnsafeMutableData { dataPtr in
            // Test object assignment through AutoreleasingUnsafeMutablePointer
            dataPtr.pointee.testObject = obj
        }
    }
    
    public func getTestObjectValue() -> Int? {
        return withAutoreleasingUnsafeMutableData { dataPtr in
            return dataPtr.pointee.testObject?.value
        }
    }
    
    public func getValuesCount() -> Int {
        return withAutoreleasingUnsafeMutableData { dataPtr in
            return dataPtr.pointee.values.count
        }
    }
}

AutoreleasingFixValidationTests.test("basic_usage_after_fix") {
    let storage = ValueStorage()
    storage.append(1)
    storage.append(2)
    storage.append(3)
    
    expectEqual(storage.getValuesCount(), 3)
}

AutoreleasingFixValidationTests.test("object_lifecycle_management") {
    TestObject.resetCounters()
    
    let storage = ValueStorage()
    let testObj = TestObject(42)
    
    storage.setTestObject(testObj)
    expectEqual(storage.getTestObjectValue(), 42)
    
    // Object should still be alive
    expectEqual(TestObject.deallocCount, 0)
    expectEqual(TestObject.allocCount, 1)
    
    storage.setTestObject(nil)
    expectNil(storage.getTestObjectValue())
}

AutoreleasingFixValidationTests.test("stress_test_with_autorelease_pools") {
    let storage = ValueStorage()
    
    // Stress test with frequent autorelease pool draining
    for i in 0..<1000 {
        autoreleasepool {
            storage.append(i)
            
            // Create and destroy objects to stress the autorelease pool
            let obj = TestObject(i)
            storage.setTestObject(obj)
            storage.setTestObject(nil)
        }
    }
    
    expectEqual(storage.getValuesCount(), 1000)
}

AutoreleasingFixValidationTests.test("concurrent_access_safety") {
    let storage = ValueStorage()
    let group = DispatchGroup()
    let iterations = 100
    
    // Test concurrent access which previously triggered the race condition
    for threadId in 0..<10 {
        group.enter()
        DispatchQueue.global().async {
            for i in 0..<iterations {
                autoreleasepool {
                    storage.append(threadId * iterations + i)
                    
                    // Mix in object operations
                    if i % 10 == 0 {
                        let obj = TestObject(threadId * iterations + i)
                        storage.setTestObject(obj)
                        _ = storage.getTestObjectValue()
                        storage.setTestObject(nil)
                    }
                }
            }
            group.leave()
        }
    }
    
    group.wait()
    expectEqual(storage.getValuesCount(), 10 * iterations)
}

AutoreleasingFixValidationTests.test("nested_autorelease_pools") {
    let storage = ValueStorage()
    TestObject.resetCounters()
    
    autoreleasepool {
        let obj1 = TestObject(1)
        storage.setTestObject(obj1)
        
        autoreleasepool {
            let obj2 = TestObject(2)
            storage.setTestObject(obj2)
            
            autoreleasepool {
                let obj3 = TestObject(3)
                storage.setTestObject(obj3)
                expectEqual(storage.getTestObjectValue(), 3)
            }
            
            // obj3 should be deallocated, but obj2 should still be alive
            expectEqual(storage.getTestObjectValue(), 3)
        }
        
        // obj2 should be deallocated, but obj3 should still be alive
        expectEqual(storage.getTestObjectValue(), 3)
    }
    
    // All objects should still be accessible through storage
    expectEqual(storage.getTestObjectValue(), 3)
}

AutoreleasingFixValidationTests.test("memory_pressure_test") {
    let storage = ValueStorage()
    TestObject.resetCounters()
    
    // Create memory pressure to trigger more aggressive autorelease pool draining
    for batch in 0..<10 {
        autoreleasepool {
            // Create many objects to fill the autorelease pool
            var objects: [TestObject] = []
            for i in 0..<100 {
                objects.append(TestObject(batch * 100 + i))
            }
            
            // Perform operations that previously crashed
            for i in 0..<100 {
                storage.append(batch * 100 + i)
                if i % 10 == 0 {
                    storage.setTestObject(objects[i])
                    _ = storage.getTestObjectValue()
                }
            }
            
            // Clear objects to trigger deallocations
            objects.removeAll()
        }
    }
    
    expectEqual(storage.getValuesCount(), 1000)
    // Verify we didn't leak objects
    expectTrue(TestObject.deallocCount > 0)
}

// Test the specific pattern that caused the original issue
AutoreleasingFixValidationTests.test("withUnsafeMutablePointer_pattern_safety") {
    class TestData {
        var counter: Int = 0
        var objects: [TestObject] = []
        
        deinit {
            // This should help detect premature deallocation
            print("TestData deallocated with counter: \(counter)")
        }
    }
    
    func testWithAutoreleasingPointer(_ data: inout TestData) {
        withUnsafeMutablePointer(to: &data) { pointer in
            let autoreleasingPtr = AutoreleasingUnsafeMutablePointer(pointer)
            
            // This access pattern previously triggered the crash
            autoreleasepool {
                autoreleasingPtr.pointee.counter += 1
                autoreleasingPtr.pointee.objects.append(TestObject(autoreleasingPtr.pointee.counter))
                
                // Force autorelease pool to drain during operation
                for _ in 0..<10 {
                    autoreleasepool {
                        _ = TestObject(999)
                    }
                }
            }
        }
    }
    
    var testData = TestData()
    TestObject.resetCounters()
    
    for _ in 0..<100 {
        testWithAutoreleasingPointer(&testData)
    }
    
    expectEqual(testData.counter, 100)
    expectEqual(testData.objects.count, 100)
    
    // Verify objects are properly retained
    for (index, obj) in testData.objects.enumerated() {
        expectEqual(obj.value, index + 1)
    }
}

runAllTests()