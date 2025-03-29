const std = @import("std");
const api = @import("api.zig");

const http = std.http;

pub const Container = struct {
    path: []const u8,

    data: ?Data,
    data_allocator: ?*std.heap.ArenaAllocator,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) Container {
        const container = Container{
            .path = path,
            .data = null,
            .data_allocator = null,
            .allocator = allocator,
        };
        return container;
    }

    pub fn deinit(self: *Container) void {
        self.allocator.free(self.path);
        if (self.data_allocator) |data_allocator| {
            data_allocator.deinit();
            self.allocator.destroy(data_allocator);
        }
    }

    pub fn create(self: *Container, req: CreateReq) !CreateRes {
        const create_res = try makeCreateRequest(self.allocator, self.path, req);
        return create_res;
    }

    pub fn remove(self: *Container, req: RemoveReq) !void {
        if (self.data) |data| {
            try makeRemoveRequest(self.allocator, self.path, &data.Id, req);
        } else {
            return ContainerError.Uninitialized;
        }
    }

    pub fn removeContainer(self: *Container, id_or_name: []const u8, req: RemoveReq) !void {
        try makeRemoveRequest(self.allocator, self.path, id_or_name, req);
    }

    pub fn start(self: *Container, req: StartReq) !void {
        if (self.data) |data| {
            try makeStartRequest(self.allocator, self.path, &data.Id, req);
        } else {
            return ContainerError.Uninitialized;
        }
    }

    pub fn startContainer(self: *Container, id_or_name: []const u8, req: StartReq) !void {
        try makeStartRequest(self.allocator, self.path, id_or_name, req);
    }

    pub fn stop(self: *Container, req: StopReq) !void {
        if (self.data) |data| {
            try makeStopRequest(self.allocator, self.path, &data.Id, req);
        } else {
            return ContainerError.Uninitialized;
        }
    }

    pub fn stopContainer(self: *Container, id_or_name: []const u8, req: StopReq) !void {
        try makeStopRequest(self.allocator, self.path, id_or_name, req);
    }

    pub fn restart(self: *Container, req: RestartReq) !void {
        if (self.data) |data| {
            try makeRestartRequest(self.allocator, self.path, &data.Id, req);
        } else {
            return ContainerError.Uninitialized;
        }
    }

    pub fn restartContainer(self: *Container, id_or_name: []const u8, req: RestartReq) !void {
        try makeRestartRequest(self.allocator, self.path, id_or_name, req);
    }

    pub fn inspect(self: *Container, req: InspectReq) !InspectRes {
        if (self.data) |data| {
            const inspect_res = try makeInspectRequest(self.allocator, self.path, &data.Id, req);
            return inspect_res;
        } else {
            return ContainerError.Uninitialized;
        }
    }

    pub fn inspectContainer(self: *Container, id_or_name: []const u8, req: InspectReq) !InspectRes {
        const inspect_res = try makeInspectRequest(self.allocator, self.path, id_or_name, req);
        return inspect_res;
    }
};

pub const ContainerError = error{
    Uninitialized,
};

// api

// create

pub const CreateReq = struct {
    pub const method = http.Method.POST;
    pub const path = "/containers/create";

    pub const arg_name = "name";
    pub const arg_platform = "platform";

    args: Args,
    body: Body,

    allocator: std.mem.Allocator,

    pub const Args = struct {
        name: []const u8,
        platform: []const u8,
    };

    pub const Body = struct {
        Image: []const u8,
        Cmd: []const []const u8,
    };

    pub fn init(allocator: std.mem.Allocator, name: []const u8, platform: []const u8, image: []const u8, cmd: []const []const u8) CreateReq {
        const create_req = CreateReq{
            .args = .{
                .name = name,
                .platform = platform,
            },
            .body = .{
                .Image = image,
                .Cmd = cmd,
            },
            .allocator = allocator,
        };
        return create_req;
    }

    pub fn deinit(self: *CreateReq) void {
        self.allocator.free(self.args.name);
        self.allocator.free(self.args.platform);
        self.allocator.free(self.body.Image);
        self.allocator.free(self.body.Cmd);
    }
};

