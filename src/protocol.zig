const std = @import("std");
const fs = std.fs;
const Connector = @import("connector.zig").Connector;
const ClassMethod = @import("connector.zig").ClassMethod;
const WireBuffer = @import("wire.zig").WireBuffer;
const Table = @import("table.zig").Table;
// amqp
pub fn dispatchCallback(conn: *Connector, class: u16, method: u16) !void {
    switch (class) {
        // connection
        10 => {
            switch (method) {
                // start
                10 => {
                    const start = CONNECTION_IMPL.start orelse return error.MethodNotImplemented;
                    const version_major = conn.rx_buffer.readU8();
                    const version_minor = conn.rx_buffer.readU8();
                    var server_properties = conn.rx_buffer.readTable();
                    const mechanisms = conn.rx_buffer.readLongString();
                    const locales = conn.rx_buffer.readLongString();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Connection.Start\n", .{});
                    try start(
                        conn,
                        version_major,
                        version_minor,
                        &server_properties,
                        mechanisms,
                        locales,
                    );
                },
                // start_ok
                11 => {
                    const start_ok = CONNECTION_IMPL.start_ok orelse return error.MethodNotImplemented;
                    var client_properties = conn.rx_buffer.readTable();
                    const mechanism = conn.rx_buffer.readShortString();
                    const response = conn.rx_buffer.readLongString();
                    const locale = conn.rx_buffer.readShortString();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Connection.Start_ok\n", .{});
                    try start_ok(
                        conn,
                        &client_properties,
                        mechanism,
                        response,
                        locale,
                    );
                },
                // secure
                20 => {
                    const secure = CONNECTION_IMPL.secure orelse return error.MethodNotImplemented;
                    const challenge = conn.rx_buffer.readLongString();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Connection.Secure\n", .{});
                    try secure(
                        conn,
                        challenge,
                    );
                },
                // secure_ok
                21 => {
                    const secure_ok = CONNECTION_IMPL.secure_ok orelse return error.MethodNotImplemented;
                    const response = conn.rx_buffer.readLongString();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Connection.Secure_ok\n", .{});
                    try secure_ok(
                        conn,
                        response,
                    );
                },
                // tune
                30 => {
                    const tune = CONNECTION_IMPL.tune orelse return error.MethodNotImplemented;
                    const channel_max = conn.rx_buffer.readU16();
                    const frame_max = conn.rx_buffer.readU32();
                    const heartbeat = conn.rx_buffer.readU16();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Connection.Tune\n", .{});
                    try tune(
                        conn,
                        channel_max,
                        frame_max,
                        heartbeat,
                    );
                },
                // tune_ok
                31 => {
                    const tune_ok = CONNECTION_IMPL.tune_ok orelse return error.MethodNotImplemented;
                    const channel_max = conn.rx_buffer.readU16();
                    const frame_max = conn.rx_buffer.readU32();
                    const heartbeat = conn.rx_buffer.readU16();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Connection.Tune_ok\n", .{});
                    try tune_ok(
                        conn,
                        channel_max,
                        frame_max,
                        heartbeat,
                    );
                },
                // open
                40 => {
                    const open = CONNECTION_IMPL.open orelse return error.MethodNotImplemented;
                    const virtual_host = conn.rx_buffer.readShortString();
                    const reserved_1 = conn.rx_buffer.readShortString();
                    const bitset0 = conn.rx_buffer.readU8();
                    const reserved_2 = if (bitset0 & (1 << 0) == 0) true else false;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Connection.Open\n", .{});
                    try open(
                        conn,
                        virtual_host,
                    );
                },
                // open_ok
                41 => {
                    const open_ok = CONNECTION_IMPL.open_ok orelse return error.MethodNotImplemented;
                    const reserved_1 = conn.rx_buffer.readShortString();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Connection.Open_ok\n", .{});
                    try open_ok(
                        conn,
                    );
                },
                // close
                50 => {
                    const close = CONNECTION_IMPL.close orelse return error.MethodNotImplemented;
                    const reply_code = conn.rx_buffer.readU16();
                    const reply_text = conn.rx_buffer.readShortString();
                    const class_id = conn.rx_buffer.readU16();
                    const method_id = conn.rx_buffer.readU16();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Connection.Close\n", .{});
                    try close(
                        conn,
                        reply_code,
                        reply_text,
                        class_id,
                        method_id,
                    );
                },
                // close_ok
                51 => {
                    const close_ok = CONNECTION_IMPL.close_ok orelse return error.MethodNotImplemented;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Connection.Close_ok\n", .{});
                    try close_ok(
                        conn,
                    );
                },
                // blocked
                60 => {
                    const blocked = CONNECTION_IMPL.blocked orelse return error.MethodNotImplemented;
                    const reason = conn.rx_buffer.readShortString();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Connection.Blocked\n", .{});
                    try blocked(
                        conn,
                        reason,
                    );
                },
                // unblocked
                61 => {
                    const unblocked = CONNECTION_IMPL.unblocked orelse return error.MethodNotImplemented;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Connection.Unblocked\n", .{});
                    try unblocked(
                        conn,
                    );
                },
                else => return error.UnknownMethod,
            }
        },
        // channel
        20 => {
            switch (method) {
                // open
                10 => {
                    const open = CHANNEL_IMPL.open orelse return error.MethodNotImplemented;
                    const reserved_1 = conn.rx_buffer.readShortString();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Channel.Open\n", .{});
                    try open(
                        conn,
                    );
                },
                // open_ok
                11 => {
                    const open_ok = CHANNEL_IMPL.open_ok orelse return error.MethodNotImplemented;
                    const reserved_1 = conn.rx_buffer.readLongString();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Channel.Open_ok\n", .{});
                    try open_ok(
                        conn,
                    );
                },
                // flow
                20 => {
                    const flow = CHANNEL_IMPL.flow orelse return error.MethodNotImplemented;
                    const bitset0 = conn.rx_buffer.readU8();
                    const active = if (bitset0 & (1 << 0) == 0) true else false;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Channel.Flow\n", .{});
                    try flow(
                        conn,
                        active,
                    );
                },
                // flow_ok
                21 => {
                    const flow_ok = CHANNEL_IMPL.flow_ok orelse return error.MethodNotImplemented;
                    const bitset0 = conn.rx_buffer.readU8();
                    const active = if (bitset0 & (1 << 0) == 0) true else false;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Channel.Flow_ok\n", .{});
                    try flow_ok(
                        conn,
                        active,
                    );
                },
                // close
                40 => {
                    const close = CHANNEL_IMPL.close orelse return error.MethodNotImplemented;
                    const reply_code = conn.rx_buffer.readU16();
                    const reply_text = conn.rx_buffer.readShortString();
                    const class_id = conn.rx_buffer.readU16();
                    const method_id = conn.rx_buffer.readU16();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Channel.Close\n", .{});
                    try close(
                        conn,
                        reply_code,
                        reply_text,
                        class_id,
                        method_id,
                    );
                },
                // close_ok
                41 => {
                    const close_ok = CHANNEL_IMPL.close_ok orelse return error.MethodNotImplemented;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Channel.Close_ok\n", .{});
                    try close_ok(
                        conn,
                    );
                },
                else => return error.UnknownMethod,
            }
        },
        // exchange
        40 => {
            switch (method) {
                // declare
                10 => {
                    const declare = EXCHANGE_IMPL.declare orelse return error.MethodNotImplemented;
                    const reserved_1 = conn.rx_buffer.readU16();
                    const exchange = conn.rx_buffer.readShortString();
                    const tipe = conn.rx_buffer.readShortString();
                    const bitset0 = conn.rx_buffer.readU8();
                    const passive = if (bitset0 & (1 << 0) == 0) true else false;
                    const durable = if (bitset0 & (1 << 1) == 0) true else false;
                    const reserved_2 = if (bitset0 & (1 << 2) == 0) true else false;
                    const reserved_3 = if (bitset0 & (1 << 3) == 0) true else false;
                    const no_wait = if (bitset0 & (1 << 4) == 0) true else false;
                    var arguments = conn.rx_buffer.readTable();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Exchange.Declare\n", .{});
                    try declare(
                        conn,
                        exchange,
                        tipe,
                        passive,
                        durable,
                        no_wait,
                        &arguments,
                    );
                },
                // declare_ok
                11 => {
                    const declare_ok = EXCHANGE_IMPL.declare_ok orelse return error.MethodNotImplemented;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Exchange.Declare_ok\n", .{});
                    try declare_ok(
                        conn,
                    );
                },
                // delete
                20 => {
                    const delete = EXCHANGE_IMPL.delete orelse return error.MethodNotImplemented;
                    const reserved_1 = conn.rx_buffer.readU16();
                    const exchange = conn.rx_buffer.readShortString();
                    const bitset0 = conn.rx_buffer.readU8();
                    const if_unused = if (bitset0 & (1 << 0) == 0) true else false;
                    const no_wait = if (bitset0 & (1 << 1) == 0) true else false;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Exchange.Delete\n", .{});
                    try delete(
                        conn,
                        exchange,
                        if_unused,
                        no_wait,
                    );
                },
                // delete_ok
                21 => {
                    const delete_ok = EXCHANGE_IMPL.delete_ok orelse return error.MethodNotImplemented;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Exchange.Delete_ok\n", .{});
                    try delete_ok(
                        conn,
                    );
                },
                else => return error.UnknownMethod,
            }
        },
        // queue
        50 => {
            switch (method) {
                // declare
                10 => {
                    const declare = QUEUE_IMPL.declare orelse return error.MethodNotImplemented;
                    const reserved_1 = conn.rx_buffer.readU16();
                    const queue = conn.rx_buffer.readShortString();
                    const bitset0 = conn.rx_buffer.readU8();
                    const passive = if (bitset0 & (1 << 0) == 0) true else false;
                    const durable = if (bitset0 & (1 << 1) == 0) true else false;
                    const exclusive = if (bitset0 & (1 << 2) == 0) true else false;
                    const auto_delete = if (bitset0 & (1 << 3) == 0) true else false;
                    const no_wait = if (bitset0 & (1 << 4) == 0) true else false;
                    var arguments = conn.rx_buffer.readTable();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Queue.Declare\n", .{});
                    try declare(
                        conn,
                        queue,
                        passive,
                        durable,
                        exclusive,
                        auto_delete,
                        no_wait,
                        &arguments,
                    );
                },
                // declare_ok
                11 => {
                    const declare_ok = QUEUE_IMPL.declare_ok orelse return error.MethodNotImplemented;
                    const queue = conn.rx_buffer.readShortString();
                    const message_count = conn.rx_buffer.readU32();
                    const consumer_count = conn.rx_buffer.readU32();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Queue.Declare_ok\n", .{});
                    try declare_ok(
                        conn,
                        queue,
                        message_count,
                        consumer_count,
                    );
                },
                // bind
                20 => {
                    const bind = QUEUE_IMPL.bind orelse return error.MethodNotImplemented;
                    const reserved_1 = conn.rx_buffer.readU16();
                    const queue = conn.rx_buffer.readShortString();
                    const exchange = conn.rx_buffer.readShortString();
                    const routing_key = conn.rx_buffer.readShortString();
                    const bitset0 = conn.rx_buffer.readU8();
                    const no_wait = if (bitset0 & (1 << 0) == 0) true else false;
                    var arguments = conn.rx_buffer.readTable();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Queue.Bind\n", .{});
                    try bind(
                        conn,
                        queue,
                        exchange,
                        routing_key,
                        no_wait,
                        &arguments,
                    );
                },
                // bind_ok
                21 => {
                    const bind_ok = QUEUE_IMPL.bind_ok orelse return error.MethodNotImplemented;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Queue.Bind_ok\n", .{});
                    try bind_ok(
                        conn,
                    );
                },
                // unbind
                50 => {
                    const unbind = QUEUE_IMPL.unbind orelse return error.MethodNotImplemented;
                    const reserved_1 = conn.rx_buffer.readU16();
                    const queue = conn.rx_buffer.readShortString();
                    const exchange = conn.rx_buffer.readShortString();
                    const routing_key = conn.rx_buffer.readShortString();
                    var arguments = conn.rx_buffer.readTable();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Queue.Unbind\n", .{});
                    try unbind(
                        conn,
                        queue,
                        exchange,
                        routing_key,
                        &arguments,
                    );
                },
                // unbind_ok
                51 => {
                    const unbind_ok = QUEUE_IMPL.unbind_ok orelse return error.MethodNotImplemented;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Queue.Unbind_ok\n", .{});
                    try unbind_ok(
                        conn,
                    );
                },
                // purge
                30 => {
                    const purge = QUEUE_IMPL.purge orelse return error.MethodNotImplemented;
                    const reserved_1 = conn.rx_buffer.readU16();
                    const queue = conn.rx_buffer.readShortString();
                    const bitset0 = conn.rx_buffer.readU8();
                    const no_wait = if (bitset0 & (1 << 0) == 0) true else false;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Queue.Purge\n", .{});
                    try purge(
                        conn,
                        queue,
                        no_wait,
                    );
                },
                // purge_ok
                31 => {
                    const purge_ok = QUEUE_IMPL.purge_ok orelse return error.MethodNotImplemented;
                    const message_count = conn.rx_buffer.readU32();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Queue.Purge_ok\n", .{});
                    try purge_ok(
                        conn,
                        message_count,
                    );
                },
                // delete
                40 => {
                    const delete = QUEUE_IMPL.delete orelse return error.MethodNotImplemented;
                    const reserved_1 = conn.rx_buffer.readU16();
                    const queue = conn.rx_buffer.readShortString();
                    const bitset0 = conn.rx_buffer.readU8();
                    const if_unused = if (bitset0 & (1 << 0) == 0) true else false;
                    const if_empty = if (bitset0 & (1 << 1) == 0) true else false;
                    const no_wait = if (bitset0 & (1 << 2) == 0) true else false;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Queue.Delete\n", .{});
                    try delete(
                        conn,
                        queue,
                        if_unused,
                        if_empty,
                        no_wait,
                    );
                },
                // delete_ok
                41 => {
                    const delete_ok = QUEUE_IMPL.delete_ok orelse return error.MethodNotImplemented;
                    const message_count = conn.rx_buffer.readU32();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Queue.Delete_ok\n", .{});
                    try delete_ok(
                        conn,
                        message_count,
                    );
                },
                else => return error.UnknownMethod,
            }
        },
        // basic
        60 => {
            switch (method) {
                // qos
                10 => {
                    const qos = BASIC_IMPL.qos orelse return error.MethodNotImplemented;
                    const prefetch_size = conn.rx_buffer.readU32();
                    const prefetch_count = conn.rx_buffer.readU16();
                    const bitset0 = conn.rx_buffer.readU8();
                    const global = if (bitset0 & (1 << 0) == 0) true else false;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Basic.Qos\n", .{});
                    try qos(
                        conn,
                        prefetch_size,
                        prefetch_count,
                        global,
                    );
                },
                // qos_ok
                11 => {
                    const qos_ok = BASIC_IMPL.qos_ok orelse return error.MethodNotImplemented;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Basic.Qos_ok\n", .{});
                    try qos_ok(
                        conn,
                    );
                },
                // consume
                20 => {
                    const consume = BASIC_IMPL.consume orelse return error.MethodNotImplemented;
                    const reserved_1 = conn.rx_buffer.readU16();
                    const queue = conn.rx_buffer.readShortString();
                    const consumer_tag = conn.rx_buffer.readShortString();
                    const bitset0 = conn.rx_buffer.readU8();
                    const no_local = if (bitset0 & (1 << 0) == 0) true else false;
                    const no_ack = if (bitset0 & (1 << 1) == 0) true else false;
                    const exclusive = if (bitset0 & (1 << 2) == 0) true else false;
                    const no_wait = if (bitset0 & (1 << 3) == 0) true else false;
                    var arguments = conn.rx_buffer.readTable();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Basic.Consume\n", .{});
                    try consume(
                        conn,
                        queue,
                        consumer_tag,
                        no_local,
                        no_ack,
                        exclusive,
                        no_wait,
                        &arguments,
                    );
                },
                // consume_ok
                21 => {
                    const consume_ok = BASIC_IMPL.consume_ok orelse return error.MethodNotImplemented;
                    const consumer_tag = conn.rx_buffer.readShortString();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Basic.Consume_ok\n", .{});
                    try consume_ok(
                        conn,
                        consumer_tag,
                    );
                },
                // cancel
                30 => {
                    const cancel = BASIC_IMPL.cancel orelse return error.MethodNotImplemented;
                    const consumer_tag = conn.rx_buffer.readShortString();
                    const bitset0 = conn.rx_buffer.readU8();
                    const no_wait = if (bitset0 & (1 << 0) == 0) true else false;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Basic.Cancel\n", .{});
                    try cancel(
                        conn,
                        consumer_tag,
                        no_wait,
                    );
                },
                // cancel_ok
                31 => {
                    const cancel_ok = BASIC_IMPL.cancel_ok orelse return error.MethodNotImplemented;
                    const consumer_tag = conn.rx_buffer.readShortString();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Basic.Cancel_ok\n", .{});
                    try cancel_ok(
                        conn,
                        consumer_tag,
                    );
                },
                // publish
                40 => {
                    const publish = BASIC_IMPL.publish orelse return error.MethodNotImplemented;
                    const reserved_1 = conn.rx_buffer.readU16();
                    const exchange = conn.rx_buffer.readShortString();
                    const routing_key = conn.rx_buffer.readShortString();
                    const bitset0 = conn.rx_buffer.readU8();
                    const mandatory = if (bitset0 & (1 << 0) == 0) true else false;
                    const immediate = if (bitset0 & (1 << 1) == 0) true else false;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Basic.Publish\n", .{});
                    try publish(
                        conn,
                        exchange,
                        routing_key,
                        mandatory,
                        immediate,
                    );
                },
                // @"return"
                50 => {
                    const @"return" = BASIC_IMPL.@"return" orelse return error.MethodNotImplemented;
                    const reply_code = conn.rx_buffer.readU16();
                    const reply_text = conn.rx_buffer.readShortString();
                    const exchange = conn.rx_buffer.readShortString();
                    const routing_key = conn.rx_buffer.readShortString();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Basic.Return\n", .{});
                    try @"return"(
                        conn,
                        reply_code,
                        reply_text,
                        exchange,
                        routing_key,
                    );
                },
                // deliver
                60 => {
                    const deliver = BASIC_IMPL.deliver orelse return error.MethodNotImplemented;
                    const consumer_tag = conn.rx_buffer.readShortString();
                    const delivery_tag = conn.rx_buffer.readU64();
                    const bitset0 = conn.rx_buffer.readU8();
                    const redelivered = if (bitset0 & (1 << 0) == 0) true else false;
                    const exchange = conn.rx_buffer.readShortString();
                    const routing_key = conn.rx_buffer.readShortString();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Basic.Deliver\n", .{});
                    try deliver(
                        conn,
                        consumer_tag,
                        delivery_tag,
                        redelivered,
                        exchange,
                        routing_key,
                    );
                },
                // get
                70 => {
                    const get = BASIC_IMPL.get orelse return error.MethodNotImplemented;
                    const reserved_1 = conn.rx_buffer.readU16();
                    const queue = conn.rx_buffer.readShortString();
                    const bitset0 = conn.rx_buffer.readU8();
                    const no_ack = if (bitset0 & (1 << 0) == 0) true else false;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Basic.Get\n", .{});
                    try get(
                        conn,
                        queue,
                        no_ack,
                    );
                },
                // get_ok
                71 => {
                    const get_ok = BASIC_IMPL.get_ok orelse return error.MethodNotImplemented;
                    const delivery_tag = conn.rx_buffer.readU64();
                    const bitset0 = conn.rx_buffer.readU8();
                    const redelivered = if (bitset0 & (1 << 0) == 0) true else false;
                    const exchange = conn.rx_buffer.readShortString();
                    const routing_key = conn.rx_buffer.readShortString();
                    const message_count = conn.rx_buffer.readU32();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Basic.Get_ok\n", .{});
                    try get_ok(
                        conn,
                        delivery_tag,
                        redelivered,
                        exchange,
                        routing_key,
                        message_count,
                    );
                },
                // get_empty
                72 => {
                    const get_empty = BASIC_IMPL.get_empty orelse return error.MethodNotImplemented;
                    const reserved_1 = conn.rx_buffer.readShortString();
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Basic.Get_empty\n", .{});
                    try get_empty(
                        conn,
                    );
                },
                // ack
                80 => {
                    const ack = BASIC_IMPL.ack orelse return error.MethodNotImplemented;
                    const delivery_tag = conn.rx_buffer.readU64();
                    const bitset0 = conn.rx_buffer.readU8();
                    const multiple = if (bitset0 & (1 << 0) == 0) true else false;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Basic.Ack\n", .{});
                    try ack(
                        conn,
                        delivery_tag,
                        multiple,
                    );
                },
                // reject
                90 => {
                    const reject = BASIC_IMPL.reject orelse return error.MethodNotImplemented;
                    const delivery_tag = conn.rx_buffer.readU64();
                    const bitset0 = conn.rx_buffer.readU8();
                    const requeue = if (bitset0 & (1 << 0) == 0) true else false;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Basic.Reject\n", .{});
                    try reject(
                        conn,
                        delivery_tag,
                        requeue,
                    );
                },
                // recover_async
                100 => {
                    const recover_async = BASIC_IMPL.recover_async orelse return error.MethodNotImplemented;
                    const bitset0 = conn.rx_buffer.readU8();
                    const requeue = if (bitset0 & (1 << 0) == 0) true else false;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Basic.Recover_async\n", .{});
                    try recover_async(
                        conn,
                        requeue,
                    );
                },
                // recover
                110 => {
                    const recover = BASIC_IMPL.recover orelse return error.MethodNotImplemented;
                    const bitset0 = conn.rx_buffer.readU8();
                    const requeue = if (bitset0 & (1 << 0) == 0) true else false;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Basic.Recover\n", .{});
                    try recover(
                        conn,
                        requeue,
                    );
                },
                // recover_ok
                111 => {
                    const recover_ok = BASIC_IMPL.recover_ok orelse return error.MethodNotImplemented;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Basic.Recover_ok\n", .{});
                    try recover_ok(
                        conn,
                    );
                },
                else => return error.UnknownMethod,
            }
        },
        // tx
        90 => {
            switch (method) {
                // select
                10 => {
                    const select = TX_IMPL.select orelse return error.MethodNotImplemented;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Tx.Select\n", .{});
                    try select(
                        conn,
                    );
                },
                // select_ok
                11 => {
                    const select_ok = TX_IMPL.select_ok orelse return error.MethodNotImplemented;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Tx.Select_ok\n", .{});
                    try select_ok(
                        conn,
                    );
                },
                // commit
                20 => {
                    const commit = TX_IMPL.commit orelse return error.MethodNotImplemented;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Tx.Commit\n", .{});
                    try commit(
                        conn,
                    );
                },
                // commit_ok
                21 => {
                    const commit_ok = TX_IMPL.commit_ok orelse return error.MethodNotImplemented;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Tx.Commit_ok\n", .{});
                    try commit_ok(
                        conn,
                    );
                },
                // rollback
                30 => {
                    const rollback = TX_IMPL.rollback orelse return error.MethodNotImplemented;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Tx.Rollback\n", .{});
                    try rollback(
                        conn,
                    );
                },
                // rollback_ok
                31 => {
                    const rollback_ok = TX_IMPL.rollback_ok orelse return error.MethodNotImplemented;
                    try conn.rx_buffer.readEOF();
                    if (std.builtin.mode == .Debug) std.debug.warn("Tx.Rollback_ok\n", .{});
                    try rollback_ok(
                        conn,
                    );
                },
                else => return error.UnknownMethod,
            }
        },
        else => return error.UnknownClass,
    }
}
pub fn isSynchronous(class_id: u16, method_id: u16) !bool {
    switch (class_id) {
        // connection
        10 => {
            switch (method_id) {
                // start
                10 => {
                    return true;
                },
                // start_ok
                11 => {
                    return true;
                },
                // secure
                20 => {
                    return true;
                },
                // secure_ok
                21 => {
                    return true;
                },
                // tune
                30 => {
                    return true;
                },
                // tune_ok
                31 => {
                    return true;
                },
                // open
                40 => {
                    return true;
                },
                // open_ok
                41 => {
                    return true;
                },
                // close
                50 => {
                    return true;
                },
                // close_ok
                51 => {
                    return true;
                },
                // blocked
                60 => {
                    return false;
                },
                // unblocked
                61 => {
                    return false;
                },
                else => return error.UnknownMethod,
            }
        },
        // channel
        20 => {
            switch (method_id) {
                // open
                10 => {
                    return true;
                },
                // open_ok
                11 => {
                    return true;
                },
                // flow
                20 => {
                    return true;
                },
                // flow_ok
                21 => {
                    return false;
                },
                // close
                40 => {
                    return true;
                },
                // close_ok
                41 => {
                    return true;
                },
                else => return error.UnknownMethod,
            }
        },
        // exchange
        40 => {
            switch (method_id) {
                // declare
                10 => {
                    return true;
                },
                // declare_ok
                11 => {
                    return true;
                },
                // delete
                20 => {
                    return true;
                },
                // delete_ok
                21 => {
                    return true;
                },
                else => return error.UnknownMethod,
            }
        },
        // queue
        50 => {
            switch (method_id) {
                // declare
                10 => {
                    return true;
                },
                // declare_ok
                11 => {
                    return true;
                },
                // bind
                20 => {
                    return true;
                },
                // bind_ok
                21 => {
                    return true;
                },
                // unbind
                50 => {
                    return true;
                },
                // unbind_ok
                51 => {
                    return true;
                },
                // purge
                30 => {
                    return true;
                },
                // purge_ok
                31 => {
                    return true;
                },
                // delete
                40 => {
                    return true;
                },
                // delete_ok
                41 => {
                    return true;
                },
                else => return error.UnknownMethod,
            }
        },
        // basic
        60 => {
            switch (method_id) {
                // qos
                10 => {
                    return true;
                },
                // qos_ok
                11 => {
                    return true;
                },
                // consume
                20 => {
                    return true;
                },
                // consume_ok
                21 => {
                    return true;
                },
                // cancel
                30 => {
                    return true;
                },
                // cancel_ok
                31 => {
                    return true;
                },
                // publish
                40 => {
                    return false;
                },
                // @"return"
                50 => {
                    return false;
                },
                // deliver
                60 => {
                    return false;
                },
                // get
                70 => {
                    return true;
                },
                // get_ok
                71 => {
                    return true;
                },
                // get_empty
                72 => {
                    return true;
                },
                // ack
                80 => {
                    return false;
                },
                // reject
                90 => {
                    return false;
                },
                // recover_async
                100 => {
                    return false;
                },
                // recover
                110 => {
                    return false;
                },
                // recover_ok
                111 => {
                    return true;
                },
                else => return error.UnknownMethod,
            }
        },
        // tx
        90 => {
            switch (method_id) {
                // select
                10 => {
                    return true;
                },
                // select_ok
                11 => {
                    return true;
                },
                // commit
                20 => {
                    return true;
                },
                // commit_ok
                21 => {
                    return true;
                },
                // rollback
                30 => {
                    return true;
                },
                // rollback_ok
                31 => {
                    return true;
                },
                else => return error.UnknownMethod,
            }
        },
        else => return error.UnknownClass,
    }
}
pub const FRAME_METHOD: u16 = 1;
pub const FRAME_HEADER: u16 = 2;
pub const FRAME_BODY: u16 = 3;
pub const FRAME_HEARTBEAT: u16 = 8;
pub const FRAME_MIN_SIZE: u16 = 4096;
pub const FRAME_END: u16 = 206;
pub const REPLY_SUCCESS: u16 = 200;
pub const CONTENT_TOO_LARGE: u16 = 311;
pub const NO_CONSUMERS: u16 = 313;
pub const CONNECTION_FORCED: u16 = 320;
pub const INVALID_PATH: u16 = 402;
pub const ACCESS_REFUSED: u16 = 403;
pub const NOT_FOUND: u16 = 404;
pub const RESOURCE_LOCKED: u16 = 405;
pub const PRECONDITION_FAILED: u16 = 406;
pub const FRAME_ERROR: u16 = 501;
pub const SYNTAX_ERROR: u16 = 502;
pub const COMMAND_INVALID: u16 = 503;
pub const CHANNEL_ERROR: u16 = 504;
pub const UNEXPECTED_FRAME: u16 = 505;
pub const RESOURCE_ERROR: u16 = 506;
pub const NOT_ALLOWED: u16 = 530;
pub const NOT_IMPLEMENTED: u16 = 540;
pub const INTERNAL_ERROR: u16 = 541;
pub const connection_interface = struct {
    start: ?fn (
        *Connector,
        version_major: u8,
        version_minor: u8,
        server_properties: ?*Table,
        mechanisms: []const u8,
        locales: []const u8,
    ) anyerror!void,
    start_ok: ?fn (
        *Connector,
        client_properties: ?*Table,
        mechanism: []const u8,
        response: []const u8,
        locale: []const u8,
    ) anyerror!void,
    secure: ?fn (
        *Connector,
        challenge: []const u8,
    ) anyerror!void,
    secure_ok: ?fn (
        *Connector,
        response: []const u8,
    ) anyerror!void,
    tune: ?fn (
        *Connector,
        channel_max: u16,
        frame_max: u32,
        heartbeat: u16,
    ) anyerror!void,
    tune_ok: ?fn (
        *Connector,
        channel_max: u16,
        frame_max: u32,
        heartbeat: u16,
    ) anyerror!void,
    open: ?fn (
        *Connector,
        virtual_host: []const u8,
    ) anyerror!void,
    open_ok: ?fn (
        *Connector,
    ) anyerror!void,
    close: ?fn (
        *Connector,
        reply_code: u16,
        reply_text: []const u8,
        class_id: u16,
        method_id: u16,
    ) anyerror!void,
    close_ok: ?fn (
        *Connector,
    ) anyerror!void,
    blocked: ?fn (
        *Connector,
        reason: []const u8,
    ) anyerror!void,
    unblocked: ?fn (
        *Connector,
    ) anyerror!void,
};

