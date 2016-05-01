local bit = require 'bit'
local class = require 'ext.class'
local vec2 = require 'vec.vec2'
local vec3 = require 'vec.vec3'
local vec4 = require 'vec.vec4'
local box2 = require 'vec.box2'
local modio = require 'base.script.singleton.modio'
local texsys = require 'base.script.singleton.texsys'
local game = require 'base.script.singleton.game'	-- this should exist by now, right?
local EmptyTile = require 'base.script.tile.empty'
local Image = require 'image'
local SpawnInfo = class()

function SpawnInfo:init(args)
	for k,v in pairs(args) do self[k] = v end
end

function SpawnInfo:respawn()
	if not self.spawn then
		error("failed to find spawn class")
	end
	-- self.spawn is a table, so self:spawn() is actually calling the table's ctor with self as the first param (after the table itself)
	self.obj = self:spawn()
	self.obj.spawnInfo = self
end

--[[
Level api:
pos = vec2()						level position offset ... experimental for multiple layers, and currently disabled
initSpawn()							called by Game when the level stars
getTile(x,y)						used by base.script.obj.object:
alignTileTemplates(x1,y1,x2,y2)		used by editor, by mod-specific objects, and internally within base.script.level
--]]
local Level = class()

local function rgbAt(image, x, y)
	local r = image.buffer[0 + image.channels * (x + image.width * y)]
	local g = image.buffer[1 + image.channels * (x + image.width * y)]
	local b = image.buffer[2 + image.channels * (x + image.width * y)]
	return bit.bor(
		bit.lshift(r, 16),
		bit.lshift(g, 8),
		b)
end

function Level:processTemplateColor(u,v,color)
	for _,key in ipairs(self.templatekeys) do
		if key.color == color then
			return key.name
		end
	end
	print("unknown template color "..('%.6x'):format(color))
end

function Level:processTileColor(u,v,color)
	for _,info in pairs(self.tilekeys) do
		if info.color == color then
			if info.startPos then
				self.startPositions:insert(vec2(u+.5, v))	-- center on the x
			end
			if info.spawn then
				self.spawnInfos:insert(SpawnInfo{pos=vec2(u+.5, v), spawn=info.spawn})	-- center on x and y
			end
			if info.tile then
				return info.tile
			end
			return EmptyTile
		end
	end
	print("unknown tile at "..u..", "..v.." has "..('%.6x'):format(color))
	return EmptyTile
end

