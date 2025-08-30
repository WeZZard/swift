// Test that both chained fixups and legacy bind info produce identical output
// REQUIRES: no_asan
// REQUIRES: CPU=arm64 || CPU=x86_64
// REQUIRES: OS=macosx
// RUN: %empty-directory(%t)

// Build with chained fixups (modern format - default on recent systems)
// RUN: %target-build-swift -target %target-swift-5.2-abi-triple -Xfrontend -disable-availability-checking %S/Inputs/TypeLowering.swift -parse-as-library -emit-module -emit-library -module-name TypeLowering -o %t/%target-library-name(TypesChained)

// Build with legacy bind info
// RUN: %target-build-swift -target %target-swift-5.2-abi-triple -Xfrontend -disable-availability-checking %S/Inputs/TypeLowering.swift -parse-as-library -emit-module -emit-library %no-fixup-chains -module-name TypeLowering -o %t/%target-library-name(TypesLegacy)

// Test chained format
// RUN: %target-swift-reflection-dump %t/%target-library-name(TypesChained) %platform-module-dir/%target-library-name(swiftCore) -dump-type-lowering < %s > %t/chained_output.txt
// RUN: %FileCheck %s --check-prefix=CHECK-%target-ptrsize < %t/chained_output.txt

// Test legacy format  
// RUN: %target-swift-reflection-dump %t/%target-library-name(TypesLegacy) %platform-module-dir/%target-library-name(swiftCore) -dump-type-lowering < %s > %t/legacy_output.txt
// RUN: %FileCheck %s --check-prefix=CHECK-%target-ptrsize < %t/legacy_output.txt

// Verify both produce identical output
// RUN: diff %t/chained_output.txt %t/legacy_output.txt

12TypeLowering11BasicStructV
// CHECK-64:      (struct TypeLowering.BasicStruct)

// CHECK-64-NEXT: (struct size=16 alignment=4 stride=16 num_extra_inhabitants=0 bitwise_takable=1
// CHECK-64-NEXT:   (field name=i1 offset=0
// CHECK-64-NEXT:     (struct size=1 alignment=1 stride=1 num_extra_inhabitants=0 bitwise_takable=1
// CHECK-64-NEXT:       (field name=_value offset=0
// CHECK-64-NEXT:         (builtin size=1 alignment=1 stride=1 num_extra_inhabitants=0 bitwise_takable=1))))
// CHECK-64-NEXT:   (field name=i2 offset=2
// CHECK-64-NEXT:     (struct size=2 alignment=2 stride=2 num_extra_inhabitants=0 bitwise_takable=1
// CHECK-64-NEXT:       (field name=_value offset=0
// CHECK-64-NEXT:         (builtin size=2 alignment=2 stride=2 num_extra_inhabitants=0 bitwise_takable=1))))
// CHECK-64-NEXT:   (field name=i3 offset=4
// CHECK-64-NEXT:     (struct size=4 alignment=4 stride=4 num_extra_inhabitants=0 bitwise_takable=1
// CHECK-64-NEXT:       (field name=_value offset=0
// CHECK-64-NEXT:         (builtin size=4 alignment=4 stride=4 num_extra_inhabitants=0 bitwise_takable=1))))
// CHECK-64-NEXT:   (field name=i4 offset=8
// CHECK-64-NEXT:     (struct size=8 alignment=8 stride=8 num_extra_inhabitants=0 bitwise_takable=1
// CHECK-64-NEXT:       (field name=_value offset=0
// CHECK-64-NEXT:         (builtin size=8 alignment=8 stride=8 num_extra_inhabitants=0 bitwise_takable=1)))))