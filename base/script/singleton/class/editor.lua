local table = require 'ext.table'
local class = require 'ext.class'

local bit = require 'bit'
local ffi = require 'ffi'
local sdl = require 'ffi.sdl'
local gl = require 'ffi.OpenGL'
local ig = require 'ffi.imgui'

local gui = require 'base.script.singleton.gui'
local animsys = require 'base.script.singleton.animsys'
local threads = require 'base.script.singleton.threads'
local modio = require 'base.script.singleton.modio'
local game = require 'base.script.singleton.game'

local vec2 = require 'vec.vec2'
local box2 = require 'vec.box2'

local Image = require 'image'

--[[
Editor api:
--]]

local Editor = class()

Editor.active = true

Editor.brushOptions = table()

Editor.brushOptions:insert{
	name='Tile',
	paint = function(self, cx, cy)
		local level = game.level

		local texpack = level.texpackTex
		local tilesWide = texpack.width / 16
		local tilesHigh = texpack.height / 16
		local fgtx = (self.selectedFgTileIndex > 0) and ((self.selectedFgTileIndex-1) % tilesWide)
		local fgty = (self.selectedFgTileIndex > 0) and ((self.selectedFgTileIndex-fgtx-1) / tilesWide)
		local bgtx = (self.selectedBgTileIndex > 0) and ((self.selectedBgTileIndex-1) % tilesWide)
		local bgty = (self.selectedBgTileIndex > 0) and ((self.selectedBgTileIndex-bgtx-1) / tilesWide)
		local xmin = math.floor(cx - tonumber(self.brushTileWidth[0]-1)/2)
		local ymin = math.floor(cy - tonumber(self.brushTileHeight[0]-1)/2)
		local xmax = xmin + self.brushTileWidth[0]-1
		local ymax = ymin + self.brushTileHeight[0]-1
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
					if self.selectedFgTileIndex == 0 then
						level.fgTileMap[offset] = 0
					else
						level.fgTileMap[offset] = 
							1
							+ ((fgtx+((x-xmin)%self.brushStampWidth[0]))%tilesWide)
							+ tilesWide * (
								((fgty+((ymax-y)%self.brushStampHeight[0]))%tilesHigh)
							)
					end
				end
				if self.paintingBgTile[0] then
					level.bgTileMap[offset] = (self.selectedBgTileIndex == 0) and 0 or (
						1 + ((bgtx+(x-xmin)%self.brushStampWidth[0])%tilesWide)
						+ tilesWide * (
							((bgty+(ymax-y)%self.brushStampHeight[0])%tilesHigh)
						)
					)
				end
				if self.paintingBackground[0] then
					level.backgroundMap[offset] = self.selectedBackgroundIndex[0]
				end
			end
		end
	end,
}
Editor.brushOptions:insert{
	name='Fill',
	paint = function(self, x, y)
		-- only on click:
		local mouse = gui.mouse
		if not (mouse.leftDown and not mouse.lastLeftDown) then return end
		
		local thread = function()
			local level = game.level
			local alreadyHit = table()
			alreadyHit[x..','..y] = true
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
				-- enable/disable this test to only check maps of fill for congruency 
				do--if mask[i] then
					if values[i] ~= srcValues[i] then
						different = true
						break
					end
				end
			end
			if not different then return end
		
			local iter = 0
			while #check > 0 do
				iter = iter + 1
				if iter%100 == 0 then coroutine.yield() end
				local pt = check:remove(1)
				local offset = (pt[1]-1) + game.level.size[1] * (pt[2]-1)
				for i=1,#maps do
					if mask[i] then
						maps[i][offset] = values[i]
					end
				end
				for side,dir in pairs(dirs) do
					local nbhd = pt + dir
					if not alreadyHit[nbhd[1]..','..nbhd[2]] then
						alreadyHit[nbhd[1]..','..nbhd[2]] = true
						local offset = (nbhd[1]-1) + game.level.size[1] * (nbhd[2]-1)
						local same = true
						for i=1,#maps do
							-- enable/disable this test to only check maps of fill for congruency 
							do--if mask[i] then
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
		end
		threads:add(thread)
	end,
}

