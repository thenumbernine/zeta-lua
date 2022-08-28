-- behavior for base.script.level subclasses
-- adds realtime heat modeling
local ffi = require 'ffi'
local class = require 'ext.class'
local table = require 'ext.table'
local gl = require 'gl'
local vec4f = require 'vec-ffi.vec4f'
local GLPingPong = require 'gl.pingpong'
local GLProgram = require 'gl.program'
local Temperature = require 'base.script.temperature'
local game = require 'base.script.singleton.game'

return function (parentClass)
	local HeatTemplate = class(parentClass)

	-- how often in game-time to update the heat fbo 
	local updateFreq = .1
	local defaultTemperature = Temperature.CtoK(15)
	-- above ground it should be 10 C in Winter to 20 C in Summer

	function HeatTemplate:init(...)
		HeatTemplate.super.init(self, ...)

		self.gradientTex = require 'gl.gradienttex'(256, 
	--[[ rainbow or heatmap or whatever
			{
				{0,0,0,0},
				{1,0,0,1/6},
				{1,1,0,2/6},
				{0,1,1,3/6},
				{0,0,1,4/6},
				{1,0,1,5/6},
				{0,0,0,6/6},
			},
	--]]
	-- [[ sunset pic from https://blog.graphiq.com/finding-the-right-color-palettes-for-data-visualizations-fcd4e707a283#.inyxk2q43
			table{
				vec4f(22,31,86,255),
				vec4f(34,54,152,255),
				vec4f(87,49,108,255),
				vec4f(156,48,72,255),
				vec4f(220,60,57,255),
				vec4f(254,96,50,255),
				vec4f(255,188,46,255),
				vec4f(255,255,55,255),
			}:map(function(c,i)
				return {(c/255):unpack()}
			end),
	--]]
			true
		)



local sofar = {}
		self.temperatureMap = ffi.new('vec4f_t[?]', self.size[1] * self.size[2])
		for j=0,self.size[2]-1 do
			for i=0,self.size[1]-1 do
				local tileType = self:getTile(i+1,j+1)
				local temp = tileType and tileType.temperature or defaultTemperature
if not sofar[temp] then
	sofar[temp] = true
print('temp', temp, 'at', i, j)
end
				self.temperatureMap[i+self.size[1]*j] = vec4f(temp, 0, 0, 0)
			end
		end

		self.temperaturePingPong = GLPingPong{
			width = self.size[1],
			height = self.size[2],
			format = gl.GL_RGBA,
			internalFormat = gl.GL_RGBA32F,
			type = gl.GL_FLOAT,
			data = self.temperatureMap,
			magFilter = gl.GL_LINEAR,
			minFilter = gl.GL_NEAREST,
		}
	
		self.lastHeatUpdateTime = game.time
	
		self.diffuseTemperatureShader = GLProgram{
			vertexCode = [[
varying vec2 pos;
varying vec2 tc;
void main() {
	pos = gl_Vertex.xy;
	tc = gl_MultiTexCoord0.xy;
	gl_Position = ftransform();
}
]],
			fragmentCode = [[
uniform vec2 du;	// 1/ texture size
varying vec2 pos;	//world coordinates
varying vec2 tc;	//in [0,1]^2
uniform sampler2D temperatureTex;
uniform float tileSize;
void main() {
	gl_FragColor = texture2D(temperatureTex, tc);
}
]],
			uniforms = {
				du = {1/self.size[1], 1/self.size[2]},
				temperatureTex = 0,
			},
		}
	
		self.displayTemperatureShader = GLProgram{
			vertexCode = [[
varying vec2 pos;
varying vec2 tc;
void main() {
	pos = gl_Vertex.xy;
	tc = gl_MultiTexCoord0.xy;
	gl_Position = ftransform();
}
]],
			fragmentCode = [[
varying vec2 pos;	//world coordinates.   TODO why varying?  why not just tc * levelSize ?
varying vec2 tc;	//in [0,1]^2

uniform sampler2D temperatureTex;
uniform sampler1D gradientTex;

uniform vec2 temperatureMinMax;

void main() {
	float temperature = texture2D(temperatureTex, tc).x;
	float gradtc = (temperature - temperatureMinMax.x) / (temperatureMinMax.y - temperatureMinMax.x);
	gl_FragColor = texture1D(gradientTex, gradtc);
	gl_FragColor.a = .5;
}
]],
			uniforms = {
				temperatureTex = 0,
				gradientTex = 1,
			},
		}
	end

	function HeatTemplate:update(dt)
		HeatTemplate.super.update(self, dt)

