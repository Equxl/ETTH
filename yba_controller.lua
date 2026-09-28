-- ============================================================
-- YBA ESP v5.0 (ObjectText Fix)
-- ============================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Список предметов, которые ищем
local TARGET_ITEMS = {
    "Rokakaka", "Lucky Arrow", "Caesar's Headband", "Clackers",
    "Ancient Scroll", "Diamond", "Dio's Diary", "Gold Coin",
    "Lucky Stone Mask", "Mysterious Arrow", "Pure Rokakaka",
    "Quinton's Glove", "Rib Cage of The Saint's Corpse",
    "Steel Ball", "Stone Mask", "Zeppeli's Hat",
}

local espObjects = {}

local function createESP(part, itemName)
    if not part or espObjects[part] then return end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "YBA_ItemESP"
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = part
    billboard.Parent = part

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = itemName
    textLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    textLabel.TextStrokeTransparency = 0
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.Parent = billboard

    espObjects[part] = billboard
end

local function clearAllESP()
    for _, gui in pairs(espObjects) do
        if gui and gui.Parent then gui:Destroy() end
    end
    espObjects = {}
end

-- Новая функция сканирования: ищем Model внутри Item_Spawns.Items
local function scanForItems()
    local itemsFolder = Workspace:FindFirstChild("Item_Spawns")
    if not itemsFolder then return end
    local items = itemsFolder:FindFirstChild("Items")
    if not items then return end

    for _, model in ipairs(items:GetChildren()) do
        if model:IsA("Model") then
            -- Ищем ProximityPrompt внутри модели
            local prompt = model:FindFirstChildOfClass("ProximityPrompt")
            if prompt then
                local itemName = prompt.ObjectText -- Берем имя из ObjectText!
                for _, targetName in ipairs(TARGET_ITEMS) do
                    if itemName:lower() == targetName:lower() then
                        -- Находим MeshPart для прикрепления ESP
                        local mesh = model:FindFirstChildOfClass("MeshPart")
                        if mesh then
                            createESP(mesh, itemName)
                        end
                        break
                    end
                end
            end
        end
    end
end

local function cleanupESP()
    for part, gui in pairs(espObjects) do
        if not part or not part.Parent then
            gui:Destroy()
            espObjects[part] = nil
        end
    end
end

-- Цикл сканирования
task.spawn(function()
    while task.wait(3) do
        pcall(scanForItems)
        pcall(cleanupESP)
    end
end)

print("[YBA ESP v5.0] Запущен. Ищем предметы по ObjectText.")
