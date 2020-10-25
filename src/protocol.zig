const std = @import("std");
const Connection = @import("connection.zig").Connection;
// amqp
pub fn dispatchCallback(class: u16, method: u16) !void {
    switch (class_id) {
        // connection
        10 => {
            switch (method_id) {
                // start
                10 => {},
                // start-ok
                11 => {},
                // secure
                20 => {},
                // secure-ok
                21 => {},
                // tune
                30 => {},
                // tune-ok
                31 => {},
                // open
                40 => {},
                // open-ok
                41 => {},
                // close
                50 => {},
                // close-ok
                51 => {},
                // blocked
                60 => {},
                // unblocked
                61 => {},
            }
        },
        // channel
        20 => {
            switch (method_id) {
                // open
                10 => {},
                // open-ok
                11 => {},
                // flow
                20 => {},
                // flow-ok
                21 => {},
                // close
                40 => {},
                // close-ok
                41 => {},
            }
        },
        // exchange
        40 => {
            switch (method_id) {
                // declare
                10 => {},
                // declare-ok
                11 => {},
                // delete
                20 => {},
                // delete-ok
                21 => {},
            }
        },
        // queue
        50 => {
            switch (method_id) {
                // declare
                10 => {},
                // declare-ok
                11 => {},
                // bind
                20 => {},
                // bind-ok
                21 => {},
                // unbind
                50 => {},
                // unbind-ok
                51 => {},
                // purge
                30 => {},
                // purge-ok
                31 => {},
                // delete
                40 => {},
                // delete-ok
                41 => {},
            }
        },
        // basic
        60 => {
            switch (method_id) {
                // qos
                10 => {},
                // qos-ok
                11 => {},
                // consume
                20 => {},
                // consume-ok
                21 => {},
                // cancel
                30 => {},
                // cancel-ok
                31 => {},
                // publish
                40 => {},
                // return
                50 => {},
                // deliver
                60 => {},
                // get
                70 => {},
                // get-ok
                71 => {},
                // get-empty
                72 => {},
                // ack
                80 => {},
                // reject
                90 => {},
                // recover-async
                100 => {},
                // recover
                110 => {},
                // recover-ok
                111 => {},
            }
        },
        // tx
        90 => {
            switch (method_id) {
                // select
                10 => {},
                // select-ok
                11 => {},
                // commit
                20 => {},
                // commit-ok
                21 => {},
                // rollback
                30 => {},
                // rollback-ok
                31 => {},
            }
        },
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
pub const CONNECTION_INDEX = 10; // CLASS
pub const Connection = struct {
    conn: *Connection,
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
pub const CHANNEL_INDEX = 20; // CLASS
pub const Channel = struct {
    conn: *Connection,
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
pub const EXCHANGE_INDEX = 40; // CLASS
pub const Exchange = struct {
    conn: *Connection,
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
pub const QUEUE_INDEX = 50; // CLASS
pub const Queue = struct {
    conn: *Connection,
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
pub const BASIC_INDEX = 60; // CLASS
pub const Basic = struct {
    conn: *Connection,
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
pub const TX_INDEX = 90; // CLASS
pub const Tx = struct {
    conn: *Connection,
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
