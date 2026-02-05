--[[
behavior for base.script.level subclasses
adds realtime heat modeling

depends on TileType .temperature


https://en.wikipedia.org/wiki/Heat_equation#Heat_conduction_in_non-homogeneous_anisotropic_media
https://reference.wolfram.com/language/PDEModels/tutorial/HeatTransfer/HeatTransfer.html

general form of conductivity:

	ρ cp (∂T/∂t + v ∇·T) - ∇ · (k ∇T) = Q

	ρ cp ∂T/∂t + ρ cp v ∇·T - ∇k · ∇T - k ΔT = Q

ρ in [kg / m^3]
cp in [m^2 / (K s^2)]
ρ cp in [kg / (K m s^2)]
∂T/∂t in [K / s]
ρ cp ∂T/∂t in [kg / (m s^3)]

v in [m/s]
∇·T in [K/m]
ρ cp v ∇·T in [kg / (m s^3)]

ΔT in [K / m^2]
k ΔT must be in [kg / (m s^3)]
so k in [kg m / (K s^3)]

so Q in [W / m^3 = kg / (m s^3)]

for:
	k = thermal conductivity in
	cp = specific heat capacity at constant pressure [m^2 / (K s^2)]
	ρ = matter-density in [kg / m^3]
	T = temperature in [K]
	Q = volumetric heat source i.e. heat flux per volume (W / m^3 = J/S / m^3 = kg / (m s^3))

for uniform medium, assume ∇ k = 0

	∂T/∂t = k/(cp ρ) ΔT + Q / (cp ρ)

substitute α = k/(cp ρ) = thermal diffusivity

	∂T/∂t = α ΔT + Q / (cp ρ)

Q / (cp ρ) is in units [K/s]

for radiation too: (adding https://en.wikipedia.org/wiki/Stefan%E2%80%93Boltzmann_law)

	∂T/∂t = 1/(cp ρ) (k ΔT + Q - μ (T^4 - v^4))

where v = temperature of surroundings

α = diffusivity table (in m^2/s): https://en.wikipedia.org/wiki/Thermal_diffusivity

carbon at 25C:				2.165e-4
aluminium:					9.7e-5
iron:						2.3e-5
steel, 1% carbon:			1.172e-5
stainless steel at 27C:		4.2e-6
silicon:					8.8e-5
air at 300K:				1.9e-5
quartz:						1.4e-6
sandstone:					1.15e-6
water vapor (1atm, 400k):	2.338e-5
ice at 0C:					1.02e-6
water at 25C:				1.43e-7
silicon dioxide:			8.3e-7
brick, common:				5.2e-7
brick, adobe:				2.7e-7
glass:						3.4e-7
wood (yellow pine):			8.2e-8


... relativistic heat?

	ρ cp (∂T/∂t + v ∇·T) - ∇k · ∇T - k ΔT = Q
		... convert material derivative with 3-velocity to spacetime derivative with 4-velocity
	ρ cp (∂T/∂t + v ∇·T) becomes ρ cp u^μ ∇_μ T
	-k ΔT becomes -k (g^μν + u^μ u^ν) ∇_μ ∇_ν T
	-∇k · ∇T becomes -(g^μν + u^μ u^ν) * ∇_μ k * ∇_ν T ... assuming a -+++ metric
	ρ cp u^μ ∇_μ T
		-(g^μν + u^μ u^ν) * ∇_μ k * ∇_ν T
		- k g^μν ∇_μ ∇_ν T - k u^μ u^ν ∇_μ ∇_ν T = Q
	the two could be combined as before to make
		-(g^μν + u^μ u^ν) ∇_μ (k ∇_ν T)
	ρ cp u^μ ∇_μ T - (g^μν + u^μ u^ν) ∇_μ (k ∇_ν T) = Q
	move our extra timelike derivative terms to the rhs:
	ρ cp u^μ ∇_μ T - g^μν ∇_μ (k ∇_ν T) = Q + u^μ u^ν ∇_μ (k ∇_ν T)

	so can you say Q is the 2nd heat derivative in the timelike direction? Q = -u^μ u^ν ∇_μ (k ∇_ν T)
	then things simplify to:
	ρ cp u^μ ∇_μ T - g^μν ∇_μ (k ∇_ν T) = 0
	ρ cp u^μ ∇_μ T = g^μν ∇_μ (k ∇_ν T)

	or ... maybe I can't cancel so much in Q, maybe one of the pieces merges with ρ cp u^μ ∇_μ  ....



ok so irl most heat comes from sun or from inside earth, and then the wind blows it around and that's how we have heat everywhere in our day to day lives.
so i should probably add some fluid advection for my heat transport.
but eventually it lends to a steady state
so i want to have blocks like air dirt etc have default temperature values ... or everything has default temp values ...
but then i want them to be a bit malleable too where neighboring temps can influence them

--]]
local ffi = require 'ffi'
local table = require 'ext.table'
local gl = require 'gl'
local vec4f = require 'vec-ffi.vec4f'
local GLPingPong = require 'gl.pingpong'
local GLProgram = require 'gl.program'
local Temperature = require 'base.script.temperature'
local game = require 'base.script.singleton.game'

return function(parentClass)
	local HeatLevelTemplate = parentClass:subclass()

	-- how often in game-time to update the heat fbo
	HeatLevelTemplate.temperatureUpdateInterval = .1
	HeatLevelTemplate.temperatureDefaultValue = Temperature.CtoK(15)
	HeatLevelTemplate.temperatureDefault_Q_per_Cp_rho = 0
	-- above ground it should be 10 C in Winter to 20 C in Summer

	function HeatLevelTemplate:init(...)
		HeatLevelTemplate.super.init(self, ...)

		self.gradientTex = require 'gl.gradienttex2d'(256,
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
			{
				{22/255, 31/255, 86/255, 1},
				{34/255, 54/255, 152/255, 1},
				{87/255, 49/255, 108/255, 1},
				{156/255, 48/255, 72/255, 1},
				{220/255, 60/255, 57/255, 1},
				{254/255, 96/255, 50/255, 1},
				{255/255, 188/255, 46/255, 1},
				{255/255, 255/255, 55/255, 1},
			},
	--]]
			true
		)

		self.temperatureMap = ffi.new('vec4f[?]', self.size[1] * self.size[2])
		self:copyTileTemperatureToTemperatureMap(1,1,self.size[1],self.size[2])

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
			version = 'latest',
			precision = 'best',
			vertexCode = [[
layout(location=0) in vec2 vertex;

out vec2 pos;
out vec2 tc;

uniform mat4 mvProjMat;

uniform vec4 defaultRect;
uniform vec4 defaultTexRect;	//xy = texcoord offset, zw = texcoord size

void main() {
	pos = defaultRect.xy + defaultRect.zw * vertex;
	tc = defaultTexRect.xy + defaultTexRect.zw * vertex;
	gl_Position = mvProjMat * vec4(pos, 0., 1.);
}
]],
			fragmentCode = [[
in vec2 pos;	//world coordinates
in vec2 tc;	//in [0,1]^2

out vec4 fragColor;

uniform vec2 du;	// 1/ texture size
uniform float dt;	//step between updates

uniform sampler2D temperatureTex;
uniform float tileSize;

void main() {
	// discrete laplacian
	vec4 props = texture(temperatureTex, tc);
	vec4 propsNew = props;
	float T = props.r;
	float Q_per_Cp_rho = props.g;
	float TxR = texture(temperatureTex, tc + vec2(0., du.y)).r;
	float TxL = texture(temperatureTex, tc - vec2(0., du.y)).r;
	float TyR = texture(temperatureTex, tc + vec2(du.x, 0.)).r;
	float TyL = texture(temperatureTex, tc - vec2(du.x, 0.)).r;
	float lapT = TxR + TxL + TyR + TyL - 4. * T;	//dx = dy = 1
	// ∂T/∂t = α ΔT		[K/m^2]
	if (Q_per_Cp_rho == 0.) {		//for now, only allow diffusion into non-source materials.
		float alpha = 1.;	// TODO store this in temperatureMap and update it when tiles change?
		float dT_dt = alpha * lapT;
		float Tnew = T + dT_dt * dt + Q_per_Cp_rho;
		propsNew.r = Tnew;
	}
	fragColor = propsNew;
}
]],
			uniforms = {
				du = {1/self.size[1], 1/self.size[2]},
				temperatureTex = 0,
			},
		}:useNone()

		self.displayTemperatureShader = GLProgram{
			version = 'latest',
			precision = 'best',
			vertexCode = [[
layout(location=0) in vec2 vertex;

out vec2 pos;
out vec2 tc;

uniform mat4 mvProjMat;

uniform vec4 defaultRect;
uniform vec4 defaultTexRect;	//xy = texcoord offset, zw = texcoord size

void main() {
	pos = defaultRect.xy + defaultRect.zw * vertex;
	tc = defaultTexRect.xy + defaultTexRect.zw * vertex;
	gl_Position = mvProjMat * vec4(pos, 0., 1.);
}
]],
			fragmentCode = [[
in vec2 pos;	//world coordinates.   TODO why not just tc * levelSize ?
in vec2 tc;	//in [0,1]^2

out vec4 fragColor;

uniform sampler2D temperatureTex;
uniform sampler2D gradientTex;

uniform vec2 temperatureMinMax;

void main() {
	float temperature = texture(temperatureTex, tc).x;
	float gradtc = (temperature - temperatureMinMax.x) / (temperatureMinMax.y - temperatureMinMax.x);
	//texture1D:
	//fragColor = texture(gradientTex, gradtc);
	//texture2D:
	fragColor = texture(gradientTex, vec2(gradtc, .5));
	fragColor.a = .5;
}
]],
			uniforms = {
				temperatureTex = 0,
				gradientTex = 1,
			},
		}:useNone()
	end

	HeatLevelTemplate.updateHeat = false

	function HeatLevelTemplate:update(dt)
		HeatLevelTemplate.super.update(self, dt)

		-- now do FBO stuff
		-- keep calculating and storing lastHeatUpdateTime even if we're not updating, so we don't accumulate an interval for too long
		if game.time - self.lastHeatUpdateTime < self.temperatureUpdateInterval then return end
		local updateDt = game.time - self.lastHeatUpdateTime
		self.lastHeatUpdateTime = game.time

		local player = game.players[1]
		if not player then return end
		if not self.updateHeat then return end
