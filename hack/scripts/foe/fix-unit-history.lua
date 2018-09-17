--created by thefriendlyhacker
--parts "inspired by" aka shamelessly copy pasted from warmist and co.'s create-unit script.


local usage = [====[

foe/fix-unit-history
====================
Gives a unit historical figure data indicating they are a member of the player's fort (or another group), which is necessary to access the labors of former pets and other units without historical data.  Usage::

    -unit id
        specify which unit is to be given historical data of the unit to be created
    -clearTamed
        Removes flags indicating the creature is a tame pet (recommended for pets or former pets)
    -reqRace race
        restricts the changes to creatures of the given race
    -reqCaste caste
        restricts the changes to creatures of the given caste, requires race arg
    -silent
        does not print warnings (still prints errors)

If the unit is not a member of the fort that needs history or is not a member of the fort, this script will print a warning and abort
]====]


local utils=require 'utils'



local function  allocateNewChunk(hist_entity)
  hist_entity.save_file_id=df.global.unit_chunk_next_id
  df.global.unit_chunk_next_id=df.global.unit_chunk_next_id+1
  hist_entity.next_member_idx=0
  print("allocating chunk:",hist_entity.save_file_id)
end

local function allocateIds(nemesis_record,hist_entity)
  if hist_entity.next_member_idx==100 then
    allocateNewChunk(hist_entity)
  end
  nemesis_record.save_file_id=hist_entity.save_file_id
  nemesis_record.member_idx=hist_entity.next_member_idx
  hist_entity.next_member_idx=hist_entity.next_member_idx+1
end

function createFigure(trgunit,he,he_group)
  local hf=df.historical_figure:new()
  hf.id=df.global.hist_figure_next_id
  hf.race=trgunit.race
  hf.caste=trgunit.caste
  hf.profession = trgunit.profession
  hf.sex = trgunit.sex
  df.global.hist_figure_next_id=df.global.hist_figure_next_id+1
  hf.appeared_year = df.global.cur_year

  hf.born_year = trgunit.birth_year
  hf.born_seconds = trgunit.birth_time
  hf.curse_year = trgunit.curse_year
  hf.curse_seconds = trgunit.curse_time
  hf.birth_year_bias = trgunit.birth_year_bias
  hf.birth_time_bias = trgunit.birth_time_bias
  hf.old_year = trgunit.old_year
  hf.old_seconds = trgunit.old_time
  hf.died_year = -1
  hf.died_seconds = -1
  hf.name:assign(trgunit.name)
  hf.civ_id = trgunit.civ_id
  hf.population_id = trgunit.population_id
  hf.breed_id = -1
  hf.unit_id = trgunit.id

  df.global.world.history.figures:insert("#",hf)

  hf.info = df.historical_figure_info:new()
  hf.info.unk_14 = df.historical_figure_info.T_unk_14:new() -- hf state?
  --unk_14.region_id = -1; unk_14.beast_id = -1; unk_14.unk_14 = 0
  hf.info.unk_14.unk_18 = -1; hf.info.unk_14.unk_1c = -1
  -- set values that seem related to state and do event
  --change_state(hf, dfg.ui.site_id, region_pos)


  --lets skip skills for now
  --local skills = df.historical_figure_info.T_skills:new() -- skills snap shot
  -- ...
  -- note that innate skills are automaticaly set by DF
  hf.info.skills = {new=true}


  he.histfig_ids:insert('#', hf.id)
  he.hist_figures:insert('#', hf)
  if he_group then
    he_group.histfig_ids:insert('#', hf.id)
    he_group.hist_figures:insert('#', hf)
    hf.entity_links:insert("#",{new=df.histfig_entity_link_memberst,entity_id=he_group.id,link_strength=100})
  end
  trgunit.flags1.important_historical_figure = true
  trgunit.flags2.important_historical_figure = true
  trgunit.hist_figure_id = hf.id
  trgunit.hist_figure_id2 = hf.id

  hf.entity_links:insert("#",{new=df.histfig_entity_link_memberst,entity_id=trgunit.civ_id,link_strength=100})

  --add entity event
  local hf_event_id=df.global.hist_event_next_id
  df.global.hist_event_next_id=df.global.hist_event_next_id+1
  df.global.world.history.events:insert("#",{new=df.history_event_add_hf_entity_linkst,year=trgunit.birth_year,
  seconds=trgunit.birth_time,id=hf_event_id,civ=hf.civ_id,histfig=hf.id,link_type=0})
  return hf
end

