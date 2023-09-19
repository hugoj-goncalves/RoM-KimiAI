-- Return to Morroc KIMI AI v0.0.2
-- Made by Shift
-- TODO -> Add Ally Swap & Warm Def
-- 

dofile("./AI/Const.lua") -- Reading outside this folder
dofile("./AI/Util.lua") -- Reading outside this folder
--dofile("SkillData.lua")

-----------------------------
-- Quick Config
-----------------------------
AGGRO_MODE				= 1		-- 0 = Passive, 1 = Agressive
IDLE_HEAL_THRESHOLD		= 90	-- % of Owner / Kimi HP when to spam Heal out of combat
COMBAT_HEAL_THRESHOLD	= 50	-- % of Owner / Kimi HP when to spam Heal during combat
WARM_DEF_MONSTERS		= 3		-- Number of monsters required to auto Warm Defence (not used yet)

----------------------------

-----------------------------
-- Default AI States
-----------------------------
IDLE_ST					= 0
FOLLOW_ST				= 1
CHASE_ST				= 2
ATTACK_ST				= 3
MOVE_CMD_ST				= 4
STOP_CMD_ST				= 5
ATTACK_OBJECT_CMD_ST	= 6
ATTACK_AREA_CMD_ST		= 7
PATROL_CMD_ST			= 8
HOLD_CMD_ST				= 9
SKILL_OBJECT_CMD_ST		= 10
SKILL_AREA_CMD_ST		= 11
FOLLOW_CMD_ST			= 12
----------------------------
-- Custom AI States
----------------------------
KITE_CMD_ST				= 13 -- Custom State, Not used

-- Extra Motions TODO -> Move to Const.lua
MOTION_DAMAGE	= 4
MOTION_PICKUP	= 5
MOTION_SIT		= 6
MOTION_SKILL	= 7
MOTION_CASTING	= 8

------------------------------------------
-- Global Variables
------------------------------------------
MyState				= IDLE_ST	-- Current State
MyEnemy				= 0			-- Current Target
MyDestX				= 0			-- Destination X
MyDestY				= 0			-- Destination Y
MyPatrolX			= 0			-- Patrol X
MyPatrolY			= 0			-- Patrol Y
ResCmdList			= List.new()	-- Command List
MyID				= 0			-- My ID
MySkill				= 0			-- Current Skill ID
MySkillLevel		= 0			-- Current Skill Level
------------------------------------------

-- Init inside AI()
Initialized			= false		-- First Initialization
OwnerID				= 0			-- Owners ID
KimiID				= 0			-- Which Kimi

-- Circle
CircleDir			= 1			-- Current circle-move position
AAI_CIRC_X			= {-2, 2, 2,-2} -- X Circle position array
AAI_CIRC_Y			= {-2,-2, 2, 2} -- Y Circle position array
AAI_CIRC_MAXSTEP	= 4			-- Max position in arrays AAI_CIRC_X && AAI_CIRC_Y
WaitTick			= false
KiteState			= false		-- Not used

-- Skills
CastDelayEnd		= 0
SwapIn				= false		-- Not used

------------------------------------------
-- Skill IDs
------------------------------------------
S_MASTER_SWAP			= 8005
S_WARM_DEF				= 8006
S_ILLUSION_OF_CLAWS		= 8009
S_CHAOTIC_HEAL			= 8014
S_BODY_DOUBLE			= 8022
S_ILLUSION_OF_BREATH	= 8024
S_ILLUSION_CRUSHER		= 8031
S_ILLUSION_OF_LIGHT		= 8034

-- TODO - Store skills with more data in SkillData.lua
--S_TEST.SkillID	= 8024
--S_TEST.HowLast	= 500
--S_TEST.Engaged	= false
--S_TEST.TimeOut	= 0
--S_TEST.Target		= 0

