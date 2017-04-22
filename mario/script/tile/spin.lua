local class = require 'ext.class'
local Tile = require 'base.script.tile.tile'
local game = require 'base.script.singleton.game'

local SpinTile = class(Tile)
SpinTile.name = 'spinblock'
SpinTile.sprite = 'spinblock'
SpinTile.seq = 'stand'
SpinTile.solid = true

local function hitAllOnTile(x,y,hitter)
	for _,obj in ipairs(game.objs) do
		local ixmin = math.floor(obj.pos[1] + obj.bbox.min[1])
		local ixmax = math.ceil(obj.pos[1] + obj.bbox.max[1])
		local iymin = math.floor(obj.pos[2] + obj.bbox.min[2])
		local iymax = math.ceil(obj.pos[2] + obj.bbox.max[2])
		if ixmin <= x and x <= ixmax
		and iymin <= y and y <= iymax
		then
			if obj.playerBounce then
				obj:playerBounce(hitter)
			end
		end
	end
end

function SpinTile:onHit(other, x, y)
	-- hit everything above this tile	
	hitAllOnTile(x, y+1, other)

	local SpinBlock = require 'mario.script.obj.spinblock'
	SpinBlock{
		pos = vec2(x+.5, y),
		tilePos = vec2(x,y),
	}
	game.level:makeEmpty(x,y)
end

function SpinTile:onSpinJump(other, x,y)
	local SpinParticle = require 'mario.script.obj.spinparticle'
	SpinParticle.breakAt(x + .5, y + .5)
	game.level:makeEmpty(x,y)
end

return SpinTile