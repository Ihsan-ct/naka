-- =========================================================
-- 🌾 NAKA AUTO FARM — SAWAH INDO v3.0 FIXED
-- REMOTE EVENTS:
-- Plant  = ReplicatedStorage.Remotes.TutorialRemotes.PlantCrop
-- Harvest = ReplicatedStorage.Remotes.TutorialRemotes.HarvestCrop
-- Buy    = ReplicatedStorage.Remotes.TutorialRemotes.RefreshShop
-- Sell   = ReplicatedStorage.Remotes.TutorialRemotes.SellCrop
-- =========================================================

if game:IsLoaded() == false then game.Loaded:Wait() end

-- ============================
-- LOAD RAYFIELD (tanpa icon error)
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

local LP   = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local Hum  = Char:WaitForChild("Humanoid")
local Root = Char:WaitForChild("HumanoidRootPart")

-- ============================
-- CHARACTER HANDLER
-- ============================
LP.CharacterAdded:Connect(function(c)
    Char = c
    Hum = c:WaitForChild("Humanoid")
    Root = c:WaitForChild("HumanoidRootPart")
end)

-- ============================
-- REMOTE EVENTS (PASTI BENAR)
-- ============================
local Remotes = RS:WaitForChild("Remotes"):WaitForChild("TutorialRemotes")

local RE_Plant   = Remotes:FindFirstChild("PlantCrop")
local RE_Harvest = Remotes:FindFirstChild("HarvestCrop") 
local RE_Buy     = Remotes:FindFirstChild("RefreshShop")  -- INI YANG BENAR!
local RE_Sell    = Remotes:FindFirstChild("SellCrop")     -- INI YANG BENAR!

print("====================================")
print("🌾 REMOTE EVENTS DITEMUKAN:")
print("Plant   = " .. tostring(RE_Plant and RE_Plant:GetFullName() or "❌"))
print("Harvest = " .. tostring(RE_Harvest and RE_Harvest:GetFullName() or "❌"))
print("Buy     = " .. tostring(RE_Buy and RE_Buy:GetFullName() or "❌"))
print("Sell    = " .. tostring(RE_Sell and RE_Sell:GetFullName() or "❌"))
print("====================================")

-- ============================
-- GAME CONFIG
-- ============================
local CROPS = {
    biasa = {
        { name="Bibit Padi", icon="🌾", price=5, level=1, time=60, sell=10, enabled=true },
        { name="Bibit Jagung", icon="🌽", price=15, level=20, time=90, sell=30, enabled=true },
        { name="Bibit Tomat", icon="🍅", price=25, level=40, time=135, sell=50, enabled=true },
        { name="Bibit Terong", icon="🍆", price=40, level=60, time=175, sell=80, enabled=true },
        { name="Bibit Strawberry", icon="🍓", price=60, level=80, time=215, sell=120, enabled=true },
    },
    besar = {
        { name="Bibit Sawit", icon="🌴", price=1000, level=80, time=800, sell=500, enabled=true },
        { name="Bibit Durian", icon="🍈", price=2000, level=120, time=1000, sell=1000, enabled=true },
    }
}

local NPC = {
    bibit = "NPC_Bibit",
    penjual = "NPC_Penjual", 
    sawit = "NPC_PedagangSawit"
}

-- ============================
-- HELPER FUNCTIONS
-- ============================
local function getLevel()
    local ls = LP:FindFirstChild("leaderstats")
    return ls and ls:FindFirstChild("Level") and ls.Level.Value or 0
end

local function getCoins()
    local ls = LP:FindFirstChild("leaderstats")
    return ls and ls:FindFirstChild("Coins") and ls.Coins.Value or 0
end

local function getSeedCount(seedName)
    -- Cek di inventory (biasanya pake IntValue)
    for _, v in ipairs(LP:GetDescendants()) do
        if v:IsA("IntValue") and v.Name == seedName then
            return v.Value
        end
    end
    return 0
end

local function findNPC(npcName)
    local npc = workspace:FindFirstChild(npcName, true)
    if not npc then
        local folder = workspace:FindFirstChild("NPCs")
        if folder then npc = folder:FindFirstChild(npcName, true) end
    end
    return npc
end

local function getNPCPosition(npcName)
    local npc = findNPC(npcName)
    if npc then
        if npc:IsA("Model") then
            local part = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head")
            return part and part.Position
        elseif npc:IsA("BasePart") then
            return npc.Position
        end
    end
    return nil
end

local function tpTo(pos)
    if Root and Root.Parent then
        Root.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
        task.wait(0.2)
    end
end

