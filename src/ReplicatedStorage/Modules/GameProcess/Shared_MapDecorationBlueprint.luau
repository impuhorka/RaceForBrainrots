local Shared_MapDecorationBlueprint = {}

Shared_MapDecorationBlueprint.TreeTemplateNames = { "Tree1", "Tree2", "Tree3" }
Shared_MapDecorationBlueprint.RockTemplateNames = { "Rock1", "Rock2" }
Shared_MapDecorationBlueprint.BushTemplateNames = { "Bush1", "Bush2" }

function Shared_MapDecorationBlueprint.TemplateInList(templateName: string?, templates: { string }): boolean
	if type(templateName) ~= "string" then
		return false
	end
	for _, name in templates do
		if name == templateName then
			return true
		end
	end
	return false
end

function Shared_MapDecorationBlueprint.MarkModel(model: Model, folder: string, templateName: string)
	model:SetAttribute("IsClientMapDecoration", true)
	model:SetAttribute("MapDecorationFolder", folder)
	model:SetAttribute("MapDecorationTemplate", templateName)
end

return Shared_MapDecorationBlueprint
