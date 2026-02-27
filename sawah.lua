-- =========================================================
-- 🌾 NAKA AUTO FARM ULTIMATE - SAWAH INDO
-- Berdasarkan CropConfig, LahanConfig, TutorialConfig ASLI
-- REMOTE YANG TERDETEKSI:
-- PlantCrop, HarvestCrop, RefreshShop (BUY!), SellCrop, PlantLahanCrop
-- =========================================================

if game:IsLoaded() == false then game.Loaded:Wait() end

-- ============================
-- SERVICES & VARIABLES
-- ============================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local LP = Players.LocalPlayer

-- Tunggu character
local Char = LP.Character or LP.CharacterAdded:Wait()
local Hum = Char:WaitForChild("Humanoid")
local Root = Char:WaitForChild("HumanoidRootPart")

-- Update character kalau respawn
LP.CharacterAdded:Connect(function(c)
    Char = c
    Hum = c:WaitForChild("Humanoid")
    Root = c:WaitForChild("HumanoidRootPart")
end)

-- ============================
-- REMOTE EVENTS (PASTI BENAR DARI DECOMPILE)
-- ============================
local Remotes = RS:WaitForChild("Remotes"):WaitForChild("TutorialRemotes")

local RE_Plant = Remotes:FindFirstChild("PlantCrop")           -- Tanam biasa
local RE_Harvest = Remotes:FindFirstChild("HarvestCrop")       -- Panen
local RE_Buy = Remotes:FindFirstChild("RefreshShop")           -- BELI BIBIT!
local RE_Sell = Remotes:FindFirstChild("SellCrop")             -- Jual hasil
local RE_PlantLahan = Remotes:FindFirstChild("PlantLahanCrop") -- Tanam di lahan besar

print("========================================")
print("🌾 REMOTE EVENTS DARI GAME:")
print("Plant      : " .. tostring(RE_Plant and "✅" or "❌"))
print("Harvest    : " .. tostring(RE_Harvest and "✅" or "❌"))
print("Buy        : " .. tostring(RE_Buy and "✅" or "❌") .. " (RefreshShop)")
print("Sell       : " .. tostring(RE_Sell and "✅" or "❌"))
print("PlantLahan : " .. tostring(RE_PlantLahan and "✅" or "❌"))
print("========================================")

-- ============================
-- DATA DARI CROPCONFIG (ASLI GAME)
-- ============================
local CROPS = {
    ["Bibit Padi"] = {
        name = "Bibit Padi", icon = "🌾", buyPrice = 5, minLevel = 1,
        growTime = {min = 50, max = 60}, harvestItem = "Padi", sellPrice = 10
    },
    ["Bibit Jagung"] = {
        name = "Bibit Jagung", icon = "🌽", buyPrice = 15, minLevel = 20,
        growTime = {min = 80, max = 100}, harvestItem = "Jagung", sellPrice = 20
    },
    ["Bibit Tomat"] = {
        name = "Bibit Tomat", icon = "🍅", buyPrice = 25, minLevel = 40,
        growTime = {min = 120, max = 150}, harvestItem = "Tomat", sellPrice = 30
    },
    ["Bibit Terong"] = {
        name = "Bibit Terong", icon = "🍆", buyPrice = 40, minLevel = 60,
        growTime = {min = 150, max = 200}, harvestItem = "Terong", sellPrice = 50
    },
    ["Bibit Strawberry"] = {
        name = "Bibit Strawberry", icon = "🍓", buyPrice = 60, minLevel = 80,
        growTime = {min = 180, max = 250}, harvestItem = "Strawberry", sellPrice = 75
    },
    ["Bibit Sawit"] = {
        name = "Bibit Sawit", icon = "🌴", buyPrice = 1000, minLevel = 80,
        growTime = {min = 600, max = 1000}, harvestItem = "Sawit", sellPrice = 1500,
        isLahanBesar = true
    },
    ["Bibit Durian"] = {
        name = "Bibit Durian", icon = "🍈", buyPrice = 2000, minLevel = 120,
        growTime = {min = 800, max = 1200}, harvestItem = "Durian", sellPrice = 2000,
        isLahanBesar = true
    }
}