--[[
select the upper-left corner of a preset patch
this looks over the tiles under it
for any that are in the patch, converts them to the correct patch tile, based on the neighbors
--]]
local patchNeighbors = {
	{name='u3', differOffsets={{-1,0},{0,1},{1,0}}}, -- upward, 3 sides empty
	{name='d3', differOffsets={{-1,0},{0,-1},{1,0}}}, -- downward, 3 sides empty
	{name='l3', differOffsets={{-1,0},{0,1},{0,-1}}}, -- leftward
	{name='r3', differOffsets={{1,0},{0,1},{0,-1}}}, -- rightward

	{name='d2r', differOffsets={{-1,0}, {0,1}, {1,-1}}}, -- pipe down to right
	{name='l2d', differOffsets={{1,0}, {0,1}, {-1,-1}}}, -- pipe left to down
	{name='u2r', differOffsets={{-1,0}, {0,-1}, {1,1}}}, -- pipe up to right
	{name='l2u', differOffsets={{1,0}, {0,-1}, {-1,1}}}, -- pipe left to up
	{name='l2r', differOffsets={{0,1},{0,-1}}}, -- pipe left to right
	{name='u2d', differOffsets={{1,0},{-1,0}}}, -- pipe up to down

	{name='ul2-diag27', diag=2, planes={{-1,2,0}}, differOffsets={{1,1}, {0,1}, {-1,0}}, matchOffsets={{1,0}, {-1,-1}}},					   -- upper left diagonal 27' part 2
	{name='ul1-diag27', diag=2, planes={{-1,2,-1}}, differOffsets={{0,1}, {-1,1}, {-2,0}}, matchOffsets={{-1,0}, {1,0}, {-2,-1}}},			 -- upper left diagonal 27' part 1
	{name='ur2-diag27', diag=2, planes={{1,2,-1}}, differOffsets={{-1,1}, {0,1}, {1,0}}, matchOffsets={{-1,0}, {1,-1}}},			-- upper right diagonal 27' part 2
	{name='ur1-diag27', diag=2, planes={{1,2,-2}}, differOffsets={{0,1}, {1,1}, {2,0}}, matchOffsets={{-1,0}, {1,0}, {2,-1}}},			  -- upper right diagonal 27' part 1

	{name='dl2-diag27', diag=2, planes={{-1,-2,2}}, differOffsets={{1,-1}, {0,-1}, {-1,0}}, matchOffsets={{1,0}, {-1,1}}},					   -- lower left diagonal 27' part 2
	{name='dl1-diag27', diag=2, planes={{-1,-2,1}}, differOffsets={{0,-1}, {-1,-1}, {-2,0}}, matchOffsets={{-1,0}, {1,0}, {-2,1}}},			 -- lower left diagonal 27' part 1
	{name='dr2-diag27', diag=2, planes={{1,-2,0}}, differOffsets={{-1,-1}, {0,-1}, {1,0}}, matchOffsets={{-1,0}, {1,1}}},			-- lower right diagonal 27' part 2
	{name='dr1-diag27', diag=2, planes={{1,-2,1}}, differOffsets={{0,-1}, {1,-1}, {2,0}}, matchOffsets={{-1,0}, {1,0}, {2,1}}},			  -- lower right diagonal 27' part 1

	{name='ul-diag45', diag=1, planes={{-1,1,0}}, differOffsets={{0,1},{-1,0}}},							   -- upper left diagonal 45'
	{name='ur-diag45', diag=1, planes={{1,1,-1}}, differOffsets={{0,1},{1,0}}},															 -- upper right diagonal 45'
	{name='dl-diag45', diag=1, planes={{-1,-1,1}}, differOffsets={{0,-1},{-1,0}}},  -- lower left diagonal 45'
	{name='dr-diag45', diag=1, planes={{1,-1,0}}, differOffsets={{0,-1},{1,0}}},						 -- lower right diagonal 45'
	
	{name='ui', differOffsets={{1,0}, {-1,0}, {0,-1}}},	 -- up, inverse
	{name='di', differOffsets={{1,0}, {-1,0}, {0,1}}},   -- down, inverse
	{name='li', differOffsets={{1,0}, {0,1}, {0,-1}}}, -- left, inverse
	{name='ri', differOffsets={{-1,0}, {0,1}, {0,-1}}},	 -- right, inverse
	
	{name='ul', differOffsets={{0,1}, {-1,0}}},									 -- upper left
	{name='ur', differOffsets={{0,1}, {1,0}}},									  -- upper right
	{name='dl', differOffsets={{0,-1}, {-1,0}}},		 -- lower left
	{name='dr', differOffsets={{0,-1}, {1,0}}},		  -- lower right
	
	{name='u', differOffsets={{0,1}}},							  -- up
	{name='r', differOffsets={{1,0}}},							  -- right
	{name='l', differOffsets={{-1,0}}},							 -- left
	{name='d', differOffsets={{0,-1}}},							 -- down
	
	--[[ breaks fence
	{name='l-notsolid', differOffsets={{-1,0}}, notsolid=true},	 -- left, not solid
	{name='r-notsolid', differOffsets={{1,0}}, notsolid=true},	  -- right, not solid
	--]]

	{name='ul3-diag27', diag=2, differOffsets={{1,2}, {0,2}, {-1,1}, {-2,1}}}, -- upper left diagonal 27' part 3
	{name='ur3-diag27', diag=2, differOffsets={{-1,2}, {0,2}, {1,1}, {2,1}}},									   -- upper right diagonal 27' part 3
	
	{name='dl3-diag27', diag=2, differOffsets={{1,-2}, {0,-2}, {-1,-1}, {-2,-1}}}, -- lower left diagonal 27' part 3
	{name='dr3-diag27', diag=2, differOffsets={{-1,-2}, {0,-2}, {1,-1}, {2,-1}}},									   -- upper right diagonal 27' part 3

	{name='uli-diag45', diag=1, differOffsets={{-1,1}}},							   -- upper left diagonal inverse 45'
	{name='uri-diag45', diag=1, differOffsets={{1,1}}},													 -- upper right diagonal inverse 45'
	{name='dli-diag45', diag=1, differOffsets={{-1,-1}}},   -- lower left diagonal inverse 45'
	{name='dri-diag45', diag=1, differOffsets={{1,-1}}},						 -- lower right diagonal inverse 45'

	{name='uli', differOffsets={{-1,1}}},												   -- upper left inverse
	{name='uri', differOffsets={{1,1}}},													-- upper right inverse
	{name='dli', differOffsets={{-1,-1}}},							   -- lower left inverse
	{name='dri', differOffsets={{1,-1}}},								-- lower right inverse
	
	{name='c4', differOffsets={{1,1},{-1,1},{1,-1},{-1,-1}}}, -- center, with diagonals missing
	
	{name='c8', differOffsets={{-1,-1},{0,-1},{1,-1},{1,0},{1,1},{0,1},{-1,1},{-1,0}}}, -- center, with nothing around it 
	
	{name='c', differOffsets={}},
}
-- note: 1) we're missing three-way tiles, (i.e. ulr dlr uld urd) and 2) some are doubled: l2r and r2l
-- and 3) 'l' is both 'lower' and 'left ... but i'm fixing that now
local patchTemplate = {
	{'ul',	'u',	'ur',	'd2r',	'l2r',	'l2d',	'',		'u3',	'',		'ul-diag45',	'ur-diag45',	'ul2-diag27', 'ul1-diag27',	'ur1-diag27',	'ur2-diag27',	},
	{'l',	'c',	'r',	'u2d',	'c8',	'u2d',	'l3',	'c4',	'r3',	'uli-diag45',	'uri-diag45',	'ul3-diag27', 'dri',		'dli',			'ur3-diag27',	},
	{'dl',	'd',	'dr',	'u2r',	'l2r',	'l2u',	'',		'd3',	'',		'dli-diag45',	'dri-diag45',	'dl3-diag27', 'uri',		'uli',			'dr3-diag27',	},
	{'',	'',		'',		'',		'',		'',		'',		'',		'',		'dl-diag45',	'dr-diag45',	'dl2-diag27', 'dl1-diag27',	'dr1-diag27',	'dr2-diag27',	},
}
local patchTilesWide = #patchTemplate[1]
local patchTilesHigh = #patchTemplate
-- map of upper-left coordinates of where valid patches are in the texpack
-- stored [x][y] where x and y are tile coordinates, i.e. pixel coordinates / 16
local validTexPackTemplateLoc = {
	[0] = { [1] = true, [2] = true, [3] = true, }
}