--print('updating heat at time '..game.time)

		-- do update here
		-- determine view bounds in tile space
		local x1 = math.floor(player.viewBBox.min[1])
		local x2 = math.ceil(player.viewBBox.max[1])
		local y1 = math.floor(player.viewBBox.min[2])
		local y2 = math.ceil(player.viewBBox.max[2])
--print('initial viewBBox:', x1, y1, x2, y2)
		-- grow by 3x
		local growWidth = x2 - x1
		local growHeight = y2 - y1
--print('initial viewBBox size', growWidth, growHeight)
		x1 = x1 - growWidth
		x2 = x2 + growWidth
		y1 = y1 - growHeight
		y2 = y2 + growHeight
--print('after region grow viewBBox:', x1, y1, x2, y2)
		-- test bounds
		if x2 < 0 or y2 < 0 or x1 >= self.size[1] or y1 >= self.size[2] then
--print('viewBBox oob so rejecting')
			return
		end
		-- clamp bounds
		x1 = math.max(x1, 0)
		y1 = math.max(y1, 0)
		x2 = math.min(x2, self.size[1]-1)
		y2 = math.min(y2, self.size[2]-1)
--print('after clamping viewBBox:', x1, y1, x2, y2)
		local viewWidth = x2 - x1 + 1
		local viewHeight = y2 - y1 + 1
