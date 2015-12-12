SWIFTC=swiftc

ifeq ($(shell uname -s), Darwin)
XCODE=$(shell xcode-select -p)
SDK=$(XCODE)/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk
TARGET=x86_64-apple-macosx10.10
SWIFTC=swiftc -target $(TARGET) -sdk $(SDK) -Xlinker -all_load
endif

SPECS=HTTPParser
SPEC_FILES=$(foreach spec,$(SPECS),Tests/$(spec)Spec.swift)

curassow:
	@echo "Building Curassow"
	@swift build

test-dependencies:
	@echo "Building Test Dependencies"
	@cd Tests/Packages && swift build

run-tests: curassow test-dependencies Tests/main.swift $(SPEC_FILES)
	@echo "Building specs"
	@$(SWIFTC) -o run-tests \
		Tests/main.swift \
		$(SPEC_FILES) \
		-I.build/debug \
		-ITests/Packages/.build/debug \
		-Xlinker Tests/Packages/.build/debug/Spectre.a \
		-Xlinker .build/debug/Commander.a \
		-Xlinker .build/debug/Curassow.a \
		-Xlinker .build/debug/Inquiline.a \
		-Xlinker .build/debug/Nest.a \

test: run-tests
	./run-tests

curassow-release:
	@echo "Building Curassow"
	@swift build --configuration release

example: curassow-release example.swift
	@echo "Building Example"
	@$(SWIFTC) -o example \
		example.swift \
		-I.build/release \
		-Xlinker .build/release/Curassow.a \
		-Xlinker .build/release/Commander.a \
		-Xlinker .build/release/Inquiline.a \
		-Xlinker .build/release/Nest.a \


clean:
	rm -fr run-tests example .build Tests/Packages/.build
