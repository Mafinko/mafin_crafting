local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
if not ESX then ESX = exports['es_extended']:getSharedObject() end
local spawnedProps = {}
local isUIOpen     = false
local currentBench = nil
local isCrafting   = false

local function Locale(key, ...)
    local lang = Config.Locales[Config.Locale] or Config.Locales.en or {}
    local str  = lang[key] or key
    if ... then return string.format(str, ...) end
    return str
end

local function Notify(msg, ntype)
    ntype = ntype or 'inform'
    if Config.NotifyType == 'ox' then
        lib.notify({ title = Config.UI.title or 'CRAFTING', description = msg, type = ntype })
    elseif Config.NotifyType == 'okok' then
        local t = ntype == 'inform' and 'info' or ntype
        exports['okokNotify']:Alert(Config.UI.title or 'CRAFTING', msg, 5000, t)
    else
        ESX.ShowNotification(msg)
    end
end

local function OpenFocus()
    SetNuiFocus(true, true)
end

local function ReleaseFocus()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end

local function SpawnProp(benchId, data)
    if not data.prop then return end
    local model = GetHashKey(data.prop)
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do
        Wait(100)
        timeout = timeout + 1
    end
    if not HasModelLoaded(model) then
        print('[mafin_crafting] Prop model not found: ' .. data.prop)
        return
    end
    local obj = CreateObjectNoOffset(model, data.coords.x, data.coords.y, data.coords.z, false, false, false)
    SetEntityHeading(obj, data.coords.w)
    SetEntityCollision(obj, true, true)
    FreezeEntityPosition(obj, true)
    PlaceObjectOnGroundProperly(obj)
    spawnedProps[benchId] = obj
    SetModelAsNoLongerNeeded(model)
end

local function RegisterTarget(benchId, data)
    local options = {{
        name     = 'mafin_crafting_' .. benchId,
        label    = data.targetLabel or Locale('open_bench'),
        icon     = data.targetIcon  or 'fas fa-hammer',
        distance = Config.PropDistance or 2.0,
        onSelect = function()
            TriggerEvent('mafin_crafting:openBench', benchId)
        end,
    }}

    if data.prop and spawnedProps[benchId] then
        exports.ox_target:addLocalEntity(spawnedProps[benchId], options)
    else
        exports.ox_target:addSphereZone({
            coords  = vec3(data.coords.x, data.coords.y, data.coords.z),
            radius  = Config.PropDistance or 2.0,
            name    = 'mafin_crafting_zone_' .. benchId,
            options = options,
            debug   = false,
        })
    end
end

CreateThread(function()
    for benchId, data in pairs(Config.Workbenches) do
        if Config.UseProp then SpawnProp(benchId, data) end
        RegisterTarget(benchId, data)
    end
end)

AddEventHandler('mafin_crafting:openBench', function(benchId)
    if isUIOpen then return end
    local bench = Config.Workbenches[benchId]
    if not bench then return end

    if bench.jobs and #bench.jobs > 0 then
        local playerJob = ESX.GetPlayerData().job
        local allowed   = false
        for _, j in ipairs(bench.jobs) do
            local grade = tonumber(playerJob.grade_index) or tonumber(playerJob.grade) or 0
            if playerJob.name == j.name and grade >= (j.grade or 0) then
                allowed = true; break
            end
        end
        if not allowed then
            Notify(Locale('no_job'), 'error')
            return
        end
    end

    TriggerServerEvent('mafin_crafting:requestBenchData', benchId)
end)

RegisterNetEvent('mafin_crafting:openUI', function(benchId, recipes, playerXP)
    if isUIOpen then return end
    isUIOpen     = true
    isCrafting   = false
    currentBench = benchId

    OpenFocus()
    SendNUIMessage({
        action    = 'open',
        bench     = Config.Workbenches[benchId],
        recipes   = recipes,
        locale    = Config.Locales[Config.Locale] or Config.Locales.en or {},
        ui        = Config.UI or {},
        playerXP  = playerXP or 0,
        xpEnabled = Config.XP.enabled,
        showXP    = Config.XP.showInUI,
    })
end)

local function CloseUI()
    if not isUIOpen then return end
    isUIOpen     = false
    isCrafting   = false
    currentBench = nil
    ReleaseFocus()
end

RegisterNUICallback('close', function(data, cb)
    CloseUI()
    cb('ok')
end)

RegisterNUICallback('craft', function(data, cb)
    if not currentBench or isCrafting then
        cb('error')
        return
    end
    isCrafting = true
    TriggerServerEvent('mafin_crafting:craft', currentBench, data.recipeIndex)
    cb('ok')
end)

RegisterNetEvent('mafin_crafting:craftResult', function(success, itemName, recipes, newXP)
    isCrafting = false
    if success then
        Notify(Locale('craft_success', itemName), 'success')
        if isUIOpen then
            SendNUIMessage({ action = 'refreshRecipes', recipes = recipes, playerXP = newXP })
        end
    else
        Notify(Locale('craft_failed'), 'error')
    end
    if isUIOpen then
        SendNUIMessage({ action = 'craftDone' })
    end
end)

RegisterNetEvent('mafin_crafting:missingItems', function()
    isCrafting = false
    Notify(Locale('missing_items'), 'error')
    if isUIOpen then SendNUIMessage({ action = 'craftDone' }) end
end)

RegisterNetEvent('mafin_crafting:noJob', function()
    isCrafting = false
    Notify(Locale('no_job'), 'error')
    if isUIOpen then CloseUI() end
end)
