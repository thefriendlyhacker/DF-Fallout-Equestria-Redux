----changes the basic properties of a projectile----
--author thefriendlyhacker
--based on work by Roses, expwnent, zaporozhets and Putnam.

local usage = [====[

ranged/ranged-properties
===========================
On a predefined trigger, this script changes the basic properties of a projectile.


Usage::
    -name str
        name of the command.  Not optional.  Must be unique.
    -clear name
        unregisters a named command.
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
    -divergence nbr (default 0)
      accuracty of the projectile. Must be non-negative number. Greater is more inaccurate.
      number corresponds to the maximum change in destination tile pos for a projectile heading towards a position 20 tiles away
      effectively, projectiles head towards a tile somewhere in a nbr radius circle around the original destination pos, scaled by distance
    -velocity nbr
      sets the proj velocity to nbr.  If -velocityMult is set, adds velocity to the old velocity times velocityMult.
    -velocityMult nbr
      multiplies the current projectile velocity by nbr, and adds that to velocity.
    -force nbr
      sets the projectile velocity as if it had been fired by a weapon with that amount of force set in the weapon RAWs. 
      added to -velocity and/or -velocityMult times the old velocity if they are present
      warning - does not work with any projectile type that does not have a defined size e.g. globs
    -maxVelocity nbr
      reduces the velocity of the projectile to nbr if it is above it.
      Equivalent to the number in ranged weapon RAWs.
    -hitRatingBase nbr
      sets the hit rating (how likely the projectile is to hit) to a flat number
      for reference, a reasonably competent shooter will launch projectiles with a hit rating between roughly 20 and 100
    -hitRatingMult nbr
      multipies the current hit rating by nbr.  Added to hitRatingBase (if any).
    -delete bool
      flags the projectile to be deleted. Passing without a bool is treated as true.
    -piercing bool
      flags the projectile as a piercing projectile (like ballista bolts). Passing without a bool is treated as true.
    -priority nbr (default 0)
      determines the order in which scripts are checked.  Order is undefined for scripts of equal priority
    -tags str or [ str1 str2 ... ]
      adds tags for the purpose of signaling other scripts using ranged-module
    -reqTags str or [ str1 str2 ... ]
      will only run when scripts with the associated tags have run on this projectile this tick.
    -forbiddenTags str or [ str1 str2 ... ]
      will not run when scripts with the associated tags have run on this projectile this tick.
      note - secondary projectiles have the "secondary" tag
    -trigType str (default "firing")
      sets when in the projectile's flight the script should be called.  Defaults to "firing".
      by default, ranged-module supports the following:
        firing - when the projectile is initially spawned
        move - whenever the projectile moves
        impact - when the projectile hits something.
      
      
]====]
utils = require 'utils'
rm= require 'ranged-module'