pub const CreateRes = struct {
    body: Body,

    arena_allocator: *std.heap.ArenaAllocator,

    pub const Body = struct {
        Id: [Data.id_len]u8,
        Warnings: []const []const u8,
    };

    pub fn createArenaAllocator(allocator: std.mem.Allocator) !*std.heap.ArenaAllocator {
        var arena_allocator = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena_allocator);
        arena_allocator.* = std.heap.ArenaAllocator.init(allocator);
        errdefer arena_allocator.deinit();

        return arena_allocator;
    }

    pub fn init(arena_allocator: *std.heap.ArenaAllocator, body: Body) CreateRes {
        const create_res = CreateRes{
            .body = body,
            .arena_allocator = arena_allocator,
        };
        return create_res;
    }

    pub fn deinit(self: *CreateRes) void {
        const allocator = self.arena_allocator.child_allocator;
        self.arena_allocator.deinit();
        allocator.destroy(self.arena_allocator);
    }
};

pub const CreateError = error{
    BadParameter,
    NoSuchImage,
    Conflict,
    ServerError,
};

// remove

pub const RemoveReq = struct {
    pub const method = http.Method.DELETE;
    pub const path = "/containers/{s}";

    pub const arg_v = "v";
    pub const arg_force = "force";
    pub const arg_link = "link";

    args: Args,

    allocator: std.mem.Allocator,

    pub const Args = struct {
        v: bool,
        force: bool,
        link: bool,
    };

    pub fn init(allocator: std.mem.Allocator, v: bool, force: bool, link: bool) RemoveReq {
        const remove_req = RemoveReq{
            .args = .{
                .v = v,
                .force = force,
                .link = link,
            },
            .allocator = allocator,
        };
        return remove_req;
    }

    pub fn deinit(_: *RemoveReq) void {}
};

pub const RemoveError = error{
    BadParameter,
    NoSuchContainer,
    Conflict,
    ServerError,
};

// start

pub const StartReq = struct {
    pub const method = http.Method.POST;
    pub const path = "/containers/{s}/start";

    pub const arg_detachKeys = "detachKeys";

    args: Args,

    allocator: std.mem.Allocator,

    pub const Args = struct {
        detachKeys: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator, detachKeys: []const u8) StartReq {
        const start_req = StartReq{
            .args = .{
                .detachKeys = detachKeys,
            },
            .allocator = allocator,
        };
        return start_req;
    }

    pub fn deinit(self: *StartReq) void {
        self.allocator.free(self.args.detachKeys);
    }
};

pub const StartError = error{
    ContainerAlreadyStarted,
    NoSuchContainer,
    ServerError,
};

// stop

pub const StopReq = struct {
    pub const method = http.Method.POST;
    pub const path = "/containers/{s}/stop";

    pub const arg_signal = "signal";
    pub const arg_t = "t";

    args: Args,

    allocator: std.mem.Allocator,

    pub const Args = struct {
        signal: []const u8,
        t: i64,
    };

    pub fn init(allocator: std.mem.Allocator, signal: []const u8, t: i64) StopReq {
        const stop_req = StopReq{
            .args = .{
                .signal = signal,
                .t = t,
            },
            .allocator = allocator,
        };
        return stop_req;
    }

    pub fn deinit(self: *StopReq) void {
        self.allocator.free(self.args.signal);
    }
};

pub const StopError = error{
    ContainerAlreadyStopped,
    NoSuchContainer,
    ServerError,
};

// restart

