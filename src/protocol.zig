const std = @import("std");
const Wire = @import("connection.zig").Wire;
// amqp
pub fn dispatchCallback(conn: *Wire, class_id: u16, method_id: u16) !void {
    switch (class_id) {
        // connection
        10 => {
            switch (method_id) {
                // start
                10 => {
                    const start = CONNECTION_IMPL.start orelse return error.MethodNotImplemented;
                    const version_major = void;
                    const version_minor = void;
                    const server_properties = void;
                    const mechanisms = void;
                    const locales = void;
                    try start(
                        version_major,
                        version_minor,
                        server_properties,
                        mechanisms,
                        locales,
                    );
                },
                // start_ok
                11 => {
                    const start_ok = CONNECTION_IMPL.start_ok orelse return error.MethodNotImplemented;
                    const client_properties = void;
                    const mechanism = void;
                    const response = void;
                    const locale = void;
                    try start_ok(
                        client_properties,
                        mechanism,
                        response,
                        locale,
                    );
                },
                // secure
                20 => {
                    const secure = CONNECTION_IMPL.secure orelse return error.MethodNotImplemented;
                    const challenge = void;
                    try secure(
                        challenge,
                    );
                },
                // secure_ok
                21 => {
                    const secure_ok = CONNECTION_IMPL.secure_ok orelse return error.MethodNotImplemented;
                    const response = void;
                    try secure_ok(
                        response,
                    );
                },
                // tune
                30 => {
                    const tune = CONNECTION_IMPL.tune orelse return error.MethodNotImplemented;
                    const channel_max = void;
                    const frame_max = void;
                    const heartbeat = void;
                    try tune(
                        channel_max,
                        frame_max,
                        heartbeat,
                    );
                },
                // tune_ok
                31 => {
                    const tune_ok = CONNECTION_IMPL.tune_ok orelse return error.MethodNotImplemented;
                    const channel_max = void;
                    const frame_max = void;
                    const heartbeat = void;
                    try tune_ok(
                        channel_max,
                        frame_max,
                        heartbeat,
                    );
                },
                // open
                40 => {
                    const open = CONNECTION_IMPL.open orelse return error.MethodNotImplemented;
                    const virtual_host = void;
                    const reserved_1 = void;
                    const reserved_2 = void;
                    try open(
                        virtual_host,
                        reserved_1,
                        reserved_2,
                    );
                },
                // open_ok
                41 => {
                    const open_ok = CONNECTION_IMPL.open_ok orelse return error.MethodNotImplemented;
                    const reserved_1 = void;
                    try open_ok(
                        reserved_1,
                    );
                },
                // close
                50 => {
                    const close = CONNECTION_IMPL.close orelse return error.MethodNotImplemented;
                    const reply_code = void;
                    const reply_text = void;
                    const class_id = void;
                    const method_id = void;
                    try close(
                        reply_code,
                        reply_text,
                        class_id,
                        method_id,
                    );
                },
                // close_ok
                51 => {
                    const close_ok = CONNECTION_IMPL.close_ok orelse return error.MethodNotImplemented;
                    try close_ok();
                },
                // blocked
                60 => {
                    const blocked = CONNECTION_IMPL.blocked orelse return error.MethodNotImplemented;
                    const reason = void;
                    try blocked(
                        reason,
                    );
                },
                // unblocked
                61 => {
                    const unblocked = CONNECTION_IMPL.unblocked orelse return error.MethodNotImplemented;
                    try unblocked();
                },
                else => return error.UnknownMethod,
            }
        },
        // channel
        20 => {
            switch (method_id) {
                // open
                10 => {
                    const open = CHANNEL_IMPL.open orelse return error.MethodNotImplemented;
                    const reserved_1 = void;
                    try open(
                        reserved_1,
                    );
                },
                // open_ok
                11 => {
                    const open_ok = CHANNEL_IMPL.open_ok orelse return error.MethodNotImplemented;
                    const reserved_1 = void;
                    try open_ok(
                        reserved_1,
                    );
                },
                // flow
                20 => {
                    const flow = CHANNEL_IMPL.flow orelse return error.MethodNotImplemented;
                    const active = void;
                    try flow(
                        active,
                    );
                },
                // flow_ok
                21 => {
                    const flow_ok = CHANNEL_IMPL.flow_ok orelse return error.MethodNotImplemented;
                    const active = void;
                    try flow_ok(
                        active,
                    );
                },
                // close
                40 => {
                    const close = CHANNEL_IMPL.close orelse return error.MethodNotImplemented;
                    const reply_code = void;
                    const reply_text = void;
                    const class_id = void;
                    const method_id = void;
                    try close(
                        reply_code,
                        reply_text,
                        class_id,
                        method_id,
                    );
                },
                // close_ok
                41 => {
                    const close_ok = CHANNEL_IMPL.close_ok orelse return error.MethodNotImplemented;
                    try close_ok();
                },
                else => return error.UnknownMethod,
            }
        },
        // exchange
        40 => {
            switch (method_id) {
                // declare
                10 => {
                    const declare = EXCHANGE_IMPL.declare orelse return error.MethodNotImplemented;
                    const reserved_1 = void;
                    const exchange = void;
                    const @"type" = void;
                    const passive = void;
                    const durable = void;
                    const reserved_2 = void;
                    const reserved_3 = void;
                    const no_wait = void;
                    const arguments = void;
                    try declare(
                        reserved_1,
                        exchange,
                        @"type",
                        passive,
                        durable,
                        reserved_2,
                        reserved_3,
                        no_wait,
                        arguments,
                    );
                },
                // declare_ok
                11 => {
                    const declare_ok = EXCHANGE_IMPL.declare_ok orelse return error.MethodNotImplemented;
                    try declare_ok();
                },
                // delete
                20 => {
                    const delete = EXCHANGE_IMPL.delete orelse return error.MethodNotImplemented;
                    const reserved_1 = void;
                    const exchange = void;
                    const if_unused = void;
                    const no_wait = void;
                    try delete(
                        reserved_1,
                        exchange,
                        if_unused,
                        no_wait,
                    );
                },
                // delete_ok
                21 => {
                    const delete_ok = EXCHANGE_IMPL.delete_ok orelse return error.MethodNotImplemented;
                    try delete_ok();
                },
                else => return error.UnknownMethod,
            }
        },
        // queue
        50 => {
            switch (method_id) {
                // declare
                10 => {
                    const declare = QUEUE_IMPL.declare orelse return error.MethodNotImplemented;
                    const reserved_1 = void;
                    const queue = void;
                    const passive = void;
                    const durable = void;
                    const exclusive = void;
                    const auto_delete = void;
                    const no_wait = void;
                    const arguments = void;
                    try declare(
                        reserved_1,
                        queue,
                        passive,
                        durable,
                        exclusive,
                        auto_delete,
                        no_wait,
                        arguments,
                    );
                },
                // declare_ok
                11 => {
                    const declare_ok = QUEUE_IMPL.declare_ok orelse return error.MethodNotImplemented;
                    const queue = void;
                    const message_count = void;
                    const consumer_count = void;
                    try declare_ok(
                        queue,
                        message_count,
                        consumer_count,
                    );
                },
                // bind
                20 => {
                    const bind = QUEUE_IMPL.bind orelse return error.MethodNotImplemented;
                    const reserved_1 = void;
                    const queue = void;
                    const exchange = void;
                    const routing_key = void;
                    const no_wait = void;
                    const arguments = void;
                    try bind(
                        reserved_1,
                        queue,
                        exchange,
                        routing_key,
                        no_wait,
                        arguments,
                    );
                },
                // bind_ok
                21 => {
                    const bind_ok = QUEUE_IMPL.bind_ok orelse return error.MethodNotImplemented;
                    try bind_ok();
                },
                // unbind
                50 => {
                    const unbind = QUEUE_IMPL.unbind orelse return error.MethodNotImplemented;
                    const reserved_1 = void;
                    const queue = void;
                    const exchange = void;
                    const routing_key = void;
                    const arguments = void;
                    try unbind(
                        reserved_1,
                        queue,
                        exchange,
                        routing_key,
                        arguments,
                    );
                },
                // unbind_ok
                51 => {
                    const unbind_ok = QUEUE_IMPL.unbind_ok orelse return error.MethodNotImplemented;
                    try unbind_ok();
                },
                // purge
                30 => {
                    const purge = QUEUE_IMPL.purge orelse return error.MethodNotImplemented;
                    const reserved_1 = void;
                    const queue = void;
                    const no_wait = void;
                    try purge(
                        reserved_1,
                        queue,
                        no_wait,
                    );
                },
                // purge_ok
                31 => {
                    const purge_ok = QUEUE_IMPL.purge_ok orelse return error.MethodNotImplemented;
                    const message_count = void;
                    try purge_ok(
                        message_count,
                    );
                },
                // delete
                40 => {
                    const delete = QUEUE_IMPL.delete orelse return error.MethodNotImplemented;
                    const reserved_1 = void;
                    const queue = void;
                    const if_unused = void;
                    const if_empty = void;
                    const no_wait = void;
                    try delete(
                        reserved_1,
                        queue,
                        if_unused,
                        if_empty,
                        no_wait,
                    );
                },
                // delete_ok
                41 => {
                    const delete_ok = QUEUE_IMPL.delete_ok orelse return error.MethodNotImplemented;
                    const message_count = void;
                    try delete_ok(
                        message_count,
                    );
                },
                else => return error.UnknownMethod,
            }
        },
        // basic
        60 => {
            switch (method_id) {
                // qos
                10 => {
                    const qos = BASIC_IMPL.qos orelse return error.MethodNotImplemented;
                    const prefetch_size = void;
                    const prefetch_count = void;
                    const global = void;
                    try qos(
                        prefetch_size,
                        prefetch_count,
                        global,
                    );
                },
                // qos_ok
                11 => {
                    const qos_ok = BASIC_IMPL.qos_ok orelse return error.MethodNotImplemented;
                    try qos_ok();
                },
                // consume
                20 => {
                    const consume = BASIC_IMPL.consume orelse return error.MethodNotImplemented;
                    const reserved_1 = void;
                    const queue = void;
                    const consumer_tag = void;
                    const no_local = void;
                    const no_ack = void;
                    const exclusive = void;
                    const no_wait = void;
                    const arguments = void;
                    try consume(
                        reserved_1,
                        queue,
                        consumer_tag,
                        no_local,
                        no_ack,
                        exclusive,
                        no_wait,
                        arguments,
                    );
                },
                // consume_ok
                21 => {
                    const consume_ok = BASIC_IMPL.consume_ok orelse return error.MethodNotImplemented;
                    const consumer_tag = void;
                    try consume_ok(
                        consumer_tag,
                    );
                },
                // cancel
                30 => {
                    const cancel = BASIC_IMPL.cancel orelse return error.MethodNotImplemented;
                    const consumer_tag = void;
                    const no_wait = void;
                    try cancel(
                        consumer_tag,
                        no_wait,
                    );
                },
                // cancel_ok
                31 => {
                    const cancel_ok = BASIC_IMPL.cancel_ok orelse return error.MethodNotImplemented;
                    const consumer_tag = void;
                    try cancel_ok(
                        consumer_tag,
                    );
                },
                // publish
                40 => {
                    const publish = BASIC_IMPL.publish orelse return error.MethodNotImplemented;
                    const reserved_1 = void;
                    const exchange = void;
                    const routing_key = void;
                    const mandatory = void;
                    const immediate = void;
                    try publish(
                        reserved_1,
                        exchange,
                        routing_key,
                        mandatory,
                        immediate,
                    );
                },
                // @"return"
                50 => {
                    const @"return" = BASIC_IMPL.@"return" orelse return error.MethodNotImplemented;
                    const reply_code = void;
                    const reply_text = void;
                    const exchange = void;
                    const routing_key = void;
                    try @"return"(
                        reply_code,
                        reply_text,
                        exchange,
                        routing_key,
                    );
                },
                // deliver
                60 => {
                    const deliver = BASIC_IMPL.deliver orelse return error.MethodNotImplemented;
                    const consumer_tag = void;
                    const delivery_tag = void;
                    const redelivered = void;
                    const exchange = void;
                    const routing_key = void;
                    try deliver(
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
                    const reserved_1 = void;
                    const queue = void;
                    const no_ack = void;
                    try get(
                        reserved_1,
                        queue,
                        no_ack,
                    );
                },
                // get_ok
                71 => {
                    const get_ok = BASIC_IMPL.get_ok orelse return error.MethodNotImplemented;
                    const delivery_tag = void;
                    const redelivered = void;
                    const exchange = void;
                    const routing_key = void;
                    const message_count = void;
                    try get_ok(
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
                    const reserved_1 = void;
                    try get_empty(
                        reserved_1,
                    );
                },
                // ack
                80 => {
                    const ack = BASIC_IMPL.ack orelse return error.MethodNotImplemented;
                    const delivery_tag = void;
                    const multiple = void;
                    try ack(
                        delivery_tag,
                        multiple,
                    );
                },
                // reject
                90 => {
                    const reject = BASIC_IMPL.reject orelse return error.MethodNotImplemented;
                    const delivery_tag = void;
                    const requeue = void;
                    try reject(
                        delivery_tag,
                        requeue,
                    );
                },
                // recover_async
                100 => {
                    const recover_async = BASIC_IMPL.recover_async orelse return error.MethodNotImplemented;
                    const requeue = void;
                    try recover_async(
                        requeue,
                    );
                },
                // recover
                110 => {
                    const recover = BASIC_IMPL.recover orelse return error.MethodNotImplemented;
                    const requeue = void;
                    try recover(
                        requeue,
                    );
                },
                // recover_ok
                111 => {
                    const recover_ok = BASIC_IMPL.recover_ok orelse return error.MethodNotImplemented;
                    try recover_ok();
                },
                else => return error.UnknownMethod,
            }
        },
        // tx
        90 => {
            switch (method_id) {
                // select
                10 => {
                    const select = TX_IMPL.select orelse return error.MethodNotImplemented;
                    try select();
                },
                // select_ok
                11 => {
                    const select_ok = TX_IMPL.select_ok orelse return error.MethodNotImplemented;
                    try select_ok();
                },
                // commit
                20 => {
                    const commit = TX_IMPL.commit orelse return error.MethodNotImplemented;
                    try commit();
                },
                // commit_ok
                21 => {
                    const commit_ok = TX_IMPL.commit_ok orelse return error.MethodNotImplemented;
                    try commit_ok();
                },
                // rollback
                30 => {
                    const rollback = TX_IMPL.rollback orelse return error.MethodNotImplemented;
                    try rollback();
                },
                // rollback_ok
                31 => {
                    const rollback_ok = TX_IMPL.rollback_ok orelse return error.MethodNotImplemented;
                    try rollback_ok();
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
const frame_method: u16 = 1;
const frame_header: u16 = 2;
const frame_body: u16 = 3;
const frame_heartbeat: u16 = 8;
const frame_min_size: u16 = 4096;
const frame_end: u16 = 206;
const reply_success: u16 = 200;
const content_too_large: u16 = 311;
const no_consumers: u16 = 313;
const connection_forced: u16 = 320;
const invalid_path: u16 = 402;
const access_refused: u16 = 403;
const not_found: u16 = 404;
const resource_locked: u16 = 405;
const precondition_failed: u16 = 406;
const frame_error: u16 = 501;
const syntax_error: u16 = 502;
const command_invalid: u16 = 503;
const channel_error: u16 = 504;
const unexpected_frame: u16 = 505;
const resource_error: u16 = 506;
const not_allowed: u16 = 530;
const not_implemented: u16 = 540;
const internal_error: u16 = 541;
pub const connection_interface = struct {
    start: ?fn (
        version_major: u8,
        version_minor: u8,
        server_properties: []u8,
        mechanisms: []u8,
        locales: []u8,
    ) anyerror!void,
    start_ok: ?fn (
        client_properties: []u8,
        mechanism: ?[128]u8,
        response: []u8,
        locale: ?[128]u8,
    ) anyerror!void,
    secure: ?fn (
        challenge: []u8,
    ) anyerror!void,
    secure_ok: ?fn (
        response: []u8,
    ) anyerror!void,
    tune: ?fn (
        channel_max: u16,
        frame_max: u32,
        heartbeat: u16,
    ) anyerror!void,
    tune_ok: ?fn (
        channel_max: u16,
        frame_max: u32,
        heartbeat: u16,
    ) anyerror!void,
    open: ?fn (
        virtual_host: ?[128]u8,
        reserved_1: ?[128]u8,
        reserved_2: bool,
    ) anyerror!void,
    open_ok: ?fn (
        reserved_1: ?[128]u8,
    ) anyerror!void,
    close: ?fn (
        reply_code: u16,
        reply_text: []u8,
        class_id: u16,
        method_id: u16,
    ) anyerror!void,
    close_ok: ?fn () anyerror!void,
    blocked: ?fn (
        reason: ?[128]u8,
    ) anyerror!void,
    unblocked: ?fn () anyerror!void,
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

pub const CONNECTION_INDEX = 10; // CLASS
pub const Connection = struct {
    conn: *Wire,
    const Self = @This();
    // METHOD =============================
    pub const OPEN_INDEX = 40;
    pub fn open_sync(
        self: *Self,
        virtual_host: ?[128]u8,
    ) void {
        const n = try os.write(self.conn.file, self.conn.tx_buffer[0..]);
        while (true) {
            const message = try self.conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const CLOSE_INDEX = 50;
    pub fn close_sync(
        self: *Self,
        reply_code: u16,
        reply_text: []u8,
        class_id: u16,
        method_id: u16,
    ) void {
        const n = try os.write(self.conn.file, self.conn.tx_buffer[0..]);
        while (true) {
            const message = try self.conn.dispatch(allocator, null);
        }
    }
};
pub const channel_interface = struct {
    open: ?fn (
        reserved_1: ?[128]u8,
    ) anyerror!void,
    open_ok: ?fn (
        reserved_1: []u8,
    ) anyerror!void,
    flow: ?fn (
        active: bool,
    ) anyerror!void,
    flow_ok: ?fn (
        active: bool,
    ) anyerror!void,
    close: ?fn (
        reply_code: u16,
        reply_text: []u8,
        class_id: u16,
        method_id: u16,
    ) anyerror!void,
    close_ok: ?fn () anyerror!void,
};

pub var CHANNEL_IMPL = channel_interface{
    .open = null,
    .open_ok = null,
    .flow = null,
    .flow_ok = null,
    .close = null,
    .close_ok = null,
};

pub const CHANNEL_INDEX = 20; // CLASS
pub const Channel = struct {
    conn: *Wire,
    const Self = @This();
    // METHOD =============================
    pub const OPEN_INDEX = 10;
    pub fn open_sync(
        self: *Self,
    ) void {
        const n = try os.write(self.conn.file, self.conn.tx_buffer[0..]);
        while (true) {
            const message = try self.conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const FLOW_INDEX = 20;
    pub fn flow_sync(
        self: *Self,
        active: bool,
    ) void {
        const n = try os.write(self.conn.file, self.conn.tx_buffer[0..]);
        while (true) {
            const message = try self.conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const CLOSE_INDEX = 40;
    pub fn close_sync(
        self: *Self,
        reply_code: u16,
        reply_text: []u8,
        class_id: u16,
        method_id: u16,
    ) void {
        const n = try os.write(self.conn.file, self.conn.tx_buffer[0..]);
        while (true) {
            const message = try self.conn.dispatch(allocator, null);
        }
    }
};
pub const exchange_interface = struct {
    declare: ?fn (
        reserved_1: u16,
        exchange: [128]u8,
        @"type": ?[128]u8,
        passive: bool,
        durable: bool,
        reserved_2: bool,
        reserved_3: bool,
        no_wait: bool,
        arguments: void,
    ) anyerror!void,
    declare_ok: ?fn () anyerror!void,
    delete: ?fn (
        reserved_1: u16,
        exchange: [128]u8,
        if_unused: bool,
        no_wait: bool,
    ) anyerror!void,
    delete_ok: ?fn () anyerror!void,
};

pub var EXCHANGE_IMPL = exchange_interface{
    .declare = null,
    .declare_ok = null,
    .delete = null,
    .delete_ok = null,
};

pub const EXCHANGE_INDEX = 40; // CLASS
pub const Exchange = struct {
    conn: *Wire,
    const Self = @This();
    // METHOD =============================
    pub const DECLARE_INDEX = 10;
    pub fn declare_sync(
        self: *Self,
        exchange: [128]u8,
        @"type": ?[128]u8,
        passive: bool,
        durable: bool,
        no_wait: bool,
        arguments: void,
    ) void {
        const n = try os.write(self.conn.file, self.conn.tx_buffer[0..]);
        while (true) {
            const message = try self.conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const DELETE_INDEX = 20;
    pub fn delete_sync(
        self: *Self,
        exchange: [128]u8,
        if_unused: bool,
        no_wait: bool,
    ) void {
        const n = try os.write(self.conn.file, self.conn.tx_buffer[0..]);
        while (true) {
            const message = try self.conn.dispatch(allocator, null);
        }
    }
};
pub const queue_interface = struct {
    declare: ?fn (
        reserved_1: u16,
        queue: [128]u8,
        passive: bool,
        durable: bool,
        exclusive: bool,
        auto_delete: bool,
        no_wait: bool,
        arguments: void,
    ) anyerror!void,
    declare_ok: ?fn (
        queue: [128]u8,
        message_count: void,
        consumer_count: u32,
    ) anyerror!void,
    bind: ?fn (
        reserved_1: u16,
        queue: [128]u8,
        exchange: [128]u8,
        routing_key: ?[128]u8,
        no_wait: bool,
        arguments: void,
    ) anyerror!void,
    bind_ok: ?fn () anyerror!void,
    unbind: ?fn (
        reserved_1: u16,
        queue: [128]u8,
        exchange: [128]u8,
        routing_key: ?[128]u8,
        arguments: void,
    ) anyerror!void,
    unbind_ok: ?fn () anyerror!void,
    purge: ?fn (
        reserved_1: u16,
        queue: [128]u8,
        no_wait: bool,
    ) anyerror!void,
    purge_ok: ?fn (
        message_count: void,
    ) anyerror!void,
    delete: ?fn (
        reserved_1: u16,
        queue: [128]u8,
        if_unused: bool,
        if_empty: bool,
        no_wait: bool,
    ) anyerror!void,
    delete_ok: ?fn (
        message_count: void,
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

pub const QUEUE_INDEX = 50; // CLASS
pub const Queue = struct {
    conn: *Wire,
    const Self = @This();
    // METHOD =============================
    pub const DECLARE_INDEX = 10;
    pub fn declare_sync(
        self: *Self,
        queue: [128]u8,
        passive: bool,
        durable: bool,
        exclusive: bool,
        auto_delete: bool,
        no_wait: bool,
        arguments: void,
    ) void {
        const n = try os.write(self.conn.file, self.conn.tx_buffer[0..]);
        while (true) {
            const message = try self.conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const BIND_INDEX = 20;
    pub fn bind_sync(
        self: *Self,
        queue: [128]u8,
        exchange: [128]u8,
        routing_key: ?[128]u8,
        no_wait: bool,
        arguments: void,
    ) void {
        const n = try os.write(self.conn.file, self.conn.tx_buffer[0..]);
        while (true) {
            const message = try self.conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const UNBIND_INDEX = 50;
    pub fn unbind_sync(
        self: *Self,
        queue: [128]u8,
        exchange: [128]u8,
        routing_key: ?[128]u8,
        arguments: void,
    ) void {
        const n = try os.write(self.conn.file, self.conn.tx_buffer[0..]);
        while (true) {
            const message = try self.conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const PURGE_INDEX = 30;
    pub fn purge_sync(
        self: *Self,
        queue: [128]u8,
        no_wait: bool,
    ) void {
        const n = try os.write(self.conn.file, self.conn.tx_buffer[0..]);
        while (true) {
            const message = try self.conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const DELETE_INDEX = 40;
    pub fn delete_sync(
        self: *Self,
        queue: [128]u8,
        if_unused: bool,
        if_empty: bool,
        no_wait: bool,
    ) void {
        const n = try os.write(self.conn.file, self.conn.tx_buffer[0..]);
        while (true) {
            const message = try self.conn.dispatch(allocator, null);
        }
    }
};
pub const basic_interface = struct {
    qos: ?fn (
        prefetch_size: u32,
        prefetch_count: u16,
        global: bool,
    ) anyerror!void,
    qos_ok: ?fn () anyerror!void,
    consume: ?fn (
        reserved_1: u16,
        queue: [128]u8,
        consumer_tag: []u8,
        no_local: bool,
        no_ack: bool,
        exclusive: bool,
        no_wait: bool,
        arguments: void,
    ) anyerror!void,
    consume_ok: ?fn (
        consumer_tag: []u8,
    ) anyerror!void,
    cancel: ?fn (
        consumer_tag: []u8,
        no_wait: bool,
    ) anyerror!void,
    cancel_ok: ?fn (
        consumer_tag: []u8,
    ) anyerror!void,
    publish: ?fn (
        reserved_1: u16,
        exchange: [128]u8,
        routing_key: ?[128]u8,
        mandatory: bool,
        immediate: bool,
    ) anyerror!void,
    @"return": ?fn (
        reply_code: u16,
        reply_text: []u8,
        exchange: [128]u8,
        routing_key: ?[128]u8,
    ) anyerror!void,
    deliver: ?fn (
        consumer_tag: []u8,
        delivery_tag: void,
        redelivered: void,
        exchange: [128]u8,
        routing_key: ?[128]u8,
    ) anyerror!void,
    get: ?fn (
        reserved_1: u16,
        queue: [128]u8,
        no_ack: bool,
    ) anyerror!void,
    get_ok: ?fn (
        delivery_tag: void,
        redelivered: void,
        exchange: [128]u8,
        routing_key: ?[128]u8,
        message_count: void,
    ) anyerror!void,
    get_empty: ?fn (
        reserved_1: ?[128]u8,
    ) anyerror!void,
    ack: ?fn (
        delivery_tag: void,
        multiple: bool,
    ) anyerror!void,
    reject: ?fn (
        delivery_tag: void,
        requeue: bool,
    ) anyerror!void,
    recover_async: ?fn (
        requeue: bool,
    ) anyerror!void,
    recover: ?fn (
        requeue: bool,
    ) anyerror!void,
    recover_ok: ?fn () anyerror!void,
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

pub const BASIC_INDEX = 60; // CLASS
pub const Basic = struct {
    conn: *Wire,
    const Self = @This();
    // METHOD =============================
    pub const QOS_INDEX = 10;
    pub fn qos_sync(
        self: *Self,
        prefetch_size: u32,
        prefetch_count: u16,
        global: bool,
    ) void {
        const n = try os.write(self.conn.file, self.conn.tx_buffer[0..]);
        while (true) {
            const message = try self.conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const CONSUME_INDEX = 20;
    pub fn consume_sync(
        self: *Self,
        queue: [128]u8,
        consumer_tag: []u8,
        no_local: bool,
        no_ack: bool,
        exclusive: bool,
        no_wait: bool,
        arguments: void,
    ) void {
        const n = try os.write(self.conn.file, self.conn.tx_buffer[0..]);
        while (true) {
            const message = try self.conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const CANCEL_INDEX = 30;
    pub fn cancel_sync(
        self: *Self,
        consumer_tag: []u8,
        no_wait: bool,
    ) void {
        const n = try os.write(self.conn.file, self.conn.tx_buffer[0..]);
        while (true) {
            const message = try self.conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const GET_INDEX = 70;
    pub fn get_sync(
        self: *Self,
        queue: [128]u8,
        no_ack: bool,
    ) void {
        const n = try os.write(self.conn.file, self.conn.tx_buffer[0..]);
        while (true) {
            const message = try self.conn.dispatch(allocator, null);
        }
    }
};
pub const tx_interface = struct {
    select: ?fn () anyerror!void,
    select_ok: ?fn () anyerror!void,
    commit: ?fn () anyerror!void,
    commit_ok: ?fn () anyerror!void,
    rollback: ?fn () anyerror!void,
    rollback_ok: ?fn () anyerror!void,
};

pub var TX_IMPL = tx_interface{
    .select = null,
    .select_ok = null,
    .commit = null,
    .commit_ok = null,
    .rollback = null,
    .rollback_ok = null,
};

pub const TX_INDEX = 90; // CLASS
pub const Tx = struct {
    conn: *Wire,
    const Self = @This();
    // METHOD =============================
    pub const SELECT_INDEX = 10;
    pub fn select_sync(
        self: *Self,
    ) void {
        const n = try os.write(self.conn.file, self.conn.tx_buffer[0..]);
        while (true) {
            const message = try self.conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const COMMIT_INDEX = 20;
    pub fn commit_sync(
        self: *Self,
    ) void {
        const n = try os.write(self.conn.file, self.conn.tx_buffer[0..]);
        while (true) {
            const message = try self.conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const ROLLBACK_INDEX = 30;
    pub fn rollback_sync(
        self: *Self,
    ) void {
        const n = try os.write(self.conn.file, self.conn.tx_buffer[0..]);
        while (true) {
            const message = try self.conn.dispatch(allocator, null);
        }
    }
};
