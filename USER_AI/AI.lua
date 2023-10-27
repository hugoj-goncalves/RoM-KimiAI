-- Return to Morroc KIMI AI v0.0.3
-- Made by Shift
-- TODO -> Add Ally Swap & Body Double
-- 
dofile("./AI/Const.lua") -- Reading outside this folder
dofile("./AI/Util.lua") -- Reading outside this folder
-- dofile("SkillData.lua")

-----------------------------
-- Quick Config
-----------------------------
AGGRO_MODE = 1 -- 0 = Passive, 1 = Agressive
MAX_AGGRO_RANGE = 10 -- Max range where to find monsters while standing
IDLE_HEAL_THRESHOLD = 70 -- % of Owner / Kimi HP when to spam Heal out of combat
COMBAT_HEAL_THRESHOLD = 40 -- % of Owner / Kimi HP when to spam Heal during combat
AUTO_WARM_DEF = 0 -- 0 = Disabled, 1 = Enabled
AUTO_ATTACK_SKILL = 1 -- 0 = Disabled, 1 = Enabled
ATTACK_SP = 70 -- 0 = Disables check
HEAL_SP = 50 -- 0 = Disables check
HEAL_LVL = 3
BREATH_LVL = 10
CLAWS_LVL = 1
DROP_TARGET_IF_NOT_MOVING_FOR = 1500 -- go back to IDLE if target is not reachable for some reason
MOVE_TO_OWNER_ACTION_DELAY = 1500 -- looks slower if move is called too often o.o

----------------------------

-----------------------------
-- Default AI States
-----------------------------
IDLE_ST = 0
FOLLOW_ST = 1
CHASE_ST = 2
ATTACK_ST = 3
MOVE_CMD_ST = 4
STOP_CMD_ST = 5
ATTACK_OBJECT_CMD_ST = 6
ATTACK_AREA_CMD_ST = 7
PATROL_CMD_ST = 8
HOLD_CMD_ST = 9
SKILL_OBJECT_CMD_ST = 10
SKILL_AREA_CMD_ST = 11
FOLLOW_CMD_ST = 12
----------------------------
-- Custom AI States
----------------------------
KITE_CMD_ST = 13 -- Custom State, Not used

-- Extra Motions TODO -> Move to Const.lua
MOTION_DAMAGE = 4
MOTION_PICKUP = 5
MOTION_SIT = 6
MOTION_SKILL = 7
MOTION_CASTING = 8

------------------------------------------
-- Global Variables
------------------------------------------
MyState = IDLE_ST -- Current State
MyEnemy = 0 -- Current Target
MyDestX = 0 -- Destination X
MyDestY = 0 -- Destination Y
MyPatrolX = 0 -- Patrol X
MyPatrolY = 0 -- Patrol Y
ResCmdList = List.new() -- Command List
MyID = 0 -- My ID
MySkill = 0 -- Current Skill ID
MySkillLevel = 0 -- Current Skill Level
------------------------------------------

-- Init inside AI()
Initialized = false -- First Initialization
OwnerID = 0 -- Owners ID
KimiID = 0 -- Which Kimi

-- Circle
CircleDir = 1 -- Current circle-move position
AAI_CIRC_X = {-2, 2, 2, -2} -- X Circle position array
AAI_CIRC_Y = {-2, -2, 2, 2} -- Y Circle position array
AAI_CIRC_MAXSTEP = 4 -- Max position in arrays AAI_CIRC_X && AAI_CIRC_Y
WaitTick = false
KiteState = false -- Not used

-- Skills
CastDelayEnd = 0
SwapIn = false -- Not used

------------------------------------------
-- Skill IDs
------------------------------------------
S_MASTER_SWAP = 8005
S_WARM_DEF = 8006
S_ILLUSION_OF_CLAWS = 8009
S_CHAOTIC_HEAL = 8014
S_BODY_DOUBLE = 8022
S_ILLUSION_OF_BREATH = 8024
S_ILLUSION_CRUSHER = 8031
S_ILLUSION_OF_LIGHT = 8034

-- TODO - Store skills with more data in SkillData.lua
-- S_TEST.SkillID	= 8024
-- S_TEST.HowLast	= 500
-- S_TEST.Engaged	= false
-- S_TEST.TimeOut	= 0
-- S_TEST.Target		= 0
WarmDefTimer = 0

