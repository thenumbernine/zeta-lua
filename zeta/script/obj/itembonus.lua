-- bonus items are temp powerups 
local class = require 'ext.class'
local Item = require 'zeta.script.obj.item'
local vec2 = require 'vec.vec2'
local game = require 'base.script.singleton.game'

local ItemBonus = class(Item)
ItemBonus.duration = 30

function ItemBonus:onUse(player)
	self:playSound('powerup')
	
	-- remove from player / get out of inventory
	player:setHeld(nil)

	self.givingBonus = player 
	self.useGravity = false
	self.collidesWithObjects = false
	self.collidesWithWorld = false
	self.canCarry = false
	self:onGiveBonus(player)
	self.doneTime = game.time + self.duration
end

function ItemBonus:update(dt, ...)
	if self.doneTime and not self.remove then
		local player = self.givingBonus
		local radius = 2
		local theta = 2 * (game.time - self.doneTime)
		self.pos = self.pos * .85 + (player.pos + vec2(radius*math.cos(theta)-.5, radius*math.sin(theta)+1)) * .15
	
		if game.time >= self.doneTime then
			self.doneTime = nil
			self.remove = true
			self:onLoseBonus(player)
			return
		end
	end

	ItemBonus.super.update(self,dt, ...)
end

function ItemBonus:draw(R, viewBBox, holdOverride)
	ItemBonus.super.draw(self, R, viewBBox, holdOverride)
	if self.doneTime and not self.remove then
		-- draw how much time is left
		local gui = require 'base.script.singleton.gui'
		gui.font:drawUnpacked(self.pos[1]+1, self.pos[2]+1, 1, -1, tostring(math.floor(self.doneTime - game.time)))
		local gl = R.gl
		gl.glEnable(gl.GL_TEXTURE_2D)
	end
end

return ItemBonus
