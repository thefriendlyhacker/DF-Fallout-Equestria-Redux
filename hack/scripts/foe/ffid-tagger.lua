-- this script performs several friend/foe ID related tasks
-- it tags fortress allies with an [FFID_ALLY] syndrome, and non-allies an [FFID_NOT_ALLY] syndrome
-- it tags fortress enemies with an [FFID_ENEMY] syndrome, and non-enemies an [FFID_NOT_ENEMY] syndrome
-- it gives allies an enemy tagging combat interaction, so hostile wildlife can be tagged enemy
-- it strips said tag/int when units change allegiance (e.g. citizens going beserk) 
-- note - at the moment it does not strip tags due to the performance hit, but instead just lets them expire
--written by thefriendlyhacker
local usage = [====[

foe/ffid-tagger
=====================
This fortress mode orientated tool gives all allies of the fort an [ALLY] syndrome tag and an enemy tagging interaction, as well as giving all enemies an [ENEMY] tag.  It strips said syndrome tags from any creature which is no longer an ally/enemy.

Arguments::

    -disable
        turns the ffid-tagger off. Any lingering tags are still left on (but will expire within 300 ticks, as defined by the syndrome).
    -help
        prints help and ends
    -noRepeat
        only tags creatures once, does not repeat on subsequent ticks
]====]
local eventful = require 'plugins.eventful'
local utils = require 'utils'
local repeatUtil = require 'repeat-util'
local syndromeUtil = require 'syndrome-util'

ffidTickRate=1 -- on low tickrates this murders fps
ffidActive = ffidActive or false
resetPolicy=syndromeUtil.ResetPolicy["ResetDuration"]

eventful.enableEvent(eventful.eventType.UNLOAD,1)

eventful.onUnload.ffidTagger = function()
  ffidActive=false 
  repeatUtil.cancel("ffid-tagger")
end

function tagUnits()
  for _,unit in ipairs(df.global.world.units.all) do
    tagUnit(unit)
  end
end
local callCommand = function()
 tagUnits()
end



function applyAllyTag(unit)
  applySyndrome(unit,"ffid ally tagged")
end

function applyNotAllyTagIfValid(unit)
  applySyndromeIfNoSynTag(unit,"ffid not ally tagged","FFID_ALLY")
end

function applyEnemyTag(unit)
  applySyndrome(unit,"ffid enemy tagged")
end

function applyNotEnemyTagIfValid(unit)
  applySyndromeIfNoSynTag(unit,"ffid not enemy tagged","FFID_ENEMY")
end

function applySyndrome(unit,syndrome)
  syndromeUtil.infectWithSyndrome(unit,find_syndrome(syndrome),resetPolicy)
end

function applySyndromeIfNoSynTag(unit,syndrome,invalidSynClass)
  for _,active_syn in pairs(unit.syndromes.active) do
    local syn= df.syndrome.find(active_syn.type)
    for _,class in ipairs(syn.syn_class) do
      if class.value == invalidSynClass then
        return false
      end
    end
  end
  applySyndrome(unit,syndrome)
end

function stripAllyTag(unit)
  stripSyndrome(unit,"ffid ally tagged")
end

function stripEnemyTag(unit)
  stripSyndrome(unit,"ffid enemy tagged")
end

function stripNotAllyTag(unit)
  stripSyndrome(unit,"ffid not ally tagged")
end

function stripNotEnemyTag(unit)
  stripSyndrome(unit,"ffid not enemy tagged")
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
    error ('INTERNAL ERROR - CANNOT FIND: ' .. syn_name)
  end
  return syndrome
end

function stripSyndrome(unit,syn_name)  --DISABLED - performance hit from applying/stripping too high
  --syndromeUtil.eraseSyndromes(unit,find_syndrome(syn_name).id)
end

function tagUnit(unit)
  --dead creatures have frozen tags
  if dfhack.units.isDead(unit) then return end  
  stripNotAllyTag(unit)
  stripNotEnemyTag(unit)
  tagUnitInner(unit) 
  applyNotAllyTagIfValid(unit)
  applyNotEnemyTagIfValid(unit)
end

function tagUnitInner(unit)
  --do I need to handle ambusher flag as well?  Not sure...  
  if unit.flags1.marauder then
    stripAllyTag(unit)
    applyEnemyTag(unit)
    return
  end
  if (unit.flags1.invader_origin) then
    stripAllyTag(unit)
    applyEnemyTag(unit)
    return
  end

  if (unit.flags1.active_invader) then
    stripAllyTag(unit)
    applyEnemyTag(unit)
    return
  end
  
  if (unit.flags2.visitor_uninvited) then
    stripAllyTag(unit)
    applyEnemyTag(unit)
    return
  end
  if unit.flags2.underworld then
    stripAllyTag(unit)
    applyEnemyTag(unit)
    return
  end
  if unit.civ_id==df.global.ui.civ_id then
    if not dfhack.units.isSane(unit) then
--for better or worse, this includes opposed to life handed out by syndromes
      stripAllyTag(unit) --still not an enemy, but not an ally either
      return
    end
    if dfhack.units.isForest(unit) then return end
    if unit.flags1.diplomat then return end
    if dfhack.units.isMerchant(unit) then return end
    if unit.flags2.visitor then return end
    if unit.flags2.resident then return end
    stripEnemyTag(unit)
    applyAllyTag(unit)
    return
  end
end

--note - repeatCall is for internal use only
validArgs = validArgs or utils.invert({
 'disable',
 'help',
 'noRepeat'
})
local args = utils.processArgs({...}, validArgs)

if args.help then
 print(usage)
 return
end

--tickrate arg option was removed, it instead is hardcoded
if not args.noRepeat then
  if args.disable then
    if ffidActive then
      repeatUtil.cancel("ffid-tagger")
      ffidActive = false
    end
  else
    if not ffidActive then
      ffidActive=true
      repeatUtil.scheduleEvery("ffid-tagger",ffidTickRate,'ticks',callCommand)
    end
  end
end
tagUnits()