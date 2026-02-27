-- =========================================================
-- 🌾 NAKA AUTO FARM — SAWAH INDO v5.0
-- Remote 100% AKURAT dari ReplicatedStorage screenshot:
--
--   RS.Remotes.TutorialRemotes:
--     RequestSell, RequestShop, RequestToolShop
--     ConfirmAction, SyncData, RequestLahan
--
--   RS.Remotes (root level RemoteEvents):
--     GetBibit       ← beli bibit dari NPC_Bibit
--     HarvestCrop    ← panen tanaman biasa
--     PlantCrop      ← tanam di AreaTanam
--     PlantLahanCrop ← tanam di AreaTanamBesar (lahan besar)
--     SellCrop       ← jual hasil panen
--     RefreshShop    ← refresh shop UI
--     ToggleAutoHarvest ← gamepass auto harvest
--     UpdateLevel, UpdateStep, SyncData
--
-- PERBAIKAN dari v4.x:
--   ✅ Nama remote benar semua (GetBibit, SellCrop, PlantLahanCrop)
--   ✅ Tidak spam log "RE.buy tidak ditemukan"
--   ✅ Level check hanya Lv.1+ bisa tanam Padi (benar di Lv.2)
--   ✅ Bibit habis → GetBibit otomatis, tidak infinite skip
--   ✅ Log bersih: tidak repeat tiap loop
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
-- REMOTE EVENTS — NAMA PASTI
-- Dari screenshot ReplicatedStorage
-- ============================
local RemotesFolder        = RS:WaitForChild("Remotes", 10)
local TutorialRemotes      = RemotesFolder and RemotesFolder:FindFirstChild("TutorialRemotes")

-- Fungsi helper cari remote di seluruh RS
local function getRemote(name)
    local r = RS:FindFirstChild(name, true)
    if r then return r end
    -- fallback workspace
    return workspace:FindFirstChild(name, true)
end

-- Remote Events yang sudah PASTI ada (dari screenshot)
local RE = {
    -- PALING PENTING
    getBibit       = getRemote("GetBibit"),          -- beli bibit dari NPC_Bibit
    harvestCrop    = getRemote("HarvestCrop"),        -- panen tanaman biasa
    plantCrop      = getRemote("PlantCrop"),          -- tanam di AreaTanam
    plantLahan     = getRemote("PlantLahanCrop"),     -- tanam di AreaTanamBesar
    sellCrop       = getRemote("SellCrop"),           -- jual hasil panen

    -- PENDUKUNG
    requestSell    = getRemote("RequestSell"),        -- buka UI jual
    requestShop    = getRemote("RequestShop"),        -- buka UI toko bibit
    confirmAction  = getRemote("ConfirmAction"),      -- konfirmasi aksi
    requestLahan   = getRemote("RequestLahan"),       -- klaim lahan besar
    refreshShop    = getRemote("RefreshShop"),        -- refresh toko
    syncData       = getRemote("SyncData"),           -- sync data player
}

-- Log status remote
local function logRemotes()
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("  🌾 NAKA v5.0 — Remote Status:")
    print("  GetBibit    = " .. (RE.getBibit    and "✅ " .. RE.getBibit:GetFullName()    or "❌"))
    print("  HarvestCrop = " .. (RE.harvestCrop and "✅ " .. RE.harvestCrop:GetFullName() or "❌"))
    print("  PlantCrop   = " .. (RE.plantCrop   and "✅ " .. RE.plantCrop:GetFullName()   or "❌"))
    print("  PlantLahan  = " .. (RE.plantLahan  and "✅ " .. RE.plantLahan:GetFullName()  or "❌"))
    print("  SellCrop    = " .. (RE.sellCrop    and "✅ " .. RE.sellCrop:GetFullName()    or "❌"))
    print("  RequestSell = " .. (RE.requestSell and "✅ " .. RE.requestSell:GetFullName() or "❌"))
    print("  RequestShop = " .. (RE.requestShop and "✅ " .. RE.requestShop:GetFullName() or "❌"))
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

-- Retry jika ada yang nil (remote mungkin belum siap saat load)
local function retryRemotes()
    for name, remote in pairs(RE) do
        if not remote then
            -- konversi nama field ke nama Remote (misal getBibit → GetBibit)
            local capitalised = name:sub(1,1):upper() .. name:sub(2)
            RE[name] = getRemote(capitalised) or getRemote(name)
        end
    end
