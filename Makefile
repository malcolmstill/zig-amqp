all-examples:
	for example in examples/* ; do \
		pushd $$example ; zig build --prefix ./ ; popd ; \
	done

generate:
	python protocol/generator.py protocol/amqp0-9-1.stripped.xml > src/protocol.zig
	zig fmt src/protocol.zig