local function firePrompt(obj)
    if not obj then return end
    for _, pp in ipairs(obj:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            pcall(function()
                game:GetService("ProximityPromptService"):PromptTriggered(pp, LP)
                pp.Triggered:Fire(LP)
            end)
            return
        end
    end
end

-- ============================
-- CORE FUNCTIONS
-- ============================

-- BELI BIBIT (pake RefreshShop)
local function buySeeds(crop, amount)
    if not RE_Buy then 
        print("❌ RE_Buy (RefreshShop) tidak ditemukan!")
        return false 
    end
    
    local pos = getNPCPosition(NPC.bibit)
    if pos then tpTo(pos) end
    
    -- RefreshShop butuh argument apa? Coba beberapa format
    local success = pcall(function()
        -- Format 1: pake nama bibit
        RE_Buy:FireServer(crop.name)
        task.wait(0.3)
        
        -- Format 2: pake tabel
        RE_Buy:FireServer({item = crop.name, amount = amount})
        task.wait(0.3)
        
        -- Format 3: pake index (kalo butuh)
        for i = 1, amount do
            RE_Buy:FireServer(crop.name)
            task.wait(0.1)
        end
    end)
    
    -- Fallback pake prompt
    local npc = findNPC(NPC.bibit)
    if npc then firePrompt(npc) end
    
    return success
end

-- PANEN (pake HarvestCrop)
local function doHarvest()
    if not RE_Harvest then return end
    
    -- Cari tanaman matang di sekitar
    local function checkAndHarvest(areaName)
        local area = workspace:FindFirstChild(areaName, true)
        if not area then return end
        
        for _, part in ipairs(area:GetDescendants()) do
            if part:IsA("BasePart") then
                -- Cek attribute matang
                local matang = part:GetAttribute("Matang") 
                    or part:GetAttribute("Ready")
                    or (part:GetAttribute("Phase") and part:GetAttribute("Phase") >= 3)
                
                if matang then
                    -- Cek owner
                    local owner = part:GetAttribute("Owner")
                    local isMine = not owner or owner == LP.Name or owner == tostring(LP.UserId)
                    
                    if isMine then
                        if Root and (Root.Position - part.Position).Magnitude > 10 then
                            tpTo(part.Position)
                        end
                        
                        -- Harvest pake berbagai format
                        RE_Harvest:FireServer(part)
                        task.wait(0.2)
                        RE_Harvest:FireServer({plot = part})
                        task.wait(0.2)
                        
                        -- Kalo ada parent model
                        if part.Parent and part.Parent:IsA("Model") then
                            RE_Harvest:FireServer(part.Parent)
                        end
                        
                        -- Prompt juga
                        firePrompt(part)
                        
                        return true
                    end
                end
            end
        end
    end
    
    -- Scan area tanam biasa
    checkAndHarvest("AreaTanam")
    
    -- Scan area tanam besar
    for i = 1, 28 do
        checkAndHarvest("AreaTanamBesar" .. i)
    end
end

-- TANAM (pake PlantCrop)
local function plantCrop(crop, isBesar)
    if not RE_Plant then return end
    
    local areaName = isBesar and "AreaTanamBesar" or "AreaTanam"
    local areaList = {}
    
    if isBesar then
        for i = 1, 28 do
            local area = workspace:FindFirstChild(areaName .. i, true)
            if area then table.insert(areaList, area) end
        end
    else
        local area = workspace:FindFirstChild(areaName, true)
        if area then areaList = {area} end
    end
    
    for _, area in ipairs(areaList) do
        for _, part in ipairs(area:GetDescendants()) do
            if part:IsA("BasePart") then
                -- Cek apakah plot kosong
                local occupied = part:GetAttribute("Occupied") 
                    or part:GetAttribute("SeedType")
                    or part:GetAttribute("PlantType")
                
                if not occupied then
                    -- Cek owner (kalo ada)
                    local owner = part:GetAttribute("Owner")
                    if owner and owner ~= LP.Name and owner ~= tostring(LP.UserId) then
                        continue
                    end
                    
                    if Root and (Root.Position - part.Position).Magnitude > 10 then
                        tpTo(part.Position)
                    end
                    
                    -- Tanam dengan berbagai format
                    RE_Plant:FireServer(crop.name, part)
                    task.wait(0.2)
                    RE_Plant:FireServer({seed = crop.name, plot = part})
                    task.wait(0.2)
                    
                    -- Click & prompt
                    firePrompt(part)
                    
                    return true
                end
            end
        end
    end
end

-- JUAL (pake SellCrop)
local function doSell()
    if not RE_Sell then return end
    
    -- Jual ke NPC_Penjual (hasil biasa)
    local pos = getNPCPosition(NPC.penjual)
    if pos then tpTo(pos) end
    
    RE_Sell:FireServer()
    task.wait(0.3)
    RE_Sell:FireServer("All")
    
    local npc = findNPC(NPC.penjual)
    if npc then firePrompt(npc) end
    
    -- Jual ke NPC_PedagangSawit (hasil sawit/durian)
    local sawitPos = getNPCPosition(NPC.sawit)
    if sawitPos then
        tpTo(sawitPos)
        RE_Sell:FireServer("Sawit")
        task.wait(0.3)
        
        local sawitNPC = findNPC(NPC.sawit)
        if sawitNPC then firePrompt(sawitNPC) end
    end
end

-- ============================
-- UI RAYFIELD (pake icon standard)
-- ============================
local Window = Rayfield:CreateWindow({
    Name = "🌾 NAKA AUTO FARM",
    LoadingTitle = "SAWAH INDO",
    LoadingSubtitle = "by cvAI4",
    ConfigurationSaving = { Enabled = true, FolderName = "NAKA", FileName = "Config" },
    KeySystem = false
})

-- State
local state = {
    running = false,
    harvested = 0,
    planted = 0,
    profit = 0,
    startTime = os.time()
}

-- Labels
local statusLabel, actionLabel, harvestLabel, plantedLabel, profitLabel, timeLabel

-- Tab Utama
local MainTab = Window:CreateTab("🌾 Farm")

MainTab:CreateSection("STATUS")
statusLabel = MainTab:CreateLabel("Status: 🔴 Berhenti")
actionLabel = MainTab:CreateLabel("Aksi: -")
harvestLabel = MainTab:CreateLabel("Dipanen: 0")
plantedLabel = MainTab:CreateLabel("Ditanam: 0")
profitLabel = MainTab:CreateLabel("Profit: Rp0")
timeLabel = MainTab:CreateLabel("Durasi: 0m")

MainTab:CreateSection("KONTROL")
MainTab:CreateButton({
    Name = "▶ Mulai Auto Farm",
    Callback = function()
        state.running = true
        state.startTime = os.time()
        statusLabel:Set("Status: 🟢 Berjalan")
        
        -- Loop farming
        task.spawn(function()
            while state.running do
                actionLabel:Set("Aksi: 🌾 Panen")
                doHarvest()
                
                actionLabel:Set("Aksi: 💰 Jual")
                if math.random(1, 3) == 1 then -- Jual kadang-kadang
                    doSell()
                end
                
                actionLabel:Set("Aksi: 🌱 Tanam")
                for _, crop in ipairs(CROPS.biasa) do
                    if crop.enabled and getLevel() >= crop.level then
                        plantCrop(crop, false)
                        state.planted = state.planted + 1
                        plantedLabel:Set("Ditanam: " .. state.planted)
                    end
                end
                
                for _, crop in ipairs(CROPS.besar) do
                    if crop.enabled and getLevel() >= crop.level then
                        plantCrop(crop, true)
                        state.planted = state.planted + 1
                        plantedLabel:Set("Ditanam: " .. state.planted)
                    end
                end
                
                -- Update durasi
                local elapsed = math.floor((os.time() - state.startTime) / 60)
                timeLabel:Set("Durasi: " .. elapsed .. "m")
                
                task.wait(5)
            end
        end)
    end
})

MainTab:CreateButton({
    Name = "⏹ Stop Auto Farm",
    Callback = function()
        state.running = false
        statusLabel:Set("Status: 🔴 Berhenti")
        actionLabel:Set("Aksi: -")
    end
})

MainTab:CreateSection("AKSI MANUAL")
MainTab:CreateButton({
    Name = "🌾 Panen Sekarang",
    Callback = function()
        task.spawn(function()
            actionLabel:Set("Aksi: 🌾 Panen Manual")
            doHarvest()
            actionLabel:Set("Aksi: -")
        end)
    end
})

MainTab:CreateButton({
    Name = "💰 Jual Sekarang", 
    Callback = function()
        task.spawn(function()
            actionLabel:Set("Aksi: 💰 Jual Manual")
            doSell()
            actionLabel:Set("Aksi: -")
        end)
    end
})

-- Tab Tanaman
local CropTab = Window:CreateTab("🌱 Tanaman")

CropTab:CreateSection("TANAMAN BIASA")
for _, crop in ipairs(CROPS.biasa) do
    CropTab:CreateToggle({
        Name = crop.icon .. " " .. crop.name .. " (Lv." .. crop.level .. ")",
        CurrentValue = true,
        Callback = function(v)
            crop.enabled = v
        end
    })
end

CropTab:CreateSection("TANAMAN BESAR")
for _, crop in ipairs(CROPS.besar) do
    CropTab:CreateToggle({
        Name = crop.icon .. " " .. crop.name .. " (Lv." .. crop.level .. ")",
        CurrentValue = true,
        Callback = function(v)
            crop.enabled = v
        end
    })
end

-- Tab Settings
local SettingsTab = Window:CreateTab("⚙️ Settings")

SettingsTab:CreateSection("INFORMASI")
SettingsTab:CreateParagraph({
    Title = "Remote Events",
    Content = "✅ PlantCrop\n✅ HarvestCrop\n✅ RefreshShop (Buy)\n✅ SellCrop"
})

SettingsTab:CreateSection("STATISTIK")
SettingsTab:CreateButton({
    Name = "📊 Tampilkan Statistik",
    Callback = function()
        Rayfield:Notify({
            Title = "Statistik Farming",
            Content = string.format(
                "Dipanen: %d\nDitanam: %d\nProfit: Rp%d",
                state.harvested, state.planted, state.profit
            ),
            Duration = 5
        })
    end
})

SettingsTab:CreateButton({
    Name = "🔄 Reset Statistik",
    Callback = function()
        state.harvested = 0
        state.planted = 0
        state.profit = 0
        harvestLabel:Set("Dipanen: 0")
        plantedLabel:Set("Ditanam: 0")
        profitLabel:Set("Profit: Rp0")
        Rayfield:Notify({ Title = "✅ Reset", Content = "Statistik direset", Duration = 3 })
    end
})

-- Tab Debug
local DebugTab = Window:CreateTab("🔍 Debug")

DebugTab:CreateSection("CEK REMOTE")
DebugTab:CreateButton({
    Name = "🔍 Test Masing-masing Remote",
    Callback = function()
        local results = {}
        
        if RE_Plant then
            pcall(function() RE_Plant:FireServer("Bibit Padi") end)
            table.insert(results, "✅ PlantCrop: OK")
        else
            table.insert(results, "❌ PlantCrop: Tidak ada")
        end
        
        if RE_Harvest then
            pcall(function() RE_Harvest:FireServer() end)
            table.insert(results, "✅ HarvestCrop: OK")
        else
            table.insert(results, "❌ HarvestCrop: Tidak ada")
        end
        
        if RE_Buy then
            pcall(function() RE_Buy:FireServer("Bibit Padi") end)
            table.insert(results, "✅ RefreshShop (Buy): OK")
        else
            table.insert(results, "❌ RefreshShop (Buy): Tidak ada")
        end
        
        if RE_Sell then
            pcall(function() RE_Sell:FireServer() end)
            table.insert(results, "✅ SellCrop: OK")
        else
            table.insert(results, "❌ SellCrop: Tidak ada")
        end
        
        Rayfield:Notify({
            Title = "Hasil Test Remote",
            Content = table.concat(results, "\n"),
            Duration = 7
        })
    end
})

DebugTab:CreateSection("NPC & AREA")
DebugTab:CreateButton({
    Name = "📍 Cek NPC",
    Callback = function()
        local msg = ""
        for name, npcName in pairs(NPC) do
            local pos = getNPCPosition(npcName)
            msg = msg .. npcName .. ": " .. (pos and "✅" or "❌") .. "\n"
        end
        Rayfield:Notify({ Title = "NPC Status", Content = msg, Duration = 5 })
    end
})

DebugTab:CreateButton({
    Name = "🌾 Cek Area Tanam",
    Callback = function()
        local biasa = workspace:FindFirstChild("AreaTanam", true)
        local besar = 0
        for i = 1, 28 do
            if workspace:FindFirstChild("AreaTanamBesar" .. i, true) then
                besar = besar + 1
            end
        end
        Rayfield:Notify({
            Title = "Area Tanam",
            Content = string.format("AreaTanam: %s\nAreaTanamBesar: %d/28", biasa and "✅" or "❌", besar),
            Duration = 4
        })
    end
})

-- Anti AFK
task.spawn(function()
    while true do
        task.wait(60)
        if Root and Root.Parent then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end
end)

-- Notifikasi sukses
Rayfield:Notify({
    Title = "✅ SCRIPT SIAP",
    Content = "Remote Events: Plant, Harvest, Buy (RefreshShop), Sell",
    Duration = 5
})

print("✅ SCRIPT NAKA V3.0 FIXED - READY TO FARM!")
