--on execution, changes the maker race of an item (sizing it for that race),
--written by thefriendlyhacker, 
--parts ripped off the create-item script by expwnent, and the create-unit script by warmist, Boltgun, Dirst, Expwnent, lethosor, mifki, Putnam and Atomic Chicken.
local usage = [====[

foe/strip-dead-dwarf-flag
=====================
This script sets the dead-dwarf flag of an item to false

Arguments::

    -item id
        specifies the item to be altered
    -race creature_name
	    specifies the creature race the item is to be resized to.
    -material material_string
        Optional.  Changes the item to the specified material.
]====]
local utils = require 'utils'

validArgs = validArgs or utils.invert({
 'item',
 'help',
 'race',
 'material'
})
local args = utils.processArgs({...}, validArgs)


if args.help then
 print(usage)
 return
end


local id=tonumber(args.item)
if not id  then
  error("No item ID provided")
end
local item=df.item.find(id)

if not item then
  error("Cannot find item with ID:"..args.item)
end

local material
if args.material then 
  material=dfhack.matinfo.find(args.material)
  if not material then
    error ('Invalid material:'..args.material)
  end
end


if not args.race then
  error ("no race given")
end

local raceIndex
for i,v in ipairs(df.global.world.raws.creatures.all) do
  if v.creature_id == args.race then
    raceIndex = i
    break
  end
end

if not raceIndex then
  qerror('Invalid race: '..args.race)
end

item.maker_race=raceIndex

if material then
  item.mat_type=material.type
  item.mat_index=material.index
end
