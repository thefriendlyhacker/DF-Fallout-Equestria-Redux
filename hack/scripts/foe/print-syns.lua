--created by thefriendlyhacker
--todo - if necessary, make it so reqSynX takes a single string or an array, and checks all of them (treating the single string as a single element array).


local usage = [====[

foe/print-syns
====================
Prints out syndromes that match certain conditions.  Syndromes will be printed if they match any of the conditions (if no conditions are specified, all syndromes are printed).

The announcement is of the form {unit name}{before text}{syndrome name}{after text}, with no spaces between each string.

Usage::
    -unit id
        specify which unit being checked
    -reqSynText text
        announces the syndrome if it's name contains this text 
    -reqSynClass class
        announces the syndrome if it has this syn class
    -reqSynName name
        announces the syndrome if it has this exact name
    -textBefore text
        in the announcement, prints this text before the syndrome
    -textAfter text
        in the announcement, prints this text after the syndrome
    -dontAnnounceName
        don't print the name as part of the announcement
    -dontAnnounceSyn
        don't print the syndrome name as part of the announcement
    -announceOnce
        only announce the first match
If the unit is not a member of the fort that needs history or is not a member of the fort, this script will print a warning and abort
]====]


local utils=require 'utils'
local syndromeUtil = require 'syndrome-util'


function announceSyndrome(syndrome,unitName,textBefore,textAfter)
  dfhack.gui.showAnnouncement(unitName..textBefore..syndrome..textAfter,COLOR_LIGHTBLUE, true)  
end

function checkSyn(syndrome,reqSynText,reqSynClass,reqSynName)
  if not reqSynText and not reqSynClass and not reqSynName then return true end
  if syndrome.syn_name==reqSynName then return true end
  if string.find(syndrome.syn_name,reqSynText) then return true end
  for _,class in ipairs(syndrome.syn_class) do if class==reqSynClass then return true end end
  return false
end
local validArgs = utils.invert({
  'unit',
  'reqSynText',
  'reqSynClass',
  'reqSynName',
  'textBefore',
  'textAfter',
  'dontAnnounceName',
  'dontAnnounceSyn',
  'announceOnce',
  'help'
})

local args =  utils.processArgs({...}, validArgs)
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
  unit_id=tonumber(args.unit)
else
  print("Error - please specify a unit")
end

local unit
local unitName=""
if df.unit.find(unit_id) then
  unit = df.unit.find(unit_id)
  if not args.dontAnnounceName then
    local unitNameData=dfhack.units.getVisibleName(unit)
	if string.len(unitNameData.nickname)>0 then unitName=unitNameData.nickname 
	else unitName=unitNameData.first_name end
  end
else
  print("Error - unit not found")
end
textBefore=args.textBefore
textAfter=args.textAfter
if not textBefore then textBefore="" end
if not textAfter then textAfter="" end

for _,unitSyn in ipairs(unit.syndromes.active) do
  local syndrome
  for _,syn in ipairs(df.global.world.raws.syndromes.all) do
    if unitSyn.type==syn.id then
      syndrome=syn
      break
    end
  end
  if not syndrome then
    error('INTERNAL ERROR - Could not find syndrome with type:' .. unitSyn.type)
  end
  if checkSyn(syndrome,args.reqSynText,args.reqSynClass,args.reqSynName) then
    local synName=syndrome.syn_name
	if args.dontAnnounceSyn then synName="" end
    announceSyndrome(synName,unitName,textBefore,textAfter)
    if args.announceOnce then return end
  end
end


