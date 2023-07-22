local ZetaLevel = require 'base.script.level':subbehavior(
	require 'base.script.behavior.level_temperature'
)

-- only spawn the player ... and whatever's close to him
-- then, as the player moves, spawn things just out of his screen
function ZetaLevel:initialSpawn()
end

-- TODO maybe built-in smoothing?
function ZetaLevel:clearTileAndBreak(x,y, other)
	assert(x >= 1 and y >= 1 and x <= self.size[1] and y <= self.size[2])
	
	other:playSound'explode1'

	--[[ deathtopieces-like behavior 
	local tileIndex = self.fgTileMap[(x-1)+self.size[1]*(y-1)]
	self.tileMap[(x-1)+self.size[1]*(y-1)] = 0
	self.fgTileMap[(x-1)+self.size[1]*(y-1)] = 0
	local tilesWide = self.texpackTex.width / self.tileSize
	local tilesHigh = self.texpackTex.height / self.tileSize
	if tileIndex > 0 then
		local ti = (tileIndex - 1) % tilesWide
		local tj = (tileIndex - ti - 1) / tilesWide

		local SpritePieces = require 'zeta.script.obj.spritepieces'
		SpritePieces.makeFrom{
			obj = {
				pos = {x+.5,y+.5},
				tex = assert(self.texpackTex),
				drawScale = {1,1},
				drawCenter = {.5,.5},
				u0 = ti/tilesWide,
				v0 = (tj+1)/tilesHigh,
				u1 = (ti+1)/tilesWide,
				v1 = tj/tilesHigh,
			},
			dir = other.vel:normalize(),
			divs = {4,4},
		}
	end
	--]]
	-- [[ breakblocks (works with regenerating breakblocks
	local BreakBlock = require 'zeta.script.obj.breakblock'
	BreakBlock{
		pos={x,y}
	}
	--]]
end

return ZetaLevel