------------------------------------------
-- Kimi IDs for readability -> Move to Const.lua
------------------------------------------
KIMI_WARD		= 1
KIMI_OCCULT		= 2
KIMI_AGILE		= 3
KIMI_RAGING		= 4


------------- Command Process  ---------------------

function	OnMOVE_CMD(x,y)
	
	TraceAI("OnMOVE_CMD")

	if ( x == MyDestX and y == MyDestY and MOTION_MOVE == GetV(V_MOTION,MyID)) then
		return		-- Already at destination
	end

	local curX, curY = GetV (V_POSITION,MyID)
	if (math.abs(x-curX)+math.abs(y-curY) > 15) then		-- If distance is greater than 15
		List.pushleft (ResCmdList,{MOVE_CMD,x,y})			-- Delay/Split command
		x = math.floor((x+curX)/2)							-- Floor the destination / 2
		y = math.floor((y+curY)/2)							-- 
	end

	Move(MyID,x,y)	
	
	MyState = MOVE_CMD_ST
	MyDestX = x
	MyDestY = y
	MyEnemy = 0
	MySkill = 0

end



function	OnKITE_CMD(x,y) -- Custom

	TraceAI("OnKITE_CMD")

	if ( x == MyDestX and y == MyDestY and MOTION_MOVE == GetV(V_MOTION,MyID)) then
		return		-- Already at destination
	end

	Kite(MyID, x, y)

	MyState = KITE_CMD_ST
	MyDestX = x
	MyDestY = y
	--MyEnemy = 0
	--MySkill = 0

end



function	OnSTOP_CMD()

	TraceAI("OnSTOP_CMD")

	if (GetV(V_MOTION,MyID) ~= MOTION_STAND) then
		Move(MyID,GetV(V_POSITION,MyID))
	end
	MyState = IDLE_ST
	MyDestX = 0
	MyDestY = 0
	MyEnemy = 0
	MySkill = 0

end



function	OnATTACK_OBJECT_CMD(id)

	TraceAI("OnATTACK_OBJECT_CMD")

	MySkill = 0
	MyEnemy = id
	MyState = CHASE_ST

end



function	OnATTACK_AREA_CMD(x,y)

	TraceAI("OnATTACK_AREA_CMD")

	if (x ~= MyDestX or y ~= MyDestY or MOTION_MOVE ~= GetV(V_MOTION,MyID)) then
		Move(MyID,x,y)	
	end

	MyDestX = x
	MyDestY = y
	MyEnemy = 0
	MyState = ATTACK_AREA_CMD_ST
	
end



function	OnPATROL_CMD(x,y)

	TraceAI("OnPATROL_CMD")

	MyPatrolX , MyPatrolY = GetV (V_POSITION,MyID)
	MyDestX = x
	MyDestY = y
	Move(MyID,x,y)
	MyState = PATROL_CMD_ST

end



function	OnHOLD_CMD()

	TraceAI("OnHOLD_CMD")

	MyDestX = 0
	MyDestY = 0
	MyEnemy = 0
	MyState = HOLD_CMD_ST

end



function	OnSKILL_OBJECT_CMD(level,skill,id)

	TraceAI("OnSKILL_OBJECT_CMD")

	MySkillLevel = level
	MySkill = skill
	MyEnemy = id
	MyState = CHASE_ST

end



function	OnSKILL_AREA_CMD(level,skill,x,y)

	TraceAI("OnSKILL_AREA_CMD")

	Move(MyID,x,y)
	MyDestX = x
	MyDestY = y
	MySkillLevel = level
	MySkill = skill
	MyState = SKILL_AREA_CMD_ST


	
end



function	OnFOLLOW_CMD()

	-- 대기명령은 대기상태와 휴식상태를 서로 전환시킨다. 
	if (MyState ~= FOLLOW_CMD_ST) then
		MoveToOwner(MyID)
		MyState = FOLLOW_CMD_ST
		MyDestX, MyDestY = GetV(V_POSITION,GetV(V_OWNER,MyID))
		MyEnemy = 0 
		--MySkill = 0
		TraceAI("OnFOLLOW_CMD")
	else
		MyState = IDLE_ST
		MyEnemy = 0 
		--MySkill = 0
		TraceAI("FOLLOW_CMD_ST --> IDLE_ST")
	end

