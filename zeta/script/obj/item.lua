local Object = require 'base.script.obj.object'
local Hero = require 'zeta.script.obj.hero'
local game = require 'base.script.singleton.game'

local Item = class(Object)
Item.playerHoldOffsetStanding = {.625, .125}
Item.playerHoldOffsetDucking = {.625, -.25}

function Item:init(args, ...)
	Item.super.init(self, args, ...)

	-- if SpawnInfo created it then 'args' is the SpawnInfo ...
	local spawnInfoIndex = game.level.spawnInfos:find(args)
	if spawnInfoIndex then
		if game.session['got permanent item '..spawnInfoIndex] then
			self.remove = true
		end
	end
end

-- new touch system
Item.solidFlags = 0
Item.touchFlags = Item.SOLID_WORLD + Item.SOLID_YES
Item.blockFlags = Item.SOLID_WORLD
function Item:touch(other, side)
	if other == self.heldby then return true end
end

function Item:playerGrab(player, side)
	-- if the player is going to be holding it then unlink it from the room system
	-- or else it'll be erased from the inventory as soon as the player changes rooms
	-- TODO tell the spawn object not to spawn it anymore 
	if self.spawnInfo then
		local spawnInfoIndex = game.level.spawnInfos:find(self.spawnInfo)
		assert(spawnInfoIndex, "failed to find item spawnInfo in level")
		game.session['got permanent item '..spawnInfoIndex] = true
		if self.spawnInfo.obj == self then
			self.spawnInfo.obj = nil
		end
		self.spawnInfo = nil
	end
	
	-- add item to player
	do
		local found = false
		for _,items in ipairs(player.items) do
			if getmetatable(self) ~= require 'zeta.script.obj.keycard'	-- they have to be held uniquely
			and getmetatable(items[1]) == getmetatable(self)
			and items[1].name == self.name
			then
				items:insert(self)
				found = true
				break
			end
		end
		if not found then
			player.items:insert(table{self})
		end
	end
	
	if self.isWeapon then
		player.weapon = self
	end
	self.heldby = player

	self.solidFlags = 0
	self.blockFlags = 0
	self.touchFlags = 0
end

return Item
