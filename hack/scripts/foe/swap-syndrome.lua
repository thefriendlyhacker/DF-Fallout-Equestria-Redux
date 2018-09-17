-- this script swaps syndromes with other syndromes, only on certain conditions
--written by thefriendlyhacker
local usage = [====[

foe/swap-syndrome
=====================
This script applies syndromes with other syndromes on certain conditions.  It can also be used to apply syndromes to all creatures (again, on certain conditions).

Arguments::

    -disable name
        removes a syndrome replacement registration.
    -help
        prints help and ends
    -noRepeat
        only executes once, does not repeat on subsequent ticks
    -name string
        names the syndrome replacement registration. Required unless -noRepeat 
    -tickRate nbr
        defines how often the syndrome(s) is replaced. Defaults to 100 ticks
    -dontDisperseCalls
        by default, the first repeat is randomly offset so that all swap-syndrome calls don't end up on the same tick (potentially creating lag spikes).  This disables that behavior.

    -oldSyn syndrome or oldSyn [ syndromes ]
        defines which syndromes are to be replaced.  If both oldSyn and oldSynClass are undefined, then the new syndrome is applied
    -oldSynClass synClass or -oldSynClass [ synClasses ]
        defines which syndrome classes are to be replaced
    -newSyn syndrome or -newSyn [ syndromes ]
        defines which syndrome(s) is to be applied
    -resetPolicy policy
        specify a policy of what to do if the unit already has an instance of the syndrome.
            NewInstance (default)
            DoNothing
            ResetDuration
            AddDuration

    -reqSyn syndrome or reqSyn [ syndromes ]
        only apply the syndrome if one of the syndrome(s) is present
    -reqSynClass synClass or reqSynClass [ synClasses ]
        only apply the syndrome if one of the syndrome class(es) is present.  If both reqSyn and reqSynClass are args, only one need match to apply the syndrome.
    -notSyn syndrome or -notSyn [ syndromes ]
        only apply the syndrome if the syndrome(s) is not present
    -notSynClass synClass or -notSynClass [ synClasses ]
        only apply the syndrome if the syndrome class(es) is not present
]====]
local eventful = require 'plugins.eventful'
local utils = require 'utils'
local repeatUtil = require 'repeat-util'
local syndromeUtil = require 'syndrome-util'

defaultTickRate=100 -- on low tickrates this may hurt fps severely
defaultResetPolicy=syndromeUtil.ResetPolicy["ResetDuration"]

function applySyndrome(unit,syndrome,resetPolicy)
  syndromeUtil.infectWithSyndromeIfValidTarget(unit,find_syndrome(syndrome),resetPolicy)
end
--func must take unit only, not nil
function checkSynConds(unit,reqSyns,reqNotSyns,reqSynClasses,reqNotSynClasses)
  local hasReqSyn=false
  if not next(reqSynClasses) and not next(reqSyns) then
    hasReqSyn=true
  end
  if hasReqSyn and not (next(reqNotSyns) or next(reqNotSynClasses)) then
    return true -- when there are no conditions
  end
  for _,active_syn in pairs(unit.syndromes.active) do
    local syn= df.syndrome.find(active_syn.type)
    for _,reqSyn in ipairs(reqSyns) do
      if syn==reqSyn then
        hasReqSyn=true
      end
    end 
    for _,reqNotSyn in ipairs(reqNotSyns) do      
      if syn==reqNotSyn then
        return false
      end
    end
    for _,class in ipairs(syn.syn_class) do
      for _,reqSynClass in ipairs(reqSynClasses) do
        if class.value==reqSynClass then
          hasReqSyn=true
        end
      end
      for _,invalidSynClass in ipairs(reqNotSynClasses) do
        if class.value == invalidSynClass then
          return false
        end
      end
    end
  end
  if hasReqSyn then return true end
  return false
end

function find_syndrome(syn_name)
  local syndrome
  for _,syn in ipairs(df.global.world.raws.syndromes.all) do
    if syn.syn_name == syn_name then
      syndrome = syn
      break
    end
  end
  if not syndrome then
    error ('error - cannot find: ' .. syn_name)
  end
  return syndrome
end

function stripSyndrome(unit,synName)
  syndromeUtil.eraseSyndromes(unit,find_syndrome(synName).id)
end

function stripSyndromeByClass(unit,synClass)
  for _,syn in ipairs(unit.syndromes.active) do
    for _,unitSynClass in ipairs(syn.syn_class) do
      if synClass==unitSynClass then
        stripSyndrome(unit,syn.id)
      end
    end
  end
