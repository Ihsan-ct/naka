-- =========================================================
-- 🌾 NAKA AUTO FARM — SAWAH INDO v3.2 (PERBAIKI 2026)
-- Fix syntax, remote Indo names, anti-overflow, fallback full
-- =========================================================

if not game:IsLoaded() then game.Loaded:Wait() end

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local PPS = game:GetService('ProximityPromptService')

local LP = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local Hum = Char:WaitForChild('Humanoid')
local Root = Char:WaitForChild('HumanoidRootPart')

LP.CharacterAdded:Connect(function(c)
    Char = c
    Hum = c:WaitForChild('Humanoid')
    Root = c:WaitForChild('HumanoidRootPart')
end)

-- Config Crops & NPC (sama)
local CROPS_BIASA = {
    {key = "Bibit Padi", icon = "🌾", minLevel = 1, enabled = true},
    {key = "Bibit Jagung", icon = "🌽", minLevel = 20, enabled = true},
    {key = "Bibit Tomat", icon = "🍅", minLevel = 40, enabled = true},
    {key = "Bibit Terong", icon = "🍆", minLevel = 60, enabled = true},
    {key = "Bibit Strawberry", icon = "🍓", minLevel = 80, enabled = true},
}

local CROPS_BESAR = {
    {key = "Bibit Sawit", icon = "🌴", minLevel = 80, enabled = true},
    {key = "Bibit Durian", icon = "🍈", minLevel = 120, enabled = true},
}

local NPC = {bibit = "NPC_Bibit", penjual = "NPC_Penjual", sawit = "NPC_PedagangSawit"}
local AREA = {tanam = "AreaTanam", tanamBesar = "AreaTanamBesar", totalBesar = 28}

-- Remote Variables
local RE_Plant, RE_Harvest, RE_Buy, RE_Sell = nil, nil, nil, nil

-- Smart Remote Finder (Perbaikan utama)
local function findRemote(names)
    for _, name in ipairs(names) do
        local r = RS:FindFirstChild(name, true) or workspace:FindFirstChild(name, true)
        if r and (r:IsA('RemoteEvent') or r:IsA('RemoteFunction')) then return r end
    end
    return nil
end

local function scanRemotes()
    local candidates = {}
    for _, obj in ipairs(RS:GetDescendants()) do
        if obj:IsA('RemoteEvent') or obj:IsA('RemoteFunction') then
            local n = obj.Name:lower()
            if n:find('tanam') or n:find('plant') or n:find('panen') or n:find('harvest') or n:find('beli') or n:find('buy') or n:find('jual') or n:find('sell') or n:find('bibit') or n:find('seed') or n:find('crop') then
                table.insert(candidates, obj)
                warn('[NAKA SCAN] ' .. obj:GetFullName() .. ' (' .. obj.ClassName .. ')')
            end
        end
    end
    return candidates
end

-- Jalankan scan
local cands = scanRemotes()

-- Assign dari kandidat & list lengkap
local plantNames = {'PlantCrop', 'TanamCrop', 'TanamBibit', 'PlantSeed', 'Tanam', 'Plant', 'SeedPlant', 'PlantBibit'}
local harvestNames = {'HarvestCrop', 'PanenCrop', 'PanenHasil', 'Harvest', 'Panen', 'HarvestAll'}
local buyNames = {'BuyItem', 'BeliBibit', 'BuySeed', 'Beli', 'Buy', 'ShopBuy', 'Purchase'}
local sellNames = {'SellItem', 'JualHasil', 'Jual', 'Sell', 'SellAll', 'NPCSell'}

RE_Plant = findRemote(plantNames)
RE_Harvest = findRemote(harvestNames)
RE_Buy = findRemote(buyNames)
RE_Sell = findRemote(sellNames)

print('[NAKA v3.2] Remote OK:')
print('Plant: ' .. (RE_Plant and '✅' or '❌'))
print('Harvest: ' .. (RE_Harvest and '✅' or '❌'))
print('Buy: ' .. (RE_Buy and '✅' or '❌'))
print('Sell: ' .. (RE_Sell and '✅' or '❌'))

-- Helper (perbaikan cache & random delay anti-ban)
local npcPosCache = {}
local function getNPCPos(name)
    if npcPosCache[name] then return npcPosCache[name] end
    local npc = workspace:FindFirstChild(name, true) or workspace.NPCs:FindFirstChild(name)
    if npc then
        local part = npc:FindFirstChild('HumanoidRootPart') or npc:FindFirstChildWhichIsA('BasePart')
        if part then npcPosCache[name] = part.Position return part.Position end
    end
    return nil
end

local function tpTo(pos)
    if Root then
        Root.CFrame = CFrame.new(pos + Vector3.new(math.random(-3,3)/10, 5, math.random(-3,3)/10)) -- Humanize
        task.wait(math.random(15,25)/10)
    end
end

