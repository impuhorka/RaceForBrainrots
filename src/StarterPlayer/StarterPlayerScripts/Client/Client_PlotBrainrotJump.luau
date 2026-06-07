local RunService = game:GetService("RunService")

local Client_PlotBrainrotJump = {}

local UPGRADE_JUMP_BASE_HEIGHT = 2.5
local COLLECT_JUMP_BASE_HEIGHT = 2.5
local JUMP_OVERDRIVE_STEP = 0.4375
local JUMP_MAX_OVERDRIVE = 4
local JUMP_UP_TIME = 0.15
local JUMP_DOWN_TIME = 0.183
local FLIP_DURATION = 0.3
local RENDER_STEP_NAME = "ClientPlotBrainrotJump"

type JumpOptions = {
	flipY: boolean?,
	baseHeight: number?,
	skipIfAnimating: boolean?,
}

type JumpState = {
	token: number,
	overdrive: number,
	restPivot: CFrame,
	jumpHeight: number,
	flipY: boolean,
	jumpProgress: number,
	spinProgress: number,
	startTime: number,
	renderKey: string,
	connection: RBXScriptConnection?,
}

local jumpStates: { [Model]: JumpState } = {}
local nextRenderKey = 0

local function easeOutQuad(t: number): number
	return 1 - (1 - t) * (1 - t)
end

local function easeInQuad(t: number): number
	return t * t
end

local function easeInOutSine(t: number): number
	return -(math.cos(math.pi * t) - 1) / 2
end

local function getStandingPivot(slotModel: Model, brainrotModel: Model): CFrame?
	local standingPart = slotModel:FindFirstChild("StandingPart", true)
	local primaryPart = brainrotModel.PrimaryPart
	if not standingPart or not standingPart:IsA("BasePart") or not primaryPart then
		return nil
	end

	local yOffset = standingPart.Size.Y / 2 + primaryPart.Size.Y / 2
	return standingPart.CFrame * CFrame.new(0, yOffset, 0) * CFrame.Angles(0, math.rad(90), 0)
end

local function getJumpHeightAtProgress(progress: number, jumpHeight: number): number
	if progress <= 0.5 then
		return jumpHeight * easeOutQuad(progress * 2)
	end

	return jumpHeight * (1 - easeInQuad((progress - 0.5) * 2))
end

local function computeJumpCFrame(restPivot: CFrame, jumpProgress: number, jumpHeight: number, spinProgress: number, flipY: boolean): CFrame
	local yOffset = getJumpHeightAtProgress(jumpProgress, jumpHeight)
	local spin = if flipY then CFrame.Angles(0, math.rad(360 * easeInOutSine(spinProgress)), 0) else CFrame.new()
	return restPivot * CFrame.new(0, yOffset, 0) * spin
end

local function stopJumpState(brainrotModel: Model, state: JumpState?)
	local activeState = state or jumpStates[brainrotModel]
	if not activeState then
		return
	end

	if activeState.connection then
		activeState.connection:Disconnect()
	end

	RunService:UnbindFromRenderStep(activeState.renderKey)

	if jumpStates[brainrotModel] == activeState then
		jumpStates[brainrotModel] = nil
	end
end

local function cancelJump(brainrotModel: Model)
	stopJumpState(brainrotModel)
end

local function applyJumpPose(brainrotModel: Model, state: JumpState)
	if brainrotModel.Parent then
		brainrotModel:PivotTo(
			computeJumpCFrame(state.restPivot, state.jumpProgress, state.jumpHeight, state.spinProgress, state.flipY)
		)
	end
end

function Client_PlotBrainrotJump.Play(brainrotModel: Model, slotModel: Model, options: JumpOptions?)
	if not brainrotModel.Parent or not slotModel.Parent then
		return
	end

	local jumpOptions = options or {}
	local flipY = jumpOptions.flipY == true
	local baseHeight = jumpOptions.baseHeight or UPGRADE_JUMP_BASE_HEIGHT
	local skipIfAnimating = jumpOptions.skipIfAnimating == true

	local pivot = getStandingPivot(slotModel, brainrotModel)
	if not pivot then
		return
	end

	local previousState = jumpStates[brainrotModel]
	local overdrive = 1
	local token = 1

	if previousState then
		if skipIfAnimating then
			return
		end
		token = previousState.token + 1
		overdrive = math.min((previousState.overdrive or 1) + 1, JUMP_MAX_OVERDRIVE)
		stopJumpState(brainrotModel, previousState)
	else
		brainrotModel:PivotTo(pivot)
	end

	local jumpHeight = baseHeight + JUMP_OVERDRIVE_STEP * (overdrive - 1)
	local totalJumpTime = JUMP_UP_TIME + JUMP_DOWN_TIME
	local spinDuration = if flipY then FLIP_DURATION else totalJumpTime

	nextRenderKey += 1
	local renderKey = RENDER_STEP_NAME .. nextRenderKey

	local state: JumpState = {
		token = token,
		overdrive = overdrive,
		restPivot = pivot,
		jumpHeight = jumpHeight,
		flipY = flipY,
		jumpProgress = 0,
		spinProgress = 0,
		startTime = os.clock(),
		renderKey = renderKey,
		connection = nil,
	}
	jumpStates[brainrotModel] = state

	RunService:UnbindFromRenderStep(renderKey)
	RunService:BindToRenderStep(renderKey, Enum.RenderPriority.Last.Value, function()
		if jumpStates[brainrotModel] ~= state then
			RunService:UnbindFromRenderStep(renderKey)
			return
		end

		applyJumpPose(brainrotModel, state)
	end)

	applyJumpPose(brainrotModel, state)

	state.connection = RunService.Heartbeat:Connect(function()
		if jumpStates[brainrotModel] ~= state then
			return
		end

		local elapsed = os.clock() - state.startTime

		if elapsed >= totalJumpTime then
			state.jumpProgress = 1
		elseif elapsed <= JUMP_UP_TIME then
			state.jumpProgress = (elapsed / JUMP_UP_TIME) * 0.5
		else
			local fallElapsed = elapsed - JUMP_UP_TIME
			state.jumpProgress = 0.5 + (fallElapsed / JUMP_DOWN_TIME) * 0.5
		end

		state.spinProgress = math.clamp(elapsed / spinDuration, 0, 1)

		if elapsed >= math.max(totalJumpTime, spinDuration) then
			stopJumpState(brainrotModel, state)

			if brainrotModel.Parent then
				brainrotModel:PivotTo(pivot)
			end
		end
	end)
end

function Client_PlotBrainrotJump.PlayUpgrade(brainrotModel: Model, slotModel: Model)
	Client_PlotBrainrotJump.Play(brainrotModel, slotModel, {
		flipY = true,
		baseHeight = UPGRADE_JUMP_BASE_HEIGHT,
		skipIfAnimating = true,
	})
end

function Client_PlotBrainrotJump.PlayCollect(brainrotModel: Model, slotModel: Model)
	Client_PlotBrainrotJump.Play(brainrotModel, slotModel, {
		flipY = false,
		baseHeight = COLLECT_JUMP_BASE_HEIGHT,
	})
end

function Client_PlotBrainrotJump.Cancel(brainrotModel: Model)
	cancelJump(brainrotModel)
end

return Client_PlotBrainrotJump
