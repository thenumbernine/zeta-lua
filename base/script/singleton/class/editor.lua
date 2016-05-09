require 'ext.table'
local class = require 'ext.class'
local bit = require 'bit'
local ffi = require 'ffi'
local sdl = require 'ffi.sdl'
local gl = require 'ffi.OpenGL'
local ig = require 'ffi.imgui'
local gui = require 'base.script.singleton.gui'
local animsys = require 'base.script.singleton.animsys'
local game = require 'base.script.singleton.game'
local vec2 = require 'vec.vec2'
local box2 = require 'vec.box2'

--[[
Editor api:
--]]

local Editor = class()

Editor.active = true

Editor.brushOptions = table{
	{
		name='Tile',
		paint = function(self, cx, cy)
			local level = game.level
			
			local xmin = math.floor(cx - tonumber(self.brushTileSize[0]-1)/2)
			local ymin = math.floor(cy - tonumber(self.brushTileSize[0]-1)/2)
			local xmax = xmin + self.brushTileSize[0]-1
			local ymax = ymin + self.brushTileSize[0]-1
			if xmax < 1 then return end
			if ymax < 1 then return end
			if xmin > level.size[1] then return end
			if ymin > level.size[2] then return end
			if xmin < 1 then xmin = 1 end
			if ymin < 1 then ymin = 1 end
			if xmax > level.size[1] then xmax = level.size[1] end
			if ymax > level.size[2] then ymax = level.size[2] end
			for y=ymin,ymax do
				for x=xmin,xmax do
					local offset = x-1 + level.size[1] * (y-1)
					if self.paintingTileType[0] then
						level.tileMap[offset] = self.selectedTileTypeIndex[0]
					end
					if self.paintingFgTile[0] then
						level.fgTileMap[offset] = self.selectedFgTileIndex
					end
					if self.paintingBgTile[0] then
						level.bgTileMap[offset] = self.selectedBgTileIndex
					end
					if self.paintingBackground[0] then
						level.backgroundMap[offset] = self.selectedBackgroundIndex[0]
					end
				end
			end
		end,
	},
	{
		name='Rect',
		paint = function(self, map, x, y, value)
		end,
	},
	{
		name='Fill',
		paint = function(self, x, y)
			local level = game.level
			local alreadyHit = table()
			local check = table{vec2(x,y)}
			local offset = x-1 + level.size[1] * (y-1)
			local maps = {
				level.tileMap,
				level.fgTileMap,
				level.bgTileMap,
				level.backgroundMap,
			}		
			local mask = {
				self.paintingTileType[0],
				self.paintingFgTile[0],
				self.paintingBgTile[0],
				self.paintingBackground[0],
			}
			local values = {
				self.selectedTileTypeIndex[0],
				self.selectedFgTileIndex,
				self.selectedBgTileIndex,
				self.selectedBackgroundIndex[0],
			}
			
			local srcValues = {}
			for i=1,#maps do
				srcValues[i] = maps[i][offset] 
			end
			
			local paintingAny = false
			for i=1,#maps do
				paintingAny = paintingAny or mask[i]
			end
			if not paintingAny then return end
			
			local different = false
			for i=1,#maps do
				-- enable to only check maps of fill for congruency 
				do	--if mask[i] then
					if values[i] ~= srcValues[i] then
						different = true
						break
					end
				end
			end
			if not different then return end
			
			while #check > 0 do
				local pt = check:remove(1)
				alreadyHit[pt[1]..','..pt[2]] = true
				local offset = (pt[1]-1) + game.level.size[1] * (pt[2]-1)
				for i=1,#maps do
					if mask[i] then
						maps[i][offset] = values[i]
					end
				end
				for side,dir in pairs(dirs) do
					local nbhd = pt + dir
					if not alreadyHit[nbhd[1]..','..nbhd[2]] then
						local offset = (nbhd[1]-1) + game.level.size[1] * (nbhd[2]-1)
						local same = true
						for i=1,#maps do
							do	--if mask[i] then
								if srcValues[i] ~= maps[i][offset] then
									same = false
									break
								end
							end
						end
						if same then
							check:insert(nbhd)
						end
					end
				end
			end
		end,
	},
}