do return end
		-- now do FBO stuff
		if game.t - self.lastHeatUpdateTime < updateFreq then return end

		self.lastHeatUpdateTime = game.t

		-- do update here
		-- determine view bounds in tile space
		local x1 = math.floor(self.viewBBox.min[1])
		local x2 = math.ceil(self.viewBBox.max[1])
		local y1 = math.floor(self.viewBBox.min[2])
		local y2 = math.ceil(self.viewBBox.max[2])
		-- grow by 3x
		local dx = x2 - x1
		local dy = y2 - y1
		x1 = x1 - dx
		x2 = x2 + dx
		y1 = y1 - dy
		y2 = y2 + dy
		-- test bounds
		if x2 < 0 or y2 < 0 or x1 >= self.size[1] or y1 >= self.size[2] then return end
		-- clamp bounds
		x1 = math.clamp(x1, 0, self.size[1]-1)
		x2 = math.clamp(x2, 0, self.size[1]-1)
		y1 = math.clamp(y1, 0, self.size[2]-1)
		y2 = math.clamp(y2, 0, self.size[2]-1)
		-- setup fbo
		-- set its viewport to the view bounds plus a bit ... maybe 2x or 3x size?
		-- render the heat update shader
		local fbo = self.temperaturePingPong.fbo
		fbo:enable()
		fbo.check()
		fbo:use()
		local viewWidth = x2-x1+1
		local viewHeight = y2-y1+1
		-- set viewport to simulation region
		gl.glViewport(x1, y1, viewWidth, viewHeight)
		-- since we're changing the viewport we have to update the projection too
		-- notice we're drawing 1 pixel <-> 1 texel
		local R = game.R
		R:ortho(-viewWidth, viewWidth, -viewHeight, viewHeight, -100, 100)
		R:viewPos(player.viewPos[1], player.viewPos[2])
		self.diffuseTemperatureShader:use()
		if self.diffuseTemperatureShader.uniforms.tileSize then
			gl.glUniform1f(self.diffuseTemperatureShader.uniforms.tileSize.loc, self.tileSize)
		end
		self.temperaturePingPong:cur():bind(0)
		-- TODO make sure the projection matrix is reset because we're changing the viewport
		R:quad(
			1, 1,
			self.size[1],
			self.size[2],
			0,0,
			1,1,
			0,
			1,1,1,1)
		self.temperaturePingPong:cur():unbind(0)
		self.diffuseTemperatureShader:useNone()
		fbo:useNone()
		fbo:disable()
	end

	-- TODO ...
	HeatTemplate.showTemperature = false

	function HeatTemplate:draw(...)
		HeatTemplate.super.draw(self, ...)
	
		if not self.showTemperature then return end
	
		local _0C_in_K = Temperature._0C_in_K
		local temperatureMin = 280	-- _0C_in_K - 100
		local temperatureMax = 320	-- _0C_in_K + 200

		local tempCurTex = self.temperaturePingPong:cur()
		self.displayTemperatureShader:use()	-- I could use the shader param but then I'd have to set uniforms as a table, which is slower
		if self.displayTemperatureShader.uniforms.temperatureMinMax then
			gl.glUniform2f(self.displayTemperatureShader.uniforms.temperatureMinMax.loc, temperatureMin, temperatureMax)
		end
		tempCurTex:bind(0)
		self.gradientTex:bind(1)
		local R = game.R
		R:quad(
			1, 1,
			self.size[1],
			self.size[2],
			0,0,
			1,1,
			0,
			1,1,1,1)
		self.gradientTex:unbind(1)
		tempCurTex:unbind(0)
		self.displayTemperatureShader:useNone()
	end

	return HeatTemplate 
end
