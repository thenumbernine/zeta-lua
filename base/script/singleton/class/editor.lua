require 'ext.table'
local class = require 'ext.class'
local bit = require 'bit'
local sdl = require 'ffi.sdl'
local gl = require 'ffi.OpenGL'
local gui = require 'base.script.singleton.gui'
local animsys = require 'base.script.singleton.animsys'
local game = require 'base.script.singleton.game'
local box2 = require 'vec.box2'
local EmptyTile = require 'base.script.tile.empty'


local function makeTile(tileClass)
	local tile = tileClass{pos={0,0}}
	tile.color = {1,1,1,.5}
	return tile
end

--[[
Editor api:
--]]

local Editor = class()

Editor.active = true
Editor.mode = 'Tile'

function Editor:setTileKeys()

	self.selectedTileIndex = nil
	self.selectedTemplateIndex = nil
	self.selectedSpawnIndex = nil
	
	-- tiles
	self.tileOptions = table()
	self.tileOptions:insert{
		bbox = box2(),
		tileClass = EmptyTile,
		tile = makeTile(EmptyTile),
	}
	for _,v in ipairs(game.levelcfg.tilekeys) do
		if v.tile then
			self.tileOptions:insert{
				bbox = box2(),
				tileClass = v.tile,
				tile = makeTile(v.tile),
			}
		end
	end
	
	-- templates
	self.templateOptions = table()
	for name,templateInfo in pairs(game.level.templateInfos) do
		local tex = templateInfo.bgtex
		self.templateOptions:insert{
			bbox = box2(),
			name = name,
			bgtex = tex,
		}
	end
	
	-- spawn
	self.spawnOptions = table()
	for _,v in ipairs(game.levelcfg.tilekeys) do
		if v.spawn then
			self.spawnOptions:insert{
				bbox = box2(),
				spawn = v.spawn,
			}
		end
	end
end

--[[
return 'true' if we're processing something
--]]
function Editor:event(event)
	-- check for enable/disable
	if event.type == sdl.SDL_KEYDOWN
	or event.type == sdl.SDL_KEYUP
	then
		local buttonDown = event.type == sdl.SDL_KEYDOWN
		if event.key.keysym.sym == sdl.SDLK_TAB then	-- editor
			if buttonDown then
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
end