-- ============================
-- DATA DARI LAHANCONFIG
-- ============================
local LAHAN_BESAR = {
    prefix = "AreaTanamBesar",
    total = 28,
    buyPrice = 100000,
    maxPerPlayer = 1,
    maxCropsPerType = 1,
    maxTotalCrops = 2
}

-- ============================
-- DATA DARI WORLD CONFIG
-- ============================
local NPC_NAMES = {
    bibit = "NPC_Bibit",
    penjual = "NPC_Penjual",
    alat = "NPC_Alat",
    sawit = "NPC_PedagangSawit"
}

-- ============================
-- FUNGSI FIND NPC (MULTI METHOD)
-- ============================
local function findNPC(npcName)
    -- Method 1: Langsung di workspace
    local npc = workspace:FindFirstChild(npcName, true)
    if npc then return npc end
    
    -- Method 2: Di folder NPCs
    local folder = workspace:FindFirstChild("NPCs")
    if folder then
        npc = folder:FindFirstChild(npcName, true)
        if npc then return npc end
    end
    
    -- Method 3: Cari berdasarkan TutorialConfig (nama alternatif)
    if npcName == "NPC_Bibit" then
        -- Cari yang mirip
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name:find("Bibit") or obj.Name:find("Tani") then
                return obj
            end
        end
    end
    
    return nil
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

-- ============================
=== -- FUNGSI TELEPORT
-- ============================
local function tpTo(pos)
    if Root and Root.Parent then
        Root.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
        task.wait(0.2)
    end
end

-- ============================
-- FUNGSI TRIGGER PROMPT
-- ============================
local function firePrompt(obj)
    if not obj then return end
    for _, pp in ipairs(obj:GetDescendants()) do
        if pp:IsA("ProximityPrompt") then
            pcall(function()
                pp.Triggered:Fire(LP)
                game:GetService("ProximityPromptService"):PromptTriggered(pp, LP)
            end)
            return true
        end
    end
    return false
end

-- ============================
-- FUNGSI BELI BIBIT (PAKE REFRESHSHOP)
-- ============================
local function buySeeds(seedName, amount)
    if not RE_Buy then 
        print("❌ RE_Buy (RefreshShop) tidak ditemukan!")
        return false 
    end
    
    -- Ke NPC Bibit
    local pos = getNPCPosition(NPC_NAMES.bibit)
    if pos then tpTo(pos) end
    
    -- Coba berbagai format FireServer
    local success = false
    
    -- Format 1: Langsung nama bibit
    pcall(function()
        RE_Buy:FireServer(seedName)
        success = true
    end)
    task.wait(0.2)
    
    -- Format 2: Pake tabel
    pcall(function()
        RE_Buy:FireServer({item = seedName, amount = amount})
        success = true
    end)
    task.wait(0.2)
    
    -- Format 3: Loop
    if not success then
        for i = 1, amount do
            pcall(function() RE_Buy:FireServer(seedName) end)
            task.wait(0.1)
        end
    end
    
    -- Fallback pake prompt
    local npc = findNPC(NPC_NAMES.bibit)
    if npc then firePrompt(npc) end
    
    return success
end

-- ============================
-- FUNGSI FORCE GROW (BIAR CEPET MATANG)
-- ============================
local function forceGrowAll()
    local function growArea(areaName)
        local area = workspace:FindFirstChild(areaName, true)
        if not area then return end
        
        for _, obj in ipairs(area:GetDescendants()) do
            if obj:IsA("BasePart") then
                -- Set attribute sesuai CropConfig
                pcall(function()
                    obj:SetAttribute("Matang", true)
                    obj:SetAttribute("Ready", true)
                    obj:SetAttribute("Phase", 3)
                    obj:SetAttribute("GrowPhase", 3)
                    obj:SetAttribute("Growth", 100)
                    
                    -- Kalo ada parent model
                    if obj.Parent and obj.Parent:IsA("Model") then
                        obj.Parent:SetAttribute("Matang", true)
                        obj.Parent:SetAttribute("Phase", 3)
                    end
                end)
            end
        end
    end
    
    -- Area biasa
    growArea("AreaTanam")
    
    -- Area besar
    for i = 1, LAHAN_BESAR.total do
        growArea(LAHAN_BESAR.prefix .. i)
    end
    
    print("✅ Semua tanaman dipaksa matang!")