function Editor:init()
	self.showTileTypes = ffi.new('bool[1]',1)
	self.paintingTileType = ffi.new('bool[1]',1)
	self.paintingFgTile = ffi.new('bool[1]',1)
	self.paintingBgTile = ffi.new('bool[1]',1)
	self.paintingBackground = ffi.new('bool[1]',1)

	self.brushTile = ffi.new('bool[1]',1)
	self.brushRect = ffi.new('bool[1]',1)
	self.brushFill = ffi.new('bool[1]',1)

	self.brushTileSize = ffi.new('int[1]',1)

	self.selectedBrushIndex = ffi.new('int[1]', 1)
	
	self.editTilesOrObjects = ffi.new('int[1]',0)
end

function Editor:setTileKeys()

	self.selectedTileTypeIndex = ffi.new('int[1]',0)
	self.selectedBackgroundIndex = ffi.new('int[1]',0)
	self.selectedFgTileIndex = 0
	self.selectedBgTileIndex = 0
	self.selectedSpawnIndex = ffi.new('int[1]',0)

	-- tile types
	self.tileOptions = game.levelcfg.tileTypes:map(function(tileType)
		return {
			tileType = tileType,
			value = ffi.new('bool[1]', 0),
		}
	end)
	self.tileOptions[0] = {
		tileType = {name='empty'},
		value = ffi.new('bool[1]', 0),
	}

	-- backgrounds
	self.backgroundOptions = game.level.backgrounds:map(function(background)
		return {
			background = background,
			value = ffi.new('bool[1]', 0),
		}
	end)
	self.backgroundOptions[0] = {
		background = {name='empty'},
		value = ffi.new('bool[1]',0),
	}

	-- spawn
	self.spawnOptions = game.levelcfg.spawnTypes:map(function(spawnType)
		return {
			spawnType = spawnType,
			value = ffi.new('bool[1]',0),
		}
	end)

end

local ImVec2_00 = ffi.new('struct ImVec2',0,0)
local ImVec2_11 = ffi.new('struct ImVec2',1,1)
local ImVec4_0000 = ffi.new('struct ImVec4',0,0,0,0)
local ImVec4_1111 = ffi.new('struct ImVec4',1,1,1,1)

