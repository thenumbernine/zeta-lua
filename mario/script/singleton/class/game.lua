local GLProgram = require 'gl.program'
local Game = require 'base.script.singleton.class.game'
local teamColors = require 'base.script.teamcolors'
local setTimeout = require 'base.script.settimeout'
local behaviors = require 'base.script.behaviors'
local MarioGame = behaviors(Game
--	, require 'base.script.behavior.postfbo'
)

MarioGame.maxFallVel = 20
MarioGame.name = 'MarioGame'

-- TODO base by max(tilesWide,tilesHigh)
MarioGame.viewSize = viewSize or 20

function MarioGame:respawn(spawnInfo)
	-- no respawning the player start (right?)
	if spawnInfo.spawn == 'base.script.obj.start' then return end

	MarioGame.super.respawn(self, spawnInfo)
	-- mario-specific
	setTimeout(self.respawnTime-.5, function()
		local Puff = require 'mario.script.obj.puff'
		Puff.puffAt(spawnInfo.pos[1], spawnInfo.pos[2])
	end)
end

function MarioGame:hitAllOnTile(x,y,hitter)
	for _,obj in ipairs(self.objs) do
		if obj ~= hitter then
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
end

function MarioGame:getPlayerClass()
	return require 'mario.script.obj.mario'
end

function MarioGame:glInit(R)
	MarioGame.super.glInit(self, R)

	local changeColorShader = GLProgram{
		version = 'latest',
		precision = 'best',
		vertexCode = [[
in vec4 vertex;
out vec2 tc;

uniform mat4 mvProjMat;

uniform vec4 defaultRect;
uniform vec4 defaultTexRect;	//xy = texcoord offset, zw = texcoord size
uniform vec4 defaultCenterAndRot;	//zw = cos(angle), sin(angle)

void main() {
	tc = defaultTexRect.xy + defaultTexRect.zw * vertex;

	vec2 rxy = vertex * defaultRect.zw - defaultCenterAndRot.xy;
	rxy = vec2(
		rxy.x * defaultCenterAndRot.z - rxy.y * defaultCenterAndRot.w,
		rxy.y * defaultCenterAndRot.z + rxy.x * defaultCenterAndRot.w
	);
	rxy += defaultCenterAndRot.xy + defaultRect.xy;
	gl_Position = mvProjMat * vec4(rxy, 0., 1.);
}
]],
		fragmentCode=[[
in vec2 tc;
out vec4 fragColor;
uniform vec4 color;
uniform sampler2D tex;
uniform vec3 colorFrom;
uniform float colorRange;
void main() {
	//TODO do distance in HSV ...
	fragColor = texture2D(tex, tc);
	float colorDist = length(fragColor.rgb - colorFrom);
	float lerp = clamp(0., 1. - colorDist / colorRange, 1.);
	fragColor = mix(fragColor, color, lerp);
}
]],
		uniforms={tex=0},
	}

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

return MarioGame
