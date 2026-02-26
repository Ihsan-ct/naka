-- =========================================================
-- 🌾 NAKA AUTO FARM — SAWAH INDO v3.0
-- Data 100% akurat dari CropConfig + LahanBesar + TutorialConfig
-- NPC: NPC_Bibit, NPC_Penjual, NPC_Alat, NPC_PedagangSawit
-- Area: AreaTanam (biasa) | AreaTanamBesar (Sawit/Durian)
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

local LP   = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local Hum  = Char:WaitForChild("Humanoid")
local Root = Char:WaitForChild("HumanoidRootPart")

LP.CharacterAdded:Connect(function(c)
    Char = c
    Hum  = c:WaitForChild("Humanoid")
    Root = c:WaitForChild("HumanoidRootPart")
end)

-- ============================
-- GAME CONFIG (dari decompile)
-- ============================

-- Tanaman biasa — ditanam di AreaTanam
local CROPS_BIASA = {
    { key="Bibit Padi",       icon="🌾", buyPrice=5,    minLevel=1,   growMin=50,  growMax=60,   harvestItem="Padi",       enabled=true },
    { key="Bibit Jagung",     icon="🌽", buyPrice=15,   minLevel=20,  growMin=80,  growMax=100,  harvestItem="Jagung",     enabled=true },
    { key="Bibit Tomat",      icon="🍅", buyPrice=25,   minLevel=40,  growMin=120, growMax=150,  harvestItem="Tomat",      enabled=true },
    { key="Bibit Terong",     icon="🍆", buyPrice=40,   minLevel=60,  growMin=150, growMax=200,  harvestItem="Terong",     enabled=true },
    { key="Bibit Strawberry", icon="🍓", buyPrice=60,   minLevel=80,  growMin=180, growMax=250,  harvestItem="Strawberry", enabled=true },
}

-- Tanaman lahan besar — ditanam di AreaTanamBesar (prefix + index)
-- MaxPerPlayer=1, MaxCropsPerType=1, MaxTotalCrops=2
local CROPS_BESAR = {
    { key="Bibit Sawit",  icon="🌴", buyPrice=1000, minLevel=80,  growMin=600, growMax=1000, harvestItem="Sawit",  fruitType="Sawit",  enabled=true },
    { key="Bibit Durian", icon="🍈", buyPrice=2000, minLevel=120, growMin=800, growMax=1200, harvestItem="Durian", fruitType="Durian", enabled=true },
}

-- NPC targets (persis dari WorldConfig & TutorialConfig)
local NPC = {
    bibit   = "NPC_Bibit",          -- Pak Tani (beli bibit)
    penjual = "NPC_Penjual",        -- Pedagang (jual hasil panen biasa)
    alat    = "NPC_Alat",           -- Toko Alat
    sawit   = "NPC_PedagangSawit",  -- Pedagang Sawit
}

-- Area tanam (persis dari WorldConfig & LahanBesarConfig)
local AREA = {
    tanam      = "AreaTanam",       -- area tanam biasa
    tanamBesar = "AreaTanamBesar",  -- prefix area lahan besar (28 area: AreaTanamBesar1..28)
    totalBesar = 28,
}

-- ============================
-- FIND REMOTES
-- ============================

-- Tunggu folder Remotes siap
local RemotesFolder = RS:WaitForChild("Remotes", 10)

local function findRE(...)
    for _, name in ipairs({...}) do
        -- Cari di seluruh RS secara rekursif
        local r = RS:FindFirstChild(name, true)
        if r and r:IsA("RemoteEvent") then return r end
        -- Cari di workspace
        r = workspace:FindFirstChild(name, true)
        if r and r:IsA("RemoteEvent") then return r end
    end
    return nil
end

-- ── REMOTE YANG SUDAH DIKETAHUI (dari screenshot) ──────────────────
-- RE_Plant   = ReplicatedStorage.Remotes.TutorialRemotes.PlantCrop  ✅
-- RE_Harvest = ReplicatedStorage.Remotes.TutorialRemotes.HarvestCrop ✅
-- RE_Buy     = ❌ belum ketemu — scan semua folder
-- RE_Sell    = ❌ belum ketemu — scan semua folder

-- Cari folder TutorialRemotes / GameRemotes / ShopRemotes dll
local function findRemoteFolder(...)
    for _, name in ipairs({...}) do
        local f = RS:FindFirstChild(name, true)
        if f then return f end
    end
    return nil
end

-- Hardcode path yang sudah diketahui
local TutRemotes = findRemoteFolder("TutorialRemotes","GameRemotes","Remotes")

