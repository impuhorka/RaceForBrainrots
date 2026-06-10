type StatStoreConfig = {
	DefaultValue: number,
	PurchaseOptions: { number },
	Economy: {
		BaseCostPerPoint: number,
		GrowthPerPoint: number,
		RoundTo: number,
	},
}

local function roundToStep(value: number, step: number): number
	if step <= 1 then
		return math.max(1, math.floor(value + 0.5))
	end
	return math.max(step, math.floor(value / step + 0.5) * step)
end

local function createStatStore(config: StatStoreConfig)
	local store = {
		DefaultValue = config.DefaultValue,
		PurchaseOptions = config.PurchaseOptions,
		Economy = config.Economy,
	}

	function store.IsValidPurchaseAmount(amount: number): boolean
		for _, option in store.PurchaseOptions do
			if option == amount then
				return true
			end
		end
		return false
	end

	function store.GetSinglePointCost(currentValue: number): number
		local economy = store.Economy
		local valueDelta = math.max(0, math.floor(currentValue) - store.DefaultValue)
		local rawCost = economy.BaseCostPerPoint * (economy.GrowthPerPoint ^ valueDelta)
		return roundToStep(rawCost, economy.RoundTo)
	end

	function store.GetPurchaseCost(currentValue: number, amount: number): number
		local safeValue = math.max(1, math.floor(currentValue))
		local safeAmount = math.max(1, math.floor(amount))
		local totalCost = 0
		for index = 0, safeAmount - 1 do
			totalCost += store.GetSinglePointCost(safeValue + index)
		end
		return math.max(1, math.floor(totalCost + 0.5))
	end

	function store.GetValueAfterPurchase(currentValue: number, amount: number): number
		return math.max(1, math.floor(currentValue) + math.max(1, math.floor(amount)))
	end

	return store
end

return {
	create = createStatStore,
}