local function firePrompt(obj, filter)
    if not obj then return false end
    for _, pp in ipairs(obj:GetDescendants()) do
        if pp:IsA('ProximityPrompt') then
            if not filter or pp.ActionText:lower():find(filter:lower()) then
                pcall(PPS.PromptTriggered, PPS, pp, LP)
                pcall(pp.Triggered.Fire, pp, LP)
                return true
            end
        end
    end
    return false
end

local function fireClick(obj)
    if not obj then return false end
    for _, cd in ipairs(obj:GetDescendants()) do
        if cd:IsA('ClickDetector') then
            pcall(cd.MouseClick.Fire, cd, LP)
            return true
        end
    end
    return false
end

local function getLevel() 
    local ls = LP.leaderstats
    return ls and ls:FindFirstChild('Level') and ls.Level.Value or 1 
end

local function getSeedCount(key)
    local noSpace = key:gsub(' ', '')
    local inv = LP:FindFirstChild('Inventory') or LP.Backpack
    local v = inv:FindFirstChild(key) or inv:FindFirstChild(noSpace)
    return v and v.Value or 0
end

-- Core Functions (perbaikan fallback)
local cfg = {autoHarvest = true, autoPlant = true, autoBuy = true, autoSell = false, useTP = true, actDelay = 0.3, buyAmt = 50, debug = false}

local stat = {running = false, harvested = 0, planted = 0, action = 'Standby'}

local function doHarvest()
    stat.action = '🌾 Panen'
    local parts = {}
    -- Collect all area parts
    local area = workspace:FindFirstChild('AreaTanam', true)
    if area then for _, p in ipairs(area:GetDescendants()) do if p:IsA('BasePart') then table.insert(parts, p) end end end
    for i = 1, 28 do
        local big = workspace:FindFirstChild('AreaTanamBesar' .. i, true)
        if big then for _, p in ipairs(big:GetDescendants()) do if p:IsA('BasePart') then table.insert(parts, p) end end end
    end
    for _, part in ipairs(parts) do
        local matang = part:GetAttribute('Matang') or part:GetAttribute('Ready') or part:GetAttribute('Phase') == 3
        local owner = part:GetAttribute('Owner')
        local isMine = not owner or owner == LP.UserId or owner == LP.Name
        if matang and isMine then
            tpTo(part.Position)
            if RE_Harvest then pcall(RE_Harvest.FireServer, RE_Harvest, part) end
            firePrompt(part.Parent or part, 'panen')
            fireClick(part)
            stat.harvested += 1
            task.wait(cfg.actDelay)
        end
    end
end

local function buySeeds(crop)
    stat.action = '🛒 Beli ' .. crop.icon
    local pos = getNPCPos(NPC.bibit)
    if pos then tpTo(pos) end
    if RE_Buy then
        pcall(RE_Buy.FireServer, RE_Buy, crop.key, cfg.buyAmt)
        pcall(RE_Buy.FireServer, RE_Buy, {item = crop.key, amount = cfg.buyAmt})
    end
    local npc = getNPCPos(NPC.bibit)
    firePrompt(npc, 'beli')
end

local function plantCrop(crop, isBesar)
    local lv = getLevel()
    if lv < crop.minLevel then return end
    local seedCt = getSeedCount(crop.key)
    if seedCt <= 0 and cfg.autoBuy then buySeeds(crop) end
    stat.action = '🌱 Tanam ' .. crop.icon
    local tool = LP.Backpack:FindFirstChild(crop.key:gsub(' ', ''))
    if tool then Hum:EquipTool(tool) task.wait(0.2) end
    local areas = isBesar and {} or workspace:FindFirstChild('AreaTanam', true):GetDescendants()
    if isBesar then for i=1,28 do table.insert(areas, workspace:FindFirstChild('AreaTanamBesar' .. i, true)) end end
    for _, area in ipairs(areas) do
        if area:IsA('BasePart') and getSeedCount(crop.key) > 0 then
            local empty = not area:GetAttribute('SeedType') and not area:GetAttribute('Occupied')
            local mine = not area:GetAttribute('Owner') or area:GetAttribute('Owner') == LP.UserId
            if empty and mine then
                tpTo(area.Position)
                if RE_Plant then pcall(RE_Plant.FireServer, RE_Plant, crop.key, area) end
                fireClick(area)
                firePrompt(area, 'tanam')
                stat.planted += 1
                task.wait(cfg.actDelay)
            end
        end
    end
    Hum:UnequipTools()
end

local function doSell()
    stat.action = '💰 Jual'
    local pos = getNPCPos(NPC.penjual)
    if pos then tpTo(pos) end
    if RE_Sell then
        pcall(RE_Sell.FireServer, RE_Sell)
        pcall(RE_Sell.FireServer, RE_Sell, 'All')
    end
    firePrompt(getNPCObj(NPC.penjual), 'jual')
    local sawitPos = getNPCPos(NPC.sawit)
    if sawitPos then tpTo(sawitPos) firePrompt(getNPCObj(NPC.sawit), 'jual') end
