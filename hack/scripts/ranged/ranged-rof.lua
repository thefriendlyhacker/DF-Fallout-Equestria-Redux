----changes the cooldown between each time a creature fires a projectile weapon----
--author thefriendlyhacker
--based on work by Roses, expwnent, zaporozhets and Putnam.

local usage = [====[

ranged/ranged-rof
===========================
This triggers when a unit fires a projectile, and changes the delay (in ticks) until the unit's
next attack.

The new delay is set according to the following formula:
    New Delay = Base Delay + Old Delay * Delay Multiplier
Base delay is set by -delayBase, and Delay Multiplier by -delayMult

For reference, dabbling firers have a normal delay of 80 ticks, legendary +5 firers 48 ticks, and legendary +100 firers 40 ticks.

Several arguments can be added to restrict a particular command to select weapons/ammo (see below)

A set of values can be passed through -delayBase and/or -delayMult.  When only one of the args is multi-value, the other is treated as an equal sized set of identical values.  If both are multi-value sets, they must be of equal length.

The script steps through the set of values when a unit fires a projectile weapon, and keeps track of
the unit's position in the set on a per command, per weapon basis. Beginning at the first
number in the set, the script iterates through the entire pair of sets, using each pair of numbers
to calculate the delay for a single firing event.  Effectively, this allows for variable delay
times.  This can simulate, for example, burst fire weapons, multi-barreled firearms, or autoloading
weapons with a reload time. 

After a delay (calculated using -resetBase and -resetMult similar to the equation above), the position in a unit's firing delay set is reset to the first position. 

Data does not persist across saves, which will mean that loading saves made in the middle of combat will influence that combat when using variable delays.  Outside of combat, this shouldn't matter.

Usage::
    -name str
        name of the command.  Not optional.  Must be unique.
    -clear name
        unregisters a named command.
    -reset name (not implemented atm)
        clears all persistant data associated with the named command. If used with no name, clears all data
    -reqProjType type or [ type1 type2 ... ]
        only runs command if the projectile is one of the appropriate types
        example: AMMO:ITEM_AMMO_BOLTS or GLOB:NONE
    -reqWeaponType type or [ type1 type2 ... ]
        only runs command if the weapon is of one of the appropriate types
        example: WEAPON:ITEM_WEAPON_CROSSBOW
    -reqProjMat mat or [ mat1 mat2 ... ]
        only runs command if the projectile is one of the appropriate material(s)
        examples: INORGANIC:IRON, CREATURE_MAT:DWARF:BRAIN
    -reqWeaponMat mat or [ mat1 mat2 ... ]
        only runs command if the weapon is one of the appropriate material(s) 
        same format as -reqProjMat 
    -timeBase nbr or [ nbr1 nbr2 ... ] (default 0)
        flat modifer to the unit's firing time, see above for details
    -timeMult nbr or [ nbr1 nbr2 ... ](default 0)
        multiplier to the unit's firing time, see above for details
    -neverReset
        never resets position in a loop
    -resetBase nbr (default 0)
    -resetMult nbr (default 5)
      determines how long until a unit's position in the command's firing delay set is reset 
      works similarly to timeBase and timeMult, see above for details
    -priority nbr (default 0)
      determines the order in which scripts are checked.  Order is undefined for scripts of equal priority
    -processSecondaries
      by default, ranged-rof ignores secondary projectiles 
      i.e. it only runs once per multi-shot burst spawned by other ranged-module scripts.
      this arg disables that behavior
    -allowMultTrigs
      by default, ranged-rof only runs once per projectile.  This arg disables that behavior
    -tags str or [ str1 str2 ... ]
      adds tags for the purpose of signaling other scripts using ranged-module
    -reqTags str or [ str1 str2 ... ]
      will only run when scripts with the associated tags have run on this projectile this tick of movement.
    -forbiddenTags str or [ str1 str2 ... ]
      will not run when scripts with the associated tags have run on this projectile this tick of movement.
]====]
eventful = require 'plugins.eventful'
utils = require 'utils'
rm= require 'ranged-module'
persist= require 'persist-table'