function getCommandFunc(funcName,reqProjMats,reqProjTypes,reqWeaponMats,reqWeaponTypes, divergence, velocity, velocityMult, force, maxVelocity, hitRatingBase, hitRatingMult, piercing, delete, scriptTags, reqTags, forbiddenTags)
  return function (proj,tags)
    if not proj.firer then return false end
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
    --dismembered limbs require this    
    if not weapon and (next(reqWeaponMats) or next(reqWeaponTypes)) then return false end

    local projType,projSubtype,projMatType,projMatIndex=proj.item:getType(),proj.item:getSubtype(),proj.item.mat_type,proj.item.mat_index
    
    --first off,checks to see if this conforms to the command requirements
    local found=false
    for i,mat in ipairs(reqProjMats) do
      if mat==dfhack.matinfo.decode(proj.item):getToken() then 
        found=true
      end
    end
    if #reqProjMats>0 and not found then return false end
    found=false
    for _,mat in ipairs(reqWeaponMats) do
      if mat==dfhack.matinfo.decode(weapon):getToken() then found=true end
    end
    if #reqWeaponMats>0 and not found then return false end
    
    found=false
    for i,itype in ipairs(reqProjTypes) do
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
    
    local dist, maxDiv
    dist=math.sqrt((proj.origin_pos.x-proj.target_pos.x)^2+(proj.origin_pos.y-proj.target_pos.y)^2+(proj.origin_pos.z-proj.target_pos.z)^2)
    maxDiv=dist/20*divergence
    --divergence
    if divergence then
      local randAngle, randDist = math.random()*2*math.pi,math.random()*maxDiv
    --for some silly reason lua has no round func, so we are doing a trick with math.ceil to duplicate it
      local targetX,targetY= math.ceil(math.cos(randAngle)*randDist+0.5)-1,math.ceil(math.sin(randAngle)*randDist+0.5)-1
      proj.target_pos.x = proj.target_pos.x + targetX
      proj.target_pos.y = proj.target_pos.y + targetY
    end 
    if not piercing==nil then proj.flags.piercing=piercing end
    if not delete==nil then proj.flags.to_be_deleted=delete end
    if hitRatingBase then
      proj.hit_rating = math.floor(proj.hit_rating*hitRatingMult+hitRatingBase) --accuracy of the attack I *think*
    end
    local newVel=proj.unk22
    if velocity then
      newVel= velocity+proj.unk22*velocityMult
      if force then --wont work if new proj doesn't have defined size
        local density=dfhack.matinfo.decode(proj.item).material.solid_density
        local size=dfhack.items.getSubtypeDef(projType,projSubtype).size
        newVel=newVel+(force*10^6)/20/density/size
      end
    end
    if maxVelocity and newVel>maxVelocity then newVel=maxVelocity end
    if maxVelocity or velocity then proj.unk22=math.floor(newVel) end
    local results={}
    results.tags=scriptTags
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
 'divergence',
 'velocity',
 'velocityMult',
 'force',
 'maxVelocity',
 'delete',
 'piercing',
 'hitRatingBase',
 'hitRatingMult',
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
local velocityMult=nil
local velocity=nil
local maxVelocity=nil
local force=nil
local divergence=0
local hitRatingBase=nil
local hitRatingMult=nil
local priority=0
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




if args.divergence then
  if tonumber(args.divergence) and tonumber(args.divergence)>=0 then
    divergence=tonumber(args.divergence)
  else
    error("arg 'divergence' must be a non-negative number")
  end
end
--nbr check
if args.hitRatingBase or args.hitRatingMult then
  if args.hitRatingBase then
    if tonumber(args.hitRatingBase) then
      hitRatingBase=tonumber(args.hitRatingBase)
    else error("-hitRatingBase must be a number") end
  else hitRatingBase=0 end
  if args.hitRatingMult then
    if tonumber(args.hitRatingMult) then
      hitRatingMult=tonumber(args.hitRatingMult)
    else error("hitRatingMult must be a number") end
  else hitRatingMult=0 end
end

if args.velocity or args.velocityMult or args.force then
  if args.force then 
    if tonumber(args.force) then 
      force=tonumber(args.force) 
    else error("-force must be a number") end
  else force=0 end
  if args.velocity then 
    if tonumber(args.velocity) then 
      velocity=tonumber(args.velocity) 
    else error("-velocity must be a number") end 
  else velocity=0 end
  if args.velocityMult then 
    if tonumber(velocityMult) then 
      velocityMult=tonumber(args.velocityMult) 
    else error("-velocityMult must be a number") end 
  else velocityMult=0 end
end

if args.maxVelocity then 
  if tonumber(args.maxVelocity) then
    maxVelocity=tonumber(args.maxVelocity)
  else error("-maxVelocity must be a number") end  
end
if args.piercing then 
  if args.piercing==true then
    piercing=true 
  elseif args.piercing=="true" then
    piercing=true
  elseif args.piercing=="false" then
    piercing=false
  else piercing=true end
end
if args.delete then 
  if args.delete==true then
    delete=true 
  elseif args.delete=="true" then
    delete=true
  elseif args.delete=="false" then
    delete=false
  else error("-piercing must be true or false") end
end
--vel,maxvel,velmult,force,hitbase,hitmult,piercing,delete,
if args.priority then
  if tonumber(args.priority) then
    priority=tonumber(args.priority)
  else
    error("priority must be a number")
  end
end

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


rm.registerFiringTrigger(args.name, priority, getCommandFunc(args.name, reqProjMats,reqProjTypes,reqWeaponMats,reqWeaponTypes, divergence, velocity, velocityMult, force, maxVelocity, hitRatingBase, hitRatingMult, piercing, delete ,tags,reqTags,forbiddenTags))
