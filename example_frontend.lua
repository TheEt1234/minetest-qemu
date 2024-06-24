local vm = QemuVirtMachine.new("test", "x86_64")

local collected_output = ""
local text = ""
local label_spacing = 1


function get_vm_formspec(pl)
    local fs = {
        "formspec_version[7]",
        "size[32, 28; true]",
        "box[0.1,5;31.8,22.9;black]",
        text,
        "button[0,0;3,1;help;help]",
        "label[0,2.5;Input:]",
        "field[3,2;8,1.6;input;;]",
        "field_close_on_enter[input;false]", -- i love minetest! :D
        "button[11,2;4,1.6;send;Send\nWith enter]",
        "button[14.5,2;4,1.6;send_no_enter;Send\nWithout enter]",
        "button[18.5,2;4,1.6;send_keycombo;Send\nKey combo]",
    }

    fs = table.concat(fs)
    minetest.show_formspec(pl, "test_vm", fs)
end

function get_vm_formspec_now(pl)
    local out = vm:get_output()
    text = "\n\n=====PROCESSED====: \n\n" ..
        ansi2formspec(out) .. "\n\n====ORIGINAL=====: \n\n" .. string.format("%q", out)
    get_vm_formspec(pl)
end

local t = 0.1

local function do_it()
    local out = vm:get_output()
    collected_output = collected_output .. out
    text = ansi2formspec(collected_output, { x = 0.1, y = 5, w = 31.8, h = 22.9, label_spacing = label_spacing })
    get_vm_formspec("singleplayer")
    minetest.after(t, do_it)
end

do_it()

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "test_vm" then return end
    if fields.input then
        local input = fields.input
        if fields.send_keycombo then
            vm:send_input(key_combination_processor(input))
        else
            if input ~= nil and input ~= "" and not fields.send_no_enter then
                input = input .. "\n"
            end
            vm:send_input(input)
        end
    end
end)