--[[
args:
	tilekeys = table to map level colors to tile/spawn classes
	templatekeys = table to map template colors to template types
	path = (optional) path where to find the map, excluding the prefix of "<mod>/maps/"
	tileFile = (optional) path where to find the tile file.
		default "<path>/tile.png"
		the tile file contains pixels that is mapped to tile/spawn classes via tilekeys 
	templateFile = (optional) path where to find the template file.
		default "<path>/template.png"
		the template file is mapped via templatekeys to the different templates at different parts of the level
	template = (optional) the template to used, if no templateFile is specified
		either template or templateFile must be defined
	seamFile = (optional) file to specify where seams in the tile patterns are located.
		default "<path>/seam.png"
		matching colors in the seam file are drawn as contiguous tiles.
	colorFile = (optional) file to find per-tile color values
		default "<path>/color.png"
	warpFile = (optional) warp info, used with doors and pipes and stuff.
		default "<path>/warp.png"
	initFile = (optional) file to run when the level inits.
		default "<path>/init.lua"
	spawnFile = (optional) file to find spawn info in addition to the tile data.
		useful when you need more than one spawn info per tile, or finer than per-tile mapping, or more info than just position and class.
		default "<path>/spawn.lua"

all the args values are valid properties of levelcfg.lua

spawnFile contents are as follows:
{
	{
		spawn='mario.script.obj.door',
		pos={2,2},
		...
	},
	...
}
--]]
function Level:init(args)

	self.pos = vec2(0,0)
	self.vel = vec2(0,0)

	self.tilekeys = assert(args.tilekeys)
	self.templatekeys = assert(args.templatekeys)
	do	-- make sure no template key colors overlap
		local templateForColor = {}
		for _,key in ipairs(self.templatekeys) do
			if templateForColor[key.color] then
				print(string.format("WARNING: template color 0x%x is used for %s and %s!", tonumber(key.color), tostring(key.name), tostring(templateForColor[key.color].name)))
			end
			templateForColor[key.color] = key.name
		end
	end	

	do	-- make sure no tile key colors overlap
		local tilekeysForColor = {}
		for _,key in ipairs(self.tilekeys) do
			if tilekeysForColor[key.color] then
				print(string.format("WARNING: tile color 0x%x is used for %s and %s!", tonumber(key.color), tostring(key.name), tostring(tilekeysForColor[key.color].name)))
			end
			tilekeysForColor[key.color] = key
		end
	end
	
	local mappath = args.path
	if mappath then mappath = 'maps/' .. mappath end

	local tileFile
	if mappath then tileFile = mappath..'/tile.png' end
	if args.tileFile then tileFile = args.tileFile end
	if tileFile then tileFile = modio:find(tileFile) end
	assert(tileFile, "couldn't find tile file")

	local tileImage = Image(tileFile)	-- meh I'll leave it in its packed format ... maybe?
	self.size = vec2(tileImage:size())
	
	local templateImage
	do
		local templateFile
		if mappath then templateFile = mappath..'/template.png' end
		if args.templateFile then templateFile = args.templateFile end
		if templateFile then
			local templateFile = modio:find(templateFile)
			if templateFile then
				templateImage = Image(templateFile)
				assert(vec2(templateImage:size()) == self.size)
			end
		end
	end
	local getTileTemplate
	if templateImage then
		getTileTemplate = function(i,j)
			return self:processTemplateColor(i,j, rgbAt(templateImage,i-1,self.size[2]-j))
		end
	else
		getTileTemplate = function(i,j)
			return args.template
		end
	end
	
	local seamImage
	do
		local seamFile
		if mappath then seamFile = mappath..'/seam.png' end
		if args.seamFile then seamFile = args.seamFile end
		if seamFile then
			seamFile = modio:find(seamFile)
			if seamFile then
				seamImage = Image(seamFile)
				assert(vec2(seamImage:size()) == self.size)
			end
		end
	end
	
	local colorImage
	do
		local colorFile
		if mappath then colorFile = mappath..'/color.png' end
		if args.colorFile then colorFile = args.colorFile end
		if colorFile then
			colorFile = modio:find(colorFile)
			if colorFile then
				colorImage = Image(colorFile)
				assert(vec2(colorImage:size()) == self.size)
			end
		end
	end
	
	local warpImage
	do
		local warpFile
		if mappath then warpFile = mappath..'/warp.png' end
		if args.warpFile then warpFile = args.warpFile end
		if warpFile then
			warpFile = modio:find(warpFile)
			if warpFile then
				warpImage = Image(warpFile)
				assert(vec2(warpImage:size()) == self.size)
			end
		end
	end
	local getTileWarp
	if warpImage then
		getTileWarp = function(i,j) return rgbAt(warpImage,i-1,self.size[2]-j) end
	else
		getTileWarp = function(i,j) return 0 end
	end
	
	self.startPositions = table(args.startPositions)
	self.spawnInfos = table()
	
	-- make level data for rgb data
	self.tile = {}
	for i=1,self.size[1] do
		local tilecol = {}
		self.tile[i] = tilecol
		for j=1,self.size[2] do

			local tileType = self:processTileColor(i,j, rgbAt(tileImage,i-1,self.size[2]-j))

			local tile = tileType{pos=vec2(i,j)}
			
			if tile.usesTemplate then
				-- if we use templates yet don't have one assigned (i.e. solid tiles) then get the template later
				-- otherwise (i.e. fence, lava, water) use our predefined template
				if not tile.template then
					tile.template = getTileTemplate(i,j)
				end
				if seamImage then
					-- 'seam' means divide the textures even if the templates match
					local seam = rgbAt(seamImage,i-1,self.size[2]-j)
					if seam ~= 0 then
						tile.seam = seam
					end
				end
			end
			tile.warp = getTileWarp(i,j)
			
			if colorImage then
				local r,g,b,a = colorImage(i-1,self.size[2]-j)
				a = a or 1
				tile.color = vec4(r,g,b,a)
			end
			
			tilecol[j] = tile
		end
	end
	
	-- add any additional spawn infos
	do
		local spawnInfoFile
		if mappath then spawnInfoFile = mappath .. '/spawn.lua' end
		if args.spawnFile then spawnInfoFile = args.spawnInfoFile end
		if spawnInfoFile then
			spawnInfoFile = modio:find(spawnInfoFile)
			if spawnInfoFile then
				local spawnInfos = assert(assert(loadstring('return '..io.readfile(spawnInfoFile)))())
				for _,args in ipairs(spawnInfos) do

					if type(args.spawn) == 'string' then
						args.spawn = require(args.spawn)
					elseif type(args.spawn) ~= 'table' then
						error("don't know how to handle spawn of type "..tostring(args.spawn))
					end
					
					assert(type(args.pos) == 'table')
					args.pos = vec2(unpack(args.pos))
					
					self.spawnInfos:insert(SpawnInfo(args))	-- center on x and y
				end
			end
		end
	end
	
	self.templateInfos = {}
	
	for _,key in pairs(self.templatekeys) do
		local templateInfo = {}
		self.templateInfos[key.name] = templateInfo
		
		-- TODO search function: mod/* then base/*

		-- default center tile
		local fn = modio:find('tile-templates/'..key.name..'/c.png')
		if fn then
			templateInfo.centerTex = texsys:load(fn)
		end
		
		local fn = modio:find('tile-templates/'..key.name..'/background.png')
		if fn then
			templateInfo.bgtex = texsys:load(fn, true)
		end
	
		-- TODO separate templates and backgrounds ... so we can have templated things like water and fences and maintain backgrounds?
		-- possible neighbor tiles
		-- 
		templateInfo.neighbors = {
			
			{name='ur2-diag27', diag=2, planes={{-1,2,0}}, differOffsets={{1,1}, {0,1}, {-1,0}}, matchOffsets={{1,0}, {-1,-1}}, mirror=true},			-- upper left diagonal 27' part 2
			{name='ur1-diag27', diag=2, planes={{-1,2,-1}}, differOffsets={{0,1}, {-1,1}, {-2,0}}, matchOffsets={{-1,0}, {1,0}, {-2,-1}}, mirror=true},		-- upper left diagonal 27' part 1
			{name='ur2-diag27', diag=2, planes={{1,2,-1}}, differOffsets={{-1,1}, {0,1}, {1,0}}, matchOffsets={{-1,0}, {1,-1}}},		-- upper right diagonal 27' part 2
			{name='ur1-diag27', diag=2, planes={{1,2,-2}}, differOffsets={{0,1}, {1,1}, {2,0}}, matchOffsets={{-1,0}, {1,0}, {2,-1}}},		-- upper right diagonal 27' part 1
		
			{name='ur-diag45', diag=1, planes={{-1,1,0}}, differOffsets={{0,1},{-1,0}}, mirror=true},				-- upper left diagonal 45'
			{name='ur-diag45', diag=1, planes={{1,1,-1}}, differOffsets={{0,1},{1,0}}},								-- upper right diagonal 45'
			{name='ur-diag45', diag=1, planes={{-1,-1,1}}, differOffsets={{0,-1},{-1,0}}, flip=true, mirror=true},	-- lower left diagonal 45'
			{name='ur-diag45', diag=1, planes={{1,-1,0}}, differOffsets={{0,-1},{1,0}}, flip=true},				-- lower right diagonal 45'
			
			{name='ui', differOffsets={{1,0}, {-1,0}, {0,-1}}},	-- up, inverse
			{name='ui', differOffsets={{1,0}, {-1,0}, {0,1}}, flip=true},	-- down, inverse
			{name='ri', differOffsets={{1,0}, {0,1}, {0,-1}}, mirror=true},	-- left, inverse
			{name='ri', differOffsets={{-1,0}, {0,1}, {0,-1}}},	-- right, inverse
			
			{name='ul', differOffsets={{0,1}, {-1,0}}},					-- upper left
			{name='ur', differOffsets={{0,1}, {1,0}}},					-- upper right
			{name='ul', differOffsets={{0,-1}, {-1,0}}, flip=true},		-- lower left
			{name='ur', differOffsets={{0,-1}, {1,0}}, flip=true},		-- lower right
			
			{name='u', differOffsets={{0,1}}},				-- up
			{name='r', differOffsets={{1,0}}},				-- right
			{name='l', differOffsets={{1,0}}, mirror=true},	-- right
			{name='l', differOffsets={{-1,0}}},				-- left
			{name='r', differOffsets={{-1,0}}, mirror=true},-- left
			{name='d', differOffsets={{0,-1}}},				-- down
			{name='u', differOffsets={{0,-1}}, flip=true},	-- down
			
			--[[ breaks fence
			{name='l-notsolid', differOffsets={{-1,0}}, notsolid=true},	-- left, not solid
			{name='r-notsolid', differOffsets={{1,0}}, notsolid=true},	-- right, not solid
			--]]

			{name='ur3-diag27', diag=2, differOffsets={{1,2}, {0,2}, {-1,1}, {-2,1}}, mirror=true},	-- upper left diagonal 27' part 3
			{name='ur3-diag27', diag=2, differOffsets={{-1,2}, {0,2}, {1,1}, {2,1}}},					-- upper right diagonal 27' part 3

			{name='uri-diag45', diag=1, differOffsets={{-1,1}}, mirror=true},				-- upper left diagonal inverse 45'
			{name='uri-diag45', diag=1, differOffsets={{1,1}}},							-- upper right diagonal inverse 45'
			{name='uri-diag45', diag=1, differOffsets={{-1,-1}}, flip=true, mirror=true},	-- lower left diagonal inverse 45'
			{name='uri-diag45', diag=1, differOffsets={{1,-1}}, flip=true},				-- lower right diagonal inverse 45'

			{name='uli', differOffsets={{-1,1}}},							-- upper left inverse
			{name='uri', differOffsets={{1,1}}},							-- upper right inverse
			{name='uli', differOffsets={{1,1}}, mirror=true},				-- upper right inverse
			{name='uli', differOffsets={{-1,-1}}, flip=true},				-- lower left inverse
			{name='uri', differOffsets={{1,-1}}, flip=true},				-- lower right inverse
			{name='uli', differOffsets={{1,-1}}, flip=true, mirror=true},	-- lower right inverse
		}
		for _,neighbor in pairs(templateInfo.neighbors) do
			local fn = modio:find('tile-templates/'..key.name..'/'..neighbor.name..'.png')
			if fn then
				neighbor.tex = texsys:load(fn)
			end
		end
		-- fix texture borders.  clamp_to_edge is best, but not perfect
		local texs = {templateInfo.centerTex}
		for _,neighbor in pairs(templateInfo.neighbors) do
			table.insert(texs, neighbor.tex)
		end
	end
	self:alignTileTemplates(1, 1, self.size[1], self.size[2])
	
	-- set background textures according to the template map
	-- (this way individual tiles can have predefined templates and not interfere with the template-based backgrounds)
	for i=1,self.size[1] do
		local tilecol = self.tile[i]
		for j=1,self.size[2] do
			local tile = tilecol[j]
			local bgtemplate = getTileTemplate(i,j)
			local templateInfo = self.templateInfos[bgtemplate]
			if templateInfo and templateInfo.bgtex then
				tile.bgtex = templateInfo.bgtex
			end
		end
	end

	-- remember this for initSpawn()'s sake
	local initFile
	if mappath then initFile = mappath..'/init.lua' end
	if args.initFile then initFile = args.initFile end
	self.initFile = initFile
end

-- init stuff to be run after level is assigned as game.level (so objs can reference it)
function Level:initSpawn()

	for i=1,self.size[1] do
		local tilecol = self.tile[i]
		for j=1,self.size[2] do
			local tile = tilecol[j]

			-- reset objects
			tile.objs = nil
			
			-- reset fluids
			tile.fluid = nil
			
			-- init particles
			local fluidClass = tile.fluidClass
			if fluidClass then
				--[[ 4-lattice
				fluidClass{pos={i + .375, j + .25}}
				fluidClass{pos={i + .875, j + .25}}
				fluidClass{pos={i + .125, j + .75}}
				fluidClass{pos={i + .625, j + .75}}
				--]]
				
				--[[ 2-lattice
				fluidClass{pos={i + .25, j + .25}}
				fluidClass{pos={i + .75, j + .75}}
				--]]
				
				-- [[ 1-lattice
				fluidClass{pos={i + .25 + (j%2) * .5, j + .5}}
				--]]
			end
		end
	end

	-- do an initial respawn
	for _,spawnInfo in ipairs(self.spawnInfos) do
		spawnInfo:respawn()
	end
	
	-- run any init scripts if they're there
	if self.initFile then
		local initFile = modio:find(self.initFile)
		if initFile then
			assert(load(assert(file[initFile])))()
		end
	end
end

-- call this on a region of any tiles change their 'usesTemplate' flag (or their metatable that has that set)
-- or their 'template' field
function Level:alignTileTemplates(xmin, ymin, xmax, ymax)
	xmin, ymin, xmax, ymax = math.floor(xmin), math.floor(ymin), math.floor(xmax), math.floor(ymax)
	
	-- adjust by our largest offset vector
	xmin = xmin - 2
	xmax = xmax + 2
	ymin = ymin - 2
	ymax = ymax + 2
	
	if xmin > self.size[1] or xmax < 1 or ymin > self.size[2] or ymax < 1 then return end
	if xmin < 1 then xmin = 1 end
	if xmax > self.size[1] then xmax = self.size[1] end
	if ymin < 1 then ymin = 1 end
	if ymax > self.size[2] then ymax = self.size[2] end	
	
	-- next align templates
	for i=xmin,xmax do
		local tilecol = self.tile[i]
		for j=ymin,ymax do
			local tile = tilecol[j]
			if not tile.usesTemplate then
			
				-- remove all those template-based vars ...
				tile.tex = nil
				tile.drawMirror = nil
				tile.drawFlipped = nil
				tile.planes = nil
			else
			
				local templateInfo = self.templateInfos[tile.template]
				if templateInfo then

					local foundTemplate = false
					for _,neighbor in ipairs(templateInfo.neighbors) do
						if neighbor.tex							-- if this type of neighbor's texture exists ...
						and (neighbor.diag or 0) <= (tile.diag or 0)	-- and we're within our diagonalization precedence (0 for 90', 1 for 45', 2 for 30')
						then
							--if not not neighbor.notsolid == not tile.solid then							-- breaks fence
							do
								local neighborIsValid = true
								-- make sure all neighbors that should differ do differ
								if neighbor.differOffsets then
									for _,offset in ipairs(neighbor.differOffsets) do
										local neighborTile = self:getTile(i + offset[1], j + offset[2])
										
										-- hmm ... first seam comes from the seam map, second seam is a class-opt define
										if neighborTile and neighborTile.usesTemplate and neighborTile.seam == tile.seam and neighborTile.seam2 == tile.seam2 then
											neighborIsValid = false
											break
										end
									end
								end
								-- make sure all neighbors that should match do match
								if neighborIsValid and neighbor.matchOffsets then
									for _,offset in ipairs(neighbor.matchOffsets) do
										local neighborTile = self:getTile(i + offset[1], j + offset[2])
										if neighborTile and not (neighborTile.usesTemplate and neighborTile.seam == tile.seam and neighborTile.seam2 == tile.seam2) then
											neighborIsValid = false
											break
										end
									end
								end
								if neighborIsValid then
									tile.tex = neighbor.tex
									tile.drawFlipped = neighbor.flip
									tile.drawMirror = neighbor.mirror
									if neighbor.planes then tile.planes = table(neighbor.planes) end
									foundTemplate = true
									break
								end
							end
						end
					end
					if not foundTemplate then
						-- then we're using the default texture, so flip and mirror all you want
						tile.tex = templateInfo.centerTex
						tile.drawFlipped = math.random(2) == 2
						tile.drawMirror = math.random(2) == 2
						tile.planes = {}
					end
				end
			end
		end
	end
end

function Level:getTile(x,y)
	x = math.floor(x)
	y = math.floor(y)
	local col = self.tile[x]
	if not col then return end
	return col[y]
end

function Level:getTileWithOffset(x,y)
	x = x - self.pos[1]
	y = y - self.pos[2]
	x = math.floor(x)
	y = math.floor(y)
	local col = self.tile[x]
	if not col then return end
	return col[y]
end

function Level:update(dt)
	self.pos[1] = self.pos[1] + self.vel[1] * dt
	self.pos[2] = self.pos[2] + self.vel[2] * dt
end

function Level:draw(R, bbox)

	-- clone & offset
	local bbox = box2(
		bbox.min[1] - self.pos[1],
		bbox.min[2] - self.pos[2],
		bbox.max[1] - self.pos[1],
		bbox.max[2] - self.pos[2])

	local ibbox = box2(
		math.floor(bbox.min[1]),
		math.floor(bbox.min[2]),
		math.floor(bbox.max[1]),
		math.floor(bbox.max[2]))
	
	local xmin = ibbox.min[1]
	local xmax = ibbox.max[1]
	local ymin = ibbox.min[2]
	local ymax = ibbox.max[2]

	if xmin > self.size[1] then return end
	if xmax < 1 then return end
	if ymin > self.size[2] then return end
	if ymax < 1 then return end
	
	if xmin < 1 then xmin = 1 end
	if xmax > self.size[1] then xmax = self.size[1] end
	if ymin < 1 then ymin = 1 end
	if ymax > self.size[2] then ymax = self.size[2] end
	
	for x=xmin,xmax do
		local tilecol = self.tile[x]
		for y=ymin,ymax do
			tilecol[y]:draw(R, bbox)
		end
	end

	for x=xmin,xmax do
		local tilecol = self.tile[x]
		for y=ymin,ymax do
			local tile = tilecol[y]
			local fluid = tile.fluid
			if fluid then
				for i=1,#fluid do
					fluid[i]:draw(R, bbox)
				end
			end
		end
	end

	for x=xmin,xmax do
		local tilecol = self.tile[x]
		for y=ymin,ymax do
			tilecol[y]:drawObjs(R, bbox)
		end
	end
end

return Level