local RE_Plant   = RS:FindFirstChild("PlantCrop",   true)
                or findRE("PlantSeed","Plant","Tanam","TanamBibit")

local RE_Harvest = RS:FindFirstChild("HarvestCrop", true)
                or findRE("HarvestAll","Harvest","Panen","PanenSemua")

-- Buy & Sell — cari di SEMUA subfolder Remotes
local RE_Buy, RE_Sell

-- Scan semua RemoteEvent di RS
local function scanAllRemotes()
    local all = {}
    for _, obj in ipairs(RS:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            all[obj.Name] = obj
            print("[AUTOFARM SCAN] RemoteEvent: " .. obj:GetFullName())
        end
    end
    return all
end

local allRemotes = scanAllRemotes()

-- Cari Buy dari hasil scan
for name, remote in pairs(allRemotes) do
    local lower = name:lower()
    if lower:find("buy") or lower:find("beli") or lower:find("purchase") or lower:find("shop") then
        if not RE_Buy then
            RE_Buy = remote
            print("[AUTOFARM] RE_Buy ditemukan: " .. remote:GetFullName())
        end
    end
    if lower:find("sell") or lower:find("jual") then
        if not RE_Sell then
            RE_Sell = remote
            print("[AUTOFARM] RE_Sell ditemukan: " .. remote:GetFullName())
        end
    end
end

-- Fallback manual
if not RE_Buy  then RE_Buy  = findRE("BuyItem","BuySeed","BeliItem","BeliBibit","Buy","PurchaseItem","ShopBuy","NPCBuy") end
if not RE_Sell then RE_Sell = findRE("SellItem","SellAll","JualItem","Sell","SellCrops","SellHarvest","NPCSell") end

print("[AUTOFARM v3] Remote Events:")
print("  Plant   = " .. (RE_Plant   and RE_Plant:GetFullName()   or "❌ not found"))
print("  Harvest = " .. (RE_Harvest and RE_Harvest:GetFullName() or "❌ not found"))
print("  Buy     = " .. (RE_Buy     and RE_Buy:GetFullName()     or "❌ not found"))
print("  Sell    = " .. (RE_Sell    and RE_Sell:GetFullName()    or "❌ not found"))

-- ============================
-- HELPER: FIND NPC
-- ============================
local function getNPCPos(npcName)
    -- Cari di workspace langsung dulu (nama persis)
    local found = workspace:FindFirstChild(npcName, true)
    if not found then
        -- Cari dalam folder NPCs
        local folder = workspace:FindFirstChild("NPCs")
        if folder then found = folder:FindFirstChild(npcName, true) end
    end
    if not found then return nil end

    if found:IsA("Model") then
        local rp = found:FindFirstChild("HumanoidRootPart")
            or found:FindFirstChildWhichIsA("BasePart")
        return rp and rp.Position
    elseif found:IsA("BasePart") then
        return found.Position
    end
    return nil
end

local function getNPCObj(npcName)
    local found = workspace:FindFirstChild(npcName, true)
    if not found then
        local folder = workspace:FindFirstChild("NPCs")
        if folder then found = folder:FindFirstChild(npcName, true) end
    end
    return found
end

-- ============================
-- HELPER: FIND AREA TANAM
-- ============================
local function getAreaTanamParts()
    -- Cari folder/model AreaTanam
    local parts = {}
    local area = workspace:FindFirstChild(AREA.tanam, true)
    if not area then return parts end

    if area:IsA("Folder") or area:IsA("Model") then
        for _, v in ipairs(area:GetDescendants()) do
            if v:IsA("BasePart") then
                table.insert(parts, v)
            end
        end
    elseif area:IsA("BasePart") then
        table.insert(parts, area)
    end
    return parts
end

local function getAreaBesarParts()
    -- Cari semua AreaTanamBesar1 .. AreaTanamBesar28
    local parts = {}
    for i = 1, AREA.totalBesar do
        local area = workspace:FindFirstChild(AREA.tanamBesar .. tostring(i), true)
        if area then
            if area:IsA("BasePart") then
                table.insert(parts, area)
            elseif area:IsA("Model") or area:IsA("Folder") then
                for _, v in ipairs(area:GetDescendants()) do
                    if v:IsA("BasePart") then table.insert(parts, v) end
                end
            end
        end
    end
    return parts
end

-- ============================
-- HELPER: PLAYER DATA
-- ============================
local function getVal(names)
    for _, n in ipairs(names) do
        -- Cek leaderstats
        local ls = LP:FindFirstChild("leaderstats")
        if ls then
            local v = ls:FindFirstChild(n)
            if v then return tonumber(v.Value) or 0 end
        end
        -- Cek PlayerData / Data
        for _, folder in ipairs({"PlayerData","Data","Stats","Inventory","Seeds","Items"}) do
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

local function getCoins()   return getVal({"Coins","coins","Gold","Money"}) end
local function getLevel()   return getVal({"Level","level","Lv","XP_Level"}) end

local function getSeedCount(seedKey)
    -- Nama di inventory mungkin tanpa spasi: "BibitPadi"
    local noSpace = seedKey:gsub(" ","")
    return getVal({seedKey, noSpace, "Seed_"..noSpace})
end

local function getHarvestCount(itemName)
    return getVal({itemName, "Item_"..itemName})
end

-- ============================
-- TELEPORT
-- ============================
local function tpTo(pos)
    if not (Root and Root.Parent) then return end
    Root.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
    task.wait(0.2)
end

-- ============================
-- PROXIMITY PROMPT TRIGGER
-- ============================
local function firePrompt(obj, actionFilter)
    if not obj then return false end
    local target = obj:IsA("Model") and obj or obj.Parent
    for _, pp in ipairs((obj:IsA("Model") and obj or obj.Parent):GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local match = not actionFilter
                or pp.ActionText:lower():find(actionFilter:lower())
                or pp.ObjectText:lower():find(actionFilter:lower())
            if match then
                pcall(function()
                    -- Metode paling reliable: fire HoldEnded → Triggered
                    local pps = game:GetService("ProximityPromptService")
                    pps:PromptTriggered(pp, LP)
                end)
                pcall(function() pp.Triggered:Fire(LP) end)
                return true
            end
        end
    end
    -- Coba cari di obj sendiri juga
    for _, pp in ipairs(obj:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            pcall(function() pp.Triggered:Fire(LP) end)
            return true
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
            pcall(function() cd.MouseClick:Fire(LP) end)
            return true
        end
    end
    return false
end

-- ============================
-- CONFIG & STATE
-- ============================
local cfg = {
    autoHarvest = true,
    autoPlant   = true,
    autoBuy     = true,
    autoSell    = false,
    loopEnabled = true,
    antiAFK     = true,
    notifLvlUp  = true,
    loopDelay   = 3,
    actDelay    = 0.4,
    buyAmt      = 50,
    useTP       = true,
}

local stat = {
    running    = false,
    action     = "⏹ Standby",
    harvested  = 0,
    planted    = 0,
    coinsGain  = 0,
    startTime  = os.time(),
    farmThread = nil,
    afkThread  = nil,
    lastLv     = 0,
    lastCoins  = 0,
}

-- Label refs
local L = {}
local function upUI()
    local e = os.time() - stat.startTime
    pcall(function() L.status:Set("◦  Status    :  " .. (stat.running and "🟢 BERJALAN" or "🔴 BERHENTI")) end)
    pcall(function() L.action:Set("◦  Aksi      :  " .. stat.action) end)
    pcall(function() L.harvest:Set("◦  Dipanen   :  " .. stat.harvested) end)
    pcall(function() L.planted:Set("◦  Ditanam   :  " .. stat.planted) end)
    pcall(function() L.coins:Set("◦  Coins +   :  " .. stat.coinsGain) end)
    pcall(function() L.durasi:Set("◦  Durasi    :  " .. math.floor(e/60) .. "m " .. e%60 .. "s") end)
end

-- ============================
-- CORE: BELI BIBIT
-- Jalan ke NPC_Bibit → fire RE_Buy(seedKey, amount)
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

    -- Coba cari RE_Buy jika belum ada — JANGAN blokir tanam
    local buyRemote = tryFindBuyRemote()
    if not buyRemote then
        -- Skip beli, lanjut proses tanam dengan bibit yang ada
        print("[AUTOFARM] RE_Buy tidak ada — skip beli " .. crop.key)
        return
    end

    stat.action = "🛒 Beli " .. crop.icon .. " " .. crop.key
    upUI()

    -- Teleport ke NPC_Bibit
    local pos = getNPCPos(NPC.bibit)
    if pos then tpTo(pos); task.wait(0.4) end

    -- Coba semua format parameter
    pcall(function() buyRemote:FireServer(crop.key, cfg.buyAmt) end)
    task.wait(cfg.actDelay)
    pcall(function() buyRemote:FireServer({item=crop.key, amount=cfg.buyAmt}) end)
    task.wait(cfg.actDelay)
    pcall(function() buyRemote:FireServer(crop.key) end)
    task.wait(cfg.actDelay)

    -- Fallback ProximityPrompt
    local npcObj = getNPCObj(NPC.bibit)
    if npcObj then
        firePrompt(npcObj, "Beli")
        task.wait(0.3)
        pcall(function() buyRemote:FireServer(crop.key, cfg.buyAmt) end)
    end
    task.wait(cfg.actDelay)
end

-- ============================
-- CORE: PANEN
-- Scan tanaman matang di AreaTanam → panen satu per satu
-- Attribute matang: "Matang", "Ready", "Phase"==3, "GrowPhase"==3
-- Owner check: Owner == LP.UserId atau LP.Name atau nil
-- ============================
local function doHarvest()
    if not cfg.autoHarvest then return end
    stat.action = "🌾 Panen..."
    upUI()

    -- Metode 1: FireServer tanpa args (HarvestAll)
    if RE_Harvest then
        pcall(function() RE_Harvest:FireServer() end)
        task.wait(cfg.actDelay)
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
                or (part:GetAttribute("Phase") ~= nil and part:GetAttribute("Phase") >= 3)
                or (part:GetAttribute("GrowPhase") ~= nil and part:GetAttribute("GrowPhase") >= 3)

            if not matang then
                -- Cek model parent
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
                    if cfg.useTP and (Root.Position - part.Position).Magnitude > 8 then
                        tpTo(part.Position)
                    end

                    -- Fire harvest dengan ref object
                    if RE_Harvest then
                        pcall(function() RE_Harvest:FireServer(part) end)
                        task.wait(cfg.actDelay / 2)
                        -- Parent model
                        if part.Parent and part.Parent:IsA("Model") then
                            pcall(function() RE_Harvest:FireServer(part.Parent) end)
                        end
                    end

                    -- ProximityPrompt & ClickDetector
                    local target = part.Parent and part.Parent:IsA("Model") and part.Parent or part
                    firePrompt(target, "Panen")
                    firePrompt(target, "Harvest")
                    fireClick(target)

                    stat.harvested = stat.harvested + 1
                    task.wait(cfg.actDelay)
                end
            end
        end
    end

    scanAndHarvest(getAreaTanamParts())
    scanAndHarvest(getAreaBesarParts())

    upUI()
end

-- ============================
-- CORE: TANAM BIBIT BIASA
-- Tutorial: "Equip bibit lalu klik area tanam"
-- → Equip tool → TP ke AreaTanam → klik/fire Plant
-- ============================
local function plantBiasa(crop)
    if not crop.enabled then return end

    local lv = getLevel()
    if lv < crop.minLevel then
        print("[AUTOFARM] Skip " .. crop.key .. " — butuh Lv." .. crop.minLevel)
        return
    end

    -- Beli bibit jika habis
    local seedCount = getSeedCount(crop.key)
    if seedCount <= 0 then
        if cfg.autoBuy then
            buySeeds(crop)
            task.wait(0.5)
            seedCount = getSeedCount(crop.key)
        end
        -- Kalau masih 0 setelah coba beli, skip tanaman ini saja — JANGAN blokir yang lain
        if seedCount <= 0 then
            print("[AUTOFARM] Bibit " .. crop.key .. " habis & tidak bisa dibeli — skip")
            return
        end
    end

    stat.action = "🌱 Tanam " .. crop.icon .. " " .. crop.key
    upUI()

    -- Equip seed tool jika ada
    local tool = LP.Backpack:FindFirstChild(crop.key)
        or LP.Backpack:FindFirstChild(crop.key:gsub(" ",""))
    if tool and Hum then
        pcall(function() Hum:EquipTool(tool) end)
        task.wait(0.3)
    end

    -- Fire Plant remote — format: (seedKey) atau (seedKey, areaPart)
    if RE_Plant then
        pcall(function() RE_Plant:FireServer(crop.key) end)
        task.wait(cfg.actDelay)
    end

    -- TP ke AreaTanam & klik
    local areaParts = getAreaTanamParts()
    for _, part in ipairs(areaParts) do
        if not stat.running then break end
        if getSeedCount(crop.key) <= 0 then break end

        -- Cek apakah plot kosong (tidak ada SeedType/PlantType/Owner)
        local isEmpty = (part:GetAttribute("SeedType") == nil)
            and (part:GetAttribute("PlantType") == nil)
            and (part:GetAttribute("Occupied") ~= true)
            and (part:GetAttribute("Matang") == nil)

        -- Atau plot milik kita yang kosong
        local owner = part:GetAttribute("Owner")
        local isMine = (owner == nil) or (tostring(owner) == tostring(LP.UserId))

        if isEmpty and isMine then
            if cfg.useTP and (Root.Position - part.Position).Magnitude > 8 then
                tpTo(part.Position)
            end

            if RE_Plant then
                pcall(function() RE_Plant:FireServer(crop.key, part) end)
                task.wait(cfg.actDelay / 2)
            end

            fireClick(part)
            firePrompt(part, "Tanam")
            firePrompt(part, "Plant")

            stat.planted = stat.planted + 1
            task.wait(cfg.actDelay)
        end
    end

    -- Unequip
    if Hum and Char then
        pcall(function()
            local equipped = Char:FindFirstChildOfClass("Tool")
            if equipped then Hum:UnequipTools() end
        end)
    end
end

-- ============================
-- CORE: TANAM SAWIT / DURIAN
-- Area: AreaTanamBesar1..28 (MaxPerPlayer=1, MaxTotal=2)
-- Harus punya lahan sendiri dulu (AreaTanamBesar yg di-claim)
-- ============================
local function plantBesar(crop)
    if not crop.enabled then return end

    local lv = getLevel()
    if lv < crop.minLevel then
        print("[AUTOFARM] Skip " .. crop.key .. " — butuh Lv." .. crop.minLevel)
        return
    end

    local seedCount = getSeedCount(crop.key)
    if seedCount <= 0 then
        if cfg.autoBuy then
            buySeeds(crop)
            task.wait(0.5)
            seedCount = getSeedCount(crop.key)
        end
        if seedCount <= 0 then return end
    end

    stat.action = "🌴 Tanam " .. crop.icon .. " " .. crop.key
    upUI()

    -- Equip tool
    local tool = LP.Backpack:FindFirstChild(crop.key)
        or LP.Backpack:FindFirstChild(crop.key:gsub(" ",""))
    if tool and Hum then
        pcall(function() Hum:EquipTool(tool) end)
        task.wait(0.3)
    end

    if RE_Plant then
        pcall(function() RE_Plant:FireServer(crop.key) end)
        task.wait(cfg.actDelay)
    end

    -- Scan AreaTanamBesar yang milik kita & kosong
    local besarParts = getAreaBesarParts()
    for _, part in ipairs(besarParts) do
        if not stat.running then break end
        if getSeedCount(crop.key) <= 0 then break end

        local owner = part:GetAttribute("Owner")
        local isMine = (tostring(owner) == tostring(LP.UserId))
            or (tostring(owner) == LP.Name)
        local isEmpty = (part:GetAttribute("SeedType") == nil)
            and (part:GetAttribute("PlantType") == nil)
            and (part:GetAttribute("Occupied") ~= true)

        if isMine and isEmpty then
            if cfg.useTP and (Root.Position - part.Position).Magnitude > 8 then
                tpTo(part.Position)
            end

            if RE_Plant then
                pcall(function() RE_Plant:FireServer(crop.key, part) end)
                task.wait(cfg.actDelay / 2)
            end

            fireClick(part)
            firePrompt(part, "Tanam")

            stat.planted = stat.planted + 1
            task.wait(cfg.actDelay)
        end
    end

    if Hum then pcall(function() Hum:UnequipTools() end) end
end

-- ============================
-- CORE: JUAL HASIL PANEN
-- Biasa → NPC_Penjual
-- Sawit → NPC_PedagangSawit
-- ============================
local function doSell()
    if not cfg.autoSell then return end
    stat.action = "💰 Jual..."
    upUI()

    -- Jual ke NPC_Penjual (Padi, Jagung, Tomat, Terong, Strawberry)
    local pos = getNPCPos(NPC.penjual)
    if pos then
        tpTo(pos)
        task.wait(0.4)
    end

    if RE_Sell then
        pcall(function() RE_Sell:FireServer() end)
        task.wait(cfg.actDelay)
        pcall(function() RE_Sell:FireServer("All") end)
        task.wait(cfg.actDelay)
    end

    local npcObj = getNPCObj(NPC.penjual)
    if npcObj then
        firePrompt(npcObj, "Jual")
        task.wait(0.3)
    end

    -- Jual ke NPC_PedagangSawit (Sawit)
    local sawitPos = getNPCPos(NPC.sawit)
    if sawitPos then
        tpTo(sawitPos)
        task.wait(0.4)
        if RE_Sell then
            pcall(function() RE_Sell:FireServer("Sawit") end)
            task.wait(cfg.actDelay)
        end
        local sawitObj = getNPCObj(NPC.sawit)
        if sawitObj then firePrompt(sawitObj, "Jual") end
    end

    task.wait(cfg.actDelay)
end

-- ============================
-- FULL FARM LOOP
-- ============================
local function farmLoop()
    stat.startTime = os.time()
    stat.lastLv    = getLevel()
    stat.lastCoins = getCoins()

    Rayfield:Notify({
        Title   = "🌾 Auto Farm Aktif!",
        Content = "Panen & tanam otomatis berjalan!",
        Duration = 4, Image = 4483362458
    })

    while stat.running do

        -- 1. PANEN
        pcall(doHarvest)
        if not stat.running then break end
        task.wait(cfg.actDelay)

        -- 2. JUAL (opsional)
        if cfg.autoSell then
            pcall(doSell)
            if not stat.running then break end
            task.wait(cfg.actDelay)
        end

        -- 3. TANAM BIASA
        if cfg.autoPlant then
            for _, crop in ipairs(CROPS_BIASA) do
                if not stat.running then break end
                pcall(plantBiasa, crop)
                task.wait(cfg.actDelay)
            end
        end

        -- 4. TANAM BESAR (Sawit & Durian)
        if cfg.autoPlant then
            for _, crop in ipairs(CROPS_BESAR) do
                if not stat.running then break end
                pcall(plantBesar, crop)
                task.wait(cfg.actDelay)
            end
        end

        -- 5. Update coins tracker
        local curCoins = getCoins()
        if curCoins > stat.lastCoins then
            stat.coinsGain = stat.coinsGain + (curCoins - stat.lastCoins)
        end
        stat.lastCoins = curCoins
        upUI()

        -- 6. Tunggu sebelum loop berikutnya
        stat.action = "⏳ Tunggu " .. cfg.loopDelay .. "s..."
        upUI()
        local w = 0
        while w < cfg.loopDelay and stat.running do
            task.wait(0.5); w = w + 0.5
        end
    end

    stat.action = "⏹ Dihentikan"
    upUI()
    Rayfield:Notify({
        Title   = "⏹ Auto Farm Stop",
        Content = "Panen: " .. stat.harvested .. " | Tanam: " .. stat.planted,
        Duration = 5, Image = 4483362458
    })
end

local function startFarm()
    if stat.running then return end
    stat.running = true
    upUI()
    stat.farmThread = task.spawn(farmLoop)
end

local function stopFarm()
    stat.running = false
    if stat.farmThread then pcall(task.cancel, stat.farmThread); stat.farmThread = nil end
    stat.action = "⏹ Dihentikan"
    upUI()
end

-- ============================
-- ANTI-AFK
-- ============================
local function startAFK()
    if stat.afkThread then return end
    stat.afkThread = task.spawn(function()
        while true do
            task.wait(55)
            if not stat.running and cfg.antiAFK and Root and Root.Parent then
                local cf = Root.CFrame
                Root.CFrame = cf * CFrame.new(0, 0, 0.5)
                task.wait(0.3)
                Root.CFrame = cf
            end
        end
    end)
end

-- Level up watcher
task.spawn(function()
    while true do
        task.wait(5)
        if cfg.notifLvlUp then
            local lv = getLevel()
            if stat.lastLv > 0 and lv > stat.lastLv then
                Rayfield:Notify({
                    Title   = "⭐ NAIK LEVEL!",
                    Content = "Level " .. stat.lastLv .. " → " .. lv .. "!",
                    Duration = 7, Image = 4483362458
                })
            end
            stat.lastLv = lv
        end
    end
end)

-- UI update timer
task.spawn(function()
    while true do
        task.wait(3)
        if stat.running then upUI() end
    end
end)

-- ============================
-- RAYFIELD UI
-- ============================
local Win = Rayfield:CreateWindow({
    Name            = "🌾  NAKA AUTO FARM",
    LoadingTitle    = "🌾  N A K A",
    LoadingSubtitle = "[ Sawah Indo  •  v3.0  •  Data Akurat ]",
    ConfigurationSaving = { Enabled=true, FolderName="NAKA", FileName="AutoFarm_v3" },
    Discord   = { Enabled=false },
    KeySystem = false,
})
Rayfield:LoadConfiguration()

Rayfield:Notify({
    Title    = "🌾  NAKA Auto Farm v3.0",
    Content  = "Data 100% akurat dari game!\nSiap digunakan.",
    Duration = 5, Image = 4483362458
})

-- ── TAB 1: FARM ─────────────────────────────────────────
local T1 = Win:CreateTab("🌾  Farm", 4483362458)

T1:CreateSection("◈  Status Real-Time")
L.status  = T1:CreateLabel("◦  Status    :  🔴 BERHENTI")
L.action  = T1:CreateLabel("◦  Aksi      :  ⏹ Standby")
L.harvest = T1:CreateLabel("◦  Dipanen   :  0")
L.planted = T1:CreateLabel("◦  Ditanam   :  0")
L.coins   = T1:CreateLabel("◦  Coins +   :  0")
L.durasi  = T1:CreateLabel("◦  Durasi    :  0m 0s")

T1:CreateSection("◈  Kontrol Utama")
T1:CreateButton({ Name="▶  Mulai Auto Farm", Callback=startFarm })
T1:CreateButton({ Name="⏹  Stop Auto Farm",  Callback=stopFarm  })
T1:CreateToggle({ Name="🔁  Loop Otomatis",   CurrentValue=true,
    Callback=function(v) cfg.loopEnabled=v end })
T1:CreateToggle({ Name="📍  Teleport Mode",   CurrentValue=true,
    Callback=function(v) cfg.useTP=v end })

T1:CreateSection("◈  Aksi Manual")
T1:CreateButton({ Name="🌾  Panen Sekarang",
    Callback=function() task.spawn(doHarvest) end })
T1:CreateButton({ Name="🌱  Tanam Sekarang",
    Callback=function()
        task.spawn(function()
            for _, c in ipairs(CROPS_BIASA) do pcall(plantBiasa, c) end
            for _, c in ipairs(CROPS_BESAR) do pcall(plantBesar, c) end
        end)
    end })
T1:CreateButton({ Name="💰  Jual Sekarang",
    Callback=function() task.spawn(doSell) end })

-- ── TAB 2: TANAMAN ─────────────────────────────────────
local T2 = Win:CreateTab("🌱  Tanaman", 4483362458)

T2:CreateSection("◈  Tanaman Biasa (AreaTanam)")
for _, c in ipairs(CROPS_BIASA) do
    local crop = c
    T2:CreateToggle({
        Name         = crop.icon .. "  " .. crop.key .. "  [Lv." .. crop.minLevel .. "]",
        CurrentValue = true,
        Callback     = function(v) crop.enabled = v end
    })
end

T2:CreateSection("◈  Lahan Besar (AreaTanamBesar)")
T2:CreateLabel("◦  Sawit & Durian butuh lahan sendiri")
T2:CreateLabel("◦  MaxPerPlayer: 1 lahan, MaxCrops: 2")
for _, c in ipairs(CROPS_BESAR) do
    local crop = c
    T2:CreateToggle({
        Name         = crop.icon .. "  " .. crop.key .. "  [Lv." .. crop.minLevel .. "]",
        CurrentValue = true,
        Callback     = function(v) crop.enabled = v end
    })
end

T2:CreateSection("◈  Fitur Auto")
T2:CreateToggle({ Name="🌾  Auto Panen",           CurrentValue=true,  Callback=function(v) cfg.autoHarvest=v end })
T2:CreateToggle({ Name="🌱  Auto Tanam",           CurrentValue=true,  Callback=function(v) cfg.autoPlant=v   end })
T2:CreateToggle({ Name="🛒  Auto Beli Bibit",      CurrentValue=true,  Callback=function(v) cfg.autoBuy=v     end })
T2:CreateToggle({ Name="💰  Auto Jual (default OFF)", CurrentValue=false, Callback=function(v) cfg.autoSell=v  end })

-- ── TAB 3: SETTINGS ────────────────────────────────────
local T3 = Win:CreateTab("⚙  Settings", 4483362458)

T3:CreateSection("◈  Timing")
T3:CreateSlider({ Name="⏱  Delay Aksi (×0.1s)", Range={1,20}, Increment=1, CurrentValue=4,
    Callback=function(v) cfg.actDelay = v * 0.1 end })
T3:CreateSlider({ Name="🔁  Delay Loop (detik)", Range={1,30}, Increment=1, CurrentValue=3,
    Callback=function(v) cfg.loopDelay = v end })
T3:CreateSlider({ Name="🛒  Jumlah Beli Bibit",  Range={10,200}, Increment=10, CurrentValue=50,
    Callback=function(v) cfg.buyAmt = v end })

T3:CreateSection("◈  Sistem")
T3:CreateToggle({ Name="⭐  Notif Level Up", CurrentValue=true,  Callback=function(v) cfg.notifLvlUp=v end })
T3:CreateToggle({ Name="🛡  Anti-AFK",       CurrentValue=true,  Callback=function(v) cfg.antiAFK=v    end })

T3:CreateSection("◈  Debug")
T3:CreateButton({ Name="🔍  Cek Remote Events", Callback=function()
    local info = {
        { "Plant",   RE_Plant   },
        { "Harvest", RE_Harvest },
        { "Buy",     RE_Buy     },
        { "Sell",    RE_Sell    },
    }
    for _, v in ipairs(info) do
        Rayfield:Notify({
            Title   = "RE_" .. v[1],
            Content = v[2] and ("✅ " .. v[2]:GetFullName()) or "❌ Tidak ditemukan",
            Duration = 3, Image = 4483362458
        })
        task.wait(0.4)
    end
end })
T3:CreateButton({ Name="📋  Scan SEMUA RemoteEvent", Callback=function()
    -- Print ke console semua RemoteEvent di RS
    local count = 0
    for _, obj in ipairs(RS:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            count = count + 1
            print("[SCAN] " .. obj:GetFullName())
        end
    end
    Rayfield:Notify({
        Title   = "📋 Scan Selesai",
        Content = "Ditemukan " .. count .. " RemoteEvent\nLihat di Console (F9)!",
        Duration = 5, Image = 4483362458
    })
end })
T3:CreateButton({ Name="📍  Cek NPC Positions", Callback=function()
    for k, name in pairs(NPC) do
        local pos = getNPCPos(name)
        Rayfield:Notify({
            Title   = name,
            Content = pos and ("✅ " .. tostring(math.floor(pos.X)) .. ", " .. tostring(math.floor(pos.Y)) .. ", " .. tostring(math.floor(pos.Z)))
                or "❌ Tidak ditemukan",
            Duration = 3, Image = 4483362458
        })
        task.wait(0.4)
    end
end })
T3:CreateButton({ Name="🌾  Cek Area Tanam", Callback=function()
    local biasa = getAreaTanamParts()
    local besar = getAreaBesarParts()
    Rayfield:Notify({
        Title   = "Area Tanam",
        Content = "AreaTanam: " .. #biasa .. " parts\nAreaTanamBesar: " .. #besar .. " parts",
        Duration = 4, Image = 4483362458
    })
end })

-- ── TAB 4: INFO ────────────────────────────────────────
local T4 = Win:CreateTab("📋  Info", 4483362458)

T4:CreateSection("◈  Cara Pakai")
T4:CreateLabel("1️⃣   Pastikan sudah selesai tutorial dulu!")
T4:CreateLabel("2️⃣   Tab 🌱 Tanaman — pilih crop sesuai level")
T4:CreateLabel("3️⃣   Tab ⚙ Settings — cek debug (NPC & Remote)")
T4:CreateLabel("4️⃣   Tab 🌾 Farm → klik ▶ Mulai Auto Farm")

T4:CreateSection("◈  Data dari Game Config")
T4:CreateLabel("🌾  Padi       Lv.1   | 50-60s   | 🏠 AreaTanam")
T4:CreateLabel("🌽  Jagung     Lv.20  | 80-100s  | 🏠 AreaTanam")
T4:CreateLabel("🍅  Tomat      Lv.40  | 120-150s | 🏠 AreaTanam")
T4:CreateLabel("🍆  Terong     Lv.60  | 150-200s | 🏠 AreaTanam")
T4:CreateLabel("🍓  Strawberry Lv.80  | 180-250s | 🏠 AreaTanam")
T4:CreateLabel("🌴  Sawit      Lv.80  | 600-1000s| 🏕 AreaTanamBesar")
T4:CreateLabel("🍈  Durian     Lv.120 | 800-1200s| 🏕 AreaTanamBesar")

T4:CreateSection("◈  NPC Targets (persis dari game)")
T4:CreateLabel("🛒  Beli Bibit   →  NPC_Bibit")
T4:CreateLabel("💰  Jual Panen   →  NPC_Penjual")
T4:CreateLabel("🌴  Jual Sawit   →  NPC_PedagangSawit")
T4:CreateLabel("🔨  Toko Alat    →  NPC_Alat")

T4:CreateSection("◈  Tentang")
T4:CreateLabel("🌾   NAKA Auto Farm  —  v3.0")
T4:CreateLabel("◦   Game  :  Sawah Indo")

-- ============================
-- INIT
-- ============================
startAFK()
print("[NAKA AUTO FARM v3.0] Sawah Indo — LOADED")
