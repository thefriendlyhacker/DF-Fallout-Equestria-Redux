local _ENV = mkmodule("ranged-module")
eventful = require 'plugins.eventful'
utils = require 'utils'

triggers=triggers or {["move"]={},["impact"]={},["firing"]={}}
pos1List=pos1List or {["move"]={},["impact"]={},["firing"]={}}
pos2List=pos2List or {["move"]={},["impact"]={},["firing"]={}}
tagsList=tagsList or {["move"]={},["impact"]={},["firing"]={}}


--adding or removing triggers while running a trigguer is undefined.

--registers a function to be called whenever a projectile moves
function registerMoveTrigger(name,priority, trigger)
  registerTrigger(name,priority,trigger,"move")
end

--wrapper for registerTrigger, type of move trigger

function registerFiringTrigger(name,priority,trigger)
  registerTrigger(name,priority,trigger,"firing")
  --I can't be bothered figuring out a better way of doing this
  if not firingTimeout then
    firingTimeout=dfhack.timeout(1,'ticks',onTickFiringCheck)
  end
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
function callLoop(proj,trigType)
  --if there aren't any triggers, just return
  if next(triggers[trigType])==nil then 
    return 
  end
  
  local tags,pos1,pos2={},nil,nil--pos1 is current priority, pos2 is position within a particular priority table
  --check to see if this proj is registered as a secondary Projectile, and initialize as necessary
  if pos1List[trigType][proj.id] then
    tags=tagsList[trigType][proj.id]
    pos1=pos1List[trigType][proj.id]
    pos2=pos2List[trigType][proj.id]
    --don't need these any more
    tagsList[trigType][proj.id]=nil
    pos1List[trigType][proj.id]=nil
    pos2List[trigType][proj.id]=nil 
  end
  --main callback loop
  --for clarity, the loop goes like this
    --first iteration, find highest priority (pos1), find first command in that priority table (pos2), process that command
    --next iteration, same priority, find next command in priority table, process command
    --...eventually, find last command in priority, process command
    --find no more commands for that priority, position in priority table (pos2) is nil so do nothing that loop  
    --position in priority table is nil so find next highest priority, find first command, prosess result
    --...eventually, cannot find any more commands in lowest priority, position in priority table is nil, do nothing that loop
    --search for more priorities, don't find any, don't look for or process any commands, meet terminate condition for loop, leave loop
  
  local command,commands
  repeat
    --if pos2==nil then the loop is either starting or has just finished a priority, and we need to find the next one
    if pos2==nil then
      local nextPos1=nil
      for priority,nextCommands in pairs(triggers[trigType]) do
        --pick the highest priority (with table of funcs) that is lower than the current priority position (if any)
        if (nextPos1==nil or priority>nextPos1) and (not pos1 or priority<pos1) then
          nextPos1=priority
          commands=nextCommands
        end
      end
      pos1=nextPos1
    end
    --now go to the next position in the priority table, if there is a next priority table
    if not (pos1==nil) then
      pos2,command=next(triggers[trigType][pos1],pos2)
    end
    --run the command
    if not (pos2==nil) then
      local results=command(proj,tags)
      if results then
        if results.terminate then return end
        if results.secondaryProjectiles then
          for _,secProj in pairs(results.secondaryProjectiles) do
            local secTags={}
            secTags._secondary=true
            for k,l in pairs(tags) do secTags[k]=l end
            if results.tags then 
              for k,l in pairs(results.tags) do secTags[k]=l end
            end
            if results.secondaryTags then
              for k,l in pairs(results.secondaryTags) do secTags[k]=l end
            end
            pos1List[trigType][secProj.id]=pos1
            pos2List[trigType][secProj.id]=pos2
            tagsList[trigType][secProj.id]=secTags
          end
        end
      if results.tags then for i,j in pairs(results.tags) do tags[i]=j end end
      end
    end
  until pos1==nil
end

function onTickFiringCheck()
  firingTimeout=dfhack.timeout(1,'ticks',onTickFiringCheck)
  pos1List["firing"]={}
  pos2List["firing"]={}
  tagsList["firing"]={}
  local nextProj=df.global.world.proj_list.next
  if nextProj then
    repeat
      if nextProj.item.distance_flown==0 then
        callLoop(nextProj.item,"firing")
      end
      nextProj=nextProj.next
    until not nextProj
  end
end

firingTimeout=firingTimeout or nil
if not firingTimeout then
  firingTimeout=dfhack.timeout(1,'ticks',onTickFiringCheck)
end

function onProjMovement(proj)
  callLoop(proj,"move",{})
end

eventful.onProjItemCheckMovement.rangedModule = onProjMovement
eventful.enableEvent(eventful.eventType.UNLOAD,1)
eventful.onUnload.rangedTriggerModule = function()
  triggers = nil
  firingTimeout=nil
end
--takes a template projectile, item details and creating unit, and creates an initialised projectile
function createProjectile(proj,itemType,itemSubtype,matType,matIndex,creator)
  local newProjItem = df.item.find(dfhack.items.createItem(itemType, itemSubtype, matType, matIndex, creator))
  newProjItem.flags.forbid = true
  if not newProjItem.quality==nil then
    if proj.item.quality==nil then
      newProjItem.quality=0
    else
      newProjItem.quality=proj.item.quality
    end
  end
  local newProj = dfhack.items.makeProjectile(newProjItem)
  
  --if newProj is created midair then dfhack "helpfully" makes it a falling projectile
  --this prevents the above call from creating a projectile, so we need to "borrow" the one dfhack made
  if newProj==nil then
    local projLink=df.global.world.proj_list
    repeat
      projLink=projLink.next
      if projLink~=nil then
        if projLink.item.item==newProjItem then
          newProj=projLink.item
        end
      else error("error - cannot create projectile from new item for unknown reason") end
    until newProj
  end
  
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