pub const RestartReq = struct {
    pub const method = http.Method.POST;
    pub const path = "/containers/{s}/restart";

    pub const arg_signal = "signal";
    pub const arg_t = "t";

    args: Args,

    allocator: std.mem.Allocator,

    pub const Args = struct {
        signal: []const u8,
        t: i64,
    };

    pub fn init(allocator: std.mem.Allocator, signal: []const u8, t: i64) RestartReq {
        const restart_req = RestartReq{
            .args = .{
                .signal = signal,
                .t = t,
            },
            .allocator = allocator,
        };
        return restart_req;
    }

    pub fn deinit(self: *RestartReq) void {
        self.allocator.free(self.args.signal);
    }
};

pub const RestartError = error{
    NoSuchContainer,
    ServerError,
};

// inspect

pub const InspectReq = struct {
    pub const method = http.Method.GET;
    pub const path = "/containers/{s}/json";

    pub const arg_size = "size";

    args: Args,

    allocator: std.mem.Allocator,

    pub const Args = struct {
        size: bool,
    };

    pub fn init(allocator: std.mem.Allocator, size: bool) InspectReq {
        const inspect_req = InspectReq{
            .args = .{
                .size = size,
            },
            .allocator = allocator,
        };
        return inspect_req;
    }

    pub fn deinit(_: *InspectReq) void {}
};