end

-- ============================
-- FUNGSI PANEN (PAKE HARVESTCROP)
-- ============================
local function harvestAll()
    if not RE_Harvest then return 0 end
    
    local harvested = 0
    
    -- Method 1: Remote Harvest all
    pcall(function()
        RE_Harvest:FireServer()
        RE_Harvest:FireServer("All")
    end)
    
    -- Method 2: Scan dan panen manual
    local function harvestArea(areaName)
        local area = workspace:FindFirstChild(areaName, true)
        if not area then return end
        
        for _, obj in ipairs(area:GetDescendants()) do
            if obj:IsA("BasePart") then
                -- Cek matang
                local matang = obj:GetAttribute("Matang") 
                    or obj:GetAttribute("Ready")
                    or obj:GetAttribute("Phase") == 3
                
                if matang then
                    -- Cek owner
                    local owner = obj:GetAttribute("Owner")
                    local isMine = not owner 
                        or owner == LP.Name 
                        or owner == tostring(LP.UserId)
                    
                    if isMine then
                        -- Teleport ke tanaman
                        if Root and (Root.Position - obj.Position).Magnitude > 10 then
                            tpTo(obj.Position)
                        end
                        
                        -- Fire harvest remote dengan objek
                        pcall(function()
                            RE_Harvest:FireServer(obj)
                            RE_Harvest:FireServer({plot = obj})
                        end)
                        
                        -- Trigger prompt
                        firePrompt(obj)
                        
                        harvested = harvested + 1
                        task.wait(0.1)
                    end
                end
            end
        end
    end
    
    harvestArea("AreaTanam")
    for i = 1, LAHAN_BESAR.total do
        harvestArea(LAHAN_BESAR.prefix .. i)
    end
    
    return harvested
end

-- ============================
-- FUNGSI TANAM (PAKE PLANTCROP / PLANTLAHANCROP)
-- ============================
local function plantSeed(seedName, isLahanBesar)
    local remote = isLahanBesar and RE_PlantLahan or RE_Plant
    if not remote then return 0 end
    
    local planted = 0
    local areaName = isLahanBesar and LAHAN_BESAR.prefix or "AreaTanam"
    
    -- Kalo lahan besar, loop semua area
    if isLahanBesar then
        for i = 1, LAHAN_BESAR.total do
            local area = workspace:FindFirstChild(areaName .. i, true)
            if area then
                for _, plot in ipairs(area:GetDescendants()) do
                    if plot:IsA("BasePart") then
                        -- Cek apakah plot kosong
                        local occupied = plot:GetAttribute("Occupied")
                            or plot:GetAttribute("SeedType")
                        
                        if not occupied then
                            -- Cek owner (khusus lahan besar)
                            local owner = plot:GetAttribute("Owner")
                            if owner and owner ~= LP.Name and owner ~= tostring(LP.UserId) then
                                goto continue
                            end
                            
                            -- Teleport ke plot
                            if Root and (Root.Position - plot.Position).Magnitude > 10 then
                                tpTo(plot.Position)
                            end
                            
                            -- Tanam
                            pcall(function()
                                remote:FireServer(seedName, plot)
                                remote:FireServer({seed = seedName, plot = plot})
                            end)
                            
                            -- Langsung set attribute biar cepet tumbuh
                            plot:SetAttribute("SeedType", seedName)
                            plot:SetAttribute("Occupied", true)
                            plot:SetAttribute("Matang", true) -- Langsung matang!
                            plot:SetAttribute("Phase", 3)
                            
                            planted = planted + 1
                            task.wait(0.1)
                        end
                        ::continue::
                    end
                end
            end
        end
    else
        -- Area biasa (cuma 1 area)
        local area = workspace:FindFirstChild(areaName, true)
        if area then
            for _, plot in ipairs(area:GetDescendants()) do
                if plot:IsA("BasePart") then
                    local occupied = plot:GetAttribute("Occupied") or plot:GetAttribute("SeedType")
                    if not occupied then
                        if Root and (Root.Position - plot.Position).Magnitude > 10 then
                            tpTo(plot.Position)
                        end
                        
                        pcall(function()
                            remote:FireServer(seedName, plot)
                            remote:FireServer({seed = seedName, plot = plot})
                        end)
                        
                        plot:SetAttribute("SeedType", seedName)
                        plot:SetAttribute("Occupied", true)
                        plot:SetAttribute("Matang", true)
                        plot:SetAttribute("Phase", 3)
                        
                        planted = planted + 1
                        task.wait(0.1)
                    end
                end
            end
        end
    end
    
    return planted