persist.GlobalTable.rangedRof=persist.GlobalTable.rangedRof or {}
local rangedRof=persist.GlobalTable.rangedRof

--3 dimension sparse table for command/creature/firing weapon combos, 
--holds the position of a unit in a command's delay set, on a per weapon basis
rangedRof.rangedArrayPos=rangedRof.rangedArrayPos or {}
rangedArrayPos=rangedRof.rangedArrayPos

--ticks until any particular unit/weapon pair's delay set pos is reset to the first element
rangedRof.rangedResetTimes=rangedRof.rangedResetTimes or {}


--if necessary, restart timers
if not rangedResetTimes then
  rangedResetTimes=rangedRof.rangedResetTimes
  for func,i in pairs(rangedResetTimes['_children']) do
    for unit,j in pairs(i['_children'] or {}) do
      for weapon,k in pairs(j['_children'] or {}) do
        createTimeout(func,unit,weapon)
      end
    end
  end
end

eventful.enableEvent(eventful.eventType.UNLOAD,1)
eventful.onUnload.rangedTriggerModule = function()
  rangedArrayPos = nil
  rangedResetTimes = nil
end

function createTimeout(func,unit_id,weapon_id,ticks)
  local func=tostring(func)
  local unit=tostring(unit_id)
  local weapon=tostring(weapon_id)
  if not ticks then ticks=rangedResetTimes[func][unit][weapon] end
  
  if rangedResetTimes[func]==nil then rangedResetTimes[func]= {} end
  if rangedResetTimes[func][unit]==nil then rangedResetTimes[func][unit] = {} end
  rangedResetTimes[func][unit][weapon]=tostring(ticks)
  function timeoutFunc()
    local curTicks=tonumber(rangedResetTimes[func][unit][weapon])
    curTicks=curTicks-1
    if curTicks>0 then
      createTimeout(func,unit,weapon,curTicks)
    else
      rangedArrayPos[func][unit][weapon]=nil
      if next(rangedArrayPos[func][unit]['_children'])==nil then rangedArrayPos[func][unit]=nil end
      if next(rangedArrayPos[func]['_children'])==nil then rangedArrayPos[func]=nil end 
      rangedResetTimes[func][unit][weapon]=nil
      if next(rangedResetTimes[func][unit]['_children'])==nil then rangedResetTimes[func][unit]=nil end
      if next(rangedResetTimes[func]['_children'])==nil then rangedResetTimes[func]=nil end 
    end
  end
  dfhack.timeout(1,'ticks',timeoutFunc)
end