local smoothBrush
do
	local function isSelectedTemplate(map,x,y)
		local level = game.level
		local texpack = level.texpackTex
		local tilesWide = texpack.width / 16
		
		if x < 1 or y < 1 or x > level.size[1] or y > level.size[2] then return end
		
		-- read the tile
		local offset = x-1 + level.size[1] * (y-1)
		local index = map[offset]
		if index > 0 then
			-- see if this is a member of the current patch
			-- ... check if it exists at the 2d offset from the selected fg tile index (check 'patchObj.patch' above)
			local tx = (index-1)%tilesWide
			local ty = (index-tx-1)/tilesWide
	
			-- make sure this tile's texture is a part of a valid patch 
			local patchtx = tx - tx%patchTilesWide
			local patchty = ty - ty%patchTilesHigh
			local row = validTexPackTemplateLoc[patchtx/patchTilesWide]
			local valid = row and row[patchty/patchTilesHigh]
			if not valid then return end
			
			local i = tx - patchtx
			local j = ty - patchty
			
			local row = patchTemplate[j+1]
			if row then
				local name = row[i+1]
				if name then
					if name == '' then return end
					return true	
				end
			end	
		end
	end

	local function isNotEmpty(map,x,y)
		local level = game.level
		if x < 1 or y < 1 or x > level.size[1] or y > level.size[2] then return end
		local offset = x-1 + level.size[1] * (y-1)
		local index = map[offset]
		return index > 0
	end

	local function validNeighbor(self,map,x,y)
		local level = game.level
		if x < 1 or y < 1 or x > level.size[1] or y > level.size[2] then return end
		if not self.alignPatchToAnything[0] then return isSelectedTemplate(map,x,y) end
		return isNotEmpty(map,x,y)
	end

	smoothBrush = {
		name = 'Smooth',
		-- names in the neighbor table of where the patch tiles are
		paint = function(self, cx,cy)
			local level = game.level

			local texpack = level.texpackTex
			local tilesWide = texpack.width / 16
			local tilesHigh = texpack.height / 16

			local xmin = math.floor(cx - tonumber(self.brushTileWidth[0]-1)/2)
			local ymin = math.floor(cy - tonumber(self.brushTileHeight[0]-1)/2)
			local xmax = xmin + self.brushTileWidth[0]-1
			local ymax = ymin + self.brushTileHeight[0]-1
			if xmax < 1 then return end
			if ymax < 1 then return end
			if xmin > level.size[1] then return end
			if ymin > level.size[2] then return end
			if xmin < 1 then xmin = 1 end
			if ymin < 1 then ymin = 1 end
			if xmax > level.size[1] then xmax = level.size[1] end
			if ymax > level.size[2] then ymax = level.size[2] end

			for _,info in ipairs{
				{map=level.fgTileMap, painting=self.paintingFgTile[0], selected=self.selectedFgTileIndex},
				{map=level.bgTileMap, painting=self.paintingBgTile[0], selected=self.selectedBgTileIndex},
				{map=level.tileMap, painting=self.paintingTileType[0], selected=self.selectedTileTypeIndex[0], drawingTileType=true},
			} do
				local map = info.map
				local painting = info.painting
				local selectedIndex = info.selected
				local drawingTileType = info.drawingTileType
				if painting then
					for y=ymin,ymax do
						for x=xmin,xmax do
							-- get the current tile's associated patch
							local seltx, selty
							if not drawingTileType then
								if x >= 1 and y >= 1 and x <= level.size[1] and y <= level.size[2] then 
									local offset = x-1 + level.size[1] * (y-1)
									local index = map[offset]
									if index > 0 then
										seltx = (index-1)%tilesWide
										selty = (index-seltx-1)/tilesWide
										seltx = seltx - seltx % patchTilesWide
										selty = selty - selty % patchTilesHigh
									end
								end
							end
							-- for fg/bg (drawingTileType == 0), if the fg/bg tex is part of a patch, then align it.  if it's not, ignore it.
							local checkThisTile = drawingTileType and isNotEmpty(map,x,y) or isSelectedTemplate(map,x,y)
							if checkThisTile then
								for _,neighbor in ipairs(patchNeighbors) do
									if (neighbor.diag or 0) <= self.smoothTileTypeIndex[0] then	    -- and we're within our diagonalization precedence (0 for 90', 1 for 45', 2 for 30')
										local neighborIsValid = true
										-- make sure all neighbors that should differ do differ
										if neighbor.differOffsets then
											for _,offset in ipairs(neighbor.differOffsets) do
												-- if not 'alignPatchToAnything' then only go by same templates. otherwise - go by anything 
												-- if drawing tile type then just check if it's empty.  TODO still only consider matching templates!
												if drawingTileType and isNotEmpty(map,x+offset[1],y+offset[2])
												or validNeighbor(self,map,x+offset[1], y+offset[2])
												then
													neighborIsValid = false
													break
												end
											end
										end
										-- make sure all neighbors that should match do match
										if neighborIsValid and neighbor.matchOffsets then
											for _,offset in ipairs(neighbor.matchOffsets) do
												-- same test as above
												if drawingTileType and isNotEmpty(map,x+offset[1],y+offset[2])
												or validNeighbor(self,map,x+offset[1], y+offset[2])
												then
													neighborIsValid = false
													break
												end
											end
										end
										if neighborIsValid then
											-- find the offset in the patch that this neighbor represents
											local done = false
											if drawingTileType then
												-- convert neighbor name to tileType
												local tileTypeIndex = level.tileTypes:find(nil, function(tileType)
													if neighbor.diag then
														return tileType.name == neighbor.name
													end
													return tileType.name == 'solid'
												end)
												map[x-1+level.size[1]*(y-1)] = tileTypeIndex or 0
												if tileTypeIndex then done = true end
											else
												for j,row in ipairs(patchTemplate) do
													for i,name in ipairs(row) do
														if name == neighbor.name then
															-- TODO instead of painting the selected patch,
															--  use the patch that the current tile belongs to
															local tx = seltx + i-1
															local ty = selty + j-1
															-- ... and paint it on the foreground
															map[x-1+level.size[1]*(y-1)] = 1+tx+tilesWide*ty
															done = true
															break
														end
													end
													if done then break end
												end
											end
											-- don't need to check anymore neighbors -- we've found one
											if done then break end
										end
									end
								end
							end
						end
					end
				end
			end
		end,
	}
