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
  local wrapFunc=function(proj) if proj.distance_flown~=0 then return else trigger(proj) end end
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
  if next(triggers[trigType])==nil then return end
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
      local results
      results=command(proj,tags)
      if results then
        if results.terminate then return end
        if results.secondaryProjectiles and results.processSecondaries then
          for i,j in pairs(results.secondaryProjectiles) do
            local secTags={}
            for k,l in pairs(tags) do secTags[k]=l end
            if results.secondaryTags then
              for k,l in pairs(results.secondaryTags) do secTags[k]=l end
            end
            callLoop(j,secTags,trigType,pos1,pos2)
          end
        end
        if results.proj then proj=results.proj end
        if results.tags then for i,j in results.tags do tags[i]=j end end
      end
    pos2,command=next(commands,pos2)
    until pos2==nil
    local newPos
    for priority,_ in pairs(triggers[trigType]) do
     if priority < pos1 and priority > newPos then newPos=priority end
    end
    pos1=newPos
  until pos==nil
end

function onProjMovement(proj)
  callLoop(proj,"move")
end

eventful.onProjItemCheckMovement.rangedModule = onProjMovement
eventful.enableEvent(eventful.eventType.UNLOAD,1)
eventful.onUnload.rangedTriggerModule = function()
 triggers = {}
end

return _ENV