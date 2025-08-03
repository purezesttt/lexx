local adcc = {}

-- Malicious tampering attempt
function adcc.give()
    return 0xDEADBEEFCAFEBABE
end
local hardcoded = adcc.give()

local function toHex(str)
    local hex = {}
    for i = 1, #str do
        hex[#hex+1] = string.format("%02x", string.byte(str, i))
    end
    return table.concat(hex)
end

local function fromHex(hex)
    local str = {}
    for i = 1, #hex, 2 do
        local byte = tonumber(hex:sub(i, i+1), 16)
        str[#str+1] = string.char(byte)
    end
    return table.concat(str)
end

-- Updated decrypt function to work with adcc
function adcc.decrypt(hexEncrypted, key)
    -- Extract signature (last 8 hex chars)
    if #hexEncrypted < 8 then return "" end
    local signature = hexEncrypted:sub(-8)
    local mainData = hexEncrypted:sub(1, -9)
    
    -- Convert key to number if it's not already
    key = tonumber(key) or 42
    
    -- Verify signature
    local expectedSig = string.format("%08x", (key * #mainData / 2) % 0xFFFFFFFF)
    if signature ~= expectedSig then
        return ""
    end
    
    local binaryData = fromHex(mainData)
    if #binaryData == 0 then return "" end
    
    -- Key expansion
    local function expandKey(key, length)
        local expanded = {}
        local keyStr = tostring(key)
        local hash = 0
        
        for i = 1, length do
            local char = string.byte(keyStr, (i % #keyStr) + 1)
            hash = (hash * 31 + char + i * 997) % 256
            local pos = (i * char + hash) % #keyStr + 1
            local val = string.byte(keyStr, pos)
            local mixed = bit32.bxor(val, hash, i % 256)
            expanded[i] = (mixed + i * 7) % 256
        end
        
        return expanded
    end
    
    local keySchedule = expandKey(key, #binaryData * 3)
    local plaintext = {}
    local keyIndex = 1
    
    -- Reverse third pass
    for i = 1, #binaryData do
        local byte = string.byte(binaryData, i)
        local original = (byte - i * 3 - keySchedule[#binaryData + i]) % 256
        plaintext[i] = string.char(original)
    end
    
    -- Reverse second pass
    local feedback = 0
    for i = 1, #plaintext do
        local byte = string.byte(plaintext[i])
        local derotated = bit32.bxor(byte, feedback)
        feedback = (feedback + derotated) % 256
        plaintext[i] = string.char(derotated)
    end
    
    -- Reverse first pass
    for i = 1, #plaintext do
        local byte = string.byte(plaintext[i])
        local decrypted = bit32.bxor(byte, keySchedule[keyIndex])
        plaintext[i] = string.char(decrypted)
        keyIndex = keyIndex + 1
    end
    
    return table.concat(plaintext)
end

function adcc.secure_loadstring()
    local original_globals = getfenv(0)
    local real_loadstring = original_globals.loadstring

    if not real_loadstring or type(real_loadstring) ~= "function" then
        return function(code) return function() end end
    end

    local funcStr = tostring(real_loadstring)
    if not (funcStr:match("^function: 0x%x+$") or funcStr:match("^builtin function: loadstring$")) then
        return function(code) return function() end end
    end

    return function(code)
        local chunk, err = real_loadstring(code)
        if not chunk then
            return function() end
        end
        return chunk
    end
end

function adcc.l(encrypted_code)
    local scy = pcall(function()
        return loadstring([[return "nope, try again: https://www.youtube.com/watch?v=ZNGqBDRJgvo"]])()
    end)

    if scy then
        local decrypted_code = adcc.decrypt(encrypted_code, hardcoded)
        local loader = adcc.secure_loadstring()
        loader(decrypted_code)()
    end
end

return adcc