end
Editor.brushOptions:insert(smoothBrush)

function Editor:init()	
	self.editTilesOrObjects = ffi.new('int[1]',0)
	
	self.paintingTileType = ffi.new('bool[1]',true)
	self.paintingFgTile = ffi.new('bool[1]',true)
	self.paintingBgTile = ffi.new('bool[1]',true)
	self.paintingBackground = ffi.new('bool[1]',true)

	self.brushTileWidth = ffi.new('int[1]',1)
	self.brushTileHeight = ffi.new('int[1]',1)
	self.brushStampWidth = ffi.new('int[1]',1)
	self.brushStampHeight = ffi.new('int[1]',1)
	self.alignPatchToAnything = ffi.new('bool[1]',true)
	self.smoothTileTypeIndex = ffi.new('int[1]',0)

	self.fgTileWindowOpenedPtr = ffi.new('bool[1]',false)
	self.bgTileWindowOpenedPtr = ffi.new('bool[1]',false)

	self.selectedBrushIndex = ffi.new('int[1]',1)
	
	self.selectedTileTypeIndex = ffi.new('int[1]',0)
	self.selectedFgTileIndex = 0
	self.selectedBgTileIndex = 0
	self.selectedBackgroundIndex = ffi.new('int[1]',0)
	self.selectedSpawnIndex = ffi.new('int[1]',0)

	self.showTileTypes = ffi.new('bool[1]',true)
	self.noClipping = ffi.new('bool[1]',false)