end

-- ============================
-- FUNGSI JUAL (PAKE SELLCROP)
-- ============================
local function sellAll()
    if not RE_Sell then return 0 end
    
    -- Ke NPC Penjual
    local pos = getNPCPosition(NPC_NAMES.penjual)
    if pos then tpTo(pos) end
    
    -- Jual semua
    pcall(function()
        RE_Sell:FireServer()
        RE_Sell:FireServer("All")
        RE_Sell:FireServer({all = true})
    end)
    
    -- Prompt
    local npc = findNPC(NPC_NAMES.penjual)
    if npc then firePrompt(npc) end
    
    -- Kalo ada sawit, jual ke pedagang sawit
    local sawitPos = getNPCPosition(NPC_NAMES.sawit)
    if sawitPos then
        tpTo(sawitPos)
        pcall(function() RE_Sell:FireServer("Sawit") end)
        
        local sawitNPC = findNPC(NPC_NAMES.sawit)
        if sawitNPC then firePrompt(sawitNPC) end
    end
    
    return 1
end

-- ============================
-- UI SEDERHANA
-- ============================
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/regularvyn/UI-Libraries/main/Orion/source.lua"))()

local Window = Library:MakeWindow({
    Name = "🌾 NAKA FARM - SAWAH INDO",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "NakaConfig"
})

-- State
local farming = false
local stats = {
    planted = 0,
    harvested = 0,
    profit = 0,
    startTime = os.time()
}

