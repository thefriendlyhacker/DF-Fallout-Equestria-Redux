----changes the cooldown between each time a creature fires a projectile weapon----
--author thefriendlyhacker
--based on work by Roses, expwnent, zaporozhets and Putnam.

local usage = [====[

ranged/ranged-multishot
===========================
This triggers when a unit fires a projectile, and creates extra projectiles.


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
        example: AMMO:ITEM_AMMO_BOLTS,
    -reqProjType type or [ type1 type2 ... ]
        only runs command if the projectile is one of the appropriate subtypes
        example: AMMO:ITEM_AMMO_BOLTS
    -reqWeaponType subtype or [ subtype1 subtype2 ... ]
        only runs command if the weapon is of one of the appropriate subtypes
        example: ITEM_WEAPON_CROSSBOW
    -reqProjMat mat or [ mat1 mat2 ... ]
        only runs command if the projectile is one of the appropriate material(s)
        examples: INORGANIC:IRON, CREATURE_MAT:DWARF:BRAIN
    -reqWeaponMat mat or [ mat1 mat2 ... ]
        only runs command if the weapon is one of the appropriate material(s) 
        same format as -reqProjMat 
    -newProjMat mat or [ mat1 mat2 ... ]
      material of the new projectile(s). Same format as above. Defaults to the same mat as the old one.
      if multiple mats are specified, uses the mat in the position corresponding to the matching mat from -reqProjMat 
    -newProjType type or [ type1 type2 ... ]
      type of the new projectile(s). Same format as above. Defaults to the same type as the old one.
      if multiple types are specified, uses the type in the position corresponding to the matching type from -reqProjType
    -newProjNbr nbr (default 1)
      number of projectiles to be spawned.  Must be integer above 0
    -divergence nbr (default 0)
      accuracty of the projectile. Must be non-negative number. Greater is more inaccurate.
      number corresponds to the maximum change in destination tile pos for a projectile heading towards a position 20 tiles away
      effectively, spawned projectiles head towards a tile somewhere in a nbr radius circle around the original destination pos
    -dontReplaceProj
      by default, deletes the original projectile and uses one of the new items as the primary projectile.  This disables that behavior. 
    -priority nbr (default 0)
      determines the order in which scripts are checked.  Order is undefined for scripts of equal priority
    -processSecondaries
      by default, ranged-multishot ignores secondary projectiles i.e. it only runs once per multi-shot burst
      this arg disables that behavior
    -allowMultTrigs
      by default, ranged-multishot only runs once per projectile.  This arg disables that behavior
    -tags str or [ str1 str2 ... ]
      adds tags for the purpose of signaling other scripts using ranged-module
    -reqTags str or [ str1 str2 ... ]
      will only run when scripts with the associated tags have run on this projectile this tick of movement.
    -forbiddenTags str or [ str1 str2 ... ]
      will not run when scripts with the associated tags have run on this projectile this tick of movement.
]====]
utils = require 'utils'
rm= require 'ranged-module'