end



function	ProcessCommand(msg)

	if		(msg[1] == MOVE_CMD) then
		OnMOVE_CMD (msg[2],msg[3])
		TraceAI("MOVE_CMD")
	elseif (msg[1] == KITE_CMD) then -- Custom
		OnKITE_CMD (msg[2],msg[3])
		TraceAI("KITE_CMD")
	elseif	(msg[1] == STOP_CMD) then
		OnSTOP_CMD ()
		TraceAI("STOP_CMD")
	elseif	(msg[1] == ATTACK_OBJECT_CMD) then
		OnATTACK_OBJECT_CMD (msg[2])
		TraceAI("ATTACK_OBJECT_CMD")
	elseif	(msg[1] == ATTACK_AREA_CMD) then
		OnATTACK_AREA_CMD (msg[2],msg[3])
		TraceAI("ATTACK_AREA_CMD")
	elseif	(msg[1] == PATROL_CMD) then
		OnPATROL_CMD (msg[2],msg[3])
		TraceAI("PATROL_CMD")
	elseif	(msg[1] == HOLD_CMD) then
		OnHOLD_CMD ()
		TraceAI("HOLD_CMD")
	elseif	(msg[1] == SKILL_OBJECT_CMD) then
		OnSKILL_OBJECT_CMD (msg[2],msg[3],msg[4],msg[5])
		TraceAI("SKILL_OBJECT_CMD")
	elseif	(msg[1] == SKILL_AREA_CMD) then
		OnSKILL_AREA_CMD (msg[2],msg[3],msg[4],msg[5])
		TraceAI("SKILL_AREA_CMD")
	elseif	(msg[1] == FOLLOW_CMD) then
		OnFOLLOW_CMD ()
		TraceAI("FOLLOW_CMD")
	end
end



-------------- state process  --------------------


function	OnIDLE_ST()
	
	TraceAI("OnIDLE_ST")

	local cmd = List.popleft(ResCmdList)
	if (cmd ~= nil) then		
		ProcessCommand(cmd)	-- 예약 명령어 처리 
		return 
	end

	-----------------------
	-- Stay near Owner
	-----------------------

	local distance = GetDistanceFromOwner(MyID)
	if (distance > 3 or distance == -1) then		-- MYOWNER_OUTSIGNT_IN
		MyState = FOLLOW_ST
		TraceAI("IDLE_ST -> FOLLOW_ST")
		return
	end

	local	object = GetOwnerEnemy(MyID)
	if (object ~= 0) then							-- MYOWNER_ATTACKED_IN
		MyState = CHASE_ST
		MyEnemy = object
		TraceAI("IDLE_ST -> CHASE_ST : MYOWNER_ATTACKED_IN")
		return 
	end

	object = GetMyEnemy(MyID)
	if (object ~= 0) then							-- ATTACKED_IN
		MyState = CHASE_ST
		MyEnemy = object
		TraceAI("IDLE_ST -> CHASE_ST : ATTACKED_IN")
		return
	end

	-----------------------
	-- Heals
	-----------------------

	local HomunHP = GetV(V_HP, MyID)
	local HomunMaxHP = GetV(V_MAXHP, MyID)
	local HomunHPPerc = (HomunHP / HomunMaxHP) * 100
	
	local OwnerHP = GetV(V_HP, OwnerID)
	local OwnerMaxHP = GetV(V_MAXHP, OwnerID)
	local OwnerHPPerc = (OwnerHP / OwnerMaxHP) * 100

	if (OwnerHPPerc < IDLE_HEAL_THRESHOLD)
	or (HomunHPPerc < IDLE_HEAL_THRESHOLD)
	then
		MyTaget = OwnerID
		SkillObject(MyID, 5, S_CHAOTIC_HEAL, OwnerID)
		return
	end

	-----------------------
	-- Test functions
	-----------------------

	local OwnerMotion = GetV(V_MOTION, OwnerID)

	if (OwnerMotion == MOTION_SIT) then

		-- Easy way to debug
		CircleAroundTarget(OwnerID)
		return

	end

	-----------------------
	-- Target Focus
	-----------------------

	object = 0
	object = GetV(V_TARGET, OwnerID)

	if (object ~= 0) then

		MyState = CHASE_ST
		MyEnemy = object
		--SetSkill()

		return

	end

	if (OwnerMotion == MOTION_CASTING) then -- Owner is casting but we dont have a target

		MyState = CHASE_ST
		MyEnemy = GetMyEnemy(myid)

	end


