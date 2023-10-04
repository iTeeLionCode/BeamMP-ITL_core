-- Module require ITL_LANG and ITL_MYSQL modules!!!
local MODULE = {}

local LANG = nil
local MYSQL = nil
local serverId = nil
local chatCommands = {}
local consoleCommands = {}
local commandPrefix = "/"
local cmdCache = {}

local function splitTextToArgsArray(text)
    local parts = {}
    local e = 0

    while true do
        local b = e+1
        b = text:find("%S",b)
        if b==nil then break end
        if text:sub(b,b)=="'" then
            e = text:find("'",b+1)
            b = b+1
        elseif text:sub(b,b)=='"' then
            e = text:find('"',b+1)
            b = b+1
        else
            e = text:find("%s",b+1)
        end
        if e==nil then e=#text+1 end
        table.insert(parts, text:sub(b,e-1))
    end

    local name = nil
    if parts ~= nil then
        name = parts[1]
        table.remove(parts, 1)

        if name ~= nil and string.sub(name, 1, 1) == commandPrefix then
            name = string.sub(name, 2)
        end
    end

    return {name = name, args = parts}
end

local function checkCmdAccess(cmd, nick)
    local sql = "SELECT users.id, users.player_name, users_groups.group_id, cmd_permissions.cmd FROM users INNER JOIN users_groups ON users.id = users_groups.user_id INNER JOIN cmd_permissions ON (entity = 'group' AND entity_id = users_groups.group_id) OR (entity = 'user' AND entity_id = users.id) WHERE users.player_name = '%s' AND cmd_permissions.cmd = '%s'";
    local dbRes = MYSQL.execute("read", sql, {nick, cmd})
    local access = MYSQL.fetchAll(dbRes)
    if #access > 0 then
        return true;
    end
    return false;
end

function MODULE.initModule(setLang, setMysql, setServerId)
    serverId = setServerId
    LANG = setLang
    MYSQL = setMysql
end

function MODULE.registerConsoleCmd(handler, name, description)
    if (MODULE.isRegistred(consoleCommands, name) == nil) then
        table.insert(consoleCommands, {name = name, description = description})
        MP.RegisterEvent("onConsoleCmd_" .. name, handler)
    end
end

function MODULE.registerChatCmd(handler, name, description)
    if (MODULE.isRegistred(chatCommands, name) == nil) then
        table.insert(chatCommands, {name = name, description = description})
        MP.RegisterEvent("onChatCmd_" .. name, handler)
    end
end

function MODULE.isRegistred(typeList, name)
    for k, v in pairs(typeList) do
        if (v.name == name) then
            return k
        end
    end
    return nil
end

function MODULE.responseMessage(senderId, msg)
    if (type(senderId) == 'nil') then
        print(msg)
    else
        MP.SendChatMessage(senderId, msg)
    end
end

function OnShowAllCommandsHandler()
    local commands = {}
    for index, cmd in ipairs(consoleCommands) do
        table.insert(commands, cmd.name .. ": " .. cmd.description .. "\n")
    end
    print(table.concat(commands, "\n"))
end
MP.RegisterEvent("onShowAllCommands", "OnShowAllCommandsHandler")

function OnChatMessageHandler(senderId, senderName, text)
    if string.sub(text, 1, 1) == commandPrefix then
        local cmd = splitTextToArgsArray(text)
        if MODULE.isRegistred(chatCommands, cmd.name) then
            local isAccess = checkCmdAccess(cmd.name, senderName)
            if isAccess then
                MP.TriggerLocalEvent("onChatCmd_" .. cmd.name, senderId, cmd.args)
            else
                MP.SendChatMessage(senderId, LANG.getRow("CMD_NOT_ALLOWED"))
            end
            return 1
        end
    end
end
MP.RegisterEvent("onChatMessage", "OnChatMessageHandler")

function OnConsoleInputHandler(text)
    local cmd = splitTextToArgsArray(text)
    if MODULE.isRegistred(consoleCommands, cmd.name) then
        MP.TriggerLocalEvent("onConsoleCmd_" .. cmd.name, cmd.args)
        return "Command: " .. cmd.name
    else
        return
    end
end
MP.RegisterEvent("onConsoleInput", "OnConsoleInputHandler")

return MODULE