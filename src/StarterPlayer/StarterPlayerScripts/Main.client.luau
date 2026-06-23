local StarterGui = game:GetService("StarterGui")

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

task.spawn(function()
	while true do
		local ok = pcall(function()
			StarterGui:SetCore("BackpackEnabled", false)
		end)
		if ok then
			break
		end
		task.wait(0.1)
	end
end)

require(script.Parent.Client.Bootstrap).start()
