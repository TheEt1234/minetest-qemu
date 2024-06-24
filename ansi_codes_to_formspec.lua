-- so i want to try making something like xterm
-- mmm lets check the readme.... "Abandon All Hope, Ye Who Enter Here"
-- OKAY NEVERMIND

-- you know what let's just strip the characters out for now

local ESC = 0x1b
-- THIS IS THE SAME ESCAPE CHARACTER USED IN MINETEST FOR COLORING

local BEL = 0x07
local BS = 0x08 -- backsapce
local HT = 0x09 -- tab
local FF = 0x0C -- Form feed, moves a printer to top of next page
local LF = 0x0A
local CR = 0x0D

local MAX_CHARS = 80 -- 80 characters/line
local TAB_WIDTH = 8  -- AS DEFINED BY THE ANSI SPECIFICATION!



local color_scheme = {
    [30] = "black",
    [31] = "red",
    [32] = "green",
    [34] = "yellow",
    [35] = "magenta",
    [36] = "cyan",
    [37] = minetest.colorspec_to_colorstring({ r = 170, g = 170, b = 170 }), -- white
    [90] = minetest.colorspec_to_colorstring({ r = 85, g = 85, b = 85 }),    -- bright black
    -- the bright colors, but nothign is stopping me from making them LIGHT :troll:
    [91] = "lightred",
    [92] = "lightgreen",
    [93] = "lightyellow",
    [94] = "lightblue",
    [95] = "#ff80ff", -- light magenta
    [96] = "lightcyan",
    [97] = "white"    -- "Bright white"

}

local sub = string.sub
local c = string.char
local b = string.byte

function string.insert(str1, str2, pos)
    return str1:sub(1, pos) .. str2 .. str1:sub(pos + 1)
end

local function trunc(t)
    for k, v in pairs(t) do t[k] = nil end
end

local function in_range_of(n, r1, r2)
    return n >= r1 and n <= r2
end
local function compact_if(cond, if_true, if_false)
    if cond then return if_true else return if_false end
end

local function parse_c0(char, cursor, bell)
    -- returns a character
    -- modifies the cursor pointer
    if char == BEL then
        bell()
    elseif char == BS then
        cursor.x = cursor.x - 1
        if cursor.x <= 0 then cursor.x = MAX_CHARS end
        return true
    elseif char == HT then
        cursor.x = cursor.x + (cursor.x % TAB_WIDTH)
        return true
    elseif char == LF then
        cursor.x = -1 -- yes, same as CR, this isn't for windows, and yes it's set to 1 because it will get incremented
        cursor.y = cursor.y + 1
        return LF
    elseif char == FF then
        return true
    elseif char == CR then
        cursor.x = -1
        return true
    end
    return false
end

