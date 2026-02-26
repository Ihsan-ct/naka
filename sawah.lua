-- =========================================================
-- 🌾 NAKA AUTO FARM — SAWAH INDO v3.0 ULTIMATE
-- Data 100% akurat dari CropConfig + LahanBesar + TutorialConfig
-- NPC: NPC_Bibit, NPC_Penjual, NPC_Alat, NPC_PedagangSawit
-- Area: AreaTanam (biasa) | AreaTanamBesar (Sawit/Durian)
-- PREMIUM FEATURES: Auto-Claim, Smart Sell, Multiple Modes, Anti-Ban
-- =========================================================

if game:IsLoaded() == false then game.Loaded:Wait() end

-- ============================
-- LOAD RAYFIELD
-- ============================
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- ============================
-- SERVICES
-- ============================
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS         = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LP   = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local Hum  = Char:WaitForChild("Humanoid")
local Root = Char:WaitForChild("HumanoidRootPart")

-- ============================
-- VARIABEL GLOBAL
-- ============================
local isAlive = true
local currentPlaceId = game.PlaceId
local gameName = "Sawah Indo"

-- ============================
-- CHARACTER HANDLER
-- ============================
local function updateChar(c)
    Char = c
    Hum = c:WaitForChild("Humanoid")
    Root = c:WaitForChild("HumanoidRootPart")
    isAlive = true
    
    -- Auto restart farm kalau lagi running
    if stat and stat.running then
        task.wait(2)
        stat.running = false
        task.wait(0.5)
        stat.running = true
        stat.farmThread = task.spawn(farmLoop)
    end
    
    if Rayfield and Rayfield.Notify then
        pcall(function()
            Rayfield:Notify({
                Title = "🔄 Respawn Detected",
                Content = "Character respawn - auto adjust!",
                Duration = 3
            })
        end)
    end
end

LP.CharacterAdded:Connect(updateChar)
LP.CharacterRemoving:Connect(function() isAlive = false end)

-- ============================
-- GAME CONFIG (dari decompile)
-- ============================

-- Tanaman biasa — ditanam di AreaTanam
local CROPS_BIASA = {
    { key="Bibit Padi",       icon="🌾", buyPrice=5,    minLevel=1,   growMin=50,  growMax=60,   harvestItem="Padi",       enabled=true,  sellPrice=10 },
    { key="Bibit Jagung",     icon="🌽", buyPrice=15,   minLevel=20,  growMin=80,  growMax=100,  harvestItem="Jagung",     enabled=true,  sellPrice=30 },
    { key="Bibit Tomat",      icon="🍅", buyPrice=25,   minLevel=40,  growMin=120, growMax=150,  harvestItem="Tomat",      enabled=true,  sellPrice=50 },
    { key="Bibit Terong",     icon="🍆", buyPrice=40,   minLevel=60,  growMin=150, growMax=200,  harvestItem="Terong",     enabled=true,  sellPrice=80 },
    { key="Bibit Strawberry", icon="🍓", buyPrice=60,   minLevel=80,  growMin=180, growMax=250,  harvestItem="Strawberry", enabled=true,  sellPrice=120 },
}

-- Tanaman lahan besar — ditanam di AreaTanamBesar (prefix + index)
-- MaxPerPlayer=1, MaxCropsPerType=1, MaxTotalCrops=2
local CROPS_BESAR = {
    { key="Bibit Sawit",  icon="🌴", buyPrice=1000, minLevel=80,  growMin=600, growMax=1000, harvestItem="Sawit",  fruitType="Sawit",  enabled=true,  sellPrice=500 },
    { key="Bibit Durian", icon="🍈", buyPrice=2000, minLevel=120, growMin=800, growMax=1200, harvestItem="Durian", fruitType="Durian", enabled=true,  sellPrice=1000 },
}

-- NPC targets (persis dari WorldConfig & TutorialConfig)
local NPC = {
    bibit   = "NPC_Bibit",          -- Pak Tani (beli bibit)
    penjual = "NPC_Penjual",        -- Pedagang (jual hasil panen biasa)
    alat    = "NPC_Alat",           -- Toko Alat
    sawit   = "NPC_PedagangSawit",  -- Pedagang Sawit
    pupuk   = "NPC_Pupuk",          -- Kalau ada
}

-- Area tanam (persis dari WorldConfig & LahanBesarConfig)
local AREA = {
    tanam      = "AreaTanam",       -- area tanam biasa
    tanamBesar = "AreaTanamBesar",  -- prefix area lahan besar (28 area: AreaTanamBesar1..28)
    totalBesar = 28,
}

-- ============================
-- REMOTE SCANNER
-- ============================

-- Tunggu folder Remotes siap
local RemotesFolder = RS:WaitForChild("Remotes", 5) or RS

local function findRE(...)
    for _, name in ipairs({...}) do
        local r = RS:FindFirstChild(name, true)
        if r and r:IsA("RemoteEvent") then return r end
        r = workspace:FindFirstChild(name, true)
        if r and r:IsA("RemoteEvent") then return r end
    end
    return nil
end

local function findRemoteFolder(...)
    for _, name in ipairs({...}) do
        local f = RS:FindFirstChild(name, true)
        if f then return f end
    end
    return nil
end

-- Hardcode path yang sudah diketahui
local TutRemotes = findRemoteFolder("TutorialRemotes","GameRemotes","Remotes","FarmingRemotes")

local RE_Plant   = RS:FindFirstChild("PlantCrop",   true)
                or findRE("PlantSeed","Plant","Tanam","TanamBibit","PlantCrop","PlantSeed","PlantItem")

local RE_Harvest = RS:FindFirstChild("HarvestCrop", true)
                or findRE("HarvestAll","Harvest","Panen","PanenSemua","HarvestCrop","HarvestPlant")