end



function	OnFOLLOW_ST()

	TraceAI("OnFOLLOW_ST")

	SwapIn = false

	if (GetDistanceFromOwner(MyID) <= 3) then		--  DESTINATION_ARRIVED_IN 
		MyState = IDLE_ST
		TraceAI("FOLLOW_ST -> IDLW_ST")
		return
	elseif (GetV(V_MOTION,MyID) == MOTION_STAND) then
		MoveToOwner (MyID)
		TraceAI("FOLLOW_ST -> FOLLOW_ST")
		return
	end

end



function	OnCHASE_ST()

	TraceAI ("OnCHASE_ST")

	if (true == IsOutOfSight(MyID,MyEnemy)) then	-- ENEMY_OUTSIGHT_IN
		MyState = IDLE_ST
		MyEnemy = 0
		MyDestX, MyDestY = 0,0
		TraceAI("CHASE_ST -> IDLE_ST : ENEMY_OUTSIGHT_IN")
		return
	end
	if (true == IsInAttackSight(MyID,MyEnemy)) then  -- ENEMY_INATTACKSIGHT_IN
		MyState = ATTACK_ST
		TraceAI("CHASE_ST -> ATTACK_ST : ENEMY_INATTACKSIGHT_IN")
		return
	end

	local x, y = GetV (V_POSITION_APPLY_SKILLATTACKRANGE, MyEnemy, MySkill, MySkillLevel)
	if (MyDestX ~= x or MyDestY ~= y) then			-- DESTCHANGED_IN
		MyDestX, MyDestY = GetV (V_POSITION_APPLY_SKILLATTACKRANGE, MyEnemy, MySkill, MySkillLevel)
		Move(MyID,MyDestX,MyDestY)
		TraceAI("CHASE_ST -> CHASE_ST : DESTCHANGED_IN")
		return
	end

end



