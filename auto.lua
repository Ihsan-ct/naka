-- =========================================================
-- ⚡ NAKA AUTO WALK v1.0
-- Record & Replay gerakan dengan presisi penuh
-- Fitur: Multi-slot, Keybind, Path Visual, Speed Control, Save/Load
-- =========================================================

if game:IsLoaded() == false then
    game.Loaded:Wait()
end

-- =========================
-- LOAD RAYFIELD
-- =========================
local httpget = game.HttpGet
local loadstr = loadstring

local RayfieldSource = httpget(game, "https://sirius.menu/rayfield")
if not RayfieldSource then warn("[AUTOWALK] Gagal load Rayfield") return end
local RayfieldFn = loadstr(RayfieldSource)
if not RayfieldFn then warn("[AUTOWALK] Gagal compile Rayfield") return end
local Rayfield = RayfieldFn()
if not Rayfield then warn("[AUTOWALK] Rayfield nil") return end

-- =========================
-- SERVICES
-- =========================
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService  = game:GetService("TweenService")

local LocalPlayer   = Players.LocalPlayer
local Character     = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid      = Character:WaitForChild("Humanoid")
local RootPart      = Character:WaitForChild("HumanoidRootPart")

-- Re-get character saat respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    Humanoid  = char:WaitForChild("Humanoid")
    RootPart  = char:WaitForChild("HumanoidRootPart")
end)

-- =========================
-- STATE
-- =========================
local RECORD_INTERVAL = 0.05   -- record tiap 50ms = 20fps
local MAX_SLOTS       = 5      -- jumlah slot rekaman

local state = {
    isRecording  = false,
    isReplaying  = false,
    currentSlot  = 1,
    replaySpeed  = 1.0,
    showPath     = true,
    loopReplay   = false,
    recordThread = nil,
    replayThread = nil,
    replayConn   = nil,         -- Heartbeat connection
    pathParts    = {},          -- part visual path
}

-- Slot rekaman: setiap slot punya array frames
-- frame = { pos = Vector3, lookAt = CFrame, speed = number, time = number }
local slots = {}
for i = 1, MAX_SLOTS do
    slots[i] = {
        name   = "Slot " .. i,
        frames = {},
        saved  = false,
    }
end

-- =========================
-- SAVE FILE HELPER
-- =========================
local SAVE_FILE = "NAKA_AutoWalk_Slots.json"

local function encodeSlots()
    -- Encode sederhana tanpa library JSON
    local lines = {"{"}
    for i = 1, MAX_SLOTS do
        local slot = slots[i]
        if #slot.frames > 0 then
            table.insert(lines, '  "slot' .. i .. '": {')
            table.insert(lines, '    "name": "' .. slot.name .. '",')
            table.insert(lines, '    "frames": [')
            for fi, frame in ipairs(slot.frames) do
                local p = frame.pos
                local sep = fi < #slot.frames and "," or ""
                table.insert(lines, string.format(
                    '      {"x":%.4f,"y":%.4f,"z":%.4f,"spd":%.4f,"t":%.4f}%s',
                    p.X, p.Y, p.Z, frame.speed, frame.time, sep
                ))
            end
            table.insert(lines, "    ]")
            local slotSep = i < MAX_SLOTS and "  }," or "  }"
            table.insert(lines, slotSep)
        end
    end
    table.insert(lines, "}")
    return table.concat(lines, "\n")
end

local function saveSlots()
    pcall(writefile, SAVE_FILE, encodeSlots())
end

