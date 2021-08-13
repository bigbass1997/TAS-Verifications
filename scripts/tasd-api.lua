local api = {}

local char = string.char

local MAGIC_NUMBER  = char(0x54, 0x41, 0x53, 0x44)
local TASD_VERSION  = char(0x00, 0x01)
local KEY_WIDTH     = char(0x02)

local KEY_CONSOLE_TYPE      = char(0x00, 0x01)
local KEY_CONSOLE_REGION    = char(0x00, 0x02)
local KEY_GAME_TITLE        = char(0x00, 0x03)
local KEY_AUTHOR            = char(0x00, 0x04)
local KEY_CATEGORY          = char(0x00, 0x05)
local KEY_EMULATOR_NAME     = char(0x00, 0x06)
local KEY_EMULATOR_VERSION  = char(0x00, 0x07)
local KEY_TAS_LAST_MODIFIED = char(0x00, 0x08)
local KEY_DUMP_LAST_MODIFIED= char(0x00, 0x09)
local KEY_NUMBER_OF_FRAMES  = char(0x00, 0x0A)
local KEY_RERECORDS         = char(0x00, 0x0B)
local KEY_SOURCE_LINK       = char(0x00, 0x0C)
local KEY_BLANK_FRAMES      = char(0x00, 0x0D)
local KEY_VERIFIED          = char(0x00, 0x0E)
local KEY_MEMORY_INIT       = char(0x00, 0x0F)

local KEY_LATCH_FILTER      = char(0x01, 0x01)
local KEY_CLOCK_FILTER      = char(0x01, 0x02)
local KEY_OVERREAD          = char(0x01, 0x03)
local KEY_DPCM              = char(0x01, 0x04)
local KEY_GAME_GENIE_CODE   = char(0x01, 0x05)

local KEY_INPUT_CHUNKS      = char(0xFE, 0x01)
local KEY_TRANSITION        = char(0xFE, 0x02)
local KEY_LAG_FRAME_CHUNK   = char(0xFE, 0x03)

local LEN_1B    = char(0x01, 0x01) -- (exponent, payload length)
local LEN_2B    = char(0x01, 0x02)
local LEN_4B    = char(0x01, 0x04)
local LEN_8B    = char(0x01, 0x08)

function calcExponent(number)
    local exp = 0
    local n = number
    while n ~= 0 do
        n = bit.rshift(n, 8)
        exp = exp + 1
    end
    
    if exp == 0 then
        exp = 1
    end
    
    return exp
end

function encodeNumber(number, bytes)
    local s = ""
    for i = 1, bytes do
        s = s..char(bit.band(number, 0xFF))
        number = bit.rshift(number, 8)
    end
    return string.reverse(s)
end

function encodeStr(str)
    local exp = calcExponent(#str)
    local size_str = encodeNumber(#str, exp)
    return char(exp)..size_str..str
end


function api.header(h)
    h:write(MAGIC_NUMBER..TASD_VERSION..KEY_WIDTH)
end

function api.consoleType(h, kind)
    h:write(KEY_CONSOLE_TYPE..LEN_1B..char(kind))
end

function api.consoleRegion(h, region)
    h:write(KEY_CONSOLE_REGION..LEN_1B..char(region))
end

function api.gameTitle(h, title)
    h:write(KEY_GAME_TITLE..encodeStr(title))
end

function api.author(h, author)
    h:write(KEY_AUTHOR..encodeStr(author))
end

function api.category(h, category)
    h:write(KEY_CATEGORY..encodeStr(category))
end

function api.emulatorName(h, name)
    h:write(KEY_EMULATOR_NAME..encodeStr(name))
end

function api.emulatorVersion(h, version)
    h:write(KEY_EMULATOR_VERSION..encodeStr(version))
end

function api.tasLastModified(h, time) -- time = 8 byte epoch number
    h:write(KEY_TAS_LAST_MODIFIED..LEN_8B..encodeNumber(time, 8))
end

function api.dumpLastModified(h)
    h:write(KEY_DUMP_LAST_MODIFIED..LEN_8B..encodeNumber(os.time(), 8))
end

function api.numberOfFrames(h)
    h:write(KEY_NUMBER_OF_FRAMES..LEN_4B..encodeNumber(movie.length(), 4))
end

function api.rerecords(h)
    local count = 0
    if type(movie.getrerecordcount) == "function" then
        count = movie.getrerecordcount()
    elseif type(movie.rerecordcount) == "function" then
        count = movie.rerecordcount()
    end
    
    h:write(KEY_RERECORDS..LEN_4B..encodeNumber(count, 4))
end

function api.sourceLink(h, url)
    h:write(KEY_SOURCE_LINK..encodeStr(url))
end

function api.blankFrames(h, frames)
    h:write(KEY_BLANK_FRAMES..LEN_2B..encodeNumber(frames, 2))
end

function api.verified(h, verified)
    h:write(KEY_VERIFIED..LEN_1B..char(verified))
end

-- TODO function api.memoryInit(h, kind, name, p) -- p is optional


function api.latchFilter(h, filter)
    h:write(KEY_LATCH_FILTER..LEN_1B..char(filter))
end

function api.clockFilter(h, filter)
    h:write(KEY_CLOCK_FILTER..LEN_1B..char(filter))
end

function api.overread(h, overread)
    h:write(KEY_OVERREAD..LEN_1B..char(overread))
end

function api.dpcm(h, dpcm)
    h:write(KEY_DPCM..LEN_1B..char(dpcm))
end

function api.gameGenieCode(h, code)
    h:write(KEY_GAME_GENIE_CODE..encodeStr(code))
end


function api.inputChunks(h, chunk) -- chunk is an array of bytes
    local length = #chunk
    local exponent = calcExponent(length)
    h:write(KEY_INPUT_CHUNKS..char(exponent))
    
    local bytes = {}
    for i = 1, exponent do
        table.insert(bytes, 1, bit.band(length, 0xFF))
        length = bit.rshift(length, 8)
    end
    
    for i = 1, #bytes do
        h:write(char(bytes[i]))
    end
    
    for i = 1, #chunk do
        h:write(char(chunk[i]))
    end
end

function api.transition(h, index, kind, port, controllerKind)
    local index_str = encodeNumber(index, 4)
    local size = 4 + 1
    
    if controllerKind then
        size = size + 2
        local exp = calcExponent(size)
        h:write(KEY_TRANSITION..char(exp)..encodeNumber(size, exp)..index_str..char(kind)..char(port)..char(controllerKind))
    else
        local exp = calcExponent(size)
        h:write(KEY_TRANSITION..char(exp)..encodeNumber(size, exp)..index_str..char(kind))
    end
end

function api.lagFrameChunk(h, index, count)
    h:write(KEY_LAG_FRAME_CHUNK..LEN_8B..encodeNumber(index, 4)..encodeNumber(count, 4))
end



return api