function getCommandFunc(funcName,reqProjMats,reqProjTypes,reqWeaponMats,reqWeaponTypes, newProjMats, newProjTypes, newProjNbr, divergence, dontReplaceProj, processSecondaries, allowMultTrigs, scriptTags, reqTags, forbiddenTags)
  return function (proj,tags)
    if not proj.firer then return false end
    if tags._secondaryProj and not processSecondaries then return end
    if tags._rof and allowMultTrigs then return end
    if reqTags then
      for tag,_ in reqTags do
        if tags[tag]==nil then return end
      end 
    end
    if forbiddenTags then
      for tag,_ in forbiddenTags do
        if tags[tag]~=nil then return end
      end
    end
    if not allowMultTrigs and tags._multishot then return end
    scriptTags._multishot=true
    local weapon=df.item.find(proj.bow_id)
    local fid=tostring(proj.firer.id)
    local wid=tostring(proj.bow_id)
    --dismembered limbs require this
    print("test2")
    
    if not weapon and (next(reqWeaponMats) or next(reqWeaponTypes)) then return false end

    local projType,projSubtype,projMatType,projMatIndex=proj.item:getType(),proj.item:getSubtype(),proj.item.mat_type,proj.item.mat_index

    --first off,checks to see if this conforms to the command requirements
    local found=false
    for i,mat in ipairs(reqProjMats) do
      if mat==dfhack.matinfo.decode(proj.item):getToken() then 
        found=true
        if #newProjTypes>0 then
          projMatType=dfhack.matinfo.find(newProjMats[i])['type']
          projMatIndex=dfhack.matinfo.find(newProjMats[i])['index']
        end
      end
    end
    if #reqProjMats>0 and not found then return false end
    
    print("test3")
    found=false
    for _,mat in ipairs(reqWeaponMats) do
      if mat==dfhack.matinfo.decode(weapon):getToken() then found=true end
    end
    if #reqWeaponMats>0 and not found then return false end
    
    found=false
    for i,itype in ipairs(reqProjTypes) do
      if dfhack.items.findType(itype)==proj.item:getType() and dfhack.items.findSubtype(itype)==proj.item:getSubtype() then
        found=true 
        if #newProjTypes>0 then
          projType=dfhack.items.findType(newProjTypes[i])
          projSubtype=dfhack.items.findSubtype(newProjTypes[i])
        end
      end
    end
    if #reqProjTypes>0 and not found then return false end
    
    print("test4")
    found=false
    if #reqWeaponTypes>0 then
      for _,itype in ipairs(reqWeaponTypes) do
        if dfhack.items.findType(itype)==weapon:getType() and dfhack.items.findSubtype(itype)==weapon:getSubtype() then
          found=true 
        end
      end
    end 
    if #reqWeaponTypes>0 and not found then return false end
    
    print("test5")
    local newProjs={}
    local dist, maxDiv
    dist=math.sqrt((proj.origin_pos.x-proj.target_pos.x)^2+(proj.origin_pos.y-proj.target_pos.y)^2+(proj.origin_pos.z-proj.target_pos.z)^2)
    maxDiv=dist/20*divergence
    print("test newProjNbr=",newProjNbr)
    --now the meaty bit - create new projectiles and delete the old one if necessary
    for i = 1, newProjNbr do
      local randAngle, randDist = math.random()*2*math.pi,math.random()*maxDiv
    --for some silly reason lua has no round func, so we are doing a trick with math.ceil to duplicate it
      local targetX,targetY= math.ceil(math.cos(randAngle)*randDist+0.5)-1,math.ceil(math.sin(randAngle)*randDist+0.5)-1
      local newProj,newProjItem=rm.createProjectile(proj,projType,projSubtype,projMatType,projMatIndex,proj.firer)
      newProj.target_pos.x = newProj.target_pos.x + targetX
      newProj.target_pos.y = newProj.target_pos.y + targetY
      table.insert(newProjs,newProj)
    end
    local results={}
    results.secondaryProjectiles=newProj
    results.processSecondaries=true
    results.tags=scriptTags
    if not dontReplaceProj then
      results.proj=table.remove(newProjs)
      proj.flags.to_be_deleted=true
    end
    return results
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
 'newProjMat',
 'newProjType',
 'newProjNbr',
 'divergence',
 'dontReplaceProj',
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
local newProjMats={}
local newProjTypes={}
local newProjNbr=1
local divergence=0
local dontReplaceProj=false
local priority=0
local processSecondaries=false
local allowMultTrigs=false
local tags={}
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



if not args.name then error("-name must be specified") end

if type(args.newProjMat)=='string' then
  newProjMats={args.newProjMat}
elseif type(args.newProjMat)=='table' then
  newProjMats=args.newProjMat
end
if type(args.newProjType)=='string' then
  newProjTypes={args.newProjType}
elseif type(args.newProjType)=='table' then
  newProjTypes=args.newProjType
end

if args.newProjNbr then
  if tonumber(args.newProjNbr) and tonumber(args.newProjNbr)>=1 then
    newProjNbr=tonumber(args.newProjNbr)
  else
    error("arg 'newProjNbr' must be an integer greater than 0")
  end
end 

if #reqProjTypes>1 and #newProjTypes>1 and #reqProjTypes~=#notProjTypes then
  error("if reqProjType and newProjType are multi-element, they must have an equal number of elements")
end

if #reqProjMats>1 and #newProjMats>1 and #reqProjMats~=#notProjMats then
  error("if reqProjMat and newProjMat are multi-element, they must have an equal number of elements")
end


if #reqProjTypes>1 and #newProjTypes==1 then
  for i,j in pairs(reqProjTypes) do
    newProjTypes[i]=next(newProjTypes)
  end
end

if #reqProjTypes==1 and #newProjTypes>1 then
  for i,j in pairs(newProjTypes) do
    reqProjTypes[i]=next(reqProjTypes)
  end
end

if #reqProjMats>1 and #newProjMats==1 then
  for i,j in pairs(reqProjMats) do
    newProjMats[i]=next(newProjMats)
  end
end

if #reqProjMats==1 and #newProjMats>1 then
  for i,j in pairs(newProjMats) do
    reqProjMats[i]=next(reqProjMats)
  end
end

if args.divergence then
  if tonumber(args.divergence) and tonumber(args.divergence)>=0 then
    divergence=tonumber(args.divergence)
  else
    error("arg 'divergence' must be a non-negative number")
  end
end

if args.dontReplaceProj then
  dontReplaceProj=true
end
print(args.priority)
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
  tags=args.tags
elseif args.tags then
  tags={args.tags}
end

if args.reqTags and type(args.reqTags)=='table' then
  reqTags=args.reqTags
elseif args.reqTags then
  reqTags={args.reqTags}
end

if args.forbiddenTags and type(args.forbiddenTags)=='table' then
  forbiddenTags=args.forbiddenTags
elseif args.forbiddenTags then
  forbiddenTags={args.forbiddenTags}
end

rm.registerFiringTrigger(args.name, priority, getCommandFunc(args.name, reqProjMats,reqProjTypes,reqWeaponMats,reqWeaponTypes, newProjMats, newProjTypes, newProjNbr, divergence, dontReplaceProj,processSecondaries,allowMultTrigs,tags,reqTags,forbiddenTags))