local function loadSlots()
    local ok, content = pcall(readfile, SAVE_FILE)
    if not ok or not content then return end
    -- Parse sederhana
    for i = 1, MAX_SLOTS do
        local slotData = content:match('"slot' .. i .. '":%s*{.-"frames":%s*%[(.-)%]')
        if slotData then
            local name = content:match('"slot' .. i .. '":%s*{.-"name":%s*"([^"]*)"')
            if name then slots[i].name = name end
            slots[i].frames = {}
            for x, y, z, spd, t in slotData:gmatch(
                '"x":([-%.%d]+),"y":([-%.%d]+),"z":([-%.%d]+),"spd":([-%.%d]+),"t":([-%.%d]+)'
            ) do
                table.insert(slots[i].frames, {
                    pos   = Vector3.new(tonumber(x), tonumber(y), tonumber(z)),
                    speed = tonumber(spd),
                    time  = tonumber(t),
                })
            end
            slots[i].saved = #slots[i].frames > 0
        end
    end
    print("[AUTOWALK] Slot dimuat dari file")
end

-- =========================
-- PATH VISUALIZATION
-- =========================
local function clearPath()
    for _, part in ipairs(state.pathParts) do
        pcall(function() part:Destroy() end)
    end
    state.pathParts = {}
end

local function drawPath(slotIndex)
    clearPath()
    if not state.showPath then return end
    local frames = slots[slotIndex].frames
    if #frames < 2 then return end

    for i = 1, #frames - 1 do
        local a = frames[i].pos
        local b = frames[i+1].pos
        local dist = (b - a).Magnitude
        if dist < 0.1 then continue end

        local part = Instance.new("Part")
        part.Anchored   = true
        part.CanCollide = false
        part.CanQuery   = false
        part.CanTouch   = false
        part.Size       = Vector3.new(0.15, 0.15, dist)
        part.CFrame     = CFrame.lookAt((a+b)/2, b) * CFrame.new(0,0,-dist/2)
        part.Material   = Enum.Material.Neon
        -- Warna gradient: hijau di awal, merah di akhir
        local progress = i / #frames
        part.Color = Color3.fromHSV(0.35 * (1 - progress), 1, 1)
        part.Parent = workspace
        table.insert(state.pathParts, part)
    end
end

-- =========================
-- RECORD SYSTEM
-- =========================
local labelStatus   = nil
local labelSlot     = nil
local labelFrames   = nil
local labelDuration = nil

local function updateStatusUI()
    if labelStatus then
        local statusText = state.isRecording and "🔴 RECORDING..." 
            or state.isReplaying and "▶ REPLAYING..." 
            or "⏹ STANDBY"
        pcall(function() labelStatus:Set("◦  Status     :  " .. statusText) end)
    end
    if labelFrames then
        local frames = #slots[state.currentSlot].frames
        pcall(function() labelFrames:Set("◦  Frames     :  " .. frames) end)
    end
    if labelDuration then
        local frames = slots[state.currentSlot].frames
        local dur = #frames > 0 and frames[#frames].time or 0
        pcall(function() labelDuration:Set(string.format("◦  Durasi     :  %.1f detik", dur)) end)
    end
    if labelSlot then
        local slot = slots[state.currentSlot]
        local info = state.currentSlot .. " — " .. slot.name
            .. " (" .. #slot.frames .. " frames)"
        pcall(function() labelSlot:Set("◦  Slot Aktif :  " .. info) end)
    end
end

local function startRecording()
    if state.isRecording then return end
    if state.isReplaying then
        Rayfield:Notify({ Title="⚠️ Sedang Replay", Content="Stop replay dulu!", Duration=3, Image=4483362458 })
        return
    end

    -- Reset slot yang dipilih
    slots[state.currentSlot].frames = {}
    slots[state.currentSlot].saved  = false
    clearPath()

    state.isRecording = true
    local startTime   = tick()
    local lastPos     = RootPart.Position
    local lastSpeed   = 0

    Rayfield:Notify({
        Title   = "🔴 Recording Dimulai!",
        Content = "Slot " .. state.currentSlot .. "\nGerak bebas — tekan [X] untuk stop",
        Duration = 4,
        Image   = 4483362458
    })

    state.recordThread = task.spawn(function()
        while state.isRecording do
            local now    = tick() - startTime
            local pos    = RootPart.Position
            local spd    = (pos - lastPos).Magnitude / RECORD_INTERVAL

            table.insert(slots[state.currentSlot].frames, {
                pos   = pos,
                speed = spd,
                time  = now,
            })

            lastPos = pos
            lastSpeed = spd
            updateStatusUI()
            task.wait(RECORD_INTERVAL)
        end
    end)
