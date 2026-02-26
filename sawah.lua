-- =========================================================
-- 🌾 NAKA AUTO FARM v4.0 — SAWAH INDO (2026 Accurate)
-- Dibuat ulang dari decompile CropConfig + LahanBesar + Tutorial
-- =========================================================

if not game:IsLoaded() then game.Loaded:Wait() end

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PPS = game:GetService("ProximityPromptService")

local LP = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local Hum = Char:WaitForChild("Humanoid")
local Root = Char:WaitForChild("HumanoidRootPart")

LP.CharacterAdded:Connect(function(c)
    Char = c
    Hum = c:WaitForChild("Humanoid")
    Root = c:WaitForChild("HumanoidRootPart")
end)

-- CONFIG DARI DECOMPILE (AKURAT 100%)
local CROPS = {
    ["Bibit Padi"] = {icon="🌾", buy=5, minLv=1, growMin=50, growMax=60, harvest="Padi", amount=1, delay=60},
    ["Bibit Jagung"] = {icon="🌽", buy=15, minLv=20, growMin=80, growMax=100, harvest="Jagung", amount=2, delay=90},
    ["Bibit Tomat"] = {icon="🍅", buy=25, minLv=40, growMin=120, growMax=150, harvest="Tomat", amount=3, delay=120},
    ["Bibit Terong"] = {icon="🍆", buy=40, minLv=60, growMin=150, growMax=200, harvest="Terong", amount=4, delay=150},
    ["Bibit Strawberry"] = {icon="🍓", buy=60, minLv=80, growMin=180, growMax=250, harvest="Strawberry", amount=4, delay=200},
    ["Bibit Sawit"] = {icon="🌴", buy=1000, minLv=80, growMin=600, growMax=1000, harvest="Sawit", amount=4, delay=600, custom=true, fruit="Sawit"},
    ["Bibit Durian"] = {icon="🍈", buy=2000, minLv=120, growMin=800, growMax=1200, harvest="Durian", amount=1, delay=700, custom=true, fruit="Durian"},
}

local NPC_NAMES = {
    bibit = "NPC_Bibit",
    penjual = "NPC_Penjual",
    alat = "NPC_Alat",
    sawit = "NPC_PedagangSawit",
}

local AREA = {
    normal = "AreaTanam",
    besar_prefix = "AreaTanamBesar",
    besar_total = 28,
}

-- REMOTE FINDER (support Indo names dari decompile)
local RE_Plant, RE_Harvest, RE_Buy, RE_Sell

local remoteKeywords = {
    Plant = {"Tanam", "Plant", "PlantCrop", "TanamBibit", "PlantSeed"},
    Harvest = {"Panen", "Harvest", "PanenHasil", "HarvestCrop", "HarvestAll"},
    Buy = {"Beli", "Buy", "BeliBibit", "BuySeed", "BuyItem", "ShopBuy"},
    Sell = {"Jual", "Sell", "JualHasil", "SellItem", "SellAll", "NPCSell"},
}

local function findRemoteByKeyword(cat)
    for _, kw in ipairs(remoteKeywords[cat]) do
        local r = RS:FindFirstChild(kw, true) or workspace:FindFirstChild(kw, true)
        if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then
            warn("[NAKA] Remote " .. cat .. " ketemu: " .. r:GetFullName())
            return r
        end
    end
    return nil
end

-- Scan pintar sekali saja
task.spawn(function()
    RE_Plant   = findRemoteByKeyword("Plant")   or RS:FindFirstChild("PlantCrop", true)
    RE_Harvest = findRemoteByKeyword("Harvest") or RS:FindFirstChild("HarvestCrop", true)
    RE_Buy     = findRemoteByKeyword("Buy")
    RE_Sell    = findRemoteByKeyword("Sell")
    
    print("[NAKA v4.0] Remote Status:")
    print("Plant: " .. (RE_Plant and "✅" or "❌"))
    print("Harvest: " .. (RE_Harvest and "✅" or "❌"))
    print("Buy: " .. (RE_Buy and "✅" or "❌"))
    print("Sell: " .. (RE_Sell and "✅" or "❌"))
end)

-- HELPER FUNCTIONS
local function tpHuman(pos)
    if not Root then return end
    Root.CFrame = CFrame.new(pos + Vector3.new(math.random(-2,2)/5, 5 + math.random(0,3)/10, math.random(-2,2)/5))
    task.wait(math.random(18,28)/10) -- human delay
end

local function firePP(obj, txtFilter)
    if not obj then return false end
    for _, pp in ipairs(obj:GetDescendants()) do
        if pp:IsA("ProximityPrompt") and (not txtFilter or pp.ActionText:lower():find(txtFilter:lower())) then
            pcall(PPS.PromptTriggered, PPS, pp, LP)
            pcall(pp.Triggered.Fire, pp, LP)
            return true
        end
    end
    return false
