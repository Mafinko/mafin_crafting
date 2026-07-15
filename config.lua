Config = {}

Config.Locale = 'en' -- 'cs' | 'en'

Config.CraftingTime = 5000
Config.ProgressBar = true
Config.UseProp = true
Config.PropDistance = 3.5
Config.NotifyType = 'okok' -- 'ox' | 'okok' | 'esx'

Config.DiscordWebhook = 'here'

Config.UI = {
    title = 'CRAFTING',
    showCloseButton = true,
    showRecipeIcons = true,
    showHeaderMeta = true,
    panelWidth = 1380,
    cornerRadius = 22,
}

Config.XP = {
    enabled = true,
    notifyOnXP = true,
    showInUI = true,
}

Config.Workbenches = {
    [1] = {
        label = 'Crafting',
        prop = 'gr_prop_gr_bench_04b',
        coords = vector4(870.5234, -2312.4065, 29.5704, 176.1024),
        targetLabel = nil,
        targetIcon = 'fas fa-gun',

        jobs = {
            -- { name = 'police', grade = 0 },
        },

        recipes = {
            {
                name = 'Armour',
                description = 'Requires: 175x money',
                result_icon = 'armour',
                time = 7500,
                requiredXP = 0,
                xpReward = 0.25,
                requireditems = {
                    { name = 'money', amount = 175, remove = true },
                },
                additems = {
                    { name = 'armour', amount = 1 },
                },
            },
            {
                name = 'Revolver',
                description = 'Requires: 68x steel, 160x scrap, 110x iron, 75x metal',
                result_icon = 'weapon_revolver',
                time = 5000,
                requiredXP = 0,
                xpReward = 0.5,
                requireditems = {
                    { name = 'steel', amount = 68, remove = true },
                    { name = 'scrap', amount = 160, remove = true },
                    { name = 'iron', amount = 110, remove = true },
                    { name = 'metal', amount = 75, remove = true },
                },
                additems = {
                    { name = 'weapon_revolver', amount = 1 },
                },
            },
            {
                name = 'Machine Pistol',
                description = 'Requires: 96x steel, 160x scrap, 72x iron, 90x metal',
                result_icon = 'weapon_machinepistol',
                time = 5000,
                requiredXP = 0,
                xpReward = 0.5,
                requireditems = {
                    { name = 'steel', amount = 96, remove = true },
                    { name = 'scrap', amount = 160, remove = true },
                    { name = 'iron', amount = 72, remove = true },
                    { name = 'metal', amount = 90, remove = true },
                },
                additems = {
                    { name = 'weapon_machinepistol', amount = 1 },
                },
            },
            {
                name = 'AP Pistol',
                description = 'Requires: 50x steel, 170x scrap, 55x iron, 45x metal',
                result_icon = 'weapon_appistol',
                time = 5000,
                requiredXP = 1,
                xpReward = 0.75,
                requireditems = {
                    { name = 'steel', amount = 50, remove = true },
                    { name = 'scrap', amount = 170, remove = true },
                    { name = 'iron', amount = 55, remove = true },
                    { name = 'metal', amount = 45, remove = true },
                },
                additems = {
                    { name = 'WEAPON_APPISTOL', amount = 1 },
                },
            },
            {
                name = 'Mini SMG',
                description = 'Requires: 75x steel, 100x scrap, 88x iron, 28x metal',
                result_icon = 'weapon_minismg',
                time = 5000,
                requiredXP = 1,
                xpReward = 1.0,
                requireditems = {
                    { name = 'steel', amount = 75, remove = true },
                    { name = 'scrap', amount = 100, remove = true },
                    { name = 'iron', amount = 88, remove = true },
                    { name = 'metal', amount = 28, remove = true },
                },
                additems = {
                    { name = 'weapon_minismg', amount = 1 },
                },
            },
            {
                name = 'Micro SMG',
                description = 'Requires: 65x steel, 135x scrap, 93x iron, 80x metal',
                result_icon = 'weapon_microsmg',
                time = 5000,
                requiredXP = 5,
                xpReward = 1.25,
                requireditems = {
                    { name = 'steel', amount = 65, remove = true },
                    { name = 'scrap', amount = 135, remove = true },
                    { name = 'iron', amount = 93, remove = true },
                    { name = 'metal', amount = 80, remove = true },
                },
                additems = {
                    { name = 'weapon_microsmg', amount = 1 },
                },
            },
        },
    },
}
