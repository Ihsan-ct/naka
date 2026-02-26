-- =========================================================
-- 🌾 NAKA AUTO FARM — SAWAH INDO v3.1 (PERBAIKAN 2026)
-- Remote auto-detect lebih pintar, anti-overflow, fallback bagus
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
local PPS        = game:GetService("ProximityPromptService")

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
-- GAME CONFIG
-- ============================
local CROPS_BIASA = {
    { key="Bibit Padi",       icon="🌾", buyPrice=5,    minLevel=1,   growMin=50,  growMax=60,   harvestItem="Padi",       enabled=true },
    { key="Bibit Jagung",     icon="🌽", buyPrice=15,   minLevel=20,  growMin=80,  growMax=100,  harvestItem="Jagung",     enabled=true },
    { key="Bibit Tomat",      icon="🍅", buyPrice=25,   minLevel=40,  growMin=120, growMax=150,  harvestItem="Tomat",      enabled=true },
    { key="Bibit Terong",     icon="🍆", buyPrice=40,   minLevel=60,  growMin=150, growMax=200,  harvestItem="Terong",     enabled=true },
    { key="Bibit Strawberry", icon="🍓", buyPrice=60,   minLevel=80,  growMin=180, growMax=250,  harvestItem="Strawberry", enabled=true },
}

local CROPS_BESAR = {
    { key="Bibit Sawit",  icon="🌴", buyPrice=1000, minLevel=80,  growMin=600, growMax=1000, harvestItem="Sawit",  fruitType="Sawit",  enabled=true },
    { key="Bibit Durian", icon="🍈", buyPrice=2000, minLevel=120, growMin=800, growMax=1200, harvestItem="Durian", fruitType="Durian", enabled=true },
}

local NPC = {
    bibit   = "NPC_Bibit",
    penjual = "NPC_Penjual",
    alat    = "NPC_Alat",
    sawit   = "NPC_PedagangSawit",
}

local AREA = {
    tanam      = "AreaTanam",
    tanamBesar = "AreaTanamBesar",
    totalBesar = 28,
}

-- ============================
-- REMOTE FINDER (PERBAIKAN UTAMA)
-- ============================
local RE_Plant, RE_Harvest, RE_Buy, RE_Sell

local possiblePlant   = {"PlantCrop", "TanamCrop", "PlantSeed", "Tanam", "TanamBibit", "Plant", "SeedPlant"}
local possibleHarvest = {"HarvestCrop", "PanenCrop", "Harvest", "Panen", "PanenHasil", "HarvestAll", "CollectCrop"}
local possibleBuy     = {"BuyItem", "BeliBibit", "BuySeed", "Purchase", "ShopBuy", "Beli", "BuyCrop", "NPCBuy"}
local possibleSell    = {"SellItem", "JualHasil", "Sell", "Jual", "SellCrops", "NPCSell", "SellAll"}

local function findRemote(names, className)
    className = className or "RemoteEvent"
    for _, name in ipairs(names) do
        local r = RS:FindFirstChild(name, true)
        if r and r.ClassName == className then return r end
        r = workspace:FindFirstChild(name, true)
        if r and r.ClassName == className then return r end
    end
    return nil
end

