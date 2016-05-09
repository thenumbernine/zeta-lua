local class = require 'ext.class'
local Game = require 'base.script.singleton.class.game'
local teamColors = require 'base.script.teamcolors'


local MarioGame = class(Game)
MarioGame.maxFallVel = 20
MarioGame.name = 'MarioGame'

function MarioGame:respawn(spawnInfo)
	MarioGame.super.respawn(self, spawnInfo)
	-- mario-specific
	setTimeout(self.respawnTime-.5, function()
		local Puff = require 'mario.script.obj.puff'
		Puff.puffAt(spawnInfo.pos[1], spawnInfo.pos[2])
	end)
end

function MarioGame:getPlayerClass()
	return require 'mario.script.obj.mario'
end

function MarioGame:glInit(R, ...)
	MarioGame.super.glInit(self, R, ...)
	local gl = R.gl

	local changeColorShader = require 'base.script.changecolorshader'(R)
	
	local Mario = require 'mario.script.obj.mario'
	Mario.shader = changeColorShader
	Mario.uniforms = {
--[[
ff 40 70	<- light cloth	-> 1.00 .251 .439
b0 28 60	<- dark cloth	-> .690 .157 .376
50 00 00	<- edge cloth	-> .314 0.00 0.00
ff d0 c0	<- light skin	-> 1.00 .816 .753
ff 70 6f	<- dark skin	-> 1.00 .439 .435
8f 58 1f	<- edge skin	-> .561 .345 .122
--]]
		colorFrom = {.845, .157, .376};
		colorRange = .6;
	}
	
	local PSwitch = require 'mario.script.obj.p-switch'
	PSwitch.shader = changeColorShader
	PSwitch.uniforms = {
--[[
88 88 f8 <- light	-> .533 .533 .973
68 68 d8 <- medium	-> .408 .408 .847
40 40 d8 <- dark	-> .251 .251 .847
--]]
		colorFrom = {.408, .408, .847};
		colorRange = .6;
	}
	PSwitch.color = teamColors[1]
	
	local ExclaimTile = require 'mario.script.tile.exclaim'
	ExclaimTile.shader = changeColorShader
	ExclaimTile.uniforms = {
		colorFrom = {.408, .408, .847};
		colorRange = .6;
	}
	ExclaimTile.color = teamColors[1]

	local ExclaimOutlineTile = require 'mario.script.tile.exclaimoutline'
	ExclaimOutlineTile.shader = changeColorShader
	ExclaimOutlineTile.uniforms = {
		colorFrom = {.408, .408, .847};
		colorRange = .6;
	}
	ExclaimOutlineTile.color = {0,0,0,0}

end

-- helper function for hitting blocks
-- coordinates are level local
function MarioGame:hitAllOnTile(x,y,hitter)
	local tile = self.level:getTile(x,y)
	if tile and tile.objs then
		for _,obj in ipairs(tile.objs) do
			if obj.playerBounce then obj:playerBounce(hitter) end
		end
	end
end


return MarioGame
