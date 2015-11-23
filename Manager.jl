#
# Manages organisms and they world
# @singleton
#
# @author DeadbraiN
#
# TODO: describe included files and how to split Manager on files.
# TODO:   - Manager may call every function from any file
# TODO:   - File may call every function except other files
# TOSO:   - If file calls Manager function it hould add Manager. before calling
# TODO: describe that manager is a mediator between all other objects
# TODO: like mutator, world, terminal and so on.
# TODO: add support of serverPort cmd line argument
# TODO: add remote functions for changing period and probs
#
module Manager
  import Creature
  import World
  import Config
  import Helper
  import Event
  import Mutator
  import Server
  import Connection
  import CommandLine
  #
  # This is how we collect Manager module from it's parts
  #
  include("ManagerRpc.jl")
  include("ManagerOrganism.jl")
  #
  # This manager is also a server for all other remote managers. These
  # remote managers are clients for current and may use "Client" module
  # to send commands and obtain results. So, this port will be used for
  # current manager(server) for listening clients.
  #
  const PARAM_SERVER_PORT = "serverPort"
  #
  # Manager's options, which may be changed by remote calls
  #
  type Options
    #
    # Amount of iterations, after whichenergy will be decreased
    #
    period::UInt
    #
    # Value for energy decrease per one time
    #
    decValue::UInt
    #
    # Mutation related probability: add/change/remove 
    #
    probs::Array{Int, 1}
  end

  #
  # Runs everything. Blocking function.
  #
  function run()
    counter = UInt(0)
    server  = _createServer()

    #
    # This server is listening for all other managers and remote
    # terminal. It runs obtained commands and send answers back.
    # In other words, it works like RPC mechanism...
    #
    Server.run(server)
    #
    # This is main infinite loop. It manages input connections
    # and organism's tasks switching.
    #
    while true
      #
      # This call runs all organism related tasks one by one
      #
      counter = _updateOrganisms(counter)
      #
      # This call switches between all non blocking asynchronous
      # functions (see @async macro). For example, it handles all
      # input connections for current server.
      #
      yield()
    end
  end

  #
  # Instance of the world
  #
  _world = World.create()
  #
  # Positions map, which stores positions of all organisms. Is used
  # for fast access to the organism by it's coordinates.
  #
  _posMap = Dict{UInt, Creature.Organism}()
  #
  # Parameters passed through command line
  #
  _params = CommandLine.create()
  #
  # Global manager's options like: energy decrease period, add/change
  # operation probability and so on. This options may be changed by
  # remote calls. See _rpcApi for details.
  #
  _options = Options(
    Config.organism["decreaseAfterTimes"],
    Config.organism["descreaseValue"],
    Config.mutator["addChange"]
  )
end