end
task.delay(3, retryRemotes)
task.delay(8, retryRemotes)

logRemotes()

-- Safe FireServer
local function fire(remote, ...)
    if not remote then return false end
    local s, e = pcall(remote.FireServer, remote, ...)
    if not s then warn("[NAKA] FireServer error [" .. remote.Name .. "]: " .. tostring(e)) end
    return s
end

-- ============================
-- DATA TANAMAN (CropConfig)
-- ============================
local CROPS_BIASA = {
    { key="Bibit Padi",       icon="🌾", toolName="BibitTool",      harvestItem="Padi",       harvestAmt=1, sellPrice=10,  buyPrice=5,    minLevel=1,   phaseModel="Bibit_Fase3",      enabled=true },
    { key="Bibit Jagung",     icon="🌽", toolName="JagungTool",     harvestItem="Jagung",     harvestAmt=2, sellPrice=20,  buyPrice=15,   minLevel=20,  phaseModel="Jagung_Fase3",     enabled=true },
    { key="Bibit Tomat",      icon="🍅", toolName="TomatTool",      harvestItem="Tomat",      harvestAmt=3, sellPrice=30,  buyPrice=25,   minLevel=40,  phaseModel="Tomat_Fase3",      enabled=true },
    { key="Bibit Terong",     icon="🍆", toolName="TerongTool",     harvestItem="Terong",     harvestAmt=4, sellPrice=50,  buyPrice=40,   minLevel=60,  phaseModel="Terong_Fase3",     enabled=true },
    { key="Bibit Strawberry", icon="🍓", toolName="StrawberryTool", harvestItem="Strawberry", harvestAmt=4, sellPrice=75,  buyPrice=60,   minLevel=80,  phaseModel="Strawberry_Fase3", enabled=true },
}
local CROPS_BESAR = {
    { key="Bibit Sawit",  icon="🌴", toolName="SawitTool",  harvestItem="Sawit",  harvestAmt=4, sellPrice=1500, buyPrice=1000, minLevel=80,  phaseModel="Sawit_Fase3",  customHarvest=true, fruitType="Sawit",  enabled=true },
    { key="Bibit Durian", icon="🍈", toolName="DurianTool", harvestItem="Durian", harvestAmt=1, sellPrice=nil,  buyPrice=2000, minLevel=120, phaseModel="Durian_Fase3", customHarvest=true, fruitType="Durian", enabled=true },
}

-- LahanBesarConfig
local LAHAN = { areaPrefix="AreaTanamBesar", totalAreas=28, maxTotalCrops=2, maxCropsPerType=1 }

-- NPC (WorldConfig: NPCFolder = "NPCs")
local NPC_FOLDER = "NPCs"
local NPC_NAMES  = { bibit="NPC_Bibit", penjual="NPC_Penjual", alat="NPC_Alat", sawit="NPC_PedagangSawit" }

-- ============================
-- NPC FINDER
-- ============================
local function getNPCObj(role)
    local name = NPC_NAMES[role]
    if not name then return nil end
    local folder = workspace:FindFirstChild(NPC_FOLDER) or workspace:FindFirstChild("NPC")
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
    elseif obj:IsA("BasePart") then return obj.Position end
    return nil
end

-- ============================
-- AREA TANAM
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

local function getAreaTanamParts()
    return collectParts(workspace:FindFirstChild("AreaTanam", true))
end

local function getAreaBesarParts()
    local parts = {}
    for i = 1, LAHAN.totalAreas do
        local area = workspace:FindFirstChild(LAHAN.areaPrefix .. tostring(i), true)
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
local function getSeedCount(key)
    return readStat({ key, key:gsub(" ",""), "Seed_"..key:gsub(" ","") })
end

-- ============================
-- TELEPORT
-- ============================
local lastTP = 0
local function tpTo(pos)
    if not pos or not Root or not Root.Parent then return end
    if (os.clock() - lastTP) < 0.2 then return end
    lastTP = os.clock()
    Root.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
    task.wait(0.2)
end
local function tpIfFar(pos, dist)
    if pos and (Root.Position - pos).Magnitude > (dist or 10) then tpTo(pos) end
end

