#  spawns water or lava at the specified coords
#  written by thefriendlyhacker
=begin

foe/spawn-liquid
=====================
This script spawns liquid at the given coordinates

type spawn-liquid help for 

=end

def print_help()
  puts "modtools/spawn-liquids height liquid x y z xOff yOff zOff"
  puts "  height: height of the water/magma"
  puts "  liquid: either water or magma, spawns that liquid (overriding any other liquid in area)"
  puts "  x y z : the location to spawn liquid at"
  puts "  xOff yOff zOff: optional convenience arguments - added to x,y,z, useful for things like spawning liquids below workshops as a part of other scripts"
end

if $script_args.any?{ |arg| arg == "help" or arg == "?" or arg == "-?" }
  print_help()
  throw :script_finished
end

args=$script_args
args.delete_if {|arg| arg=='[' or arg==']'}
height=args[0].to_i
#liquid is handled later
x=args[2].to_i 
y=args[3].to_i
z=args[4].to_i
if args.count>=5
 x+=args[5].to_i
end
if args.count>=6
 y+=args[6].to_i
end
if args.count>=7
 z+=args[7].to_i
end

tile=df.map_tile_at(x, y, z)
if tile.shape_passableflow
 case args[1]
 when 'magma'
  tile.spawn_magma(height)
 when 'water'
  tile.spawn_water(height)
 end
end