function getCommandFunc(funcName,reqProjMats,reqProjTypes,reqWeaponMats,reqWeaponTypes, timeBase, timeMult, resetBase, resetMult, neverReset, processSecondaries, allowMultTrigs, scriptTags, reqTags, forbiddenTags)
  return function (proj,tags)
    if not proj.firer then return false end
    --dear god this is hacky but I don't know a nicer way of checking if the projectile is a unit or an item
    if not pcall(function() return proj.item end) then return false end
    if tags._secondaryProj and not processSecondaries then return end
    if tags._rof and allowMultTrigs then return end
    if reqTags then
      for tag,_ in pairs(reqTags) do
        if tags[tag]==nil then return end
      end 
    end
    if forbiddenTags then
      for tag,_ in pairs(forbiddenTags) do
        if tags[tag]~=nil then return end
      end
    end
    local weapon=df.item.find(proj.bow_id)
    local fid=tostring(proj.firer.id)
    local wid=tostring(proj.bow_id)

    
    if not weapon and (next(reqWeaponMats) or next(reqWeaponTypes)) then return false end

    --first off,checks to see if this conforms to the command requirements

    local found=false
    for _,mat in ipairs(reqProjMats) do
      if mat==dfhack.matinfo.decode(proj.item):getToken() then found=true end
    end
    if #reqProjMats>0 and not found then return false end
    
    found=false
    for _,mat in ipairs(reqWeaponMats) do
      if mat==dfhack.matinfo.decode(weapon):getToken() then found=true end
    end
    if #reqWeaponMats>0 and not found then return false end
    
    found=false
    for _,itype in ipairs(reqProjTypes) do
      if dfhack.items.findType(itype)==proj.item:getType() and dfhack.items.findSubtype(itype)==proj.item:getSubtype() then
        found=true 
      end
    end
    if #reqProjTypes>0 and not found then return false end
    
    
    found=false
    if #reqWeaponTypes>0 then
      for _,itype in ipairs(reqWeaponTypes) do
        if dfhack.items.findType(itype)==weapon:getType() and dfhack.items.findSubtype(itype)==weapon:getSubtype() then
          found=true 
        end
      end
    end 
    if #reqWeaponTypes>0 and not found then return false end
    
    --now the meaty bit - calculate and set the new think_counter time
    local oldThinkCounter=proj.firer.counters.think_counter
    if #timeBase>1 then
      --init rangedArrayPos if necessary
      if rangedArrayPos[funcName]==nil then rangedArrayPos[funcName]={} end
      if rangedArrayPos[funcName][fid]==nil then rangedArrayPos[funcName][fid]={} end
      if rangedArrayPos[funcName][fid][wid]==nil then rangedArrayPos[funcName][fid][wid]=tostring(1) end
      local arrayPos=tonumber(rangedArrayPos[funcName][fid][wid])
      proj.firer.counters.think_counter=math.max(1,math.floor(oldThinkCounter*timeMult[arrayPos]+timeBase[arrayPos]))
    else
      proj.firer.counters.think_counter=math.max(1,math.floor(oldThinkCounter*timeMult[1]+timeBase[1]))
    end
    
    -- set/reset the delay trigger  
    if #timeBase>1 then
      if not neverReset then
        local delayTime=math.max(1,math.floor(oldThinkCounter*resetMult+resetBase))
        if rangedResetTimes[funcName] and rangedResetTimes[funcName][fid] and rangedResetTimes[funcName][fid][wid] then
          rangedResetTimes[funcName][fid][wid]=tostring(delayTime)
        else
          createTimeout(funcName,proj.firer.id,proj.bow_id,delayTime)
        end
      end
    end

    --iterate through the array of firing times
    if #timeBase>1 then
      --increment and loop back
      rangedArrayPos[funcName][fid][wid]=tostring(tonumber(rangedArrayPos[funcName][fid][wid])+1)
      if tonumber(rangedArrayPos[funcName][fid][wid])>#timeBase then
        rangedArrayPos[funcName][fid][wid]=tostring(1)
      end
    end
    returnTags={["_rof"]=true}
    if scriptTags then for i,j in pairs(scriptTags) do returnTags[i]=j end end
    return returnTags
    
  end
  
end
 
local validArgs = utils.invert({
 'help',
 'clear',
 'reset',
 'name',
 'reqProjMat',
 'reqProjType',
 'reqWeaponMat',
 'reqWeaponType',
 'timeBase',
 'timeMult',
 'neverReset',
 'delayBase',
 'delayMult',
 'priority',
 'processSecondaries',
 'allowMultTrigs',
 'tags',
 'reqTags',
 'forbiddenTags'
 
})

if moduleMode then return end

local args = utils.processArgs({...}, validArgs)

if args.help then
 print(usage)
 return
end

if args.clear then
  if args.name then
    rm.deregisterMoveTrigger(args.name)
  else
    error("must have name to clear")
  end
end

if args.reset then
  return --todo
end

local reqProjMats={}
local reqProjTypes={}
local reqWeaponMats={}
local reqWeaponTypes={}
local timeBase={0}
local timeMult={0}
local resetBase=0
local resetMult=5
local neverReset=false
local priority=0
local processSecondaries=false
local allowMultTrigs=false
local tags=nil
local reqTags=nil
local forbiddenTags=nil