end

function Editor:setTileKeys()

	-- tile types
	self.tileOptions = game.levelcfg.tileTypes:map(function(tileType)
		local tex	
		if tileType.solid or tileType.diag then
			local width, height = 16, 16
			local channels = 4
			local border = 1
			local image = Image(width, height, channels, 'unsigned char', function(i,j)
				if i < border or j < border or i >= width-border or j >= height-border then return 0,0,0,0 end
				local plane = tileType.planes and tileType.planes[1]
				if plane then
					local x=(i+.5)/16
					local y=(j+.5)/16
					local y = x * plane[1] + y * plane[2] + plane[3]
					if y < 0 then return 255,255,255,255 end
				elseif tileType.solid then
					return 255,255,255,255
				end
				return 0,0,0,0
			end)
			-- make solid image hollow
			image = Image(image.width, image.height, image.channels, image.format, function(i,j)
				if i > border-1 and j > border-1 and i < image.width-border-1 and j < image.height-border-1 then
					if image.buffer[0+image.channels*(i+image.width*j)] > 0 
					and image.buffer[0+image.channels*(i-1+image.width*j)] > 0
					and image.buffer[0+image.channels*(i+1+image.width*j)] > 0
					and image.buffer[0+image.channels*(i+image.width*(j-1))] > 0
					and image.buffer[0+image.channels*(i+image.width*(j+1))] > 0
					then
						return 0,0,0,0
					end
				end
				return image.buffer[0+image.channels*(i+image.width*j)],
						image.buffer[1+image.channels*(i+image.width*j)],
						image.buffer[2+image.channels*(i+image.width*j)],
						image.buffer[3+image.channels*(i+image.width*j)]
			end)
			local Tex2D = require 'gl.tex2d'
			tex = Tex2D{
				image = image,
				minFilter = gl.GL_NEAREST,
				magFilter = gl.GL_NEAREST,
				internalFormat = gl.GL_RGBA,
				format = gl.GL_RGBA,
			}
	
		end
		return {
			tileType = tileType,
			tex = tex,
		}
	end)
	self.tileOptions[0] = {
		tileType = {name='empty'},
	}

	-- backgrounds
	self.backgroundOptions = game.level.backgrounds:map(function(background)
		return {
			background = background,
		}
	end)
	self.backgroundOptions[0] = {
		background = {name='empty'},
	}

	-- spawn
	self.spawnOptions = game.levelcfg.spawnTypes:map(function(spawnType)
		return {
			spawnType = spawnType,
		}
	end)

