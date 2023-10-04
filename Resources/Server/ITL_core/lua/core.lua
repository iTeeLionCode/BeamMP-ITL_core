local MODULE = {}

function MODULE.getUserByName(playerName)
    local dbRes = MYSQL.execute("read", "SELECT * FROM users WHERE player_name = '%s'", {playerName})
    local users = MYSQL.fetchAll(dbRes)

    if #users > 0 then
        return users[1]
    end

    return nil
end

function MODULE.reloadPlayersCache()
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
        local sql = "SELECT blockings.id, blockings.server_id, blockings.user_id, blockings.type, blockings.cancel_at, blockings.reason, users.player_name FROM blockings JOIN users ON blockings.user_id = users.id WHERE blockings.server_id = '"..pluginConfig.server_id.."' AND type = 'mute' AND blockings.cancel_at > '%s' AND users.player_name IN ("..playerNames..")"
        local dbRes = MYSQL.execute("read", sql, {now})
        blockings = MYSQL.fetchAll(dbRes)
    end
    if blockings ~= nil then
        for key, item in pairs(blockings) do
            playersCache[item.playerName]["mute"] = {id = item.id, cancel_at = item.cancel_at, reason = item.reason}
        end
    end
end

function MODULE.startUserSession(playerName, userId)
    local playerIdent = MP.GetPlayerIdentifiers(UTILS.getPlayerIdByName(playerName))
    local now = os.date("%Y-%m-%d %H:%M:%S")

    if playerName ~= nil then
        if userId ~= nil then
            MYSQL.execute("write", "INSERT INTO users_stats (server_id, user_id, player_name, connect_date, ip) VALUES ('%s', '%s', '%s', '%s', '%s')", {pluginConfig.server_id, userId, playerName, now, playerIdent.ip})
        else
            MYSQL.execute("write", "INSERT INTO users_stats (server_id, player_name, connect_date, ip) VALUES ('%s', '%s', '%s', '%s')", {pluginConfig.server_id, playerName, now, playerIdent.ip})
        end
    end
end

function MODULE.endUserSession(playerName, userId)
    local now = os.date("%Y-%m-%d %H:%M:%S")
    if playerName ~= nil then
        MYSQL.execute("write", "UPDATE users_stats SET disconnect_date = '%s' WHERE server_id = '%s' AND player_name = '%s'", {now, pluginConfig.server_id, playerName})
    else
        local count = 0
        local players = MP.GetPlayers()
        if players ~= nil then
            for key, playerName in pairs(players) do
                count = count + 1
            end
        end
        if count == 0 then
            MYSQL.execute("write", "UPDATE users_stats SET disconnect_date = '%s' WHERE server_id = '%s' AND disconnect_date IS NULL", {now, pluginConfig.server_id})
        end
    end
end

function MODULE.kick(playerName, reason)
    local playerId = UTILS.getPlayerIdByName(playerName)
    if playerId ~= nil then
        MP.DropPlayer(playerId, reason)
    end
end

function MODULE.ban(playerName, reason, duration)
    local untilDate = os.date("%Y-%m-%d %H:%M:%S", UTILS.getFutureTimestamp(duration))

    kick(playerName, reason)

    local user = getUserByName(playerName);
    if user ~= nil then
        MYSQL.execute("write", "INSERT INTO blockings (server_id, user_id, type, cancel_at, reason) VALUES ('%s', '%s', '%s', '%s', '%s')", {pluginConfig.server_id, user.id, "ban", untilDate, reason})
    else
        return "User not found in DB";
    end

    return true;
end

-- ToDo unban
function MODULE.unban(playerName)

end

function MODULE.mute(playerName, reason, duration)
    local untilDate = os.date("%Y-%m-%d %H:%M:%S", UTILS.getFutureTimestamp(duration))

    local user = getUserByName(playerName);
    if user ~= nil then
        MYSQL.execute("write", "INSERT INTO blockings (server_id, user_id, type, cancel_at, reason) VALUES ('%s', '%s', '%s', '%s', '%s')", {pluginConfig.server_id, user.id, "mute", untilDate, reason})
    else
        return "User not found in DB";
    end

    return true
end

-- ToDo unmute
function MODULE.unmute(playerName)

end

function MODULE.checkPlayerOnAuth(playerName, isGuest)
    local userId = nil

    if pluginConfig.guests_allowed ~= nil then
        if (pluginConfig.guests_allowed == false and isGuest == true) then
            print(string.format("User %s kicked because guests are not allowed!", playerName))
            return LANG.getRow("USER_GUEST_NOT_ALLOWED")
        end
    end

    local dbRes = MYSQL.execute("read", "SELECT id FROM users WHERE player_name = '%s'", {playerName})
    local users = MYSQL.fetchAll(dbRes)
    if #users > 0 then
        userId = users[1].id
        local now = os.date("%Y-%m-%d %H:%M:%S")
        local dbRes = MYSQL.execute("read", "SELECT id, user_id, cancel_at, reason FROM blockings WHERE type = 'ban' AND is_canceled = 0 AND server_id = '%s' AND user_id = '%s' AND cancel_at > '%s' ORDER BY id DESC", {pluginConfig.server_id, userId, now})
        local blockings = MYSQL.fetchAll(dbRes)
        if #blockings > 0 then
            print(string.format("User %s kicked because of ban %s: %s", playerName, blockings[1].id, blockings[1].reason))
            return string.format(LANG.getRow("YOU_ARE_BANNED_UNTIL_FOR_REASON"), blockings[1].cancel_at, blockings[1].reason)
        end
    else
        userId = MYSQL.execute("write", "INSERT INTO users (player_name) VALUES ('%s')", {playerName})
    end

    local defaultGroup = pluginConfig.default_group_id
    if userId ~= nil and defaultGroup ~= nil then
        local dbRes = MYSQL.execute("read", "SELECT id FROM users_groups WHERE server_id = '%s' AND user_id = '%s' AND group_id = '%s'", {pluginConfig.server_id, userId, pluginConfig.default_group_id})
        local usersgroups = MYSQL.fetchAll(dbRes)
        if #usersgroups <= 0 then
            MYSQL.execute("write", "INSERT INTO users_groups (server_id, user_id, group_id) VALUES ('%s', '%s', '%s')", {pluginConfig.server_id, userId, pluginConfig.default_group_id})
        end
    end

    -- ToDo: ban by previous ip

    return nil
end

return MODULE