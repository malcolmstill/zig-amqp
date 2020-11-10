
build-example:
	zig build-exe --single-threaded src/example.zig
	strip example

build-example-small:
	zig build-exe --release-small --single-threaded --strip src/example.zig
	strip example

build-example-small-compressed:
	zig build-exe --release-small --single-threaded --strip src/example.zig
	strip example
	upx example

release:
	zig build-exe --release-safe --single-threaded --strip src/example.zig
	strip example

generate:
	python protocol/generator.py protocol/amqp0-9-1.stripped.xml > src/protocol.zig
	zig fmt src/protocol.zig