end

local ImVec2_00 = ig.ImVec2(0,0)
local ImVec2_11 = ig.ImVec2(1,1)
local ImVec4_0000 = ig.ImVec4(0,0,0,0)
local ImVec4_1111 = ig.ImVec4(1,1,1,1)

function Editor:updateGUI()
	ig.igText('EDITOR')
	
	ig.igRadioButton('Edit Tiles', self.editTilesOrObjects, 0)
	ig.igRadioButton('Edit Objects', self.editTilesOrObjects, 1)

	-- not sure if I should use brushes for painting objects or not ...
	ig.igCheckbox('Tile Type', self.paintingTileType)
	ig.igCheckbox('Fg Tile', self.paintingFgTile)
	ig.igCheckbox('Bg Tile', self.paintingBgTile)
	ig.igCheckbox('Background', self.paintingBackground)

	if self.editTilesOrObjects[0] == 0 then
		if ig.igCollapsingHeader('Brush Options:') then
			for i,brushOption in ipairs(self.brushOptions) do
				ig.igRadioButton(brushOption.name..' brush', self.selectedBrushIndex, i)
			end
			ig.igSliderInt('Brush Tile Width', self.brushTileWidth, 1, 20)
			ig.igSliderInt('Brush Tile Height', self.brushTileHeight, 1, 20)
			ig.igSliderInt('Brush Stamp Width', self.brushStampWidth, 1, 20)
			ig.igSliderInt('Brush Stamp Height', self.brushStampHeight, 1, 20)
			if self.brushOptions[self.selectedBrushIndex[0]] == smoothBrush then
				ig.igCheckbox('Smooth Aligns Patch to Anything', self.alignPatchToAnything)
				ig.igRadioButton("Smooth Tiles to 90'", self.smoothTileTypeIndex, 0)
				ig.igRadioButton("Smooth Tiles to 45'", self.smoothTileTypeIndex, 1)
				ig.igRadioButton("Smooth Tiles to 27'", self.smoothTileTypeIndex, 2)
			end
		end
		if ig.igCollapsingHeader('Tile Type Options:',0) then
			for i=0,#self.tileOptions do
				local tileOption = self.tileOptions[i]	
				local tex = tileOption.tex
				if tex then
					local texIDPtr = ffi.cast('void*',ffi.cast('intptr_t',tex.id))
					if ig.igImageButton(
						texIDPtr,
						ig.ImVec2(32, 32), --size
						ig.ImVec2(0, 1), --uv0
						ig.ImVec2(1, 0)) --uv1
					then
						self.selectedTileTypeIndex[0] = i
					end
					ig.igSameLine()
				end	
				ig.igRadioButton(tileOption.tileType.name, self.selectedTileTypeIndex, i)
			end
		end
		
		for _,side in ipairs{'Fg', 'Bg'} do
			local lc = side:lower()	
			if ig.igCollapsingHeader(side..' Tile Options:') then
					
				local tex = game.level.texpackTex
				local texIDPtr = ffi.cast('void*',ffi.cast('intptr_t',tex.id))
				local tilesWide = tex.width / 16
				local tilesHigh = tex.height / 16
				local bw, bh = 16, 16	-- button size
				local ti = (self['selected'..side..'TileIndex'] - 1) % tilesWide
				local tj = (self['selected'..side..'TileIndex'] - 1 - ti) / tilesWide
				if ig.igImageButton(
					texIDPtr,
					ig.ImVec2(bw,bh),	-- size
					ig.ImVec2(ti/tilesWide, tj/tilesHigh),	-- uv0
					ig.ImVec2((ti+1)/tilesWide, (tj+1)/tilesHigh))	-- uv1
				then
					-- popup of the whole thing?
					self[lc..'TileWindowOpenedPtr'][0] = true
				end
				if ig.igButton('Clear '..side..' Tile') then
					self['selected'..side..'TileIndex'] = 0
				end

				if self[lc..'TileWindowOpenedPtr'][0] then
					ig.igBegin(
						side..' Tile Window',
						self[lc..'TileWindowOpenedPtr'],
						ig.ImGuiWindowFlags_NoTitleBar)
					
					local texScreenPos = ig.igGetCursorScreenPos()
					local mousePos = ig.igGetMousePos()
					local cursorX = mousePos.x - texScreenPos.x - 2
					local cursorY = mousePos.y - texScreenPos.y - 2
					local x = math.clamp(math.floor(cursorX / tex.width * tilesWide), 0, tilesWide-1)
					local y = math.clamp(math.floor(cursorY / tex.height * tilesHigh), 0, tilesHigh-1)

					if ig.igImageButton(
						texIDPtr,
						ig.ImVec2(tex.width, tex.height))	-- size
					then
						self['selected'..side..'TileIndex'] = 1+x+tilesWide*y
						self[lc..'TileWindowOpenedPtr'][0] = false
					end
					if ig.igIsItemHovered() then
						ig.igBeginTooltip()
						ig.igImage(
							texIDPtr, -- tex
							ig.ImVec2(64, 64), -- size
							ig.ImVec2(x/tilesWide, y/tilesHigh), -- uv0
							ig.ImVec2((x+1)/tilesWide, (y+1)/tilesHigh)) -- uv1
						ig.igEndTooltip()
					end
					
					ig.igEnd()
				end
			end
		end
		if ig.igCollapsingHeader('Background Options:') then
			for i=0,#self.backgroundOptions do
				local background = self.backgroundOptions[i].background
				
				local tex = background.tex
				if tex then
					local texIDPtr = ffi.cast('void*',ffi.cast('intptr_t',tex.id))
					if ig.igImageButton(
						texIDPtr,
						ig.ImVec2(32, 32)) --size
					then
						self.selectedBackgroundIndex[0] = i
					end
					ig.igSameLine()
				end
				
				ig.igRadioButton(background.name, self.selectedBackgroundIndex, i)
	
				if i > 0 then
					if ig.igTreeNode('background '..i..': '..background.name) then
						-- something is acting strange here.
						-- if I pick certain values then my objects freeze ... like it's influencing something else?
						local float = ffi.new('float[1]')
						for _,field in ipairs{'scaleX', 'scaleY', 'scrollX', 'scrollY'} do
							float[0] = background[field] or 0
							ig.igInputFloat('background '..i..' '..field, float)
							background[field] = float[0]
						end
						ig.igTreePop()
					end
				end
			end
		end
		ig.igCheckbox('Show Tile Types', self.showTileTypes)
		ig.igCheckbox('no clipping', self.noClipping)
	end
	if self.editTilesOrObjects[0] == 1 then
		if ig.igCollapsingHeader('Object Options:') then
			for i,spawnOption in ipairs(self.spawnOptions) do
				ig.igRadioButton(spawnOption.spawnType.spawn, self.selectedSpawnIndex, i)
			end
		end
	end
	if ig.igButton('Save Map') then
		self:save()
	end
	if ig.igButton('Save Backgrounds') then
		self:saveBackgrounds()
	end
	if ig.igButton('Save Texpack') then
		self:saveTexPack()
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
		for y=ymin,ymax do
			for x=xmin,xmax do
				local tiletype = game.level.tileMap[(x-1)+game.level.size[1]*(y-1)]
				if tiletype ~= 0 then
					local option = self.tileOptions[tiletype]
					local tex = option and option.tex
					if tex then tex:bind() end
					R:quad(
						x, y,
						1, 1,
						0, 0, 
						1, 1,
						0,
						1,1,1,1)--table.unpack(colorForType(tiletype)))
				end
			end
		end
	end

	-- show the brush
	do
		local mouse = gui.mouse
		gl.glBindTexture(gl.GL_TEXTURE_2D, 0)
		gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_LINE)
		gl.glLineWidth(3)
		local cx = math.floor(self.viewBBox.min[1] + (self.viewBBox.max[1] - self.viewBBox.min[1]) * mouse.pos[1])
		local cy = math.floor(self.viewBBox.min[2] + (self.viewBBox.max[2] - self.viewBBox.min[2]) * mouse.pos[2])
		local xmin = math.floor(cx - tonumber(self.brushTileWidth[0]-1)/2)
		local ymin = math.floor(cy - tonumber(self.brushTileHeight[0]-1)/2)
		local xmax = xmin + self.brushTileWidth[0]-1
		local ymax = ymin + self.brushTileHeight[0]-1
		R:quad(
			xmin + .1, ymin + .1,
			xmax - xmin + .8, ymax - ymin + .8,
			0, 0, 1, 1, 0,
			1, 1, 0, 1)	--color
		gl.glLineWidth(1)
		gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_FILL)
		gl.glEnable(gl.GL_TEXTURE_2D)
	end
