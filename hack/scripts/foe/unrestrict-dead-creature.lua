-- sets the dead_dwarf flag of all newly created items of a specific type to false
--written by thefriendlyhacker, code from transform-unit by expwnent, Putnam
local usage = [====[

foe/unrestrict-dead-creature
=====================
This script automatically sets the dead-dwarf flag of a type of item to false, allowing it to be butchered
can be used to permit cannibalization of sapiant species or the butchery of non-slaughtered pets, among other things

Arguments::
    -listItemTypes
        lists all types of objects in Dwarf Fortress(but not subtypes)
    -itemType type or [ type1 type2 ... ]
        specifies the type and optionally subtype of the item to deflag as dead-dwarf (TYPE:SUBTYPE)
        e.g. WEAPON:ITEM_WEAPON_PICK or [ CORPSE CORPSEPIECE ]
    -creatureType name or [ name1 name2 ... ]
        if a corpse or corpse piece, defines what kind of creature (and optionally, caste) is required
        e.g. DWARF or [ ANT_MAN:QUEEN ANT_MAN:DRONE ]
    -creatureClass class or [ class1 class2 ... ]
        if a corpse or corpse piece, defines which creature classes the source creature must have at least one of
        e.g. GENERAL_POISON or [ MAMMAL POISONOUS ] 
]====]
local utils = require 'utils'
local eventful = require 'plugins.eventful'

registrations = registrations or {}
itemArrayPosition=itemArrayPosition or 0

eventful.enableEvent(eventful.eventType.UNLOAD,1)
eventful.onUnload.reactionProductTrigger = function()
 registrations = {}
 itemArrayPosition=0
end


function checkLoop()
  dfhack.timeout(1,'ticks',checkLoop)
  for i=itemArrayPosition,#df.global.world.items.all-1 do
    item=df.global.world.items.all[i]
    if item.flags.dead_dwarf then
      for _,entry in ipairs(registrations) do
        if checkItem(item,entry.reqItemTypes,entry.reqCreatures,entry.reqCreatureClasses) then
          item.flags.dead_dwarf=false
        end
      end
    end
  end
  itemArrayPosition=#df.global.world.items.all
end

if (not timeoutID) or (not dfhack.timeoutActive(timeoutID)) then
  itemIDPosition=0
  checkLoop()
end 

--[[function getItemTypeID(itemTypeString)
  itemType,_=string.gsub(itemTypeString,":.*","")
  return df.item_type[itemType]
end
function getItemSubtypeID(itemTypeString)
  itemTypeID,hasSubtype=getItemTypeID()
end]]--

--stub atm - loop called on each function run


function checkItem(item,reqItemTypes,reqCreatures,reqCreatureClasses)
  if reqItemTypes then
    local found=false
    for i,j in ipairs(reqItemTypes) do
      if item:getType()==j.itemType then
        if (j.subtype==-1) or (item:getSubtype()==j.subtype) then
          found=true
          break
        end
      end
    end
    if not found then return false end
  end
  if (item:getType()==df.item_type.CORPSE) or (item:getType()==df.item_type.CORPSEPIECE) then
    if reqCreatures then
      local found=false
      for i,j in ipairs(reqCreatures) do
        if item.race2==j.race then
          if (j.caste==-1) or (item.caste2==j.caste) then 
            found=true
            break
          end
        end
      end
      if not found then return false end
    end
    if reqCreatureClasses then
      local found=false
      for i,j in ipairs(reqCreatureClasses) do
        for u,v in ipairs(df.global.world.raws.creatures.all[item.race2].caste[item.caste2].creature_class) do
          --caste class strings are contained in their own 1 element vectors for some reason. Don't ask me.
          if j==v[0] then
            found=true
            break
          end
        end
      end
      if not found then return false end
    end
  end
  return true
end


validArgs = validArgs or utils.invert({
 'creatureType',
 'itemType',
 'creatureClass',
 'help',
 'listItemTypes'
})

local args = utils.processArgs({...}, validArgs)


if args.help then
  print(usage)
  return
end

if args.listItemTypes then
  for _,i in ipairs(df.item_type) do
    print(i)
  end
  return
end

if not args.type then
  reqItemTypes=nil
else
  reqItemTypes={}
  if type(args.type)=='string' then
    args.type={args.type}
  end
  for i,j in ipairs(args.type) do
    if dfhack.items.findType(j)==-1 then
      error(j.." - type does not exist.")
    end
    reqItemTypes[i]={}
    reqItemTypes[i].itemType=dfhack.items.findType(j)
    if not string.find(j,":") then
      reqItemTypes[i].subtype=-1
    else
      if dfhack.items.findSubype(j)==-1 then
        error(j.." - subtype does not exist.")
      end
      reqItemTypes[i].subtype=dfhack.items.findSubtype(j)
    end
  end
end


if not args.creatureType then
  reqCreatures=nil
else
  reqCreatures={}
  if type(args.creatureType)=='string' then
    args.creatureType={args.creatureType}
  end
  for i,j in ipairs(args.creatureType) do
    if not string.find(j,":") then
      raceString=j
      casteString=nil
    else
      raceString=string.sub(j,1,string.find(j,":")-1)
      casteString=string.sub(j,string.find(j,":")+1,-1)
    end
    for u,v in ipairs(df.global.world.raws.creatures.all) do
      if v.creature_id == raceString then
        raceIndex = u
        race = v
        break
      end
    end
    if not raceIndex then
      error (j..' - race does not exist')
    end
    reqCreatures[i]={}
    reqCreatures[i].race=raceIndex
    if not casteString then
      reqCreatures[i].caste=-1
    else  
      for u,v in ipairs(race.caste) do
        if v.caste_id == casteString then
          casteIndex = u
          break
        end
      end
      if not casteIndex then
        error(j.." - caste does not exist.")
      end
      reqCreatures[i].caste=casteIndex
    end
  end
end
if args.creatureClass then
  if type(args.creatureClass)=='string' then
    args.creatureClass={args.creatureClass}
  end
  reqCreatureClasses=args.creatureClass
end
entry={reqItemTypes=reqItemTypes,reqCreatures=reqCreatures,reqCreatureClasses=reqCreatureClasses}
table.insert(registrations,entry)