------------------------------------------
-- Kimi IDs for readability -> Move to Const.lua
------------------------------------------
KIMI_WARD = 1
KIMI_OCCULT = 2
KIMI_AGILE = 3
KIMI_RAGING = 4

------------------------------------------
-- Caches
------------------------------------------
MY_TRYING_MOVE_TIMER = 0
MY_TRYING_MOVE_TO_OWNER_TIMER = 0
MY_LAST_POS_X = -1
MY_LAST_POS_Y = -1

------------- Command Process  ---------------------

function OnMOVE_CMD(x, y)

    TraceAI("OnMOVE_CMD")

    if (x == MyDestX and y == MyDestY and MOTION_MOVE == GetV(V_MOTION, MyID)) then
        return -- Already at destination
    end

    local curX, curY = GetV(V_POSITION, MyID)
    if (math.abs(x - curX) + math.abs(y - curY) > 15) then -- If distance is greater than 15
        List.pushleft(ResCmdList, {MOVE_CMD, x, y}) -- Delay/Split command
        x = math.floor((x + curX) / 2) -- Floor the destination / 2
        y = math.floor((y + curY) / 2) -- 
    end

    Move(MyID, x, y)

    MyState = MOVE_CMD_ST
    MyDestX = x
    MyDestY = y
    MyEnemy = 0
    MySkill = 0

end

function OnKITE_CMD(x, y) -- Custom

    TraceAI("OnKITE_CMD")

    if (x == MyDestX and y == MyDestY and MOTION_MOVE == GetV(V_MOTION, MyID)) then
        return -- Already at destination
    end

    Kite(MyID, x, y)

    MyState = KITE_CMD_ST
    MyDestX = x
    MyDestY = y
    -- MyEnemy = 0
    -- MySkill = 0

end

function OnSTOP_CMD()

    TraceAI("OnSTOP_CMD")

    if (GetV(V_MOTION, MyID) ~= MOTION_STAND) then
        Move(MyID, GetV(V_POSITION, MyID))
    end
    MyState = IDLE_ST
    MyDestX = 0
    MyDestY = 0
    MyEnemy = 0
    MySkill = 0

end

function OnATTACK_OBJECT_CMD(id)

    TraceAI("OnATTACK_OBJECT_CMD")

    MySkill = 0
    MyEnemy = id
    MyState = CHASE_ST

end

function OnATTACK_AREA_CMD(x, y)

    TraceAI("OnATTACK_AREA_CMD")

    if (x ~= MyDestX or y ~= MyDestY or MOTION_MOVE ~= GetV(V_MOTION, MyID)) then
        Move(MyID, x, y)
    end

    MyDestX = x
    MyDestY = y
    MyEnemy = 0
    MyState = ATTACK_AREA_CMD_ST

end

function OnPATROL_CMD(x, y)

    TraceAI("OnPATROL_CMD")

    MyPatrolX, MyPatrolY = GetV(V_POSITION, MyID)
    MyDestX = x
    MyDestY = y
    Move(MyID, x, y)
    MyState = PATROL_CMD_ST

end

function OnHOLD_CMD()

    TraceAI("OnHOLD_CMD")

    MyDestX = 0
    MyDestY = 0
    MyEnemy = 0
    MyState = HOLD_CMD_ST

end

function OnSKILL_OBJECT_CMD(level, skill, id)

    TraceAI("OnSKILL_OBJECT_CMD")

    MySkillLevel = level
    MySkill = skill
    MyEnemy = id
    MyState = CHASE_ST

end

function OnSKILL_AREA_CMD(level, skill, x, y)

    TraceAI("OnSKILL_AREA_CMD")

    Move(MyID, x, y)
    MyDestX = x
    MyDestY = y
    MySkillLevel = level
    MySkill = skill
    MyState = SKILL_AREA_CMD_ST

end

function OnFOLLOW_CMD()

    -- ´ë±â¸í·ÉÀº ´ë±â»óÅÂ¿Í ÈÞ½Ä»óÅÂ¸¦ ¼­·Î ÀüÈ¯½ÃÅ²´Ù. 
    if (MyState ~= FOLLOW_CMD_ST) then
        MoveToOwner(MyID)
        MyState = FOLLOW_CMD_ST
        MyDestX, MyDestY = GetV(V_POSITION, GetV(V_OWNER, MyID))
        MyEnemy = 0
        -- MySkill = 0
        TraceAI("OnFOLLOW_CMD")
    else
        MyState = IDLE_ST
        MyEnemy = 0
        -- MySkill = 0
        TraceAI("FOLLOW_CMD_ST --> IDLE_ST")
    end