if type(args.reqProjMat)=='string' then
  reqProjMats={args.reqProjMat}
elseif type(args.reqProjMat)=='table' then
  reqProjMats=args.reqProjMat
end
if type(args.reqProjType)=='string' then
  reqProjTypes={args.reqProjType}
elseif type(args.reqProjType)=='table' then
  reqProjTypes=args.reqProjType
end
if type(args.reqWeaponMat)=='string' then
  reqWeaponMats={args.reqWeaponMat}
elseif type(args.reqWeaponMat)=='table' then
  reqWeaponMats=args.reqWeaponsMat
end
if type(args.reqWeaponType)=='string' then
  reqWeaponTypes={args.reqWeaponType}
elseif type(args.reqWeaponType)=='table' then
  reqWeaponTypes=args.reqWeaponType
end


if (not args.timeBase) and (not args.timeMult) then
  error("-timeBase or -timeMult must be defined")
end

if args.timeBase and type(args.timeBase)=='string' then
  timeBase={args.timeBase}
elseif args.timeBase then
  timeBase=args.timeBase
end

if args.timeMult and type(args.timeMult)=='string' then
  timeMult={args.timeMult}
elseif args.timeMult then
  timeMult=args.timeMult  
end


for i,numb in ipairs(timeBase) do
  timeBase[i]=tonumber(numb)
  if not timeBase[i] then 
    error("all elements of timeBase must be numbers") 
  end
end

for i,numb in ipairs(timeMult) do
  timeMult[i]=tonumber(numb)
  if not timeMult[i] then 
    error("all elements of timeMult must be numbers") 
  end
end

if #timeBase>1 and #timeMult>1 and #timeBase~=#timeMult then
  error("-timeBase and -timeMult must be the same length when they are both tables")
end

if #timeBase>1 and #timeMult==1 then
  for i=#timeMult+1,#timeBase do
    timeMult[i]=timeMult[1]
  end
end

if #timeMult>1 and #timeBase==1 then
  for i=#timeBase+1,#timeMult do
    timeBase[i]=timeBase[1]
  end
end

if args.resetBase then
  resetBase=tonumber(args.resetBase)
  if not resetBase then error("resetBase must be a number") end
end

if args.resetMult then
  resetMult=tonumber(args.resetMult)
  if not resetMult then error("resetMult must be a number") end
end

if args.neverReset then
  neverReset=true
end

if not args.name then error("-name must be specified") end

if args.priority then
  if tonumber(args.priority) then
    priority=tonumber(args.priority)
  else
    error("priority must be a number")
  end
end

if args.processSecondaries then processSecondaries=true end
if args.allowMultTrigs then allowMultTrigs=true end

if args.tags and type(args.tags)=='table' then
  for _,tag in pairs(args.tags) do
    tags[tag]=true
  end
elseif args.tags then
  tags[args.tags]=true
end

if args.reqTags and type(args.reqTags)=='table' then
  reqTags={}
  for _,tag in pairs(args.reqTags) do
    reqTags[tag]=true
  end
elseif args.reqTags then
  reqTags={}
  reqTags[args.reqTags]=true
end

if args.forbiddenTags and type(args.forbiddenTags)=='table' then
  forbiddenTags={}
  for _,tag in pairs(args.forbiddenTags) do
    forbiddenTags[tag]=true
  end
elseif args.forbiddenTags then
  forbiddenTags={}
  forbiddenTags[args.forbiddenTags]=true
end


rm.registerFiringTrigger(args.name, priority, getCommandFunc(args.name, reqProjMats,reqProjTypes,reqWeaponMats,reqWeaponTypes, timeBase, timeMult, resetBase, resetMult, neverReset,processSecondaries,allowMultTrigs,tags,reqTags,forbiddenTags))
