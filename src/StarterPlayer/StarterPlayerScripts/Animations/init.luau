local CollectionService = game:GetService("CollectionService")

local AnimatedButton0 = require(script.AnimatedButton0)

local TAG_ANIMATIONS = {
	AnimatedButton0 = AnimatedButton0,
}

local active: { [Instance]: any } = {}

local teardown

local function setup(instance: Instance)
	if not instance:IsA("ImageButton") then
		return
	end
	if active[instance] then
		return
	end

	for tag, animationClass in TAG_ANIMATIONS do
		if CollectionService:HasTag(instance, tag) then
			local animation = animationClass.new(instance)
			animation:Setup()
			active[instance] = animation
			animation:Connect(instance.Destroying, function()
				teardown(instance)
			end)
			return
		end
	end
end

teardown = function(instance: Instance)
	local animation = active[instance]
	if not animation then
		return
	end
	animation:Destroy()
	active[instance] = nil
end

for tag in TAG_ANIMATIONS do
	CollectionService:GetInstanceAddedSignal(tag):Connect(setup)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(teardown)

	for _, instance in CollectionService:GetTagged(tag) do
		setup(instance)
	end
end

return nil