pub const Data = struct {
    Id: [id_len]u8,
    Created: ?[]const u8 = null,
    Path: []const u8,
    Args: []const []const u8,
    State: ?DataState = null,
    Image: []const u8,
    ResolvConfPath: []const u8,
    HostnamePath: []const u8,
    HostsPath: []const u8,
    LogPath: ?[]const u8 = null,
    Name: []const u8,
    RestartCount: i64,
    Driver: []const u8,
    Platform: []const u8,
    ImageManifestDescriptor: ?DataImageManifestDescriptor = null,
    MountLabel: []const u8,
    ProcessLabel: []const u8,
    AppArmorProfile: []const u8,
    ExecIDs: ?[]const []const u8 = null,
    HostConfig: DataHostConfig,
    GraphDriver: DataGraphDriver,
    SizeRw: ?i64 = null,
    SizeRootFs: ?i64 = null,
    Mounts: []DataMount,
    Config: DataConfig,
    NetworkSettings: DataNetworkSettings,

    pub const DataState = struct {
        Status: []const u8,
        Running: bool,
        Paused: bool,
        Restarting: bool,
        OOMKilled: bool,
        Dead: bool,
        Pid: i64,
        ExitCode: i64,
        Error: []const u8,
        StartedAt: []const u8,
        FinishedAt: []const u8,
        Health: ?StateHealth = null,

        pub const StateHealth = struct {
            Status: []const u8,
            FailingStreak: i64,
            Log: ?[]HealthLog = null,

            pub const HealthLog = struct {
                Start: []const u8,
                End: []const u8,
                ExitCode: i64,
                Output: []const u8,
            };
        };
    };

    pub const DataImageManifestDescriptor = struct {
        mediaType: []const u8,
        digest: []const u8,
        size: i64,
        urls: ?[]const []const u8 = null,
        // annotations: ?ImageManifestDescriptorAnnotation = null,
        data: ?[]const u8 = null,
        platform: ?ImageManifestDescriptorPlatform = null,
        artifactType: ?[]const u8 = null,

        pub const ImageManifestDescriptorPlatform = struct {
            architecture: []const u8,
            os: []const u8,
            @"os.version": []const u8,
            @"os.features": []const []const u8,
            variant: []const u8,
        };
    };

    pub const DataHostConfig = struct {
        CpuShares: i64,
        Memory: i64,
        CgroupParent: []const u8,
        BlkioWeight: i64,
        BlkioWeightDevice: ?[]HostConfigBlkioWeightDevice = null,
        BlkioDeviceReadBps: ?[]HostConfigBlkioDeviceReadBps = null,
        BlkioDeviceWriteBps: ?[]HostConfigBlkioDeviceWriteBps = null,
        BlkioDeviceReadIOps: ?[]HostConfigBlkioDeviceReadIOps = null,
        BlkioDeviceWriteIOps: ?[]HostConfigBlkioDeviceWriteIOps = null,
        CpuPeriod: i64,
        CpuQuota: i64,
        CpuRealtimePeriod: i64,
        CpuRealtimeRuntime: i64,
        CpusetCpus: []const u8,
        CpusetMems: []const u8,
        Devices: ?[]HostConfigDevice = null,
        DeviceCgroupRules: ?[]const []const u8 = null,
        DeviceRequests: ?[]HostConfigDeviceRequest = null,
        KernelMemoryTCP: ?i64 = null,
        MemoryReservation: i64,
        MemorySwap: i64,
        MemorySwappiness: ?i64 = null,
        NanoCpus: i64,
        OomKillDisable: bool,
        Init: ?bool = null,
        PidsLimit: ?i64 = null,
        Ulimits: ?[]HostConfigUlimit = null,
        CpuCount: i64,
        CpuPercent: i64,
        IOMaximumIOps: i64,
        IOMaximumBandwidth: i64,
        Binds: ?[]const []const u8 = null,
        ContainerIDFile: []const u8,
        LogConfig: HostConfigLogConfig,
        NetworkMode: []const u8,
        // PortBindings: ?HostConfigPortBindings = null,
        RestartPolicy: HostConfigRestartPolicy,
        AutoRemove: bool,
        VolumeDriver: []const u8,
        VolumesFrom: ?[]const []const u8 = null,
        Mounts: ?[]HostConfigMount = null,
        ConsoleSize: ?[]i64 = null,
        // Annotations: HostConfigAnnotations,
        CapAdd: ?[]const []const u8 = null,
        CapDrop: ?[]const []const u8 = null,
        CgroupnsMode: []const u8,
        Dns: ?[]const []const u8 = null,
        DnsOptions: ?[]const []const u8 = null,
        DnsSearch: ?[]const []const u8 = null,
        ExtraHosts: ?[]const []const u8 = null,
        GroupAdd: ?[]const []const u8 = null,
        IpcMode: []const u8,
        Cgroup: []const u8,
        Links: ?[]const []const u8 = null,
        OomScoreAdj: i64,
        PidMode: []const u8,
        Privileged: bool,
        PublishAllPorts: bool,
        ReadonlyRootfs: bool,
        SecurityOpt: ?[]const []const u8 = null,
        // StorageOpt: ?HostConfigStorageOpt = null,
        // Tmpfs: ?HostConfigTmpfs = null,
        UTSMode: []const u8,
        UsernsMode: []const u8,
        ShmSize: i64,
        // Sysctls: ?HostConfigSysctls = null,
        Runtime: ?[]const u8 = null,
        Isolation: []const u8,
        MaskedPaths: []const []const u8,
        ReadonlyPaths: []const []const u8,

        pub const HostConfigBlkioWeightDevice = struct {
            Path: []const u8,
            Weight: i64,
        };

        pub const HostConfigBlkioDeviceReadBps = struct {
            Path: []const u8,
            Rate: i64,
        };

        pub const HostConfigBlkioDeviceWriteBps = struct {
            Path: []const u8,
            Rate: i64,
        };

        pub const HostConfigBlkioDeviceReadIOps = struct {
            Path: []const u8,
            Rate: i64,
        };

        pub const HostConfigBlkioDeviceWriteIOps = struct {
            Path: []const u8,
            Rate: i64,
        };

        pub const HostConfigDevice = struct {
            PathOnHost: []const u8,
            PathInContainer: []const u8,
            CgroupPermissions: []const u8,
        };

        pub const HostConfigDeviceRequest = struct {
            Driver: []const u8,
            Count: i64,
            DeviceIDs: []const []const u8,
            Capabilities: []const []const u8,
            // Options: DeviceRequestsOptions
        };

        pub const HostConfigUlimit = struct {
            Name: []const u8,
            Soft: i64,
            Hard: i64,
        };

        pub const HostConfigLogConfig = struct {
            Type: []const u8,
            // Config: LogConfigConfig,
        };

        pub const HostConfigRestartPolicy = struct {
            Name: []const u8,
            MaximumRetryCount: i64,
        };

        pub const HostConfigMount = struct {
            Target: []const u8,
            Source: []const u8,
            Type: []const u8,
            ReadOnly: bool,
            Consistency: []const u8,
            BindOptions: MountsBindOptions,
            VolumeOptions: MountsVolumeOptions,
            ImageOptions: MountsImageOptions,
            TmpfsOptions: MountsTmpfsOptions,

            pub const MountsBindOptions = struct {
                Propagation: []const u8,
                NonRecursive: bool,
                CreateMountpoint: bool,
                ReadOnlyNonRecursive: bool,
                ReadOnlyForceRecursive: bool,
            };

            pub const MountsVolumeOptions = struct {
                NoCopy: bool,
                // Labels: VolumeOptionsLabels,
                DriverConfig: VolumeOptionsDriverConfig,
                Subpath: []const u8,

                pub const VolumeOptionsDriverConfig = struct {
                    Name: []const u8,
                    // Options: DriverConfigOptions,
                };
            };

            pub const MountsImageOptions = struct {
                Subpath: []const u8,
            };

            pub const MountsTmpfsOptions = struct {
                SizeBytes: i64,
                Mode: i64,
                Options: []const []const u8,
            };
        };
    };

    pub const DataGraphDriver = struct {
        Name: []const u8,
        // Data: GraphDriverData,
    };

    pub const DataMount = struct {
        Type: []const u8,
        Name: []const u8,
        Source: []const u8,
        Destination: []const u8,
        Driver: []const u8,
        Mode: []const u8,
        RW: bool,
        Propagation: []const u8,
    };

    pub const DataConfig = struct {
        Hostname: []const u8,
        Domainname: []const u8,
        User: []const u8,
        AttachStdin: bool,
        AttachStdout: bool,
        AttachStderr: bool,
        // ExposedPorts: ?ConfigExposedPorts = null,
        Tty: bool,
        OpenStdin: bool,
        StdinOnce: bool,
        Env: []const []const u8,
        Cmd: []const []const u8,
        Healthcheck: ?ConfigHealthcheck = null,
        ArgsEscaped: ?bool = null,
        Image: []const u8,
        // Volumes: ?ConfigVolumes = null,
        WorkingDir: []const u8,
        Entrypoint: ?[]const []const u8 = null,
        NetworkDisabled: ?bool = null,
        MacAddress: ?[]const u8 = null,
        OnBuild: ?[]const []const u8 = null,
        // Labels: ConfigLabels,
        StopSignal: ?[]const u8 = null,
        StopTimeout: ?i64 = null,
        Shell: ?[]const []const u8 = null,

        pub const ConfigHealthcheck = struct {
            Test: []const []const u8,
            Interval: i64,
            Timeout: i64,
            Retries: i64,
            StartPeriod: i64,
            StartInterval: i64,
        };
    };

    pub const DataNetworkSettings = struct {
        Bridge: []const u8,
        SandboxID: []const u8,
        HairpinMode: bool,
        LinkLocalIPv6Address: []const u8,
        LinkLocalIPv6PrefixLen: i64,
        // Ports: ?NetworkSettingsPorts = null,
        SandboxKey: []const u8,
        SecondaryIPAddresses: ?[]NetworkSettingsSecondaryIPAddress = null,
        SecondaryIPv6Addresses: ?[]NetworkSettingsSecondaryIPv6Address = null,
        EndpointID: []const u8,
        Gateway: []const u8,
        GlobalIPv6Address: []const u8,
        GlobalIPv6PrefixLen: i64,
        IPAddress: []const u8,
        IPPrefixLen: i64,
        IPv6Gateway: []const u8,
        MacAddress: []const u8,
        // Networks: NetworkSettingsNetworks,

        pub const NetworkSettingsSecondaryIPAddress = struct {
            Addr: []const u8,
            PrefixLen: i64,
        };

        pub const NetworkSettingsSecondaryIPv6Address = struct {
            Addr: []const u8,
            PrefixLen: i64,
        };
    };

    pub const id_len: u7 = 64;
};

