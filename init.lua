local modpath = minetest.get_modpath(minetest.get_current_modname())

local ie = assert(minetest.request_insecure_environment(),
    "you clearly haven't read the installation instructions have you")


local ffi = ie.require("ffi")

ffi.cdef [[
    typedef int pid_t;

//    typedef struct FILE FILE;
//    FILE* popen(const char *command, const char *type);
//    int pclose(FILE* stream);


    //pid_t fork(void);
    int kill(pid_t pid, int sig);
]]

local function kill(pid)
    ffi.C.kill(pid, 9); -- SIGKILL
end

local function pidof(command)
    minetest.log("Checking the PID of: " .. command)
    local f = ie.io.popen("ps -C '" .. command .. "'", "r")
    local content = f:read("*all")
    -- good luck :3
    if content:find("^error") then
        -- uh oh
        f:close()
        error("An error occured while attempting to get pid of that command, this is like really bad.")
    else
        local pid = tonumber(content:split("\n")[2]:split(" ", false)[1])
        f:close()
        return pid
    end
end

local function compact_if(cond, iftrue, iffalse)
    if cond then return iftrue else return iffalse end
end

QemuVirtMachine = {
    machines = {},
    vm_path = modpath .. "/virtual_machines",
    --    predetermined_image_path = modpath .. "/images",
    boot_image_path = modpath .. "/boot_images"
}

QemuVirtMachine.__index = QemuVirtMachine

local supports_kvm = true           -- turn off if not
local host_cpu_architecture = "x86_64"
local default_memory_limit = "800M" -- 800 megabytes, should be plenty enough, for the current arch linux iso
function QemuVirtMachine.new(vm_name, vm_cpu_architecture, cdrom)
    if cdrom == nil then cdrom = "" end
    local vm_path = QemuVirtMachine.vm_path .. "/" .. vm_name
    local use_host_cpu = host_cpu_architecture == vm_cpu_architecture
    return QemuVirtMachine.new_raw({
        arch = vm_cpu_architecture,
        cdrom = cdrom,
        image = vm_path .. ".img",
        pipe = vm_path,
        monitor = vm_path .. "_monitor",
        memory_limit = default_memory_limit,
        command = "qemu-system-" ..
            vm_cpu_architecture ..
            compact_if(supports_kvm, " -enable-kvm", "") ..
            compact_if(cdrom ~= "", (" -cdrom " .. QemuVirtMachine.boot_image_path .. cdrom), "") ..
            " -boot menu=on -monitor pipe:" ..
            vm_path .. "_monitor -drive file=" .. vm_path .. ".img -m " .. default_memory_limit
            ..
            " -serial pipe:" ..
            vm_path .. " -nographic " .. compact_if(use_host_cpu, "-cpu host", "") --.. " -chardev pipe,id=mtqemu,"
    })
end

function QemuVirtMachine.new_raw(info)
    print("Creating a new qemu virtual machine, executing: " .. info.command)
    info.command = string.gsub(info.command, "  ", " ") -- the ps linux command F A I L S when there are 2 spaces, not even joking, this is to make it safe.
    local self = setmetatable({
        process = ie.io.popen(info.command, "w"),       -- todo: use popen for fancy terminal?
        dead = false,
        info = {
            arch = info.arch,
            cdrom = info.cdrom,
            image = info.image,
            pipe = info.pipe,
            memory_limit = info.memory_limit,
            num_cores = info.num_cores,
            command = info.command,
        },
        pipe_in = ie.io.open(info.pipe .. ".in", "r+"),
        pipe_out = nil,    -- NEEDS to be open by timeout 0.05s cat <file>
        monitor_in = ie.io.open(info.monitor .. ".in", "r+"),
        monitor_out = nil, -- you dont need this

        machines_index = #QemuVirtMachine.machines + 1
    }, QemuVirtMachine)
    QemuVirtMachine.machines[#QemuVirtMachine.machines + 1] = self

    return self
end

function QemuVirtMachine.create_vm(name, size)
    ie.os.execute("qemu-img create -f qcow2 " ..
        QemuVirtMachine.vm_path .. "/" .. name .. ".img " .. size)
    assert(ie.os.execute("mkfifo " ..
        QemuVirtMachine.vm_path .. "/" .. name .. ".in " .. QemuVirtMachine.vm_path .. "/" .. name .. ".out"))
    assert(ie.os.execute("mkfifo " ..
        QemuVirtMachine.vm_path ..
        "/" .. name .. "_monitor.in " .. QemuVirtMachine.vm_path .. "/" .. name .. "_monitor.out"))
    return true
end

function QemuVirtMachine:send_input(input)
    self.pipe_in:write(input)
end

function QemuVirtMachine:send_command(command) -- QEMU monitor, read only https://www.qemu.org/docs/master/system/monitor.html
    minetest.log("Sending QEMU monitor command: " .. command)
    self.monitor_in:write(command)
    self.monitor_in:flush()
end

function QemuVirtMachine:get_output()
    local f = ie.io.popen("timeout 0.05s cat " .. self.info.pipe .. ".out")
    local contents = f:read("*all")
    return contents
end

function QemuVirtMachine:stop()
    table.remove(QemuVirtMachine.machines, self.machines_index)
    kill(pidof(self.info.command))
    self.pipe_in:close()
    self.monitor_in:close()
    self.dead = true
end

minetest.register_on_shutdown(function()
    for _, v in pairs(QemuVirtMachine.machines) do
        v:stop()
    end
    minetest.log("Stopped all virtual machines that were running.")
end)

dofile(modpath .. "/ansi_codes_to_formspec.lua")
dofile(modpath .. "/key_combination_processor.lua")
dofile(modpath .. "/example_frontend.lua")
