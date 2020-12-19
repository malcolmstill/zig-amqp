pub const Basic = struct {
    pub const Consume = struct {
        pub const Options = struct {
            no_local: bool = false,
            no_ack: bool = false,
            exclusive: bool = false,
            no_wait: bool = false,
        };
    };

    pub const Publish = struct {
        pub const Options = struct {
            mandatory: bool = false,
            immediate: bool = false,
        };
    };
};