pub var CONNECTION_IMPL = connection_interface{
    .start = null,
    .start_ok = null,
    .secure = null,
    .secure_ok = null,
    .tune = null,
    .tune_ok = null,
    .open = null,
    .open_ok = null,
    .close = null,
    .close_ok = null,
    .blocked = null,
    .unblocked = null,
};

pub const CONNECTION_CLASS = 10; // CLASS
pub const Connection = struct {
    const Self = @This();
    // METHOD =============================
    pub const START_METHOD = 10;
    // METHOD =============================
    pub const START_OK_METHOD = 11;
    pub fn start_ok_resp(
        conn: *Connector,
        client_properties: ?*Table,
        mechanism: []const u8,
        response: []const u8,
        locale: []const u8,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.START_OK_METHOD);
        conn.tx_buffer.writeTable(client_properties);
        conn.tx_buffer.writeShortString(mechanism);
        conn.tx_buffer.writeLongString(response);
        conn.tx_buffer.writeShortString(locale);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
    }
    // METHOD =============================
    pub const SECURE_METHOD = 20;
    // METHOD =============================
    pub const SECURE_OK_METHOD = 21;
    pub fn secure_ok_resp(
        conn: *Connector,
        response: []const u8,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.SECURE_OK_METHOD);
        conn.tx_buffer.writeLongString(response);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
    }
    // METHOD =============================
    pub const TUNE_METHOD = 30;
    // METHOD =============================
    pub const TUNE_OK_METHOD = 31;
    pub fn tune_ok_resp(
        conn: *Connector,
        channel_max: u16,
        frame_max: u32,
        heartbeat: u16,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.TUNE_OK_METHOD);
        conn.tx_buffer.writeU16(channel_max);
        conn.tx_buffer.writeU32(frame_max);
        conn.tx_buffer.writeU16(heartbeat);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
    }
    // METHOD =============================
    pub const OPEN_METHOD = 40;
    pub fn open_sync(
        conn: *Connector,
        virtual_host: []const u8,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.OPEN_METHOD);
        conn.tx_buffer.writeShortString(virtual_host);
        const reserved_1 = "";
        conn.tx_buffer.writeShortString(reserved_1);
        const reserved_2 = false;
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (reserved_2) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        var received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = CONNECTION_CLASS, .method = Connection.OPEN_OK_METHOD };
            received_response = try conn.dispatch(expecting);
        }
    }
    // METHOD =============================
    pub const OPEN_OK_METHOD = 41;
    // METHOD =============================
    pub const CLOSE_METHOD = 50;
    pub fn close_sync(
        conn: *Connector,
        reply_code: u16,
        reply_text: []const u8,
        class_id: u16,
        method_id: u16,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.CLOSE_METHOD);
        conn.tx_buffer.writeU16(reply_code);
        conn.tx_buffer.writeShortString(reply_text);
        conn.tx_buffer.writeU16(class_id);
        conn.tx_buffer.writeU16(method_id);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        var received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = CONNECTION_CLASS, .method = Connection.CLOSE_OK_METHOD };
            received_response = try conn.dispatch(expecting);
        }
    }
    // METHOD =============================
    pub const CLOSE_OK_METHOD = 51;
    pub fn close_ok_resp(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.CLOSE_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
    }
    // METHOD =============================
    pub const BLOCKED_METHOD = 60;
    pub fn blocked_resp(
        conn: *Connector,
        reason: []const u8,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.BLOCKED_METHOD);
        conn.tx_buffer.writeShortString(reason);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
    }
    // METHOD =============================
    pub const UNBLOCKED_METHOD = 61;
    pub fn unblocked_resp(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CONNECTION_CLASS, Connection.UNBLOCKED_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
    }
};
pub const channel_interface = struct {
    open: ?fn (
        *Connector,
    ) anyerror!void,
    open_ok: ?fn (
        *Connector,
    ) anyerror!void,
    flow: ?fn (
        *Connector,
        active: bool,
    ) anyerror!void,
    flow_ok: ?fn (
        *Connector,
        active: bool,
    ) anyerror!void,
    close: ?fn (
        *Connector,
        reply_code: u16,
        reply_text: []const u8,
        class_id: u16,
        method_id: u16,
    ) anyerror!void,
    close_ok: ?fn (
        *Connector,
    ) anyerror!void,
};