pub const InspectRes = struct {
    body: Data,

    arena_allocator: *std.heap.ArenaAllocator,

    pub fn createArenaAllocator(allocator: std.mem.Allocator) !*std.heap.ArenaAllocator {
        var arena_allocator = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena_allocator);
        arena_allocator.* = std.heap.ArenaAllocator.init(allocator);
        errdefer arena_allocator.deinit();

        return arena_allocator;
    }

    pub fn init(arena_allocator: *std.heap.ArenaAllocator, body: Data) InspectRes {
        const inspect_res = InspectRes{
            .body = body,
            .arena_allocator = arena_allocator,
        };
        return inspect_res;
    }

    pub fn deinit(self: *InspectRes) void {
        const allocator = self.arena_allocator.child_allocator;
        self.arena_allocator.deinit();
        allocator.destroy(self.arena_allocator);
    }
};

pub const InspectError = error{
    NoSuchContainer,
    ServerError,
};

fn makeCreateRequest(allocator: std.mem.Allocator, path: []const u8, req: CreateReq) !CreateRes {
    var http_response = prepare: {
        const url = try std.mem.join(allocator, "", &.{ path, CreateReq.path });
        errdefer allocator.free(url);

        const arg_name = try std.mem.join(allocator, "", &.{ CreateReq.arg_name, "=", req.args.name });
        errdefer allocator.free(arg_name);
        const arg_platform = try std.mem.join(allocator, "", &.{ CreateReq.arg_platform, "=", req.args.platform });
        errdefer allocator.free(arg_platform);
        const args = [_][]const u8{
            arg_name, arg_platform,
        };

        const json_req = try std.json.stringifyAlloc(allocator, req.body, .{});
        errdefer allocator.free(json_req);

        const http_response = try api.makeHttpRequest(allocator, CreateReq.method, url, &args, json_req);

        allocator.free(json_req);
        allocator.free(arg_platform);
        allocator.free(arg_name);
        allocator.free(url);

        break :prepare http_response;
    };
    errdefer http_response.deinit(allocator);

    switch (http_response.status_code) {
        .created => {
            if (http_response.body) |body| {
                var arena_allocator = try CreateRes.createArenaAllocator(allocator);
                errdefer allocator.destroy(arena_allocator);

                const res_body = try std.json.parseFromSliceLeaky(CreateRes.Body, arena_allocator.allocator(), body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true });

                http_response.deinit(allocator);

                const res = CreateRes.init(arena_allocator, res_body);
                return res;
            }
            return api.ApiError.NoBody;
        },
        .bad_request => {
            return CreateError.BadParameter;
        },
        .not_found => {
            return CreateError.NoSuchImage;
        },
        .conflict => {
            return CreateError.Conflict;
        },
        .internal_server_error => {
            return CreateError.ServerError;
        },
        else => {
            return api.ApiError.UnknownStatusCode;
        },
    }
}

