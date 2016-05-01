local class = require 'ext.class'
local ItemObject = require 'mario.script.obj.item'
local PlayerItem = require 'base.script.item'
local SpinParticle = require 'mario.script.obj.spinparticle'
local game = require 'base.script.singleton.game'


-- this is what tracks the player and mods its interaction with the world

local PickaxeItem = class(PlayerItem)
PickaxeItem.sprite = 'pickaxe'
PickaxeItem.drawOffset = {0, .5}

function PickaxeItem:checkPickAt(x,y,player)
	local level = game.level
	x, y = math.floor(x), math.floor(y)
	local tile = level:getTile(x,y)
	if tile then
		if tile.objs then
			for _,obj in ipairs(tile.objs) do
				if obj ~= player and obj.hitByShell then obj:hitByShell(self) end
			end
		end
		if tile.solid then
			tile:makeEmpty()
			level:alignTileTemplates(x,y,x,y)
			SpinParticle.breakAt(x+.5, y+.5)
			return true
		end
	end
end

function PickaxeItem:onShoot(player)
	local dir
	if player.drawMirror then
		dir = -1
	else
		dir = 1
	end

	-- check tiles above
	if self:checkPickAt(player.pos[1], player.pos[2] + player.bbox.max[2] + 1, player) then return end
	
	-- in front
	for y = math.floor(player.pos[2] + player.bbox.max[2]), math.floor(player.pos[2] + player.bbox.min[2] - 1), -1 do
		if self:checkPickAt(player.pos[1] + dir, y, player) then break end
	end
end


-- this is the world object

local Pickaxe = class(ItemObject)
Pickaxe.sprite = 'pickaxe'
Pickaxe.itemClass = PickaxeItem

return Pickaxe
