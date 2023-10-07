-- Module require LUA mysql extension and ITL_CFG module!!!
-- (Debian example for mysql module install: apt-get install lua-sql-mysql)
local MODULE = {}

local SQL = require("luasql.mysql")
local env = SQL.mysql()
local config = nil

local function debug (variable)
    if config ~= nil and config.debug ~= nil and config.debug == true then
        print(variable)
    end
end

function MODULE.initModule(setConfig)
    config = setConfig
end

function MODULE.execute(direction, clause, args)
    local directionConfig = {}
    if direction == "write" then
        directionConfig = config.write
    else
        directionConfig = config.read
    end
    local conn = env:connect(directionConfig.name, directionConfig.user, directionConfig.pass, directionConfig.host, directionConfig.port)

    if #args > 0 then
        local escapedArgs = {}
        for index, arg in ipairs(args) do
            table.insert(escapedArgs, conn:escape(arg))
        end
        clause = string.format(clause, table.unpack(args))
    end

    debug(clause)

    local dbRes = nil
    local success, cursor = pcall(conn.execute, conn, clause)
    if success then
        if type(cursor) == "number" then
            dbRes = conn:getlastautoid()
        else
            dbRes = cursor
        end
    else
        print("MySQL error: ", cursor)
    end

    conn:close()
    return dbRes
end

function MODULE.fetchAll(dbRes)
    local rows = {}

    if dbRes == nil then
        return rows
    end

    local row = dbRes:fetch({}, "a")
    while row do
        table.insert(rows, row)
        row = dbRes:fetch({}, "a")
    end
    dbRes:close()
    return rows
end

return MODULE
