local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client_GuideBeam = {}

local localPlayer = Players.LocalPlayer

type BeamState = {
	startAttachment: Attachment?,
	endAttachment: Attachment?,
	beam: Beam?,
	targetPart: BasePart?,
}

local beamState: BeamState = {}
local trackedBeamTarget: BasePart? = nil

function Client_GuideBeam.Clear()
	if beamState.beam then
		beamState.beam:Destroy()
	end
	if beamState.startAttachment then
		beamState.startAttachment:Destroy()
	end
	if beamState.endAttachment then
		beamState.endAttachment:Destroy()
	end

	beamState = {}
	trackedBeamTarget = nil
end

local function getBeamTemplate(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local vfx = assets and assets:FindFirstChild("VFX")
	return vfx and vfx:FindFirstChild("TutorialBeam")
end

function Client_GuideBeam.AttachToTarget(targetPart: BasePart?)
	if not targetPart or not targetPart.Parent then
		Client_GuideBeam.Clear()
		return
	end

	if trackedBeamTarget == targetPart and beamState.beam and beamState.beam.Parent then
		return
	end

	Client_GuideBeam.Clear()

	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local template = getBeamTemplate()
	if not template then
		return
	end

	local templateStart = template:FindFirstChild("Start")
	local templateEnd = template:FindFirstChild("End")
	local templateBeam = template:FindFirstChild("Beam")
	if not templateStart or not templateStart:IsA("Attachment") then
		return
	end
	if not templateEnd or not templateEnd:IsA("Attachment") then
		return
	end
	if not templateBeam or not templateBeam:IsA("Beam") then
		return
	end

	local startAttachment = templateStart:Clone()
	startAttachment.Name = "GuideBeamStart"
	startAttachment.Parent = root

	local endAttachment = templateEnd:Clone()
	endAttachment.Name = "GuideBeamEnd"
	endAttachment.Parent = targetPart

	local beam = templateBeam:Clone()
	beam.Name = "GuideBeam"
	beam.Attachment0 = startAttachment
	beam.Attachment1 = endAttachment
	beam.Parent = root

	beamState = {
		startAttachment = startAttachment,
		endAttachment = endAttachment,
		beam = beam,
		targetPart = targetPart,
	}
	trackedBeamTarget = targetPart
end

return Client_GuideBeam
