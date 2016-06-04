--[[
save file serialization is going to use the same list for re-creating objects when loading the game
but certain serializable objects shouldn't/can't be spawned.  like shots and temp effects.  anything that depends on another entity to create. 
spawn will hold the list of what you can create from the editor.
serialize will hold the list of what you can't.
--]]
return {
	spawn = {
		{spawn='base.script.obj.object'},	-- generic object 
		{spawn='base.script.obj.start'},	-- player start
	},
	serialize = {},
}
