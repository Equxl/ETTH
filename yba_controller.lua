print("--- СПИСОК КНОПОК В ИНТЕРФЕЙСЕ ---")
for _, gui in ipairs(game.Players.LocalPlayer.PlayerGui:GetChildren()) do
    for _, btn in ipairs(gui:GetDescendants()) do
        if btn:IsA("TextButton") or btn:IsA("ImageButton") then
            print("Кнопка: [" .. btn.Name .. "] | Текст: [" .. (btn.Text or "нет текста") .. "] | Путь: " .. btn:GetFullName())
        end
    end
end
print("--- КОНЕЦ ---")
