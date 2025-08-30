add_swift_unittest(SwiftStaticMirrorTests
  ChainedFixupsTest.cpp
)

target_link_libraries(SwiftStaticMirrorTests
  swiftStaticMirror
  swiftRemoteInspection
  swiftDemangling
)

# Add test data directory
set(SWIFT_STATICMIRROR_TEST_DATA_DIR "${CMAKE_CURRENT_SOURCE_DIR}/TestData")
target_compile_definitions(SwiftStaticMirrorTests
  PRIVATE "SWIFT_STATICMIRROR_TEST_DATA_DIR=\"${SWIFT_STATICMIRROR_TEST_DATA_DIR}\""
)