pub var CHANNEL_IMPL = channel_interface{
    .open = null,
    .open_ok = null,
    .flow = null,
    .flow_ok = null,
    .close = null,
    .close_ok = null,
};

pub const CHANNEL_CLASS = 20; // CLASS
pub const Channel = struct {
    const Self = @This();
    // METHOD =============================
    pub const OPEN_METHOD = 10;
    pub fn open_sync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CHANNEL_CLASS, Channel.OPEN_METHOD);
        const reserved_1 = "";
        conn.tx_buffer.writeShortString(reserved_1);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        var received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = CHANNEL_CLASS, .method = Channel.OPEN_OK_METHOD };
            received_response = try conn.dispatch(expecting);
        }
    }
    // METHOD =============================
    pub const OPEN_OK_METHOD = 11;
    // METHOD =============================
    pub const FLOW_METHOD = 20;
    pub fn flow_sync(
        conn: *Connector,
        active: bool,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CHANNEL_CLASS, Channel.FLOW_METHOD);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (active) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        var received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = CHANNEL_CLASS, .method = Channel.FLOW_OK_METHOD };
            received_response = try conn.dispatch(expecting);
        }
    }
    // METHOD =============================
    pub const FLOW_OK_METHOD = 21;
    pub fn flow_ok_resp(
        conn: *Connector,
        active: bool,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CHANNEL_CLASS, Channel.FLOW_OK_METHOD);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (active) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
    }
    // METHOD =============================
    pub const CLOSE_METHOD = 40;
    pub fn close_sync(
        conn: *Connector,
        reply_code: u16,
        reply_text: []const u8,
        class_id: u16,
        method_id: u16,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CHANNEL_CLASS, Channel.CLOSE_METHOD);
        conn.tx_buffer.writeU16(reply_code);
        conn.tx_buffer.writeShortString(reply_text);
        conn.tx_buffer.writeU16(class_id);
        conn.tx_buffer.writeU16(method_id);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        var received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = CHANNEL_CLASS, .method = Channel.CLOSE_OK_METHOD };
            received_response = try conn.dispatch(expecting);
        }
    }
    // METHOD =============================
    pub const CLOSE_OK_METHOD = 41;
    pub fn close_ok_resp(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(CHANNEL_CLASS, Channel.CLOSE_OK_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
    }
};
pub const exchange_interface = struct {
    declare: ?fn (
        *Connector,
        exchange: []const u8,
        tipe: []const u8,
        passive: bool,
        durable: bool,
        no_wait: bool,
        arguments: ?*Table,
    ) anyerror!void,
    declare_ok: ?fn (
        *Connector,
    ) anyerror!void,
    delete: ?fn (
        *Connector,
        exchange: []const u8,
        if_unused: bool,
        no_wait: bool,
    ) anyerror!void,
    delete_ok: ?fn (
        *Connector,
    ) anyerror!void,
};

