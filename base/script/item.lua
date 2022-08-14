local class = require 'ext.class'
local Object = require 'base.script.obj.object'

--[[
'items' are overlays in rendering (called from Player's draw)
and execute upon player inputRun

for that reason it's disconnected from the game.objs (doesn't call Object:init())
--]]

local PlayerItem = class()

function PlayerItem:init(args)
	self.pos = vec2()
	if args then
		if args.pos then self.pos:set(args.pos[1], args.pos[2]) end
	end
end

function PlayerItem:drawItem(player, R, viewBBox)
	self.drawMirror = player.drawMirror
	if self.drawMirror then
		self.pos[1] = player.pos[1] - self.drawOffset[1]
	else
		self.pos[1] = player.pos[1] + self.drawOffset[1]
	end
	self.pos[2] = player.pos[2] + self.drawOffset[2]
	
	Object.draw(self, R, viewBBox)
end

return PlayerItem
