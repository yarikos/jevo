#
# Events:
#   clone      {Organism}                Fires if script is called "clone" command.
#   getenergy  {Organism, Point, {ret=>Num}} Fires to check if specified point
#                                        in world contains an energy. Returns amount
#                                        of energy in "ret" property.
#   grableft   {Organism, UInt, {ret=>Num}} Fires to obtain energy from the left side of
#                                        current organism. Second parameter is an 
#                                        amount of energy to grab. "ret" will contain
#                                        new organism's position.
#   grabright  {Organism, UInt, {ret=>Num}} Fires to obtain energy from the right side of
#                                        current organism. Second parameter is an 
#                                        amount of energy to grab. "ret" will contain
#                                        new organism's position.
#   grabup     {Organism, UInt, {ret=>Num}} Fires to obtain energy from the up side of
#                                        current organism. Second parameter is an 
#                                        amount of energy to grab. "ret" will contain
#                                        new organism's position.
#   grabdown   {Organism, UInt, {ret=>Num}} Fires to obtain energy from the right side of
#                                        current organism. Second parameter is an 
#                                        amount of energy to grab. "ret" will contain
#                                        new organism's position.
#   stepleft   {Organism, {ret=>Point}}  Fires to make a step left. "ret" will contain
#                                        new organism's position.
#   stepright  {Organism, {ret=>Point}}  Fires to make a step right. "ret" will contain
#                                        new organism's position.
#   stepup     {Organism, {ret=>Point}}  Fires to make a step up. "ret" will contain
#                                        new organism's position.
#   stepdown   {Organism, {ret=>Point}}  Fires to make a step down. "ret" will contain
#                                        new organism's position.
#
# @author DeadbraiN
#
# TODO: code should be wrapped by try...catch, because different 
# TODO: exceptions are possible.
#
# TODO: think about energy limit for organism. add new library
# TODO: function: fullOfEnergy():Bool
# TODO: add memory operations: mem_read(index):Int, mem_write(index, Int)
#
module Creature
  import Event
  import Helper
  using Config
  using Debug

  export Code
  export Organism
  export RetObj

  export create
  export mutate

  # TODO: remove this type and use ASCIIString instead
  type Code
    str::ASCIIString
    #
    # Start string should contain 3 symbols: 1 unchanged, 2 empty and 3 unchanged.
    # String should be a correct julia code. 
    #
    function Code() new("   ") end
  end
  #
  # Organism related data
  # TODO: describe events. e.g.: beforeclone, clone
  #
  type Organism
    #
    # Amount of energy for current organism
    #
    energy::UInt
    #
    # Organism's position in a world
    #
    pos::Helper.Point
    #
    # Code of organism
    #
    code::Code
    #
    # Compiled and covered by function version of code
    #
    fnCode::Function
    #
    # Adds events listening/firing logic to the organism.
    #
    observer::Event.Observer
  end
  #
  # Universal structure for returning a value from event handlers.
  # See "beforeclone", "getenergy" and other events for details.
  #
  type RetObj
    #
    # Return value
    #
    ret::Any
    #
    # Position in a world
    #
    pos::Helper.Point
    #
    # ctor
    #
    RetObj(r = nothing, p = nothing) = (x = new(r); p === nothing ? x : (x.pos = p;x))
  end
  #
  # Creates new organism with default settings.
  # @return {Creature}
  #
  function create(pos::Helper.Point = Helper.Point(1, 1))
    Organism(Config.val(ORGANISM, START_ENERGY), pos, Code(), ()->nothing, Event.create())
  end
  #
  # TODO: optimize this method as deep aspossible
  # Produces one add/change/del mutation on code and returns it's modified version.
  # Probabilities array is an array of three items: add,change,del values. e.g.:
  # [1,2,1] means that add and del mutations will be twice less then change one.
  # Character for adding and changing is in visible ASCII range - 32:126. see ASCII
  # table for details. Change mutation is the most frequent, so it should be first.
  # @param org Organism, which code we have to modify
  # @param prob Probability array (add,change,del). e.g.: [X,X,X]
  #
  function mutate(org::Organism, prob::Array{Int})
    pIndex = Helper.getProbIndex(prob)
    len    = length(org.code.str) - 1
    i      = rand(2:len)

    # 1 - add, 2 - change, 3 - del
    if pIndex === 2 org.code.str     = string(org.code.str[1:i-1], Char(rand(32:126)), org.code.str[i+1:end])
    elseif pIndex === 1 org.code.str = string(org.code.str[1:i-1], Char(rand(32:126)), org.code.str[i:end])
    elseif len > 2 org.code.str      = string(org.code.str[1:i-1], org.code.str[i+1:end]) end
    #
    # Updates compiled version of the code. Only valid code will be applied.
    # TODO: if code is valid, then we have to check in on remote controlled
    # TODO: worker to prevent infinite loop.
    #
    try
      org.fnCode = eval(parse("function body() $(org.code.str) end"))
      #
      # If parsed code doesn't contain mistakes, then current organism
      # should be fed with bonus energy.
      #
      org.energy += Config.val(ORGANISM, GOOD_MUTATION_ENERGY)
    end
  end
  #
  # TODO: describe organism's task function
  #
  function born(org)
    #
    # eg - means Energy Get. Short name to help organism find this name faster.
    # Checks if specified point with (x,y) coordinates has an energy value.
    # Possible values [0:typemax(Int)]. 0 means no energy.
    # @param x X coordinate
    # @param y Y coordinate
    # @return {UInt} Energy value
    #
    function eg(x::Int, y::Int) Creature._getEnergy(org, x, y) end
    #
    # el - means get Energy Left. Short name to help organism find this name faster.
    # Grabs energy from the left point. Grabbibg means decrease energy at point
    # and increase it at organism.
    # @param amount Amount of energy to grab
    # @return {UInt} Amount of grabbed energy
    #
    function el(amount::UInt) Creature._grabEnergy(org, "left", amount) end
    #
    # er - means get Energy Right. Short name to help organism find this name faster.
    # Grabs energy from the right point.
    # @param amount Amount of energy to grab
    # @return {UInt} Amount of grabbed energy
    #
    function er(amount::UInt) Creature._grabEnergy(org, "right", amount) end
    #
    # eu - means get Energy Up. Short name to help organism find this name faster.
    # Grabs energy from the up point.
    # @param amount Amount of energy to grab
    # @return {UInt} Amount of grabbed energy
    #
    function eu(amount::UInt) Creature._grabEnergy(org, "up", amount) end
    #
    # ed - means get Energy Down. Short name to help organism find this name faster.
    # Grabs energy from the down point.
    # @param amount Amount of energy to grab
    # @return {Int} Amount of grabbed energy
    #
    function ed(amount::UInt) Creature._grabEnergy(org, "down", amount) end
    #
    # sl - means make Step Left. Short name to help organism find this name faster.
    # Makes one step left. It decreases organism's x coodinate by 1.
    #
    function sl() Creature._step(org, "left") end
    #
    # sr - means make Step Right. Short name to help organism find this name faster.
    # Makes one step right. It increases organism's x coodinate by 1.
    #
    function sr() Creature._step(org, "right") end
    #
    # su - means make Step Up. Short name to help organism find this name faster.
    # Makes one step up. It decrease organism's y coodinate by 1.
    #
    function su() Creature._step(org, "up") end
    #
    # sd - means make Step Down. Short name to help organism find this name faster.
    # Makes one step down. It increase organism's y coodinate by 1.
    #
    function sd() Creature._step(org, "down") end
    #
    # c - means Clone. Short name to help organism find this name faster.
    # Makes organism clone. During cloning new organism will get few
    # mutations. It will be a difference from father's organism. This
    # function should find "free" place for new organism around it.
    # If there is no "free" place, then cloning will be declined.
    #
    function c() Creature._clone(org) end

    #
    # -----------------------------------------------------------------------
    # This is main loop, where organism lives. It's body will be changed soon
    # by mutations. This loop must be after ambedded functions.
    #
    return function life()
      while org.energy > UInt(0)
        produce()
        #
        # It's okay if organism has errors and throws exceptions. It's possible
        # that these errors will be fixed by future mutations.
        #
        try
          org.fnCode()
          #
          # TODO: temporary code. shows correct organisms
          #
          println(org.code.str)
        end
      end
    end
  end
  #
  # Clones an organism. It only fires an event. Clonning will be
  # processes in a Manager module. See it for details.
  # @param {Organism} creature Instance of parent organism.
  #
  function _clone(creature::Organism)
    Event.fire(creature.observer, "clone", creature)
  end
  #
  # Checks amount of organism's energy in {x,y} point
  # @param x X coordinate
  # @param y Y coordinate
  #
  function _getEnergy(creature::Organism, x::Int, y::Int)
    #
    # This map will be used for communication between this organism and
    # some outside object. "ret" will be contained amount of energy.
    #
    retObj = RetObj()
    #
    # Listener of "getenergy" should set amount of energy in retObj.ret
    # Possible values [0...typemax(Int)]
    #
    Event.fire(creature.observer, "getenergy", creature, Helper.Point(x, y), retObj)
    #
    # Return value
    #
    retObj.ret
  end
  #
  # Universal method for grabbing energy from the world. It grabs at
  # the position up, left, bottom or right from current organism.
  # @param creature Current organism
  # @param dir      Direction ("left", "right", "up", "down")
  # @param amount   Amount of energy to grab
  #
  function _grabEnergy(creature::Organism, dir::ASCIIString, amount::UInt)
    #
    # This map will be used for communication between this organism and
    # some outside object. "ret" key will be contained amount of grabbed energy.
    #
    retObj = RetObj()
    #
    # Listener of "grab$dir" should set amount of energy in retObj.ret
    # Possible values [0...amount]
    #
    Event.fire(creature.observer, "grab$dir", creature, amount, retObj)
    creature.energy += retObj.ret

    retObj.ret
  end
  #
  # Makes one step with specified direction
  # @param creature Organism to move
  # @param dir Direction ("left", "right", "up", "down")
  #
  function _step(creature::Organism, dir::ASCIIString)
    #
    # This map will be used for communication between this organism and
    # some outside object. "ret" key will be contained amount of grabbed energy.
    #
    retObj = RetObj()
    #
    # Listener of "step$dir" should set new position in retObj.ret
    #
    Event.fire(creature.observer, "step$dir", creature, retObj)
    creature.pos = retObj.pos
  end
end