pub var EXCHANGE_IMPL = exchange_interface{
    .declare = null,
    .declare_ok = null,
    .delete = null,
    .delete_ok = null,
};

pub const EXCHANGE_CLASS = 40; // CLASS
pub const Exchange = struct {
    const Self = @This();
    // METHOD =============================
    pub const DECLARE_METHOD = 10;
    pub fn declare_sync(
        conn: *Connector,
        exchange: []const u8,
        tipe: []const u8,
        passive: bool,
        durable: bool,
        no_wait: bool,
        arguments: ?*Table,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(EXCHANGE_CLASS, Exchange.DECLARE_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(exchange);
        conn.tx_buffer.writeShortString(tipe);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (passive) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        if (durable) bitset0 |= (_bit << 1) else bitset0 &= ~(_bit << 1);
        const reserved_2 = false;
        if (reserved_2) bitset0 |= (_bit << 2) else bitset0 &= ~(_bit << 2);
        const reserved_3 = false;
        if (reserved_3) bitset0 |= (_bit << 3) else bitset0 &= ~(_bit << 3);
        if (no_wait) bitset0 |= (_bit << 4) else bitset0 &= ~(_bit << 4);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.writeTable(arguments);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        var received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = EXCHANGE_CLASS, .method = Exchange.DECLARE_OK_METHOD };
            received_response = try conn.dispatch(expecting);
        }
    }
    // METHOD =============================
    pub const DECLARE_OK_METHOD = 11;
    // METHOD =============================
    pub const DELETE_METHOD = 20;
    pub fn delete_sync(
        conn: *Connector,
        exchange: []const u8,
        if_unused: bool,
        no_wait: bool,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(EXCHANGE_CLASS, Exchange.DELETE_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(exchange);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (if_unused) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        if (no_wait) bitset0 |= (_bit << 1) else bitset0 &= ~(_bit << 1);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        var received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = EXCHANGE_CLASS, .method = Exchange.DELETE_OK_METHOD };
            received_response = try conn.dispatch(expecting);
        }
    }
    // METHOD =============================
    pub const DELETE_OK_METHOD = 21;
};
pub const queue_interface = struct {
    declare: ?fn (
        *Connector,
        queue: []const u8,
        passive: bool,
        durable: bool,
        exclusive: bool,
        auto_delete: bool,
        no_wait: bool,
        arguments: ?*Table,
    ) anyerror!void,
    declare_ok: ?fn (
        *Connector,
        queue: []const u8,
        message_count: u32,
        consumer_count: u32,
    ) anyerror!void,
    bind: ?fn (
        *Connector,
        queue: []const u8,
        exchange: []const u8,
        routing_key: []const u8,
        no_wait: bool,
        arguments: ?*Table,
    ) anyerror!void,
    bind_ok: ?fn (
        *Connector,
    ) anyerror!void,
    unbind: ?fn (
        *Connector,
        queue: []const u8,
        exchange: []const u8,
        routing_key: []const u8,
        arguments: ?*Table,
    ) anyerror!void,
    unbind_ok: ?fn (
        *Connector,
    ) anyerror!void,
    purge: ?fn (
        *Connector,
        queue: []const u8,
        no_wait: bool,
    ) anyerror!void,
    purge_ok: ?fn (
        *Connector,
        message_count: u32,
    ) anyerror!void,
    delete: ?fn (
        *Connector,
        queue: []const u8,
        if_unused: bool,
        if_empty: bool,
        no_wait: bool,
    ) anyerror!void,
    delete_ok: ?fn (
        *Connector,
        message_count: u32,
    ) anyerror!void,
};