function	OnATTACK_ST()

	TraceAI("OnATTACK_ST")

	-----------------------
	-- Heals
	-----------------------

	local HomunHP = GetV(V_HP, MyID)
	local HomunMaxHP = GetV(V_MAXHP, MyID)
	local HomunHPPerc = (HomunHP / HomunMaxHP) * 100
	
	local OwnerHP = GetV(V_HP, OwnerID)
	local OwnerMaxHP = GetV(V_MAXHP, OwnerID)
	local OwnerHPPerc = (OwnerHP / OwnerMaxHP) * 100

	if (OwnerHPPerc < COMBAT_HEAL_THRESHOLD)
	or (HomunHPPerc < COMBAT_HEAL_THRESHOLD)
	then
		SkillObject(MyID, 5, S_CHAOTIC_HEAL, OwnerID)
		return
	end

	-----------------------

	if (true == IsOutOfSight(MyID,MyEnemy)) then	-- ENEMY_OUTSIGHT_IN
		MyState = FOLLOW_ST
		TraceAI("ATTACK_ST -> IDLE_ST")
		return 
	end

	if (MOTION_DEAD == GetV(V_MOTION,MyEnemy)) then   -- ENEMY_DEAD_IN
		MyState = FOLLOW_ST
		TraceAI("ATTACK_ST -> IDLE_ST")
		return
	end

	SetSkill() --Always use skill
		
	if (false == IsInAttackSight(MyID,MyEnemy)) then  -- ENEMY_OUTATTACKSIGHT_IN
		MyState = CHASE_ST
		MyDestX, MyDestY = GetV(V_POSITION_APPLY_SKILLATTACKRANGE, MyEnemy, MySkill, MySkillLevel)
		Move(MyID,MyDestX,MyDestY)
		TraceAI("ATTACK_ST -> CHASE_ST  : ENEMY_OUTATTACKSIGHT_IN")
		return
	end
	
	if (MySkill == 0) then -- If there is no skill selected, just auto attack
		Attack(MyID,MyEnemy)
	else

		-- Cast Skill

		if (1 == DoSkill(MySkill, MySkillLevel, MyEnemy)) then
			MyEnemy = 0 -- Cast failed for some reason
		end

		--MySkill = 0 --Default AI resets skill after casting

	end

	TraceAI("ATTACK_ST -> ATTACK_ST  : ENERGY_RECHARGED_IN")
	return

end



function	OnMOVE_CMD_ST()

	TraceAI("OnMOVE_CMD_ST")

	local x, y = GetV (V_POSITION,MyID)
	if (x == MyDestX and y == MyDestY) then				-- DESTINATION_ARRIVED_IN
		
		MyState = IDLE_ST

	end

end



function OnKite_CMD_ST() -- Custom
	
	TraceAI("OnKITE_CMD_ST")

	local x, y = GetV (V_POSITION,MyID)
	if (x == MyDestX and y == MyDestY) then				-- DESTINATION_ARRIVED_IN
		
		MyState = ATTACK_ST
		KiteState = false

	end

end




function OnSTOP_CMD_ST()


end



function OnATTACK_OBJECT_CMD_ST()

	
end



function OnATTACK_AREA_CMD_ST()

	TraceAI("OnATTACK_AREA_CMD_ST")

	local	object = GetOwnerEnemy(MyID)
	if (object == 0) then							
		object = GetMyEnemy(MyID) 
	end

	if (object ~= 0) then							-- MYOWNER_ATTACKED_IN or ATTACKED_IN
		MyState = CHASE_ST
		MyEnemy = object
		return
	end

	local x , y = GetV(V_POSITION,MyID)
	if (x == MyDestX and y == MyDestY) then			-- DESTARRIVED_IN
			MyState = IDLE_ST
	end

end



function OnPATROL_CMD_ST()

	TraceAI("OnPATROL_CMD_ST")

	local	object = GetOwnerEnemy(MyID)
	if (object == 0) then							
		object = GetMyEnemy(MyID) 
	end

	if (object ~= 0) then							-- MYOWNER_ATTACKED_IN or ATTACKED_IN
		MyState = CHASE_ST
		MyEnemy = object
		TraceAI("PATROL_CMD_ST -> CHASE_ST : ATTACKED_IN")
		return
	end

	local x , y = GetV(V_POSITION,MyID)
	if (x == MyDestX and y == MyDestY) then			-- DESTARRIVED_IN
		MyDestX = MyPatrolX
		MyDestY = MyPatrolY
		MyPatrolX = x
		MyPatrolY = y
		Move(MyID,MyDestX,MyDestY)
	end

end



function OnHOLD_CMD_ST()

	TraceAI("OnHOLD_CMD_ST")
	
	if (MyEnemy ~= 0) then
		local d = GetDistance(MyEnemy,MyID)
		if (d ~= -1 and d <= GetV(V_ATTACKRANGE,MyID)) then
				Attack(MyID,MyEnemy)
		else
			MyEnemy = 0
		end
		return
	end


	local	object = GetOwnerEnemy(MyID)
	if (object == 0) then							
		object = GetMyEnemy(MyID)
		if (object == 0) then						
			return
		end
	end

	MyEnemy = object