fn makeRemoveRequest(allocator: std.mem.Allocator, path: []const u8, id_or_name: []const u8, req: RemoveReq) !void {
    var http_response = prepare: {
        const url_format = try std.fmt.allocPrint(allocator, RemoveReq.path, .{id_or_name});
        errdefer allocator.free(url_format);
        const url = try std.mem.join(allocator, "", &.{ path, url_format });
        errdefer allocator.free(url);

        const arg_v_format = try std.fmt.allocPrint(allocator, "{}", .{req.args.v});
        errdefer allocator.free(arg_v_format);
        const arg_v = try std.mem.join(allocator, "", &.{ RemoveReq.arg_v, "=", arg_v_format });
        errdefer allocator.free(arg_v);
        const arg_force_format = try std.fmt.allocPrint(allocator, "{}", .{req.args.force});
        errdefer allocator.free(arg_force_format);
        const arg_force = try std.mem.join(allocator, "", &.{ RemoveReq.arg_force, "=", arg_force_format });
        errdefer allocator.free(arg_force);
        const arg_link_format = try std.fmt.allocPrint(allocator, "{}", .{req.args.link});
        errdefer allocator.free(arg_link_format);
        const arg_link = try std.mem.join(allocator, "", &.{ RemoveReq.arg_link, "=", arg_link_format });
        errdefer allocator.free(arg_link);
        const args = [_][]const u8{
            arg_v,
            arg_force,
            arg_link,
        };

        const http_response = try api.makeHttpRequest(allocator, RemoveReq.method, url, &args, null);

        allocator.free(arg_link);
        allocator.free(arg_link_format);
        allocator.free(arg_force);
        allocator.free(arg_force_format);
        allocator.free(arg_v);
        allocator.free(arg_v_format);
        allocator.free(url);
        allocator.free(url_format);

        break :prepare http_response;
    };
    errdefer http_response.deinit(allocator);

    switch (http_response.status_code) {
        .no_content => {
            return;
        },
        .bad_request => {
            return RemoveError.BadParameter;
        },
        .not_found => {
            return RemoveError.NoSuchContainer;
        },
        .conflict => {
            return RemoveError.Conflict;
        },
        .internal_server_error => {
            return RemoveError.ServerError;
        },
        else => {
            return api.ApiError.UnknownStatusCode;
        },
    }
}