pub var QUEUE_IMPL = queue_interface{
    .declare = null,
    .declare_ok = null,
    .bind = null,
    .bind_ok = null,
    .unbind = null,
    .unbind_ok = null,
    .purge = null,
    .purge_ok = null,
    .delete = null,
    .delete_ok = null,
};

pub const QUEUE_CLASS = 50; // CLASS
pub const Queue = struct {
    const Self = @This();
    // METHOD =============================
    pub const DECLARE_METHOD = 10;
    pub fn declare_sync(
        conn: *Connector,
        queue: []const u8,
        passive: bool,
        durable: bool,
        exclusive: bool,
        auto_delete: bool,
        no_wait: bool,
        arguments: ?*Table,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.DECLARE_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(queue);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (passive) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        if (durable) bitset0 |= (_bit << 1) else bitset0 &= ~(_bit << 1);
        if (exclusive) bitset0 |= (_bit << 2) else bitset0 &= ~(_bit << 2);
        if (auto_delete) bitset0 |= (_bit << 3) else bitset0 &= ~(_bit << 3);
        if (no_wait) bitset0 |= (_bit << 4) else bitset0 &= ~(_bit << 4);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.writeTable(arguments);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        var received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = QUEUE_CLASS, .method = Queue.DECLARE_OK_METHOD };
            received_response = try conn.dispatch(expecting);
        }
    }
    // METHOD =============================
    pub const DECLARE_OK_METHOD = 11;
    // METHOD =============================
    pub const BIND_METHOD = 20;
    pub fn bind_sync(
        conn: *Connector,
        queue: []const u8,
        exchange: []const u8,
        routing_key: []const u8,
        no_wait: bool,
        arguments: ?*Table,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.BIND_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(queue);
        conn.tx_buffer.writeShortString(exchange);
        conn.tx_buffer.writeShortString(routing_key);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (no_wait) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.writeTable(arguments);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        var received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = QUEUE_CLASS, .method = Queue.BIND_OK_METHOD };
            received_response = try conn.dispatch(expecting);
        }
    }
    // METHOD =============================
    pub const BIND_OK_METHOD = 21;
    // METHOD =============================
    pub const UNBIND_METHOD = 50;
    pub fn unbind_sync(
        conn: *Connector,
        queue: []const u8,
        exchange: []const u8,
        routing_key: []const u8,
        arguments: ?*Table,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.UNBIND_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(queue);
        conn.tx_buffer.writeShortString(exchange);
        conn.tx_buffer.writeShortString(routing_key);
        conn.tx_buffer.writeTable(arguments);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        var received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = QUEUE_CLASS, .method = Queue.UNBIND_OK_METHOD };
            received_response = try conn.dispatch(expecting);
        }
    }
    // METHOD =============================
    pub const UNBIND_OK_METHOD = 51;
    // METHOD =============================
    pub const PURGE_METHOD = 30;
    pub fn purge_sync(
        conn: *Connector,
        queue: []const u8,
        no_wait: bool,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.PURGE_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(queue);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (no_wait) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        var received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = QUEUE_CLASS, .method = Queue.PURGE_OK_METHOD };
            received_response = try conn.dispatch(expecting);
        }
    }
    // METHOD =============================
    pub const PURGE_OK_METHOD = 31;
    // METHOD =============================
    pub const DELETE_METHOD = 40;
    pub fn delete_sync(
        conn: *Connector,
        queue: []const u8,
        if_unused: bool,
        if_empty: bool,
        no_wait: bool,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(QUEUE_CLASS, Queue.DELETE_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(queue);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (if_unused) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        if (if_empty) bitset0 |= (_bit << 1) else bitset0 &= ~(_bit << 1);
        if (no_wait) bitset0 |= (_bit << 2) else bitset0 &= ~(_bit << 2);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        var received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = QUEUE_CLASS, .method = Queue.DELETE_OK_METHOD };
            received_response = try conn.dispatch(expecting);
        }
    }
    // METHOD =============================
    pub const DELETE_OK_METHOD = 41;
};
pub const basic_interface = struct {
    qos: ?fn (
        *Connector,
        prefetch_size: u32,
        prefetch_count: u16,
        global: bool,
    ) anyerror!void,
    qos_ok: ?fn (
        *Connector,
    ) anyerror!void,
    consume: ?fn (
        *Connector,
        queue: []const u8,
        consumer_tag: []const u8,
        no_local: bool,
        no_ack: bool,
        exclusive: bool,
        no_wait: bool,
        arguments: ?*Table,
    ) anyerror!void,
    consume_ok: ?fn (
        *Connector,
        consumer_tag: []const u8,
    ) anyerror!void,
    cancel: ?fn (
        *Connector,
        consumer_tag: []const u8,
        no_wait: bool,
    ) anyerror!void,
    cancel_ok: ?fn (
        *Connector,
        consumer_tag: []const u8,
    ) anyerror!void,
    publish: ?fn (
        *Connector,
        exchange: []const u8,
        routing_key: []const u8,
        mandatory: bool,
        immediate: bool,
    ) anyerror!void,
    @"return": ?fn (
        *Connector,
        reply_code: u16,
        reply_text: []const u8,
        exchange: []const u8,
        routing_key: []const u8,
    ) anyerror!void,
    deliver: ?fn (
        *Connector,
        consumer_tag: []const u8,
        delivery_tag: u64,
        redelivered: bool,
        exchange: []const u8,
        routing_key: []const u8,
    ) anyerror!void,
    get: ?fn (
        *Connector,
        queue: []const u8,
        no_ack: bool,
    ) anyerror!void,
    get_ok: ?fn (
        *Connector,
        delivery_tag: u64,
        redelivered: bool,
        exchange: []const u8,
        routing_key: []const u8,
        message_count: u32,
    ) anyerror!void,
    get_empty: ?fn (
        *Connector,
    ) anyerror!void,
    ack: ?fn (
        *Connector,
        delivery_tag: u64,
        multiple: bool,
    ) anyerror!void,
    reject: ?fn (
        *Connector,
        delivery_tag: u64,
        requeue: bool,
    ) anyerror!void,
    recover_async: ?fn (
        *Connector,
        requeue: bool,
    ) anyerror!void,
    recover: ?fn (
        *Connector,
        requeue: bool,
    ) anyerror!void,
    recover_ok: ?fn (
        *Connector,
    ) anyerror!void,
};

