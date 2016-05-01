return {
	{	
	--[[
	TODO:
	jump_fall and ledge_fall might have overlaps
	same with the last landing frame and some standing frames
	--]]
		name='samus',
		dir='samus',
		freq=24,
		frames={
			stand_fwd='stand_fwd.png',		-- stand facing forward
			
			stand_r1='stand_r1.png',	-- stand right
			stand_r2='stand_r2.png',
			stand_r3='stand_r3.png',

			stand_l1='stand_l1.png',	-- stand left
			stand_l2='stand_l2.png',
			stand_l3='stand_l3.png',

			kneel_l1='kneel_l1.png',
			kneel_l2='kneel_l2.png',
			kneel_l3='kneel_l3.png',
			
			kneel_r1='kneel_r1.png',
			kneel_r2='kneel_r2.png',
			kneel_r3='kneel_r3.png',
			
			run_l1='run_l1.png',
			run_l2='run_l2.png',
			run_l3='run_l3.png',
			run_l4='run_l4.png',
			run_l5='run_l5.png',
			run_l6='run_l6.png',
			run_l7='run_l7.png',
			run_l8='run_l8.png',
			run_l9='run_l9.png',
			run_l10='run_l10.png',

			run_r1='run_r1.png',
			run_r2='run_r2.png',
			run_r3='run_r3.png',
			run_r4='run_r4.png',
			run_r5='run_r5.png',
			run_r6='run_r6.png',
			run_r7='run_r7.png',
			run_r8='run_r8.png',
			run_r9='run_r9.png',
			run_r10='run_r10.png',
			
			run_diag_up_l1='run_diag_up_l1.png',
			run_diag_up_l2='run_diag_up_l2.png',
			run_diag_up_l3='run_diag_up_l3.png',
			run_diag_up_l4='run_diag_up_l4.png',
			run_diag_up_l5='run_diag_up_l5.png',
			run_diag_up_l6='run_diag_up_l6.png',
			run_diag_up_l7='run_diag_up_l7.png',
			run_diag_up_l8='run_diag_up_l8.png',
			run_diag_up_l9='run_diag_up_l9.png',
			run_diag_up_l10='run_diag_up_l10.png',

			run_diag_up_r1='run_diag_up_r1.png',
			run_diag_up_r2='run_diag_up_r2.png',
			run_diag_up_r3='run_diag_up_r3.png',
			run_diag_up_r4='run_diag_up_r4.png',
			run_diag_up_r5='run_diag_up_r5.png',
			run_diag_up_r6='run_diag_up_r6.png',
			run_diag_up_r7='run_diag_up_r7.png',
			run_diag_up_r8='run_diag_up_r8.png',
			run_diag_up_r9='run_diag_up_r9.png',
			run_diag_up_r10='run_diag_up_r10.png',
						
			run_diag_down_l1='run_diag_down_l1.png',
			run_diag_down_l2='run_diag_down_l2.png',
			run_diag_down_l3='run_diag_down_l3.png',
			run_diag_down_l4='run_diag_down_l4.png',
			run_diag_down_l5='run_diag_down_l5.png',
			run_diag_down_l6='run_diag_down_l6.png',
			run_diag_down_l7='run_diag_down_l7.png',
			run_diag_down_l8='run_diag_down_l8.png',
			run_diag_down_l9='run_diag_down_l9.png',
			run_diag_down_l10='run_diag_down_l10.png',
			
			run_diag_down_r1='run_diag_down_r1.png',
			run_diag_down_r2='run_diag_down_r2.png',
			run_diag_down_r3='run_diag_down_r3.png',
			run_diag_down_r4='run_diag_down_r4.png',
			run_diag_down_r5='run_diag_down_r5.png',
			run_diag_down_r6='run_diag_down_r6.png',
			run_diag_down_r7='run_diag_down_r7.png',
			run_diag_down_r8='run_diag_down_r8.png',
			run_diag_down_r9='run_diag_down_r9.png',
			run_diag_down_r10='run_diag_down_r10.png',
						
			run_shoot_l1='run_shoot_l1.png',
			run_shoot_l2='run_shoot_l2.png',
			run_shoot_l3='run_shoot_l3.png',
			run_shoot_l4='run_shoot_l4.png',
			run_shoot_l5='run_shoot_l5.png',
			run_shoot_l6='run_shoot_l6.png',
			run_shoot_l7='run_shoot_l7.png',
			run_shoot_l8='run_shoot_l8.png',
			run_shoot_l9='run_shoot_l9.png',
			run_shoot_l10='run_shoot_l10.png',
			
			run_shoot_r1='run_shoot_r1.png',
			run_shoot_r2='run_shoot_r2.png',
			run_shoot_r3='run_shoot_r3.png',
			run_shoot_r4='run_shoot_r4.png',
			run_shoot_r5='run_shoot_r5.png',
			run_shoot_r6='run_shoot_r6.png',
			run_shoot_r7='run_shoot_r7.png',
			run_shoot_r8='run_shoot_r8.png',
			run_shoot_r9='run_shoot_r9.png',
			run_shoot_r10='run_shoot_r10.png',
									
			jump_up_l1='jump_up_l1.png',	-- jump up facing left
			jump_up_l2='jump_up_l2.png',	-- (repeat. jump peaked => jump_fall_l1)
			jump_fall_l1='jump_fall_l1.png',	-- fall after jumping, facing left
			jump_fall_l2='jump_fall_l2.png',
			jump_fall_l3='jump_fall_l3.png',
			jump_fall_l4='jump_fall_l4.png',	-- (repeat. land => land_l1)

			jump_up_r1='jump_up_r1.png',	-- jump up facing right
			jump_up_r2='jump_up_r2.png',
			jump_fall_r1='jump_fall_r1.png',	-- fall after jumping, facing right
			jump_fall_r2='jump_fall_r2.png',
			jump_fall_r3='jump_fall_r3.png',
			jump_fall_r4='jump_fall_r4.png',	-- (repeat. land => land_r1)
			
			ledge_fall_l1='ledge_fall_l1.png',
			ledge_fall_l2='ledge_fall_l2.png',
			ledge_fall_l3='ledge_fall_l3.png',
			ledge_extra_l1='ledge_extra_l1.png',
			ledge_extra_l2='ledge_extra_l2.png',

			ledge_fall_r1='ledge_fall_r1.png',
			ledge_fall_r2='ledge_fall_r2.png',
			ledge_fall_r3='ledge_fall_r3.png',
			ledge_extra_r1='ledge_extra_r1.png',
			ledge_extra_r2='ledge_extra_r2.png',

			enter_morph_l1='enter_morph_l1.png',
			enter_morph_l2='enter_morph_l2.png',
			
			enter_morph_r1='enter_morph_r1.png',
			enter_morph_r2='enter_morph_r2.png',

			morph_1='morph_1.png',
			morph_2='morph_2.png',
			morph_3='morph_3.png',
			morph_4='morph_4.png',
			morph_5='morph_5.png',
			morph_6='morph_6.png',
			morph_7='morph_7.png',
			morph_8='morph_8.png',

			jump_aim_diag_up_r='jump_aim_diag_up_r.png',

			fall_aim_diag_up_r='fall_aim_diag_up_r.png',

			jump_aim_diag_down_r='jump_aim_diag_down_r.png',

			fall_aim_diag_down_r='fall_aim_diag_down_r.png',

			land_l1='land_l1.png',	-- land facing left
			land_l2='land_l2.png',	-- => standl1, or to the next frame ...
			
			land_r1='land_r1.png',	-- land facing right
			land_r2='land_r2.png',	-- 

			-- extra frames similar to stand sequences (but slightly different)
			jump_land_l3='jump_land_l3.png',
			jump_land_r3='jump_land_r3.png',
			ledge_land_l3='ledge_land_l3.png',
			extra_stand_r='extra_stand_r.png',
			
			touchngo_l='touchngo_l.png',
			touchngo_r='touchngo_r.png',
			
			flip_l1='flip_l1.png',
			flip_l2='flip_l2.png',
			flip_l3='flip_l3.png',
			flip_l4='flip_l4.png',
			flip_l5='flip_l5.png',
			flip_l6='flip_l6.png',
			flip_l7='flip_l7.png',
			flip_l8='flip_l8.png',

			flip_r1='flip_r1.png',
			flip_r2='flip_r2.png',
			flip_r3='flip_r3.png',
			flip_r4='flip_r4.png',
			flip_r5='flip_r5.png',
			flip_r6='flip_r6.png',
			flip_r7='flip_r7.png',
			flip_r8='flip_r8.png',
			
			fall_aimdown_l='fall_aimdown_l.png',
			fall_aimdown_r='fall_aimdown_r.png',
	
			-- TODO find arm missile left

			-- might be duplicates ... check why it's not symmetric with right-standing
			stand_missile_l1='stand_missile_l1.png',
			stand_missile_l2='stand_missile_l2.png',
			stand_missile_l3='stand_missile_l3.png',
			
			-- i think there's supposed to be another arm missile before the first?
			arm_missile_r1='arm_missile_r1.png',
			stand_missile_r1='stand_missile_r1.png',
			
			turn_l='turn_l.png',		-- turn left to right
			turn_fwd='turn_fwd.png',
			turn_r='turn_r.png',		-- => standr1

			turn_aimup_l='turn_aimup_l.png',		-- turn left to right while aiming up
			turn_aimup_fwd='turn_aimup_fwd.png',
			turn_aimup_r='turn_aimup_r.png',		-- => aimur

			turn_aimdown_l='turn_aimdown_l.png',		-- turn left to right while aiming (diagonally) down
			turn_aimdown_fwd='turn_aimdown_fwd.png',	-- diagonally only, since you can't aim down without kneeling
			turn_aimdown_r='turn_aimdown_r.png',		-- => aimur
			
			turn_kneel_l='turn_kneel_l.png',
			turn_kneel_fwd='turn_kneel_fwd.png',
			turn_kneel_r='turn_kneel_r.png',
			
			turn_aimup_kneel_l='turn_aimup_kneel_l.png',
			turn_aimup_kneel_fwd='turn_aimup_kneel_fwd.png',
			turn_aimup_kneel_r='turn_aimup_kneel_r.png',

			turn_aimdown_kneel_l='turn_kneel_l.png',
			turn_aimdown_kneel_fwd='turn_kneel_fwd.png',
			turn_aimdown_kneel_r='turn_kneel_r.png',
			
			aim_up_l='aim_up_l.png',	-- aim up while standing facing left
			aim_up_r='aim_up_r.png',	-- aim up while standing facing right
			
			aim_missile_up_l='aim_missile_up_l.png',	-- aim up missile while standing facing left
			aim_missile_up_r='aim_missile_up_r.png',	-- aim up missile while standing facing right
			
			aim_diag_up_l1='aim_diag_up_l1.png',
			aim_diag_up_l2='aim_diag_up_l2.png',

			aim_diag_up_r1='aim_diag_up_r1.png',
			aim_diag_up_r2='aim_diag_up_r2.png',
			
			aim_diag_up_kneel_l='aim_diag_up_kneel_l.png',
			aim_diag_up_kneel_r='aim_diag_up_kneel_r.png',

			aim_missile_diag_up_l='aim_missile_diag_up_l.png',	-- aim missile up and left
			
			aim_diag_down_l1='aim_diag_down_l1.png',
			aim_diag_down_l2='aim_diag_down_l2.png',

			aim_diag_down_r1='aim_diag_down_r1.png',
			aim_diag_down_r2='aim_diag_down_r2.png',
			
			--aim_missile_diag_down_l='aim_missile_diag_down_l.png',	-- aim missile down and left
			aim_missile_diag_down_r='aim_missile_diag_down_r.png',	-- aim missile down and right
			
			aim_diag_down_kneel_l='aim_diag_down_kneel_l.png',
			aim_diag_down_kneel_r='aim_diag_down_kneel_r.png',
			
			painl='painl.png',
			painr='painr.png',
			
			dieflash='dieflash.png',	-- die flash
			die1='die1.png',
			die2='die2.png',
			die3='die3.png',
			die4='die4.png',
			die5='die5.png',
			die6='die6.png',
			die7='die7.png',
			die8='die8.png',
			
		},
		seqs={
			stand={'stand_fwd'},	-- alias for the default
			
			stand_l={freq=8, 'stand_l1', 'stand_l2', 'stand_l3', 'stand_l2'},
			stand_r={freq=8, 'stand_r1', 'stand_r2', 'stand_r3', 'stand_r2'},
			
			kneel_l={freq=8, 'kneel_l1', 'kneel_l2', 'kneel_l3', 'kneel_l2'},
			kneel_r={freq=8, 'kneel_r1', 'kneel_r2', 'kneel_r3', 'kneel_r2'},
			
			run_l={'run_l1', 'run_l2', 'run_l3', 'run_l4', 'run_l5', 'run_l6', 'run_l7', 'run_l8', 'run_l9', 'run_l10'},
			run_r={'run_r1', 'run_r2', 'run_r3', 'run_r4', 'run_r5', 'run_r6', 'run_r7', 'run_r8', 'run_r9', 'run_r10'},

			run_diag_up_l={'run_diag_up_l1', 'run_diag_up_l2', 'run_diag_up_l3', 'run_diag_up_l4', 'run_diag_up_l5', 'run_diag_up_l6', 'run_diag_up_l7', 'run_diag_up_l8', 'run_diag_up_l9', 'run_diag_up_l10'},
			run_diag_up_r={'run_diag_up_r1', 'run_diag_up_r2', 'run_diag_up_r3', 'run_diag_up_r4', 'run_diag_up_r5', 'run_diag_up_r6', 'run_diag_up_r7', 'run_diag_up_r8', 'run_diag_up_r9', 'run_diag_up_r10'},

			run_diag_down_l={'run_diag_down_l1', 'run_diag_down_l2', 'run_diag_down_l3', 'run_diag_down_l4', 'run_diag_down_l5', 'run_diag_down_l6', 'run_diag_down_l7', 'run_diag_down_l8', 'run_diag_down_l9', 'run_diag_down_l10'},
			run_diag_down_r={'run_diag_down_r1', 'run_diag_down_r2', 'run_diag_down_r3', 'run_diag_down_r4', 'run_diag_down_r5', 'run_diag_down_r6', 'run_diag_down_r7', 'run_diag_down_r8', 'run_diag_down_r9', 'run_diag_down_r10'},

			run_shoot_l={'run_shoot_l1', 'run_shoot_l2', 'run_shoot_l3', 'run_shoot_l4', 'run_shoot_l5', 'run_shoot_l6', 'run_shoot_l7', 'run_shoot_l8', 'run_shoot_l9', 'run_shoot_l10'},
			run_shoot_r={'run_shoot_r1', 'run_shoot_r2', 'run_shoot_r3', 'run_shoot_r4', 'run_shoot_r5', 'run_shoot_r6', 'run_shoot_r7', 'run_shoot_r8', 'run_shoot_r9', 'run_shoot_r10'},
			
			turn_ltor={'turn_l','turn_fwd','turn_r'},	-- => standr
			turn_rtol={'turn_r','turn_fwd','turn_l'},	-- => standl

			turn_aimup_ltor={'turn_aimup_l', 'turn_aimup_fwd', 'turn_aimup_r'},	-- => aim_up_r
			turn_aimup_rtol={'turn_aimup_r', 'turn_aimup_fwd', 'turn_aimup_l'},	-- => aim_up_l

			turn_aimdown_ltor={'turn_aimdown_l', 'turn_aimdown_fwd', 'turn_aimdown_r'},	-- => aim_down_r
			turn_aimdown_rtol={'turn_aimdown_r', 'turn_aimdown_fwd', 'turn_aimdown_l'},	-- => aim_down_l

			turn_kneel_ltor={'turn_kneel_l', 'turn_kneel_fwd', 'turn_kneel_r'},	-- => kneel_r
			turn_kneel_rtol={'turn_kneel_r', 'turn_kneel_fwd', 'turn_kneel_l'},	-- => kneel_l

			turn_aimup_kneel_ltor={'turn_aimup_kneel_l', 'turn_aimup_kneel_fwd', 'turn_aimup_kneel_r'},	-- => aim_up_r
			turn_aimup_kneel_rtol={'turn_aimup_kneel_r', 'turn_aimup_kneel_fwd', 'turn_aimup_kneel_l'},	-- => aim_up_l

			turn_aimdown_kneel_ltor={'turn_aimdown_kneel_l', 'turn_aimdown_kneel_fwd', 'turn_aimdown_kneel_r'},	-- => aim_down_r
			turn_aimdown_kneel_rtol={'turn_aimdown_kneel_r', 'turn_aimdown_kneel_fwd', 'turn_aimdown_kneel_l'},	-- => aim_down_l

			jump_up_l={'jump_up_l1', 'jump_up_l2'},	-- => jump_fall_l
			jump_up_r={'jump_up_r1', 'jump_up_r2'},	-- => jump_fall_r

			jump_fall_l={'jump_fall_l1', 'jump_fall_l2', 'jump_fall_l3', 'jump_fall_l4'},	-- => land_l
			jump_fall_r={'jump_fall_r1', 'jump_fall_r2', 'jump_fall_r3', 'jump_fall_r4'},	-- => land_r
			
			ledge_fall_l={'ledge_fall_l1', 'ledge_fall_l2', 'ledge_fall_l3'},
			ledge_fall_r={'ledge_fall_r1', 'ledge_fall_r2', 'ledge_fall_r3'},

			land_l={'land_l1', 'land_l2'},	-- => standl
			land_r={'land_r1', 'land_r2'},	-- => standl

			flip_l={'flip_l1', 'flip_l2', 'flip_l3', 'flip_l4', 'flip_l5', 'flip_l6', 'flip_l7', 'flip_l8'},
			flip_r={'flip_r1', 'flip_r2', 'flip_r3', 'flip_r4', 'flip_r5', 'flip_r6', 'flip_r7', 'flip_r8'},
			
			aim_diag_up_l={'aim_diag_up_l1', 'aim_diag_up_l2'},
			aim_diag_up_r={'aim_diag_up_r1', 'aim_diag_up_r2'},
			
			aim_diag_down_l={'aim_diag_up_l1', 'aim_diag_up_l2'},
			aim_diag_down_r={'aim_diag_up_r1', 'aim_diag_up_r2'},
			
			enter_morph_l={'enter_morph_l1', 'enter_morph_l2'},
			enter_morph_r={'enter_morph_r1', 'enter_morph_r2'},
			
			morph_l={freq=8, 'morph_8', 'morph_7', 'morph_6', 'morph_5', 'morph_4', 'morph_3', 'morph_2', 'morph_1'},
			morph_r={freq=8, 'morph_1', 'morph_2', 'morph_3', 'morph_4', 'morph_5', 'morph_6', 'morph_7', 'morph_8'},
			
			leave_morph_l={'enter_morph_l2', 'enter_morph_l1'},
			leave_morph_r={'enter_morph_r2', 'enter_morph_r1'},
			
			dieflash={'painl', 'dieflash'},	-- => die
			die={'die1', 'die2', 'die3', 'die4', 'die5', 'die6', 'die7', 'die8'},	-- => fade out
		},
	},
	
	{
		name='shot',
		dir='shot',
		frames={
			stand='stand.png',
		},
	},
	
	{
		name='door-frame',
		dir='door',
		frames={
			stand='frame.png',
		},
	},
	
	{
		name='door-portal',
		dir='door',
		frames={
			stand='portal.png',
			open1='open1.png',
			open2='open2.png',
			open3='open3.png',
		},
		seqs={
			open={'open1', 'open2', 'open3'},
		},
	},
}