function Editor:updateGUI()
	ig.igText('EDITOR')
	
	ig.igRadioButton('Edit Tiles', self.editTilesOrObjects, 0)
	
	ig.igCheckbox('Tile Type', self.paintingTileType)
	ig.igCheckbox('Fg Tile', self.paintingFgTile)
	ig.igCheckbox('Bg Tile', self.paintingBgTile)
	ig.igCheckbox('Background', self.paintingBackground)
	
	ig.igRadioButton('Edit Objects', self.editTilesOrObjects, 1)

	if self.editTilesOrObjects[0] == 0 then
		if ig.igCollapsingHeader('Brush Options:', 0) then
			for i,brushOption in ipairs(self.brushOptions) do
				ig.igRadioButton(brushOption.name..' brush', self.selectedBrushIndex, i)
			end
			ig.igSliderInt('Brush Tile Size', self.brushTileSize, 1, 20, '%.0f')
		end
		if ig.igCollapsingHeader('Tile Type Options:',0) then
			for i=0,#self.tileOptions do
				ig.igRadioButton(self.tileOptions[i].tileType.name, self.selectedTileTypeIndex, i)
			end
		end
		
		for _,info in ipairs{
			-- foreground
			{
				side = 'Fg',
			},
			-- background
			{
				side = 'Bg',
			},
		} do
			local side = info.side
			local lc = side:lower()	
			if ig.igCollapsingHeader(side..' Tile Options:',0) then
				
				self[lc..'TileWindowOpenedPtr'] = self[lc..'TileWindowOpenedPtr'] or ffi.new('bool[1]',false)
			
				local tex = game.level.texpackTex
				local texIDPtr = ffi.cast('void*',ffi.cast('intptr_t',tex.id))
				local tilesWide = tex.width / 16
				local tilesHigh = tex.height / 16
				local bw, bh = 16, 16	-- button size
				local ti = (self['selected'..side..'TileIndex'] - 1) % tilesWide
				local tj = (self['selected'..side..'TileIndex'] - 1 - ti) / tilesWide
				if ig.igImageButton(
					texIDPtr,
					ffi.new('struct ImVec2', bw,bh),	-- size
					ffi.new('struct ImVec2', ti/tilesWide, tj/tilesHigh),	-- uv0
					ffi.new('struct ImVec2', (ti+1)/tilesWide, (tj+1)/tilesHigh),	-- uv1
					-1,			-- frame_padding
					ImVec4_0000,	-- bg_color
					ImVec4_1111)	-- tint_color
				then
					-- popup of the whole thing?
					self['show'..side..'TileWindow'] = true
				end
				if ig.igButton('Clear '..side..' Tile', ImVec2_00) then
					self['selected'..side..'TileIndex'] = 0
				end

				if self['show'..side..'TileWindow'] then
					ig.igBegin(side..' Tile Window', self[lc..'TileWindowOpenedPtr'], 0)
					
					local texScreenPos = ffi.new('struct ImVec2[1]')
					ig.igGetCursorScreenPos(texScreenPos)
					local mousePos = ffi.new('struct ImVec2[1]')
					ig.igGetMousePos(mousePos)

					local cursorX = mousePos[0].x - texScreenPos[0].x
					local cursorY = mousePos[0].y - texScreenPos[0].y

					if ig.igImageButton(
						texIDPtr,
						ffi.new('struct ImVec2', tex.width, tex.height),	-- size
						ImVec2_00,	-- uv0
						ImVec2_11,	-- uv1
						-1,	-- frame_padding
						ImVec4_0000,	-- bg_color
						ImVec4_1111)	-- tint_color
					then
						local x = math.clamp(math.floor(cursorX / tex.width * tilesWide), 0, tilesWide-1)
						local y = math.clamp(math.floor(cursorY / tex.height * tilesHigh), 0, tilesHigh-1)
						self['selected'..side..'TileIndex'] = 1+x+tilesWide*y
						self['show'..side..'TileWindow'] = false
					end
					
					ig.igEnd()
				end
			end
		end
		if ig.igCollapsingHeader('Background Options:',0) then
			for i=0,#self.backgroundOptions do
				ig.igRadioButton(self.backgroundOptions[i].background.name, self.selectedBackgroundIndex, i)
			end
		end
		ig.igCheckbox('Show Tile Types', self.showTileTypes)
	end
	if self.editTilesOrObjects[0] == 1 then
		if ig.igCollapsingHeader('Object Options:',0) then
			for i,spawnOption in ipairs(self.spawnOptions) do
				ig.igRadioButton(spawnOption.spawnType.spawn, self.selectedSpawnIndex, i)
			end
		end
	end
	if ig.igButton('Save', ImVec2_00) then
		self:save()
	end
end



--[[
return 'true' if we're processing something
--]]
function Editor:event(event)
	local canHandleKeyboard = not ig.igGetIO()[0].WantCaptureKeyboard

	-- check for enable/disable
	if event.type == sdl.SDL_KEYDOWN
	or event.type == sdl.SDL_KEYUP
	then
		local buttonDown = event.type == sdl.SDL_KEYDOWN
		if event.key.keysym.sym == sdl.SDLK_TAB then	-- editor
			if buttonDown and canHandleKeyboard then
				self.active = not self.active
				return true
			end
		elseif event.key.keysym.sym == sdl.SDLK_LSHIFT
		or event.key.keysym.sym == sdl.SDLK_RSHIFT
		then
			self.shiftDown = buttonDown
		end
	end

	if not self.active then return end

	-- active editor events here
end

--[[
now's where I need imgui ...
buttons:
'paint background'
'paint bgtile'
'paint fgtile'
'paint tile type'
'save'
'load'
'path:' ...
--]]

function Editor:doBrush(map, x, y, value)
	self.brushOptions[self.selectedBrushIndex[0]].paint(self, map, x, y, value)
