local pluginName = "ITL_core"
local pluginVersion = "0.0.2"
local pluginInitialized = nil

local CMD = require("cmd")
local CFG = require("cfg")
local LANG = require("lang")
local MYSQL = require("mysql")
local UTILS = require("utils")

local config = CFG.getLocal("main")
local playersCache = {}

local currentLang = config.lang
if currentLang ~= nil then
    LANG.initModule(config.lang)
end
local serverId = config.server_id;

CMD.initModule(LANG, MYSQL, serverId)
MYSQL.initModule(CFG.getGlobal("mysql"))

local function getUserByName(playerName)
    local dbRes = MYSQL.execute("read", "SELECT * FROM users WHERE player_name = '%s'", {playerName})
    local users = MYSQL.fetchAll(dbRes)

    if #users > 0 then
        return users[1]
    end

    return nil
end

local function reloadPlayersCache()
    playersCache = {}

    local players = MP.GetPlayers()
    if players ~= nil then
        for key, playerName in pairs(players) do
            playersCache[playerName] = {playerId = key, userId = nil, mute = nil}
        end
    end

    local playerNames = "'" .. UTILS.tabconcat(players, "','") .. "'"
    local dbRes = MYSQL.execute("read", "SELECT * FROM users WHERE player_name IN ("..playerNames..")", {})
    local users = MYSQL.fetchAll(dbRes)
    if users ~= nil then
        for key, user in pairs(users) do
            playersCache[user.playerName]["userId"] = user.id
        end
    end

    local now = os.date("%Y-%m-%d %H:%M:%S")
    local blockings = {}
    if players ~= nil then
        local sql = "SELECT blockings.id, blockings.server_id, blockings.user_id, blockings.type, blockings.cancel_at, blockings.reason, users.player_name FROM blockings JOIN users ON blockings.user_id = users.id WHERE blockings.server_id = '"..serverId.."' AND type = 'mute' AND blockings.cancel_at > '%s' AND users.player_name IN ("..playerNames..")"
        local dbRes = MYSQL.execute("read", sql, {now})
        blockings = MYSQL.fetchAll(dbRes)
    end
    if blockings ~= nil then
        for key, item in pairs(blockings) do
            playersCache[item.playerName]["mute"] = {id = item.id, cancel_at = item.cancel_at, reason = item.reason}
        end
    end
end

local function startUserSession(playerName, userId)
    local playerIdent = MP.GetPlayerIdentifiers(UTILS.getPlayerIdByName(playerName))
    local now = os.date("%Y-%m-%d %H:%M:%S")

    if playerName ~= nil then
        if userId ~= nil then
            MYSQL.execute("write", "INSERT INTO users_stats (server_id, user_id, player_name, connect_date, ip) VALUES ('%s', '%s', '%s', '%s', '%s')", {serverId, userId, playerName, now, playerIdent.ip})
        else
            MYSQL.execute("write", "INSERT INTO users_stats (server_id, player_name, connect_date, ip) VALUES ('%s', '%s', '%s', '%s')", {serverId, playerName, now, playerIdent.ip})
        end
    end
end

local function endUserSession(playerName, userId)
    local now = os.date("%Y-%m-%d %H:%M:%S")
    if playerName ~= nil then
        MYSQL.execute("write", "UPDATE users_stats SET disconnect_date = '%s' WHERE server_id = '%s' AND player_name = '%s'", {now, serverId, playerName})
    else
        MYSQL.execute("write", "UPDATE users_stats SET disconnect_date = '%s' WHERE server_id = '%s' AND disconnect_date IS NULL", {now, serverId})
    end
end

local function kick(playerName, reason)
    local playerId = UTILS.getPlayerIdByName(playerName)
    if playerId ~= nil then
        MP.DropPlayer(playerId, reason)
    end
end

local function ban(playerName, reason, duration)
    local untilDate = os.date("%Y-%m-%d %H:%M:%S", UTILS.getFutureTimestamp(duration))

    kick(playerName, reason)

    local user = getUserByName(playerName);
    if serverId ~= nil then
        if user ~= nil and serverId ~= nil then
            MYSQL.execute("write", "INSERT INTO blockings (server_id, user_id, type, cancel_at, reason) VALUES ('%s', '%s', '%s', '%s', '%s')", {serverId, user.id, "ban", untilDate, reason})
        else
            return "User not found in DB";
        end
    end

    return true;
end

-- ToDo unban
local function unban(playerName)

end

