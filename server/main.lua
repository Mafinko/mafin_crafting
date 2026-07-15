local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
if not ESX then ESX = exports['es_extended']:getSharedObject() end

local XP_FILE = GetResourcePath(GetCurrentResourceName()) .. '/data/mafin_crafting_xp.json'
local xpDatabase = {}
local xpDirty = false
local craftCooldowns = {}
local openCooldowns = {}

local function Locale(key, ...)
    local lang = Config.Locales[Config.Locale] or Config.Locales.en or {}
    local str = lang[key] or key
    if ... then return string.format(str, ...) end
    return str
end

local function LoadXPDatabase()
    local f = io.open(XP_FILE, 'r')
    if f then
        local content = f:read('*a')
        f:close()
        if content and content ~= '' then
            local ok, decoded = pcall(json.decode, content)
            if ok and type(decoded) == 'table' then
                xpDatabase = decoded
                local count = 0
                for _ in pairs(xpDatabase) do count = count + 1 end
                print('[mafin_crafting] XP database loaded. Records: ' .. count)
            else
                print('[mafin_crafting] ERROR parsing XP database, starting empty.')
                xpDatabase = {}
            end
        end
    else
        xpDatabase = {}
        print('[mafin_crafting] XP database does not exist, it will be created after first craft.')
    end
end

local function SaveXPDatabase()
    if not xpDirty then return end

    local ok, encoded = pcall(json.encode, xpDatabase)
    if not ok then
        print('[mafin_crafting] ERROR json.encode: ' .. tostring(encoded))
        return
    end

    local f = io.open(XP_FILE, 'w')
    if f then
        f:write(encoded)
        f:close()
        xpDirty = false
        print('[mafin_crafting] XP database saved -> ' .. XP_FILE)
    else
        print('[mafin_crafting] ERROR: cannot write to ' .. XP_FILE)
    end
end

CreateThread(function()
    while true do
        Wait(60000)
        SaveXPDatabase()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        xpDirty = true
        SaveXPDatabase()
    end
end)

LoadXPDatabase()

local function GetPlayerXP(source)
    if not Config.XP.enabled then return math.huge end
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return 0 end
    local id = xPlayer.getIdentifier()
    return tonumber(xpDatabase[id]) or 0.0
end

local function SetPlayerXP(source, newXP)
    if not Config.XP.enabled then return end
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    local id = xPlayer.getIdentifier()
    xpDatabase[id] = math.max(0.0, newXP)
    xpDirty = true
end

local function AddPlayerXP(source, amount)
    if not Config.XP.enabled then return GetPlayerXP(source) end
    local newXP = GetPlayerXP(source) + amount
    SetPlayerXP(source, newXP)
    return newXP
end

local function IsOnCooldown(tbl, source, seconds)
    local now = os.time()
    local last = tbl[source]
    if last and (now - last) < seconds then return true end
    tbl[source] = now
    return false
end

local function Notify(source, msg, ntype)
    ntype = ntype or 'inform'
    if Config.NotifyType == 'ox' then
        TriggerClientEvent('ox_lib:notify', source, {
            title = Config.UI.title or 'CRAFTING',
            description = msg,
            type = ntype,
        })
    elseif Config.NotifyType == 'okok' then
        local t = ntype == 'inform' and 'info' or ntype
        exports['okokNotify']:Alert(Config.UI.title or 'CRAFTING', msg, 5000, t, source)
    else
        TriggerClientEvent('esx:showNotification', source, msg)
    end
end

local function SendDiscordLog(title, message, color)
    if not Config.DiscordWebhook or Config.DiscordWebhook == '' or Config.DiscordWebhook == 'here' then return end

    PerformHttpRequest(
        Config.DiscordWebhook,
        function() end,
        'POST',
        json.encode({
            username = 'Crafting Logs',
            embeds = {{
                color = color,
                title = '**' .. title .. '**',
                description = message,
                footer = { text = os.date('%d.%m.%Y | %H:%M:%S') },
            }},
        }),
        { ['Content-Type'] = 'application/json' }
    )
end

local function GetJobGrade(job)
    return tonumber(job.grade_index) or tonumber(job.grade) or 0
end

local function GetPlayerItemCount(source, itemName)
    local item = exports.ox_inventory:GetItem(source, itemName, nil, false)
    return item and item.count or 0
end

local function CheckJob(xPlayer, bench)
    if not bench.jobs or #bench.jobs == 0 then return true end
    local job = xPlayer.getJob()
    for _, j in ipairs(bench.jobs) do
        if job.name == j.name and GetJobGrade(job) >= (j.grade or 0) then
            return true
        end
    end
    return false
end

