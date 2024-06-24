--[[
    Rules:
        *All* keys have to be seperated by "-"
        ctrl, if present must be first
        No duplicates
        If 0x is present, the number is treated as a character

    Example:
        ctrl-a-n => sends ctrl a, then n


    Some of theese *_char functions were generated by ai because i couldnt bother propertly researching this
]]

-- confusing? ummm.... yeah... thats a you issue
local str = string.char
local num = string.byte

-- so... this is.... uhhh... yeah... fun!
-- i love having to interpret crap like
-- meta+ctrl+shift+alt+b


local function ctrl_char(c)
    return str(num(c:upper()) - 64)
end

local function shift_char(c)
    if num(c) >= num("a") and num(c) <= num("z") then
        return str(num(c) - 32)
    else
        return c
    end
end

local function alt_char(c)
    return str(bit.bor(num(c), 0x80))
end

local function meta_char(c)
    return str(bit.bor(num(c), 0x40))
end

local function fX(x)
    return str(0x80 + x)
end

-- im assuming everything the magic ai gave me is correct

local char_codes = {
    ["ctrl"] = ctrl_char,
    ["shift"] = shift_char,
    ["alt"] = alt_char,
    ["meta"] = meta_char,
    ["windows"] = meta_char,
    ["super"] = meta_char,
    ["backspace"] = 0x08,
    ["tab"] = num("\t"),
    ["enter"] = num("\n"),
    ["f1"] = fX(1),
    ["f2"] = fX(2),
    ["f3"] = fX(3),
    ["f4"] = fX(4),
    ["f5"] = fX(5),
    ["f6"] = fX(6),
    ["f7"] = fX(7),
    ["f8"] = fX(8),
    ["f9"] = fX(9),
    ["f10"] = fX(10),
    ["f11"] = fX(11),
    ["f12"] = fX(12),
    ["up"] = num('\37'),
    ["sysrq"] = 0x54,
    ["esc"] = 0x1b
}

function key_combination_processor(input_str)
    local keys = input_str:split("-")
    local stack = {}
    local out = ""
    if #keys > 20 then return end -- no what are you doing
    for k, v in pairs(keys) do
        if string.sub(v, 1, 2) == "0x" then
            out = out .. str(tonumber(v))
        elseif char_codes[v] then
            if type(char_codes[v]) == "number" then
                out = out .. str(char_codes[v])
            elseif type(char_codes[v]) == "function" then
                stack[#stack + 1] = char_codes[v]
            end
        else
            if #stack == 0 then
                out = out .. v
            else
                -- ok so we need to pop the stack
                -- Example situation: ctrl+shift+a, we are at a, we have ctrl and shift at the stack
                local ch = v
                for i = #stack, 1, -1 do
                    ch = table.remove(stack, i)(ch)
                end
                out = out .. ch
            end
        end
    end
    return out
end