local function parse_csi(text, cursor, i, effect_queue, raw_text)
    -- oh i will love this
    --[[
    For Control Sequence Introducer, or CSI, commands, the ESC [ (written as \e[ or \033[ in several programming languages)
    is followed by any number (including none) of "parameter bytes" in the range 0x30–0x3F (ASCII 0–9:;<=>?),
    then by any number of "intermediate bytes" in the range 0x20–0x2F (ASCII space and !"#$%&'()*+,-./),
    then finally by a single "final byte" in the range 0x40–0x7E (ASCII @A–Z[\]^_`a–z{|}~).[5]: 5.4 

    All common sequences just use the parameters as a series of semicolon-separated numbers such as 1;2;3.
    Missing numbers are treated as 0 (1;;3 acts like the middle number is 0, and no parameters at all in ESC[m acts like a 0 reset code).
    Some sequences (such as CUU) treat 0 as 1 in order to make missing parameters useful.[5]: F.4.2 
        - wikipedia

    My question is... wikipedia... what is the pourpourse of the intermediate bytes
    But whatever

    So first thing, i need to remember that a stream of text is possible to parse, with the (for ex.) interpreted text at the top, uninterpreted at the bottom
    And i should also track any changes, but that's for later


    ]]

    local command_maxlen = 100
    local params = ""       -- 0x30 to 0x3F, if it has "<=>?" then its private
    local intermediate = "" -- 0x20 to 0x2F, unsure of pourpourse
    local command = ""      -- command is in range of 0x40 to 0x7E, if 0x70-0x7E then private

    local looped = 0
    local valid = true
    while true and looped < command_maxlen do
        looped = looped + 1
        i = i + 1
        local char = sub(raw_text, i, i)
        if char == nil or #char == 0 then
            valid = false
            break
        elseif in_range_of(b(char), 0x30, 0x3F) then
            params = params .. char
        elseif char == "<" or char == "=" or char == ">" or char == "?" then -- private characters
            params = params .. char
        elseif in_range_of(b(char), 0x20, 0x2F) then
            intermediate = intermediate .. char
        elseif in_range_of(b(char), 0x40, 0x7E) then
            command = char
            break
        elseif in_range_of(b(char), 0x70, 0x7E) then -- again, private codes
            command = char
            break
        else
            valid = false
            break
        end
    end
    if #command == 0 then valid = false end

    local function zero_based_to_one_based(n)
        if n == 0 or not n then return 1 else return math.max(1, n) end
    end

    if not valid then
        return i, text
    end
    --minetest.debug("Got CSI command:" .. command)
    params = string.split(params, ";") -- if somethings missing then its 0
    local valid_number_params = {}
    for k, v in ipairs(params) do
        valid_number_params[k] = tonumber(v or 0) or 0
    end
    if command == "A" then -- Cursor Up
        local n = zero_based_to_one_based(valid_number_params[1])
        cursor.y = cursor.y + n
    elseif command == "B" then -- cursor down
        local n = zero_based_to_one_based(valid_number_params[1])
        cursor.y = cursor.y - n
    elseif command == "C" then -- cursor forward
        local n = zero_based_to_one_based(valid_number_params[1])
        cursor.x = cursor.x + n
    elseif command == "D" then -- cursor back
        local n = zero_based_to_one_based(valid_number_params[1])
        cursor.x = cursor.x - n
    elseif command == "E" then -- cursor next line, not in the microsoft DOS driver ansi.sys
        local n = zero_based_to_one_based(valid_number_params[1])
        cursor.y = cursor.y + n
        cursor.x = 1
    elseif command == "F" then -- cursor previous line, not in the microsoft DOS driver ansi.sys
        local n = zero_based_to_one_based(valid_number_params[1])
        cursor.y = cursor.y - n
        cursor.x = 1
    elseif command == "G" then -- cursor horizontal absolute
        local n = zero_based_to_one_based(valid_number_params[1])
        cursor.y = n
    elseif command == "H" then -- cursor position
        -- this one has 2 arguments
        local x, y = zero_based_to_one_based(valid_number_params[1]), zero_based_to_one_based(valid_number_params[2])
        cursor.x = x
        cursor.y = y
    elseif command == "J" then -- erase in display
        -- if n == 0 then clear from cursor to end
        -- if n is 1 then clear from cursor to beginning
        -- if n is 2 clear the entire screen
        -- if n is 3 clear the entire screen and delete all lines in the scrollback buffer
        -- i think sitatuion 2 and 3 are the same
        local n = valid_number_params[1] or 0
        if n == 0 then
            local y = cursor.y
            local x = cursor.x
            text[y] = string.sub(text[y], 1, x + 1)
            for k, v in pairs(text) do
                if k > y then text[k] = nil end
            end
            return i, text
        elseif n == 1 then
            local y = cursor.y
            local x = cursor.x
            text[y] = string.sub(text[y], x - 1)
            for k, v in pairs(text) do
                if k < y then text[k] = nil end
            end
            return i, text
        elseif n == 2 or n == 3 then
            return i, trunc(text)
        end
    elseif command == "K" then -- erase in line
        -- n == 1: clear from cursor to end
        -- n == 2: clear from beginning to cursor
        -- n == 3: clear the whole line
        -- cursor position doesn't change
        local n = valid_number_params[1]

        if n == 0 then     -- clear from cursor to end
            text[cursor.y] = string.sub(text[cursor.y], 1, cursor.x + 1)
        elseif n == 1 then -- clear from beginning to cursor
            text[cursor.y] = string.sub(text[cursor.y], cursor.x - 1)
        elseif n == 2 then -- clear whole line
            text[cursor.y] = nil
        end

        return i, text
    elseif command == "S" then -- scroll up
        local n = math.min(100, zero_based_to_one_based(valid_number_params[1]))
        for i = 1, n do
            text[#text + 1] = ""
        end
    elseif command == "T" then -- scroll down
        local n = math.min(100, zero_based_to_one_based(valid_number_params[1]))
        for i = 1, n do
            table.insert(text, 1, "")
        end
    elseif command == "m" then -- SGR AAAAAAAAAAAA this is where the fun stuff starts.... and also where "post processing" starts
        local n = valid_number_params[1]
        --[[
                0: reset or normal
                no 1: bold
                no 3: italic
                no 4: underline
                no 5: slow blink
                no 10: default font
                no 22: normal intensity
                no 24: not underlined
                no 25: not blinking
                |as| minetest coloring 30-37: set foreground color
                as minetest coloring 38: set foreground color: next arguments are 5;n or 2;r;g;b
                no 40-47: set background color
                no 48: set background color: next arguments are 5;n or 2;r;g;b
                no 49: default background color

                those are what i think is a good goal to support - so basically just colors
                for this we most likely need hypertext

                also yeah it uses the cursor position for the effect
                ]]
        -- i think theese effects should be handled in post tbh
        if effect_queue[cursor.y] == nil then effect_queue[cursor.y] = {} end
        table.insert(effect_queue[cursor.y], {
            x = math.floor(cursor.x),
            effect = n,
            params = valid_number_params,
        })
    elseif command == "l" then
    elseif command == "h" then
    else
        --        minetest.log("Foreign CSI escape sequence: " .. command)
    end
    return i, text
end

local function insert(str1, str2, pos)
    local first_string = str1:sub(1, pos)
    if #first_string ~= pos then
        first_string = first_string .. string.rep(" ", pos - #first_string)
    end
    return str1:sub(1, pos) .. str2 .. str1:sub(pos + 1)
end

-- By: rubenwardy
-- https://discord.com/channels/369122544273588224/369123175583186964/1155263079584649236
-- in the minetest main menu: https://github.com/minetest/minetest/blob/master/builtin/mainmenu/settings/dlg_settings.lua#L435
-- WHY THE F### ISN'T THIS A PUBLI- whatever....

-- @param visible_l the length of the scroll_container and scrollbar
-- @param total_l length of the scrollable area
-- @param scroll_factor as passed to scroll_container
local function make_scrollbaroptions_for_scroll_container(visible_l, total_l, scroll_factor)
    if not (total_l >= visible_l) then
        return false, 0
    end
    local max = total_l - visible_l
    local thumb_size = (visible_l / total_l) * max
    return ("scrollbaroptions[min=0;max=%f;thumbsize=%f]"):format(max / scroll_factor, thumb_size / scroll_factor), max
end

function ansi2formspec(raw_text, position, bell)
    -- note: this function should be O(n)
    local effect_queue = {}
    bell = bell or function() end
    local cursor = { x = 1, y = 1 }
    local output_text = {}
    local raw_text_length = #raw_text
    local i = 1
    while i <= raw_text_length do
        local char = string.sub(raw_text, i, i)
        local ret = parse_c0(b(char), cursor, bell)
        if ret == LF then
            output_text[#output_text + 1] = ""
        elseif ret then
            -- empty, because in this case we don't want to do anything
        elseif char == c(ESC) then
            -- o the no an escape sequence
            i = i + 1 -- skip to the next char, you must use i = i + 1 when reading the next char.
            local next_char = b(string.sub(raw_text, i, i))
            local ret = parse_c0(next_char, cursor, bell)
            if ret == LF then
                output_text[#output_text + 1] = ""
            elseif not ret then
                if next_char == b("[") then
                    -- the fun starts here...
                    local new_text
                    i, new_text = parse_csi(output_text, cursor, i, effect_queue, raw_text) -- yes we edit the i here
                    if new_text then
                        output_text = new_text
                    end
                elseif next_char == b("c") then -- reset/initialize
                    output_text = {}
                end
            end
        else
            cursor.x = cursor.x + 1
            -- here is the problem:
            -- we need to insert text at x AND Y
            -- y is the real problem here
            -- i mean we can just turn this function to O((n^2)/2) by having a string.gfind call
            -- but no thats like dumb...
            -- we need some way to store all the LF's... oh i have an idea
            local max_height = 1000
            if cursor.y <= 0 or cursor.y >= max_height then
                cursor.y = 1
            end

            if output_text[cursor.y] == nil then
                for i = 1, math.abs(cursor.y - #output_text) do
                    output_text[#output_text + 1] = ""
                end
            end
            output_text[cursor.y] = insert(output_text[cursor.y], char, cursor.x)
        end
        i = i + 1
    end
    -- now output text should be good...
    -- 80 chars/line

    local formspec = {
        { "scroll_container[",          position.x, ",", position.y, ";", position.w, ",", position.h, ";", "terminal_scrollbar;", "vertical;", 0.1, "]" },
        -- now we style the labels to make them look decent
        { "style_type[label;font=mono]" }
    }


    -- this also processes the effect queue and its gonna get real messy
    local default_color = "white"
    local current_color = default_color

    local Y = 1
    for k, v in ipairs(output_text) do
        if v ~= "" then
            local text = v
            text = minetest.colorize(current_color, text)
            if effect_queue[k] then
                for effect_indx, effect in ipairs(effect_queue[k]) do
                    if effect.effect ~= 0 then
                        minetest.debug("Getting effect: " .. dump(effect))
                    end
                    if not effect.effect or effect.effect == 0 then
                        current_color = default_color
                        insert(text, minetest.get_color_escape_sequence(current_color), effect.x)
                    elseif effect.effect >= 30 and effect.effect <= 37 then
                        minetest.log("Recognized effect")
                        -- 30-37: set foreground color
                        current_color = color_scheme[effect.effect] or "white"
                        insert(text, minetest.get_color_escape_sequence(current_color) .. " color changed", effect.x)
                    elseif effect.effect == 38 then
                        --38: set foreground color: next arguments are 5;n or 2;r;g;b
                        if effect.params[1] == 5 then -- 8bit color
                            -- "As 256-color lookup tables became common on graphic cards, escape sequences were added to select from a pre-defined set of 256 colors:[citation needed]"
                            -- yall are making this harder than it should
                        elseif effect.params[1] == 2 then -- 24 bit, std rgb
                            current_color = minetest.colorspec_to_colorstring({
                                r = effect.params[2],
                                g = effect.params[3],
                                b = effect.params[4],
                            }) or "white"
                            insert(text, minetest.get_color_escape_sequence(current_color), effect.x)
                        end
                    end
                end
            end

            text = minetest.formspec_escape(text)

            formspec[#formspec + 1] = { "label[0,", Y, ";", minetest.formspec_escape(v), "]" }
        end
        Y = Y + position.label_spacing
    end

    local options, max = make_scrollbaroptions_for_scroll_container(position.h, Y, 0.1)
    formspec[#formspec + 1] = { "scroll_container_end[]" }
    formspec[#formspec + 1] = { options or "" }
    if max ~= 0 then
        formspec[#formspec + 1] = {
            "scrollbar[", position.x + position.w - 0.5, ",", position.y, ";",
            0.5, ",", position.h, ";",
            "vertical;", "terminal_scrollbar;", 1000000, "]"
        }
    end

    local formspec_string = ""

    for k, v in ipairs(formspec) do
        formspec_string = formspec_string .. table.concat(v)
    end

    return formspec_string
end
