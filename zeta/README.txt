TODO list

- go ahead and put ext & vec on global namespace.  they're probably already there.
- editor: 
	- move texpack tiles and change map tiles accordingly
	- separate 'object' into 'create object' and 'select object'
	- click-and-drag on tile selection to form rectangles for brush + stamp size?
	- distinction between numbers and strings
	- toggle editor for strings and multi-line strings (maybe a popup button?)
	- for editing vec2's, show as a point or as a vector .. maybe even click and drag to change? 
	- object classes use 'spawnfields' for editor fields, types, and tooltips
- fix collisions with sloped tiles.  determine ymin and ymax on the x side of sloped tiles and test that against object bbox. 
- environmental effects ... foreground warping (underwater, heat), blowing wind, falling snow/rain/leaves, etc
- get savepoint loading to work
- missile launcher missile ammo
collision:
[player,geemer,turrets] + world = push
[missiles,grenades] + world = push
[missiles,grenades] + [player, 	

										world	p.		g.		item	s.		b.		
world									-
player, geemer, turrets					push	push			
shot									push	push	push
item									push	touch	-		-
saw blades and electric barriers		-		touch	touch	-		-

'-': no collision
'push': collision does not interpenetrate.  it stops on the surface to resolve.
'touch': collision evaluation still happens at the surface, but the collision can interpenetrate.

'shot': shots.  blaster shot, plasma shot, 
	shot pushes all objects except sawblades and electric barriers ... only grenades hit them

'item': anything pick-up-able (item subclasses) and anything interactable (playerLook behaviors) 
	world pushes this.  nothing else pushes it.  it is affected by gravity. it doesn't push anything.

how to implement this:
collision flags:
	world		is 00001 touches 00000 collides 00000 (map, doors, break blocks, ... lifts, ...)
	solid		is 00010 touches 11111 collides 00011 (player, geemer, turret)
	shot		is 00100 touches 10011 collides 00111 (blaster shot, plasma shot)
	item		is 01000 touches 00011 collides 00001 (any item subclass, terminal, savepoint, energy refill)
	nonsolid	is 10000 touches 00010 collides 00000


collidesWithWorld:
	- everyone should have this set
	- except sawblades and barriers, and anything that wants to go through the floor
		... and better not have 'useGravity' set

issues so far:
	- break blocks aren't hit by shots and don't block falling items 
	- barriers don't stop players


monsters:
	- barriers only hit players if player is moving
	- sawblades only hit geemers if geemers are moving
	- geemers and doors don’t mix.  one pushes the other and the geemer teleports.
	- moar mining base monsters:
		- flying drones ...
		- other evil robots like you
	- moar cave monsters.  
		- venus fly traps
		- close-range guy
		- things that fly back and forth maybe
		- maybe some kind of shooter
rooms
	- fixed? 16x16? 24x24? 32x32?
	- arbitrary?

VETOED list:
- screen base spawning
	- first i tried spawn and remove based on spawninfo.  enemies would disappear if they walked too far from their start.
	- then i did spawn by spawninfo, remove by object.  if you lure an enemy too far from their home to kill them, they reappear.  this is frustrating. 
	- finally i'm going back to metroid/castlevania/cavestory-styled rooms 
- don't use 'spawnclass' as a class shortcut to register classes that are spawned.
	to execute the spawn code, all the class will have to be require()'d somewhere in one spot anyways
	it's better to list the names in 'spawnTypes' than have everything being required
- don't separating playerLook vs canCarry.  set an item down by a terminal, and try to pick it up again.
	item system options:
		- carrying items (spelunky / current system)
			pros:
			- most flexible
			cons:
			- using 'a' for run and use item means ... you can't run / always run when using an item 
			- need terminal/savepoint button *and* object button, or else objects can get stuck if you put them down by terminals
				- for the record, spelunky was like this too.  one button for items, up for doors
			- item order is never the same (can be fixed)
			- have to have your hands empty to pick something up
			- when you pick something up, it switches your inventory
		- touch to get (metroid)
			pros:
			- most simple
			cons:
			- no easy way to switch between and use individual items
			- need a distinct weapon for throwing objects
		- push 'interact' button to to pick up (cave story)
			- just like metroid style, but with an extra button to get things
	item overhaul:
		- touch/interaact to pick everything up -- no carrying
		- left/right switches weapons only.  one weapon is 'throw grenades' -- only if you have grenades.
		- canCarry only operates with a powerup: carry gloves, used for story stuff
		- separate inventory screen for using non-weapon objects
			(this means no more 'take the keycard out to open the door')

buttons:
	- up/down to aim, left/right to move
	- L/R: weapon prev/next (shift+L/R for inv prev/next? or too confusing?  separate L2&R2 for inv prev/next?  or too many buttons?)

	- B: jump
	- Y: shoot
	- A: use selected aux item.  
		- for weapons/armor: this equips it.
		- for aux things like grappling hook, speed booster, jetpack, pick-up gloves, etc, this uses it.
	- X: go to inventory, where arrows select and B uses the item.  
		using items involves:
			- one-time use items (reserve, powerup, etc)
			- activating/deactivating items (powerup suits, high-jump, etc)
			- selecting current aux item (grappling hook, speed booster, jetpack, pick-up gloves, etc)

- how to craft? designated locations (like aquaria)? or anywhere?

stats:
	* attack (+ to damage)
	* defense (- to damage ... with a minimum?)
	* health
	- jump height? or only special mod for high jump boots?
	- running max speed? or only special mod for speed boost?

items:
	* health boost
		- craft: 1 green tentacle + 1 emerald
	* attack boost (temporary)
		- craft: 1 red tentacle + 1 ruby 
	* shield boost (temporary)
		- craft: 1 red tentacle + 1 emeralde
	- grenades
	- cloak (temporary)
	- flare (lighting)

ammo:
	- plasma
		craft to create: 1 emerald -> 50 plasma, 1 ruby -> 200 plasma
	- petrol
		craft to create: 1 oil
	- electricity
		craft to create: 1 sapphire
	- bullets
	- grenades
	- missiles

weapons (not crafted):
	* blaster 
		weight: light
		damage type: projectile + electricity
		ammo: plasma (slowly recharges, initial capacity 10 or 50 or so)
	- flamethrower (heat)
		ammo: petrol
	- freeze weapon (ice)
		ammo: electricity
	- minigun (projectile)
		ammo: bullets
	* grenade launcher (splash)
		ammo: grenades
	* rocket launcher (/homing? as a modifier?) (projectile + splash)
		ammo: missiles
	- electricity gun / tesla coil (electricity)
		ammo: electricity
	* plasma rifle / rapid fire (projectile + electricity)
		ammo: plasma (added capacity to 100 or 200 or so)
	- skillsaw
		ammo: electricity
	- Halo sword (heat + electricity)
		ammo: ?
	- heat ray (heat)
		ammo: ? 

modifiers (not crafted):
	- ammo capacity
		- plasma
		- petrol
		- electricity
		- bullets
		- grenades
		- missiles
	- grappling hook
	- shield
	- jetpack
	- visors:
		- infrared
		- motion
		- x-ray

inventory (not crafted):
	- armor
		types:
		- reduce biological damage (monster touch)
		- reduce plasma damage
		- reduce explosion damage
		- reduce projectile damage
		- reduce acid damage (environment / radsuit / slime)
		- reduce heat damage ... heat weapons? hear air? heat magma?
		- water breathe time?
		- reduce ice damage
	- legs:
		- speed shoes
		- high jump boots
	- arms:
		- ledge pull-up ? only certain walls?
		- touch & go? only certain walls?
		- lifting objects / upgrade for heavier?

craft materials, found on their own:
	emerald
	ruby
	sapphire	
	blaster frame
	oil

enemies:
	
		mining baes:
	turret -> drop 5% grenade, 5% heart 
	shocking things - vertical and horizontal
	sawblades from mario world ... or indiana jones 
	sentry? 
	rogue robots ... that look like you?

		intro to caves:
	green geemer -> 10% heart 
	red geemer -> 10% heart
	venus fly trap / hides in background
	some sort of close-range guy who walks slowly
	bats or something that hover in circles
	something that shoots something out


inspirations:

Super Mario World (1990.11.21)
Super Metroid (1994.03.19)
Abuse (1996.02.29)
Castlevania: Symphony of the Night (Super Metroid) (1997.03.20)
Cave Story (Super Metroid) (2004.12.20)
Aquaria (Super Metroid) (2007.12.07)
Spelunky (Super Mario World, La-Mulana, Rick Dangerous, Spelunker) (2008.12.21)
Minecraft (Dwarf Fortress) (2009.03.17)
Aliens: Infestation (2011.09.29)