-- ============================
-- INTERAKSI PROXIMITY / CLICK
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
    local function check(o)
        if not o then return false end
        if o:GetAttribute("Matang") == true then return true end
        if o:GetAttribute("Ready")  == true then return true end
        if o:GetAttribute("Ripe")   == true then return true end
        if o:GetAttribute("CanHarvest") == true then return true end
        local ph = o:GetAttribute("Phase") or o:GetAttribute("GrowPhase") or o:GetAttribute("Stage")
        if ph and tonumber(ph) and tonumber(ph) >= 3 then return true end
        return false
    end
    if check(part) then return true end
    local mdl = part.Parent
    if mdl and mdl:IsA("Model") then
        if check(mdl) then return true end
        -- CropConfig: phase matang = model bernama *_Fase3
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
    loopDelay   = 5,      -- detik antar loop (lebih lambat = lebih aman)
    actDelay    = 0.5,    -- detik antar aksi
    buyAmt      = 50,     -- jumlah bibit dibeli
    minSeedThr  = 5,      -- beli jika stok < ini
    useTP       = true,
}

local stat = {
    running    = false,
    action     = "⏹ Standby",
    harvested  = 0,
    planted    = 0,
    sold       = 0,
    coinsGain  = 0,
    startTime  = os.time(),
    lastLv     = 0,
    lastCoins  = 0,
    loops      = 0,
    errors     = 0,
}

-- Thread registry
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
    pcall(function() L.status:Set("  Status   : " .. (stat.running and "🟢 BERJALAN" or "🔴 BERHENTI")) end)
    pcall(function() L.action:Set("  Aksi     : " .. stat.action) end)
    pcall(function() L.lv:Set("  Level    : " .. getLevel() .. " | Coins: " .. getCoins()) end)
    pcall(function() L.harvest:Set("  Dipanen  : " .. stat.harvested) end)
    pcall(function() L.planted:Set("  Ditanam  : " .. stat.planted) end)
    pcall(function() L.sold:Set("  Terjual  : " .. stat.sold) end)
    pcall(function() L.coins:Set("  Coins +  : " .. stat.coinsGain) end)
    pcall(function() L.loops:Set("  Loop     : " .. stat.loops .. " | Errors: " .. stat.errors) end)
    pcall(function() L.durasi:Set(string.format("  Durasi   : %dm %ds", math.floor(e/60), e%60)) end)
end
local function setAction(txt) stat.action = txt; updateUI() end

-- ============================
-- CORE: BELI BIBIT
-- Remote: GetBibit (dari screenshot RS)
-- TutorialConfig: GET_BIBIT → INTERACT NPC_Bibit
-- ============================
local function buySeeds(crop)
    if not cfg.autoBuy then return end

    -- Cek apakah sudah cukup
    if getSeedCount(crop.key) >= cfg.minSeedThr then return end

    setAction("🛒 Beli " .. crop.icon .. " " .. crop.key)

    local npcObj = getNPCObj("bibit")
    local npcPos = getNPCPos("bibit")

    -- TP ke NPC_Bibit
    if cfg.useTP and npcPos then tpTo(npcPos) end
    task.wait(0.3)

    -- Metode 1: RE GetBibit (nama pasti dari screenshot)
    -- Format: FireServer(seedKey, amount)
    if RE.getBibit then
        fire(RE.getBibit, crop.key, cfg.buyAmt)
        task.wait(cfg.actDelay * 0.5)
        fire(RE.getBibit, { seed=crop.key, amount=cfg.buyAmt })
        task.wait(cfg.actDelay * 0.5)
        fire(RE.getBibit, crop.key)
        task.wait(cfg.actDelay)
    end

    -- Metode 2: RequestShop → buka UI toko, lalu ConfirmAction
    if RE.requestShop then
        fire(RE.requestShop, crop.key)
        task.wait(cfg.actDelay)
    end
    if RE.confirmAction then
        fire(RE.confirmAction, "Buy", crop.key, cfg.buyAmt)
        task.wait(cfg.actDelay * 0.5)
        fire(RE.confirmAction, crop.key, cfg.buyAmt)
        task.wait(cfg.actDelay)
    end

    -- Metode 3: ProximityPrompt NPC langsung
    if npcObj then
        interact(npcObj, {"Beli Bibit", "Beli", "Buy"})
        task.wait(cfg.actDelay)
    end

    local got = getSeedCount(crop.key)
    if got > 0 then
        print(string.format("[NAKA] ✅ Beli %s berhasil! Stok: %d", crop.key, got))
    else
        print(string.format("[NAKA] ⚠️ Beli %s belum terkonfirmasi (stok: %d)", crop.key, got))
    end
