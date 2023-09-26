local MODULE = {}
local globalPath = "Config/"
local localPath = debug.getinfo(1).source:match("@?(.*/)") .. "../config/"

function MODULE.readFile(path)
    local file = io.open(path, "rb")
    if not file then
       return nil
    else
       local content = file:read "*a"
       file:close()
       return content
    end
 end

function MODULE.getLocal(name)
    return MODULE.get("local", name)
end

function MODULE.getGlobal(name)
    return MODULE.get("global", name)
end

function MODULE.get(type, name)
    local rootPath = localPath
    if type == "global" then
        rootPath = globalPath
    end

    local filePath = rootPath .. name .. ".json"
    if (FS.IsFile(filePath)) then
        return Util.JsonDecode(MODULE.readFile(filePath))
    else
        return nil
    end
end

return MODULE