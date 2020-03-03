----changes the cooldown between each time a creature fires a projectile weapon----
--author thefriendlyhacker
--based on work by Roses, expwnent, zaporozhets and Putnam.

local usage = [====[

foe/random-tlcm
===========================
This randomizes a selected tissue layer's color across all units to which it applies.  Only works on Historical Figures.


Usage::
    -name str
        name of the command.  Not optional.
    -tissueName tissue or [ tissue1 tissue2 ... ]
        randomize all tissue layer colors with the given name(s)
]====]
eventful = require 'plugins.eventful'
utils = require 'utils'


eventful.enableEvent(eventful.eventType.UNLOAD,1)
eventful.onUnload.randomTLCM = function()
timeoutID=nil
checkedCreatures=nil
tissues=nil
end

tissues=tissues or {}

--load and init persistant table elements
local persist= require 'persist-table'



persist.GlobalTable.randomTLCM=persist.GlobalTable.randomTLCM or {}
rTLCM= persist.GlobalTable.randomTLCM

checkedCreatures=checkedCreatures or {}

function checkColorMod(unit,tlcmName)
  rTLCM[tlcmName]=rTLCM[tlcmName] or {}--The persistent table is either getting cleared or bugging out for some reason. This is a hacky workaround
  if rTLCM[tlcmName][tostring(unit.id)]~=nil then return end
  local changed=false
  for i,v in ipairs(df.creature_raw.find(unit.race).caste[unit.caste].color_modifiers) do
    if v.part==tlcmName and #(v.pattern_frequency)>1 then 
      changed=true
      rTLCM[tlcmName][tostring(unit.id)]='true'
      local totalWeight=0
      for _,vf in ipairs(v.pattern_frequency) do
        totalWeight=totalWeight+vf
      end
      currentWeight=0
      colorWeight=math.random(0,totalWeight)
      for col,vf in ipairs(v.pattern_frequency) do
        currentWeight=currentWeight+vf
        if currentWeight>=colorWeight then unit.appearance.colors[i]=col break end
      end
    end
  end
end

function timeoutFunc()
  timeoutID=dfhack.timeout(1,'ticks',timeoutFunc)
  for _,unit in ipairs(df.global.world.units.active) do
    if not checkedCreatures[unit.id] then
      checkedCreatures[unit.id]=true
      for _,tissue in pairs(tissues) do
        checkColorMod(unit,tissue)
      end 
    end
  end
end


if not timeoutID then timeoutID=dfhack.timeout(1,'ticks',timeoutFunc) end

 
local validArgs = utils.invert({
 'help',
 'clear',
 'reset',
 'name',
 'tissueName'
})

if moduleMode then return end

local args = utils.processArgs({...}, validArgs)

if args.help then
 print(usage)
 return
end

if args.clear then
  return --todo
end

if args.reset then
  return --todo
end

local tissueName=args.tissueName

if not args.name then error("-name must be specified") end

if not args.tissueName then error("-tissueName must be specified") end

tissues[args.name]=args.tissueName
rTLCM[args.tissueName]=rTLCM[args.tissueName] or {}