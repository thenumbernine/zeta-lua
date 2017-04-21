local class = require 'ext.class'
local ItemObject  = require 'mario.script.obj.item'
local PlayerItem = require 'base.script.item'


local WingsItem = class(PlayerItem)
WingsItem.sprite = 'wings'
WingsItem.seq = 'fly'
WingsItem.drawOffset = {-.5, 1}
WingsItem.followTime = 30

function WingsItem:update(player, dt)
--[[
	self.followTime = self.followTime - dt
	if self.followTime < 0 then
		player.item = nil	-- remove this item
		return
	end
--]]

	if player.inputJump then
		player.onground = false
		player.vel[2] = 10
	end
end


local Wings = class(ItemObject)
Wings.sprite = 'wings'
Wings.itemClass = WingsItem

return Wings
