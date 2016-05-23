--[[
holds patch information about the texpack
--]]
local table = require 'ext.table'


--[[
select the upper-left corner of a preset patch
this looks over the tiles under it
for any that are in the patch, converts them to the correct patch tile, based on the neighbors
--]]
local neighbors = table{
	{name='c8', differOffsets={{-1,-1},{0,-1},{1,-1},{1,0},{1,1},{0,1},{-1,1},{-1,0}}}, -- center, with nothing around it 
	{name='c4', differOffsets={{1,1},{-1,1},{1,-1},{-1,-1}}}, -- center, with diagonals missing
	
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

	{name='ul2-diag27', diag=2, differOffsets={{1,1}, {0,1}, {-1,0}}, matchOffsets={{1,0}, {-1,-1}}},					   -- upper left diagonal 27' part 2
	{name='ul1-diag27', diag=2, differOffsets={{0,1}, {-1,1}, {-2,0}}, matchOffsets={{-1,0}, {1,0}, {-2,-1}}},			 -- upper left diagonal 27' part 1
	{name='ur2-diag27', diag=2, differOffsets={{-1,1}, {0,1}, {1,0}}, matchOffsets={{-1,0}, {1,-1}}},			-- upper right diagonal 27' part 2
	{name='ur1-diag27', diag=2, differOffsets={{0,1}, {1,1}, {2,0}}, matchOffsets={{-1,0}, {1,0}, {2,-1}}},			  -- upper right diagonal 27' part 1

	{name='dl2-diag27', diag=2, differOffsets={{1,-1}, {0,-1}, {-1,0}}, matchOffsets={{1,0}, {-1,1}}},					   -- lower left diagonal 27' part 2
	{name='dl1-diag27', diag=2, differOffsets={{0,-1}, {-1,-1}, {-2,0}}, matchOffsets={{-1,0}, {1,0}, {-2,1}}},			 -- lower left diagonal 27' part 1
	{name='dr2-diag27', diag=2, differOffsets={{-1,-1}, {0,-1}, {1,0}}, matchOffsets={{-1,0}, {1,1}}},			-- lower right diagonal 27' part 2
	{name='dr1-diag27', diag=2, differOffsets={{0,-1}, {1,-1}, {2,0}}, matchOffsets={{-1,0}, {1,0}, {2,1}}},			  -- lower right diagonal 27' part 1

	{name='ul-diag45', diag=1, differOffsets={{0,1},{-1,0}}},							   -- upper left diagonal 45'
	{name='ur-diag45', diag=1, differOffsets={{0,1},{1,0}}},															 -- upper right diagonal 45'
	{name='dl-diag45', diag=1, differOffsets={{0,-1},{-1,0}}},  -- lower left diagonal 45'
	{name='dr-diag45', diag=1, differOffsets={{0,-1},{1,0}}},						 -- lower right diagonal 45'
	
	{name='ui', differOffsets={{1,0}, {-1,0}, {0,-1}}},	 -- up, inverse
	{name='di', differOffsets={{1,0}, {-1,0}, {0,1}}},   -- down, inverse
	{name='li', differOffsets={{1,0}, {0,1}, {0,-1}}}, -- left, inverse
	{name='ri', differOffsets={{-1,0}, {0,1}, {0,-1}}},	 -- right, inverse
	
	{name='ul', differOffsets={{0,1}, {-1,0}}},									 -- upper left
	{name='ur', differOffsets={{0,1}, {1,0}}},									  -- upper right
	{name='dl', differOffsets={{0,-1}, {-1,0}}},		 -- lower left
	{name='dr', differOffsets={{0,-1}, {1,0}}},		  -- lower right
	
	{name='u0', differOffsets={{0,1}}, modCoord={{2,0}, {1,0}}},	-- up
	{name='u1', differOffsets={{0,1}}, modCoord={{2,1}, {1,0}}},	-- up
	{name='r0', differOffsets={{1,0}}, modCoord={{1,0}, {2,0}}},	-- right
	{name='r1', differOffsets={{1,0}}, modCoord={{1,0}, {2,1}}},	-- right
	{name='l0', differOffsets={{-1,0}}, modCoord={{1,0}, {2,0}}},	-- left
	{name='l1', differOffsets={{-1,0}}, modCoord={{1,0}, {2,1}}},	-- left
	{name='d0', differOffsets={{0,-1}}, modCoord={{2,0}, {1,0}}},	-- down
	{name='d1', differOffsets={{0,-1}}, modCoord={{2,1}, {1,0}}},	-- down
	
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
	
	{name='c00', differOffsets={}, modCoord={{2,0},{2,0}}},
	{name='c01', differOffsets={}, modCoord={{2,0},{2,1}}},
	{name='c10', differOffsets={}, modCoord={{2,1},{2,0}}},
	{name='c11', differOffsets={}, modCoord={{2,1},{2,1}}},
}
-- note: (1) we're missing three-way tiles, (i.e. ulr dlr uld urd) and (2) some are doubled: l2r and r2l and (3) we don't have 27 degree upward slopes
local template = {
	{'ul',	'u0',	'u1',	'ur',	'd2r',	'l2d',	'u3',	'',		'ul-diag45',	'ur-diag45',	'ul2-diag27', 'ul1-diag27',	'ur1-diag27',	'ur2-diag27',	},
	{'l0',	'c00',	'c10',	'r0',	'u2r',	'l2u',	'u2d',	'',		'uli-diag45',	'uri-diag45',	'ul3-diag27', 'dri',		'dli',			'ur3-diag27',	},
	{'l1',	'c01',	'c11',	'r1',	'l3',	'l2r',	'c4',	'r3',	'dli-diag45',	'dri-diag45',	'dl3-diag27', 'uri',		'uli',			'dr3-diag27',	},
	{'dl',	'd0',	'd1',	'dr',	'',		'',		'd3',	'',		'dl-diag45',	'dr-diag45',	'dl2-diag27', 'dl1-diag27',	'dr1-diag27',	'dr2-diag27',	},
}
-- map of upper-left coordinates of where valid patches are in the texpack
-- stored [x][y] where x and y are tile coordinates, i.e. pixel coordinates / 16
local locs = {
	[0] = {
		[2] = true,
		[4] = true,
		[6] = true,
		[8] = true,
		[10] = true,
	},
}

-- places where the renderer should auto-texgen the tiles
local stamps = {
	[0] = {
		[1] = {1,2},
	},
	[1] = {
		[0] = {2,1},
		[1] = {2,2},
		[3] = {2,1},
	},
	[3] = {
		[1] = {1,2},
	},
}

return {
	neighbors = neighbors,
	template = template,
	locs = locs,
	stamps = stamps,
	width = #template[1],
	height = #template,
}
