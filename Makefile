SWIFTC=swiftc

ifeq ($(shell uname -s), Darwin)
XCODE=$(shell xcode-select -p)
SDK=$(XCODE)/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk
TARGET=x86_64-apple-macosx10.10
SWIFTC=swiftc -target $(TARGET) -sdk $(SDK) -Xlinker -all_load
endif

SPECS=Configuration HTTPParser Address
SPEC_FILES=$(foreach spec,$(SPECS),Tests/$(spec)Spec.swift)

RELEASE_LIBS=Curassow Commander Inquiline Nest fd
DEBUG_LIBS=$(RELEASE_LIBS) Spectre

DEBUG_SWIFT_ARGS=$(foreach lib,$(DEBUG_LIBS),-Xlinker .build/debug/$(lib).a)
RELEASE_SWIFT_ARGS=$(foreach lib,$(RELEASE_LIBS),-Xlinker .build/release/$(lib).a)

curassow:
	@echo "Building Curassow"
	@swift build

run-tests: curassow Tests/main.swift $(SPEC_FILES)
	@echo "Building specs"
	@$(SWIFTC) -o run-tests \
		Tests/main.swift \
		$(SPEC_FILES) \
		-I.build/debug \
		$(DEBUG_SWIFT_ARGS)

run-integration-tests: curassow
	@echo "Building Nest Test Suite"
	@cd Tests/Integration/NestTestSuite && swift build
	@echo "Building Curassow Nest Test Suite Server"
	@$(SWIFTC) -o run-integration-tests \
		Tests/Integration/main.swift \
		Tests/Integration/NestTestSuite/Server/application.swift \
		-I.build/debug \
		-Xlinker .build/debug/Commander.a \
		-Xlinker .build/debug/Curassow.a \
		-Xlinker .build/debug/Inquiline.a \
		-Xlinker .build/debug/Nest.a \

unit-test: run-tests
	@./run-tests

integration-test: run-integration-tests
	@pkill run-integration-tests || true
	@echo "Starting Server"
	@./run-integration-tests --bind 127.0.0.1:9393 &
	@sleep 1
	@echo "Starting Test Suite"
	@Tests/Integration/NestTestSuite/.build/debug/NestTestSuite --host http://127.0.0.1:9393 Tests/Integration/NestTestSuite/Features/*.feature
	@pkill run-integration-tests || true

test: unit-test

curassow-release:
	@echo "Building Curassow"
	@swift build --configuration release

example: curassow-release example/example.swift
	@echo "Building Example"
	@$(SWIFTC) -o example/example \
		example/example.swift \
		-I.build/release \
		$(RELEASE_SWIFT_ARGS)

clean:
	rm -fr run-tests example/example .build