end

local function stopRecording()
    if not state.isRecording then return end
    state.isRecording = false
    if state.recordThread then
        task.cancel(state.recordThread)
        state.recordThread = nil
    end

    local frameCount = #slots[state.currentSlot].frames
    slots[state.currentSlot].saved = frameCount > 0
    saveSlots()
    drawPath(state.currentSlot)
    updateStatusUI()

    Rayfield:Notify({
        Title   = "⏹ Recording Selesai!",
        Content = "Slot " .. state.currentSlot .. "\n" .. frameCount .. " frames direkam\nDisimpan ke file!",
        Duration = 5,
        Image   = 4483362458
    })
end

-- =========================
-- SMOOTH INTERPOLATION HELPERS
-- Catmull-Rom spline untuk gerakan super smooth
-- =========================
local function catmullRom(p0, p1, p2, p3, t)
    local t2 = t * t
    local t3 = t2 * t
    return 0.5 * (
        (2 * p1) +
        (-p0 + p2) * t +
        (2*p0 - 5*p1 + 4*p2 - p3) * t2 +
        (-p0 + 3*p1 - 3*p2 + p3) * t3
    )
end

local function findFrameAtTime(frames, targetTime)
    local lo, hi = 1, #frames - 1
    while lo < hi do
        local mid = math.floor((lo + hi) / 2)
        if frames[mid].time < targetTime then lo = mid + 1
        else hi = mid end
    end
    return math.max(1, lo - 1)
end

