-- =========================================================
-- 🌾 NAKA AUTO FARM — SAWAH INDO v4.0
-- Data 100% AKURAT dari decompile CropConfig + LahanBesarConfig
-- + TutorialConfig + LocaleConfig
--
-- PERBAIKAN dari v3.0:
--   ✅ ToolName per tanaman dari CropConfig asli
--   ✅ HarvestAmount & AutoHarvestDelay dari config asli
--   ✅ SellPrice dari SellableItems config
--   ✅ Phase detection: *_Fase3 model = matang
--   ✅ ProximityPrompt action text dari LocaleConfig
--   ✅ LahanBesar: MaxPerPlayer=1, MaxCropsPerType=1, MaxTotalCrops=2
--   ✅ NPC folder: workspace.NPCs (dari WorldConfig)
--   ✅ AreaTanam target dari TutorialConfig
--   ✅ Remote cache + retry otomatis
--   ✅ Thread management (tidak ada zombie threads)
--   ✅ Anti-AFK tidak ganggu farming
--   ✅ Coins tracker akurat
--   ✅ Level-up notif
--   ✅ Debug tab lengkap
-- =========================================================

if not game:IsLoaded() then game.Loaded:Wait() end

-- ============================
-- LOAD RAYFIELD
-- ============================
local Rayfield
local ok = pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not ok then
    local stub = { Set = function() end }
    local tabStub = {
        CreateSection = function() end,
        CreateLabel   = function() return stub end,
        CreateButton  = function() end,
        CreateToggle  = function() end,
        CreateSlider  = function() end,
    }
    Rayfield = {
        CreateWindow      = function() return { CreateTab = function() return tabStub end } end,
        Notify            = function(_, d) print("[NOTIF] " .. tostring(d.Title) .. ": " .. tostring(d.Content)) end,
        LoadConfiguration = function() end,
    }
    warn("[NAKA] Rayfield gagal dimuat, menggunakan stub UI")
end

-- ============================
-- SERVICES
-- ============================
local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")

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
-- DATA AKURAT DARI DECOMPILE
-- ============================

-- CropConfig → Seeds
local CROPS_BIASA = {
    { key="Bibit Padi",       icon="🌾", toolName="BibitTool",      harvestItem="Padi",       harvestAmt=1, autoHDelay=60,  sellPrice=10,  buyPrice=5,    seedSellPx=3,    minLevel=1,   phaseModel="Bibit_Fase3",       enabled=true },
    { key="Bibit Jagung",     icon="🌽", toolName="JagungTool",     harvestItem="Jagung",     harvestAmt=2, autoHDelay=90,  sellPrice=20,  buyPrice=15,   seedSellPx=11,   minLevel=20,  phaseModel="Jagung_Fase3",      enabled=true },
    { key="Bibit Tomat",      icon="🍅", toolName="TomatTool",      harvestItem="Tomat",      harvestAmt=3, autoHDelay=120, sellPrice=30,  buyPrice=25,   seedSellPx=18,   minLevel=40,  phaseModel="Tomat_Fase3",       enabled=true },
    { key="Bibit Terong",     icon="🍆", toolName="TerongTool",     harvestItem="Terong",     harvestAmt=4, autoHDelay=150, sellPrice=50,  buyPrice=40,   seedSellPx=30,   minLevel=60,  phaseModel="Terong_Fase3",      enabled=true },
    { key="Bibit Strawberry", icon="🍓", toolName="StrawberryTool", harvestItem="Strawberry", harvestAmt=4, autoHDelay=200, sellPrice=75,  buyPrice=60,   seedSellPx=45,   minLevel=80,  phaseModel="Strawberry_Fase3",  enabled=true },
}

-- CropConfig → Seeds (CustomHarvest = true)
local CROPS_BESAR = {
    { key="Bibit Sawit",  icon="🌴", toolName="SawitTool",  harvestItem="Sawit",  harvestAmt=4, autoHDelay=600, sellPrice=1500, buyPrice=1000, seedSellPx=750,  minLevel=80,  phaseModel="Sawit_Fase3",  customHarvest=true, fruitType="Sawit",  enabled=true },
    { key="Bibit Durian", icon="🍈", toolName="DurianTool", harvestItem="Durian", harvestAmt=1, autoHDelay=700, sellPrice=nil,  buyPrice=2000, seedSellPx=1500, minLevel=120, phaseModel="Durian_Fase3", customHarvest=true, fruitType="Durian", enabled=true },
}

-- LahanBesarConfig
local LAHAN_BESAR = {
    areaPrefix      = "AreaTanamBesar",
    totalAreas      = 28,
    buyPrice        = 100000,
    maxPerPlayer    = 1,
    maxCropsPerType = 1,
    maxTotalCrops   = 2,
}

-- WorldConfig
local NPC_FOLDER = "NPCs"
local NPC_NAMES  = {
    bibit   = "NPC_Bibit",
    penjual = "NPC_Penjual",
    alat    = "NPC_Alat",
    sawit   = "NPC_PedagangSawit",
}

