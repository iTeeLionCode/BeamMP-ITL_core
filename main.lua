local pluginName = "ITLcore"

function onInit()

    local CMD = require("cmd")
    local CFG = require("cfg")
    local LANG = require("lang")
    local MYSQL = require("mysql")
    local HELPER = require("helper")

    local config = CFG.getLocal("main")
    local playersCache = {}
    local cmdCache = {}

    LANG.set(config.lang)

    local function getUserByName(playerName)
        local dbRes = MYSQL.execute("read", "SELECT * FROM users WHERE nick = '%s'", {playerName})
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
            for key, nick in pairs(players) do
                playersCache[nick] = {playerId = key, userId = nil, mute = nil}
            end
        end

        local nicks = "'" .. HELPER.tabconcat(players, "','") .. "'"
        local dbRes = MYSQL.execute("read", "SELECT * FROM users WHERE nick IN ("..nicks..")", {})
        local users = MYSQL.fetchAll(dbRes)
        if users ~= nil then
            for key, user in pairs(users) do
                playersCache[user.nick]["userId"] = user.id
            end
        end

        local now = os.date("%Y-%m-%d %H:%M:%S")
        local blockings = {}
        if players ~= nil then
            local sql = "SELECT blockings.id, blockings.user_id, blockings.type, blockings.cancelAt, blockings.reason, users.nick FROM blockings JOIN users ON blockings.user_id = users.id WHERE type = 'mute' AND blockings.cancelAt > '%s' AND users.nick IN ("..nicks..")"
            local dbRes = MYSQL.execute("read", sql, {now})
            blockings = MYSQL.fetchAll(dbRes)
        end
        if blockings ~= nil then
            for key, item in pairs(blockings) do
                playersCache[item.nick]["mute"] = {id = item.id, cancelAt = item.cancelAt, reason = item.reason}
            end
        end
    end

    local function kick(playerName, reason)
        local playerId = HELPER.getPlayerIdByName(playerName)
        if playerId ~= nil then
            MP.DropPlayer(playerId, reason)
        end
    end

    local function ban(playerName, reason, duration)
        local untilDate = os.date("%Y-%m-%d %H:%M:%S", HELPER.getFutureTimestamp(duration))

        local user = getUserByName(playerName);
        if user ~= nil then
            MYSQL.execute("write", "INSERT INTO blockings (user_id, type, cancelAt, reason) VALUES ('%s', '%s', '%s', '%s')", {user.id, "ban", untilDate, reason})
        end

        kick(playerName, reason)
    end

    local function mute(playerName, reason, duration)
        local untilDate = os.date("%Y-%m-%d %H:%M:%S", HELPER.getFutureTimestamp(duration))

        local user = getUserByName(playerName);
        if user ~= nil then
            MYSQL.execute("write", "INSERT INTO blockings (user_id, type, cancelAt, reason) VALUES ('%s', '%s', '%s', '%s')", {user.id, "mute", untilDate, reason})
        end
    end

    local function checkPlayerOnConnect(playerName, isGuest)
        if (config.guests_allowed == false and isGuest == true) then
            -- ToDo: statistics row
            print(string.format("User %s kicked because guests are not allowed!", playerName))
            return LANG.getRow("USER_GUEST_NOT_ALLOWED")
        end

        local dbRes = MYSQL.execute("read", "SELECT id FROM users WHERE nick = '%s'", {playerName})
        local users = MYSQL.fetchAll(dbRes)
        if #users > 0 then
            local now = os.date("%Y-%m-%d %H:%M:%S")
            local dbRes = MYSQL.execute("read", "SELECT id, user_id, cancelAt, reason FROM blockings WHERE type = 'ban' AND isForciblyCanceled = 0 AND user_id = '%s' AND cancelAt > '%s' ORDER BY id DESC", {users[1].id, now})
            local users = MYSQL.fetchAll(dbRes)
            if #users > 0 then
                print(string.format("User %s kicked because of ban %s: %s", playerName, users[1].id, users[1].reason))
                return string.format(LANG.getRow("YOU_ARE_BANNED_UNTIL_FOR_REASON"), users[1].cancelAt, users[1].reason)
            end
        else
            MYSQL.execute("write", "INSERT INTO users (nick) VALUES ('%s')", {playerName})
        end

        -- ToDo: ban by previous ip

        return nil
    end


    --
    -- EVENTS
    --


    -- function onConsoleCmdHandler_testc(args)
    --     -- print("test")
    -- end
    -- CMD.registerConsoleCmd("onConsoleCmdHandler_testc", "testc", "TEST")

    -- function onConsoleCmdHandler_testc2(args)
    --     -- print("test")
    -- end
    -- CMD.registerConsoleCmd("onConsoleCmdHandler_testc2", "testc2", "TEST")


    function OnShowCommandsHandler(args)
        MP.TriggerGlobalEvent("onShowAllCommands")
    end
    CMD.registerConsoleCmd("onShowCommandsHandler", "commands", "Show all registred commands")


    function onChatCmdHandler_kick(initiatorId, args)
        if args[1] == nil or args[2] == nil then
            MP.SendChatMessage(initiatorId, string.format("%s. %s", LANG.getRow("CMD_WONG_SYNTAX"), LANG.getRow("CMD_KICK_USAGE")))
        else
            kick(args[1], args[2])
        end
    end
    CMD.registerChatCmd("onChatCmdHandler_kick", "kick", "Kick player")


    function onConsoleCmdHandler_ban(args)
        if args[1] == nil or args[2] == nil or args[3] == nil then
            print(string.format("%s. %s", LANG.getRow("CMD_WONG_SYNTAX"), LANG.getRow("CMD_BAN_USAGE")))
        else
            ban(args[1], args[2], args[3])
        end
    end
    CMD.registerConsoleCmd("onConsoleCmdHandler_ban", "ban", "Ban player")

    function onChatCmdHandler_ban(initiatorId, args)
        if args[1] == nil or args[2] == nil or args[3] == nil then
            MP.SendChatMessage(initiatorId, string.format("%s. %s", LANG.getRow("CMD_WONG_SYNTAX"), LANG.getRow("CMD_BAN_USAGE")))
        else
            ban(args[1], args[2], args[3])
        end
    end
    CMD.registerChatCmd("onChatCmdHandler_ban", "ban", "Ban player")


    function onConsoleCmdHandler_mute(args)
        if args[1] == nil or args[2] == nil or args[3] == nil then
            print(string.format("%s. %s", LANG.getRow("CMD_WONG_SYNTAX"), LANG.getRow("CMD_MUTE_USAGE")))
        else
            mute(args[1], args[2], args[3])
        end
        reloadPlayersCache()
    end
    CMD.registerConsoleCmd("onConsoleCmdHandler_mute", "mute", "Mute player")

    function onChatCmdHandler_mute(initiatorId, args)
        if args[1] == nil or args[2] == nil or args[3] == nil then
            MP.SendChatMessage(initiatorId, string.format("%s. %s", LANG.getRow("CMD_WONG_SYNTAX"), LANG.getRow("CMD_MUTE_USAGE")))
        else
            mute(args[1], args[2], args[3])
        end
        reloadPlayersCache()
    end
    CMD.registerChatCmd("onChatCmdHandler_mute", "mute", "Mute player")


    function onConsoleCmdHandler_getplayers(args)
        print(playersCache)
    end
    CMD.registerConsoleCmd("onConsoleCmdHandler_getplayers", "getplayers", "Mute player")

    function onChatCmdHandler_getplayers(initiatorId, args)
        if playersCache ~= nil then
            for nick, player in pairs(playersCache) do
                if player.mute == nil then
                    player["mute"] = {cancelAt = "NO", reason = "NO"}
                end
                MP.SendChatMessage(initiatorId, string.format("%s - pid: %s, uid: %s, muted until: %s, mute reason: %s", nick, player.playerId, player.userId, player.mute.cancelAt, player.mute.reason))
            end
        end
    end
    CMD.registerChatCmd("onChatCmdHandler_getplayers", "getplayers", "Mute player")


    function onConsoleCmdHandler_reloadplayers(args)
        reloadPlayersCache()
    end
    CMD.registerConsoleCmd("onConsoleCmdHandler_reloadplayers", "reloadplayers", "Mute player")

    function onChatCmdHandler_reloadplayers(initiatorId, args)
        reloadPlayersCache()
    end
    CMD.registerChatCmd("onChatCmdHandler_reloadplayers", "reloadplayers", "Mute player")


    function preventMutedUserMessageHandler(senderId, senderName, text)
        for nick, player in pairs(playersCache) do
            if nick == senderName and player.mute ~= nil then
                MP.SendChatMessage(senderId, string.format(LANG.getRow("YOU_ARE_MUTED_UNTIL_FOR_REASON"), player.mute.cancelAt, player.mute.reason))
                return 1
            end
        end
    end
    MP.RegisterEvent("onChatMessage", "preventMutedUserMessageHandler")

    function onPlayerAuthHandler(playerName, playerRole, isGuest, identifiers)
        local res = checkPlayerOnConnect(playerName, isGuest)
        if res ~= nil then
            return res
        end
    end
    MP.RegisterEvent("onPlayerAuth", "onPlayerAuthHandler")

    function onPlayerJoiningHandler(playerId)
        reloadPlayersCache()
    end
    MP.RegisterEvent("onPlayerJoining", "onPlayerJoiningHandler")

end