end

-- ============================
-- CORE: PANEN
-- Remote: HarvestCrop (dari screenshot RS)
-- ============================
local function doHarvest()
    if not cfg.autoHarvest then return end
    setAction("🌾 Panen semua...")

    -- Metode 1: HarvestCrop tanpa argumen (harvest all)
    if RE.harvestCrop then
        fire(RE.harvestCrop)
        task.wait(cfg.actDelay * 0.5)
        fire(RE.harvestCrop, "All")
        task.wait(cfg.actDelay)
    end

    -- Metode 2: scan per plot yang matang
    local function scanHarvest(parts)
        for _, part in ipairs(parts) do
            if not stat.running then break end
            if not isPlotMature(part) then continue end
            if not isOwnedByMe(part) then continue end

            if cfg.useTP then tpIfFar(part.Position, 8) end

            local target = (part.Parent and part.Parent:IsA("Model")) and part.Parent or part

            if RE.harvestCrop then
                fire(RE.harvestCrop, part)
                task.wait(cfg.actDelay * 0.2)
                if part.Parent and part.Parent:IsA("Model") then
                    fire(RE.harvestCrop, part.Parent)
                    task.wait(cfg.actDelay * 0.2)
                end
            end

            -- ProximityPrompt "Panen" (LocaleConfig: HarvestAction)
            interact(target, {"Panen", "Harvest", "Ambil"})
            stat.harvested = stat.harvested + 1
            task.wait(cfg.actDelay * 0.3)
        end
    end

    scanHarvest(getAreaTanamParts())
    scanHarvest(getAreaBesarParts())
    updateUI()
end

-- ============================
-- CORE: TANAM BIASA
-- Remote: PlantCrop (dari screenshot RS)
-- TutorialConfig: "Equip bibit lalu klik area tanam"
-- CropConfig.ToolName = "BibitTool", "JagungTool", dst.
-- ============================
local function plantBiasa(crop, areaParts)
    if not crop.enabled then return end

    local lv = getLevel()
    -- Level 0 artinya belum bisa dibaca, biarkan jalan
    if lv > 0 and lv < crop.minLevel then return end

    -- Pastikan ada bibit
    if getSeedCount(crop.key) < 1 then
        buySeeds(crop)
        task.wait(0.5)
        if getSeedCount(crop.key) < 1 then return end
    end

    setAction("🌱 Tanam " .. crop.icon .. " " .. crop.key)

    -- Equip tool (CropConfig.ToolName)
    local tool
    for _, tn in ipairs({ crop.toolName, crop.key, crop.key:gsub(" ","") }) do
        tool = LP.Backpack:FindFirstChild(tn)
        if not tool and Char then tool = Char:FindFirstChild(tn) end
        if tool then break end
    end
    if tool and Hum then pcall(function() Hum:EquipTool(tool) end); task.wait(0.25) end

    -- Fire PlantCrop global (server mungkin handle semua plot sekaligus)
    if RE.plantCrop then
        fire(RE.plantCrop, crop.key)
        task.wait(cfg.actDelay * 0.5)
    end

    -- Scan plot kosong & tanam satu per satu
    local planted = 0
    for _, part in ipairs(areaParts) do
        if not stat.running then break end
        if getSeedCount(crop.key) < 1 then break end
        if not isPlotEmpty(part) then continue end

        if cfg.useTP then tpIfFar(part.Position, 8) end

        if RE.plantCrop then
            -- Format: (seedKey, plotPart)
            fire(RE.plantCrop, crop.key, part)
            task.wait(cfg.actDelay * 0.2)
            if part.Parent and part.Parent:IsA("Model") then
                fire(RE.plantCrop, crop.key, part.Parent)
                task.wait(cfg.actDelay * 0.2)
            end
        end

        interact(part, {"Tanam", "Plant", "Semai"})
        planted = planted + 1
        stat.planted = stat.planted + 1
        task.wait(cfg.actDelay * 0.3)
    end

    if Hum then pcall(function() Hum:UnequipTools() end) end
    if planted > 0 then print(string.format("[NAKA] ✅ Ditanam %dx %s", planted, crop.key)) end
end