end

function ProcessCommand(msg)

    if (msg[1] == MOVE_CMD) then
        OnMOVE_CMD(msg[2], msg[3])
        TraceAI("MOVE_CMD")
    elseif (msg[1] == KITE_CMD) then -- Custom
        OnKITE_CMD(msg[2], msg[3])
        TraceAI("KITE_CMD")
    elseif (msg[1] == STOP_CMD) then
        OnSTOP_CMD()
        TraceAI("STOP_CMD")
    elseif (msg[1] == ATTACK_OBJECT_CMD) then
        OnATTACK_OBJECT_CMD(msg[2])
        TraceAI("ATTACK_OBJECT_CMD")
    elseif (msg[1] == ATTACK_AREA_CMD) then
        OnATTACK_AREA_CMD(msg[2], msg[3])
        TraceAI("ATTACK_AREA_CMD")
    elseif (msg[1] == PATROL_CMD) then
        OnPATROL_CMD(msg[2], msg[3])
        TraceAI("PATROL_CMD")
    elseif (msg[1] == HOLD_CMD) then
        OnHOLD_CMD()
        TraceAI("HOLD_CMD")
    elseif (msg[1] == SKILL_OBJECT_CMD) then
        OnSKILL_OBJECT_CMD(msg[2], msg[3], msg[4], msg[5])
        TraceAI("SKILL_OBJECT_CMD")
    elseif (msg[1] == SKILL_AREA_CMD) then
        OnSKILL_AREA_CMD(msg[2], msg[3], msg[4], msg[5])
        TraceAI("SKILL_AREA_CMD")
    elseif (msg[1] == FOLLOW_CMD) then
        OnFOLLOW_CMD()
        TraceAI("FOLLOW_CMD")
    end
end

-------------- State Process  --------------------

function OnIDLE_ST()

    TraceAI("OnIDLE_ST")

    local cmd = List.popleft(ResCmdList)
    if (cmd ~= nil) then
        TraceAI("OnIDLE_ST CMD??")
        ProcessCommand(cmd) -- ¿¹¾à ¸í·É¾î Ã³¸® 
        return
    end

    DoHeal(IDLE_HEAL_THRESHOLD)

    local object = 0
    -- object = GetV(V_TARGET, MyID)
    -- if (object ~= 0 and 1 == IsMonster(object)) then
    --     MyState = CHASE_ST
    --     MyEnemy = object
    --     TraceAI("IDLE_ST -> CHASE_ST : TARGET MY FOCUS")
    --     return
    -- end

    object = GetV(V_TARGET, OwnerID)
    if (object ~= 0 and 1 == IsMonster(object)) then
        MyState = CHASE_ST
        MyEnemy = object
        TraceAI("IDLE_ST -> CHASE_ST : TARGET FOCUS")
        return
    end

    object = GetOwnerEnemy(MyID)
    if (object ~= 0) then -- MYOWNER_ATTACKED_IN
        MyState = CHASE_ST
        MyEnemy = object
        TraceAI("IDLE_ST -> CHASE_ST : MYOWNER_ATTACKED_IN")
        return
    end

    object = GetMyEnemy(MyID)
    if (object ~= 0) then -- ATTACKED_IN
        MyState = CHASE_ST
        MyEnemy = object
        TraceAI("IDLE_ST -> CHASE_ST : ATTACKED_IN")
        return
    end

    -- local OwnerMotion = GetV(V_MOTION, OwnerID)
    -- if (OwnerMotion == MOTION_CASTING) then -- Owner is casting but we dont have a target
    --     MyState = CHASE_ST
    --     MyEnemy = GetMyEnemy(MyID)
    --     TraceAI("IDLE_ST -> CHASE_ST : OWNER CASTING")
    --     return
    -- end

    local distance = GetDistanceFromOwner(MyID)
    if (distance > 6 or distance == -1) then -- MYOWNER_OUTSIGNT_IN
        MyState = FOLLOW_ST
        TraceAI("IDLE_ST -> FOLLOW_ST")
        return
    end

    -----------------------
    -- Test functions
    -----------------------
    -- if (OwnerMotion == MOTION_SIT) then
    --     -- Easy way to debug
    --     CircleAroundTarget(OwnerID)
    --     return
    -- end
end

