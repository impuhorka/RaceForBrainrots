local AvatarEditorService = game:GetService("AvatarEditorService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedModules = require(ReplicatedStorage.Modules.Loader)
local ClientLoader = require(script.Parent.Parent.Loader)

local Shared_FavoritePrompt = SharedModules.require("Shared_FavoritePrompt")

local Client_FavoritePrompt = {}

local PLACE_ID = game.PlaceId
local ITEM_TYPE = Enum.AvatarItemType.Asset

local favoritePromptHandler: RemoteEvent? = nil
local started = false

local function getFavoritePromptHandler(): RemoteEvent
	if favoritePromptHandler then
		return favoritePromptHandler
	end

	favoritePromptHandler = ReplicatedStorage:WaitForChild("Events"):WaitForChild("FavoritePromptHandler") :: RemoteEvent
	return favoritePromptHandler
end

local function hasPromptBeenShown(): boolean
	local Client_Data = ClientLoader.require("Client_Data")
	return Client_Data:GetValue("FavoritePromptShown") == true
end

local function markPromptShown()
	if hasPromptBeenShown() then
		return
	end

	getFavoritePromptHandler():FireServer("MarkShown")
end

local function isExperienceFavorited(): boolean?
	local ok, favorited = pcall(function()
		return AvatarEditorService:GetFavoriteAsync(PLACE_ID, ITEM_TYPE)
	end)
	if not ok then
		return nil
	end

	return favorited == true
end

local function promptFavorite()
	pcall(function()
		AvatarEditorService:PromptSetFavorite(PLACE_ID, ITEM_TYPE, true)
	end)
end

local function runFavoritePromptFlow()
	if hasPromptBeenShown() then
		return
	end

	task.wait(Shared_FavoritePrompt.PlaytimeSeconds)

	if hasPromptBeenShown() then
		return
	end

	local favorited = isExperienceFavorited()
	if favorited == true then
		markPromptShown()
		return
	end

	promptFavorite()
	markPromptShown()
end

function Client_FavoritePrompt.Init()
	if started then
		return
	end
	started = true

	task.spawn(function()
		local Client_Data = ClientLoader.require("Client_Data")
		Client_Data.WaitUntilReady()

		if hasPromptBeenShown() then
			return
		end

		runFavoritePromptFlow()
	end)
end

return Client_FavoritePrompt
