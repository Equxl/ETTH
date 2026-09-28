print("--- ПОИСК ПРЕДМЕТОВ ---")
local found = false
for _, obj in ipairs(game:GetService("Workspace"):GetDescendants()) do
    if obj:IsA("ProximityPrompt") then
        -- Ищем все подсказки, которые относятся к предметам
        if obj.ObjectText ~= "" and obj.ActionText ~= "" then
            print("Найден предмет: [" .. obj.ObjectText .. "] | Действие: [" .. obj.ActionText .. "] | Путь: " .. obj:GetFullName())
            found = true
        end
    end
end
if not found then print("Предметы не найдены. Убедитесь, что вы стоите рядом с ними.") end
print("--- КОНЕЦ ---")
