--replaces projectiles with other projectiles
--created by thefriendlyhacker
local usage = [====[
foe/projectile-swap
=====================
This script replaces newly created projectiles with other projectiles as defined below.  

IN PROGRESS

Arguments::

    -clear
        clear all registered triggers
    -itemType type
        trigger the command for items of this type
        examples:
            ITEM_GLOB
            ITEM_AMMO
    -itemSubtype subtype  (optional)
        trigger the commmand for items of this subtype
        examples:
            ITEM_AMMO_BOLTS

    -material mat (optional)
        trigger the commmand on items with the given material
        examples
            INORGANIC:IRON
            CREATURE_MAT:DWARF:BONE
    -contaminant mat (optional)
        trigger the command on items with a given material contaminant
        examples
            INORGANIC:IRON
            CREATURE_MAT:DWARF:BRAIN
            PLANT_MAT:MUSHROOM_HELMET_PLUMP:DRINK
    -itemType type
        trigger the command for items of this type
        examples:
            ITEM_GLOB
            ITEM_AMMO
    -itemSubtype subtype  (optional)
        trigger the commmand for items of this subtype
        examples:
            ITEM_AMMO_BOLTS

    -material mat
        replaces the projectile with one of the given material
        examples
            INORGANIC:IRON
            CREATURE_MAT:DWARF:BONE
    -contaminant mat (optional)
        trigger the command on items with a given material contaminant
        examples
            INORGANIC:IRON
            CREATURE_MAT:DWARF:BRAIN
            PLANT_MAT:MUSHROOM_HELMET_PLUMP:DRINK
    -ignoreTemp temp (optional)
        does not copy over temperature value. Optionally, may specify overriding temperature (instead of room temperature).
]====]
local eventful = require 'plugins.eventful'
local utils = require 'utils'

itemTriggers = itemTriggers or {}
materialTriggers = materialTriggers or {}
contaminantTriggers = contaminantTriggers or {}

eventful.enableEvent(eventful.eventType.UNIT_ATTACK,1) -- this event type is cheap, so checking every tick is fine
eventful.enableEvent(eventful.eventType.INVENTORY_CHANGE,5) -- this is expensive, but you might still want to set it lower
eventful.enableEvent(eventful.eventType.UNLOAD,1)

eventful.onUnload.itemTrigger = function()
 itemTriggers = {}
 materialTriggers = {}
 contaminantTriggers = {}
end

function processTrigger(command)
 local command2 = {}
 for i,arg in ipairs(command.command) do
  if arg == '\\ATTACKER_ID' then
   command2[i] = '' .. command.attacker.id
  elseif arg == '\\DEFENDER_ID' then
   command2[i] = '' .. command.defender.id
  elseif arg == '\\ITEM_MATERIAL' then
   command2[i] = command.itemMat:getToken()
  elseif arg == '\\ITEM_MATERIAL_TYPE' then
   command2[i] = command.itemMat['type']
  elseif arg == '\\ITEM_MATERIAL_INDEX' then
   command2[i] = command.itemMat.index
  elseif arg == '\\ITEM_ID' then
   command2[i] = '' .. command.item.id
  elseif arg == '\\ITEM_TYPE' then
   command2[i] = command.itemType
  elseif arg == '\\CONTAMINANT_MATERIAL' then
   command2[i] = command.contaminantMat:getToken()
  elseif arg == '\\CONTAMINANT_MATERIAL_TYPE' then
   command2[i] = command.contaminantMat['type']
  elseif arg == '\\CONTAMINANT_MATERIAL_INDEX' then
   command2[i] = command.contaminantMat.index
  elseif arg == '\\MODE' then
   command2[i] = command.mode
  elseif arg == '\\UNIT_ID' then
   command2[i] = command.unit.id
  elseif string.sub(arg,1,1) == '\\' then
   command2[i] = string.sub(arg,2)
  else
   command2[i] = arg
  end
 end
 dfhack.run_command(table.unpack(command2))
end

function getitemType(item)
 if item:getSubtype() ~= -1 and dfhack.items.getSubtypeDef(item:getType(),item:getSubtype()) then
  itemType = dfhack.items.getSubtypeDef(item:getType(),item:getSubtype()).id
 else
  itemType = df.item_type[item:getType()]
 end
 return itemType
end

function compareInvModes(reqMode,itemMode)
 if reqMode == nil then
  return
 end
 if not tonumber(reqMode) and df.unit_inventory_item.T_mode[itemMode] == tostring(reqMode) then
  return true
 elseif tonumber(reqMode) == itemMode then
  return true
 end
end

function checkMode(table,triggerArg)
 for _,command in ipairs(triggerArg) do
  if command[""..table.mode..""] then
   local reqModeType = command[""..table.mode..""]
   local modeType = tonumber(table.modeType)
   if #reqModeType == 1 then
    if compareInvModes(reqModeType,modeType) or compareInvModes(reqModeType[1],modeType) then
     utils.fillTable(command,table)
     processTrigger(command)
     utils.unfillTable(command,table)
    end
   elseif #reqModeType > 1 then
    for _,r in ipairs(reqModeType) do
     if compareInvModes(r,modeType) then
      utils.fillTable(command,table)
      processTrigger(command)
      utils.unfillTable(command,table)
     end
    end
   else
    utils.fillTable(command,table)
    processTrigger(command)
    utils.unfillTable(command,table)
   end
  end
 end
