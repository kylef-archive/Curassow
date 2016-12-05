.PHONY: build
build:
	swift build

test-sync: build
	dredd --server '.build/debug/example' Sources/example/example.apib http://localhost:8000

test-dispatch: build
	dredd --server '.build/debug/example --worker-type dispatch --bind 0.0.0.0:9000' Sources/example/example.apib http://localhost:9000

test: test-sync test-dispatch
