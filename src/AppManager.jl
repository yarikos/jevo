#
# TODO: description
# TODO: describe "recover" command line argument
#
include("ImportFolders.jl")

import Manager
import Helper
import Backup
import CommandLine
#
# Name of the command line argument, which tells the application
# to recover itself from last backup.
#
const ARG_RECOVER = "recover"
#
# This function starts the manager, world, organisms, server etc...
# It checks "recover" argument for recovering from last backup or
# runs in a common mode.
#
function main()
  local args::Dict{String, String} = CommandLine.create()
  local man::ManagerTypes.ManagerData = Manager.create()

  if CommandLine.has(args, ARG_RECOVER)
    Manager.recover(man)
    return Manager.run(man, true)
  end

  Helper.info("Running from scratch...")
  Manager.run(man)
end
#
# Application entry point
#
main()
