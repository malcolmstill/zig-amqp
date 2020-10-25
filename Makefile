
build-example:
	zig build-exe --strip src/example.zig

generate:
	python protocol/generator.py protocol/amqp0-9-1.stripped.xml > src/protocol.zig; zig fmt src/protocol.zig