end

function Editor:save()
	local level = game.level
	local dir = modio.search[1]..'/maps/'..modio.levelcfg.path
	
	-- save tile files
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
		local dest = dir..'/' .. info.dst
		-- backup
		if io.fileexists(dest) then
			file[dir..'/~' .. info.dst] = file[dest]
		end
		image:save(dest)
	end

	-- save spawninfos
	file[modio.search[1]..'/maps/'..modio.levelcfg.path..'/spawn.lua'] = 
		'{\n'
		..level.spawnInfos:map(function(spawnInfo)
			local t = {}
			for k,v in pairs(spawnInfo) do t[k] = v end
			-- remove objects from serialization
			t.obj = nil
			return '\t'..tolua(t)..','
		end):concat('\n')
		..'\n}'
end

function Editor:saveBackgrounds()
	local dir = modio.search[1]..'/script/'
	local dest = dir..'backgrounds.lua'
	if io.fileexists(dest) then
		file[dir..'/~backgrounds.lua'] = file[dest]
	end
	file[dest] = 
		'{\n'
		..game.level.backgrounds:map(function(background)
			local t = {}
			for k,v in pairs(background) do t[k] = v end
			t.tex = nil
			return '\t'..tolua(t)..','
		end):concat('\n')
		..'\n}'
end

function Editor:saveTexPack()
end

return Editor