fn makeStartRequest(allocator: std.mem.Allocator, path: []const u8, id_or_name: []const u8, req: StartReq) !void {
    var http_response = prepare: {
        const url_format = try std.fmt.allocPrint(allocator, StartReq.path, .{id_or_name});
        errdefer allocator.free(url_format);
        const url = try std.mem.join(allocator, "", &.{ path, url_format });
        errdefer allocator.free(url);

        const arg_detachKeys = try std.mem.join(allocator, "", &.{ StartReq.arg_detachKeys, "=", req.args.detachKeys });
        errdefer allocator.free(arg_detachKeys);
        const args = [_][]const u8{
            arg_detachKeys,
        };

        const http_response = try api.makeHttpRequest(allocator, StartReq.method, url, &args, null);

        allocator.free(arg_detachKeys);
        allocator.free(url);
        allocator.free(url_format);

        break :prepare http_response;
    };
    errdefer http_response.deinit(allocator);

    switch (http_response.status_code) {
        .no_content => {
            return;
        },
        .not_modified => {
            return StartError.ContainerAlreadyStarted;
        },
        .not_found => {
            return StartError.NoSuchContainer;
        },
        .internal_server_error => {
            return StartError.ServerError;
        },
        else => {
            return api.ApiError.UnknownStatusCode;
        },
    }
}

fn makeStopRequest(allocator: std.mem.Allocator, path: []const u8, id_or_name: []const u8, req: StopReq) !void {
    var http_response = prepare: {
        const url_format = try std.fmt.allocPrint(allocator, StopReq.path, .{id_or_name});
        errdefer allocator.free(url_format);
        const url = try std.mem.join(allocator, "", &.{ path, url_format });
        errdefer allocator.free(url);

        const arg_signal = try std.mem.join(allocator, "", &.{ StopReq.arg_signal, "=", req.args.signal });
        errdefer allocator.free(arg_signal);
        const arg_t_format = try std.fmt.allocPrint(allocator, "{}", .{req.args.t});
        errdefer allocator.free(arg_t_format);
        const arg_t = try std.mem.join(allocator, "", &.{ StopReq.arg_t, "=", arg_t_format });
        errdefer allocator.free(arg_t);
        const args = [_][]const u8{
            arg_signal, arg_t,
        };

        const http_response = try api.makeHttpRequest(allocator, StopReq.method, url, &args, null);

        allocator.free(arg_t);
        allocator.free(arg_t_format);
        allocator.free(arg_signal);
        allocator.free(url);
        allocator.free(url_format);

        break :prepare http_response;
    };
    errdefer http_response.deinit(allocator);

    switch (http_response.status_code) {
        .no_content => {
            return;
        },
        .not_modified => {
            return StopError.ContainerAlreadyStopped;
        },
        .not_found => {
            return StopError.NoSuchContainer;
        },
        .internal_server_error => {
            return StopError.ServerError;
        },
        else => {
            return api.ApiError.UnknownStatusCode;
        },
    }
}

