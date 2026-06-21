local Client_PlotSignVisibility = {}

local function storeDefaults(signRoot: Instance)
	for _, descendant in signRoot:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant:GetAttribute("OriginalTransparency") == nil then
				descendant:SetAttribute("OriginalTransparency", descendant.Transparency)
			end
			if descendant:GetAttribute("OriginalCanCollide") == nil then
				descendant:SetAttribute("OriginalCanCollide", descendant.CanCollide)
			end
		elseif descendant:IsA("SurfaceGui") then
			if descendant:GetAttribute("OriginalSurfaceGuiEnabled") == nil then
				descendant:SetAttribute("OriginalSurfaceGuiEnabled", descendant.Enabled)
			end
		end
	end
end

function Client_PlotSignVisibility.setPlotSignVisible(signRoot: Instance?, visible: boolean)
	if not signRoot then
		return
	end

	storeDefaults(signRoot)

	for _, descendant in signRoot:GetDescendants() do
		if descendant:IsA("BasePart") then
			if visible then
				local transparency = descendant:GetAttribute("OriginalTransparency")
				if transparency ~= nil then
					descendant.Transparency = transparency
				end
				local canCollide = descendant:GetAttribute("OriginalCanCollide")
				if canCollide ~= nil then
					descendant.CanCollide = canCollide
				end
			else
				descendant.Transparency = 1
				descendant.CanCollide = false
			end
		elseif descendant:IsA("SurfaceGui") then
			if visible then
				local enabled = descendant:GetAttribute("OriginalSurfaceGuiEnabled")
				if enabled ~= nil then
					descendant.Enabled = enabled
				end
			else
				descendant.Enabled = false
			end
		end
	end
end

return Client_PlotSignVisibility