function validTarget(unit, loud)
  if not unit.civ_id==df.global.ui.civ_id then
    if loud then print("warning: creature not a valid target (different civ id)") end
    return
  end 
  if not dfhack.units.isSane(unit) then
    if loud then print("warning: creature not a valid target (insane)") end
    return false
  end
  if (unit.flags1.marauder) then
    if loud then print("warning: creature not a valid target (marauder)") end
    return false
  end
  if (unit.flags1.invader_origin) then
    if loud then print("warning: creature not a valid target (invader origin)") end
    return false
  end
  if (unit.flags1.active_invader) then
    if loud then print("warning: creature not a valid target (active invader)") end
    return false
  end
  if (unit.flags1.forest) then
    if loud then print("warning: creature not a valid target (caravan guard)") end
    return false
  end
  if (unit.flags1.diplomat) then
    if loud then print("warning: creature not a valid target (diplomat)") end
    return false
  end
  if (unit.flags1.merchant) then
    if loud then print("warning: creature not a valid target (merchant)") end
    return false
  end
  if (unit.flags2.visitor) then
    if loud then print("warning: creature not a valid target (visiter)") end
    return false
  end
  if (unit.flags2.visitor_uninvited) then
    if loud then print("warning: creature not a valid target (uninvited visitor)") end
    return false
  end
  if (unit.flags2.underworld) then
    if loud then print("warning: creature not a valid target (underworld)") end
    return false
  end
  if (unit.flags2.resident) then
    if loud then print("warning: creature not a valid target (resident)") end
    return false
  end

  --will be replaced with commented stuff at some stage
  --I think I need to reference figure data instead, but I have a workaround so I don't need this
  --if dfhack.units.getNemesis(unit).figure then
    --  if loud then print("warning: creature already has nemesis data") end
     -- return false
  --end 

--it should be able to handle things with nemesis data correctly
--since I don't know how, leaving it for now
--  nem=dfhack.units.getNemesis(unit)
--  if (nem) then
--    for i,v in pairs(nem.figure.histfig_links)
--    if v.
--      print("warning - creature already has nemesis data")
--    end
--  end

  return true
end

function createNemesis(trgunit,civ_id,group_id)

  local id=df.global.nemesis_next_id
  local nem=df.nemesis_record:new()

  nem.id=id
  nem.unit_id=trgunit.id
  nem.unit=trgunit
  nem.flags:resize(4)
  --not sure about these flags...
  -- [[
  nem.flags[4]=true
  nem.flags[5]=true
  nem.flags[6]=true
  nem.flags[7]=true
  nem.flags[8]=true
  nem.flags[9]=true
  --]]
  --[[for k=4,8 do
      nem.flags[k]=true
  end]]
  nem.unk10=-1
  nem.unk11=-1
  nem.unk12=-1
  df.global.world.nemesis.all:insert("#",nem)
  df.global.nemesis_next_id=id+1
  trgunit.general_refs:insert("#",{new=df.general_ref_is_nemesisst,nemesis_id=id})
  trgunit.flags1.important_historical_figure=true

  nem.save_file_id=-1

  local he=df.historical_entity.find(civ_id)
  he.nemesis_ids:insert("#",id)
  he.nemesis:insert("#",nem)
  local he_group
  if group_id and group_id~=-1 then
      he_group=df.historical_entity.find(group_id)
  end
  if he_group then
      he_group.nemesis_ids:insert("#",id)
      he_group.nemesis:insert("#",nem)
  end
  allocateIds(nem,he)
  nem.figure=createFigure(trgunit,he,he_group)

end



validArgs = --[[validArgs or]]utils.invert({
  'unit',
  'clearTamed',
  'reqRace',
  'reqCaste',
  'silent',
  'help'
})

local args = utils.processArgs({...}, validArgs)
if args.help then
  print(usage)
  return
end

local loud
if args.silent then
  loud=false
else
  loud=true
end


local unit_id
if args.unit then
  unit_id=args.unit
else
  print("Error - please specify a unit")
end

local unit
if df.unit.find(unit_id) then
  unit = df.unit.find(unit_id)
else
  print("Error - unit not found")
end

if args.reqRace then
  local race
  local race_id
  for i,v in ipairs(df.global.world.raws.creatures.all) do
    if v.creature_id == args.reqRace then
      race=v
      race_id = i
      break
    end
  end
  if not race_id then 
    print("error: race not found")
    return
  end
  if (not unit.race==race_id) then
    if loud then print("warning: not required race") end
    return
  end
  if args.reqCaste then
    local caste_id
    for i,v in ipairs(race.caste) do
      if v.caste_id == args.reqCaste then
        caste_id = i
        break
      end
    end
    if not caste then
      print("error: caste not found")
      return
    end
    if not race.caste==caste_id then
      if loud then print("warning: not required caste") end
      return
    end
  end
end

local civ_id = df.global.ui.civ_id
local group_id = df.global.ui.group_id
--dunno what to set population to and create-unit doesn't set it to anything, so leaving it
--local population_id=

if validTarget(unit,loud) then
  createNemesis(unit, civ_id, group_id)
  unit.civ_id= civ_id
  --unit.population_id= population_id       leaving this
  if args.clearTamed then
    unit.flags1.tame = false
    unit.training_level = 9
  end
end


