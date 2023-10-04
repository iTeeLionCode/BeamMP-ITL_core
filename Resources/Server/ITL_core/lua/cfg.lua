local MODULE = {}

local globalPath = "Config/"
local localPath = debug.getinfo(1).source:match("@?(.*/)") .. "../config/"

local function readFile(path)
    local file = io.open(path, "rb")
    if not file then
       return nil
    else
       local content = file:read "*a"
       file:close()
       return content
    end
end

local function get(type, name)
    local rootPath = localPath
    if type == "global" then
        rootPath = globalPath
    end

    local filePath = rootPath .. name .. ".json"
    if (FS.IsFile(filePath)) then
        return Util.JsonDecode(readFile(filePath))
    else
        return nil
    end
end

function MODULE.getLocal(name)
    return get("local", name)
end

function MODULE.getGlobal(name)
    return get("global", name)
end

return MODULE