end

function Editor:update()
	if not self.active then return end
	sdl.SDL_ShowCursor(sdl.SDL_ENABLE)
	
	local canHandleMouse = not ig.igGetIO()[0].WantCaptureMouse
	if not canHandleMouse then return end
	
	local level = game.level
	local mouse = gui.mouse
	if mouse.leftDown and not found then
		local xf = self.viewBBox.min[1] + (self.viewBBox.max[1] - self.viewBBox.min[1]) * mouse.pos[1]
		local yf = self.viewBBox.min[2] + (self.viewBBox.max[2] - self.viewBBox.min[2]) * mouse.pos[2]
		local x = math.floor(xf)
		local y = math.floor(yf)
		if x >= 1 and y >= 1 and x <= level.size[1] and y <= level.size[2] then
			if self.editTilesOrObjects[0] == 0 then
				if self.shiftDown then
					if self.paintingTileType[0] then
						self.selectedTileTypeIndex[0] = level.tileMap[x-1+level.size[1]*(y-1)]
					end
					if self.paintingFgTile[0] then
						self.selectedFgTileIndex = level.fgTileMap[x-1+level.size[1]*(y-1)]
					end
					if self.paintingBgTile[0] then
						self.selectedBgTileIndex = level.bgTileMap[x-1+level.size[1]*(y-1)]
					end
					if self.paintingBackground[0] then
						self.selectedBackgroundIndex[0] = level.backgroundMap[x-1+level.size[1]*(y-1)]
					end
				else
					self.brushOptions[self.selectedBrushIndex[0]].paint(self, x, y)
				end
			elseif self.editTilesOrObjects[0] == 1 then
				if self.shiftDown then
					-- ... hmm this is dif than tiles
					-- search through and pick out a spawn obj under the mouse
					self.selectedSpawnIndex[0] = 0
					for _,spawnInfo in ipairs(level.spawnInfos) do
						if spawnInfo.pos[1] == x+.5 and spawnInfo.pos[2] == y then
							self.selectedSpawnIndex[0] = self.spawnOptions:find(nil, function(option)
								return option.spawnType.spawn == spawnInfo.spawn
							end) or 0
						end
					end
				else
					-- and here ... we place a spawn obj ... exactly at mouse pos?
					for i=#level.spawnInfos,1,-1 do
						local spawnInfo = level.spawnInfos[i]
						if spawnInfo.pos[1] == x+.5 and spawnInfo.pos[2] == y then
							if spawnInfo.obj then
								spawnInfo.obj.remove = true
							end
							level.spawnInfos:remove(i)
						end
					end
					local SpawnInfo = require 'base.script.spawninfo'
					if self.selectedSpawnIndex[0] ~= 0 then
						local spawnInfo = SpawnInfo{
							pos=vec2(x+.5, y),
							spawn=self.spawnOptions[self.selectedSpawnIndex[0]].spawnType.spawn,
						}
						level.spawnInfos:insert(spawnInfo)
						spawnInfo:respawn()
					end
				end
			end
		end
	end
end

local vec3 = require 'vec.vec3'
local colorForTypeTable = table()
local predefinedColors = table{
	{0,0,0},
	{1,1,1},
	{1,0,0},
	{1,1,0},
	{0,1,0},
	{0,1,1},
	{0,0,1},
	{1,0,1},
}
local function colorForType(index)
	local color = colorForTypeTable[index]
	if not color then 
		color = predefinedColors:remove(1) or vec3(math.random(), math.random(), math.random()):normalize()
		color = {color[1], color[2], color[3], .7}
		colorForTypeTable[index] = color
	end
	return color
end