local function mute(playerName, reason, duration)
    local untilDate = os.date("%Y-%m-%d %H:%M:%S", UTILS.getFutureTimestamp(duration))

    local user = getUserByName(playerName);
    if serverId ~= nil then
        if user ~= nil then
            MYSQL.execute("write", "INSERT INTO blockings (server_id, user_id, type, cancel_at, reason) VALUES ('%s', '%s', '%s', '%s', '%s')", {serverId, user.id, "mute", untilDate, reason})
        else
            return "User not found in DB";
        end
    end

    return true
end

-- ToDo unmute
local function unmute(playerName)

end

local function checkPlayerOnAuth(playerName, isGuest)
    local userId = nil

    if config.guests_allowed ~= nil then
        if (config.guests_allowed == false and isGuest == true) then
            print(string.format("User %s kicked because guests are not allowed!", playerName))
            return LANG.getRow("USER_GUEST_NOT_ALLOWED")
        end
    end

    local dbRes = MYSQL.execute("read", "SELECT id FROM users WHERE player_name = '%s'", {playerName})
    local users = MYSQL.fetchAll(dbRes)
    if #users > 0 then
        userId = users[1].id
        local now = os.date("%Y-%m-%d %H:%M:%S")
        local dbRes = MYSQL.execute("read", "SELECT id, user_id, cancel_at, reason FROM blockings WHERE type = 'ban' AND is_canceled = 0 AND server_id = '%s' AND user_id = '%s' AND cancel_at > '%s' ORDER BY id DESC", {serverId, userId, now})
        local blockings = MYSQL.fetchAll(dbRes)
        if #blockings > 0 then
            print(string.format("User %s kicked because of ban %s: %s", playerName, blockings[1].id, blockings[1].reason))
            return string.format(LANG.getRow("YOU_ARE_BANNED_UNTIL_FOR_REASON"), blockings[1].cancel_at, blockings[1].reason)
        end
    else
        userId = MYSQL.execute("write", "INSERT INTO users (player_name) VALUES ('%s')", {playerName})
    end

    local defaultGroup = config.default_group_id
    if userId ~= nil and defaultGroup ~= nil then
        local dbRes = MYSQL.execute("read", "SELECT id FROM users_groups WHERE server_id = '%s' AND user_id = '%s' AND group_id = '%s'", {serverId, userId, config.default_group_id})
        local usersgroups = MYSQL.fetchAll(dbRes)
        if #usersgroups <= 0 then
            MYSQL.execute("write", "INSERT INTO users_groups (server_id, user_id, group_id) VALUES ('%s', '%s', '%s')", {serverId, userId, config.default_group_id})
        end
    end

    -- ToDo: ban by previous ip

    return nil
end


