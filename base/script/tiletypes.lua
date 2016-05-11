return {
	-- solid	
	{name='solid', solid=true},
	
	-- 45 degrees
	{name='ul-diag45', solid=true, diag=1, plane={-1,1,0}},
	{name='ur-diag45', solid=true, diag=1, plane={1,1,-1}},
	{name='dl-diag45', solid=true, diag=1, plane={-1,-1,1}}, 
	{name='dr-diag45', solid=true, diag=1, plane={1,-1,0}},
	
	-- 27 degrees on ground
	{name='ul2-diag27', solid=true, diag=2, plane={-1,2,0}}, 
	{name='ul1-diag27', solid=true, diag=2, plane={-1,2,-1}},
	{name='ur2-diag27', solid=true, diag=2, plane={1,2,-1}}, 
	{name='ur1-diag27', solid=true, diag=2, plane={1,2,-2}}, 
	
	{name='dl2-diag27', solid=true, diag=2, plane={-1,-2,2}}, 
	{name='dl1-diag27', solid=true, diag=2, plane={-1,-2,1}},
	{name='dr2-diag27', solid=true, diag=2, plane={1,-2,1}}, 
	{name='dr1-diag27', solid=true, diag=2, plane={1,-2,0}}, 
	
	-- water
	{name='water', canSwim = true},
	
	-- ladder
	{name='ladder', canClimb = true},

	-- TODO tile types for modified UV
	-- especially for tiling stamps across a large area
	-- placing a stamp is one thing, but prevents fillbrush from ever painting over the region again
	-- modified UV tiles would fix that
}
