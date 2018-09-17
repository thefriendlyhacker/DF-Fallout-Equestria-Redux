-- trigger commands when custom reactions complete
-- author expwnent, contributions by thefriendlyhacker
-- replaces autoSyndrome
--@ module = true
local usage = [====[

foe/reaction-trigger
=========================
Triggers dfhack commands when custom reactions complete, regardless of whether
it produced anything, once per completion.  Arguments::

    -clear
        unregister all reaction hooks
    -reactionName name
        specify the name of the reaction
    -syndrome name
        specify the name of the syndrome to be applied to the targets
    -allowNonworkerTargets
        allow other units to be targeted if the worker is immune or ignored. Only the first valid target is affected. 
        commands must be paired with syndromes, or the command will execute on all creatures within range. 
        overridden by -allowMultipleTargets 
    -allowMultipleTargets
        allow all targets within range to be affected by the command or syndrome
        if absent:
            if running a script, only one target will be used
            if applying a syndrome, then only one target will be infected
    -ignoreWorker
        does not target the worker.  Only makes sense with -allowMultipleTargets or -allowNonworkerTargets.
    -range [ x y z ]
        controls how far elligible targets can be from the workshop.  Defaults to [ 0 0 0 ] (within the workshop).  
        negative x/y numbers can be used to ignore outer squares of the workshop.  The worker is always within range.  
        Line of sight is not respected.
    -resetPolicy policy
        the policy in the case that the syndrome is already present
        policy
            NewInstance (default)
            DoNothing
            ResetDuration
            AddDuration
    -dontSkipInactive
        when selecting targets in range, include creatures that are inactive and within range (including dead creatures)
    -command [ commandStrs ]
        specify the command to be run on the target(s). 
        if a syndrome is also provided, the command will only execute on valid targets for the syndrome. 
        special args
            \\WORKER_ID
            \\TARGET_ID
            \\BUILDING_ID
            \\LOCATION
            \\REACTION_NAME
            \\anything -> \anything
            anything -> anything

]====]
local eventful = require 'plugins.eventful'
local syndromeUtil = require 'syndrome-util'
local utils = require 'utils'

reactionHooks = reactionHooks or {}

eventful.enableEvent(eventful.eventType.UNLOAD,1)
eventful.onUnload.reactionTrigger = function()
 reactionHooks = {}
end

function getWorkerAndBuilding(job)
 local workerId = -1
 local buildingId = -1
 for _,generalRef in ipairs(job.general_refs) do
  if generalRef:getType() == df.general_ref_type.UNIT_WORKER then
   if workerId ~= -1 then
    print(job)
    printall(job)
    error('reaction-trigger: two workers on same job: ' .. workerId .. ', ' .. generalRef.unit_id)
   else
    workerId = generalRef.unit_id
    if workerId == -1 then
     print(job)
     printall(job)
     error('reaction-trigger: invalid worker')
    end
   end
  elseif generalRef:getType() == df.general_ref_type.BUILDING_HOLDER then
   if buildingId ~= -1 then
    print(job)
    printall(job)
    error('reaction-trigger: two buildings same job: ' .. buildingId .. ', ' .. generalRef.building_id)
   else
    buildingId = generalRef.building_id
    if buildingId == -1 then
     print(job)
     printall(job)
     error('reaction-trigger: invalid building')
    end
   end
  end
 end
 return workerId,buildingId
end

local function processCommand(job, worker, target, building, command)
 local result = {}
 for _,arg in ipairs(command) do
  if arg == '\\WORKER_ID' then
   table.insert(result,''..worker.id)
  elseif arg == '\\TARGET_ID' then
   table.insert(result,''..target.id)
  elseif arg == '\\BUILDING_ID' then
   table.insert(result,''..building.id)
  elseif arg == '\\LOCATION' then
   table.insert(result,''..job.pos.x)
   table.insert(result,''..job.pos.y)
   table.insert(result,''..job.pos.z)
  elseif arg == '\\REACTION_NAME' then
   table.insert(result,''..job.reaction_name)
  elseif string.sub(arg,1,1) == '\\' then
   table.insert(result,string.sub(arg,2))
  else
   table.insert(result,arg)
  end
 end
 return result
