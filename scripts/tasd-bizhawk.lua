
local handle = nil

local wasMovieLoaded = false
local readyToDump = false

local writtenFrames = 0

local playerKeys = {
    {"P1 Right", "P1 Left", "P1 Down", "P1 Up", "P1 Start", "P1 Select", "P1 B", "P1 A"},
    {"P2 Right", "P2 Left", "P2 Down", "P2 Up", "P2 Start", "P2 Select", "P2 B", "P2 A"}
}

--local inspect = require("inspect")
local api = require("tasd-api")

console.clear()

function getDumpFilename()
    local _, _, path, filename, ext = string.find(movie.filename(), "(.-)([^\\/]-%.?)([^%.\\/]*)$")
    return path..filename.."tasd"
end

function writeFrame()
    local input = movie.getinput(emu.framecount() - 1)
    
    local chunk = {0, 0}
    
    for i = 1, 2 do
        for k = 7, 0, -1 do
            local key = playerKeys[i][k + 1]
            if input[key] == true then
                chunk[i] = bit.set(chunk[i], k)
            end
        end
    end
    
    --print("("..emu.framecount()..") "..writtenFrames.." is "..string.format("0x%02X 0x%02X", chunk[1], chunk[2]))
    
    api.inputChunks(handle, chunk)
end

while not movie.isloaded() do
    emu.yield()
end

while true do
    if movie.isloaded() and not wasMovieLoaded then
        if emu.framecount() == 0 then
            wasMovieLoaded = true
            local filename = getDumpFilename()
            handle = io.open(filename, "wb+")
            
            if handle == nil then
                print("Error opening dump file!")
                break
            else
                api.header(handle)
                api.consoleType(handle, 1)
                api.emulatorName(handle, "Bizhawk")
                api.dumpLastModified(handle)
                api.numberOfFrames(handle, movie.length())
                api.rerecords(handle)
                api.blankFrames(handle, 0)
                handle:flush()
            end
            
            --print(tostring(movie.length()-1)..": "..inspect(movie.getinput(movie.length()-1)))
            
            print("Dumping has started...")
            --[[print("on frame: "..emu.framecount())
            print("Lag frames on start: "..emu.lagcount())]]--
            client.unpause()
            readyToDump = true
            writtenFrames = 0
        elseif emu.framecount() > 0 then
            client.pause()
            print("Sorry! You cannot activate/start this script after the first frame of a movie!")
            print("Use: File > Movie > Play from Beginning")
            print("Then while the movie is still paused, activate this script again.")
            break
        end
    elseif not movie.isloaded() then
        wasMovieLoaded = false
        readyToDump = false
    end
    
    
    if readyToDump then
        if not emu.islagged() and emu.framecount() <= movie.length() and emu.framecount() > 0 then
            --print(emu.framecount()..": "..inspect(movie.getinput(emu.framecount())))
            --table.insert(allInputs, movie.getinput(emu.framecount()))
            
            writeFrame()
            handle:flush()
            writtenFrames = writtenFrames + 1
        end
        
        --[[if emu.islagged() then
            print("("..emu.framecount()..") "..writtenFrames.." is lag")
        end
        print("Lag frames: "..emu.lagcount())]]--
    end
    
    
    if movie.mode() == "FINISHED" then
        wasMovieLoaded = false
        readyToDump = false
        finalFrame = false
        client.pause()
        movie.stop()
        handle:close()
        print("Movie dump complete!")
    end
    
    emu.frameadvance()
end