-- Scan semua RemoteEvent di RS
local allRemotes = {}
local function scanAllRemotes()
    for _, obj in ipairs(RS:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            allRemotes[obj.Name] = obj
            print("[AUTOFARM SCAN] RemoteEvent: " .. obj:GetFullName())
        end
    end
    return allRemotes
end

scanAllRemotes()

-- Cari Buy & Sell dari hasil scan
local RE_Buy, RE_Sell, RE_Claim, RE_Craft

for name, remote in pairs(allRemotes) do
    local lower = name:lower()
    if lower:find("buy") or lower:find("beli") or lower:find("purchase") or lower:find("shop") then
        if not RE_Buy then RE_Buy = remote end
    end
    if lower:find("sell") or lower:find("jual") then
        if not RE_Sell then RE_Sell = remote end
    end
    if lower:find("claim") or lower:find("beli") and lower:find("lahan") then
        if not RE_Claim then RE_Claim = remote end
    end
    if lower:find("craft") or lower:find("upgrade") or lower:find("buat") then
        if not RE_Craft then RE_Craft = remote end
    end
end

-- Fallback manual
if not RE_Buy  then RE_Buy  = findRE("BuyItem","BuySeed","BeliItem","BeliBibit","Buy","PurchaseItem","ShopBuy","NPCBuy","BuyCrop","BuySeedItem") end
if not RE_Sell then RE_Sell = findRE("SellItem","SellAll","JualItem","Sell","SellCrops","SellHarvest","NPCSell","SellCrop","SellHarvestItem") end
if not RE_Claim then RE_Claim = findRE("ClaimLand","BeliLahan","PurchaseLand","BuyLand","ClaimArea") end
if not RE_Craft then RE_Craft = findRE("Craft","Upgrade","BuatAlat","CraftItem","UpgradeTool") end

print("[AUTOFARM ULTIMATE] Remote Events:")
print("  Plant   = " .. (RE_Plant   and RE_Plant:GetFullName()   or "❌ not found"))
print("  Harvest = " .. (RE_Harvest and RE_Harvest:GetFullName() or "❌ not found"))
print("  Buy     = " .. (RE_Buy     and RE_Buy:GetFullName()     or "❌ not found"))
print("  Sell    = " .. (RE_Sell    and RE_Sell:GetFullName()    or "❌ not found"))
print("  Claim   = " .. (RE_Claim   and RE_Claim:GetFullName()   or "❌ not found"))
print("  Craft   = " .. (RE_Craft   and RE_Craft:GetFullName()   or "❌ not found"))

-- ============================
-- HELPER: FIND NPC
-- ============================
local NPC_CACHE = {}
local function getNPCPos(npcName)
    if NPC_CACHE[npcName] and NPC_CACHE[npcName].pos then
        return NPC_CACHE[npcName].pos
    end
    
    -- Cari di workspace langsung dulu
    local found = workspace:FindFirstChild(npcName, true)
    if not found then
        local folder = workspace:FindFirstChild("NPCs") or workspace:FindFirstChild("NPC")
        if folder then found = folder:FindFirstChild(npcName, true) end
    end
    if not found then return nil end

    if found:IsA("Model") then
        local rp = found:FindFirstChild("HumanoidRootPart")
            or found:FindFirstChild("Head")
            or found:FindFirstChildWhichIsA("BasePart")
        if rp then 
            NPC_CACHE[npcName] = {obj = found, pos = rp.Position}
            return rp.Position 
        end
    elseif found:IsA("BasePart") then
        NPC_CACHE[npcName] = {obj = found, pos = found.Position}
        return found.Position
    end
    return nil
end

local function getNPCObj(npcName)
    if NPC_CACHE[npcName] and NPC_CACHE[npcName].obj then
        return NPC_CACHE[npcName].obj
    end
    
    local found = workspace:FindFirstChild(npcName, true)
    if not found then
        local folder = workspace:FindFirstChild("NPCs") or workspace:FindFirstChild("NPC")
        if folder then found = folder:FindFirstChild(npcName, true) end
    end
    
    if found then
        NPC_CACHE[npcName] = {obj = found, pos = found:IsA("Model") and (found:FindFirstChild("HumanoidRootPart") or found:FindFirstChild("Head") or found:FindFirstChildWhichIsA("BasePart")).Position or found.Position}
    end
    return found
end

-- ============================
-- HELPER: FIND AREA TANAM
-- ============================
local AREA_CACHE = {biasa = {}, besar = {}}
local lastAreaScan = 0

local function refreshAreaCache()
    if tick() - lastAreaScan < 10 then return end
    lastAreaScan = tick()
    
    -- Reset cache
    AREA_CACHE.biasa = {}
    AREA_CACHE.besar = {}
    
    -- Cari AreaTanam
    local area = workspace:FindFirstChild(AREA.tanam, true)
    if area then
        if area:IsA("Folder") or area:IsA("Model") then
            for _, v in ipairs(area:GetDescendants()) do
                if v:IsA("BasePart") then
                    table.insert(AREA_CACHE.biasa, v)
                end
            end
        elseif area:IsA("BasePart") then
            table.insert(AREA_CACHE.biasa, area)
        end
    end
    
    -- Cari AreaTanamBesar
    for i = 1, AREA.totalBesar do
        local area = workspace:FindFirstChild(AREA.tanamBesar .. tostring(i), true)
        if area then
            if area:IsA("BasePart") then
                table.insert(AREA_CACHE.besar, area)
            elseif area:IsA("Model") or area:IsA("Folder") then
                for _, v in ipairs(area:GetDescendants()) do
                    if v:IsA("BasePart") then
                        table.insert(AREA_CACHE.besar, v)
                    end
                end
            end
        end
    end
end

local function getAreaTanamParts()
    refreshAreaCache()
    return AREA_CACHE.biasa
end

local function getAreaBesarParts()
    refreshAreaCache()
    return AREA_CACHE.besar
end

-- ============================
-- HELPER: PLAYER DATA
-- ============================
local DATA_CACHE = {coins = 0, level = 0, seeds = {}, harvest = {}}
local lastDataScan = 0

local function getVal(names)
    for _, n in ipairs(names) do
        -- Cek leaderstats
        local ls = LP:FindFirstChild("leaderstats")
        if ls then
            local v = ls:FindFirstChild(n)
            if v then return tonumber(v.Value) or 0 end
        end
        -- Cek PlayerData / Data
        for _, folder in ipairs({"PlayerData","Data","Stats","Inventory","Seeds","Items","Currency"}) do
            local f = LP:FindFirstChild(folder)
            if f then
                local v = f:FindFirstChild(n, true)
                if v then return tonumber(v.Value) or 0 end
            end
        end
        -- Cek attribute
        local attr = LP:GetAttribute(n)
        if attr then return tonumber(attr) or 0 end
    end
    return 0
end

local function getCoins()   return getVal({"Coins","coins","Gold","Money","Uang","Rupiah"}) end
local function getLevel()   return getVal({"Level","level","Lv","XP_Level","PetaniLevel"}) end
local function getXP()      return getVal({"XP","Exp","Experience","Pengalaman"}) end

local function getSeedCount(seedKey)
    local noSpace = seedKey:gsub(" ","")
    return getVal({seedKey, noSpace, "Seed_"..noSpace, "Bibit"..noSpace})
end

local function getHarvestCount(itemName)
    return getVal({itemName, "Item_"..itemName, "Hasil_"..itemName})
end

-- ============================
-- TELEPORT
-- ============================
local function tpTo(pos, offset)
    if not (Root and Root.Parent and isAlive) then return end
    offset = offset or Vector3.new(0, 5, 0)
    Root.CFrame = CFrame.new(pos + offset)
    task.wait(0.2)
end

local function safeTP(pos)
    if not cfg.useTP then return end
    pcall(function() tpTo(pos) end)
end

-- ============================
-- PROXIMITY PROMPT TRIGGER
-- ============================
local function firePrompt(obj, actionFilter)
    if not obj then return false end
    
    -- Coba di obj langsung
    for _, pp in ipairs(obj:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local match = not actionFilter
                or (pp.ActionText and pp.ActionText:lower():find(actionFilter:lower()))
                or (pp.ObjectText and pp.ObjectText:lower():find(actionFilter:lower()))
            if match then
                pcall(function()
                    local pps = game:GetService("ProximityPromptService")
                    pps:PromptTriggered(pp, LP)
                    pp.Triggered:Fire(LP)
                    pp.Triggered:Fire(LP, 0)
                end)
                task.wait(0.1)
                return true
            end
        end
    end
    
    -- Coba di parent (kalau obj adalah part)
    if obj.Parent then
        for _, pp in ipairs(obj.Parent:GetDescendants()) do
            if pp:IsA("ProximityPrompt") then
                pcall(function() pp.Triggered:Fire(LP) end)
                return true
            end
        end
    end
    
    return false
end

-- ============================
-- CLICK DETECTOR
-- ============================
local function fireClick(obj)
    if not obj then return false end
    for _, cd in ipairs(obj:GetDescendants()) do
        if cd:IsA("ClickDetector") then
            pcall(function() 
                cd.MouseClick:Fire(LP)
                cd.MouseHoverEnter:Fire(LP)
                cd.MouseHoverLeave:Fire(LP)
            end)
            return true
        end
    end
    return false
end

-- ============================
-- INVENTORY TRACKER
-- ============================
local Inventory = {
    seeds = {},
    harvest = {},
    tools = {},
    lastUpdate = 0
}

local function updateInventory()
    if tick() - Inventory.lastUpdate < 2 then return Inventory end
    Inventory.lastUpdate = tick()
    
    -- Reset
    for k in pairs(Inventory.seeds) do Inventory.seeds[k] = 0 end
    for k in pairs(Inventory.harvest) do Inventory.harvest[k] = 0 end
    for k in pairs(Inventory.tools) do Inventory.tools[k] = 0 end
    
    -- Scan backpack
    for _, tool in ipairs(LP.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            Inventory.tools[tool.Name] = (Inventory.tools[tool.Name] or 0) + 1
        end
    end
    
    -- Scan character
    if Char then
        for _, tool in ipairs(Char:GetChildren()) do
            if tool:IsA("Tool") then
                Inventory.tools[tool.Name] = (Inventory.tools[tool.Name] or 0) + 1
            end
        end
    end
    
    -- Scan seeds dari data
    for _, crop in ipairs(CROPS_BIASA) do
        local count = getSeedCount(crop.key)
        if count > 0 then
            Inventory.seeds[crop.key] = count
        end
    end
    for _, crop in ipairs(CROPS_BESAR) do
        local count = getSeedCount(crop.key)
        if count > 0 then
            Inventory.seeds[crop.key] = count
        end
    end
    
    -- Scan harvest dari data
    for _, crop in ipairs(CROPS_BIASA) do
        local count = getHarvestCount(crop.harvestItem)
        if count > 0 then
            Inventory.harvest[crop.harvestItem] = count
        end
    end
    for _, crop in ipairs(CROPS_BESAR) do
        local count = getHarvestCount(crop.harvestItem)
        if count > 0 then
            Inventory.harvest[crop.harvestItem] = count
        end
    end
    
    return Inventory
end

-- ============================
-- CONFIG & STATE
-- ============================
local cfg = {
    -- Core toggles
    autoHarvest = true,
    autoPlant   = true,
    autoBuy     = true,
    autoSell    = false,
    autoClaim   = true,
    autoCraft   = false,
    
    -- Settings
    loopEnabled = true,
    antiAFK     = true,
    notifLvlUp  = true,
    useTP       = true,
    randomDelay = true,
    humanize    = true,
    
    -- Timing
    loopDelay   = 3,
    actDelay    = 0.4,
    buyAmt      = 50,
    sellThreshold = 100,
    
    -- Mode
    farmMode    = "⚡ Cepat (Prioritas Panen)",
    
    -- Anti-ban
    maxErrors   = 5,
    errorCount  = 0,
    lastAction  = 0,
    
    -- Priority
    priorityCrops = {"Bibit Sawit", "Bibit Durian", "Bibit Strawberry", "Bibit Tomat"}
}

local stat = {
    running    = false,
    action     = "⏹ Standby",
    harvested  = 0,
    planted    = 0,
    coinsGain  = 0,
    startTime  = 0,
    farmThread = nil,
    afkThread  = nil,
    lastLv     = 0,
    lastCoins  = 0,
    totalProfit = 0,
    errorCount = 0,
}

-- Label refs
local L = {}
local function upUI()
    local e = os.time() - stat.startTime
    local profit = stat.coinsGain
    
    pcall(function() 
        if L.status then L.status:Set("◦  Status    :  " .. (stat.running and "🟢 BERJALAN" or "🔴 BERHENTI")) end
        if L.action then L.action:Set("◦  Aksi      :  " .. stat.action) end
        if L.harvest then L.harvest:Set("◦  Dipanen   :  " .. stat.harvested) end
        if L.planted then L.planted:Set("◦  Ditanam   :  " .. stat.planted) end
        if L.coins then L.coins:Set("◦  Profit    :  Rp" .. stat.coinsGain) end
        if L.durasi then L.durasi:Set("◦  Durasi    :  " .. math.floor(e/60) .. "m " .. e%60 .. "s") end
        if L.level then 
            local lv = getLevel()
            L.level:Set("◦  Level     :  " .. lv .. (stat.lastLv > 0 and "  [+" .. (lv-stat.lastLv) .. "]" or ""))
        end
    end)
end

-- ============================
-- RANDOM DELAY (HUMANIZE)
-- ============================
local function waitHuman(min, max)
    if not cfg.humanize then 
        task.wait(min)
        return
    end
    local delay = min + math.random() * (max - min)
    task.wait(delay)
end

local function doAction(name, func)
    if not stat.running then return end
    
    stat.action = name
    upUI()
    
    local success, err = pcall(func)
    if not success then
        stat.errorCount = stat.errorCount + 1
        print("[ERROR] " .. name .. ": " .. tostring(err))
        
        if stat.errorCount >= cfg.maxErrors then
            stat.running = false
            Rayfield:Notify({
                Title = "⚠️ Terlalu Banyak Error",
                Content = "Auto farm dihentikan",
                Duration = 5
            })
        end
    end
    
    if cfg.randomDelay then
        waitHuman(cfg.actDelay * 0.8, cfg.actDelay * 1.2)
    else
        task.wait(cfg.actDelay)
    end
end

-- ============================
-- CORE: BELI BIBIT
-- ============================
local function tryFindBuyRemote()
    if RE_Buy then return RE_Buy end
    
    for _, obj in ipairs(RS:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local lower = obj.Name:lower()
            if lower:find("buy") or lower:find("beli") or lower:find("shop") or lower:find("purchase") then
                RE_Buy = obj
                print("[AUTOFARM] RE_Buy ditemukan: " .. obj:GetFullName())
                return RE_Buy
            end
        end
    end
    return nil
end

local function buySeeds(crop)
    if not cfg.autoBuy then return end
    
    local buyRemote = tryFindBuyRemote()
    if not buyRemote then
        print("[AUTOFARM] RE_Buy tidak ada — skip beli " .. crop.key)
        return
    end
    
    doAction("🛒 Beli " .. crop.icon .. " " .. crop.key, function()
        -- Teleport ke NPC_Bibit
        local pos = getNPCPos(NPC.bibit)
        if pos then safeTP(pos) end
        
        -- Coba semua format parameter
        local argsList = {
            {crop.key, cfg.buyAmt},
            {item = crop.key, amount = cfg.buyAmt},
            {crop.key},
            {Seed = crop.key, Quantity = cfg.buyAmt},
            {Name = crop.key, Count = cfg.buyAmt}
        }
        
        for _, args in ipairs(argsList) do
            pcall(function() buyRemote:FireServer(unpack(args)) end)
            task.wait(0.1)
        end
        
        -- Fallback ProximityPrompt
        local npcObj = getNPCObj(NPC.bibit)
        if npcObj then
            firePrompt(npcObj, "Beli")
            fireClick(npcObj)
        end
    end)
end

-- ============================
-- CORE: PANEN
-- ============================
local function doHarvest()
    if not cfg.autoHarvest then return end
    
    doAction("🌾 Panen...", function()
        -- Metode 1: FireServer tanpa args (HarvestAll)
        if RE_Harvest then
            pcall(function() RE_Harvest:FireServer() end)
            pcall(function() RE_Harvest:FireServer("All") end)
            pcall(function() RE_Harvest:FireServer(LP) end)
        end
        
        -- Metode 2: Scan & panen satu per satu
        local function scanAndHarvest(parts)
            for _, part in ipairs(parts) do
                if not stat.running then break end
                
                -- Cek apakah matang
                local matang = part:GetAttribute("Matang")
                    or part:GetAttribute("Ready")
                    or part:GetAttribute("Ripe")
                    or part:GetAttribute("CanHarvest")
                    or (part:GetAttribute("Phase") and part:GetAttribute("Phase") >= 3)
                    or (part:GetAttribute("GrowPhase") and part:GetAttribute("GrowPhase") >= 3)
                    or (part:GetAttribute("Growth") and part:GetAttribute("Growth") >= 100)
                
                if not matang then
                    local mdl = part.Parent
                    if mdl and mdl:IsA("Model") then
                        matang = mdl:GetAttribute("Matang") or mdl:GetAttribute("Ready")
                            or mdl:GetAttribute("Ripe") or mdl:GetAttribute("CanHarvest")
                    end
                end
                
                if matang then
                    -- Cek owner
                    local owner = part:GetAttribute("Owner")
                        or (part.Parent and part.Parent:IsA("Model") and part.Parent:GetAttribute("Owner"))
                    local isMine = (owner == nil)
                        or (tostring(owner) == tostring(LP.UserId))
                        or (tostring(owner) == LP.Name)
                    
                    if isMine then
                        -- TP ke tanaman
                        if cfg.useTP and Root and (Root.Position - part.Position).Magnitude > 8 then
                            tpTo(part.Position, Vector3.new(0, 2, 0))
                        end
                        
                        -- Fire harvest dengan berbagai format
                        if RE_Harvest then
                            pcall(function() RE_Harvest:FireServer(part) end)
                            pcall(function() RE_Harvest:FireServer(part.Parent) end)
                            pcall(function() RE_Harvest:FireServer(part, LP) end)
                        end
                        
                        -- ProximityPrompt & ClickDetector
                        local target = part.Parent and part.Parent:IsA("Model") and part.Parent or part
                        firePrompt(target, "Panen")
                        firePrompt(target, "Harvest")
                        fireClick(target)
                        
                        stat.harvested = stat.harvested + 1
                        
                        if cfg.randomDelay then
                            waitHuman(0.2, 0.6)
                        else
                            task.wait(0.3)
                        end
                    end
                end
            end
        end
        
        scanAndHarvest(getAreaTanamParts())
        scanAndHarvest(getAreaBesarParts())
    end)
end

-- ============================
-- CORE: TANAM BIBIT BIASA
-- ============================
local function plantBiasa(crop)
    if not crop.enabled or not cfg.autoPlant then return end
    
    local lv = getLevel()
    if lv < crop.minLevel then return end
    
    -- Cek bibit
    local seedCount = getSeedCount(crop.key)
    if seedCount <= 0 then
        if cfg.autoBuy then
            buySeeds(crop)
            seedCount = getSeedCount(crop.key)
        end
        if seedCount <= 0 then return end
    end
    
    doAction("🌱 Tanam " .. crop.icon .. " " .. crop.key, function()
        -- Equip seed tool jika ada
        local tool = LP.Backpack:FindFirstChild(crop.key)
            or LP.Backpack:FindFirstChild(crop.key:gsub(" ",""))
            or LP.Backpack:FindFirstChild("Bibit" .. crop.key:gsub("Bibit",""):gsub(" ",""))
        
        if tool and Hum then
            pcall(function() Hum:EquipTool(tool) end)
            task.wait(0.3)
        end
        
        -- Fire Plant remote
        if RE_Plant then
            pcall(function() RE_Plant:FireServer(crop.key) end)
            pcall(function() RE_Plant:FireServer({seed = crop.key}) end)
        end
        
        -- TP ke AreaTanam & tanam
        local areaParts = getAreaTanamParts()
        for _, part in ipairs(areaParts) do
            if not stat.running then break end
            if getSeedCount(crop.key) <= 0 then break end
            
            -- Cek apakah plot kosong
            local isEmpty = (part:GetAttribute("SeedType") == nil)
                and (part:GetAttribute("PlantType") == nil)
                and (part:GetAttribute("Occupied") ~= true)
                and (part:GetAttribute("Matang") == nil)
                and (part:GetAttribute("Owner") == nil or tostring(part:GetAttribute("Owner")) == tostring(LP.UserId))
            
            if isEmpty then
                if cfg.useTP and Root and (Root.Position - part.Position).Magnitude > 8 then
                    tpTo(part.Position, Vector3.new(0, 2, 0))
                end
                
                -- Coba semua metode tanam
                if RE_Plant then
                    pcall(function() RE_Plant:FireServer(crop.key, part) end)
                    pcall(function() RE_Plant:FireServer(part, crop.key) end)
                    pcall(function() RE_Plant:FireServer({seed = crop.key, plot = part}) end)
                end
                
                fireClick(part)
                firePrompt(part, "Tanam")
                firePrompt(part, "Plant")
                
                stat.planted = stat.planted + 1
                
                if cfg.randomDelay then
                    waitHuman(0.2, 0.5)
                else
                    task.wait(0.3)
                end
            end
        end
        
        -- Unequip
        if Hum and Char then
            pcall(function()
                local equipped = Char:FindFirstChildOfClass("Tool")
                if equipped then Hum:UnequipTools() end
            end)
        end
    end)
end

-- ============================
-- CORE: TANAM SAWIT / DURIAN
-- ============================
local function plantBesar(crop)
    if not crop.enabled or not cfg.autoPlant then return end
    
    local lv = getLevel()
    if lv < crop.minLevel then return end
    
    local seedCount = getSeedCount(crop.key)
    if seedCount <= 0 then
        if cfg.autoBuy then
            buySeeds(crop)
            seedCount = getSeedCount(crop.key)
        end
        if seedCount <= 0 then return end
    end
    
    doAction("🌴 Tanam " .. crop.icon .. " " .. crop.key, function()
        -- Equip tool
        local tool = LP.Backpack:FindFirstChild(crop.key)
            or LP.Backpack:FindFirstChild(crop.key:gsub(" ",""))
        
        if tool and Hum then
            pcall(function() Hum:EquipTool(tool) end)
            task.wait(0.3)
        end
        
        if RE_Plant then
            pcall(function() RE_Plant:FireServer(crop.key) end)
        end
        
        -- Scan AreaTanamBesar yang milik kita & kosong
        local besarParts = getAreaBesarParts()
        for _, part in ipairs(besarParts) do
            if not stat.running then break end
            if getSeedCount(crop.key) <= 0 then break end
            
            local owner = part:GetAttribute("Owner")
            local isMine = (owner == nil) 
                or (tostring(owner) == tostring(LP.UserId))
                or (tostring(owner) == LP.Name)
            
            local isEmpty = (part:GetAttribute("SeedType") == nil)
                and (part:GetAttribute("PlantType") == nil)
                and (part:GetAttribute("Occupied") ~= true)
            
            if isMine and isEmpty then
                if cfg.useTP and Root and (Root.Position - part.Position).Magnitude > 8 then
                    tpTo(part.Position, Vector3.new(0, 2, 0))
                end
                
                if RE_Plant then
                    pcall(function() RE_Plant:FireServer(crop.key, part) end)
                    pcall(function() RE_Plant:FireServer(part, crop.key) end)
                end
                
                fireClick(part)
                firePrompt(part, "Tanam")
                
                stat.planted = stat.planted + 1
                task.wait(cfg.actDelay)
            end
        end
        
        if Hum then pcall(function() Hum:UnequipTools() end) end
    end)
end

-- ============================
-- CORE: JUAL HASIL PANEN
-- ============================
local function doSell()
    if not cfg.autoSell then return end
    
    doAction("💰 Jual...", function()
        updateInventory()
        
        -- Jual ke NPC_Penjual
        local pos = getNPCPos(NPC.penjual)
        if pos then
            safeTP(pos)
        end
        
        if RE_Sell then
            pcall(function() RE_Sell:FireServer() end)
            pcall(function() RE_Sell:FireServer("All") end)
            pcall(function() RE_Sell:FireServer(LP) end)
            pcall(function() RE_Sell:FireServer({all = true}) end)
        end
        
        local npcObj = getNPCObj(NPC.penjual)
        if npcObj then
            firePrompt(npcObj, "Jual")
            fireClick(npcObj)
        end
        
        -- Jual ke NPC_PedagangSawit
        local sawitPos = getNPCPos(NPC.sawit)
        if sawitPos then
            safeTP(sawitPos)
            if RE_Sell then
                pcall(function() RE_Sell:FireServer("Sawit") end)
                pcall(function() RE_Sell:FireServer({item = "Sawit"}) end)
            end
            local sawitObj = getNPCObj(NPC.sawit)
            if sawitObj then 
                firePrompt(sawitObj, "Jual")
                fireClick(sawitObj)
            end
        end
    end)
end

-- ============================
-- AUTO-CLAIM LAHAN BESAR
-- ============================
local function claimLahanBesar()
    if not cfg.autoClaim then return end
    
    doAction("🏕 Claim Lahan...", function()
        local besarParts = getAreaBesarParts()
        local myLahan = 0
        
        -- Hitung lahan yang udah jadi milik kita
        for _, part in ipairs(besarParts) do
            local owner = part:GetAttribute("Owner")
            if owner and (tostring(owner) == tostring(LP.UserId) or tostring(owner) == LP.Name) then
                myLahan = myLahan + 1
            end
        end
        
        -- Kalau masih kurang dari 2, coba claim
        if myLahan < 2 then
            for _, part in ipairs(besarParts) do
                if myLahan >= 2 then break end
                if not stat.running then break end
                
                local owner = part:GetAttribute("Owner")
                if not owner or owner == "" then
                    -- Lahan kosong, coba claim
                    if cfg.useTP then safeTP(part.Position) end
                    
                    -- Fire claim remote
                    if RE_Claim then
                        pcall(function() RE_Claim:FireServer(part) end)
                        pcall(function() RE_Claim:FireServer({land = part}) end)
                        pcall(function() RE_Claim:FireServer() end)
                    end
                    
                    fireClick(part)
                    firePrompt(part, "Beli")
                    firePrompt(part, "Claim")
                    
                    myLahan = myLahan + 1
                    task.wait(cfg.actDelay)
                end
            end
        end
    end)
end

-- ============================
-- AUTO-CRAFT/UPGRADE
-- ============================
local function autoCraft()
    if not cfg.autoCraft then return end
    
    doAction("🔧 Craft...", function()
        local npcAlat = getNPCPos(NPC.alat)
        if npcAlat then
            safeTP(npcAlat)
            
            if RE_Craft then
                pcall(function() RE_Craft:FireServer("Sabit", 1) end)
                pcall(function() RE_Craft:FireServer({item = "Sabit", tier = 1}) end)
                pcall(function() RE_Craft:FireServer("Cangkul", 1) end)
            end
            
            firePrompt(getNPCObj(NPC.alat), "Upgrade")
            firePrompt(getNPCObj(NPC.alat), "Craft")
        end
    end)
end

-- ============================
-- SMART SELL (Threshold)
-- ============================
local function smartSell()
    if not cfg.autoSell then return end
    
    updateInventory()
    local totalItems = 0
    for _, v in pairs(Inventory.harvest) do
        totalItems = totalItems + v
    end
    
    -- Jual kalau inventory penuh atau mencapai threshold
    if totalItems >= cfg.sellThreshold then
        doSell()
    end
end

-- ============================
-- FARM MODES
-- ============================
local FarmModes = {
    ["⚡ Cepat (Prioritas Panen)"] = function()
        doHarvest()
        waitHuman(0.5, 1)
        if cfg.autoPlant then
            for _, crop in ipairs(CROPS_BESAR) do 
                if crop.enabled then plantBesar(crop) end
            end
            for _, crop in ipairs(CROPS_BIASA) do 
                if crop.enabled then plantBiasa(crop) end
            end
        end
    end,
    
    ["🌱 Fokus Tanam"] = function()
        for i = 1, 3 do
            if not stat.running then break end
            for _, crop in ipairs(CROPS_BESAR) do 
                if crop.enabled then plantBesar(crop) end
            end
            for _, crop in ipairs(CROPS_BIASA) do 
                if crop.enabled then plantBiasa(crop) end
            end
            waitHuman(0.3, 0.7)
        end
        doHarvest()
    end,
    
    ["💰 Fokus Profit"] = function()
        doHarvest()
        doSell()
        -- Tanam yang paling mahal dulu
        local priority = {"Bibit Durian", "Bibit Sawit", "Bibit Strawberry", "Bibit Tomat"}
        for _, cropName in ipairs(priority) do
            for _, crop in ipairs(CROPS_BESAR) do
                if crop.key == cropName and crop.enabled then
                    plantBesar(crop)
                end
            end
            for _, crop in ipairs(CROPS_BIASA) do
                if crop.key == cropName and crop.enabled then
                    plantBiasa(crop)
                end
            end
        end
        -- Sisanya
        for _, crop in ipairs(CROPS_BESAR) do 
            if crop.enabled then plantBesar(crop) end
        end
        for _, crop in ipairs(CROPS_BIASA) do 
            if crop.enabled then plantBiasa(crop) end
        end
    end,
    
    ["🤖 Auto Pilot (Smart)"] = function()
        updateInventory()
        local coins = getCoins()
        local level = getLevel()
        
        -- Decision making based on current state
        if coins < 1000 then
            -- Kalo miskin, fokus panen & jual
            doHarvest()
            doSell()
        elseif level < 80 then
            -- Kalo masih rendah level, fokus tanam yang cepet panen
            doHarvest()
            for _, crop in ipairs(CROPS_BIASA) do
                if crop.enabled and crop.minLevel <= level then
                    plantBiasa(crop)
                end
            end
        else
            -- Kalo udah high level, fokus profit
            doHarvest()
            doSell()
            for _, crop in ipairs(CROPS_BESAR) do
                if crop.enabled then plantBesar(crop) end
            end
        end
    end
}

-- ============================
-- FARM LOOP
-- ============================
local function farmLoop()
    stat.startTime = os.time()
    stat.lastLv = getLevel()
    stat.lastCoins = getCoins()
    stat.errorCount = 0
    
    Rayfield:Notify({
        Title = "🌾 Auto Farm Aktif!",
        Content = "Mode: " .. cfg.farmMode,
        Duration = 4
    })
    
    while stat.running and isAlive do
        -- Auto-claim lahan
        if cfg.autoClaim then
            pcall(claimLahanBesar)
        end
        
        -- Auto-craft (periodik)
        if cfg.autoCraft and math.random(1, 10) == 1 then
            pcall(autoCraft)
        end
        
        -- Jalanin mode yang dipilih
        if FarmModes[cfg.farmMode] then
            pcall(FarmModes[cfg.farmMode])
        else
            -- Fallback
            pcall(doHarvest)
            if cfg.autoSell then pcall(smartSell) end
            if cfg.autoPlant then
                for _, crop in ipairs(CROPS_BIASA) do 
                    if crop.enabled then pcall(plantBiasa, crop) end
                end
                for _, crop in ipairs(CROPS_BESAR) do 
                    if crop.enabled then pcall(plantBesar, crop) end
                end
            end
        end
        
        -- Update coins tracker
        local curCoins = getCoins()
        if curCoins > stat.lastCoins then
            local gain = curCoins - stat.lastCoins
            stat.coinsGain = stat.coinsGain + gain
            stat.totalProfit = stat.totalProfit + gain
        end
        stat.lastCoins = curCoins
        
        -- Update level
        local curLv = getLevel()
        if curLv > stat.lastLv and cfg.notifLvlUp then
            Rayfield:Notify({
                Title = "⭐ NAIK LEVEL!",
                Content = "Level " .. stat.lastLv .. " → " .. curLv .. "!",
                Duration = 5
            })
        end
        stat.lastLv = curLv
        
        upUI()
        
        -- Tunggu sebelum loop berikutnya
        if stat.running then
            stat.action = "⏳ Tunggu " .. cfg.loopDelay .. "s..."
            upUI()
            
            local w = 0
            while w < cfg.loopDelay and stat.running and isAlive do
                task.wait(0.5)
                w = w + 0.5
            end
        end
    end
    
    stat.action = "⏹ Dihentikan"
    stat.running = false
    upUI()
    
    Rayfield:Notify({
        Title = "⏹ Auto Farm Stop",
        Content = "Panen: " .. stat.harvested .. " | Tanam: " .. stat.planted .. " | Profit: Rp" .. stat.coinsGain,
        Duration = 5
    })
end

local function startFarm()
    if stat.running then 
        Rayfield:Notify({Title = "⚠️ Sudah Berjalan", Content = "Auto farm sudah aktif", Duration = 3})
        return 
    end
    
    stat.running = true
    stat.errorCount = 0
    upUI()
    
    if stat.farmThread then
        pcall(task.cancel, stat.farmThread)
    end
    stat.farmThread = task.spawn(farmLoop)
end

local function stopFarm()
    stat.running = false
    if stat.farmThread then 
        pcall(task.cancel, stat.farmThread)
        stat.farmThread = nil 
    end
    stat.action = "⏹ Dihentikan"
    upUI()
end

-- ============================
-- ANTI-AFK & ANTI-BAN
-- ============================
local function startAFK()
    if stat.afkThread then return end
    
    stat.afkThread = task.spawn(function()
        while true do
            task.wait(60)
            if not isAlive then continue end
            
            -- Anti-AFK
            if cfg.antiAFK and Root and Root.Parent then
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                    
                    -- Random movement kecil
                    if math.random(1, 3) == 1 then
                        local cf = Root.CFrame
                        Root.CFrame = cf * CFrame.new(math.random(-2,2), 0, math.random(-2,2))
                        task.wait(0.2)
                        Root.CFrame = cf
                    end
                end)
            end
            
            -- Refresh cache
            pcall(function()
                refreshAreaCache()
                updateInventory()
            end)
        end
    end)
end

-- Level up watcher
task.spawn(function()
    while true do
        task.wait(5)
        if cfg.notifLvlUp and isAlive then
            local lv = getLevel()
            if stat.lastLv > 0 and lv > stat.lastLv then
                Rayfield:Notify({
                    Title = "⭐ NAIK LEVEL!",
                    Content = "Level " .. stat.lastLv .. " → " .. lv .. "!",
                    Duration = 5
                })
            end
            stat.lastLv = lv
        end
    end
end)

-- UI update timer
task.spawn(function()
    while true do
        task.wait(2)
        if stat.running and isAlive then 
            pcall(upUI) 
        end
    end
end)

-- ============================
-- RAYFIELD UI
-- ============================
local Win = Rayfield:CreateWindow({
    Name = "🌾 NAKA AUTO FARM ULTIMATE",
    LoadingTitle = "🌾 N A K A  U L T I M A T E",
    LoadingSubtitle = "[ Sawah Indo • v3.0 • Premium Features ]",
    ConfigurationSaving = { Enabled = true, FolderName = "NAKA", FileName = "AutoFarm_Ultimate" },
    Discord = { Enabled = false },
    KeySystem = false,
})

Rayfield:LoadConfiguration()

Rayfield:Notify({
    Title = "🌾 NAKA Auto Farm Ultimate",
    Content = "Premium features activated!\nMode: " .. cfg.farmMode,
    Duration = 5
})

-- ── TAB 1: FARM ─────────────────────────────────────────
local T1 = Win:CreateTab("🌾 Farm", "4483362458")

T1:CreateSection("◈ Status Real-Time")
L.status = T1:CreateLabel("◦ Status    :  🔴 BERHENTI")
L.action = T1:CreateLabel("◦ Aksi      :  ⏹ Standby")
L.harvest = T1:CreateLabel("◦ Dipanen   :  0")
L.planted = T1:CreateLabel("◦ Ditanam   :  0")
L.coins = T1:CreateLabel("◦ Profit    :  Rp0")
L.durasi = T1:CreateLabel("◦ Durasi    :  0m 0s")
L.level = T1:CreateLabel("◦ Level     :  0")

T1:CreateSection("◈ Kontrol Utama")
T1:CreateButton({ 
    Name = "▶ Mulai Auto Farm", 
    Callback = startFarm 
})

T1:CreateButton({ 
    Name = "⏹ Stop Auto Farm", 
    Callback = stopFarm 
})

T1:CreateDropdown({
    Name = "🎯 Mode Farming",
    Options = {"⚡ Cepat (Prioritas Panen)", "🌱 Fokus Tanam", "💰 Fokus Profit", "🤖 Auto Pilot (Smart)"},
    CurrentOption = cfg.farmMode,
    Callback = function(opt) 
        cfg.farmMode = opt 
        Rayfield:Notify({
            Title = "Mode Diganti",
            Content = "Sekarang: " .. opt,
            Duration = 3
        })
    end
})

T1:CreateToggle({ 
    Name = "🔁 Loop Otomatis", 
    CurrentValue = cfg.loopEnabled,
    Callback = function(v) cfg.loopEnabled = v end 
})

T1:CreateToggle({ 
    Name = "📍 Teleport Mode", 
    CurrentValue = cfg.useTP,
    Callback = function(v) cfg.useTP = v end 
})

T1:CreateToggle({ 
    Name = "🎭 Humanize (Random Delay)", 
    CurrentValue = cfg.humanize,
    Callback = function(v) cfg.humanize = v end 
})

T1:CreateSection("◈ Aksi Manual")
T1:CreateButton({ 
    Name = "🌾 Panen Sekarang",
    Callback = function() task.spawn(doHarvest) end 
})

T1:CreateButton({ 
    Name = "🌱 Tanam Sekarang",
    Callback = function()
        task.spawn(function()
            for _, c in ipairs(CROPS_BIASA) do 
                if c.enabled then pcall(plantBiasa, c) end
            end
            for _, c in ipairs(CROPS_BESAR) do 
                if c.enabled then pcall(plantBesar, c) end
            end
        end)
    end 
})

T1:CreateButton({ 
    Name = "💰 Jual Sekarang",
    Callback = function() task.spawn(doSell) end 
})

T1:CreateButton({ 
    Name = "🏕 Claim Lahan Sekarang",
    Callback = function() task.spawn(claimLahanBesar) end 
})

-- ── TAB 2: TANAMAN ─────────────────────────────────────
local T2 = Win:CreateTab("🌱 Tanaman", "4483362458")

T2:CreateSection("◈ Tanaman Biasa (AreaTanam)")
for _, c in ipairs(CROPS_BIASA) do
    local crop = c
    T2:CreateToggle({
        Name = crop.icon .. " " .. crop.key .. " [Lv." .. crop.minLevel .. "]",
        CurrentValue = crop.enabled,
        Callback = function(v) crop.enabled = v end
    })
end

T2:CreateSection("◈ Lahan Besar (AreaTanamBesar)")
T2:CreateLabel("◦ Sawit & Durian butuh lahan sendiri")
T2:CreateLabel("◦ MaxPerPlayer: 1 lahan, MaxCrops: 2")

for _, c in ipairs(CROPS_BESAR) do
    local crop = c
    T2:CreateToggle({
        Name = crop.icon .. " " .. crop.key .. " [Lv." .. crop.minLevel .. "]",
        CurrentValue = crop.enabled,
        Callback = function(v) crop.enabled = v end
    })
end

T2:CreateSection("◈ Fitur Auto")
T2:CreateToggle({ 
    Name = "🌾 Auto Panen", 
    CurrentValue = cfg.autoHarvest,
    Callback = function(v) cfg.autoHarvest = v end 
})

T2:CreateToggle({ 
    Name = "🌱 Auto Tanam", 
    CurrentValue = cfg.autoPlant,
    Callback = function(v) cfg.autoPlant = v end 
})

T2:CreateToggle({ 
    Name = "🛒 Auto Beli Bibit", 
    CurrentValue = cfg.autoBuy,
    Callback = function(v) cfg.autoBuy = v end 
})

T2:CreateToggle({ 
    Name = "💰 Auto Jual (Smart)", 
    CurrentValue = cfg.autoSell,
    Callback = function(v) cfg.autoSell = v end 
})

T2:CreateToggle({ 
    Name = "🏕 Auto-Claim Lahan Besar", 
    CurrentValue = cfg.autoClaim,
    Callback = function(v) cfg.autoClaim = v end 
})

T2:CreateToggle({ 
    Name = "🔧 Auto-Craft/Upgrade", 
    CurrentValue = cfg.autoCraft,
    Callback = function(v) cfg.autoCraft = v end 
})

-- ── TAB 3: SETTINGS ────────────────────────────────────
local T3 = Win:CreateTab("⚙ Settings", "4483362458")

T3:CreateSection("◈ Timing")
T3:CreateSlider({ 
    Name = "⏱ Delay Aksi (detik)", 
    Range = {0.1, 2}, 
    Increment = 0.1, 
    CurrentValue = cfg.actDelay,
    Callback = function(v) cfg.actDelay = v end 
})

T3:CreateSlider({ 
    Name = "🔁 Delay Loop (detik)", 
    Range = {1, 30}, 
    Increment = 1, 
    CurrentValue = cfg.loopDelay,
    Callback = function(v) cfg.loopDelay = v end 
})

T3:CreateSlider({ 
    Name = "🛒 Jumlah Beli Bibit", 
    Range = {10, 500}, 
    Increment = 10, 
    CurrentValue = cfg.buyAmt,
    Callback = function(v) cfg.buyAmt = v end 
})

T3:CreateSlider({ 
    Name = "📦 Threshold Auto Jual", 
    Range = {50, 1000}, 
    Increment = 10, 
    CurrentValue = cfg.sellThreshold,
    Callback = function(v) cfg.sellThreshold = v end 
})

T3:CreateSection("◈ Sistem")
T3:CreateToggle({ 
    Name = "⭐ Notif Level Up", 
    CurrentValue = cfg.notifLvlUp,
    Callback = function(v) cfg.notifLvlUp = v end 
})

T3:CreateToggle({ 
    Name = "🛡 Anti-AFK", 
    CurrentValue = cfg.antiAFK,
    Callback = function(v) cfg.antiAFK = v end 
})

T3:CreateToggle({ 
    Name = "⚠️ Random Delay (Anti-Ban)", 
    CurrentValue = cfg.randomDelay,
    Callback = function(v) cfg.randomDelay = v end 
})

T3:CreateSection("◈ Priority Crops")
T3:CreateLabel("Urutan prioritas untuk mode Fokus Profit:")
for i, cropName in ipairs(cfg.priorityCrops) do
    T3:CreateLabel(i .. ". " .. cropName)
end

-- ── TAB 4: DEBUG ───────────────────────────────────────
local T4 = Win:CreateTab("🔍 Debug", "4483362458")

T4:CreateSection("◈ Remote Events")
T4:CreateButton({ 
    Name = "🔍 Cek Remote Events", 
    Callback = function()
        local info = {
            { "Plant", RE_Plant },
            { "Harvest", RE_Harvest },
            { "Buy", RE_Buy },
            { "Sell", RE_Sell },
            { "Claim", RE_Claim },
            { "Craft", RE_Craft },
        }
        for _, v in ipairs(info) do
            Rayfield:Notify({
                Title = "RE_" .. v[1],
                Content = v[2] and ("✅ " .. v[2]:GetFullName()) or "❌ Tidak ditemukan",
                Duration = 3
            })
            task.wait(0.4)
        end
    end 
})

T4:CreateButton({ 
    Name = "📋 Scan SEMUA RemoteEvent", 
    Callback = function()
        local count = 0
        for _, obj in ipairs(RS:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                count = count + 1
                print("[SCAN] " .. obj:GetFullName())
            end
        end
        Rayfield:Notify({
            Title = "📋 Scan Selesai",
            Content = "Ditemukan " .. count .. " RemoteEvent\nLihat di Console (F9)!",
            Duration = 5
        })
    end 
})

T4:CreateSection("◈ NPC & Area")
T4:CreateButton({ 
    Name = "📍 Cek NPC Positions", 
    Callback = function()
        for k, name in pairs(NPC) do
            local pos = getNPCPos(name)
            Rayfield:Notify({
                Title = name,
                Content = pos and ("✅ " .. math.floor(pos.X) .. ", " .. math.floor(pos.Y) .. ", " .. math.floor(pos.Z))
                    or "❌ Tidak ditemukan",
                Duration = 3
            })
            task.wait(0.4)
        end
    end 
})

T4:CreateButton({ 
    Name = "🌾 Cek Area Tanam", 
    Callback = function()
        refreshAreaCache()
        Rayfield:Notify({
            Title = "Area Tanam",
            Content = "AreaTanam: " .. #AREA_CACHE.biasa .. " parts\nAreaTanamBesar: " .. #AREA_CACHE.besar .. " parts",
            Duration = 4
        })
    end 
})

T4:CreateButton({ 
    Name = "📦 Cek Inventory", 
    Callback = function()
        updateInventory()
        local msg = "Seeds:\n"
        for k, v in pairs(Inventory.seeds) do
            msg = msg .. "  " .. k .. ": " .. v .. "\n"
        end
        msg = msg .. "Harvest:\n"
        for k, v in pairs(Inventory.harvest) do
            msg = msg .. "  " .. k .. ": " .. v .. "\n"
        end
        Rayfield:Notify({
            Title = "Inventory",
            Content = msg,
            Duration = 5
        })
    end 
})

T4:CreateSection("◈ Stats")
T4:CreateButton({ 
    Name = "📊 Tampilkan Statistik", 
    Callback = function()
        Rayfield:Notify({
            Title = "📊 Statistik Farming",
            Content = string.format(
                "Dipanen: %d\nDitanam: %d\nProfit: Rp%d\nDurasi: %d menit",
                stat.harvested, stat.planted, stat.coinsGain, 
                math.floor((os.time() - stat.startTime) / 60)
            ),
            Duration = 5
        })
    end 
})

T4:CreateButton({ 
    Name = "🔄 Reset Statistik", 
    Callback = function()
        stat.harvested = 0
        stat.planted = 0
        stat.coinsGain = 0
        stat.startTime = os.time()
        upUI()
        Rayfield:Notify({
            Title = "✅ Reset",
            Content = "Statistik telah direset",
            Duration = 3
        })
    end 
})

-- ── TAB 5: INFO ────────────────────────────────────────
local T5 = Win:CreateTab("📋 Info", "4483362458")

T5:CreateSection("◈ Cara Pakai")
T5:CreateLabel("1️⃣ Pastikan sudah selesai tutorial dulu!")
T5:CreateLabel("2️⃣ Tab 🌱 Tanaman — pilih crop sesuai level")
T5:CreateLabel("3️⃣ Tab ⚙ Settings — atur delay & threshold")
T5:CreateLabel("4️⃣ Pilih mode farming di tab 🌾 Farm")
T5:CreateLabel("5️⃣ Klik ▶ Mulai Auto Farm")

T5:CreateSection("◈ Data dari Game Config")
T5:CreateLabel("🌾 Padi       Lv.1   | 50-60s   | Jual: Rp10")
T5:CreateLabel("🌽 Jagung     Lv.20  | 80-100s  | Jual: Rp30")
T5:CreateLabel("🍅 Tomat      Lv.40  | 120-150s | Jual: Rp50")
T5:CreateLabel("🍆 Terong     Lv.60  | 150-200s | Jual: Rp80")
T5:CreateLabel("🍓 Strawberry Lv.80  | 180-250s | Jual: Rp120")
T5:CreateLabel("🌴 Sawit      Lv.80  | 600-1000s| Jual: Rp500")
T5:CreateLabel("🍈 Durian     Lv.120 | 800-1200s| Jual: Rp1000")

T5:CreateSection("◈ NPC Targets")
T5:CreateLabel("🛒 Beli Bibit   → NPC_Bibit")
T5:CreateLabel("💰 Jual Panen   → NPC_Penjual")
T5:CreateLabel("🌴 Jual Sawit   → NPC_PedagangSawit")
T5:CreateLabel("🔨 Toko Alat    → NPC_Alat")

T5:CreateSection("◈ Premium Features")
T5:CreateLabel("✅ Auto-Claim Lahan Besar")
T5:CreateLabel("✅ Smart Sell dengan Threshold")
T5:CreateLabel("✅ 4 Mode Farming (termasuk Auto Pilot)")
T5:CreateLabel("✅ Humanize & Random Delay")
T5:CreateLabel("✅ Inventory Tracker")
T5:CreateLabel("✅ Anti-AFK & Anti-Ban")
T5:CreateLabel("✅ Auto-Craft (experimental)")

T5:CreateSection("◈ Tentang")
T5:CreateLabel("🌾 NAKA Auto Farm Ultimate v3.0")
T5:CreateLabel("◦ Game  : Sawah Indo")
T5:CreateLabel("◦ Creator: cvAI4 (by gigs & xyren)")
T5:CreateLabel("◦ Update : " .. os.date("%d %B %Y"))

-- ============================
-- INITIALIZATION
-- ============================
startAFK()
refreshAreaCache()
updateInventory()

print([[

╔══════════════════════════════════════════╗
║    🌾 NAKA AUTO FARM ULTIMATE v3.0       ║
║    ====================================   ║
║    Game     : Sawah Indo                  ║
║    Status   : LOADED                      ║
║    Features : 25+ Premium Features        ║
║    Mode     : " .. cfg.farmMode .. "      ║
║                                            ║
║    cvAI4 - by gigs & xyren                ║
╚══════════════════════════════════════════╝

]])

-- Notifikasi selamat datang
Rayfield:Notify({
    Title = "🌾 NAKA ULTIMATE READY",
    Content = "Premium features activated!\nHappy farming!",
    Duration = 5
})