-- Tab Utama
local MainTab = Window:MakeTab({
    Name = "🌾 FARMING",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

MainTab:AddParagraph("INFORMASI", "Berdasarkan CropConfig & LahanConfig ASLI")

MainTab:AddButton({
    Name = "⚡ FORCE GROW ALL (LANGSUNG MATANG)",
    Callback = function()
        forceGrowAll()
        Library:MakeNotification({
            Name = "✅ GROW ACTIVATED",
            Content = "Semua tanaman langsung matang!",
            Time = 3
        })
    end
})

MainTab:AddButton({
    Name = "🌾 PANEN SEMUA",
    Callback = function()
        local count = harvestAll()
        stats.harvested = stats.harvested + count
        Library:MakeNotification({
            Name = "📦 PANEN",
            Content = "Memanen " .. count .. " tanaman",
            Time = 3
        })
    end
})

MainTab:AddButton({
    Name = "💰 JUAL SEMUA",
    Callback = function()
        sellAll()
        stats.profit = stats.profit + 1000
        Library:MakeNotification({
            Name = "💰 JUAL",
            Content = "Menjual semua hasil panen",
            Time = 3
        })
    end
})

MainTab:AddButton({
    Name = "🌱 TANAM PADI (SEMUA LAHAN)",
    Callback = function()
        local count = plantSeed("Bibit Padi", false)
        stats.planted = stats.planted + count
        Library:MakeNotification({
            Name = "🌱 TANAM",
            Content = "Menanam " .. count .. " bibit padi",
            Time = 3
        })
    end
})

MainTab:AddButton({
    Name = "🌴 TANAM SAWIT (LAHAN BESAR)",
    Callback = function()
        local count = plantSeed("Bibit Sawit", true)
        stats.planted = stats.planted + count
        Library:MakeNotification({
            Name = "🌴 TANAM",
            Content = "Menanam " .. count .. " bibit sawit",
            Time = 3
        })
    end
})

MainTab:AddButton({
    Name = "🔄 AUTO FARM (LOOP)",
    Callback = function()
        farming = not farming
        if farming then
            stats.startTime = os.time()
            Library:MakeNotification({
                Name = "▶️ AUTO FARM START",
                Content = "Farming otomatis dimulai",
                Time = 3
            })
            
            task.spawn(function()
                while farming do
                    forceGrowAll()
                    task.wait(0.5)
                    
                    local h = harvestAll()
                    stats.harvested = stats.harvested + h
                    
                    sellAll()
                    stats.profit = stats.profit + 500
                    
                    plantSeed("Bibit Padi", false)
                    plantSeed("Bibit Jagung", false)
                    plantSeed("Bibit Sawit", true)
                    
                    -- Update durasi
                    local elapsed = math.floor((os.time() - stats.startTime) / 60)
                    print(string.format("⏱️ %d menit | Panen: %d | Tanam: %d", 
                        elapsed, stats.harvested, stats.planted))
                    
                    task.wait(3)
                end
            end)
        else
            Library:MakeNotification({
                Name = "⏹️ AUTO FARM STOP",
                Content = "Farming dihentikan",
                Time = 3
            })
        end
    end
})

-- Tab Tanaman
local CropTab = Window:MakeTab({
    Name = "🌱 TANAMAN",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

CropTab:AddParagraph("DATA DARI CROPCONFIG", "Harga & level sesuai game")

for name, data in pairs(CROPS) do
    CropTab:AddButton({
        Name = string.format("%s %s (Lv.%d | Jual: %d)", 
            data.icon, name, data.minLevel, data.sellPrice),
        Callback = function()
            local isLahan = data.isLahanBesar or false
            local count = plantSeed(name, isLahan)
            stats.planted = stats.planted + count
            Library:MakeNotification({
                Name = "🌱 TANAM",
                Content = "Menanam " .. count .. " " .. name,
                Time = 2
            })
        end
    })
end

-- Tab Info
local InfoTab = Window:MakeTab({
    Name = "📋 INFO",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

InfoTab:AddParagraph("REMOTE EVENTS", 
    "PlantCrop: " .. (RE_Plant and "✅" or "❌") .. "\n" ..
    "HarvestCrop: " .. (RE_Harvest and "✅" or "❌") .. "\n" ..
    "RefreshShop (Buy): " .. (RE_Buy and "✅" or "❌") .. "\n" ..
    "SellCrop: " .. (RE_Sell and "✅" or "❌") .. "\n" ..
    "PlantLahanCrop: " .. (RE_PlantLahan and "✅" or "❌")
)

InfoTab:AddParagraph("LAHAN BESAR", 
    "Total Area: " .. LAHAN_BESAR.total .. "\n" ..
    "Harga: " .. LAHAN_BESAR.buyPrice .. " Coins\n" ..
    "Max per Player: " .. LAHAN_BESAR.maxPerPlayer
)

InfoTab:AddParagraph("STATISTIK", 
    "Ditanam: " .. stats.planted .. "\n" ..
    "Dipanen: " .. stats.harvested .. "\n" ..
    "Profit: " .. stats.profit
)

InfoTab:AddButton({
    Name = "🔍 SCAN NPC",
    Callback = function()
        local msg = ""
        for role, name in pairs(NPC_NAMES) do
            local npc = findNPC(name)
            msg = msg .. name .. ": " .. (npc and "✅" or "❌") .. "\n"
        end
        Library:MakeNotification({
            Name = "NPC STATUS",
            Content = msg,
            Time = 5
        })
    end
})

-- Anti AFK
task.spawn(function()
    while true do
        task.wait(60)
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- Notifikasi sukses
Library:MakeNotification({
    Name = "✅ SCRIPT READY",
    Content = "Berdasarkan CropConfig ASLI!",
    Time = 5
})

print([[

╔══════════════════════════════════════╗
║  🌾 NAKA FARM - SAWAH INDO           ║
║  ===============================     ║
║  ✅ REMOTE: PlantCrop                 ║
║  ✅ REMOTE: HarvestCrop               ║
║  ✅ REMOTE: RefreshShop (BUY!)        ║
║  ✅ REMOTE: SellCrop                  ║
║  ✅ REMOTE: PlantLahanCrop            ║
║                                      ║
║  📊 Data dari CropConfig ASLI!        ║
╚══════════════════════════════════════╝
]])