fn makeRestartRequest(allocator: std.mem.Allocator, path: []const u8, id_or_name: []const u8, req: RestartReq) !void {
    var http_response = prepare: {
        const url_format = try std.fmt.allocPrint(allocator, RestartReq.path, .{id_or_name});
        errdefer allocator.free(url_format);
        const url = try std.mem.join(allocator, "", &.{ path, url_format });
        errdefer allocator.free(url);

        const arg_signal = try std.mem.join(allocator, "", &.{ RestartReq.arg_signal, "=", req.args.signal });
        errdefer allocator.free(arg_signal);
        const arg_t_format = try std.fmt.allocPrint(allocator, "{}", .{req.args.t});
        errdefer allocator.free(arg_t_format);
        const arg_t = try std.mem.join(allocator, "", &.{ RestartReq.arg_t, "=", arg_t_format });
        errdefer allocator.free(arg_t);
        const args = [_][]const u8{
            arg_signal, arg_t,
        };

        const http_response = try api.makeHttpRequest(allocator, RestartReq.method, url, &args, null);

        allocator.free(arg_t);
        allocator.free(arg_t_format);
        allocator.free(arg_signal);
        allocator.free(url);
        allocator.free(url_format);

        break :prepare http_response;
    };
    errdefer http_response.deinit(allocator);

    switch (http_response.status_code) {
        .no_content => {
            return;
        },
        .not_found => {
            return RestartError.NoSuchContainer;
        },
        .internal_server_error => {
            return RestartError.ServerError;
        },
        else => {
            return api.ApiError.UnknownStatusCode;
        },
    }
}

fn makeInspectRequest(allocator: std.mem.Allocator, path: []const u8, id_or_name: []const u8, req: InspectReq) !InspectRes {
    var http_response = prepare: {
        const url_format = try std.fmt.allocPrint(allocator, InspectReq.path, .{id_or_name});
        errdefer allocator.free(url_format);
        const url = try std.mem.join(allocator, "", &.{ path, url_format });
        errdefer allocator.free(url);

        const arg_size_format = try std.fmt.allocPrint(allocator, "{}", .{req.args.size});
        errdefer allocator.free(arg_size_format);
        const arg_size = try std.mem.join(allocator, "", &.{ InspectReq.arg_size, "=", arg_size_format });
        errdefer allocator.free(arg_size);
        const args = [_][]const u8{
            arg_size,
        };

        const http_response = try api.makeHttpRequest(allocator, InspectReq.method, url, &args, null);

        allocator.free(arg_size);
        allocator.free(arg_size_format);
        allocator.free(url);
        allocator.free(url_format);

        break :prepare http_response;
    };
    errdefer http_response.deinit(allocator);

    switch (http_response.status_code) {
        .ok => {
            if (http_response.body) |body| {
                var arena_allocator = try InspectRes.createArenaAllocator(allocator);
                errdefer allocator.destroy(arena_allocator);

                const res_body = try std.json.parseFromSliceLeaky(Data, arena_allocator.allocator(), body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true });

                http_response.deinit(allocator);

                const res = InspectRes.init(arena_allocator, res_body);
                return res;
            }
            return api.ApiError.NoBody;
        },
        .not_found => {
            return InspectError.NoSuchContainer;
        },
        .internal_server_error => {
            return InspectError.ServerError;
        },
        else => {
            return api.ApiError.UnknownStatusCode;
        },
    }
}
