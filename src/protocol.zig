const std = @import("std");
const Wire = @import("connection.zig").Wire;
// amqp
pub fn dispatchCallback(class_id: u16, method_id: u16) !void {
    switch (class_id) {
        // connection
        10 => {
            switch (method_id) {
                // start
                10 => {
                    const start = CONNECTION_IMPLEMENTATION.start orelse return error.MethodNotImplemented;
                    try start();
                },
                // start_ok
                11 => {
                    const start_ok = CONNECTION_IMPLEMENTATION.start_ok orelse return error.MethodNotImplemented;
                    try start_ok();
                },
                // secure
                20 => {
                    const secure = CONNECTION_IMPLEMENTATION.secure orelse return error.MethodNotImplemented;
                    try secure();
                },
                // secure_ok
                21 => {
                    const secure_ok = CONNECTION_IMPLEMENTATION.secure_ok orelse return error.MethodNotImplemented;
                    try secure_ok();
                },
                // tune
                30 => {
                    const tune = CONNECTION_IMPLEMENTATION.tune orelse return error.MethodNotImplemented;
                    try tune();
                },
                // tune_ok
                31 => {
                    const tune_ok = CONNECTION_IMPLEMENTATION.tune_ok orelse return error.MethodNotImplemented;
                    try tune_ok();
                },
                // open
                40 => {
                    const open = CONNECTION_IMPLEMENTATION.open orelse return error.MethodNotImplemented;
                    try open();
                },
                // open_ok
                41 => {
                    const open_ok = CONNECTION_IMPLEMENTATION.open_ok orelse return error.MethodNotImplemented;
                    try open_ok();
                },
                // close
                50 => {
                    const close = CONNECTION_IMPLEMENTATION.close orelse return error.MethodNotImplemented;
                    try close();
                },
                // close_ok
                51 => {
                    const close_ok = CONNECTION_IMPLEMENTATION.close_ok orelse return error.MethodNotImplemented;
                    try close_ok();
                },
                // blocked
                60 => {
                    const blocked = CONNECTION_IMPLEMENTATION.blocked orelse return error.MethodNotImplemented;
                    try blocked();
                },
                // unblocked
                61 => {
                    const unblocked = CONNECTION_IMPLEMENTATION.unblocked orelse return error.MethodNotImplemented;
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
                    const open = CHANNEL_IMPLEMENTATION.open orelse return error.MethodNotImplemented;
                    try open();
                },
                // open_ok
                11 => {
                    const open_ok = CHANNEL_IMPLEMENTATION.open_ok orelse return error.MethodNotImplemented;
                    try open_ok();
                },
                // flow
                20 => {
                    const flow = CHANNEL_IMPLEMENTATION.flow orelse return error.MethodNotImplemented;
                    try flow();
                },
                // flow_ok
                21 => {
                    const flow_ok = CHANNEL_IMPLEMENTATION.flow_ok orelse return error.MethodNotImplemented;
                    try flow_ok();
                },
                // close
                40 => {
                    const close = CHANNEL_IMPLEMENTATION.close orelse return error.MethodNotImplemented;
                    try close();
                },
                // close_ok
                41 => {
                    const close_ok = CHANNEL_IMPLEMENTATION.close_ok orelse return error.MethodNotImplemented;
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
                    const declare = EXCHANGE_IMPLEMENTATION.declare orelse return error.MethodNotImplemented;
                    try declare();
                },
                // declare_ok
                11 => {
                    const declare_ok = EXCHANGE_IMPLEMENTATION.declare_ok orelse return error.MethodNotImplemented;
                    try declare_ok();
                },
                // delete
                20 => {
                    const delete = EXCHANGE_IMPLEMENTATION.delete orelse return error.MethodNotImplemented;
                    try delete();
                },
                // delete_ok
                21 => {
                    const delete_ok = EXCHANGE_IMPLEMENTATION.delete_ok orelse return error.MethodNotImplemented;
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
                    const declare = QUEUE_IMPLEMENTATION.declare orelse return error.MethodNotImplemented;
                    try declare();
                },
                // declare_ok
                11 => {
                    const declare_ok = QUEUE_IMPLEMENTATION.declare_ok orelse return error.MethodNotImplemented;
                    try declare_ok();
                },
                // bind
                20 => {
                    const bind = QUEUE_IMPLEMENTATION.bind orelse return error.MethodNotImplemented;
                    try bind();
                },
                // bind_ok
                21 => {
                    const bind_ok = QUEUE_IMPLEMENTATION.bind_ok orelse return error.MethodNotImplemented;
                    try bind_ok();
                },
                // unbind
                50 => {
                    const unbind = QUEUE_IMPLEMENTATION.unbind orelse return error.MethodNotImplemented;
                    try unbind();
                },
                // unbind_ok
                51 => {
                    const unbind_ok = QUEUE_IMPLEMENTATION.unbind_ok orelse return error.MethodNotImplemented;
                    try unbind_ok();
                },
                // purge
                30 => {
                    const purge = QUEUE_IMPLEMENTATION.purge orelse return error.MethodNotImplemented;
                    try purge();
                },
                // purge_ok
                31 => {
                    const purge_ok = QUEUE_IMPLEMENTATION.purge_ok orelse return error.MethodNotImplemented;
                    try purge_ok();
                },
                // delete
                40 => {
                    const delete = QUEUE_IMPLEMENTATION.delete orelse return error.MethodNotImplemented;
                    try delete();
                },
                // delete_ok
                41 => {
                    const delete_ok = QUEUE_IMPLEMENTATION.delete_ok orelse return error.MethodNotImplemented;
                    try delete_ok();
                },
                else => return error.UnknownMethod,
            }
        },
        // basic
        60 => {
            switch (method_id) {
                // qos
                10 => {
                    const qos = BASIC_IMPLEMENTATION.qos orelse return error.MethodNotImplemented;
                    try qos();
                },
                // qos_ok
                11 => {
                    const qos_ok = BASIC_IMPLEMENTATION.qos_ok orelse return error.MethodNotImplemented;
                    try qos_ok();
                },
                // consume
                20 => {
                    const consume = BASIC_IMPLEMENTATION.consume orelse return error.MethodNotImplemented;
                    try consume();
                },
                // consume_ok
                21 => {
                    const consume_ok = BASIC_IMPLEMENTATION.consume_ok orelse return error.MethodNotImplemented;
                    try consume_ok();
                },
                // cancel
                30 => {
                    const cancel = BASIC_IMPLEMENTATION.cancel orelse return error.MethodNotImplemented;
                    try cancel();
                },
                // cancel_ok
                31 => {
                    const cancel_ok = BASIC_IMPLEMENTATION.cancel_ok orelse return error.MethodNotImplemented;
                    try cancel_ok();
                },
                // publish
                40 => {
                    const publish = BASIC_IMPLEMENTATION.publish orelse return error.MethodNotImplemented;
                    try publish();
                },
                // @"return"
                50 => {
                    const @"return" = BASIC_IMPLEMENTATION.@"return" orelse return error.MethodNotImplemented;
                    try @"return"();
                },
                // deliver
                60 => {
                    const deliver = BASIC_IMPLEMENTATION.deliver orelse return error.MethodNotImplemented;
                    try deliver();
                },
                // get
                70 => {
                    const get = BASIC_IMPLEMENTATION.get orelse return error.MethodNotImplemented;
                    try get();
                },
                // get_ok
                71 => {
                    const get_ok = BASIC_IMPLEMENTATION.get_ok orelse return error.MethodNotImplemented;
                    try get_ok();
                },
                // get_empty
                72 => {
                    const get_empty = BASIC_IMPLEMENTATION.get_empty orelse return error.MethodNotImplemented;
                    try get_empty();
                },
                // ack
                80 => {
                    const ack = BASIC_IMPLEMENTATION.ack orelse return error.MethodNotImplemented;
                    try ack();
                },
                // reject
                90 => {
                    const reject = BASIC_IMPLEMENTATION.reject orelse return error.MethodNotImplemented;
                    try reject();
                },
                // recover_async
                100 => {
                    const recover_async = BASIC_IMPLEMENTATION.recover_async orelse return error.MethodNotImplemented;
                    try recover_async();
                },
                // recover
                110 => {
                    const recover = BASIC_IMPLEMENTATION.recover orelse return error.MethodNotImplemented;
                    try recover();
                },
                // recover_ok
                111 => {
                    const recover_ok = BASIC_IMPLEMENTATION.recover_ok orelse return error.MethodNotImplemented;
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
                    const select = TX_IMPLEMENTATION.select orelse return error.MethodNotImplemented;
                    try select();
                },
                // select_ok
                11 => {
                    const select_ok = TX_IMPLEMENTATION.select_ok orelse return error.MethodNotImplemented;
                    try select_ok();
                },
                // commit
                20 => {
                    const commit = TX_IMPLEMENTATION.commit orelse return error.MethodNotImplemented;
                    try commit();
                },
                // commit_ok
                21 => {
                    const commit_ok = TX_IMPLEMENTATION.commit_ok orelse return error.MethodNotImplemented;
                    try commit_ok();
                },
                // rollback
                30 => {
                    const rollback = TX_IMPLEMENTATION.rollback orelse return error.MethodNotImplemented;
                    try rollback();
                },
                // rollback_ok
                31 => {
                    const rollback_ok = TX_IMPLEMENTATION.rollback_ok orelse return error.MethodNotImplemented;
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
    start: ?fn () anyerror!void,
    start_ok: ?fn () anyerror!void,
    secure: ?fn () anyerror!void,
    secure_ok: ?fn () anyerror!void,
    tune: ?fn () anyerror!void,
    tune_ok: ?fn () anyerror!void,
    open: ?fn () anyerror!void,
    open_ok: ?fn () anyerror!void,
    close: ?fn () anyerror!void,
    close_ok: ?fn () anyerror!void,
    blocked: ?fn () anyerror!void,
    unblocked: ?fn () anyerror!void,
};

pub var CONNECTION_IMPLEMENTATION = connection_interface{
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
    open: ?fn () anyerror!void,
    open_ok: ?fn () anyerror!void,
    flow: ?fn () anyerror!void,
    flow_ok: ?fn () anyerror!void,
    close: ?fn () anyerror!void,
    close_ok: ?fn () anyerror!void,
};

pub var CHANNEL_IMPLEMENTATION = channel_interface{
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
    declare: ?fn () anyerror!void,
    declare_ok: ?fn () anyerror!void,
    delete: ?fn () anyerror!void,
    delete_ok: ?fn () anyerror!void,
};

pub var EXCHANGE_IMPLEMENTATION = exchange_interface{
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
    declare: ?fn () anyerror!void,
    declare_ok: ?fn () anyerror!void,
    bind: ?fn () anyerror!void,
    bind_ok: ?fn () anyerror!void,
    unbind: ?fn () anyerror!void,
    unbind_ok: ?fn () anyerror!void,
    purge: ?fn () anyerror!void,
    purge_ok: ?fn () anyerror!void,
    delete: ?fn () anyerror!void,
    delete_ok: ?fn () anyerror!void,
};

pub var QUEUE_IMPLEMENTATION = queue_interface{
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
    qos: ?fn () anyerror!void,
    qos_ok: ?fn () anyerror!void,
    consume: ?fn () anyerror!void,
    consume_ok: ?fn () anyerror!void,
    cancel: ?fn () anyerror!void,
    cancel_ok: ?fn () anyerror!void,
    publish: ?fn () anyerror!void,
    @"return": ?fn () anyerror!void,
    deliver: ?fn () anyerror!void,
    get: ?fn () anyerror!void,
    get_ok: ?fn () anyerror!void,
    get_empty: ?fn () anyerror!void,
    ack: ?fn () anyerror!void,
    reject: ?fn () anyerror!void,
    recover_async: ?fn () anyerror!void,
    recover: ?fn () anyerror!void,
    recover_ok: ?fn () anyerror!void,
};

pub var BASIC_IMPLEMENTATION = basic_interface{
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

pub var TX_IMPLEMENTATION = tx_interface{
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