end



function OnSKILL_OBJECT_CMD_ST()

end

function OnSKILL_AREA_CMD_ST()

	TraceAI("OnSKILL_AREA_CMD_ST")

	local x , y = GetV(V_POSITION,MyID)
	if (GetDistance(x,y,MyDestX,MyDestY) <= GetV(V_SKILLATTACKRANGE_LEVEL, MyID, MySkill, MySkillLevel)) then	-- DESTARRIVED_IN
		SkillGround(MyID,MySkillLevel,MySkill,MyDestX,MyDestY)
		MyState = IDLE_ST
		MySkill = 0
	end

end



function OnFOLLOW_CMD_ST()

	TraceAI("OnFOLLOW_CMD_ST")

	local ownerX, ownerY, myX, myY
	ownerX, ownerY = GetV(V_POSITION,GetV(V_OWNER,MyID)) -- 주인
	myX, myY = GetV(V_POSITION,MyID)					  -- 나 
	
	local d = GetDistance (ownerX,ownerY,myX,myY)

	if ( d <= 3) then									  -- 3셀 이하 거리면 
		return 
	end

	local motion = GetV(V_MOTION,MyID)
	if (motion == MOTION_MOVE) then                       -- 이동중
		d = GetDistance(ownerX, ownerY, MyDestX, MyDestY)
		if ( d > 3) then                                  -- 목적지 변경 ?
			MoveToOwner(MyID)
			MyDestX = ownerX
			MyDestY = ownerY
			return
		end
	else                                                  -- 다른 동작 
		MoveToOwner(MyID)
		MyDestX = ownerX
		MyDestY = ownerY
		return
	end
	
end



function	GetOwnerEnemy(myid)
	local result = 0
	local owner  = GetV(V_OWNER,myid)
	local actors = GetActors()
	local enemys = {}
	local index = 1
	local target
	for i,v in ipairs(actors) do
		if (v ~= owner and v ~= myid) then
			target = GetV (V_TARGET,v)
			if (target == owner) then
				if (IsMonster(v) == 1) then
					enemys[index] = v
					index = index+1
				else
					local motion = GetV(V_MOTION,i)
					if (motion == MOTION_ATTACK or motion == MOTION_ATTACK2 or motion == MOTION_CASTING or motion == MOTION_SKILL) then
						enemys[index] = v
						index = index+1
					end
				end
			end
		end
	end

	local min_dis = 100
	local dis
	for i,v in ipairs(enemys) do
		dis = GetDistance2 (myid,v)
		if (dis < min_dis) then
			result = v
			min_dis = dis
		end
	end
	
	return result
end



function	OwnerIsCastTarget(myid) -- Custom function

	local result = 0
	local owner  = GetV(V_OWNER, myid)
	local actors = GetActors()
	local target

	for i,v in ipairs(actors) do
		if (v ~= owner and v ~= myid) then				-- If not owner or itself
			target = GetV(V_TARGET,v)					-- Get target
			if (target == owner) then					-- Targt is owner
				if (IsMonster(v) == 1) then				-- Its a monster
					local motion = GetV(V_MOTION, i)	-- Get motion
					if (motion == MOTION_CASTING or motion == MOTION_SKILL) then 
						result = v						-- Owner is a skill target
						return result
					end
				end
			end
		end
	end
	
	return result

end



function	GetMyEnemy(myid)

	local result = 0

	--local type = GetV(V_HOMUNTYPE,myid)
	--if (type == LIF or type == LIF_H or type == AMISTR or type == AMISTR_H or type == LIF2 or type == LIF_H2 or type == AMISTR2 or type == AMISTR_H2) then
	--	result = GetMyEnemyA(myid)
	--elseif (type == FILIR or type == FILIR_H or type == VANILMIRTH or type == VANILMIRTH_H or type == FILIR2 or type == FILIR_H2 or type == VANILMIRTH2 or type == VANILMIRTH_H2) then
	--	result = GetMyEnemyB(myid)
	--end

	if (AGGRO_MODE == 0) then
		result = GetMyEnemyA(myid)
	elseif (AGGRO_MODE == 1) then
		result = GetMyEnemyB(myid)
	end

	--result = GetMyEnemyB(myid)

	return result