pub var BASIC_IMPL = basic_interface{
    .qos = null,
    .qos_ok = null,
    .consume = null,
    .consume_ok = null,
    .cancel = null,
    .cancel_ok = null,
    .publish = null,
    .@"return" = null,
    .deliver = null,
    .get = null,
    .get_ok = null,
    .get_empty = null,
    .ack = null,
    .reject = null,
    .recover_async = null,
    .recover = null,
    .recover_ok = null,
};

pub const BASIC_CLASS = 60; // CLASS
pub const Basic = struct {
    const Self = @This();
    // METHOD =============================
    pub const QOS_METHOD = 10;
    pub fn qos_sync(
        conn: *Connector,
        prefetch_size: u32,
        prefetch_count: u16,
        global: bool,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.QOS_METHOD);
        conn.tx_buffer.writeU32(prefetch_size);
        conn.tx_buffer.writeU16(prefetch_count);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (global) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        var received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = BASIC_CLASS, .method = Basic.QOS_OK_METHOD };
            received_response = try conn.dispatch(expecting);
        }
    }
    // METHOD =============================
    pub const QOS_OK_METHOD = 11;
    // METHOD =============================
    pub const CONSUME_METHOD = 20;
    pub fn consume_sync(
        conn: *Connector,
        queue: []const u8,
        consumer_tag: []const u8,
        no_local: bool,
        no_ack: bool,
        exclusive: bool,
        no_wait: bool,
        arguments: ?*Table,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.CONSUME_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(queue);
        conn.tx_buffer.writeShortString(consumer_tag);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (no_local) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        if (no_ack) bitset0 |= (_bit << 1) else bitset0 &= ~(_bit << 1);
        if (exclusive) bitset0 |= (_bit << 2) else bitset0 &= ~(_bit << 2);
        if (no_wait) bitset0 |= (_bit << 3) else bitset0 &= ~(_bit << 3);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.writeTable(arguments);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        var received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = BASIC_CLASS, .method = Basic.CONSUME_OK_METHOD };
            received_response = try conn.dispatch(expecting);
        }
    }
    // METHOD =============================
    pub const CONSUME_OK_METHOD = 21;
    // METHOD =============================
    pub const CANCEL_METHOD = 30;
    pub fn cancel_sync(
        conn: *Connector,
        consumer_tag: []const u8,
        no_wait: bool,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.CANCEL_METHOD);
        conn.tx_buffer.writeShortString(consumer_tag);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (no_wait) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        var received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = BASIC_CLASS, .method = Basic.CANCEL_OK_METHOD };
            received_response = try conn.dispatch(expecting);
        }
    }
    // METHOD =============================
    pub const CANCEL_OK_METHOD = 31;
    // METHOD =============================
    pub const PUBLISH_METHOD = 40;
    pub fn publish_resp(
        conn: *Connector,
        exchange: []const u8,
        routing_key: []const u8,
        mandatory: bool,
        immediate: bool,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.PUBLISH_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(exchange);
        conn.tx_buffer.writeShortString(routing_key);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (mandatory) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        if (immediate) bitset0 |= (_bit << 1) else bitset0 &= ~(_bit << 1);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
    }
    // METHOD =============================
    pub const RETURN_METHOD = 50;
    // METHOD =============================
    pub const DELIVER_METHOD = 60;
    // METHOD =============================
    pub const GET_METHOD = 70;
    pub fn get_sync(
        conn: *Connector,
        queue: []const u8,
        no_ack: bool,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.GET_METHOD);
        const reserved_1 = 0;
        conn.tx_buffer.writeU16(reserved_1);
        conn.tx_buffer.writeShortString(queue);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (no_ack) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        var received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = BASIC_CLASS, .method = Basic.GET_OK_METHOD };
            received_response = try conn.dispatch(expecting);
        }
    }
    // METHOD =============================
    pub const GET_OK_METHOD = 71;
    // METHOD =============================
    pub const GET_EMPTY_METHOD = 72;
    // METHOD =============================
    pub const ACK_METHOD = 80;
    pub fn ack_resp(
        conn: *Connector,
        delivery_tag: u64,
        multiple: bool,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.ACK_METHOD);
        conn.tx_buffer.writeU64(delivery_tag);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (multiple) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
    }
    // METHOD =============================
    pub const REJECT_METHOD = 90;
    pub fn reject_resp(
        conn: *Connector,
        delivery_tag: u64,
        requeue: bool,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.REJECT_METHOD);
        conn.tx_buffer.writeU64(delivery_tag);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (requeue) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
    }
    // METHOD =============================
    pub const RECOVER_ASYNC_METHOD = 100;
    pub fn recover_async_resp(
        conn: *Connector,
        requeue: bool,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.RECOVER_ASYNC_METHOD);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (requeue) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
    }
    // METHOD =============================
    pub const RECOVER_METHOD = 110;
    pub fn recover_resp(
        conn: *Connector,
        requeue: bool,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(BASIC_CLASS, Basic.RECOVER_METHOD);
        var bitset0: u8 = 0;
        const _bit: u8 = 1;
        if (requeue) bitset0 |= (_bit << 0) else bitset0 &= ~(_bit << 0);
        conn.tx_buffer.writeU8(bitset0);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
    }
    // METHOD =============================
    pub const RECOVER_OK_METHOD = 111;
};
pub const tx_interface = struct {
    select: ?fn (
        *Connector,
    ) anyerror!void,
    select_ok: ?fn (
        *Connector,
    ) anyerror!void,
    commit: ?fn (
        *Connector,
    ) anyerror!void,
    commit_ok: ?fn (
        *Connector,
    ) anyerror!void,
    rollback: ?fn (
        *Connector,
    ) anyerror!void,
    rollback_ok: ?fn (
        *Connector,
    ) anyerror!void,
};