function onInit()

    function OnShowCommandsHandler(args)
        print("SHOW CMD")
        MP.TriggerGlobalEvent("onShowAllCommands")
    end
    CMD.registerConsoleCmd("OnShowCommandsHandler", "commands", "Show all registred commands")

    function OnConsoleCmd_reloadplayers_handler(args)
        reloadPlayersCache()
    end
    CMD.registerConsoleCmd("OnConsoleCmd_reloadplayers_handler", "reloadplayers", "Mute player")

    function OnConsoleCmd_ban_handler(args)
        if args[1] == nil or args[2] == nil or args[3] == nil then
            print(string.format("%s. %s", LANG.getRow("CMD_WONG_SYNTAX"), LANG.getRow("CMD_BAN_USAGE")))
        else
            ban(args[1], args[2], args[3])
        end
    end
    CMD.registerConsoleCmd("OnConsoleCmd_ban_handler", "ban", "Ban player")

    function OnConsoleCmd_mute_handler(args)
        if args[1] == nil or args[2] == nil or args[3] == nil then
            print(string.format("%s. %s", LANG.getRow("CMD_WONG_SYNTAX"), LANG.getRow("CMD_MUTE_USAGE")))
        else
            mute(args[1], args[2], args[3])
        end
        reloadPlayersCache()
    end
    CMD.registerConsoleCmd("OnConsoleCmd_mute_handler", "mute", "Mute player")

    function OnConsoleCmd_getplayers_handler(args)
        print(playersCache)
    end
    CMD.registerConsoleCmd("OnConsoleCmd_getplayers_handler", "getplayers", "Mute player")

    -- 

    function OnChatCmd_reloadplayers_handler(initiatorId, args)
        reloadPlayersCache()
    end
    CMD.registerChatCmd("OnChatCmd_reloadplayers_handler", "reloadplayers", "Mute player")

    function OnChatCmd_whoami_handler(initiatorId, args)
        MP.SendChatMessage(initiatorId, string.format("%s: %s", initiatorId, MP.GetPlayerName(initiatorId)))
    end
    CMD.registerChatCmd("OnChatCmd_whoami_handler", "whoami", "Shows your playerId and playerName")

    function OnChatCmd_playerslist_handler(initiatorId, args)
        local players = {}
        for id, name in pairs(MP.GetPlayers()) do
            table.insert(players, id .. ": " .. name)
        end
        MP.SendChatMessage(initiatorId, string.format("%s", table.concat(players, "| ")))
    end
    CMD.registerChatCmd("OnChatCmd_playerslist_handler", "players", "Shows players list")

    function OnChatCmd_getplayers_handler(initiatorId, args)
        if playersCache ~= nil then
            for playerName, player in pairs(playersCache) do
                if player.mute == nil then
                    player["mute"] = {cancel_at = "NO", reason = "NO"}
                end
                MP.SendChatMessage(initiatorId, string.format("%s - pid: %s, uid: %s, muted until: %s, mute reason: %s", playerName, player.playerId, player.userId, player.mute.cancel_at, player.mute.reason))
            end
        end
    end
    CMD.registerChatCmd("OnChatCmd_getplayers_handler", "players2", "Mute player")

    function OnChatCmd_kick_handler(initiatorId, args)
        if args[1] == nil or args[2] == nil then
            MP.SendChatMessage(initiatorId, string.format("%s. %s", LANG.getRow("CMD_WONG_SYNTAX"), LANG.getRow("CMD_KICK_USAGE")))
        else
            kick(args[1], args[2])
        end
    end
    CMD.registerChatCmd("OnChatCmd_kick_handler", "kick", "Kick player")


    function OnChatCmd_ban_handler(initiatorId, args)
        if args[1] == nil or args[2] == nil or args[3] == nil then
            MP.SendChatMessage(initiatorId, string.format("%s. %s", LANG.getRow("CMD_WONG_SYNTAX"), LANG.getRow("CMD_BAN_USAGE")))
        else
            ban(args[1], args[2], args[3])
        end
    end
    CMD.registerChatCmd("OnChatCmd_ban_handler", "ban", "Ban player")


    function OnChatCmd_mute_handler(initiatorId, args)
        if args[1] == nil or args[2] == nil or args[3] == nil then
            MP.SendChatMessage(initiatorId, string.format("%s. %s", LANG.getRow("CMD_WONG_SYNTAX"), LANG.getRow("CMD_MUTE_USAGE")))
        else
            mute(args[1], args[2], args[3])
        end
        reloadPlayersCache()
    end
    CMD.registerChatCmd("OnChatCmd_mute_handler", "mute", "Mute player")

    -- 

    function PreventMutedUserMessageHandler(senderId, senderName, text)
        for playerName, player in pairs(playersCache) do
            if playerName == senderName and player.mute ~= nil then
                MP.SendChatMessage(senderId, string.format(LANG.getRow("YOU_ARE_MUTED_UNTIL_FOR_REASON"), player.mute.cancel_at, player.mute.reason))
                return 1
            end
        end
    end
    MP.RegisterEvent("onChatMessage", "PreventMutedUserMessageHandler")

    function OnPlayerAuthHandler(playerName, playerRole, isGuest, identifiers)
        local res = checkPlayerOnAuth(playerName, isGuest)
        if res ~= nil then
            return res
        end
    end
    MP.RegisterEvent("onPlayerAuth", "OnPlayerAuthHandler")

    function OnPlayerConnectingHandler(playerId)
        local playerName = MP.GetPlayerName(playerId)
        local user = getUserByName(playerName)
        local userId = nil
        if user.id ~= nil then
            userId = user.id
        end
        startUserSession(playerName, userId)
    end
    MP.RegisterEvent("onPlayerConnecting", "OnPlayerConnectingHandler")

    function OnPlayerJoiningHandler(playerId)
        reloadPlayersCache()
    end
    MP.RegisterEvent("onPlayerJoining", "OnPlayerJoiningHandler")

    function OnPlayerDisconnectHandler(playerId)
        local playerName = MP.GetPlayerName(playerId)
        local user = getUserByName(playerName)
        local userId = nil
        if user.id ~= nil then
            userId = user.id
        end
        endUserSession(playerName, userId)
    end
    MP.RegisterEvent("onPlayerDisconnect", "OnPlayerDisconnectHandler")

    function OnShutdownHandler()
        endUserSession(nil, nil)
    end
    MP.RegisterEvent("onShutdown", "OnShutdownHandler")

end

endUserSession(nil, nil)