-- ============================
-- CORE: TANAM LAHAN BESAR
-- Remote: PlantLahanCrop (dari screenshot RS — BERBEDA dari PlantCrop!)
-- LahanBesarConfig: MaxPerPlayer=1, MaxCropsPerType=1, MaxTotalCrops=2
-- ============================
local function plantBesar(crop, areaParts)
    if not crop.enabled then return end

    local lv = getLevel()
    if lv > 0 and lv < crop.minLevel then return end

    if getSeedCount(crop.key) < 1 then
        buySeeds(crop)
        task.wait(0.5)
        if getSeedCount(crop.key) < 1 then return end
    end

    setAction("🌴 Tanam " .. crop.icon .. " " .. crop.key .. " (Lahan Besar)")

    -- Equip tool
    local tool
    for _, tn in ipairs({ crop.toolName, crop.key, crop.key:gsub(" ","") }) do
        tool = LP.Backpack:FindFirstChild(tn)
        if not tool and Char then tool = Char:FindFirstChild(tn) end
        if tool then break end
    end
    if tool and Hum then pcall(function() Hum:EquipTool(tool) end); task.wait(0.25) end

    -- Fire PlantLahanCrop global
    if RE.plantLahan then
        fire(RE.plantLahan, crop.key)
        task.wait(cfg.actDelay * 0.5)
    end

    -- Scan lahan milik kita
    local planted = 0
    for _, part in ipairs(areaParts) do
        if not stat.running then break end
        if getSeedCount(crop.key) < 1 then break end
        if not isPlotEmpty(part) then continue end
        -- Lahan besar WAJIB milik kita (MaxPerPlayer=1)
        if not isOwnedByMe(part) then continue end

        if cfg.useTP then tpIfFar(part.Position, 8) end

        if RE.plantLahan then
            fire(RE.plantLahan, crop.key, part)
            task.wait(cfg.actDelay * 0.2)
            if part.Parent and part.Parent:IsA("Model") then
                fire(RE.plantLahan, crop.key, part.Parent)
                task.wait(cfg.actDelay * 0.2)
            end
        end

        interact(part, {"Tanam", "Plant"})
        planted = planted + 1
        stat.planted = stat.planted + 1
        task.wait(cfg.actDelay * 0.3)
    end

    if Hum then pcall(function() Hum:UnequipTools() end) end
    if planted > 0 then print(string.format("[NAKA] ✅ Ditanam %dx %s (Lahan Besar)", planted, crop.key)) end
end

local function doPlant()
    if not cfg.autoPlant then return end
    local biasaParts = getAreaTanamParts()
    local besarParts = getAreaBesarParts()

    for _, crop in ipairs(CROPS_BIASA) do
        if not stat.running then break end
        pcall(plantBiasa, crop, biasaParts)
        task.wait(cfg.actDelay * 0.3)
    end
    for _, crop in ipairs(CROPS_BESAR) do
        if not stat.running then break end
        pcall(plantBesar, crop, besarParts)
        task.wait(cfg.actDelay * 0.3)
    end
end