local function BuildRecipesWithCounts(source, benchId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end

    local bench = Config.Workbenches[benchId]
    local playerXP = GetPlayerXP(source)
    local out = {}

    for i, recipe in ipairs(bench.recipes) do
        local requiredXP = recipe.requiredXP or 0
        local hasXP = playerXP >= requiredXP

        local r = {
            index = i,
            name = recipe.name,
            description = recipe.description,
            result_icon = recipe.result_icon,
            time = recipe.time or Config.CraftingTime,
            additems = recipe.additems,
            xpReward = recipe.xpReward or 0,
            requiredXP = requiredXP,
            hasXP = hasXP,
            requireditems = {},
            canCraft = hasXP,
        }

        for _, req in ipairs(recipe.requireditems) do
            local have = GetPlayerItemCount(source, req.name)
            local ok = have >= req.amount
            if not ok then r.canCraft = false end
            table.insert(r.requireditems, {
                name = req.name,
                amount = req.amount,
                remove = req.remove,
                have = have,
                ok = ok,
            })
        end

        out[i] = r
    end

    return out
end

RegisterNetEvent('mafin_crafting:requestBenchData', function(benchId)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    if IsOnCooldown(openCooldowns, source, 2) then return end

    benchId = tonumber(benchId)
    if not benchId then return end

    local bench = Config.Workbenches[benchId]
    if not bench then return end

    if not CheckJob(xPlayer, bench) then
        Notify(source, Locale('no_job'), 'error')
        return
    end

    TriggerClientEvent('mafin_crafting:openUI', source, benchId, BuildRecipesWithCounts(source, benchId), GetPlayerXP(source))
end)

RegisterNetEvent('mafin_crafting:craft', function(benchId, recipeIndex)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    benchId = tonumber(benchId)
    recipeIndex = tonumber(recipeIndex)
    if not benchId or not recipeIndex then return end

    local bench = Config.Workbenches[benchId]
    if not bench or not bench.recipes[recipeIndex] then return end

    local recipe = bench.recipes[recipeIndex]
    if IsOnCooldown(craftCooldowns, source, 2) then return end

    if not CheckJob(xPlayer, bench) then
        TriggerClientEvent('mafin_crafting:noJob', source)
        return
    end

    local playerXP = GetPlayerXP(source)
    local requiredXP = recipe.requiredXP or 0
    if Config.XP.enabled and playerXP < requiredXP then
        Notify(source, Locale('xp_required', requiredXP, playerXP), 'error')
        TriggerClientEvent('mafin_crafting:missingItems', source)
        return
    end

    for _, req in ipairs(recipe.requireditems) do
        if GetPlayerItemCount(source, req.name) < req.amount then
            Notify(source, Locale('missing_items'), 'error')
            TriggerClientEvent('mafin_crafting:missingItems', source)
            return
        end
    end

    local usedStr = ''
    for _, req in ipairs(recipe.requireditems) do
        if req.remove ~= false then
            usedStr = usedStr .. string.format('- %dx %s\n', req.amount, req.name)
            exports.ox_inventory:RemoveItem(source, req.name, req.amount)
        end
    end

    local receivedStr = ''
    for _, add in ipairs(recipe.additems) do
        receivedStr = receivedStr .. string.format('- %dx %s\n', add.amount, add.name)
        exports.ox_inventory:AddItem(source, add.name, add.amount)
    end

    local xpReward = recipe.xpReward or 0
    local newXP = playerXP
    if Config.XP.enabled and xpReward > 0 then
        newXP = AddPlayerXP(source, xpReward)
        if Config.XP.notifyOnXP then
            Notify(source, Locale('xp_gained', xpReward, newXP), 'success')
        end
    end

    SendDiscordLog('Successful Craft', string.format(
        '**Player:** %s (%s)\n**Bench:** %s\n\n**Used:**\n%s\n**Received:**\n%s\n**XP:** +%.1f (total: %.1f)',
        xPlayer.getName(),
        xPlayer.getIdentifier(),
        bench.label or benchId,
        usedStr ~= '' and usedStr or 'None',
        receivedStr,
        xpReward,
        newXP
    ), 3066993)

    TriggerClientEvent('mafin_crafting:craftResult', source, true, recipe.name, BuildRecipesWithCounts(source, benchId), newXP)
end)

AddEventHandler('playerDropped', function()
    local source = source
    craftCooldowns[source] = nil
    openCooldowns[source] = nil
end)

RegisterCommand('xp_set', function(source, args)
    if source ~= 0 then
        print('[mafin_crafting] xp_set can only be used from the server console!')
        return
    end

    local target = tonumber(args[1])
    local amount = tonumber(args[2])
    if not target or not amount then
        print('Usage: xp_set <playerId> <amount>')
        return
    end

    SetPlayerXP(target, amount)
    print(string.format('[mafin_crafting] XP for player %d set to %.1f', target, amount))
end, true)

RegisterCommand('xp_add', function(source, args)
    if source ~= 0 then return end

    local target = tonumber(args[1])
    local amount = tonumber(args[2])
    if not target or not amount then
        print('Usage: xp_add <playerId> <amount>')
        return
    end

    local newXP = AddPlayerXP(target, amount)
    print(string.format('[mafin_crafting] Added %.1f XP to player %d (total: %.1f)', amount, target, newXP))
end, true)

RegisterCommand('xp_get', function(source, args)
    if source ~= 0 then return end

    local target = tonumber(args[1])
    if not target then
        print('Usage: xp_get <playerId>')
        return
    end

    print(string.format('[mafin_crafting] Player %d has %.1f XP', target, GetPlayerXP(target)))
end, true)