function OnFOLLOW_ST()

    TraceAI("OnFOLLOW_ST")

    SwapIn = false

    local ownerX, ownerY, myX, myY
    ownerX, ownerY = GetV(V_POSITION, GetV(V_OWNER, MyID))
    myX, myY = GetV(V_POSITION, MyID)

    if (GetDistanceFromOwner(MyID) <= 7) then --  DESTINATION_ARRIVED_IN 
        MyState = IDLE_ST
        MY_TRYING_MOVE_TO_OWNER_TIMER = 0
        TraceAI("FOLLOW_ST -> IDLE_ST")
        return
    else -- if (GetV(V_MOTION, MyID) == MOTION_STAND) then
        if (MY_TRYING_MOVE_TO_OWNER_TIMER > 0) then
            local d = GetDistance(ownerX, ownerY, MyDestX, MyDestY)
            if (d > 3) then
                MoveToOwner(MyID)
                MyDestX = ownerX
                MyDestY = ownerY

                MY_TRYING_MOVE_TO_OWNER_TIMER = GetTick() + MOVE_TO_OWNER_ACTION_DELAY
                TraceAI("FOLLOW_ST -> FOLLOW_ST UPDATED")
                return
            end

            if (GetTick() < MY_TRYING_MOVE_TO_OWNER_TIMER) then
                return
            end
        end

        MoveToOwner(MyID)
        MyDestX = ownerX
        MyDestY = ownerY

        MY_TRYING_MOVE_TO_OWNER_TIMER = GetTick() + MOVE_TO_OWNER_ACTION_DELAY
        TraceAI("FOLLOW_ST -> FOLLOW_ST")
        return
    end

end

function OnCHASE_ST()

    TraceAI("OnCHASE_ST")

    -----------------------
    -- Warm Def
    -----------------------
    if (AUTO_WARM_DEF == 1) then
        if (true == DoWarmDef()) then
            return
        end
    end

    DoHeal(IDLE_HEAL_THRESHOLD)

    -- local dOwner = GetDistance2(OwnerID, MyID)
    -- if (dOwner > 15) then
    --     MyState = FOLLOW_ST
    --     MyEnemy = 0
    --     MyDestX, MyDestY = 0, 0
    --     TraceAI("CHASE_ST -> FOLLOW_ST : OWNER TOO FAR")
    --     return
    -- end

    local object = 0
    -- object = GetV(V_TARGET, MyID)
    -- if (object ~= 0 and MyEnemy ~= object and 1 == IsMonster(object)) then
    --     MyState = CHASE_ST
    --     MyEnemy = object
    --     TraceAI("CHASE_ST -> CHASE_ST : TARGET MY FOCUS")
    --     return
    -- end
    object = GetV(V_TARGET, OwnerID)
    if (object ~= 0 and MyEnemy ~= object and 1 == IsMonster(object)) then
        MyState = CHASE_ST
        MyEnemy = object
        TraceAI("CHASE_ST -> CHASE_ST : TARGET FOCUS")
        return
    end

    local d = GetDistance2(MyEnemy, MyID)
    local myPosX, myPosY = GetV(V_POSITION, MyID)
    if (MY_TRYING_MOVE_TIMER > 0 and MY_TRYING_MOVE_TIMER < GetTick() and MY_LAST_POS_X == myPosX and MY_LAST_POS_Y ==
        myPosY) then
        MY_TRYING_MOVE_TIMER = 0
        MyState = FOLLOW_ST
        MyEnemy = 0
        MyDestX, MyDestY = 0, 0
        TraceAI("CHASE_ST -> FOLLOW_ST : FAILED TO MOVE FOR TOO LONG " .. tostring(d))
        return
    end
    MY_LAST_POS_X, MY_LAST_POS_Y = myPosX, myPosY

    if (true == IsOutOfSight(MyID, MyEnemy)) then -- ENEMY_OUTSIGHT_IN
        MyState = IDLE_ST
        MyEnemy = 0
        MyDestX, MyDestY = 0, 0
        TraceAI("CHASE_ST -> IDLE_ST : ENEMY_OUTSIGHT_IN")
        return
    end

    if (true == IsInAttackSight(MyID, MyEnemy)) then -- ENEMY_INATTACKSIGHT_IN
        MyState = ATTACK_ST
        TraceAI("CHASE_ST -> ATTACK_ST : ENEMY_INATTACKSIGHT_IN")
        return
    end

    local x, y = GetV(V_POSITION_APPLY_SKILLATTACKRANGE, MyEnemy, MySkill, MySkillLevel)
    if (MyDestX ~= x or MyDestY ~= y) then -- DESTCHANGED_IN
        MyDestX, MyDestY = GetV(V_POSITION_APPLY_SKILLATTACKRANGE, MyEnemy, MySkill, MySkillLevel)
        Move(MyID, MyDestX, MyDestY)

        if (MY_TRYING_MOVE_TIMER == 0) then
            MY_TRYING_MOVE_TIMER = GetTick() + DROP_TARGET_IF_NOT_MOVING_FOR
        end

        TraceAI("CHASE_ST -> CHASE_ST : DESTCHANGED_IN (distance: " .. tostring(d) .. ")")
        return
    end