end

local function farmLoop()
    while stat.running do
        doHarvest()
        if cfg.autoSell then doSell() end
        for _, crop in ipairs(CROPS_BIASA) do plantCrop(crop, false) end
        for _, crop in ipairs(CROPS_BESAR) do plantCrop(crop, true) end
        task.wait(math.random(25,35)/10)
    end
end

local function startFarm() stat.running = true task.spawn(farmLoop) end
local function stopFarm() stat.running = false end

-- UI Rayfield (lengkap, fix syntax)
local Win = Rayfield:CreateWindow({
    Name = '🌾 NAKA AUTO FARM v3.2',
    LoadingTitle = '🌾 SAWAH INDO',
    LoadingSubtitle = 'Perbaiki Full 2026',
    ConfigurationSaving = {Enabled = true, FolderName = 'NAKA', FileName = 'v3.2'},
    KeySystem = false
})

Rayfield:LoadConfiguration()
Rayfield:Notify({Title = '🌾 v3.2 Loaded!', Content = 'Klik Debug untuk scan remote!', Duration = 5})

local T1 = Win:CreateTab('🌾 Farm', 4483362458)
local L_status = T1:CreateLabel('Status: Stop')
local L_action = T1:CreateLabel('Aksi: Standby')
local L_harvest = T1:CreateLabel('Panen: 0')
local L_planted = T1:CreateLabel('Tanam: 0')

T1:CreateButton({Name = '▶ Mulai', Callback = startFarm})
T1:CreateButton({Name = '⏹ Stop', Callback = stopFarm})

local T2 = Win:CreateTab('🌱 Tanaman', 4483362458)
for _, crop in ipairs(CROPS_BIASA) do
    T2:CreateToggle({Name = crop.icon .. ' ' .. crop.key, CurrentValue = true, Callback = function(v) crop.enabled = v end})
end
for _, crop in ipairs(CROPS_BESAR) do
    T2:CreateToggle({Name = crop.icon .. ' ' .. crop.key, CurrentValue = true, Callback = function(v) crop.enabled = v end})
end

local T3 = Win:CreateTab('⚙ Settings', 4483362458)
T3:CreateToggle({Name = '📍 Teleport', CurrentValue = true, Callback = function(v) cfg.useTP = v end})
T3:CreateToggle({Name = '🛒 Auto Beli', CurrentValue = true, Callback = function(v) cfg.autoBuy = v end})
T3:CreateToggle({Name = '💰 Auto Jual', CurrentValue = false, Callback = function(v) cfg.autoSell = v end})
T3:CreateSlider({Name = 'Delay (0.1s)', Range = {2,10}, Increment = 1, CurrentValue = 3, Callback = function(v) cfg.actDelay = v/10 end})

T3:CreateSection('Debug')
T3:CreateButton({Name = '🔍 Cek Remote', Callback = function()
    Rayfield:Notify({Title = 'Plant', Content = RE_Plant and '✅' or '❌'})
    Rayfield:Notify({Title = 'Harvest', Content = RE_Harvest and '✅' or '❌'})
    Rayfield:Notify({Title = 'Buy/Sell', Content = (RE_Buy or RE_Sell) and '✅' or '❌'})
end})
T3:CreateButton({Name = '📋 Re-Scan Remote', Callback = scanRemotes})
T3:CreateButton({Name = '🌾 Panen Manual', Callback = function() task.spawn(doHarvest) end})
T3:CreateButton({Name = '🌱 Tanam Manual', Callback = function() task.spawn(function() for _,c in CROPS_BIASA do plantCrop(c,false) end end) end})

local T4 = Win:CreateTab('📋 Info', 4483362458)
T4:CreateLabel('1. Selesai tutorial dulu!')
T4:CreateLabel('2. Pilih tanaman sesuai Lv')
T4:CreateLabel('3. Mulai Farm!')
T4:CreateLabel('CoreGui error = Roblox bug, ignore!')

-- Update UI loop
task.spawn(function()
    while true do
        task.wait(2)
        L_status:Set('Status: ' .. (stat.running and '🟢 Jalan' or '🔴 Stop'))
        L_action:Set('Aksi: ' .. stat.action)
        L_harvest:Set('Panen: ' .. stat.harvested)
        L_planted:Set('Tanam: ' .. stat.planted)
    end
end)

-- Anti AFK
task.spawn(function()
    while true do
        task.wait(60)
        if Root then
            local cf = Root.CFrame
            Root.CFrame = cf * CFrame.new(0.5,0,0)
            task.wait(0.1)
            Root.CFrame = cf
        end
    end
end)

print('[NAKA v3.2] Perbaiki selesai - F9 untuk scan detail!')
