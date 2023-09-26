local MODULE = {}

--MP.GetPlayerName(playerId)

function MODULE.getPlayerIdByName(playerName)
    local players = MP.GetPlayers()
    for id, name in pairs(players) do
        if name == playerName then
            return id
        end
    end
    return nil
end

function MODULE.getFutureTimestamp(duration)
    local sumInSeconds = 0

    local minutes = tonumber(string.match(duration, "([0-9]+)m"))
    if minutes ~= nil then 
        sumInSeconds = sumInSeconds + minutes * 60
    end

    local hours = tonumber(string.match(duration, "([0-9]+)h"))
    if hours ~= nil then 
        sumInSeconds = sumInSeconds + hours * 3600
    end

    local days = tonumber(string.match(duration, "([0-9]+)d"))
    if days ~= nil then 
        sumInSeconds = sumInSeconds + days * 86400
    end

    -- if formats not found interpret as minutes
    if sumInSeconds == 0 then
        minutes = tonumber(string.gsub(duration, "%D", ""))
        if minutes ~= nil then
            sumInSeconds = minutes * 60
        end
    end

    return os.time() + sumInSeconds
end

function MODULE.tabconcat(tab, separator)
    newTab = {}
    for _, v in pairs(tab) do
        table.insert(newTab, v)
    end
    return table.concat(newTab, separator)
end

return MODULE