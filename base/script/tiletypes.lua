return {
	-- solid	
	{name='solid', solid = true},
	-- 45 degrees
	{name='45 ur', diag=1, planes={{-1,1,0}}},
	{name='45 ul', diag=1, planes={{1,1,-1}}},
	{name='45 dr', diag=1, planes={{-1,-1,1}}}, 
	{name='45 dl', diag=1, planes={{1,-1,0}}},
	-- 27 degrees on ground
	{name='27 ur', diag=2, planes={{-1,2,0}}}, 
	{name='27 ur2', diag=2, planes={{-1,2,-1}}},
	{name='27 ul', diag=2, planes={{1,2,-1}}}, 
	{name='27 ul2', diag=2, planes={{1,2,-2}}}, 

	-- water
	{name='water', canSwim = true},
	
	-- ladder
	{name='ladder', canClimb = true},
}
