local function crystalItemBehavior(parentClass)
	local CrystalItemTemplate = class(parentClass)

	function CrystalItemTemplate:draw(...)
		CrystalItemTemplate.super.draw(self, ...)
		local sprite = rawget(self, 'sprite')
		self.sprite = 'crystal'
		CrystalItemTemplate.super.draw(self, ...)
		self.sprite = sprite
	end

	return CrystalItemTemplate
end

return crystalItemBehavior