end




-------------------------------------------
--  Get nearest non agressive enemy
-------------------------------------------
function	GetMyEnemyA(myid)
	local result = 0
	local owner  = GetV(V_OWNER,myid)
	local actors = GetActors()
	local enemys = {}
	local index = 1
	local target
	for i,v in ipairs(actors) do
		if (v ~= owner and v ~= myid) then
			target = GetV(V_TARGET,v)
			if (target == myid) then
				enemys[index] = v
				index = index+1
			end
		end
	end

	local min_dis = 100
	local dis
	for i,v in ipairs(enemys) do
		dis = GetDistance2(myid,v)
		if (dis < min_dis) then

			-- Additional Check, LineOfSight, Alive etc.
			if (true == CanChaseEnemy(v)) then
				result = v
				min_dis = dis
			end

		end
	end

	return result
end



-------------------------------------------
--  Get nearest agressive enemy
-------------------------------------------
function	GetMyEnemyB(myid)
	local result = 0
	local owner  = GetV(V_OWNER,myid)
	local actors = GetActors()
	local enemys = {}
	local index = 1
	local type
	for i,v in ipairs(actors) do
		if (v ~= owner and v ~= myid) then
			if (1 == IsMonster(v))	then
				enemys[index] = v
				index = index+1
			end
		end
	end

	local min_dis = 100
	local dis
	for i,v in ipairs(enemys) do
		dis = GetDistance2(myid,v)
		if (dis < min_dis) then

			-- Additional Check, LineOfSight, Alive etc.
			if (true == CanChaseEnemy(v)) then
				result = v
				min_dis = dis
			end

		end
	end

	return result
end



function	CanChaseEnemy(enemyid)

	local result = false

	if (true == IsOutOfSight(MyID,enemyid)) then	-- ENEMY_OUTSIGHT_IN
		result = false
	end
	if (true == IsInAttackSight(MyID,enemyid)) then  -- ENEMY_INATTACKSIGHT_IN
		result = true
	end

	return result

end



function AI(myid)

	MyID = myid
	local msg	= GetMsg(myid)			-- command
	local rmsg	= GetResMsg(myid)		-- reserved command

	if not Initialized then

		OwnerID = GetV(V_OWNER, MyID)
		KimiID = GetV(V_HOMUNTYPE, MyID)
		Initialized = true
		-- FriendList_Clear() Missing function

	end
	
	if msg[1] == NONE_CMD then
		if rmsg[1] ~= NONE_CMD then
			if List.size(ResCmdList) < 10 then
				List.pushright(ResCmdList,rmsg) -- 예약 명령 저장
			end
		end
	else
		List.clear(ResCmdList)	-- 새로운 명령이 입력되면 예약 명령들은 삭제한다.  
		ProcessCommand (msg)	-- 명령어 처리 
	end

		
	-- 상태 처리 
 	if (MyState == IDLE_ST) then
		OnIDLE_ST()
	elseif (MyState == CHASE_ST) then					
		OnCHASE_ST()
	elseif (MyState == ATTACK_ST) then
		OnATTACK_ST()
	elseif (MyState == FOLLOW_ST) then
		OnFOLLOW_ST()
	elseif (MyState == MOVE_CMD_ST) then
		OnMOVE_CMD_ST()
	elseif (MyState == KITE_CMD_ST) then -- Custom
		OnKITE_CMD_ST()
	elseif (MyState == STOP_CMD_ST) then
		OnSTOP_CMD_ST()
	elseif (MyState == ATTACK_OBJECT_CMD_ST) then
		OnATTACK_OBJECT_CMD_ST()
	elseif (MyState == ATTACK_AREA_CMD_ST) then
		OnATTACK_AREA_CMD_ST()
	elseif (MyState == PATROL_CMD_ST) then
		OnPATROL_CMD_ST()
	elseif (MyState == HOLD_CMD_ST) then
		OnHOLD_CMD_ST()
	elseif (MyState == SKILL_OBJECT_CMD_ST) then
		OnSKILL_OBJECT_CMD_ST()
	elseif (MyState == SKILL_AREA_CMD_ST) then
		OnSKILL_AREA_CMD_ST()
	elseif (MyState == FOLLOW_CMD_ST) then
		OnFOLLOW_CMD_ST()
	end