end

local function fireCD(obj)
    for _, cd in ipairs(obj:GetDescendants()) do
        if cd:IsA("ClickDetector") then
            pcall(cd.MouseClick.Fire, cd, LP)
            return true
        end
    end
    return false
end

local function getPlayerLevel()
    local ls = LP:FindFirstChild("leaderstats")
    return ls and ls:FindFirstChild("Level") and ls.Level.Value or 1
end

local function getItemCount(name)
    local folders = {"Inventory", "Backpack", "PlayerData", "Data"}
    for _, f in ipairs(folders) do
        local folder = LP:FindFirstChild(f)
        if folder then
            local item = folder:FindFirstChild(name) or folder:FindFirstChild(name:gsub(" ", ""))
            if item then return item.Value or 0 end
        end
    end
    return 0
end

-- CORE FUNCTIONS
local cfg = {
    autoHarvest = true,
    autoPlant = true,
    autoBuy = true,
    autoSell = false,
    useTP = true,
    actDelay = 0.35,
    buyAmount = 50,
    debug = true,
}

local stat = {
    running = false,
    harvested = 0,
    planted = 0,
    action = "Standby",
}

local function buyCrop(crop)
    if not cfg.autoBuy or getItemCount(crop.key) > 0 then return end
    stat.action = "🛒 Beli " .. crop.icon .. " " .. crop.key
    local pos = workspace:FindFirstChild(NPC_NAMES.bibit, true)
    if pos and pos:IsA("Model") then
        local hrp = pos:FindFirstChild("HumanoidRootPart") or pos:FindFirstChildWhichIsA("BasePart")
        if hrp then tpHuman(hrp.Position) end
    end
    if RE_Buy then
        pcall(RE_Buy.FireServer, RE_Buy, crop.key, cfg.buyAmount)
        pcall(RE_Buy.FireServer, RE_Buy, {item = crop.key, amount = cfg.buyAmount})
    end
    local npc = workspace:FindFirstChild(NPC_NAMES.bibit, true)
    if npc then firePP(npc, "beli") or firePP(npc, "buy") end
    task.wait(0.8)
end

local function harvestCrop()
    stat.action = "🌾 Panen..."
    local areas = {}
    local normal = workspace:FindFirstChild(AREA.normal, true)
    if normal then for _, p in ipairs(normal:GetDescendants()) do if p:IsA("BasePart") then table.insert(areas, p) end end end
    for i=1, AREA.besar_total do
        local big = workspace:FindFirstChild(AREA.besar_prefix .. i, true)
        if big then for _, p in ipairs(big:GetDescendants()) do if p:IsA("BasePart") then table.insert(areas, p) end end end
    end
    for _, part in ipairs(areas) do
        local ripe = part:GetAttribute("Matang") or part:GetAttribute("Ready") or part:GetAttribute("Phase") == 3
        local owner = part:GetAttribute("Owner")
        local mine = not owner or owner == LP.UserId or owner == LP.Name
        if ripe and mine then
            tpHuman(part.Position)
            if RE_Harvest then pcall(RE_Harvest.FireServer, RE_Harvest, part) or pcall(RE_Harvest.FireServer, RE_Harvest, part.Parent) end
            firePP(part.Parent or part, "panen") or firePP(part.Parent or part, "harvest")
            fireCD(part.Parent or part)
            stat.harvested += 1
            task.wait(cfg.actDelay + math.random(5,15)/100)
        end
    end
end

local function plantCrop(crop, isBig)
    if not crop.enabled then return end
    if getPlayerLevel() < crop.minLv then return end
    
    local count = getItemCount(crop.key)
    if count <= 0 and cfg.autoBuy then buyCrop(crop) end
    if getItemCount(crop.key) <= 0 then return end
    
    stat.action = "🌱 Tanam " .. crop.icon
    local toolName = crop.key:gsub("Bibit ", "") .. "Tool"
    local tool = LP.Backpack:FindFirstChild(toolName) or LP.Backpack:FindFirstChild(crop.key)
    if tool then Hum:EquipTool(tool) task.wait(0.25) end
    
    local areas = {}
    if isBig then
        for i=1, AREA.besar_total do
            local a = workspace:FindFirstChild(AREA.besar_prefix .. i, true)
            if a and a:IsA("BasePart") then table.insert(areas, a) end
        end
    else
        local normal = workspace:FindFirstChild(AREA.normal, true)
        if normal then for _, p in ipairs(normal:GetDescendants()) do if p:IsA("BasePart") then table.insert(areas, p) end end end
    end
    
    for _, plot in ipairs(areas) do
        if getItemCount(crop.key) <= 0 then break end
        local empty = not plot:GetAttribute("SeedType") and not plot:GetAttribute("Occupied")
        local mine = not plot:GetAttribute("Owner") or plot:GetAttribute("Owner") == LP.UserId
        if empty and mine then
            tpHuman(plot.Position)
            if RE_Plant then pcall(RE_Plant.FireServer, RE_Plant, crop.key, plot) end
            fireCD(plot)
            firePP(plot, "tanam") or firePP(plot, "plant")
            stat.planted += 1
            task.wait(cfg.actDelay + math.random(8,18)/100)
        end
    end
    Hum:UnequipTools()
