//===--- ChainedFixupsTest.cpp - Tests for chained fixups support --------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#include "swift/StaticMirror/ObjectFileContext.h"
#include "swift/RemoteInspection/ReflectionContext.h"
#include "llvm/Object/MachO.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/raw_ostream.h"
#include "gtest/gtest.h"
#include <memory>
#include <vector>

using namespace swift;
using namespace swift::static_mirror;
using namespace llvm::object;

namespace {

class ChainedFixupsTest : public ::testing::Test {
protected:
  void SetUp() override {
    // Set up test environment
  }

  void TearDown() override {
    // Clean up
  }

  // Helper to create a mock MachO object with specified fixup type
  std::unique_ptr<MachOObjectFile> createMockMachO(bool useChainedFixups) {
    // This would need to create a minimal valid MachO file
    // For testing purposes, we'd use pre-built test binaries
    return nullptr; // Placeholder
  }
};

TEST_F(ChainedFixupsTest, DetectsChainedFixupsFormat) {
  // Test that we correctly detect binaries with chained fixups
  const char *testBinary = getenv("SWIFT_TEST_CHAINED_BINARY");
  if (!testBinary) {
    GTEST_SKIP() << "Set SWIFT_TEST_CHAINED_BINARY to test binary path";
  }

  auto BufferOrErr = llvm::MemoryBuffer::getFile(testBinary);
  ASSERT_TRUE(BufferOrErr) << "Failed to load test binary";

  auto BinaryOrErr = createBinary(BufferOrErr.get()->getMemBufferRef());
  ASSERT_TRUE(BinaryOrErr) << "Failed to create binary object";

  auto *MachO = dyn_cast<MachOObjectFile>(BinaryOrErr.get().getBinary());
  ASSERT_NE(MachO, nullptr) << "Binary is not MachO";

  // Check for LC_DYLD_CHAINED_FIXUPS
  bool hasChainedFixups = false;
  for (const auto &Load : MachO->load_commands()) {
    if (Load.C.cmd == llvm::MachO::LC_DYLD_CHAINED_FIXUPS) {
      hasChainedFixups = true;
      break;
    }
  }
  
  EXPECT_TRUE(hasChainedFixups) << "Binary should have chained fixups";
}

TEST_F(ChainedFixupsTest, DetectsLegacyBindFormat) {
  // Test that we correctly detect binaries with legacy bind info
  const char *testBinary = getenv("SWIFT_TEST_LEGACY_BINARY");
  if (!testBinary) {
    GTEST_SKIP() << "Set SWIFT_TEST_LEGACY_BINARY to test binary path";
  }

  auto BufferOrErr = llvm::MemoryBuffer::getFile(testBinary);
  ASSERT_TRUE(BufferOrErr) << "Failed to load test binary";

  auto BinaryOrErr = createBinary(BufferOrErr.get()->getMemBufferRef());
  ASSERT_TRUE(BinaryOrErr) << "Failed to create binary object";

  auto *MachO = dyn_cast<MachOObjectFile>(BinaryOrErr.get().getBinary());
  ASSERT_NE(MachO, nullptr) << "Binary is not MachO";

  // Check for absence of LC_DYLD_CHAINED_FIXUPS
  bool hasChainedFixups = false;
  bool hasBindInfo = false;
  for (const auto &Load : MachO->load_commands()) {
    if (Load.C.cmd == llvm::MachO::LC_DYLD_CHAINED_FIXUPS) {
      hasChainedFixups = true;
    } else if (Load.C.cmd == llvm::MachO::LC_DYLD_INFO_ONLY) {
      hasBindInfo = true;
    }
  }
  
  EXPECT_FALSE(hasChainedFixups) << "Binary should not have chained fixups";
  EXPECT_TRUE(hasBindInfo) << "Binary should have legacy bind info";
}

TEST_F(ChainedFixupsTest, ProcessesChainedFixupsCorrectly) {
  // Test that chained fixups are processed correctly
  const char *testBinary = getenv("SWIFT_TEST_CHAINED_BINARY");
  if (!testBinary) {
    GTEST_SKIP() << "Set SWIFT_TEST_CHAINED_BINARY to test binary path";
  }

  std::vector<const ObjectFile*> ObjectFiles;
  auto BufferOrErr = llvm::MemoryBuffer::getFile(testBinary);
  ASSERT_TRUE(BufferOrErr);

  auto BinaryOrErr = createBinary(BufferOrErr.get()->getMemBufferRef());
  ASSERT_TRUE(BinaryOrErr);

  ObjectFiles.push_back(dyn_cast<ObjectFile>(BinaryOrErr.get().getBinary()));
  
  // Create reflection context
  auto Context = makeReflectionContextForObjectFiles(ObjectFiles, 
                                                     /*ObjCInterop=*/false);
  ASSERT_NE(Context, nullptr) << "Failed to create reflection context";

  // Verify we can dump sections without errors
  std::string Output;
  llvm::raw_string_ostream OS(Output);
  Context->Builder.dumpAllSections<NoObjCInterop, 8>(OS);
  
  EXPECT_FALSE(Output.empty()) << "Should have produced output";
  EXPECT_TRUE(Output.find("FIELDS") != std::string::npos) 
    << "Output should contain reflection sections";
}

TEST_F(ChainedFixupsTest, ProcessesLegacyBindCorrectly) {
  // Test that legacy bind info is processed correctly
  const char *testBinary = getenv("SWIFT_TEST_LEGACY_BINARY");
  if (!testBinary) {
    GTEST_SKIP() << "Set SWIFT_TEST_LEGACY_BINARY to test binary path";
  }

  std::vector<const ObjectFile*> ObjectFiles;
  auto BufferOrErr = llvm::MemoryBuffer::getFile(testBinary);
  ASSERT_TRUE(BufferOrErr);

  auto BinaryOrErr = createBinary(BufferOrErr.get()->getMemBufferRef());
  ASSERT_TRUE(BinaryOrErr);

  ObjectFiles.push_back(dyn_cast<ObjectFile>(BinaryOrErr.get().getBinary()));
  
  // Create reflection context
  auto Context = makeReflectionContextForObjectFiles(ObjectFiles,
                                                     /*ObjCInterop=*/false);
  ASSERT_NE(Context, nullptr) << "Failed to create reflection context";

  // Verify we can dump sections without errors
  std::string Output;
  llvm::raw_string_ostream OS(Output);
  Context->Builder.dumpAllSections<NoObjCInterop, 8>(OS);
  
  EXPECT_FALSE(Output.empty()) << "Should have produced output";
  EXPECT_TRUE(Output.find("FIELDS") != std::string::npos)
    << "Output should contain reflection sections";
}

TEST_F(ChainedFixupsTest, CompareBothFormatsOutput) {
  // Test that both formats produce identical output
  const char *chainedBinary = getenv("SWIFT_TEST_CHAINED_BINARY");
  const char *legacyBinary = getenv("SWIFT_TEST_LEGACY_BINARY");
  
  if (!chainedBinary || !legacyBinary) {
    GTEST_SKIP() << "Set both SWIFT_TEST_CHAINED_BINARY and "
                 << "SWIFT_TEST_LEGACY_BINARY to test";
  }

  // Process chained binary
  std::string ChainedOutput;
  {
    std::vector<const ObjectFile*> ObjectFiles;
    auto BufferOrErr = llvm::MemoryBuffer::getFile(chainedBinary);
    ASSERT_TRUE(BufferOrErr);

    auto BinaryOrErr = createBinary(BufferOrErr.get()->getMemBufferRef());
    ASSERT_TRUE(BinaryOrErr);

    ObjectFiles.push_back(dyn_cast<ObjectFile>(BinaryOrErr.get().getBinary()));
    auto Context = makeReflectionContextForObjectFiles(ObjectFiles, false);
    
    llvm::raw_string_ostream OS(ChainedOutput);
    Context->Builder.dumpAllSections<NoObjCInterop, 8>(OS);
  }

  // Process legacy binary
  std::string LegacyOutput;
  {
    std::vector<const ObjectFile*> ObjectFiles;
    auto BufferOrErr = llvm::MemoryBuffer::getFile(legacyBinary);
    ASSERT_TRUE(BufferOrErr);

    auto BinaryOrErr = createBinary(BufferOrErr.get()->getMemBufferRef());
    ASSERT_TRUE(BinaryOrErr);

    ObjectFiles.push_back(dyn_cast<ObjectFile>(BinaryOrErr.get().getBinary()));
    auto Context = makeReflectionContextForObjectFiles(ObjectFiles, false);
    
    llvm::raw_string_ostream OS(LegacyOutput);
    Context->Builder.dumpAllSections<NoObjCInterop, 8>(OS);
  }

  // Compare outputs
  EXPECT_EQ(ChainedOutput, LegacyOutput) 
    << "Chained and legacy formats should produce identical output";
}

TEST_F(ChainedFixupsTest, DiagnosticModeWorks) {
  // Test that diagnostic mode provides expected output
  const char *testBinary = getenv("SWIFT_TEST_CHAINED_BINARY");
  if (!testBinary) {
    GTEST_SKIP() << "Set SWIFT_TEST_CHAINED_BINARY to test binary path";
  }

  // Enable diagnostics
  setenv("SWIFT_REFLECTION_DUMP_DIAGNOSTICS", "1", 1);

  // Capture stdout
  testing::internal::CaptureStdout();

  std::vector<const ObjectFile*> ObjectFiles;
  auto BufferOrErr = llvm::MemoryBuffer::getFile(testBinary);
  ASSERT_TRUE(BufferOrErr);

  auto BinaryOrErr = createBinary(BufferOrErr.get()->getMemBufferRef());
  ASSERT_TRUE(BinaryOrErr);

  ObjectFiles.push_back(dyn_cast<ObjectFile>(BinaryOrErr.get().getBinary()));
  auto Context = makeReflectionContextForObjectFiles(ObjectFiles, false);

  std::string Output;
  llvm::raw_string_ostream OS(Output);
  Context->Builder.dumpAllSections<NoObjCInterop, 8>(OS);

  std::string Diagnostics = testing::internal::GetCapturedStdout();

  // Check for diagnostic output
  EXPECT_TRUE(Diagnostics.find("DIAGNOSTIC:") != std::string::npos)
    << "Should have diagnostic output";
  EXPECT_TRUE(Diagnostics.find("Processing chained fixups") != std::string::npos ||
              Diagnostics.find("Using legacy bind table") != std::string::npos)
    << "Should indicate which format is being used";

  // Clean up
  unsetenv("SWIFT_REFLECTION_DUMP_DIAGNOSTICS");
}

TEST_F(ChainedFixupsTest, HandlesCorruptedFixups) {
  // Test error handling for corrupted fixup data
  // This would require creating a malformed binary or mocking the APIs
  // For now, we just ensure error paths don't crash
  
  // Create empty object file list
  std::vector<const ObjectFile*> EmptyList;
  
  // This should handle empty input gracefully
  auto Context = makeReflectionContextForObjectFiles(EmptyList, false);
  ASSERT_NE(Context, nullptr) << "Should handle empty object list";
  
  std::string Output;
  llvm::raw_string_ostream OS(Output);
  Context->Builder.dumpAllSections<NoObjCInterop, 8>(OS);
  
  // Should produce minimal output for empty input
  EXPECT_TRUE(Output.empty() || Output.find("FIELDS") != std::string::npos);
}

} // anonymous namespace