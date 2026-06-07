local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local CollectionService = game:GetService("CollectionService")

local Shared_BrainrotAnimations = {}

local idleTracks: { [Model]: AnimationTrack } = {}
local preloadedConfigNames: { [string]: boolean } = {}
local taggedAnimatedConfigNames: { [string]: boolean } = {}
local TAG_NAME = "AnimatedBrainrot"

local function rebuildAnimatedConfigNameCache()
	table.clear(taggedAnimatedConfigNames)
	for _, tagged in CollectionService:GetTagged(TAG_NAME) do
		if tagged:IsA("Model") then
			taggedAnimatedConfigNames[tagged.Name] = true
		end
	end
end

function Shared_BrainrotAnimations.IsAnimatedConfigName(configName: string): boolean
	if type(configName) ~= "string" or configName == "" then
		return false
	end

	if taggedAnimatedConfigNames[configName] then
		return true
	end

	-- Refresh lazily so newly added/streamed tagged models are picked up.
	rebuildAnimatedConfigNameCache()
	return taggedAnimatedConfigNames[configName] == true
end

function Shared_BrainrotAnimations.GetIdleAnimation(configName: string): Animation?
	if not Shared_BrainrotAnimations.IsAnimatedConfigName(configName) then
		return nil
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local animFolder = assets and assets:FindFirstChild("Animations")
	local configAnimFolder = animFolder and animFolder:FindFirstChild(configName)
	local idleAnim = configAnimFolder and configAnimFolder:FindFirstChild("Idle")

	if idleAnim and idleAnim:IsA("Animation") then
		return idleAnim
	end

	return nil
end

function Shared_BrainrotAnimations.PreloadIdle(configName: string)
	if preloadedConfigNames[configName] then
		return
	end

	local idleAnim = Shared_BrainrotAnimations.GetIdleAnimation(configName)
	if not idleAnim then
		return
	end

	local ok = pcall(function()
		ContentProvider:PreloadAsync({ idleAnim })
	end)

	if ok then
		preloadedConfigNames[configName] = true
	end
end

function Shared_BrainrotAnimations.PreloadInventoryBrainrots(inventory: { any })
	local animations: { Animation } = {}
	local pendingConfigNames: { string } = {}
	local seen: { [string]: boolean } = {}

	for _, item in inventory do
		if item and item.ItemType == "Brainrot" and type(item.ConfigName) == "string" then
			local configName = item.ConfigName
			if not preloadedConfigNames[configName] and not seen[configName] then
				local idleAnim = Shared_BrainrotAnimations.GetIdleAnimation(configName)
				if idleAnim then
					seen[configName] = true
					table.insert(animations, idleAnim)
					table.insert(pendingConfigNames, configName)
				end
			end
		end
	end

	if #animations == 0 then
		return
	end

	local ok = pcall(function()
		ContentProvider:PreloadAsync(animations)
	end)

	if ok then
		for _, configName in pendingConfigNames do
			preloadedConfigNames[configName] = true
		end
	end
end

function Shared_BrainrotAnimations.GetAnimator(model: Model): Animator?
	if not model then
		return nil
	end

	local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
	if humanoid then
		return humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	end

	local animController = model:FindFirstChildWhichIsA("AnimationController", true)
	if not animController then
		animController = Instance.new("AnimationController")
		animController.Parent = model
	end

	return animController:FindFirstChildOfClass("Animator") or Instance.new("Animator", animController)
end

function Shared_BrainrotAnimations.StopIdle(model: Model)
	local track = idleTracks[model]
	if track then
		track:Stop()
		idleTracks[model] = nil
	end
end

function Shared_BrainrotAnimations.PlayIdle(model: Model, configName: string?): AnimationTrack?
	if not model or not model:IsA("Model") then
		return nil
	end

	local resolvedConfigName = configName or model:GetAttribute("ConfigName") or model.Name
	local idleAnim = Shared_BrainrotAnimations.GetIdleAnimation(resolvedConfigName)
	if not idleAnim then
		return nil
	end

	local animator = Shared_BrainrotAnimations.GetAnimator(model)
	if not animator then
		return nil
	end

	for _, track in animator:GetPlayingAnimationTracks() do
		if track.Animation and track.Animation.AnimationId == idleAnim.AnimationId then
			track.Looped = true
			idleTracks[model] = track
			return track
		end
	end

	local existingTrack = idleTracks[model]
	if existingTrack and existingTrack.Animation and existingTrack.Animation.AnimationId == idleAnim.AnimationId then
		if not existingTrack.IsPlaying then
			existingTrack.Looped = true
			existingTrack:Play(0.1, 1, 1)
		end
		return existingTrack
	end

	local track = animator:LoadAnimation(idleAnim)
	track.Priority = Enum.AnimationPriority.Idle
	track.Looped = true
	track:Play(0.1, 1, 1)
	idleTracks[model] = track

	if not model:GetAttribute("_IdleAnimCleanup") then
		model:SetAttribute("_IdleAnimCleanup", true)
		model.Destroying:Connect(function()
			Shared_BrainrotAnimations.StopIdle(model)
		end)
	end

	return track
end

return Shared_BrainrotAnimations