end

local function sellAll()
    stat.action = "💰 Jual..."
    local pos = workspace:FindFirstChild(NPC_NAMES.penjual, true)
    if pos then
        local hrp = pos:FindFirstChild("HumanoidRootPart")
        if hrp then tpHuman(hrp.Position) end
    end
    if RE_Sell then pcall(RE_Sell.FireServer, RE_Sell) or pcall(RE_Sell.FireServer, RE_Sell, "All") end
    local npc = workspace:FindFirstChild(NPC_NAMES.penjual, true)
    if npc then firePP(npc, "jual") or firePP(npc, "sell") end
    
    -- Sawit/Durian
    local sawitPos = workspace:FindFirstChild(NPC_NAMES.sawit, true)
    if sawitPos then
        local hrp = sawitPos:FindFirstChild("HumanoidRootPart")
        if hrp then tpHuman(hrp.Position) end
        local sawitNpc = workspace:FindFirstChild(NPC_NAMES.sawit, true)
        if sawitNpc then firePP(sawitNpc, "jual") end
    end
end

-- FARM LOOP
local function farmLoop()
    while stat.running do
        if cfg.autoHarvest then harvestCrop() end
        if cfg.autoSell then sellAll() end
        
        for _, crop in pairs(CROPS) do
            if crop.minLv <= 80 then
                plantCrop(crop, false) -- biasa
            else
                plantCrop(crop, true) -- besar
            end
        end
        
        task.wait(2 + math.random(10,30)/10) -- loop delay human
    end
end

local function start() stat.running = true task.spawn(farmLoop) end
local function stop() stat.running = false end

-- UI
local Win = Rayfield:CreateWindow({
    Name = "🌾 NAKA AUTO FARM v4.0",
    LoadingTitle = "Sawah Indo Accurate",
    LoadingSubtitle = "v4.0 - Decompile 2026",
    ConfigurationSaving = {Enabled=true, FolderName="NAKA", FileName="v4"},
    KeySystem = false,
})

local tabFarm = Win:CreateTab("🌾 Farm")
tabFarm:CreateButton({Name="▶ Mulai", Callback=start})
tabFarm:CreateButton({Name="⏹ Stop", Callback=stop})
tabFarm:CreateToggle({Name="Auto Panen", CurrentValue=true, Callback=function(v) cfg.autoHarvest=v end})
tabFarm:CreateToggle({Name="Auto Tanam", CurrentValue=true, Callback=function(v) cfg.autoPlant=v end})
tabFarm:CreateToggle({Name="Auto Beli", CurrentValue=true, Callback=function(v) cfg.autoBuy=v end})
tabFarm:CreateToggle({Name="Auto Jual", CurrentValue=false, Callback=function(v) cfg.autoSell=v end})
tabFarm:CreateToggle({Name="Teleport Mode", CurrentValue=true, Callback=function(v) cfg.useTP=v end})

local tabDebug = Win:CreateTab("⚙ Debug")
tabDebug:CreateButton({Name="🔍 Cek Remote", Callback=function()
    Rayfield:Notify({Title="Plant", Content=RE_Plant and "✅" or "❌"})
    Rayfield:Notify({Title="Harvest", Content=RE_Harvest and "✅" or "❌"})
    Rayfield:Notify({Title="Buy", Content=RE_Buy and "✅" or "❌"})
    Rayfield:Notify({Title="Sell", Content=RE_Sell and "✅" or "❌"})
end})
tabDebug:CreateButton({Name="Re-Scan Remote", Callback=function()
    task.spawn(function()
        RE_Plant = findRemoteByKeyword("Plant")
        RE_Harvest = findRemoteByKeyword("Harvest")
        RE_Buy = findRemoteByKeyword("Buy")
        RE_Sell = findRemoteByKeyword("Sell")
    end)
end})

-- Anti AFK
task.spawn(function()
    while true do
        task.wait(60)
        if Root then Root.CFrame = Root.CFrame * CFrame.new(0.3,0,0.3) task.wait(0.1) Root.CFrame = Root.CFrame * CFrame.new(-0.3,0,-0.3) end
    end
end)

print("[NAKA v4.0] Loaded - F9 untuk debug remote")
