const std = @import("std");
const Connection = @import("connection.zig").Connection;
// amqp
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
    // METHOD =============================
    pub const START_OK_INDEX = 11;
    pub fn start_ok_sync(
        conn: *Connection,
        client_properties: void,
        mechanism: void,
        response: void,
        locale: void,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const SECURE_OK_INDEX = 21;
    pub fn secure_ok_sync(
        conn: *Connection,
        response: void,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const TUNE_OK_INDEX = 31;
    pub fn tune_ok_sync(
        conn: *Connection,
        channel_max: u16,
        frame_max: u32,
        heartbeat: u16,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const OPEN_INDEX = 40;
    pub fn open_sync(
        conn: *Connection,
        virtual_host: ?[128]u8,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const CLOSE_INDEX = 50;
    pub fn close_sync(
        conn: *Connection,
        reply_code: u16,
        reply_text: []u8,
        class_id: u16,
        method_id: u16,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const CLOSE_OK_INDEX = 51;
    pub fn close_ok_sync(
        conn: *Connection,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const BLOCKED_INDEX = 60;
    pub fn blocked(conn: *Connection) void {}
    // METHOD =============================
    pub const UNBLOCKED_INDEX = 61;
    pub fn unblocked(conn: *Connection) void {}
};
pub const CHANNEL_INDEX = 20; // CLASS
pub const Channel = struct {
    // METHOD =============================
    pub const OPEN_INDEX = 10;
    pub fn open_sync(
        conn: *Connection,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const FLOW_INDEX = 20;
    pub fn flow_sync(
        conn: *Connection,
        active: bool,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const FLOW_OK_INDEX = 21;
    pub fn flow_ok(conn: *Connection) void {}
    // METHOD =============================
    pub const CLOSE_INDEX = 40;
    pub fn close_sync(
        conn: *Connection,
        reply_code: u16,
        reply_text: []u8,
        class_id: u16,
        method_id: u16,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const CLOSE_OK_INDEX = 41;
    pub fn close_ok_sync(
        conn: *Connection,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
};
pub const EXCHANGE_INDEX = 40; // CLASS
pub const Exchange = struct {
    // METHOD =============================
    pub const DECLARE_INDEX = 10;
    pub fn declare_sync(
        conn: *Connection,
        exchange: void,
        @"type": void,
        passive: bool,
        durable: bool,
        no_wait: bool,
        arguments: void,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const DELETE_INDEX = 20;
    pub fn delete_sync(
        conn: *Connection,
        exchange: void,
        if_unused: bool,
        no_wait: bool,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
};
pub const QUEUE_INDEX = 50; // CLASS
pub const Queue = struct {
    // METHOD =============================
    pub const DECLARE_INDEX = 10;
    pub fn declare_sync(
        conn: *Connection,
        queue: [128]u8,
        passive: bool,
        durable: bool,
        exclusive: bool,
        auto_delete: bool,
        no_wait: bool,
        arguments: void,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const BIND_INDEX = 20;
    pub fn bind_sync(
        conn: *Connection,
        queue: [128]u8,
        exchange: void,
        routing_key: void,
        no_wait: bool,
        arguments: void,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const UNBIND_INDEX = 50;
    pub fn unbind_sync(
        conn: *Connection,
        queue: [128]u8,
        exchange: void,
        routing_key: void,
        arguments: void,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const PURGE_INDEX = 30;
    pub fn purge_sync(
        conn: *Connection,
        queue: [128]u8,
        no_wait: bool,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const DELETE_INDEX = 40;
    pub fn delete_sync(
        conn: *Connection,
        queue: [128]u8,
        if_unused: bool,
        if_empty: bool,
        no_wait: bool,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
};
pub const BASIC_INDEX = 60; // CLASS
pub const Basic = struct {
    // METHOD =============================
    pub const QOS_INDEX = 10;
    pub fn qos_sync(
        conn: *Connection,
        prefetch_size: u32,
        prefetch_count: u16,
        global: bool,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const CONSUME_INDEX = 20;
    pub fn consume_sync(
        conn: *Connection,
        queue: [128]u8,
        consumer_tag: []u8,
        no_local: bool,
        no_ack: bool,
        exclusive: bool,
        no_wait: bool,
        arguments: void,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const CANCEL_INDEX = 30;
    pub fn cancel_sync(
        conn: *Connection,
        consumer_tag: []u8,
        no_wait: bool,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const PUBLISH_INDEX = 40;
    pub fn publish(conn: *Connection) void {}
    // METHOD =============================
    pub const GET_INDEX = 70;
    pub fn get_sync(
        conn: *Connection,
        queue: [128]u8,
        no_ack: bool,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const ACK_INDEX = 80;
    pub fn ack(conn: *Connection) void {}
    // METHOD =============================
    pub const REJECT_INDEX = 90;
    pub fn reject(conn: *Connection) void {}
    // METHOD =============================
    pub const RECOVER_ASYNC_INDEX = 100;
    pub fn recover_async(conn: *Connection) void {}
    // METHOD =============================
    pub const RECOVER_INDEX = 110;
    pub fn recover(conn: *Connection) void {}
};
pub const TX_INDEX = 90; // CLASS
pub const Tx = struct {
    // METHOD =============================
    pub const SELECT_INDEX = 10;
    pub fn select_sync(
        conn: *Connection,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const COMMIT_INDEX = 20;
    pub fn commit_sync(
        conn: *Connection,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
    // METHOD =============================
    pub const ROLLBACK_INDEX = 30;
    pub fn rollback_sync(
        conn: *Connection,
    ) void {
        const n = try os.write(conn.file, conn.tx_buffer[0..]);
        while (true) {
            const message = try conn.dispatch(allocator, null);
        }
    }
};