end

function OnATTACK_ST()

    TraceAI("OnATTACK_ST")

    -----------------------
    -- Warm Def
    -----------------------
    if (AUTO_WARM_DEF == 1) then
        if (true == DoWarmDef()) then
            return
        end
    end

    -----------------------
    -- Heal

    -----------------------
    -- TraceAI("ATTACK_ST -> HEAL CHECK")
    DoHeal(COMBAT_HEAL_THRESHOLD)
    -----------------------

    -- TraceAI("ATTACK_ST -> SET SKILL")
    SetSkill() -- Always use skill

    -- TraceAI("ATTACK_ST -> CHECK DEAD")
    if (MOTION_DEAD == GetV(V_MOTION, MyEnemy)) then -- ENEMY_DEAD_IN
        MyState = FOLLOW_ST
        TraceAI("ATTACK_ST -> IDLE_ST : ENEMY DEAD")
        return
    end

    -- local hp = GetV(V_HP, MyEnemy)
    -- TraceAI("ATTACK_ST -> IDLE_ST : ENEMY - HP " .. tostring(MyEnemy) .. " - " .. tostring(hp))

    -- TraceAI("ATTACK_ST -> CHECK OOS")
    if (true == IsOutOfSight(MyID, MyEnemy)) then -- ENEMY_OUTSIGHT_IN
        MyState = FOLLOW_ST
        TraceAI("ATTACK_ST -> IDLE_ST : ENEMY_OUTSIGHT_IN")
        return
    end

    -- TraceAI("ATTACK_ST -> CHECK INSIGHT")
    if (false == IsInAttackSight(MyID, MyEnemy)) then -- ENEMY_OUTATTACKSIGHT_IN
        MyState = CHASE_ST
        MyDestX, MyDestY = GetV(V_POSITION_APPLY_SKILLATTACKRANGE, MyEnemy, MySkill, MySkillLevel)
        Move(MyID, MyDestX, MyDestY)
        TraceAI("ATTACK_ST -> CHASE_ST  : ENEMY_OUTATTACKSIGHT_IN")
        return
    end
    -- TraceAI("ATTACK_ST -> AFTER CHECK INSIGHT")

    if (MySkill == 0) then -- If there is no skill selected, just auto attack
        Attack(MyID, MyEnemy)
        TraceAI("ATTACK_ST -> Melee Attack")
    else
        -- Cast Skill
        local HomunSP = GetV(V_SP, MyID)
        -- TraceAI("ATTACK_ST -> CASTING ATTACK SKILL " .. tostring(MySkill) .. " SP (" .. tostring(HomunSP) .. "/" ..
        --             tostring(ATTACK_SP) .. ")")
        if (HomunSP < ATTACK_SP) then
            Attack(MyID, MyEnemy)
            TraceAI("ATTACK_ST -> Melee Attack")
        else
            local castResult = DoSkill(MySkill, MySkillLevel, MyEnemy)
            if (castResult == true) then
                TraceAI("ATTACK_ST -> Used Attack spell")
            else
                MyEnemy = 0
            end
        end
        MySkill = 0
    end

    return

end

function OnMOVE_CMD_ST()

    TraceAI("OnMOVE_CMD_ST")

    local x, y = GetV(V_POSITION, MyID)
    if (x == MyDestX and y == MyDestY) then -- DESTINATION_ARRIVED_IN

        MyState = IDLE_ST

    end

end