pub var TX_IMPL = tx_interface{
    .select = null,
    .select_ok = null,
    .commit = null,
    .commit_ok = null,
    .rollback = null,
    .rollback_ok = null,
};

pub const TX_CLASS = 90; // CLASS
pub const Tx = struct {
    const Self = @This();
    // METHOD =============================
    pub const SELECT_METHOD = 10;
    pub fn select_sync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(TX_CLASS, Tx.SELECT_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        var received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = TX_CLASS, .method = Tx.SELECT_OK_METHOD };
            received_response = try conn.dispatch(expecting);
        }
    }
    // METHOD =============================
    pub const SELECT_OK_METHOD = 11;
    // METHOD =============================
    pub const COMMIT_METHOD = 20;
    pub fn commit_sync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(TX_CLASS, Tx.COMMIT_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        var received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = TX_CLASS, .method = Tx.COMMIT_OK_METHOD };
            received_response = try conn.dispatch(expecting);
        }
    }
    // METHOD =============================
    pub const COMMIT_OK_METHOD = 21;
    // METHOD =============================
    pub const ROLLBACK_METHOD = 30;
    pub fn rollback_sync(
        conn: *Connector,
    ) !void {
        conn.tx_buffer.writeFrameHeader(.Method, conn.channel, 0);
        conn.tx_buffer.writeMethodHeader(TX_CLASS, Tx.ROLLBACK_METHOD);
        conn.tx_buffer.updateFrameLength();
        const n = try std.os.write(conn.file.handle, conn.tx_buffer.extent());
        conn.tx_buffer.reset();
        var received_response = false;
        while (!received_response) {
            const expecting: ClassMethod = .{ .class = TX_CLASS, .method = Tx.ROLLBACK_OK_METHOD };
            received_response = try conn.dispatch(expecting);
        }
    }
    // METHOD =============================
    pub const ROLLBACK_OK_METHOD = 31;
};