--print('viewBBox size: ', viewWidth, viewHeight, 'center', xCenter, yCenter)
		-- setup fbo
		-- set its viewport to the view bounds plus a bit ... maybe 2x or 3x size?
		-- render the heat update shader
		gl.glDisable(gl.GL_BLEND);
		self.temperaturePingPong:swap()
		self.temperaturePingPong:draw{
			-- set viewport to simulation region
			viewport = {x1, y1, viewWidth, viewHeight},
			callback = function()
				-- since we're changing the viewport we have to update the projection too
				-- notice we're drawing 1 pixel <-> 1 texel
				local R = game.R

				-- [[
				R:ortho(-.5*viewWidth, .5*viewWidth, -.5*viewHeight, .5*viewHeight, -100, 100)
				local xCenter = (x1 + x2 + 1) * .5 + 1
				local yCenter = (y1 + y2 + 1) * .5 + 1
				R:viewPos(xCenter, yCenter)
				--]]
				--[[ hmm
				R:ortho(x1,y1,x2,y2,-100,100)
				R:viewPos(0, 0)
				--]]
				
				local temperatureTex = self.temperaturePingPong:prev()
				temperatureTex:bind(0)

				R:quad(
					1,1,
					self.size[1],self.size[2],
					0,0,
					1,1,
					0,
					1,1,1,1,
					self.diffuseTemperatureShader,
					{
						tileSize = self.tileSize,
						dt = updateDt,
					},
					0,0
				)

				temperatureTex:unbind(0)
			end,
		}
		gl.glEnable(gl.GL_BLEND);
	end

	-- TODO ...
	HeatLevelTemplate.showTemperature = false

	function HeatLevelTemplate:draw(...)
		local R = game.R
		HeatLevelTemplate.super.draw(self, ...)

		if not self.showTemperature then return end

		local _0C_in_K = Temperature._0C_in_K
		local temperatureMin = 280	-- _0C_in_K - 100
		local temperatureMax = 320	-- _0C_in_K + 200

		local tempCurTex = self.temperaturePingPong:cur()
		tempCurTex:bind(0)
		self.gradientTex:bind(1)
		
		R:quad(
			1,1,
			self.size[1],self.size[2],
			0,0,
			1,1,
			0,
			1,1,1,1,
			self.displayTemperatureShader,
			{
				temperatureMinMax = {temperatureMin, temperatureMax},
			},
			0,0
		)

		self.gradientTex:unbind(1)
		tempCurTex:unbind(0)
	end

	function HeatLevelTemplate:setTile(...)
		local x, y, tileIndex, fgTileIndex, bgTileIndex, backgroundIndex, dontUpdateTexs = ...
		HeatLevelTemplate.super.setTile(self, ...)
		-- now if we were modifying the tileIndex then update the heat too
		if tileIndex then
			self:copyTileTemperatureToTemperatureMap(x,y,x,y)
			-- TODO don't do this if the change came from a break block
			if not dontUpdateTexs then	-- TODO when is this set again?
				self:onUpdateTemperatureMap(x,y,x,y)
			end
		end
	end

	-- this copies temperature cpu buffer to temperature gpu buffer
	function HeatLevelTemplate:onUpdateTemperatureMap(x1,y1,x2,y2)
		return self:refreshTileTexelsForLayer(
			x1,
			y1,
			x2,
			y2,
			self.temperatureMap,
			self.temperaturePingPong:cur(),
			gl.GL_RGBA,	--gl.GL_RGBA32F,
			gl.GL_FLOAT
		)
	end

	-- ok this should be done at some times (on init, on editor change)
	-- but not others (in-game block changes, i.e. breaking blocks)
	-- or maybe in both cases what I want is not the temp to change, but rather the heat source to change
	--	but even then, upon editor/init I want the temp to initialize to a steady-state
	function HeatLevelTemplate:onUpdateTileMap(x1,y1,x2,y2)
		HeatLevelTemplate.super.onUpdateTileMap(self,x1,y1,x2,y2)

		self:copyTileTemperatureToTemperatureMap(x1,y1,x2,y2)
		self:onUpdateTemperatureMap(x1,y1,x2,y2)
	end

	-- this copies tileType to temperature cpu buffer
	function HeatLevelTemplate:copyTileTemperatureToTemperatureMap(x1,y1,x2,y2)
		if x2 < 1 or y2 < 1 or x1 > self.size[1] or y1 > self.size[2] then return end
		x1 = math.max(x1, 1)
		y1 = math.max(y1, 1)
		x2 = math.min(x2, self.size[1])
		y2 = math.min(y2, self.size[2])
		if x2 < x1 or y2 < y1 then return end
		for y=y1,y2 do
			for x=x1,x2 do
				local tileType = self:getTile(x,y)
				local temp = tileType and tileType.temperature or self.temperatureDefaultValue
				local Q_per_Cp_rho = tileType and tileType.Q_per_Cp_rho or self.temperatureDefault_Q_per_Cp_rho
				self.temperatureMap[(x-1)+self.size[1]*(y-1)] = vec4f(temp, Q_per_Cp_rho, 0, 0)
			end
		end
	end

	return HeatLevelTemplate
end
