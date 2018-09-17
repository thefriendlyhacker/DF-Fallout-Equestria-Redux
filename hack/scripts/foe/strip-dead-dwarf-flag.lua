-- on execution, sets the dead_dwarf flag of an item to false
--written by thefriendlyhacker
local usage = [====[

foe/strip-dead-dwarf-flag
=====================
This script sets the dead-dwarf flag of an item to false

Arguments::

    -item id
        specifies the item to be altered
]====]
local utils = require 'utils'

validArgs = validArgs or utils.invert({
 'item',
 'help',
})
local args = utils.processArgs({...}, validArgs)


if args.help then
 print(usage)
 return
end
local id=tonumber(args.item)

item=df.item.find(id)

item.flags.dead_dwarf=false
