# Return to Morroc - Homunculus (Kimi) AI
Homunculus(Kimi) AI for Return to Morroc, made in Lua programming language.
<br>

## How to "install"
- Make back up of **AI.lua** inside ReturnToMorroc/**AI_sakray/USER_AI**
- Replace **AI.lua** in ReturnToMorroc/**AI_sakray/USER_AI** with **AI.lua** file from repo
- _(optional)_ Configure the ai by editing '**Quick Config**' values at the start of the file
- Ingame type **/hoai** to between default and custom AI

```
AGGRO_MODE              = 1     -- 0 = Passive, 1 = Agressive
IDLE_HEAL_THRESHOLD     = 90    -- % of Owner / Kimi HP when to spam Heal out of combat
COMBAT_HEAL_THRESHOLD   = 50    -- % of Owner / Kimi HP when to spam Heal during combat
WARM_DEF_MONSTERS       = 3     -- Number of monsters required to auto Warm Defence (not used yet)
```
<br>

## How to customize
The AI uses a state machine to decide what course of action it should take, the states are defined at the start of the file and should not be modified. <br>
Adding custom states is possible but it's unknown if you can actually call them without issues. (see KITE_CMD_ST) <br>
There are Command- and State Processes, some base logic happens inside Command Process, but most of the logic should happen inside State Process. <br>
If your Kimi stops working, you probably made a mistake in the code while adding or changing something. Take extra caution in syntax and work on one thing at a time! <br><br>

**Example**<br>
We can modify **function	OnIDLE_ST()** to do more stuff while idle (Owner is standing, out of combat). <br>
Use **GetV(V_MOTION, OwnerID)** to get the current motion of the owner and store it. <br>
Then compare it to specific motion, in this case **MOTION_SIT** to know if the owner is sitting. <br>
If the condition is true, we can do something and call return to not execute any code bellow <br>
```
function	OnIDLE_ST()

  -- Do stuff!
	local OwnerMotion = GetV(V_MOTION, OwnerID)

	if (OwnerMotion == MOTION_SIT) then

		CircleAroundTarget(OwnerID) -- Custom function
		return -- Don't execute anything after this

	end

end
```

**CircleAroundTarget(TrgID)** is a custom function and has some predefined variables at the top of the file called **AAI_CIRC_X**, **AAI_CIRC_Y** and **CircleDir**
```
function CircleAroundTarget(TrgID)

	local ox, oy	= GetV(V_POSITION, TrgID) -- target position
	local x, y		= GetV(V_POSITION, MyID) -- current position

	MyDestX = ox + AAI_CIRC_X[CircleDir]
	MyDestY = oy + AAI_CIRC_Y[CircleDir]

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
```

## Documentation / Sources
http://winter.sgv417.jp/alchemy/download/official/AI_manual_en.html
<br>
https://irowiki.org/wiki/Homunculus_System
<br>

## Contact
Can contact discord user 'asfaras' for questions and feature requests.