-- Scan pintar (hanya kandidat, anti-overflow)
local function smartScanRemotes()
    local candidates = {}
    for _, obj in ipairs(RS:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local n = obj.Name:lower()
            local full = obj:GetFullName()
            local typeStr = obj.ClassName == "RemoteFunction" and "RemoteFunction" or "RemoteEvent"
            if n:find("tanam") or n:find("plant") or n:find("seed") or n:find("bibit") or n:find("panen") or n:find("harvest") or n:find("beli") or n:find("buy") or n:find("jual") or n:find("sell") or n:find("crop") or n:find("shop") then
                table.insert(candidates, {name = full, type = typeStr, lower = n})
                warn("[NAKA DEBUG] Kandidat: " .. full .. " (" .. typeStr .. ")")
            end
        end
    end
    return candidates
end

-- Jalankan scan sekali saat load
local candidates = smartScanRemotes()

-- Assign berdasarkan keyword prioritas
for _, cand in ipairs(candidates) do
    local n = cand.lower
    if not RE_Plant and (n:find("tanam") or n:find("plant")) then RE_Plant = cand.obj or RS:FindFirstChild(cand.name:match("[^%.]+$"), true) end
    if not RE_Harvest and (n:find("panen") or n:find("harvest")) then RE_Harvest = cand.obj or RS:FindFirstChild(cand.name:match("[^%.]+$"), true) end
    if not RE_Buy and (n:find("beli") or n:find("buy")) then RE_Buy = cand.obj or RS:FindFirstChild(cand.name:match("[^%.]+$"), true) end
    if not RE_Sell and (n:find("jual") or n:find("sell")) then RE_Sell = cand.obj or RS:FindFirstChild(cand.name:match("[^%.]+$"), true) end
end

-- Fallback manual kalau scan gak ketemu
RE_Plant   = RE_Plant   or findRemote(possiblePlant)
RE_Harvest = RE_Harvest or findRemote(possibleHarvest)
RE_Buy     = RE_Buy     or findRemote(possibleBuy)
RE_Sell    = RE_Sell    or findRemote(possibleSell)

print("[NAKA v3.1] Remote Status:")
print("Plant: " .. (RE_Plant and RE_Plant:GetFullName() or "❌ Not found"))
print("Harvest: " .. (RE_Harvest and RE_Harvest:GetFullName() or "❌ Not found"))
print("Buy: " .. (RE_Buy and RE_Buy:GetFullName() or "❌ Not found"))
print("Sell: " .. (RE_Sell and RE_Sell:GetFullName() or "❌ Not found"))

-- ============================
-- HELPER FUNCTIONS (sama, tapi ditambah cache pos NPC)
-- ============================
local npcCache = {}
local function getNPCPos(npcName)
    if npcCache[npcName] then return npcCache[npcName] end
    local found = workspace:FindFirstChild(npcName, true) or (workspace:FindFirstChild("NPCs") and workspace.NPCs:FindFirstChild(npcName, true))
    if not found then return nil end
    local part = found:FindFirstChild("HumanoidRootPart") or found:FindFirstChildWhichIsA("BasePart")
    if part then 
        npcCache[npcName] = part.Position
        return part.Position 
    end
    return nil
end

local function getNPCObj(npcName)
    return workspace:FindFirstChild(npcName, true) or (workspace:FindFirstChild("NPCs") and workspace.NPCs:FindFirstChild(npcName, true))
end

-- getAreaTanamParts & getAreaBesarParts tetap sama, tapi tambah debounce kalau terlalu lambat
-- (kode tetap, skip tulis ulang kalau gak berubah)

-- getVal, getCoins, getLevel, getSeedCount tetap sama

-- tpTo tetap sama

-- firePrompt (perbaikan: tambah HoldDuration kalau prompt hold)
local function firePrompt(obj, actionFilter)
    if not obj then return false end
    local target = obj:IsA("Model") and obj or obj.Parent or obj
    for _, pp in ipairs(target:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            local match = not actionFilter or pp.ActionText:lower():find(actionFilter:lower()) or pp.ObjectText:lower():find(actionFilter:lower())
            if match then
                pcall(function()
                    if pp.HoldDuration > 0 then
                        pp.HoldEnded:Fire(LP)
                    end
                    PPS:PromptTriggered(pp, LP)
                end)
                pcall(function() pp.Triggered:Fire(LP) end)
                return true
            end
        end
    end
    return false
end

-- fireClick tetap sama

-- ============================
-- CONFIG & STATE (tambah debug toggle)
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
    debugPrint  = false,  -- toggle ini di UI kalau mau liat lebih banyak log
}

-- stat & L & upUI tetap sama, tapi tambah debug label kalau perlu

-- buySeeds (perbaikan: coba argumen table & string)
local function buySeeds(crop)
    if not cfg.autoBuy then return end
    if not RE_Buy then 
        print("[BUY] No remote, skip")
        return 
    end

    stat.action = "🛒 Beli " .. crop.icon .. " " .. crop.key
    upUI()

    local pos = getNPCPos(NPC.bibit)
    if pos then tpTo(pos); task.wait(0.5) end

    pcall(function() RE_Buy:FireServer(crop.key, cfg.buyAmt) end)
    task.wait(cfg.actDelay)
    pcall(function() RE_Buy:FireServer({Item = crop.key, Amount = cfg.buyAmt}) end)
    task.wait(cfg.actDelay)
    pcall(function() RE_Buy:FireServer({crop.key, cfg.buyAmt}) end)

    local npc = getNPCObj(NPC.bibit)
    if npc then firePrompt(npc, "beli") or firePrompt(npc, "buy") end
end

-- doHarvest (perbaikan: prioritas remote > prompt, tambah parent check lebih baik)
local function doHarvest()
    -- ... (kode lama tetap, tapi tambah)
    if RE_Harvest then
        pcall(RE_Harvest.FireServer, RE_Harvest) -- tanpa arg dulu
        task.wait(0.1)
    end
    -- scanAndHarvest tetap
end

-- plantBiasa & plantBesar tetap, tapi tambah check tool exist lebih baik

-- doSell tetap

-- farmLoop tetap, tapi tambah pcall lebih banyak untuk stability

-- startFarm, stopFarm, startAFK, watchers tetap

-- UI (tambah toggle debug)
-- Di tab Settings tambah:
T3:CreateToggle({ Name="🛠 Debug Log (F9)", CurrentValue=false,
    Callback=function(v) cfg.debugPrint = v end })

-- INIT
startAFK()
print("[NAKA AUTO FARM v3.1] Loaded - Debug aktif di F9 kalau toggle nyala")

-- END
