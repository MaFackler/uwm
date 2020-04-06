const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    var exe = b.addExecutable("uwm", "src/main.zig");
    exe.addIncludeDir("/usr/include/");
    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("x11");
    exe.install();

    const run = b.step("run", "run the program");
    run.dependOn(&exe.run().step);
}
