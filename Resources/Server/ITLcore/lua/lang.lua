local MODULE = {}

local langsPath = debug.getinfo(1).source:match("@?(.*/)") .. "../lang/"
local lang = 'en'

function MODULE.initModule(setLang)
    lang = setLang
end

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

function MODULE.getRow(name)
    local filePath = langsPath .. lang .. ".json"
    if (FS.IsFile(filePath)) then
        local lang = Util.JsonDecode(MODULE.readFile(filePath))
        return lang[name]
    else
        return name
    end
end

return MODULE