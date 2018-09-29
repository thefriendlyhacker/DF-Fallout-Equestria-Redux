local _ENV = mkmodule("ranged-module")
eventful = require 'plugins.eventful'
utils = require 'utils'

triggers=triggers or {["move"]={},["impact"]={}}

--adding or removing triggers while running a trigguer is undefined.

--registers a function to be called whenever a projectile moves
function registerMoveTrigger(name,priority, trigger)
  registerTrigger(name,priority,trigger,"move")
end

--wrapper for registerTrigger, type of move trigger
function registerFiringTrigger(name,priority,trigger)
  local wrapFunc=function(proj,tags) if proj.distance_flown~=0 then return else trigger(proj,tags) end end
  registerMoveTrigger(name,priority,wrapFunc)
end

function registerTrigger(name,priority,trigger,trigType)
  if not triggers[trigType]then error(trigType.." is not a valid trigger type") end
  if not triggers[trigType][priority] then triggers[trigType][priority]={} end
  triggers[trigType][priority][name]=trigger
end

--wrapper for deregisterTrigger
function deregisterMoveTrigger(name)
  deregisterTrigger(name,"move")
end

--takes a name and a type of trigger, and deregisters that trigger, if found 
--returns the priority and function of the trigger if found, else returns nil
function deregisterTrigger(name,trigType)
  if not triggers[trigType]then error(trigType.." is not a valid trigger type") end
  for priority,trigTable in pairs(triggers[trigType]) do
    for tName,func in pairs(trigTable) do
      if tName==name then
        local retFunc=func
        triggers[trigType][priority][name]=nil
        if next(triggers[trigType][priority])==nil then triggers[name][priority]=nil end
        return priority,retFunc
      end
    end
  end
  return nil, nil
end


--supports recursion, called with tags,pos1,pos2=nil initially
function callLoop(proj,trigType,tags,pos1,pos2)
  if next(triggers[trigType])==nil then 
    return 
  end
  if not pos1 then
    pos1=next(triggers[trigType])
    for priority,_ in pairs(triggers[trigType]) do
      if priority>pos1 then pos1=priority end
    end
  end
  tags=tags or {}
  repeat
    commands=triggers[trigType][pos1]
    local command
    pos2,command=next(commands,pos2)
    repeat
      local results=command(proj,tags)
      if results then
        if results.terminate then return end
        if results.secondaryProjectiles and results.processSecondaries then
          for i,j in pairs(results.secondaryProjectiles) do
            local secTags={}
            secTags._secondary=true
            for k,l in pairs(tags) do secTags[k]=l end
            if results.secondaryTags then
              for k,l in pairs(results.secondaryTags) do secTags[k]=l end
            end
            callLoop(j,trigType,secTags,pos1,pos2)
          end
        end
        if results.proj then proj=results.proj end
        if results.tags then for i,j in results.tags do tags[i]=j end end
      end
      pos2,command=next(commands,pos2)
    until pos2==nil
    local newPos=nil
    for priority,_ in pairs(triggers[trigType]) do
     if priority < pos1 and ((not newPos) or (priority > newPos)) then newPos=priority end
    end
    pos1=newPos
  until pos==nil
end

function onProjMovement(proj)
  callLoop(proj,"move",{})
end

eventful.onProjItemCheckMovement.rangedModule = onProjMovement
eventful.enableEvent(eventful.eventType.UNLOAD,1)
eventful.onUnload.rangedTriggerModule = function()
 triggers = {}
end
--takes a template projectile, item details and creating unit, and creates an initialised projectile
function createProjectile(proj,itemType,itemSubtype,matType,matIndex,creator)
  local newProjItem = df.item.find(dfhack.items.createItem(itemType, itemSubtype, matType, matIndex, creator))
  newProjItem.flags.forbid = true
  newProjItem.quality = proj.item.quality
  local newProj = dfhack.items.makeProjectile(newProjItem)
  --link, don't need to touch
  --id, don't need to touch
  newProj.firer=proj.firer
  newProj.origin_pos.x = proj.origin_pos.x
  newProj.origin_pos.y = proj.origin_pos.y
  newProj.origin_pos.z = proj.origin_pos.z
  newProj.prev_pos.x = proj.origin_pos.x
  newProj.prev_pos.y = proj.origin_pos.y
  newProj.prev_pos.z = proj.origin_pos.z
  newProj.cur_pos.x = proj.origin_pos.x
  newProj.cur_pos.y = proj.origin_pos.y
  newProj.cur_pos.z = proj.origin_pos.z
  newProj.target_pos.x = proj.target_pos.x
  newProj.target_pos.y = proj.target_pos.y
  newProj.target_pos.z = proj.target_pos.z
  newProj.distance_flown = proj.distance_flown
  newProj.fall_threshold = proj.fall_threshold
  newProj.min_hit_distance = proj.min_hit_distance
  newProj.min_ground_distance = proj.min_ground_distance
  --flags
  newProj.flags.no_impact_destroy = proj.flags.no_impact_destroy
  newProj.flags.has_hit_ground = proj.flags.has_hit_ground
  newProj.flags.bouncing = proj.flags.bouncing
  newProj.flags.high_flying = proj.flags.high_flying
  newProj.flags.piercing = proj.flags.piercing
  newProj.flags.to_be_deleted = proj.flags.to_be_deleted
  newProj.flags.unk6 = proj.flags.unk6
  newProj.flags.unk7 = proj.flags.unk7
  newProj.flags.parabolic = proj.flags.parabolic
  newProj.flags.unk9 = proj.flags.unk9
  newProj.flags.no_collide = proj.flags.no_collide
  newProj.flags.safe_landing = proj.flags.safe_landing
  --end flags
  newProj.fall_counter = proj.fall_counter
  newProj.fall_delay = proj.fall_delay
  newProj.hit_rating = proj.hit_rating --accuracy of the attack I *think*
  newProj.unk21 = proj.unk21 --only ever seen this equal to 0
  newProj.unk22 = proj.unk22--this is projectile velocity, note to self vel=(force/20)/(density*size/10^6 (cm^3->m^3))
  newProj.bow_id = proj.bow_id
  newProj.unk_item_id = proj.unk_item_id --no idea what this is
  newProj.unk_unit_id = proj.unk_unit_id --ditto
  newProj.unk_v40_1 = proj.unk_v40_1 --probably target ID
  newProj.speed_x = proj.speed_x --these are always 0 for projectiles, dunno their significance
  newProj.speed_y = proj.speed_y
  newProj.speed_z = proj.speed_z
  newProj.accel_x = proj.accel_x --ditto
  newProj.accel_y = proj.accel_y
  newProj.accel_z = proj.accel_z
  return newProj,newProjItem
end
return _ENV