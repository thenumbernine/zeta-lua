local function crystalItemBehavior(parentClass)
	local CrystalItemTemplate = class(parentClass)

	function CrystalItemTemplate:draw(...)
		local sprite = rawget(self, 'sprite')
		self.sprite = 'crystal'
		CrystalItemTemplate.super.draw(self, ...)
		self.sprite = sprite
		CrystalItemTemplate.super.draw(self, ...)
	end

	return CrystalItemTemplate
end

return crystalItemBehavior
