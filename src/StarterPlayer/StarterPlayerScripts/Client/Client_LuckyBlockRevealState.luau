local Client_LuckyBlockRevealState = {}

local maskedIndices: { [number]: boolean } = {}
local changedEvent = Instance.new("BindableEvent")

function Client_LuckyBlockRevealState.MaskIndex(index: number)
	if index <= 0 then
		return
	end
	if maskedIndices[index] then
		return
	end
	maskedIndices[index] = true
	changedEvent:Fire()
end

function Client_LuckyBlockRevealState.UnmaskIndex(index: number)
	if not maskedIndices[index] then
		return
	end
	maskedIndices[index] = nil
	changedEvent:Fire()
end

function Client_LuckyBlockRevealState.IsMaskedIndex(index: number?): boolean
	if not index then
		return false
	end
	return maskedIndices[index] == true
end

function Client_LuckyBlockRevealState.OnChanged(listener: () -> ())
	return changedEvent.Event:Connect(listener)
end

return Client_LuckyBlockRevealState
