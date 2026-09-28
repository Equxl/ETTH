-- ============================================================
-- ОТЛАДОЧНЫЙ СКРИПТ ДЛЯ YBA
-- Показывает все RemoteEvent и логирует их вызовы
-- ============================================================
print("=== [DEBUG] Запуск отладки YBA ===")

-- 1. Ищем все RemoteEvent в игре
local function findRemotes()
    print("\n--- Поиск RemoteEvent ---")
    local found = {}
    
    local function scan(container, path)
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                table.insert(found, obj)
                print("Найден:", path .. "." .. obj.Name)
            end
        end
    end
    
    scan(game:GetService("ReplicatedStorage"), "ReplicatedStorage")
    scan(game:GetService("Workspace"), "Workspace")
    scan(game:GetService("Players").LocalPlayer, "LocalPlayer")
    
    local char = game:GetService("Players").LocalPlayer.Character
    if char then
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("RemoteEvent") then
                table.insert(found, obj)
                print("Найден в Character:", obj.Name)
            end
        end
    end
    
    print("Всего найдено RemoteEvent:", #found)
    return found
end

-- 2. Хукаем FireServer, чтобы видеть, что игра отправляет при продаже
local function hookFireServer()
    print("\n--- Хук FireServer ---")
    print("Теперь ВРУЧНУЮ продайте любой предмет торговцу.")
    print("Все вызовы будут выведены ниже.\n")
    
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)
    
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" and self:IsA("RemoteEvent") then
            local args = {...}
            print("[FireServer] RemoteEvent:", self:GetFullName())
            print("  Аргументы:")
            for i, v in ipairs(args) do
                if type(v) == "table" then
                    print("   [" .. i .. "] table:")
                    for k, val in pairs(v) do
                        print("      " .. tostring(k) .. " = " .. tostring(val))
                    end
                else
                    print("   [" .. i .. "]", tostring(v))
                end
            end
            print("")
        end
        return oldNamecall(self, ...)
    end)
    
    setreadonly(mt, true)
end

-- 3. Показать объекты вокруг игрока
local function showNearby()
    local char = game:GetService("Players").LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    print("\n--- Объекты в радиусе 30 studs ---")
    for _, obj in ipairs(game:GetService("Workspace"):GetDescendants()) do
        if obj ~= char and (obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("Tool")) then
            local pos = nil
            if obj:IsA("BasePart") then pos = obj.Position
            elseif obj:IsA("Model") and obj.PrimaryPart then pos = obj.PrimaryPart.Position
            elseif obj:IsA("Tool") and obj:FindFirstChildWhichIsA("BasePart") then
                pos = obj:FindFirstChildWhichIsA("BasePart").Position
            end
            if pos and (pos - root.Position).Magnitude < 30 then
                local parent = obj.Parent and obj.Parent.Name or "nil"
                print(obj.ClassName, "| Имя:", obj.Name, "| Родитель:", parent)
            end
        end
    end
end

-- Запуск
findRemotes()
hookFireServer()
task.wait(1)
showNearby()

print("\n=== [DEBUG] Готово. Продайте предмет вручную и посмотрите вывод. ===")
