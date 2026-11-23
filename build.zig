const std = @import("std");
const exe_name = "template-cpp-zig";

pub fn build(b: *std.Build) void {
    const mod = b.createModule(.{
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
        .link_libcpp = true,
    });

    mod.addCSourceFile(.{
        .file = b.path("src/main.cpp"),
        .flags = &.{
            "-std=c++23",
            "-MJ",
            ".compile_commands.tmp",
        },
    });

    const exe = b.addExecutable(.{
        .name = exe_name,
        .root_module = mod,
    });

    b.installArtifact(exe);
    const py_script =
        \\import json, os, sys
        \\tmp, out = ".compile_commands.tmp", sys.argv[1]
        \\if os.path.exists(tmp):
        \\    with open(tmp) as f: raw = f.read().strip().rstrip(",")
        \\    entries = json.loads(f"[{raw}]")
        \\    os.remove(tmp)
        \\else:
        \\    entries = [{"directory": os.getcwd(), "file": "src/main.cpp", "arguments": ["-std=c++23", "src/main.cpp"]}]
        \\for e in entries:
        \\    args, skip = ["clang++"], False
        \\    for a in e.get("arguments", []):
        \\        if skip: skip = False; continue
        \\        if a == "-MJ": skip = True; continue
        \\        if a not in ("zig", "c++", "cc", "-cc1"): args.append(a)
        \\    e["arguments"] = args
        \\with open(out, "w") as f: json.dump(entries, f, indent=2)
    ;
    const gen_cdb = b.addSystemCommand(&.{ "python3", "-c", py_script });
    const cdb_out = gen_cdb.addOutputFileArg("compile_commands.json");
    gen_cdb.step.dependOn(&exe.step);
    const update_source = b.addUpdateSourceFiles();
    update_source.addCopyFileToSource(cdb_out, "compile_commands.json");
    b.getInstallStep().dependOn(&update_source.step);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run Program");
    run_step.dependOn(&run_cmd.step);
}
