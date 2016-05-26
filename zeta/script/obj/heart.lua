local class = require 'ext.class'
local Item = require 'zeta.script.obj.item'

local Heart = class(Item)
Heart.sprite = 'heart'
Heart.invSeq = 'stand1'	-- stop flashing!

-- [[ go away after a few seconds 
function Heart:init(...)
	Heart.super.init(self, ...)
	local game = require 'base.script.singleton.game'
	self.removeTime = game.time + 10
end
--]]

-- [[ for regular touch-based items
Heart.useGravity = false
function Heart:touch(other)
	if self.remove then return end
	if not other:isa(require 'zeta.script.obj.hero') then return true end
	other.health = math.min(other.health + 1, other.maxHealth)
	self:playSound('powerup')
	self.remove = true
end
--]]

--[[ for player to have to pick them up -- like bonus items
function Heart:playerGrab(player)
	player.health = math.min(player.health + 1, player.maxHealth)
	self:playSound('powerup')
	self.remove = true
end
--]]

--[[ for inventory items:
function Heart:onUse(player)
	player.health = math.min(player.health + 1, player.maxHealth)
	self:playSound('powerup')
	self.remove = true
end
--]]

return Heart