end

eventful.onJobCompleted.reactionTrigger = function(job)
 if job.completion_timer > 0 then
  return
 end

-- if job.job_type ~= df.job_type.CustomReaction then
--  --TODO: support builtin reaction triggers if someone asks
--  return
-- end

 if not job.reaction_name or job.reaction_name == '' then
  return
 end
-- print('reaction name: ' .. job.reaction_name)
 if not job.reaction_name or not reactionHooks[job.reaction_name] then
  return
 end

 local worker,building = getWorkerAndBuilding(job)
 worker = df.unit.find(worker)
 building = df.building.find(building)
 if not worker or not building then
  --this probably means that it finished before EventManager could get a copy of the job while the job was running
  --TODO: consider printing a warning once
  return
 end

 local function doAction(action)
  local didSomething
  if action.syndrome and not action.ignoreWorker then
   didSomething = syndromeUtil.infectWithSyndromeIfValidTarget(worker, action.syndrome, syndromeUtil.ResetPolicy[action.resetPolicy]) or didSomething
  end
  if action.command and not action.ignoreWorker and ( not action.syndrome or didSomething ) then
   local processed = processCommand(job, worker, worker, building, action.command)
   dfhack.run_command(table.unpack(processed))
  end
  if didSomething and not action.allowMultipleTargets then
   return
  end
  if not action.allowNonworkerTargets and not action.allowMultipleTargets then
   return
  end
  local function foreach(unit)
    local xRange, yRange, zRange
    if action.range then
      xRange,yRange,zRange = tonumber(action.range[1]), tonumber(action.range[2]), tonumber(action.range[3])
    else
      xRange,yRange,zRange = 0, 0, 0
    end
   if unit == worker or not (action.dontSkipInactive or dfhack.units.isActive(unit)) then
    return false
   elseif   unit.pos.z < building.z - zRange or unit.pos.z > building.z + zRange then
    return false
   elseif unit.pos.x < building.x1 - xRange or unit.pos.x > building.x2 + xRange then
    return false
   elseif unit.pos.y < building.y1 - yRange or unit.pos.y > building.y2 + yRange then
    return false
   else
    if action.syndrome then
     didSomething = syndromeUtil.infectWithSyndromeIfValidTarget(unit,action.syndrome,syndromeUtil.ResetPolicy[action.resetPolicy]) or didSomething
    end    
    if action.command and ( not action.syndrome or didSomething ) then
     local processed=processCommand(job, worker, unit, building, action.command)
     dfhack.run_command(table.unpack(processed))
    end
    if didSomething and not action.allowMultipleTargets then
     return true
    end
    return false
   end
  end
  for _,unit in ipairs(df.global.world.units.all) do
   if foreach(unit) then
    break
   end
  end
 end
 for _,action in ipairs(reactionHooks[job.reaction_name]) do
  doAction(action)
 end
end
eventful.enableEvent(eventful.eventType.JOB_COMPLETED,0) --0 is necessary to catch cancelled jobs and not trigger them

validArgs = validArgs or utils.invert({
 'help',
 'clear',
 'reactionName',
 'syndrome',
 'command',
 'allowNonworkerTargets',
 'allowMultipleTargets',
 'range',
 'ignoreWorker',
 'dontSkipInactive',
 'resetPolicy'
})

if moduleMode then
 return
end
local args = utils.processArgs({...}, validArgs)

if args.help then
 print(usage)
 return
end

if args.clear then
 reactionHooks = {}
end

if not args.reactionName then
 return
end

if not reactionHooks[args.reactionName] then
 reactionHooks[args.reactionName] = {}
end

if args.syndrome then
 local foundIt
 for _,syndrome in ipairs(df.global.world.raws.syndromes.all) do
  if syndrome.syn_name == args.syndrome then
   args.syndrome = syndrome
   foundIt = true
   break
  end
 end
 if not foundIt then
  error('Could not find syndrome ' .. args.syndrome)
 end
end

table.insert(reactionHooks[args.reactionName], args)

