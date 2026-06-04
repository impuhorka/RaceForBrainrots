local AnimationBase = {}
AnimationBase.__index = AnimationBase

function AnimationBase.new(instance: Instance)
	local self = setmetatable({}, AnimationBase)
	self.Instance = instance
	self._connections = {}
	return self
end

function AnimationBase:Connect(signal: RBXScriptSignal, fn: (...any) -> ())
	local connection = signal:Connect(fn)
	table.insert(self._connections, connection)
	return connection
end

function AnimationBase:Setup() end

function AnimationBase:Destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self.Instance = nil
end

return AnimationBase
