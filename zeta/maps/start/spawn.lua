{
	{pos={109.5,237},spawn="base.script.obj.start"},
	{pos={113.5,237},spawn="zeta.script.obj.heart"},
	{pos={111.5,236},spawn="zeta.script.obj.terminal",text="evacuation orders given!\nplease proceed to launchpad 1 for immediate departure"},
	{pos={141.5,221},spawn="zeta.script.obj.terminal",text="team 1 left without us.\nteam 2's rocket won't start.\nI think I'm going to go activate the defense robot to help us fight these creatures off...",use="if object.hasGiven then return end\nobject.hasGiven = true\ncreate\n 'zeta.script.obj.item'\n {pos = object.pos + {-1,1},\n  sprite = 'keycard'}"},
	{pos={116.5,236},spawn="zeta.script.obj.terminal",text="defense protocols initiated\nweapons storage unlocked",use="if object.hasGiven then return end\nobject.hasGiven = true\ncreate\n 'zeta.script.obj.blaster'\n {pos = object.pos + {1,3}}\n"},
}