local function samplePosition(frames, t)
    if #frames == 0 then return Vector3.zero end
    if #frames == 1 then return frames[1].pos end
    local totalTime = frames[#frames].time
    t = math.clamp(t, 0, totalTime)
    local i  = findFrameAtTime(frames, t)
    i = math.clamp(i, 1, #frames - 1)
    local f0 = frames[math.max(1,       i-1)]
    local f1 = frames[i]
    local f2 = frames[math.min(#frames, i+1)]
    local f3 = frames[math.min(#frames, i+2)]
    local segDur = f2.time - f1.time
    local alpha  = segDur > 0 and math.clamp((t - f1.time) / segDur, 0, 1) or 0
    local smooth = alpha * alpha * (3 - 2 * alpha)  -- smoothstep
    return catmullRom(f0.pos, f1.pos, f2.pos, f3.pos, smooth)
end

local function sampleSpeed(frames, t)
    if #frames == 0 then return 16 end
    local totalTime = frames[#frames].time
    t = math.clamp(t, 0, totalTime)
    local i  = findFrameAtTime(frames, t)
    i = math.clamp(i, 1, #frames - 1)
    local f1 = frames[i]
    local f2 = frames[math.min(#frames, i+1)]
    local segDur = f2.time - f1.time
    local alpha  = segDur > 0 and math.clamp((t - f1.time) / segDur, 0, 1) or 0
    return math.clamp(f1.speed + (f2.speed - f1.speed) * alpha, 0, 100)
end

-- =========================
-- REPLAY SYSTEM — SMOOTH HEARTBEAT
-- RunService.Heartbeat = update tiap frame (60fps+)
-- Catmull-Rom = posisi mulus tanpa patah-patah
-- =========================
local function startReplay()
    if state.isReplaying then return end
    if state.isRecording then
        Rayfield:Notify({ Title="⚠️ Sedang Record", Content="Stop record dulu!", Duration=3, Image=4483362458 })
        return
    end

    local frames = slots[state.currentSlot].frames
    if #frames < 2 then
        Rayfield:Notify({ Title="⚠️ Slot Kosong", Content="Record dulu sebelum replay!", Duration=3, Image=4483362458 })
        return
    end

    state.isReplaying = true
    drawPath(state.currentSlot)

    local totalTime   = frames[#frames].time
    local playTime    = 0
    local origSpeed   = Humanoid.WalkSpeed
    local lastLookDir = Vector3.new(0, 0, -1)
    local LOOK_AHEAD  = 0.08  -- detik look-ahead untuk arah hadap

    -- Nonaktifkan kontrol keyboard player saat replay
    local function disableControl()
        pcall(function()
            LocalPlayer.DevComputerMovementMode = Enum.DevComputerMovementMode.Disabled
        end)
    end
    local function enableControl()
        pcall(function()
            LocalPlayer.DevComputerMovementMode = Enum.DevComputerMovementMode.UserChoice
        end)
    end
    disableControl()

    Rayfield:Notify({
        Title   = "▶ Replay Dimulai!",
        Content = "Slot " .. state.currentSlot .. " — Speed: " .. state.replaySpeed .. "x\nTekan [X] untuk stop",
        Duration = 4,
        Image   = 4483362458
    })

    -- ── Heartbeat: update tiap frame ─────────────────────
    local heartbeatConn
    heartbeatConn = RunService.Heartbeat:Connect(function(dt)
        if not state.isReplaying then
            heartbeatConn:Disconnect()
            enableControl()
            Humanoid.WalkSpeed = origSpeed
            pcall(function() Humanoid:Move(Vector3.zero, false) end)
            return
        end

        if not (RootPart and RootPart.Parent and Humanoid and Humanoid.Parent) then return end

        -- Maju waktu
        playTime = playTime + dt * state.replaySpeed

        -- Selesai?
        if playTime >= totalTime then
            if state.loopReplay then
                playTime = playTime % totalTime
            else
                -- Posisi terakhir
                local endPos = frames[#frames].pos
                local endCF  = CFrame.lookAt(endPos, endPos + lastLookDir)
                RootPart.CFrame    = endCF
                Humanoid.WalkSpeed = origSpeed
                state.isReplaying  = false
                heartbeatConn:Disconnect()
                enableControl()
                pcall(function() Humanoid:Move(Vector3.zero, false) end)
                updateStatusUI()
                Rayfield:Notify({
                    Title   = "⏹ Replay Selesai",
                    Content = "Slot " .. state.currentSlot .. " selesai diputar",
                    Duration = 3,
                    Image   = 4483362458
                })
                return
            end
        end

        -- Sample posisi sekarang dan sedikit ke depan (look-ahead)
        local currentPos = samplePosition(frames, playTime)
        local aheadPos   = samplePosition(frames, math.min(totalTime, playTime + LOOK_AHEAD))

        -- Hitung arah hadap smooth
        local lookDir = aheadPos - currentPos
        if lookDir.Magnitude > 0.001 then
            -- Lerp arah agar tidak tiba-tiba berputar
            lastLookDir = lastLookDir:Lerp(lookDir.Unit, math.min(1, dt * 18))
            if lastLookDir.Magnitude < 0.001 then lastLookDir = lookDir.Unit end
        end

        -- Bangun CFrame: posisi Catmull-Rom + rotasi smooth
        local up        = Vector3.new(0, 1, 0)
        local lookFlat  = Vector3.new(lastLookDir.X, 0, lastLookDir.Z)
        if lookFlat.Magnitude < 0.001 then lookFlat = Vector3.new(0, 0, -1) end
        local targetCF  = CFrame.lookAt(currentPos, currentPos + lookFlat)

        -- Apply langsung — 60fps Heartbeat sudah sangat smooth
        RootPart.CFrame = targetCF

        -- WalkSpeed mengikuti kecepatan rekaman asli
        local recordedSpeed = sampleSpeed(frames, playTime)
        Humanoid.WalkSpeed  = math.clamp(recordedSpeed * state.replaySpeed, 1, 80)

        -- Trigger animasi jalan
        if lookFlat.Magnitude > 0.001 then
            Humanoid:Move(lookFlat.Unit, false)
        end
    end)

    state.replayConn   = heartbeatConn
    state.replayThread = nil
    updateStatusUI()
end

local function stopReplay()
    if not state.isReplaying then return end
    state.isReplaying = false
    -- Putus Heartbeat connection
    if state.replayConn then
        pcall(function() state.replayConn:Disconnect() end)
        state.replayConn = nil
    end
    if state.replayThread then
        pcall(function() task.cancel(state.replayThread) end)
        state.replayThread = nil
    end
    -- Kembalikan kontrol player
    pcall(function()
        LocalPlayer.DevComputerMovementMode = Enum.DevComputerMovementMode.UserChoice
    end)
    pcall(function() Humanoid:Move(Vector3.zero, false) end)
    updateStatusUI()
    Rayfield:Notify({ Title="⏹ Replay Dihentikan", Content="", Duration=2, Image=4483362458 })
end

local function stopAll()
    stopRecording()
    stopReplay()
    updateStatusUI()
end

-- =========================
-- KEYBIND SYSTEM
-- F5 = Record/Stop
-- F6 = Replay/Stop
-- X  = Stop semua
-- =========================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.F5 then
        if state.isRecording then stopRecording()
        else startRecording() end

    elseif input.KeyCode == Enum.KeyCode.F6 then
        if state.isReplaying then stopReplay()
        else startReplay() end

    elseif input.KeyCode == Enum.KeyCode.X then
        stopAll()
    end
end)

-- =========================
-- BUILD UI — RAYFIELD
-- =========================
local Window = Rayfield:CreateWindow({
    Name            = "⚡  NAKA  AUTO WALK",
    LoadingTitle    = "⚡  N A K A",
    LoadingSubtitle = "[ Auto Walk  •  Record & Replay  •  v1.0 ]",
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "NAKA",
        FileName   = "AutoWalk_v1"
    },
    Discord   = { Enabled = false },
    KeySystem = false,
})

Rayfield:LoadConfiguration()

-- Muat slot dari file saat start
pcall(loadSlots)

Rayfield:Notify({
    Title    = "⚡  NAKA Auto Walk v1.0",
    Content  = "Record & Replay siap!\nF5=Record  F6=Replay  X=Stop",
    Duration = 5,
    Image    = 4483362458
})

-- ╔══════════════════════════════╗
-- ║  TAB 1 — CONTROL             ║
-- ╚══════════════════════════════╝
local ControlTab = Window:CreateTab("⚡  Control", 4483362458)

ControlTab:CreateSection("◈  Status Live")
labelStatus   = ControlTab:CreateLabel("◦  Status     :  ⏹ STANDBY")
labelSlot     = ControlTab:CreateLabel("◦  Slot Aktif :  1 — Slot 1 (0 frames)")
labelFrames   = ControlTab:CreateLabel("◦  Frames     :  0")
labelDuration = ControlTab:CreateLabel("◦  Durasi     :  0.0 detik")

ControlTab:CreateSection("◈  Record & Replay")

ControlTab:CreateButton({
    Name = "🔴  Mulai Record  [ F5 ]",
    Callback = function() startRecording() end
})

ControlTab:CreateButton({
    Name = "⏹  Stop Record  [ F5 ]",
    Callback = function() stopRecording() end
})

ControlTab:CreateButton({
    Name = "▶  Mulai Replay  [ F6 ]",
    Callback = function() startReplay() end
})

ControlTab:CreateButton({
    Name = "⏹  Stop Replay  [ F6 ]",
    Callback = function() stopReplay() end
})

ControlTab:CreateButton({
    Name = "✖  Stop Semua  [ X ]",
    Callback = function() stopAll() end
})

ControlTab:CreateSection("◈  Slot Aktif")

ControlTab:CreateDropdown({
    Name          = "📂  Pilih Slot",
    Options       = {"Slot 1","Slot 2","Slot 3","Slot 4","Slot 5"},
    CurrentOption = {"Slot 1"},
    Callback      = function(Value)
        local idx = tonumber(tostring(Value):match("%d+")) or 1
        state.currentSlot = idx
        drawPath(idx)
        updateStatusUI()
        Rayfield:Notify({
            Title   = "📂  Slot " .. idx,
            Content = slots[idx].name .. "\n" .. #slots[idx].frames .. " frames tersimpan",
            Duration = 3,
            Image   = 4483362458
        })
    end
})

ControlTab:CreateToggle({
    Name         = "🔁  Loop Replay",
    CurrentValue = false,
    Callback     = function(Value) state.loopReplay = Value end
})

ControlTab:CreateSection("◈  Kecepatan Replay")

ControlTab:CreateDropdown({
    Name          = "⚡  Speed Multiplier",
    Options       = {"0.25x","0.5x","0.75x","1x (Normal)","1.5x","2x","3x"},
    CurrentOption = {"1x (Normal)"},
    Callback      = function(Value)
        local speeds = {
            ["0.25x"]=0.25, ["0.5x"]=0.5, ["0.75x"]=0.75,
            ["1x (Normal)"]=1.0, ["1.5x"]=1.5, ["2x"]=2.0, ["3x"]=3.0
        }
        state.replaySpeed = speeds[tostring(Value)] or 1.0
        Rayfield:Notify({
            Title   = "⚡  Speed: " .. tostring(Value),
            Content = "Kecepatan replay diubah",
            Duration = 2,
            Image   = 4483362458
        })
    end
})

-- ╔══════════════════════════════╗
-- ║  TAB 2 — SLOTS               ║
-- ╚══════════════════════════════╝
local SlotsTab = Window:CreateTab("📂  Slots", 4483362458)

SlotsTab:CreateSection("◈  Kelola Slot")

-- Tampilkan info semua slot
for i = 1, MAX_SLOTS do
    local slot = slots[i]
    SlotsTab:CreateLabel("◦  Slot " .. i .. "  :  " .. slot.name .. " — " .. #slot.frames .. " frames")
end

SlotsTab:CreateSection("◈  Rename Slot")

SlotsTab:CreateDropdown({
    Name          = "📝  Pilih Slot untuk Rename",
    Options       = {"Slot 1","Slot 2","Slot 3","Slot 4","Slot 5"},
    CurrentOption = {"Slot 1"},
    Callback      = function(Value)
        state.currentSlot = tonumber(tostring(Value):match("%d+")) or 1
    end
})

SlotsTab:CreateInput({
    Name        = "✏  Nama Baru",
    PlaceholderText = "Contoh: Rute Farm, Rute AFK...",
    RemoveTextAfterFocusLost = false,
    Callback    = function(Value)
        if Value and #Value > 0 then
            slots[state.currentSlot].name = Value
            saveSlots()
            Rayfield:Notify({
                Title   = "✏  Slot " .. state.currentSlot .. " Direname",
                Content = "Nama baru: " .. Value,
                Duration = 3,
                Image   = 4483362458
            })
            updateStatusUI()
        end
    end
})

SlotsTab:CreateSection("◈  Hapus Slot")

SlotsTab:CreateButton({
    Name = "🗑  Hapus Slot Aktif",
    Callback = function()
        slots[state.currentSlot].frames = {}
        slots[state.currentSlot].saved  = false
        clearPath()
        saveSlots()
        updateStatusUI()
        Rayfield:Notify({
            Title   = "🗑  Slot " .. state.currentSlot .. " Dihapus",
            Content = "Rekaman dihapus dari memori & file",
            Duration = 3,
            Image   = 4483362458
        })
    end
})

SlotsTab:CreateButton({
    Name = "🗑  Hapus SEMUA Slot",
    Callback = function()
        for i = 1, MAX_SLOTS do
            slots[i].frames = {}
            slots[i].saved  = false
            slots[i].name   = "Slot " .. i
        end
        clearPath()
        saveSlots()
        updateStatusUI()
        Rayfield:Notify({
            Title   = "🗑  Semua Slot Dihapus",
            Content = "Semua rekaman dihapus",
            Duration = 3,
            Image   = 4483362458
        })
    end
})

-- ╔══════════════════════════════╗
-- ║  TAB 3 — SETTINGS            ║
-- ╚══════════════════════════════╝
local SettingsTab = Window:CreateTab("⚙  Settings", 4483362458)

SettingsTab:CreateSection("◈  Visualisasi Path")

SettingsTab:CreateToggle({
    Name         = "🎨  Tampilkan Garis Path",
    CurrentValue = true,
    Callback     = function(Value)
        state.showPath = Value
        if Value then
            drawPath(state.currentSlot)
        else
            clearPath()
        end
    end
})

SettingsTab:CreateButton({
    Name = "🔄  Refresh Visualisasi Path",
    Callback = function()
        drawPath(state.currentSlot)
        Rayfield:Notify({ Title="🎨  Path Direfresh", Content="", Duration=2, Image=4483362458 })
    end
})

SettingsTab:CreateButton({
    Name = "✖  Hapus Visualisasi Path",
    Callback = function()
        clearPath()
        Rayfield:Notify({ Title="✖  Path Dihapus", Content="", Duration=2, Image=4483362458 })
    end
})

SettingsTab:CreateSection("◈  File")

SettingsTab:CreateButton({
    Name = "💾  Simpan Semua Slot ke File",
    Callback = function()
        saveSlots()
        Rayfield:Notify({
            Title   = "💾  Tersimpan!",
            Content = "Semua slot disimpan ke\n" .. SAVE_FILE,
            Duration = 4,
            Image   = 4483362458
        })
    end
})

SettingsTab:CreateButton({
    Name = "📂  Muat Slot dari File",
    Callback = function()
        loadSlots()
        drawPath(state.currentSlot)
        updateStatusUI()
        Rayfield:Notify({
            Title   = "📂  Dimuat!",
            Content = "Slot berhasil dimuat dari file",
            Duration = 4,
            Image   = 4483362458
        })
    end
})

-- ╔══════════════════════════════╗
-- ║  TAB 4 — INFO                ║
-- ╚══════════════════════════════╝
local InfoTab = Window:CreateTab("📋  Info", 4483362458)

InfoTab:CreateSection("◈  Keybind")
InfoTab:CreateLabel("[ F5 ]  →  Mulai / Stop Record")
InfoTab:CreateLabel("[ F6 ]  →  Mulai / Stop Replay")
InfoTab:CreateLabel("[ X  ]  →  Stop Semua")

InfoTab:CreateSection("◈  Cara Pakai")
InfoTab:CreateLabel("1️⃣   Pilih slot di tab Control")
InfoTab:CreateLabel("2️⃣   Tekan F5 — mulai bergerak bebas")
InfoTab:CreateLabel("3️⃣   Tekan F5 lagi — stop & simpan otomatis")
InfoTab:CreateLabel("4️⃣   Tekan F6 — replay gerakan persis sama")
InfoTab:CreateLabel("5️⃣   Atur speed: 0.25x sampai 3x")

InfoTab:CreateSection("◈  Fitur")
InfoTab:CreateLabel("◦  5 slot rekaman terpisah")
InfoTab:CreateLabel("◦  Simpan ke file — tidak hilang saat restart")
InfoTab:CreateLabel("◦  Visualisasi path warna gradien")
InfoTab:CreateLabel("◦  Speed control 0.25x – 3x")
InfoTab:CreateLabel("◦  Loop replay otomatis")
InfoTab:CreateLabel("◦  Presisi tinggi — 20fps record rate")

InfoTab:CreateSection("◈  Tentang")
InfoTab:CreateLabel("⚡   NAKA Auto Walk  —  v1.0")
InfoTab:CreateLabel("◦   Dibuat oleh  :  NAKA")

-- =========================
-- INIT
-- =========================
updateStatusUI()
print("[NAKA AUTO WALK] v1.0 — LOADED  |  F5=Record  F6=Replay  X=Stop")
