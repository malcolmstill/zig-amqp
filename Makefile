
build-example:
	zig build-exe --single-threaded src/example.zig

build-example-small:
	zig build-exe -O ReleaseFast --single-threaded --strip src/example.zig
	strip example

build-example-small-compressed:
	zig build-exe -O ReleaseFast --single-threaded --strip src/example.zig
	strip example
	upx example

release:
	zig build-exe -O ReleaseSafe --single-threaded --strip src/example.zig
	strip example

generate:
	python protocol/generator.py protocol/amqp0-9-1.stripped.xml > src/protocol.zig
	zig fmt src/protocol.zig