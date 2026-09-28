-- ============================================================
-- YBA PROXIMITY HOOK
-- ============================================================
print("[HOOK] Запуск хука ProximityPrompt...")

local oldFireProximityPrompt = fireproximityprompt

if oldFireProximityPrompt then
    fireproximityprompt = function(prompt, ...)
        if prompt and prompt:IsA("ProximityPrompt") then
            print("[HOOK] >>> Вызван fireproximityprompt!")
            print("[HOOK] Объект: " .. prompt:GetFullName())
            print("[HOOK] ObjectText: " .. prompt.ObjectText)
            print("[HOOK] ActionText: " .. prompt.ActionText)
            print("[HOOK] Родитель: " .. tostring(prompt.Parent))
            print("[HOOK] ------------------------")
        end
        return oldFireProximityPrompt(prompt, ...)
    end
    print("[HOOK] Хук установлен. ТЕПЕРЬ продайте предмет торговцу вручную!")
else
    print("[HOOK] Ошибка: fireproximityprompt недоступен в этом исполнителе.")
end