Editor.tileBackColor = {0,0,0,.5}
Editor.tileSelColor = {1,0,0,.5}
function Editor:draw(R, viewBBox)
	if not self.active then return end

	self.viewBBox = box2(viewBBox)
	
	-- draw spawn infos in the level
	local level = game.level
	for _,spawnInfo in ipairs(level.spawnInfos) do
		local x,y = spawnInfo.pos:unpack()
		local sprite = require(spawnInfo.spawn).sprite
		local tex = sprite and animsys:getTex(sprite, 'stand')
		if tex then
			tex:bind()
			
			local sx, sy = 1, 1
			if tex then
				sx = tex.width/16
				sy = tex.height/16
			end
			
			R:quad(x-sx*.5,y,sx,sy,0,1,1,-1,0,1,1,1,.5)
		
			tex:unbind()	
		end
		gl.glBindTexture(gl.GL_TEXTURE_2D, 0)
		gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_LINE)
		R:quad(x-.4,(y+.5)-.4,.8,.8,0,1,1,-1,0,1,1,1,1)
		gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_FILL)
		gl.glEnable(gl.GL_TEXTURE_2D)

		gui.font:drawUnpacked(x-.5,y+1,.5,-.5,spawnInfo.spawn:match('([^%.]*)$'))
		gl.glEnable(gl.GL_TEXTURE_2D)
	end

	-- clone & offset
	local bbox = box2(
		viewBBox.min[1] - game.level.pos[1],
		viewBBox.min[2] - game.level.pos[2],
		viewBBox.max[1] - game.level.pos[1],
		viewBBox.max[2] - game.level.pos[2])

	local ibbox = box2(
		math.floor(bbox.min[1]),
		math.floor(bbox.min[2]),
		math.floor(bbox.max[1]),
		math.floor(bbox.max[2]))
	
	local xmin = ibbox.min[1]
	local xmax = ibbox.max[1]
	local ymin = ibbox.min[2]
	local ymax = ibbox.max[2]

	if xmin > game.level.size[1] then return end
	if xmax < 1 then return end
	if ymin > game.level.size[2] then return end
	if ymax < 1 then return end
	
	if xmin < 1 then xmin = 1 end
	if xmax > game.level.size[1] then xmax = game.level.size[1] end
	if ymin < 1 then ymin = 1 end
	if ymax > game.level.size[2] then ymax = game.level.size[2] end

	if self.showTileTypes[0] then
		gl.glBindTexture(gl.GL_TEXTURE_2D, 0)
		gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_LINE)
		gl.glLineWidth(3)
		for y=ymin,ymax do
			for x=xmin,xmax do
				local tiletype = game.level.tileMap[(x-1)+game.level.size[1]*(y-1)]
				if tiletype ~= 0 then
					R:quad(
						x+.1, y+.1,
						.8, .8,
						0, 0, 
						1, 1,
						0,
						table.unpack(colorForType(tiletype)))
				end
			end
		end
		gl.glLineWidth(1)
		gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_FILL)
		gl.glEnable(gl.GL_TEXTURE_2D)
	end
end

local Image = require 'image'
local bit = require 'bit'
local table = require 'ext.table'
function Editor:save()
	print('saving...')
	-- save color file
	-- if any tiles have colors to them

	-- save template file
	
	-- save tile file
	local level = game.level
	for _,info in ipairs{
		{src=level.tileMap, dst='tile.png'},
		{src=level.fgTileMap, dst='tile-fg.png'},
		{src=level.bgTileMap, dst='tile-bg.png'},
		{src=level.backgroundMap, dst='background.png'},
	} do
		local image = Image(level.size[1], level.size[2], 3, 'unsigned char')
		for j=0,level.size[2]-1 do
			for i=0,level.size[1]-1 do
				local color = info.src[i+level.size[1]*(level.size[2]-j-1)]
				image.buffer[0+3*(i+level.size[1]*j)] = bit.band(0xff, bit.rshift(color, 0))
				image.buffer[1+3*(i+level.size[1]*j)] = bit.band(0xff, bit.rshift(color, 8))
				image.buffer[2+3*(i+level.size[1]*j)] = bit.band(0xff, bit.rshift(color, 16))
			end
		end
		local modio = require 'base.script.singleton.modio'
		local dir = modio.search[1]..'/maps/'..modio.levelcfg.path
		local dest = dir..'/' .. info.dst
		-- backup
		if io.fileexists(dest) then
			file[dir..'/~' .. info.dst] = file[dest]
		end
		image:save(dest)
	end
end

return Editor