end

function handler(table)
 local itemMat = dfhack.matinfo.decode(table.item)
 local itemMatStr = itemMat:getToken()
 local itemType = getitemType(table.item)
 table.itemMat = itemMat
 table.itemType = itemType

 checkMode(table,(itemTriggers[itemType] or {}))
 checkMode(table,(materialTriggers[itemMatStr] or {}))

 for _,contaminant in ipairs(table.item.contaminants or {}) do
  local contaminantMat = dfhack.matinfo.decode(contaminant.mat_type, contaminant.mat_index)
  local contaminantStr = contaminantMat:getToken()
  table.contaminantMat = contaminantMat
  checkMode(table,(contaminantTriggers[contaminantStr] or {}))
  table.contaminantMat = nil
 end
end

function equipHandler(unit, item, mode, modeType)
 local table = {}
 table.mode = mode
 table.modeType = modeType
 table.item = df.item.find(item)
 table.unit = df.unit.find(unit)
 if table.item and table.unit then -- they must both be not nil or errors will occur after this point with instant reactions.
  handler(table)
 end
end

function modeHandler(unit, item, modeOld, modeNew)
 local mode
 local modeType
 if modeOld then
  mode = "onUnequip"
  modeType = modeOld
  equipHandler(unit, item, mode, modeType)
 end
 if modeNew then
  mode = "onEquip"
  modeType = modeNew
  equipHandler(unit, item, mode, modeType)
 end
end

eventful.onInventoryChange.equipmentTrigger = function(unit, item, item_old, item_new)
 local modeOld = (item_old and item_old.mode)
 local modeNew = (item_new and item_new.mode)
 if modeOld ~= modeNew then
  modeHandler(unit,item,modeOld,modeNew)
 end
end

eventful.onUnitAttack.attackTrigger = function(attacker,defender,wound)
 attacker = df.unit.find(attacker)
 defender = df.unit.find(defender)

 if not attacker then
  return
 end

 local attackerWeapon
 for _,item in ipairs(attacker.inventory) do
  if item.mode == df.unit_inventory_item.T_mode.Weapon then
   attackerWeapon = item.item
   break
  end
 end

 if not attackerWeapon then
  return
 end

 local table = {}
 table.attacker = attacker
 table.defender = defender
 table.item = attackerWeapon
 table.mode = 'onStrike'
 handler(table)
end

validArgs = validArgs or utils.invert({
 'clear',
 'help',
 'checkAttackEvery',
 'checkInventoryEvery',
 'command',
 'itemType',
 'onStrike',
 'onEquip',
 'onUnequip',
 'material',
 'contaminant',
})
local args = utils.processArgs({...}, validArgs)

if args.help then
 print(usage)
 return
end

if args.clear then
 itemTriggers = {}
 materialTriggers = {}
 contaminantTriggers = {}
end

if args.checkAttackEvery then
 if not tonumber(args.checkAttackEvery) then
  error('checkAttackEvery must be a number')
 end
 eventful.enableEvent(eventful.eventType.UNIT_ATTACK,tonumber(args.checkAttackEvery))
end

if args.checkInventoryEvery then
 if not tonumber(args.checkInventoryEvery) then
  error('checkInventoryEvery must be a number')
 end
 eventful.enableEvent(eventful.eventType.INVENTORY_CHANGE,tonumber(args.checkInventoryEvery))
end

if not args.command then
 if not args.clear then
  error 'specify a command'
 end
 return
end

if args.itemType and dfhack.items.findType(args.itemType) == -1 then
 local temp
 for _,itemdef in ipairs(df.global.world.raws.itemdefs.all) do
  if itemdef.id == args.itemType then
   temp = args.itemType--itemdef.subtype
   break
  end
 end
 if not temp then
  error 'Could not find item type.'
 end
 args.itemType = temp
end

local numConditions = (args.material and 1 or 0) + (args.itemType and 1 or 0) + (args.contaminant and 1 or 0)
if numConditions > 1 then
 error 'too many conditions defined: not (yet) supported (pester expwnent if you want it)'
elseif numConditions == 0 then
 error 'specify a material, weaponType, or contaminant'
end

if args.material then
 if not materialTriggers[args.material] then
  materialTriggers[args.material] = {}
 end
 table.insert(materialTriggers[args.material],args)
elseif args.itemType then
 if not itemTriggers[args.itemType] then
  itemTriggers[args.itemType] = {}
 end
 table.insert(itemTriggers[args.itemType],args)
elseif args.contaminant then
 if not contaminantTriggers[args.contaminant] then
  contaminantTriggers[args.contaminant] = {}
 end
 table.insert(contaminantTriggers[args.contaminant],args)
end