function OnKite_CMD_ST() -- Custom

    TraceAI("OnKITE_CMD_ST")

    local x, y = GetV(V_POSITION, MyID)
    if (x == MyDestX and y == MyDestY) then -- DESTINATION_ARRIVED_IN

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

    local object = GetOwnerEnemy(MyID)
    if (object == 0) then
        object = GetMyEnemy(MyID)
    end

    if (object ~= 0) then -- MYOWNER_ATTACKED_IN or ATTACKED_IN
        MyState = CHASE_ST
        MyEnemy = object
        return
    end

    local x, y = GetV(V_POSITION, MyID)
    if (x == MyDestX and y == MyDestY) then -- DESTARRIVED_IN
        MyState = IDLE_ST
    end

end

function OnPATROL_CMD_ST()

    TraceAI("OnPATROL_CMD_ST")

    local object = GetOwnerEnemy(MyID)
    if (object == 0) then
        object = GetMyEnemy(MyID)
    end

    if (object ~= 0) then -- MYOWNER_ATTACKED_IN or ATTACKED_IN
        MyState = CHASE_ST
        MyEnemy = object
        TraceAI("PATROL_CMD_ST -> CHASE_ST : ATTACKED_IN")
        return
    end

    local x, y = GetV(V_POSITION, MyID)
    if (x == MyDestX and y == MyDestY) then -- DESTARRIVED_IN
        MyDestX = MyPatrolX
        MyDestY = MyPatrolY
        MyPatrolX = x
        MyPatrolY = y
        Move(MyID, MyDestX, MyDestY)
    end

end

function OnHOLD_CMD_ST()

    TraceAI("OnHOLD_CMD_ST")

    if (MyEnemy ~= 0) then
        local d = GetDistance2(MyEnemy, MyID)
        if (d ~= -1 and d <= GetV(V_ATTACKRANGE, MyID)) then
            Attack(MyID, MyEnemy)
        else
            MyEnemy = 0
        end
        return
    end

    local object = GetOwnerEnemy(MyID)
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

    local x, y = GetV(V_POSITION, MyID)
    if (GetDistance(x, y, MyDestX, MyDestY) <= GetV(V_SKILLATTACKRANGE_LEVEL, MyID, MySkill, MySkillLevel)) then -- DESTARRIVED_IN
        SkillGround(MyID, MySkillLevel, MySkill, MyDestX, MyDestY)
        MyState = IDLE_ST
        MySkill = 0
    end

end

function OnFOLLOW_CMD_ST()

    TraceAI("OnFOLLOW_CMD_ST")

    local ownerX, ownerY, myX, myY
    ownerX, ownerY = GetV(V_POSITION, GetV(V_OWNER, MyID)) -- ÁÖÀÎ
    myX, myY = GetV(V_POSITION, MyID) -- ³ª 

    local d = GetDistance(ownerX, ownerY, myX, myY)

    if (d <= 3) then -- 3¼¿ ÀÌÇÏ °Å¸®¸é 
        return
    end

    local motion = GetV(V_MOTION, MyID)
    if (motion == MOTION_MOVE) then -- ÀÌµ¿Áß
        d = GetDistance(ownerX, ownerY, MyDestX, MyDestY)
        if (d > 3) then -- ¸ñÀûÁö º¯°æ ?
            MoveToOwner(MyID)
            MyDestX = ownerX
            MyDestY = ownerY
            return
        end
    else -- ´Ù¸¥ µ¿ÀÛ 
        MoveToOwner(MyID)
        MyDestX = ownerX
        MyDestY = ownerY
        return
    end

end

function GetOwnerEnemy(myid)
    local result = 0
    local owner = GetV(V_OWNER, myid)
    local actors = GetActors()
    local enemys = {}
    local index = 1
    local target
    for i, v in ipairs(actors) do
        if (v ~= owner and v ~= myid) then
            target = GetV(V_TARGET, v)
            if (target == owner) then
                if (IsMonster(v) == 1) then
                    enemys[index] = v
                    index = index + 1
                else
                    local motion = GetV(V_MOTION, i)
                    if (motion == MOTION_ATTACK or motion == MOTION_ATTACK2 or motion == MOTION_CASTING or motion ==
                        MOTION_SKILL) then
                        enemys[index] = v
                        index = index + 1
                    end
                end
            end
        end
    end

    local min_dis = 50
    local dis
    for i, v in ipairs(enemys) do
        dis = GetDistance2(myid, v)
        if (dis < min_dis) then
            result = v
            min_dis = dis
        end
    end

    if (result ~= 0) then
        TraceAI("OWNER ATTACKED by " .. result .. " dist " .. dis)
    end
    return result