-- ============================
-- CORE: JUAL
-- Remote: SellCrop + RequestSell (dari screenshot RS)
-- LocaleConfig: NPC_SellCrops="Jual Hasil Panen", NPC_SellSawit="Jual Sawit"
-- ============================
local function doSell()
    if not cfg.autoSell then return end

    -- Jual hasil biasa → NPC_Penjual
    setAction("💰 Jual ke NPC_Penjual...")
    local npcPenjual = getNPCObj("penjual")
    local posPenjual = getNPCPos("penjual")
    if cfg.useTP and posPenjual then tpTo(posPenjual) end
    task.wait(0.3)

    -- Buka UI jual dulu
    if RE.requestSell then
        fire(RE.requestSell)
        task.wait(cfg.actDelay)
    end
    -- Jual semua
    if RE.sellCrop then
        fire(RE.sellCrop)
        task.wait(cfg.actDelay * 0.4)
        fire(RE.sellCrop, "All")
        task.wait(cfg.actDelay * 0.4)
        -- Jual per item
        for _, c in ipairs(CROPS_BIASA) do
            fire(RE.sellCrop, c.harvestItem)
            task.wait(0.15)
        end
        task.wait(cfg.actDelay)
    end
    if npcPenjual then
        interact(npcPenjual, {"Jual Hasil Panen", "Jual Semua", "Jual", "Sell All", "Sell"})
        task.wait(cfg.actDelay)
    end

    -- Jual Sawit/Durian → NPC_PedagangSawit
    setAction("🌴 Jual Sawit/Durian...")
    local npcSawit = getNPCObj("sawit")
    local posSawit = getNPCPos("sawit")
    if cfg.useTP and posSawit then tpTo(posSawit) end
    task.wait(0.3)

    if RE.requestSell then fire(RE.requestSell, "Sawit"); task.wait(cfg.actDelay) end
    if RE.sellCrop then
        fire(RE.sellCrop, "Sawit")
        task.wait(cfg.actDelay * 0.4)
        fire(RE.sellCrop, "Durian")
        task.wait(cfg.actDelay)
    end
    if npcSawit then
        interact(npcSawit, {"Jual Sawit", "Jual Buah", "Sell Palm"})
        task.wait(cfg.actDelay)
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
        Content = "v5.0 — Remote names akurat dari game!\nLevel: " .. getLevel(),
        Duration = 4, Image = 4483362458
    })

    while stat.running do
        stat.loops = stat.loops + 1

        -- 1. Panen
        local okH = pcall(doHarvest)
        if not okH then stat.errors += 1 end
        if not stat.running then break end
        task.wait(cfg.actDelay)

        -- 2. Jual (opsional)
        if cfg.autoSell then
            local okS = pcall(doSell)
            if not okS then stat.errors += 1 end
            if not stat.running then break end
            task.wait(cfg.actDelay)
        end

        -- 3. Tanam
        local okP = pcall(doPlant)
        if not okP then stat.errors += 1 end
        if not stat.running then break end
        task.wait(cfg.actDelay)

        -- 4. Coin tracker
        local cur = getCoins()
        if cur > stat.lastCoins then stat.coinsGain += (cur - stat.lastCoins) end
        stat.lastCoins = cur

        -- 5. Tunggu
        setAction(string.format("⏳ Tunggu %ds... (loop #%d | Lv.%d)", cfg.loopDelay, stat.loops, getLevel()))
        local w = 0
        while w < cfg.loopDelay and stat.running do task.wait(0.5); w += 0.5 end
    end

    setAction("⏹ Dihentikan")
    Rayfield:Notify({
        Title   = "⏹ Auto Farm Stop",
        Content = string.format("Panen: %d | Tanam: %d | Loop: %d", stat.harvested, stat.planted, stat.loops),
        Duration = 5, Image = 4483362458
    })
end

local function startFarm()
    if stat.running then return end
    stat.running   = true
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
task.spawn(function()
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
                print("[NAKA] ⭐ Level up! " .. stat.lastLv .. " → " .. lv)
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
    LoadingSubtitle     = "[ v5.0  •  Remote Names 100% Akurat ]",
    ConfigurationSaving = { Enabled=true, FolderName="NAKA", FileName="AutoFarm_v5" },
    Discord             = { Enabled=false },
    KeySystem           = false,
})
Rayfield:LoadConfiguration()

Rayfield:Notify({
    Title   = "🌾 NAKA Auto Farm v5.0",
    Content = "GetBibit:" .. (RE.getBibit and "✅" or "❌")
        .. " HarvestCrop:" .. (RE.harvestCrop and "✅" or "❌")
        .. "\nPlantCrop:" .. (RE.plantCrop and "✅" or "❌")
        .. " SellCrop:" .. (RE.sellCrop and "✅" or "❌"),
    Duration = 6, Image = 4483362458
})

-- ─── TAB 1: FARM ─────────────────────────────────────────
local T1 = Win:CreateTab("🌾  Farm", 4483362458)

T1:CreateSection("◈  Status Real-Time")
L.status  = T1:CreateLabel("  Status   : 🔴 BERHENTI")
L.action  = T1:CreateLabel("  Aksi     : ⏹ Standby")
L.lv      = T1:CreateLabel("  Level    : -")
L.harvest = T1:CreateLabel("  Dipanen  : 0")
L.planted = T1:CreateLabel("  Ditanam  : 0")
L.sold    = T1:CreateLabel("  Terjual  : 0")
L.coins   = T1:CreateLabel("  Coins +  : 0")
L.loops   = T1:CreateLabel("  Loop     : 0 | Errors: 0")
L.durasi  = T1:CreateLabel("  Durasi   : 0m 0s")

