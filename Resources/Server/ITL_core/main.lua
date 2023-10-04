pluginName = "ITL_core"
pluginVersion = "0.0.3"
pluginConfig = nil
playersCache = {}

CMD = require("cmd")
CFG = require("cfg")
LANG = require("lang")
MYSQL = require("mysql")
UTILS = require("utils")
CORE = require("core")

function onInit()

    print("Plugin " .. pluginName .. " ("..pluginVersion..") loaded!!!")
 
    pluginConfig = CFG.getLocal("main")
    LANG.initModule(pluginConfig.lang)
    CMD.initModule(LANG, MYSQL, pluginConfig.server_id)
    MYSQL.initModule(CFG.getGlobal("mysql"))

    -- Console CMD

    function OnShowCommandsHandler(args)
        print("Commands list:")
        MP.TriggerGlobalEvent("onShowAllCommands")
    end
    CMD.registerConsoleCmd("OnShowCommandsHandler", "commands", "Show all registred commands")
    
    function OnConsoleCmd_reloadplayers_handler(args)
        CORE.reloadPlayersCache()
    end
    CMD.registerConsoleCmd("OnConsoleCmd_reloadplayers_handler", "reloadplayers", "Reload players cache")

    function OnConsoleCmd_getplayers_handler(args)
        print(playersCache)
    end
    CMD.registerConsoleCmd("OnConsoleCmd_getplayers_handler", "playerscache", "Show players cache")
    
    function OnConsoleCmd_ban_handler(args)
        if args[1] == nil or args[2] == nil or args[3] == nil then
            print(string.format("%s. %s", LANG.getRow("CMD_WONG_SYNTAX"), LANG.getRow("CMD_BAN_USAGE")))
        else
            CORE.ban(args[1], args[2], args[3])
        end
    end
    CMD.registerConsoleCmd("OnConsoleCmd_ban_handler", "ban", "Ban player")
    
    function OnConsoleCmd_mute_handler(args)
        if args[1] == nil or args[2] == nil or args[3] == nil then
            print(string.format("%s. %s", LANG.getRow("CMD_WONG_SYNTAX"), LANG.getRow("CMD_MUTE_USAGE")))
        else
            CORE.mute(args[1], args[2], args[3])
        end
        CORE.reloadPlayersCache()
    end
    CMD.registerConsoleCmd("OnConsoleCmd_mute_handler", "mute", "Mute player")
    
    -- Chat CMD
    
    function OnChatCmd_whoami_handler(initiatorId, args)
        MP.SendChatMessage(initiatorId, string.format("%s: %s", initiatorId, MP.GetPlayerName(initiatorId)))
    end
    CMD.registerChatCmd("OnChatCmd_whoami_handler", "whoami", "Shows your playerId and playerName")

    function OnChatCmd_reloadplayers_handler(initiatorId, args)
        CORE.reloadPlayersCache()
    end
    CMD.registerChatCmd("OnChatCmd_reloadplayers_handler", "reloadplayers", "Reload players cache")
    
    function OnChatCmd_playerslist_handler(initiatorId, args)
        for id, name in pairs(MP.GetPlayers()) do
            MP.SendChatMessage(initiatorId, string.format("%s: %s", id, name))
        end
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
    CMD.registerChatCmd("OnChatCmd_getplayers_handler", "aplayers", "Show players cache with additional info")
    
    function OnChatCmd_kick_handler(initiatorId, args)
        if args[1] == nil or args[2] == nil then
            MP.SendChatMessage(initiatorId, string.format("%s. %s", LANG.getRow("CMD_WONG_SYNTAX"), LANG.getRow("CMD_KICK_USAGE")))
        else
            CORE.kick(args[1], args[2])
        end
    end
    CMD.registerChatCmd("OnChatCmd_kick_handler", "kick", "Kick player")
    
    
    function OnChatCmd_ban_handler(initiatorId, args)
        if args[1] == nil or args[2] == nil or args[3] == nil then
            MP.SendChatMessage(initiatorId, string.format("%s. %s", LANG.getRow("CMD_WONG_SYNTAX"), LANG.getRow("CMD_BAN_USAGE")))
        else
            CORE.ban(args[1], args[2], args[3])
        end
    end
    CMD.registerChatCmd("OnChatCmd_ban_handler", "ban", "Ban player")
    
    
    function OnChatCmd_mute_handler(initiatorId, args)
        if args[1] == nil or args[2] == nil or args[3] == nil then
            MP.SendChatMessage(initiatorId, string.format("%s. %s", LANG.getRow("CMD_WONG_SYNTAX"), LANG.getRow("CMD_MUTE_USAGE")))
        else
            CORE.mute(args[1], args[2], args[3])
        end
        CORE.reloadPlayersCache()
    end
    CMD.registerChatCmd("OnChatCmd_mute_handler", "mute", "Mute player")
    
    -- Events
    
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
        local res = CORE.checkPlayerOnAuth(playerName, isGuest)
        if res ~= nil then
            return res
        end
    end
    MP.RegisterEvent("onPlayerAuth", "OnPlayerAuthHandler")
    
    function OnPlayerConnectingHandler(playerId)
        local playerName = MP.GetPlayerName(playerId)
        local user = CORE.getUserByName(playerName)
        local userId = nil
        if user.id ~= nil then
            userId = user.id
        end
        CORE.startUserSession(playerName, userId)
    end
    MP.RegisterEvent("onPlayerConnecting", "OnPlayerConnectingHandler")
    
    function OnPlayerJoiningHandler(playerId)
        CORE.reloadPlayersCache()
    end
    MP.RegisterEvent("onPlayerJoining", "OnPlayerJoiningHandler")
    
    function OnPlayerDisconnectHandler(playerId)
        local playerName = MP.GetPlayerName(playerId)
        local user = CORE.getUserByName(playerName)
        local userId = nil
        if user.id ~= nil then
            userId = user.id
        end
        CORE.endUserSession(playerName, userId)
    end
    MP.RegisterEvent("onPlayerDisconnect", "OnPlayerDisconnectHandler")
    
    function OnShutdownHandler()
        CORE.endUserSession(nil, nil)
    end
    MP.RegisterEvent("onShutdown", "OnShutdownHandler")

end