end

function OwnerIsCastTarget(myid) -- Custom function

    local result = 0
    local owner = GetV(V_OWNER, myid)
    local actors = GetActors()
    local target

    for i, v in ipairs(actors) do
        if (v ~= owner and v ~= myid) then -- If not owner or itself
            target = GetV(V_TARGET, v) -- Get target
            if (target == owner) then -- Targt is owner
                if (IsMonster(v) == 1) then -- Its a monster
                    local motion = GetV(V_MOTION, i) -- Get motion
                    if (motion == MOTION_CASTING or motion == MOTION_SKILL) then
                        result = v -- Owner is a skill target
                        return result
                    end
                end
            end
        end
    end

    return result

end

function GetMyEnemy(myid)

    local result = 0

    -- local type = GetV(V_HOMUNTYPE,myid)
    -- if (type == LIF or type == LIF_H or type == AMISTR or type == AMISTR_H or type == LIF2 or type == LIF_H2 or type == AMISTR2 or type == AMISTR_H2) then
    --	result = GetMyEnemyA(myid)
    -- elseif (type == FILIR or type == FILIR_H or type == VANILMIRTH or type == VANILMIRTH_H or type == FILIR2 or type == FILIR_H2 or type == VANILMIRTH2 or type == VANILMIRTH_H2) then
    --	result = GetMyEnemyB(myid)
    -- end

    if (AGGRO_MODE == 0) then
        result = GetMyEnemyA(myid)
    elseif (AGGRO_MODE == 1) then
        result = GetMyEnemyB(myid)
    end

    -- result = GetMyEnemyB(myid)

    return result
end

-------------------------------------------
--  Get nearest non agressive enemy
-------------------------------------------
function GetMyEnemyA(myid)
    local result = 0
    local owner = GetV(V_OWNER, myid)
    local actors = GetActors()
    local enemys = {}
    local index = 1
    local target
    for i, v in ipairs(actors) do
        if (v ~= owner and v ~= myid) then
            -- target = GetV(V_TARGET,v)
            -- (target == myid or target == owner) then
            enemys[index] = v
            index = index + 1
            -- end
        end
    end

    local min_dis = 100
    local dis
    for i, v in ipairs(enemys) do
        dis = GetDistance2(myid, v)
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
function GetMyEnemyB(myid)
    local result = 0
    local owner = GetV(V_OWNER, myid)
    local actors = GetActors()
    local enemys = {}
    local index = 1
    local type
    for i, v in ipairs(actors) do
        if (v ~= owner and v ~= myid) then
            if (1 == IsMonster(v)) then
                enemys[index] = v
                index = index + 1
            end
        end
    end

    local min_dis = 100
    local dis
    for i, v in ipairs(enemys) do
        dis = GetDistance2(myid, v)
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

function CanChaseEnemy(enemyid)

    -- Default to true
    local result = true

    -- Run conditions if cant chase

    -- if (GetDistance2(myid, enemyid) > MAX_AGGRO_RANGE) then
    --	result = false
    -- end

    if (true == IsOutOfSight(MyID, enemyid)) then -- ENEMY_OUTSIGHT_IN
        result = false
    end

    if (true == IsInAttackSight(MyID, enemyid)) then -- ENEMY_INATTACKSIGHT_IN
        result = true
    end

    return result

end

function AI(myid)

    MyID = myid
    local msg = GetMsg(myid) -- command
    local rmsg = GetResMsg(myid) -- reserved command

    if not Initialized then

        OwnerID = GetV(V_OWNER, MyID)
        KimiID = GetV(V_HOMUNTYPE, MyID)
        Initialized = true
        -- FriendList_Clear() Missing function

    end

    if msg[1] == NONE_CMD then
        if rmsg[1] ~= NONE_CMD then
            if List.size(ResCmdList) < 10 then
                List.pushright(ResCmdList, rmsg) -- ¿¹¾à ¸í·É ÀúÀå
            end
        end
    else
        List.clear(ResCmdList) -- »õ·Î¿î ¸í·ÉÀÌ ÀÔ·ÂµÇ¸é ¿¹¾à ¸í·ÉµéÀº »èÁ¦ÇÑ´Ù.  
        ProcessCommand(msg) -- ¸í·É¾î Ã³¸® 
    end

    -- »óÅÂ Ã³¸® 
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
    if x < min then
        return min
    end
    if x > max then
        return max
    end
    return x