end

function registerScript(name,func,tickRate,dontDisperse)
  assert(name,'error - no name defined')
  if not tickRate then tickRate=defaultTickRate end
  repeatUtil.scheduleEvery(name,tickRate,'ticks',func)
  if not dontDisperse then
  --yeah, I am using impl details, it is the nicest way to do this
    local callback=dfhack.timeout_active(repeatUtil.repeating[name],nil)
    dfhack.timeout(tickRate-math.random(0,tickRate-1),'ticks',callback)
  end
end

function searchUnitForSyndromes(unit,syns,synClasses)
  for _,unitSyn in ipairs(unit.syndromes.active) do
    local synType=df.syndrome.find(unitSyn.type)
    for _,unitSynClass in ipairs(synType.syn_class) do
      for _,synClass in ipairs(synClasses) do
        if synClass==unitSynClass then return true end
      end
    end
    for _,syn in ipairs(syns) do
      if synType.syn_name==syn then return true end
    end
  end
  return false
end

function swapSyns(unit,oldSyns,oldSynCs,newSyns,resetPolicy)
  for _,syn in ipairs(oldSyns) do
    stripSyndrome(unit,syn)
  end
  for _,synC in ipairs(oldSynCs) do
    stripSyndromeByClass(unit,synC)
  end
  for _,newSyn in ipairs(newSyns) do
    applySyndrome(unit,newSyn,resetPolicy)
  end
end


--this is a desperate attempt to reduce runtime costs by writing code such that everything done in the callback proper is a local variable lookup.
function getCallbackInner(oldSyns,oldSynCs,newSyns,reqSyns,reqSynCs,notSyns,notSynCs, resetP)
  return function()
    for _,unit in ipairs(df.global.world.units.all) do
      if searchUnitForSyndromes(unit,oldSyns,oldSynCs) then
        if checkSynConds(unit,reqSyns,reqSynCs,notSyns,notSynCs) then
          swapSyns(unit,oldSyns,oldSynCs,newSyns,resetP)
        end
      end
    end
  end
end

function getCallback(args)
  return getCallbackInner(args.oldSyn,args.oldSynClass,args.newSyn,args.reqSyn,args.reqSynClass,args.notSyn,args.notSynClass,args.resetPolicy)
end


--note - repeatCall is for internal use only
validArgs = validArgs or utils.invert({
 'disable',
 'help',
 'noRepeat',
 'name',
 'tickRate',
 'dontDisperseCalls',
 'oldSyn',
 'oldSynClass',
 'newSyn', 
 'resetPolicy',
 'reqSyn',
 'reqSynClass',
 'notSyn',
 'notSynClass'
})
local args = utils.processArgs({...}, validArgs)

if args.help then
  print(usage)
  return
end
if args.disable then
  repeatUtil.cancel(args.name)
  return
end


if not args.tickRate then
  args.tickRate=defaultTickRate
end


if type(args.oldSyn)=="string" then
  args.oldSyn= {args.oldSyn}
end
if not args.oldSyn then
  args.oldSyn={}
end


if type(args.oldSynClass)=="string" then
  args.oldSynClass= {args.oldSynClass}
end
if not args.oldSynClass then
  args.oldSynClass= {}
end

if type(args.newSyn)=="string" then
  args.newSyn= {args.newSyn}
end
if not args.newSyn then
  args.newSyn={}
end


if type(args.reqSyn)=="string" then
  args.reqSyn={args.reqSyn}
end
if not args.reqSyn then
  args.reqSyn={}
end


if type(args.reqSynClass)=="string" then
  args.reqSynClass={args.reqSynClass}
end
if not args.reqSynClass then
  args.reqSynClass={}
end

if type(args.notSyn)=="string" then
  args.notSyn= {args.notSyn}
end
if not args.notSyn then
  args.notSyn= {}
end

if type(args.notSynClass)=="string" then
  args.notSynClass= {args.notSynClass}
end
if not args.notSynClass then
  args.notSynClass= {}
end

if not args.resetPolicy then args.resetPolicy=defaultResetPolicy
else
  assert( syndromeUtil.ResetPolicy[args.resetPolicy],"error - resetPolicy must be: DoNothing, ResetDuration, AddDuration or NewInstance")
  args.resetPolicy=syndromeUtil.ResetPolicy[args.resetPolicy]
end


callback=getCallback(args)
if not args.noRepeat then
  registerScript(args.name,callback,args.tickRate,args.dontDisperseCalls)
end
callback()