T1:CreateSection("◈  Kontrol Utama")
T1:CreateButton({ Name="▶  Mulai Auto Farm", Callback=startFarm })
T1:CreateButton({ Name="⏹  Stop Auto Farm",  Callback=stopFarm  })
T1:CreateToggle({ Name="📍  Teleport Mode", CurrentValue=true, Callback=function(v) cfg.useTP=v end })

T1:CreateSection("◈  Aksi Manual")
T1:CreateButton({ Name="🌾  Panen Sekarang",    Callback=function() spawnThread(doHarvest) end })
T1:CreateButton({ Name="🌱  Tanam Sekarang",    Callback=function() spawnThread(doPlant) end })
T1:CreateButton({ Name="💰  Jual Sekarang",
    Callback=function()
        local old = cfg.autoSell; cfg.autoSell = true
        spawnThread(function() pcall(doSell); cfg.autoSell = old end)
    end })
T1:CreateButton({ Name="🛒  Beli Bibit Padi Sekarang",
    Callback=function() spawnThread(function() buySeeds(CROPS_BIASA[1]) end) end })

-- ─── TAB 2: TANAMAN ──────────────────────────────────────
local T2 = Win:CreateTab("🌱  Tanaman", 4483362458)

T2:CreateSection("◈  Tanaman Biasa  (PlantCrop → AreaTanam)")
for _, c in ipairs(CROPS_BIASA) do
    local crop = c
    T2:CreateToggle({
        Name         = string.format("%s  %s  [Lv.%d]  💰%d/ea  ×%d",
            crop.icon, crop.key, crop.minLevel, crop.sellPrice, crop.harvestAmt),
        CurrentValue = true,
        Callback     = function(v) crop.enabled = v end
    })
end