end

function KiteTarget(TrgID)

    KiteState = true

    local x, y = Get_V(V_POSITION, MyID)
    local tx, ty = Get_V(V_POSITION, TrgID)
    local dirX, dirY

    dirX = Clamp(x - ex, -1, 1)
    dirY = Clamp(y - ey, -1, 1)

    Move(MyID, x + dirX, y + dirY)

end

function DoHeal(threshold)
    local HomunSP = GetV(V_SP, MyID)
    if (HomunSP <= HEAL_SP) then
        return
    end

    local HomunHP = GetV(V_HP, MyID)
    local HomunMaxHP = GetV(V_MAXHP, MyID)
    local HomunHPPerc = (HomunHP / HomunMaxHP) * 100

    local OwnerHP = GetV(V_HP, OwnerID)
    local OwnerMaxHP = GetV(V_MAXHP, OwnerID)
    local OwnerHPPerc = (OwnerHP / OwnerMaxHP) * 100

    if (OwnerHPPerc < threshold) or (HomunHPPerc < threshold) then
        TraceAI("Casting HeaL! OwnerHPPerc: " .. tostring(OwnerHPPerc) .. " HomunHPPerc: " .. tostring(HomunHPPerc))
        MyTaget = OwnerID
        SkillObject(MyID, HEAL_LVL, S_CHAOTIC_HEAL, OwnerID)
        return
    end
end

--------------------------------------------------
function CircleAroundTarget(TrgID)
    --------------------------------------------------

    -- Find closest corner

    local ox, oy = GetV(V_POSITION, TrgID) -- target position
    local x, y = GetV(V_POSITION, MyID) -- current position

    MyDestX = ox + AAI_CIRC_X[CircleDir]
    MyDestY = oy + AAI_CIRC_Y[CircleDir]

    -- Check if stuck, timeout and just try to go to next spot
    -- If stuck too many times idk maybe go to owner

    --------------- At destination -------------
    -- Not sure if there is RO jank, but previous if check used math, probaby dont need it
    -- if  (math.abs(MyDestX - x) < 1)
    -- and (math.abs(MyDestY - y) < 1) -- yes!
    if (x == MyDestX) and (y == MyDestY) then

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

    -- if Skill.Level == 0 then return false; end
    local CurrTime = GetTick()
    if CastDelayEnd > CurrTime then
        -- TraceAI("Casting too fast...")
        return false;
    end

    -- if Skill.Engaged then -- if the skill is already active (or in delay time), wait until it goes OFF
    -- if CurrTime > Skill.TimeOut then
    --	Skill.Engaged = false
    -- end
    -- else -- if the skill is OFF, activate it

    MySkill = Skill
    MySkillLevel = Level
    -- Skill.TimeOut = CurrTime + 300
    -- Skill.Engaged = true
    SkillObject(MyID, MySkillLevel, MySkill, Target)
    CastDelayEnd = CurrTime + 50

    MySkill = 0
    MySkillLevel = 0

    return true

end

function SetSkill()
    -- Todo -> GetSkill level
    if (AUTO_ATTACK_SKILL == 0) then
        return
    end

    if KimiID == KIMI_OCCULT then
        -- TraceAI("Setting skill to KIMI_OCCULT")
        MySkill = S_ILLUSION_OF_BREATH
        MySkillLevel = BREATH_LVL
    -- elseif KimiID == KIMI_WARD then
    --     -- TraceAI("Setting skill to KIMI_WARD")
    --     MySkill = S_ILLUSION_OF_BREATH
    --     MySkillLevel = CLAWS_LVL
    else -- All other Kimis
        -- TraceAI("Setting skill to KIMI_OTHER" .. KimiID)
        MySkill = S_ILLUSION_OF_CLAWS
        MySkillLevel = CLAWS_LVL
    end
end

function DoWarmDef()

    local result = false
    local CurrTime = GetTick()

    if WarmDefTimer > CurrTime then
        return result;
    end

    DoSkill(S_WARM_DEF, 5, MyID)
    WarmDefTimer = CurrTime + 12000 -- 12000 ms = 12 seconds
    result = true

    return result

end

function DoSwap() -- Not used currently

    local result = false

    if (OwnerIsCastTarget(MyID)) then

        DoSkill(S_MASTER_SWAP, 5, OwnerID)
        result = true

    end

    return result

end