end

function Clamp(x, min, max)
    if x < min then return min end
    if x > max then return max end
    return x
end

function KiteTarget(TrgID)

	KiteState = true

	local x, y		= Get_V(V_POSITION, MyID)
	local tx, ty	= Get_V(V_POSITION, TrgID)
	local dirX, dirY
			
	dirX = Clamp(x - ex, -1, 1)
	dirY = Clamp(y - ey, -1, 1)

	Move(MyID, x + dirX, y + dirY)

end


function CircleAroundTarget(TrgID)
--------------------------------------------------

	-- Find closest corner

	local ox, oy	= GetV(V_POSITION, TrgID) -- target position
	local x, y		= GetV(V_POSITION, MyID) -- current position

	MyDestX = ox + AAI_CIRC_X[CircleDir]
	MyDestY = oy + AAI_CIRC_Y[CircleDir]

	-- Check if stuck, timeout and just try to go to next spot
	-- If stuck too many times idk maybe go to owner

	--------------- At destination -------------
	-- Not sure if there is RO jank, but previous if check used math, probaby dont need it
	--if  (math.abs(MyDestX - x) < 1)
	--and (math.abs(MyDestY - y) < 1) -- yes!
	if (x == MyDestX)
	and (y == MyDestY)
	then

		CircleDir = CircleDir + 1 -- increment position

		if (CircleDir > AAI_CIRC_MAXSTEP) then -- final position, reset circle
			CircleDir = 1
		end

	else

		Move(MyID, MyDestX, MyDestY) -- Was outside of condition before, but was janky af

	end

end

--------------------------------------------------
function DoSkill(Skill, Level, Target)
--------------------------------------------------

	--if Skill.Level == 0 then return false; end
	local CurrTime = GetTick()
	if CastDelayEnd > CurrTime then return false; end

	local HomunSP = GetV(V_SP, MyID)
	local result = false

	--if Skill.Engaged then -- if the skill is already active (or in delay time), wait until it goes OFF

		--if CurrTime > Skill.TimeOut then
		--	Skill.Engaged = false
		--end

	--else -- if the skill is OFF, activate it

		--if HomunSP >= Skill.MinSP then -- if there are enough SP left

			MySkill = Skill
			MySkillLevel = Level
			--Skill.TimeOut = CurrTime + 300
			--Skill.Engaged = true
			SkillObject(MyID, MySkillLevel, MySkill, Target)
			CastDelayEnd = CurrTime + 300
			result = true
			--MySkill = 0

		--end

	--end

	MySkill = 0
	MySkillLevel = 0

	return result

end


function SetSkill()

	-- Todo -> GetSkill level

	if KimiID == KIMI_OCCULT then 
		MySkill = S_ILLUSION_OF_BREATH
		MySkillLevel = 10
	else -- All other Kimis
		MySkill = S_ILLUSION_OF_CLAWS
		MySkillLevel = 5
	end

end

function DoSwap() -- Not used currently

	local result = false

	if (OwnerIsCastTarget(MyID)) then

		DoSkill(S_MASTER_SWAP, 5, OwnerID)
		result = true

	end

	return result

end
