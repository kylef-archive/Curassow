curassow:
	swift build

spectre:
	cd Spectre && swift build

tests: curassow spectre
	swiftc -o run-tests \
		Tests/HTTPParserSpecs.swift \
		-I.build/debug -Xlinker .build/debug/Curassow.o \
		-ISpectre/.build/debug -Xlinker Spectre/.build/debug/Spectre.a \
		-Xlinker -all_load

test: tests