-- LocaleConfig ProximityPrompt action keywords
local PP = {
    harvest  = {"Panen", "Harvest", "Ambil"},
    plant    = {"Tanam", "Plant", "Semai"},
    buy      = {"Beli Bibit", "Beli", "Buy"},
    sell     = {"Jual Hasil Panen", "Jual Semua", "Jual", "Sell All", "Sell"},
    sellSawit= {"Jual Sawit", "Jual Buah", "Sell Palm"},
}

-- ============================
-- REMOTE DETECTION
-- ============================
local remoteMap = {}

local function buildRemoteMap()
    remoteMap = {}
    for _, obj in ipairs(RS:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local lo = obj.Name:lower()
            if not remoteMap[lo] then remoteMap[lo] = obj end
            local fp = obj:GetFullName():lower():gsub("replicatedstorage%.", "")
            if not remoteMap[fp] then remoteMap[fp] = obj end
        end
    end
end
buildRemoteMap()

RS.DescendantAdded:Connect(function(obj)
    if obj:IsA("RemoteEvent") then
        local lo = obj.Name:lower()
        if not remoteMap[lo] then remoteMap[lo] = obj end
        print("[NAKA] Remote baru terdeteksi: " .. obj:GetFullName())
    end
end)

local function findRemote(keywords)
    for _, kw in ipairs(keywords) do
        local lo = kw:lower()
        if remoteMap[lo] then return remoteMap[lo] end
        for key, remote in pairs(remoteMap) do
            if key:find(lo, 1, true) then return remote end
        end
    end
    return nil
end

local RE = { plant=nil, harvest=nil, buy=nil, sell=nil }

local function detectRemotes()
    RE.plant   = findRemote({"plantcrop","plantseed","plant","tanam","tanambibit"})
    RE.harvest = findRemote({"harvestcrop","harvestall","harvest","panen","panensemua"})
    RE.buy     = findRemote({"buyseed","buyitem","belibibit","buy","beli","purchase","shopbuy"})
    RE.sell    = findRemote({"sellitem","sellall","jualitem","jual","sell","sellcrops"})
end
detectRemotes()
task.delay(3, detectRemotes)
task.delay(8, detectRemotes)

local function logRemotes()
    print("[NAKA v4.0] Remote Events:")
    print("  Plant   = " .. (RE.plant   and RE.plant:GetFullName()   or "❌ not found"))
    print("  Harvest = " .. (RE.harvest and RE.harvest:GetFullName() or "❌ not found"))
    print("  Buy     = " .. (RE.buy     and RE.buy:GetFullName()     or "❌ not found"))
    print("  Sell    = " .. (RE.sell    and RE.sell:GetFullName()    or "❌ not found"))
end
logRemotes()

local function fire(remote, ...)
    if not remote then return false end
    local s, e = pcall(remote.FireServer, remote, ...)
    if not s then warn("[NAKA] FireServer error " .. remote.Name .. ": " .. tostring(e)) end
    return s
end

-- ============================
-- NPC FINDER
-- ============================
local function getNPCObj(role)
    local name = NPC_NAMES[role]
    if not name then return nil end
    local folder = workspace:FindFirstChild(NPC_FOLDER)
        or workspace:FindFirstChild("NPC")
    if folder then
        local found = folder:FindFirstChild(name, true)
        if found then return found end
    end
    return workspace:FindFirstChild(name, true)
end

local function getNPCPos(role)
    local obj = getNPCObj(role)
    if not obj then return nil end
    if obj:IsA("Model") then
        local rp = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
        return rp and rp.Position
    elseif obj:IsA("BasePart") then
        return obj.Position
    end
    return nil
end

-- ============================
-- AREA FINDER
-- ============================
local function collectParts(obj)
    local parts = {}
    if not obj then return parts end
    if obj:IsA("BasePart") then table.insert(parts, obj)
    else
        for _, v in ipairs(obj:GetDescendants()) do
            if v:IsA("BasePart") then table.insert(parts, v) end
        end
    end
    return parts
end

-- TutorialConfig: Target = "AreaTanam"
local function getAreaTanamParts()
    return collectParts(workspace:FindFirstChild("AreaTanam", true))
end

-- LahanBesarConfig: AreaTanamBesar1..28
local function getAreaBesarParts()
    local parts = {}
    for i = 1, LAHAN_BESAR.totalAreas do
        local area = workspace:FindFirstChild(LAHAN_BESAR.areaPrefix .. tostring(i), true)
        for _, p in ipairs(collectParts(area)) do table.insert(parts, p) end
    end
    return parts
end

-- ============================
-- PLAYER DATA
-- ============================
local function readStat(names)
    if type(names) == "string" then names = {names} end
    for _, src in ipairs({
        LP:FindFirstChild("leaderstats"),
        LP:FindFirstChild("PlayerData"),
        LP:FindFirstChild("Data"),
        LP:FindFirstChild("Stats"),
        LP:FindFirstChild("Inventory"),
        LP,
    }) do
        if src then
            for _, n in ipairs(names) do
                local v = src:FindFirstChild(n, true)
                if v and v:IsA("ValueBase") then return tonumber(v.Value) or 0 end
            end
        end
    end
    for _, n in ipairs(names) do
        local a = LP:GetAttribute(n)
        if a then return tonumber(a) or 0 end
    end
    return 0
end

local function getCoins()  return readStat({"Coins","coins","Gold","Money","Cash"}) end
local function getLevel()  return readStat({"Level","level","Lv","LV","XP_Level","PlayerLevel"}) end
local function getSeedCount(key) return readStat({ key, key:gsub(" ",""), "Seed_"..key:gsub(" ","") }) end

-- ============================
-- TELEPORT
-- ============================
local lastTP = 0
local function tpTo(pos, force)
    if not pos or not Root or not Root.Parent then return end
    if not force and (os.clock() - lastTP) < 0.25 then return end
    lastTP = os.clock()
    Root.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
    task.wait(0.2)
end
local function tpIfFar(pos, dist)
    if pos and (Root.Position - pos).Magnitude > (dist or 10) then tpTo(pos) end
end

-- ============================
-- INTERAKSI
-- ============================
local function triggerPP(obj, keywords)
    if not obj then return end
    local root = (obj:IsA("Model") and obj)
        or (obj.Parent and obj.Parent:IsA("Model") and obj.Parent) or obj
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            local matched = not keywords
            if not matched then
                local text = (d.ActionText .. " " .. d.ObjectText):lower()
                for _, kw in ipairs(keywords) do
                    if text:find(kw:lower(), 1, true) then matched = true; break end
                end
            end
            if matched then
                pcall(function() d.Triggered:Fire(LP) end)
                pcall(function() game:GetService("ProximityPromptService"):PromptTriggered(d, LP) end)
            end
        end
    end
end

local function triggerCD(obj)
    if not obj then return end
    local root = (obj:IsA("Model") and obj)
        or (obj.Parent and obj.Parent:IsA("Model") and obj.Parent) or obj
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("ClickDetector") then
            pcall(function() d.MouseClick:Fire(LP) end)
        end
    end
end

local function interact(obj, keywords)
    triggerPP(obj, keywords)
    triggerCD(obj)
end

-- ============================
-- PLOT HELPERS
-- ============================
local function isPlotMature(part)
    local function checkObj(o)
        if not o then return false end
        if o:GetAttribute("Matang") == true then return true end
        if o:GetAttribute("Ready")  == true then return true end
        if o:GetAttribute("Ripe")   == true then return true end
        if o:GetAttribute("CanHarvest") == true then return true end
        local ph = o:GetAttribute("Phase") or o:GetAttribute("GrowPhase") or o:GetAttribute("Stage")
        if ph and tonumber(ph) and tonumber(ph) >= 3 then return true end
        return false
    end
    if checkObj(part) then return true end
    local mdl = part.Parent
    if mdl and mdl:IsA("Model") then
        if checkObj(mdl) then return true end
        -- CropConfig: Fase matang = Phases[3].ModelName berisi "_Fase3"
        for _, c in ipairs(mdl:GetChildren()) do
            if c.Name:find("_Fase3") then return true end
        end
    end
    return false
end

local function isOwnedByMe(obj)
    local function check(o)
        if not o then return true end
        local ow = o:GetAttribute("Owner") or o:GetAttribute("OwnerID") or o:GetAttribute("OwnerId")
        if ow == nil then return true end
        return tostring(ow) == tostring(LP.UserId) or tostring(ow) == LP.Name
    end
    if not check(obj) then return false end
    if obj.Parent and obj.Parent:IsA("Model") then
        if not check(obj.Parent) then return false end
    end
    return true
end

local function isPlotEmpty(part)
    local function checkEmpty(o)
        if not o then return true end
        if o:GetAttribute("Occupied") == true then return false end
        local st = o:GetAttribute("SeedType") or o:GetAttribute("PlantType") or o:GetAttribute("Crop")
        if st and st ~= "" and st ~= "None" then return false end
        return true
    end
    if not checkEmpty(part) then return false end
    local mdl = part.Parent
    if mdl and mdl:IsA("Model") then
        if not checkEmpty(mdl) then return false end
        for _, c in ipairs(mdl:GetChildren()) do
            if c:IsA("Model") and c.Name:find("_Fase") then return false end
        end
    end
    return true
end

-- ============================
-- CONFIG & STATE
-- ============================
local cfg = {
    autoHarvest = true,
    autoPlant   = true,
    autoBuy     = true,
    autoSell    = false,
    antiAFK     = true,
    notifLvlUp  = true,
    loopDelay   = 3,
    actDelay    = 0.4,
    buyAmt      = 50,
    minSeedThr  = 5,
    useTP       = true,
}

local stat = {
    running   = false,
    action    = "⏹ Standby",
    harvested = 0,
    planted   = 0,
    sold      = 0,
    coinsGain = 0,
    startTime = os.time(),
    lastLv    = 0,
    lastCoins = 0,
    loops     = 0,
    errors    = 0,
}

local threads = {}
local function spawnThread(fn)
    local t = task.spawn(fn)
    table.insert(threads, t)
    return t
end

-- ============================
-- UI LABELS
-- ============================
local L = {}
local function updateUI()
    local e = os.time() - stat.startTime
    pcall(function() L.status:Set("  Status    :  "  .. (stat.running and "🟢 BERJALAN" or "🔴 BERHENTI")) end)
    pcall(function() L.action:Set("  Aksi      :  "  .. stat.action) end)
    pcall(function() L.harvest:Set("  Dipanen   :  " .. stat.harvested) end)
    pcall(function() L.planted:Set("  Ditanam   :  " .. stat.planted) end)
    pcall(function() L.sold:Set("  Terjual   :  "    .. stat.sold) end)
    pcall(function() L.coins:Set("  Coins +   :  "   .. stat.coinsGain) end)
    pcall(function() L.loops:Set("  Loop      :  "   .. stat.loops) end)
    pcall(function() L.errors:Set("  Errors    :  "  .. stat.errors) end)
    pcall(function() L.durasi:Set(string.format("  Durasi    :  %dm %ds", math.floor(e/60), e%60)) end)
end

local function setAction(txt) stat.action = txt; updateUI() end

-- ============================
-- CORE: BELI BIBIT
-- TutorialConfig: NPC_Bibit → INTERACT (BUY_BIBIT step)
-- LocaleConfig: NPC_BuySeeds = "Beli Bibit"
-- ============================
local function buySeeds(crop)
    if not cfg.autoBuy then return end
    if getSeedCount(crop.key) >= cfg.minSeedThr then return end
    if not RE.buy then RE.buy = findRemote({"buyseed","buy","beli","purchase"}) end

    setAction("🛒 Beli " .. crop.icon .. " " .. crop.key)

    local npcObj = getNPCObj("bibit")
    if cfg.useTP then tpTo(getNPCPos("bibit")) end
    if npcObj then interact(npcObj, PP.buy); task.wait(cfg.actDelay) end

    if RE.buy then
        fire(RE.buy, crop.key, cfg.buyAmt)                       -- format 1
        task.wait(cfg.actDelay * 0.4)
        fire(RE.buy, { item=crop.key, amount=cfg.buyAmt })       -- format 2
        task.wait(cfg.actDelay * 0.4)
        fire(RE.buy, crop.key)                                   -- format 3
        task.wait(cfg.actDelay)
    else
        warn("[NAKA] RE.buy tidak ditemukan — skip beli " .. crop.key)
    end
end

-- ============================
-- CORE: PANEN
-- TutorialConfig: HARVEST → INTERACT, Target=nil
-- LocaleConfig: HarvestAction = "Panen"
-- CropConfig: Phase[3].ModelName = "*_Fase3" = matang
-- ============================
local function doHarvest()
    if not cfg.autoHarvest then return end
    setAction("🌾 Panen semua...")

    -- Metode 1: global HarvestAll
    if RE.harvest then
        fire(RE.harvest)
        task.wait(cfg.actDelay * 0.5)
        fire(RE.harvest, "All")
        task.wait(cfg.actDelay)
    end

    -- Metode 2: scan per plot
    local function scanHarvest(parts)
        for _, part in ipairs(parts) do
            if not stat.running then break end
            if not isPlotMature(part) then continue end
            if not isOwnedByMe(part) then continue end

            if cfg.useTP then tpIfFar(part.Position, 8) end

            local target = (part.Parent and part.Parent:IsA("Model")) and part.Parent or part

            if RE.harvest then
                fire(RE.harvest, part)
                task.wait(cfg.actDelay * 0.2)
                if part.Parent and part.Parent:IsA("Model") then
                    fire(RE.harvest, part.Parent)
                    task.wait(cfg.actDelay * 0.2)
                end
            end
            interact(target, PP.harvest)

            stat.harvested = stat.harvested + 1
            task.wait(cfg.actDelay * 0.3)
        end
    end

    scanHarvest(getAreaTanamParts())
    scanHarvest(getAreaBesarParts())
    updateUI()
end

-- ============================
-- CORE: TANAM
-- TutorialConfig PLANT: "Equip bibit lalu klik area tanam"
-- CropConfig.ToolName = "BibitTool", "JagungTool", dst.
-- ============================
local function plantCrop(crop, areaParts, isBesar)
    if not crop.enabled then return end

    local lv = getLevel()
    if lv > 0 and lv < crop.minLevel then
        print(string.format("[NAKA] Skip %s — butuh Lv.%d (saat ini Lv.%d)", crop.key, crop.minLevel, lv))
        return
    end

    if getSeedCount(crop.key) < 1 then
        buySeeds(crop); task.wait(0.5)
        if getSeedCount(crop.key) < 1 then
            print("[NAKA] Bibit " .. crop.key .. " habis, skip"); return
        end
    end

    setAction("🌱 Tanam " .. crop.icon .. " " .. crop.key)

    -- Equip tool (ToolName dari CropConfig: "BibitTool", "JagungTool", dst.)
    local tool
    for _, tn in ipairs({ crop.toolName, crop.key, crop.key:gsub(" ","") }) do
        tool = LP.Backpack:FindFirstChild(tn)
        if not tool and Char then tool = Char:FindFirstChild(tn) end
        if tool then break end
    end
    if tool and Hum then pcall(function() Hum:EquipTool(tool) end); task.wait(0.25) end

    -- Fire plant global
    if RE.plant then fire(RE.plant, crop.key); task.wait(cfg.actDelay * 0.4) end

    -- Scan plot kosong
    local planted = 0
    for _, part in ipairs(areaParts) do
        if not stat.running then break end
        if getSeedCount(crop.key) < 1 then break end
        if not isPlotEmpty(part) then continue end
        if isBesar and not isOwnedByMe(part) then continue end  -- LahanBesar: wajib milik sendiri

        if cfg.useTP then tpIfFar(part.Position, 8) end

        if RE.plant then
            fire(RE.plant, crop.key, part)
            task.wait(cfg.actDelay * 0.2)
            if part.Parent and part.Parent:IsA("Model") then
                fire(RE.plant, crop.key, part.Parent)
                task.wait(cfg.actDelay * 0.2)
            end
        end
        interact(part, PP.plant)

        planted = planted + 1
        stat.planted = stat.planted + 1
        task.wait(cfg.actDelay * 0.3)
    end

    if Hum then pcall(function() Hum:UnequipTools() end) end
    if planted > 0 then print("[NAKA] Ditanam " .. planted .. "x " .. crop.key) end
end

local function doPlant()
    if not cfg.autoPlant then return end
    local biasaParts = getAreaTanamParts()
    local besarParts = getAreaBesarParts()
    for _, crop in ipairs(CROPS_BIASA) do
        if not stat.running then break end
        pcall(plantCrop, crop, biasaParts, false); task.wait(cfg.actDelay * 0.4)
    end
    for _, crop in ipairs(CROPS_BESAR) do
        if not stat.running then break end
        pcall(plantCrop, crop, besarParts, true); task.wait(cfg.actDelay * 0.4)
    end
end

-- ============================
-- CORE: JUAL
-- TutorialConfig GO_SELL: Target="NPC_Penjual"
-- LocaleConfig: NPC_SellCrops="Jual Hasil Panen", NPC_SellSawit="Jual Sawit"
-- SellableItems: Padi=10, Jagung=20, Tomat=30, Terong=50, Strawberry=75, Sawit=1500
-- ============================
local function doSell()
    if not cfg.autoSell then return end
    if not RE.sell then RE.sell = findRemote({"sellitem","sellall","jual","sell"}) end

    -- Jual hasil biasa → NPC_Penjual
    setAction("💰 Jual ke NPC_Penjual...")
    local npcPenjual = getNPCObj("penjual")
    if cfg.useTP then tpTo(getNPCPos("penjual")) end
    if npcPenjual then interact(npcPenjual, PP.sell); task.wait(cfg.actDelay) end
    if RE.sell then
        fire(RE.sell); task.wait(cfg.actDelay * 0.4)
        fire(RE.sell, "All"); task.wait(cfg.actDelay)
    end

    -- Jual Sawit/Durian → NPC_PedagangSawit (CustomHarvest)
    setAction("🌴 Jual ke NPC_PedagangSawit...")
    local npcSawit = getNPCObj("sawit")
    if cfg.useTP then tpTo(getNPCPos("sawit")) end
    if npcSawit then interact(npcSawit, PP.sellSawit); task.wait(cfg.actDelay) end
    if RE.sell then
        fire(RE.sell, "Sawit"); task.wait(cfg.actDelay * 0.4)
        fire(RE.sell, "Durian"); task.wait(cfg.actDelay)
    end

    stat.sold = stat.sold + 1
    updateUI()
end

-- ============================
-- FARM LOOP
-- ============================
local farmThread

local function farmLoop()
    stat.startTime = os.time()
    stat.lastLv    = getLevel()
    stat.lastCoins = getCoins()
    stat.loops     = 0
    stat.errors    = 0

    Rayfield:Notify({
        Title   = "🌾 Auto Farm Aktif!",
        Content = "NAKA v4.0 — Data akurat dari game config!",
        Duration = 4, Image = 4483362458
    })

    while stat.running do
        stat.loops = stat.loops + 1

        -- 1. Panen
        if not pcall(doHarvest) then stat.errors += 1 end
        if not stat.running then break end
        task.wait(cfg.actDelay)

        -- 2. Jual (opsional)
        if cfg.autoSell then
            if not pcall(doSell) then stat.errors += 1 end
            if not stat.running then break end
            task.wait(cfg.actDelay)
        end

        -- 3. Tanam
        if not pcall(doPlant) then stat.errors += 1 end
        if not stat.running then break end
        task.wait(cfg.actDelay)

        -- 4. Coin tracking
        local cur = getCoins()
        if cur > stat.lastCoins then stat.coinsGain += (cur - stat.lastCoins) end
        stat.lastCoins = cur

        -- 5. Tunggu antar loop
        setAction(string.format("⏳ Tunggu %ds... (loop #%d)", cfg.loopDelay, stat.loops))
        local w = 0
        while w < cfg.loopDelay and stat.running do task.wait(0.5); w += 0.5 end
    end

    setAction("⏹ Dihentikan")
    Rayfield:Notify({
        Title   = "⏹ Auto Farm Stop",
        Content = string.format("Panen: %d | Tanam: %d | Loop: %d | Error: %d",
            stat.harvested, stat.planted, stat.loops, stat.errors),
        Duration = 5, Image = 4483362458
    })
end

local function startFarm()
    if stat.running then return end
    stat.running  = true
    stat.harvested = 0; stat.planted = 0; stat.sold = 0
    stat.coinsGain = 0; stat.loops = 0; stat.errors = 0
    updateUI()
    farmThread = spawnThread(farmLoop)
end

local function stopFarm()
    stat.running = false
    if farmThread then pcall(task.cancel, farmThread); farmThread = nil end
    setAction("⏹ Dihentikan"); updateUI()
end

-- ============================
-- ANTI-AFK
-- ============================
local afkThread
local function startAntiAFK()
    if afkThread then return end
    afkThread = task.spawn(function()
        while true do
            task.wait(58)
            if not stat.running and cfg.antiAFK and Root and Root.Parent then
                local cf = Root.CFrame
                Root.CFrame = cf * CFrame.new(0, 0, 0.4)
                task.wait(0.3)
                Root.CFrame = cf
            end
        end
    end)
end

-- Level-up watcher
spawnThread(function()
    while true do
        task.wait(5)
        if cfg.notifLvlUp then
            local lv = getLevel()
            if stat.lastLv > 0 and lv > stat.lastLv then
                Rayfield:Notify({
                    Title   = "⭐ NAIK LEVEL!",
                    Content = "Level " .. stat.lastLv .. " → " .. lv .. " 🎉",
                    Duration = 7, Image = 4483362458
                })
                print("[NAKA] Level up! " .. stat.lastLv .. " → " .. lv)
            end
            stat.lastLv = lv
        end
    end
end)

-- UI updater
spawnThread(function()
    while true do task.wait(2); if stat.running then updateUI() end end
end)

-- ============================
-- RAYFIELD UI
-- ============================
local Win = Rayfield:CreateWindow({
    Name                = "🌾  NAKA AUTO FARM  |  Sawah Indo",
    LoadingTitle        = "🌾  N A K A  A U T O  F A R M",
    LoadingSubtitle     = "[ v4.0  •  Data Akurat dari Game Config ]",
    ConfigurationSaving = { Enabled=true, FolderName="NAKA", FileName="AutoFarm_v4" },
    Discord             = { Enabled=false },
    KeySystem           = false,
})
Rayfield:LoadConfiguration()

Rayfield:Notify({
    Title   = "🌾 NAKA Auto Farm v4.0",
    Content = "Data akurat dari decompile!\nPlant:" .. (RE.plant and "✅" or "⏳")
        .. " Harvest:" .. (RE.harvest and "✅" or "⏳")
        .. " Buy:" .. (RE.buy and "✅" or "⏳"),
    Duration = 5, Image = 4483362458
})

-- ─── TAB 1: FARM ─────────────────────────────────────────
local T1 = Win:CreateTab("🌾  Farm", 4483362458)

T1:CreateSection("◈  Status Real-Time")
L.status  = T1:CreateLabel("  Status    :  🔴 BERHENTI")
L.action  = T1:CreateLabel("  Aksi      :  ⏹ Standby")
L.harvest = T1:CreateLabel("  Dipanen   :  0")
L.planted = T1:CreateLabel("  Ditanam   :  0")
L.sold    = T1:CreateLabel("  Terjual   :  0")
L.coins   = T1:CreateLabel("  Coins +   :  0")
L.loops   = T1:CreateLabel("  Loop      :  0")
L.errors  = T1:CreateLabel("  Errors    :  0")
L.durasi  = T1:CreateLabel("  Durasi    :  0m 0s")

T1:CreateSection("◈  Kontrol Utama")
T1:CreateButton({ Name="▶  Mulai Auto Farm", Callback=startFarm })
T1:CreateButton({ Name="⏹  Stop Auto Farm",  Callback=stopFarm  })
T1:CreateToggle({ Name="📍  Teleport Mode", CurrentValue=true,
    Callback=function(v) cfg.useTP = v end })

T1:CreateSection("◈  Aksi Manual")
T1:CreateButton({ Name="🌾  Panen Sekarang",    Callback=function() spawnThread(doHarvest) end })
T1:CreateButton({ Name="🌱  Tanam Sekarang",    Callback=function() spawnThread(doPlant) end })
T1:CreateButton({ Name="💰  Jual Sekarang",
    Callback=function()
        local old = cfg.autoSell; cfg.autoSell = true
        spawnThread(function() pcall(doSell); cfg.autoSell = old end)
    end })

-- ─── TAB 2: TANAMAN ──────────────────────────────────────
local T2 = Win:CreateTab("🌱  Tanaman", 4483362458)

T2:CreateSection("◈  Tanaman Biasa  (workspace.AreaTanam)")
for _, c in ipairs(CROPS_BIASA) do
    local crop = c
    T2:CreateToggle({
        Name         = string.format("%s  %s  [Lv.%d]  Jual %d/ea  |  Panen x%d",
            crop.icon, crop.key, crop.minLevel, crop.sellPrice, crop.harvestAmt),
        CurrentValue = true,
        Callback     = function(v) crop.enabled = v end
    })
end

T2:CreateSection("◈  Lahan Besar  (AreaTanamBesar 1-28)")
T2:CreateLabel("  Max 1 lahan per player | Max 2 tanaman | Klaim: 100.000 coins")
T2:CreateLabel("  MaxCropsPerType=1: 1 Sawit + 1 Durian saja!")
for _, c in ipairs(CROPS_BESAR) do
    local crop = c
    T2:CreateToggle({
        Name         = string.format("%s  %s  [Lv.%d]  CustomHarvest  |  Panen x%d",
            crop.icon, crop.key, crop.minLevel, crop.harvestAmt),
        CurrentValue = true,
        Callback     = function(v) crop.enabled = v end
    })
end

T2:CreateSection("◈  Fitur Otomatis")
T2:CreateToggle({ Name="🌾  Auto Panen",               CurrentValue=true,  Callback=function(v) cfg.autoHarvest=v end })
T2:CreateToggle({ Name="🌱  Auto Tanam",               CurrentValue=true,  Callback=function(v) cfg.autoPlant=v   end })
T2:CreateToggle({ Name="🛒  Auto Beli Bibit",          CurrentValue=true,  Callback=function(v) cfg.autoBuy=v     end })
T2:CreateToggle({ Name="💰  Auto Jual  (default OFF)", CurrentValue=false, Callback=function(v) cfg.autoSell=v    end })

-- ─── TAB 3: SETTINGS ─────────────────────────────────────
local T3 = Win:CreateTab("⚙  Settings", 4483362458)

T3:CreateSection("◈  Timing")
T3:CreateSlider({ Name="⏱  Delay Aksi (×0.1s)", Range={1,20}, Increment=1, CurrentValue=4,
    Callback=function(v) cfg.actDelay = v * 0.1 end })
T3:CreateSlider({ Name="🔁  Delay Loop (detik)", Range={1,60}, Increment=1, CurrentValue=3,
    Callback=function(v) cfg.loopDelay = v end })
T3:CreateSlider({ Name="🛒  Jumlah Beli Bibit", Range={10,200}, Increment=10, CurrentValue=50,
    Callback=function(v) cfg.buyAmt = v end })
T3:CreateSlider({ Name="📦  Threshold Beli (beli kalau <)", Range={1,50}, Increment=1, CurrentValue=5,
    Callback=function(v) cfg.minSeedThr = v end })

T3:CreateSection("◈  Sistem")
T3:CreateToggle({ Name="⭐  Notif Level Up", CurrentValue=true, Callback=function(v) cfg.notifLvlUp=v end })
T3:CreateToggle({ Name="🛡  Anti-AFK",       CurrentValue=true, Callback=function(v) cfg.antiAFK=v    end })

-- ─── TAB 4: DEBUG ────────────────────────────────────────
local T4 = Win:CreateTab("🔍  Debug", 4483362458)

T4:CreateSection("◈  Remote Events")
T4:CreateButton({ Name="🔄  Refresh & Cek Remotes", Callback=function()
    buildRemoteMap(); detectRemotes(); logRemotes()
    local names = {"Plant","Harvest","Buy","Sell"}
    local remotes = {RE.plant, RE.harvest, RE.buy, RE.sell}
    for i, name in ipairs(names) do
        Rayfield:Notify({
            Title   = "RE." .. name,
            Content = remotes[i] and ("✅ " .. remotes[i]:GetFullName()) or "❌ Tidak ditemukan",
            Duration = 3, Image = 4483362458
        })
        task.wait(0.4)
    end
end })

T4:CreateButton({ Name="📋  Scan Semua RemoteEvent", Callback=function()
    local count = 0
    for _, obj in ipairs(RS:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            count += 1; print("[SCAN] " .. obj:GetFullName())
        end
    end
    Rayfield:Notify({
        Title   = "📋 Scan Selesai",
        Content = count .. " RemoteEvent\nCek Console F9",
        Duration = 4, Image = 4483362458
    })
end })

T4:CreateSection("◈  NPC & Area")
T4:CreateButton({ Name="📍  Cek Semua NPC", Callback=function()
    for role, name in pairs(NPC_NAMES) do
        local pos = getNPCPos(role)
        Rayfield:Notify({
            Title   = name,
            Content = pos and string.format("✅ %.0f, %.0f, %.0f", pos.X, pos.Y, pos.Z)
                or "❌ Tidak ditemukan — cek workspace.NPCs",
            Duration = 3, Image = 4483362458
        })
        task.wait(0.4)
    end
end })

T4:CreateButton({ Name="🌾  Cek Area Tanam", Callback=function()
    local b = getAreaTanamParts()
    local bb = getAreaBesarParts()
    Rayfield:Notify({
        Title   = "Area Tanam",
        Content = string.format("AreaTanam: %d parts\nAreaTanamBesar (1-28): %d parts", #b, #bb),
        Duration = 4, Image = 4483362458
    })
end })

T4:CreateButton({ Name="📦  Cek Stok Bibit", Callback=function()
    local lines = {}
    for _, c in ipairs(CROPS_BIASA) do
        table.insert(lines, c.icon .. " " .. c.key .. ": " .. getSeedCount(c.key))
    end
    for _, c in ipairs(CROPS_BESAR) do
        table.insert(lines, c.icon .. " " .. c.key .. ": " .. getSeedCount(c.key))
    end
    for _, l in ipairs(lines) do print("[INV] " .. l) end
    Rayfield:Notify({
        Title   = "📦 Stok Bibit",
        Content = table.concat(lines, "\n"),
        Duration = 6, Image = 4483362458
    })
end })

T4:CreateButton({ Name="📊  Info Player", Callback=function()
    Rayfield:Notify({
        Title   = "📊 Player Info",
        Content = string.format("Level: %d\nCoins: %d", getLevel(), getCoins()),
        Duration = 4, Image = 4483362458
    })
end })

-- ─── TAB 5: INFO ─────────────────────────────────────────
local T5 = Win:CreateTab("📋  Info", 4483362458)

T5:CreateSection("◈  Cara Pakai")
T5:CreateLabel("1️⃣   Selesaikan tutorial game terlebih dahulu!")
T5:CreateLabel("2️⃣   Tab 🌱 Tanaman — aktifkan sesuai level kamu")
T5:CreateLabel("3️⃣   Tab 🔍 Debug — pastikan Remote & NPC ✅")
T5:CreateLabel("4️⃣   Tab 🌾 Farm → klik ▶ Mulai Auto Farm")
T5:CreateLabel("5️⃣   Auto Jual default OFF — aktifkan di tab Tanaman")

T5:CreateSection("◈  Tanaman & Harga Jual (CropConfig + SellableItems)")
T5:CreateLabel("🌾  Bibit Padi       Lv.1   | 50-60s    | 🛒5 💰10/ea  | x1")
T5:CreateLabel("🌽  Bibit Jagung     Lv.20  | 80-100s   | 🛒15 💰20/ea | x2")
T5:CreateLabel("🍅  Bibit Tomat      Lv.40  | 120-150s  | 🛒25 💰30/ea | x3")
T5:CreateLabel("🍆  Bibit Terong     Lv.60  | 150-200s  | 🛒40 💰50/ea | x4")
T5:CreateLabel("🍓  Bibit Strawberry Lv.80  | 180-250s  | 🛒60 💰75/ea | x4")
T5:CreateLabel("🌴  Bibit Sawit      Lv.80  | 600-1000s | 🛒1000 💰1500| x4")
T5:CreateLabel("🍈  Bibit Durian     Lv.120 | 800-1200s | 🛒2000 CustomHarvest")

T5:CreateSection("◈  NPC (WorldConfig: folder NPCs)")
T5:CreateLabel("🛒  NPC_Bibit         — Pak Tani  (Beli Bibit)")
T5:CreateLabel("💰  NPC_Penjual       — Pedagang  (Jual Hasil Panen)")
T5:CreateLabel("🌴  NPC_PedagangSawit — Pedagang Sawit/Durian")
T5:CreateLabel("🔨  NPC_Alat          — Toko Alat (tool permanen)")

T5:CreateSection("◈  Lahan Besar (LahanBesarConfig)")
T5:CreateLabel("🏕  AreaTanamBesar1 .. AreaTanamBesar28")
T5:CreateLabel("💰  Harga klaim lahan: 100.000 coins")
T5:CreateLabel("🌱  MaxPerPlayer: 1 lahan")
T5:CreateLabel("🚫  MaxCropsPerType: 1 | MaxTotalCrops: 2")
T5:CreateLabel("📌  Bibit Sawit & Durian HANYA di lahan sendiri!")

T5:CreateSection("◈  Tentang")
T5:CreateLabel("🌾  NAKA Auto Farm v4.0 — Sawah Indo")
T5:CreateLabel("   Dari: CropConfig, LahanBesarConfig,")
T5:CreateLabel("         TutorialConfig, LocaleConfig")

-- ============================
-- INIT
-- ============================
startAntiAFK()
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("  🌾 NAKA AUTO FARM v4.0 — SAWAH INDO 🌾")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
logRemotes()
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