function Editor:update()
	if not self.active then return end
	sdl.SDL_ShowCursor(sdl.SDL_ENABLE)
	
	local found
	local mouse = gui.mouse
	if mouse.leftDown then
		for index,tileOption in ipairs(self.tileOptions) do
			if tileOption.bbox:contains(mouse.pos) then
				self.selectedTileIndex = index
				self.mode = 'Tile'
				found = true
				break
			end
		end	
		
		if not found then
			for index,templateOption in ipairs(self.templateOptions) do
				if templateOption.bbox:contains(mouse.pos) then
					self.selectedTemplateIndex = index
					self.mode = 'Template'
					found = true
					break
				end
			end
		end
		
		if not found then
			for index,spawnOption in ipairs(self.spawnOptions) do
				if spawnOption.bbox:contains(mouse.pos) then
					self.selectedSpawnIndex = index
					self.mode = 'Spawn'
					found = true
					break
				end
			end
		end
	end
	
	if mouse.leftDown and not found then
		local x = math.floor(self.viewBBox.min[1] + (self.viewBBox.max[1] - self.viewBBox.min[1]) * mouse.pos[1])
		local y = math.floor(self.viewBBox.min[2] + (self.viewBBox.max[2] - self.viewBBox.min[2]) * mouse.pos[2])
		if x >= 1 and y >= 1 and x <= game.level.size[1] and y <= game.level.size[2] then
			local tile = game.level.tile[x][y]
			if self.mode == 'Tile' then
				if self.shiftDown then
					for index,tileOption in ipairs(self.tileOptions) do
						if tileOption.tileClass == getmetatable(tile) then
							self.selectedTileIndex = index
						end
					end
				else
					local tileOption = self.tileOptions[self.selectedTileIndex]
					if tileOption then
						tile:makeEmpty(tile)	-- eliminate all non-permanent fields
						setmetatable(tile, tileOption.tileClass)	-- change class (todo this doesn't consider any custom fields...)
						game.level:alignTileTemplates(x,y,x,y)
					end
				end
			elseif self.mode == 'Template' then
				if self.shiftDown then
					for index,templateOption in ipairs(self.templateOptions) do
						if templateOption.bgtex == tile.bgtex then
							self.selectedTemplateIndex = index
						end
					end
				else
					local templateOption = self.templateOptions[self.selectedTemplateIndex]
					if templateOption then
						tile.bgtex = templateOption.bgtex
					end
				end
			elseif self.mode == 'Spawn' then
				if self.shiftDown then
					-- ... hmm this is dif than tiles
					-- search through and pick out a spawn obj under the mouse
					self.selectedSpawnIndex = nil
					for _,spawnInfo in ipairs(game.level.spawnInfos) do
						if spawnInfo.pos[1] == x+.5 and spawnInfo.pos[2] == y then
							self.selectedSpawnIndex = self.spawnOptions:find(nil, function(option) return option == spawnInfo.spawn end)
						end
					end
				else
					-- and here ... we place a spawn obj ... exactly at mouse pos?
					for i=#game.level.spawnInfos,1,-1 do
						local spawnInfo = game.level.spawnInfos[i]
						if spawnInfo.pos[1] == x+.5 and spawnInfo.pos[2] == y then
							spawnInfo.obj.remove = true
							game.level.spawnInfos:remove(i)
						end
					end
					local SpawnInfo = require 'base.script.spawninfo'
					if self.selectedSpawnIndex then
						local spawnInfo = SpawnInfo{
							pos=vec2(x+.5, y),
							spawn=self.spawnOptions[self.selectedSpawnIndex].spawn,
						}
						game.level.spawnInfos:insert(spawnInfo)
						spawnInfo:respawn()
					end
				end
			end
		end
	end
end

Editor.tileBackColor = {0,0,0,.25}
Editor.tileSelColor = {1,0,0,.25}
function Editor:draw(R, viewBBox)
	if not self.active then return end
	
	self.viewBBox = box2(viewBBox)
	local viewSizeX = viewBBox.max[1] - viewBBox.min[1]
	local viewSizeY = viewBBox.max[2] - viewBBox.min[2]

	gui.font:drawUnpacked(
		(viewBBox.min[1] + viewBBox.max[1])*.5,
		viewBBox.max[2],
		2, -2, 'EDITOR')
	gl.glEnable(gl.GL_TEXTURE_2D)
	
	local space = .1
	local x = viewBBox.min[1] + space
	local y = viewBBox.max[2] - 1 - space
	
	
	for index,tileOption in ipairs(self.tileOptions) do
		local tile = tileOption.tile

		gl.glUseProgram(0)
		gl.glBindTexture(gl.GL_TEXTURE_2D, 0)
		gl.glDisable(gl.GL_TEXTURE_2D)
		local color
		if self.mode == 'Tile' and index == self.selectedTileIndex then
			color = self.tileSelColor
		else
			color = self.tileBackColor
		end
		local bx, by = x - space, y - space
		local bw, bh = 1 + 2 * space, 1 + 2 * space
		R:quad(
			bx, by, bw, bh,
			0, 0, 1, 1,
			0,
			unpack(color))
		gl.glEnable(gl.GL_TEXTURE_2D)
		
		tileOption.bbox.min[1] = (bx - viewBBox.min[1]) / viewSizeX
		tileOption.bbox.min[2] = (by - viewBBox.min[2]) / viewSizeY
		tileOption.bbox.max[1] = (bx + bw - viewBBox.min[1]) / viewSizeX
		tileOption.bbox.max[2] = (by + bh - viewBBox.min[2]) / viewSizeY

		if tile then
			tile.pos[1] = x
			tile.pos[2] = y
			tile:draw(R, viewBBox)
		end
		
		x = x + 1 + 3 * space
		if x > viewBBox.max[1] then
			x = viewBBox.min[1] + space
			y = y - (1 + 3 * space)
			-- make sure it's on our current page
		end
	end
	
	y = y - 2 * (1 + 3 * space)
	x = viewBBox.min[1] + space
	for index,templateOption in ipairs(self.templateOptions) do
		gl.glUseProgram(0)
		gl.glBindTexture(gl.GL_TEXTURE_2D, 0)
		gl.glDisable(gl.GL_TEXTURE_2D)
		local color
		if self.mode == 'Template' and index == self.selectedTemplateIndex then
			color = self.tileSelColor
		else
			color = self.tileBackColor
		end
		local bx, by = x - space, y - space
		local bw, bh = 1 + 2 * space, 1 + 2 * space
		R:quad(bx, by, bw, bh, 0, 0, 1, 1, 0, unpack(color))
		gl.glEnable(gl.GL_TEXTURE_2D)

		templateOption.bbox.min[1] = (bx - viewBBox.min[1]) / viewSizeX
		templateOption.bbox.min[2] = (by - viewBBox.min[2]) / viewSizeY
		templateOption.bbox.max[1] = (bx + bw - viewBBox.min[1]) / viewSizeX
		templateOption.bbox.max[2] = (by + bh - viewBBox.min[2]) / viewSizeY

		local tex = templateOption.bgtex
		if tex then
			gl.glBindTexture(gl.GL_TEXTURE_2D, tex.id)
			R:quad(x,y,1,1,0,0,1,1,0,1,1,1,.25)
		end
		
		x = x + 1 + 3 * space
		if x > viewBBox.max[1] then
			x = viewBBox.min[1] + space
			y = y - (1 + 3 * space)
			-- make sure it's on our current page
		end
	end
	
	y = y - 2 * (1 + 3 * space)
	x = viewBBox.min[1] + space
	for index,spawnOption in ipairs(self.spawnOptions) do
		gl.glUseProgram(0)
		gl.glBindTexture(gl.GL_TEXTURE_2D, 0)
		gl.glDisable(gl.GL_TEXTURE_2D)
		local color
		if self.mode == 'Spawn' and index == self.selectedSpawnIndex then
			color = self.tileSelColor
		else
			color = self.tileBackColor
		end
		local bx, by = x - space, y - space
		local bw, bh = 1 + 2 * space, 1 + 2 * space
		R:quad(bx, by, bw, bh, 0, 0, 1, 1, 0, unpack(color))
		gl.glEnable(gl.GL_TEXTURE_2D)

		spawnOption.bbox.min[1] = (bx - viewBBox.min[1]) / viewSizeX
		spawnOption.bbox.min[2] = (by - viewBBox.min[2]) / viewSizeY
		spawnOption.bbox.max[1] = (bx + bw - viewBBox.min[1]) / viewSizeX
		spawnOption.bbox.max[2] = (by + bh - viewBBox.min[2]) / viewSizeY

		local tex = animsys:getTex(spawnOption.spawn.sprite, 'stand')
		if tex then
			gl.glBindTexture(gl.GL_TEXTURE_2D, tex.id)
			R:quad(x,y,1,1,0,1,1,-1,0,1,1,1,.25)
		end
		
		x = x + 1 + 3 * space
		if x > viewBBox.max[1] then
			x = viewBBox.min[1] + space
			y = y - (1 + 3 * space)
			-- make sure it's on our current page
		end
	end	

	-- draw spawn infos
	local level = game.level
	for _,spawnInfo in ipairs(level.spawnInfos) do
		local tex = animsys:getTex(spawnInfo.spawn.sprite, 'stand')
		if tex then
			gl.glBindTexture(gl.GL_TEXTURE_2D, tex.id)
			
			local sx, sy = 1, 1
			if tex then
				sx = tex.width/16
				sy = tex.height/16
			end
			
			local x,y = spawnInfo.pos:unpack()
			R:quad(x-sx*.5,y,sx,sy,0,1,1,-1,0,1,1,1,.5)
		end
	end
end

return Editor