T2:CreateSection("◈  Lahan Besar  (PlantLahanCrop → AreaTanamBesar 1-28)")
T2:CreateLabel("  Perlu klaim lahan sendiri! Max 1 lahan, 2 tanaman total")
T2:CreateLabel("  MaxCropsPerType=1: max 1 Sawit + 1 Durian")
for _, c in ipairs(CROPS_BESAR) do
    local crop = c
    T2:CreateToggle({
        Name         = string.format("%s  %s  [Lv.%d]  CustomHarvest  ×%d",
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
T3:CreateSlider({ Name="⏱  Delay Aksi (×0.1s)", Range={1,20}, Increment=1, CurrentValue=5,
    Callback=function(v) cfg.actDelay = v * 0.1 end })
T3:CreateSlider({ Name="🔁  Delay Loop (detik)", Range={1,60}, Increment=1, CurrentValue=5,
    Callback=function(v) cfg.loopDelay = v end })
T3:CreateSlider({ Name="🛒  Jumlah Beli Bibit", Range={10,200}, Increment=10, CurrentValue=50,
    Callback=function(v) cfg.buyAmt = v end })
T3:CreateSlider({ Name="📦  Threshold Beli (beli jika < ini)", Range={1,50}, Increment=1, CurrentValue=5,
    Callback=function(v) cfg.minSeedThr = v end })

T3:CreateSection("◈  Sistem")
T3:CreateToggle({ Name="⭐  Notif Level Up", CurrentValue=true, Callback=function(v) cfg.notifLvlUp=v end })
T3:CreateToggle({ Name="🛡  Anti-AFK",       CurrentValue=true, Callback=function(v) cfg.antiAFK=v    end })

-- ─── TAB 4: DEBUG ────────────────────────────────────────
local T4 = Win:CreateTab("🔍  Debug", 4483362458)

T4:CreateSection("◈  Remote Events (nama pasti dari RS)")
T4:CreateButton({ Name="🔄  Refresh & Cek Remotes", Callback=function()
    retryRemotes(); logRemotes()
    local checks = {
        {"GetBibit",       RE.getBibit},
        {"HarvestCrop",    RE.harvestCrop},
        {"PlantCrop",      RE.plantCrop},
        {"PlantLahanCrop", RE.plantLahan},
        {"SellCrop",       RE.sellCrop},
        {"RequestSell",    RE.requestSell},
        {"RequestShop",    RE.requestShop},
    }
    for _, v in ipairs(checks) do
        Rayfield:Notify({
            Title   = v[1],
            Content = v[2] and ("✅ " .. v[2]:GetFullName()) or "❌ Tidak ditemukan",
            Duration = 2, Image = 4483362458
        })
        task.wait(0.3)
    end
end })

T4:CreateSection("◈  NPC & Area")
T4:CreateButton({ Name="📍  Cek Semua NPC", Callback=function()
    for role, name in pairs(NPC_NAMES) do
        local pos = getNPCPos(role)
        Rayfield:Notify({
            Title   = name,
            Content = pos and string.format("✅ %.0f, %.0f, %.0f", pos.X, pos.Y, pos.Z)
                or "❌ Tidak ditemukan — cek workspace." .. NPC_FOLDER,
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

T4:CreateButton({ Name="📦  Cek Stok Bibit + Level", Callback=function()
    local lv = getLevel()
    local lines = {string.format("Level: %d | Coins: %d", lv, getCoins()), ""}
    for _, c in ipairs(CROPS_BIASA) do
        local unlocked = lv >= c.minLevel
        table.insert(lines, string.format("%s %s: %d %s",
            c.icon, c.key, getSeedCount(c.key), unlocked and "✅" or ("🔒Lv."..c.minLevel)))
    end
    for _, c in ipairs(CROPS_BESAR) do
        local unlocked = lv >= c.minLevel
        table.insert(lines, string.format("%s %s: %d %s",
            c.icon, c.key, getSeedCount(c.key), unlocked and "✅" or ("🔒Lv."..c.minLevel)))
    end
    for _, l in ipairs(lines) do print("[NAKA] " .. l) end
    Rayfield:Notify({
        Title   = "📦 Stok & Level",
        Content = table.concat(lines, "\n"),
        Duration = 8, Image = 4483362458
    })
end })

T4:CreateButton({ Name="🧪  Test GetBibit (beli 1 Bibit Padi)", Callback=function()
    spawnThread(function()
        local before = getSeedCount("Bibit Padi")
        fire(RE.getBibit, "Bibit Padi", 1)
        task.wait(1)
        local after = getSeedCount("Bibit Padi")
        Rayfield:Notify({
            Title   = "🧪 Test GetBibit",
            Content = string.format("Sebelum: %d | Sesudah: %d\n%s",
                before, after, after > before and "✅ Berhasil!" or "❌ Tidak berubah"),
            Duration = 5, Image = 4483362458
        })
    end)
end })

-- ─── TAB 5: INFO ─────────────────────────────────────────
local T5 = Win:CreateTab("📋  Info", 4483362458)

T5:CreateSection("◈  Remote Events (dari screenshot RS)")
T5:CreateLabel("🔵 GetBibit       — beli bibit dari NPC_Bibit")
T5:CreateLabel("🔵 HarvestCrop    — panen tanaman")
T5:CreateLabel("🔵 PlantCrop      — tanam di AreaTanam")
T5:CreateLabel("🔵 PlantLahanCrop — tanam di AreaTanamBesar")
T5:CreateLabel("🔵 SellCrop       — jual hasil panen")
T5:CreateLabel("🔵 RequestSell    — buka UI jual")
T5:CreateLabel("🔵 RequestShop    — buka UI toko bibit")
T5:CreateLabel("🔵 RequestLahan   — klaim lahan besar")

T5:CreateSection("◈  Data Tanaman (CropConfig + SellableItems)")
T5:CreateLabel("🌾 Bibit Padi       Lv.1   | 50-60s    | 🛒5   💰10/ea | ×1")
T5:CreateLabel("🌽 Bibit Jagung     Lv.20  | 80-100s   | 🛒15  💰20/ea | ×2")
T5:CreateLabel("🍅 Bibit Tomat      Lv.40  | 120-150s  | 🛒25  💰30/ea | ×3")
T5:CreateLabel("🍆 Bibit Terong     Lv.60  | 150-200s  | 🛒40  💰50/ea | ×4")
T5:CreateLabel("🍓 Bibit Strawberry Lv.80  | 180-250s  | 🛒60  💰75/ea | ×4")
T5:CreateLabel("🌴 Bibit Sawit      Lv.80  | 600-1000s | 🛒1000 💰1500 | ×4")
T5:CreateLabel("🍈 Bibit Durian     Lv.120 | 800-1200s | 🛒2000 CustomHarvest")

T5:CreateSection("◈  Tentang")
T5:CreateLabel("🌾  NAKA Auto Farm v5.0 — Sawah Indo")
T5:CreateLabel("   Remote names 100% dari ReplicatedStorage")

-- ============================
-- INIT
-- ============================
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("  🌾 NAKA AUTO FARM v5.0 — SAWAH INDO 🌾")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
logRemotes()
