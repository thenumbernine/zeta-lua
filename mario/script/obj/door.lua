local class = require 'ext.class'
local GameObject  = require 'base.script.obj.object'
local game = require 'base.script.singleton.game'
local threads = require 'base.script.singleton.threads'
local vec2 = require 'vec.vec2'

local Door = class(GameObject)

Door.sprite = 'door'
Door.solidFlags = 0
Door.touchFlags = 0
Door.blockFlags = 0
Door.useGravity = false
Door.canCarryThru = false	-- can we carry objects through this door?

function Door:init(args)
	Door.super.init(self, args)

	self.dests = table()
	self.destIndex = 1

	-- wait for all objects to be linked before testing what tiles have and what don't have doors on them
	threads:add(function()
		coroutine.yield()

		local level = game.level
		
		local doorTile = level:getTile(self.pos[1], self.pos[2]+.5)
		if not doorTile then
			print("door is not on a tile!")
			return
		end
		
		for i=1,level.size[1] do
			local tilecol = level.tile[i]
			for j=1,level.size[2] do
				local tile = tilecol[j]
				
				if tile.warp == doorTile.warp then
					local hasDoor = false
					if tile.objs then
						for _,obj in ipairs(tile.objs) do
							if obj:isa(Door) then
								hasDoor = true
								break
							end
						end
					end
					if not hasDoor then
						-- add it to the list of destinations
						self.dests:insert(vec2(i+.5,j))
					end
				end
			end
		end
	end)
end

function Door:playerLook(player)
	if #self.dests == 0 then return end
	local destx, desty = unpack(self.dests[self.destIndex])
	self.destIndex = self.destIndex % #self.dests + 1
	local level = game.level
	destx, desty = destx + level.pos[1], desty + level.pos[2]
	self:playSound('door')
	player:beginWarp()
	setTimeout(.25, player.endWarp, player, destx, desty, self.canCarryThru)
end

return Door
