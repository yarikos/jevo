#
# Multi connection server implementation. Works through TCP
# protocol for connection with clients. Fully asynchronous and
# one threaded. It implements RPC-similar logic, where clients
# may run functions with parameters on server and obtain results.
#
# It uses green threads (or coroutines) inside. See this link
# http://julia.readthedocs.org/en/latest/manual/control-flow/#man-tasks
# for details regarding coroutines. Because of green threads,
# it uses "magic" inside: there are two places in this module,
# where this magic happens. First place is some main code or
# code, which creates the server and run it. It may be any
# other module or code. Second place is internal server's event
# loop machine, which is used for accepting clients connections
# and obtaining data (see @async macro in code). So, if you create
# a server with create() method, it will return Server's data
# object imediately. Calling run() method it also returns control
# back at that moment, but in reality server starts to listen
# clients in some loop (in our example this loop is out the run()
# code - in a parent code). After running, server creates one task
# (green thread) per one connection. To run server out you have to
# call yield() function in your (parent) code all the time.
# See example below for details:
#
#     #
#     # This callback function will be called as many times
#     # as server will obtain client's request (command)
#     #
#     function onCommand(cmd::Connection.Command, ans::Connection.Answer)
#       # This is how we create the answer for client.
#       # ans.data has type Any.
#       ans.data = "answer"
#     end
#     #
#     # Creation of server doesn't run it
#     #
#     connection = Server.create(ip"127.0.0.1", 2016)
#     #
#     # Before running we have to bind command event listeners
#     #
#     Event.on(connection.observer, Server.EVENT_BEFORE_RESPONSE, onCommand)
#     #
#     # This is how our server run itself
#     #
#     Server.run(connection)
#
#     ...
#
#     #
#     # This is client's (parent) code, which was mentioned before
#     #
#     while <condition>
#       # ...your stuff is here...
#
#       #
#       # This call is used for switching between Tasks (green threads),
#       # checks new connections, obtaining commands from clients,...
#       yield()
#     end
#     ...
#     #
#     # This is how we stop our server
#     #
#     Server.stop(connection)
#
# You have two possibilities how to run main code: you may have
# a loop (like in example above) or your code may wait for
# connection in background (without blocking loop). For example,
# you may run this example in a REPL without infinite loop at the
# end. In this case, you don't need to call yield() manually.
#
# Events:
#     command{Connection.Command, Connection.Answer} Fires if new
#            command was obtained from client. Contains command
#            itself and special answer object, where you may set your
#            custom data.
#
# @author DeadbraiN
# TODO: add EVENT_AFTER_RESPONSE logic description
module Server
  import Event
  import Connection
  import Helper

  export create
  export run
  export stop
  export isOk
  export EVENT_BEFORE_RESPONSE
  export EVENT_AFTER_RESPONSE
  export ServerConnection
  #
  # Name of the event, which is fired if answer from client's
  # request is obtained.
  #
  const EVENT_AFTER_RESPONSE  = "after-response"
  #
  # Name of the event, which is fired if client sent us a command. If
  # this event fires, then specified command should be runned here - on
  # server side.
  #
  const EVENT_BEFORE_RESPONSE = "before-response"
  #
  # Describes a server. It contains clients sockets, tasks, server object
  # and it's observer.
  #
  type ServerConnection
    tasks   ::Array{Task, 1}
    socks   ::Array{Base.TCPSocket, 1}
    server  ::Base.TCPServer
    observer::Event.Observer
    host    ::Base.IPAddr
    port    ::Int
  end
  #
  # Creates a server. Returns special server's data object, which identifies
  # this server and takes an ability to listen it events. It also contains
  # server's related tasks. See Server.ServerConnection type for
  # details. It doesn't run the server (use run() method for this), but
  # it start to listen specified host and port using Base.listen() method.
  # Setting port to zero you may create "empty" connection. In fact, in
  # this case, server will not be created and will not work.
  # @param host Host we are listening to
  # @param port Port we are listening to
  # @return {Server.ServerConnection} Server's related data object
  #
  function create(host::Base.IPAddr, port::Integer)
    local tasks::Array{Task, 1} = Task[]
    local socks::Array{Base.TCPSocket, 1} = Base.TCPSocket[]
    local obs::Event.Observer = Event.create()
    local con::ServerConnection

    if port > 0
      try
        local server::Base.TCPServer = listen(host, port)
        con = ServerConnection(tasks, socks, server, obs, host, port)
        Helper.info(string("Server created: ", host, ":", port))
        return con
      catch e
        Helper.warn("Server.create(): $e")
      end
    end

    ServerConnection(tasks, socks, Base.TCPServer(), obs, host, port)
  end
  #
  # Runs the server. Starts listening clients connections
  # and starts answering on requests. This method implements
  # main asynchronous client-server communication logic. Here
  # all green threads are used. See this link for details:
  # http://julia.readthedocs.org/en/latest/manual/control-flow/#man-tasks
  # Don't remember to call yield() in your main code (or loop).
  # It also calls _update() for removing closed connections
  # ans failed tasks.
  # @param con Server connection object returned by Server.create()
  # @return {Bool} Run status
  #
  function run(con::Server.ServerConnection)
    if !isOk(con)
      Helper.warn("Server.run(): Server wasn\'t created correctly. Try to change Server.create() arguments.")
      return false
    end

    Helper.info(string("Server has run: ", con.host, ":", con.port))
    @async begin
      while true
        try
          #
          # This line handles new connections
          #
          push!(con.socks, accept(con.server))
        catch e
          #
          # Possibly Server.stop() was called.
          #
          if Helper.isopen(con.server) === false
            local sock::Base.TCPSocket
            for sock in con.socks close(sock) end
            break
          end
          Helper.warn("Server.run(): $e")
        end
        sock = con.socks[length(con.socks)]
        push!(con.tasks, @async while Helper.isopen(sock)
          _answer(sock, con.observer)
          _update(con)
        end)
      end
    end
    #
    # This yield() prevents server from error:
    # ArgumentError("server not connected, make sure \"listen\" has been called")
    #
    yield()
    true
  end
  #
  # Makes request to client. This method is not blocking. It returns
  # just after the call. Answer will be obtained in run() method
  # async loop.
  # @param con Connection object returned by create() method
  # @param fn Callback function id, which will be called if answer
  #           will be obtained from client.
  # @param args Custom fn arguments
  # @return true - request was sent, false wasn't
  #
  function request(con::ServerConnection, fn::Integer, args...)
    if !Helper.isopen(con.sock) return false end
    #
    # This line is non blocking one
    #
    try
      serialize(con.sock, Connection.Command(fn, [i for i in args]))
    catch e
      Helper.warn("Server.request(): $e")
      close(con.sock)
      return false
    end

    true
  end
  #
  # Returns server's state. true means - created and run.
  # @param con Client connection state
  # @return {Bool}
  #
  function isOk(con::Server.ServerConnection)
    Helper.isopen(con.server)
  end
  #
  # Stops the server. Stops listening all connections and drops
  # existing if exist.
  # @param con Server object returned by create() method.
  #
  function stop(con::Server.ServerConnection)
    try
      local sock::Base.TCPSocket
      for sock in con.socks close(sock) end
      close(con.server)
      Helper.info(string("Server has stopped: ", con.host, ":", con.port))
    catch e
      Helper.warn("Server.stop(): $e")
    end
  end
  #
  # This method should be called in main server's loop or outside
  # code for removing stopped tasks and sockets (connections)
  # between clients and this server. See an example at the beginning
  # of this module for details.
  # @param con Connection object returned by create() method
  #
  function _update(con::Server.ServerConnection)
    i::Int = 1

    while i <= length(con.socks)
      if Helper.isopen(con.socks[i])
       	i += 1
      else
        deleteat!(con.socks, i)
        deleteat!(con.tasks, i)
      end
    end
  end
  #
  # Reads one command from client's socket and fires an event
  # to main code. After that, writes an answer into the socket
  # back.
  # @param sock Client's socket
  # @param obs Observer for firing an event to "parent" code
  #
  function _answer(sock::Base.TCPSocket, obs::Event.Observer)
    local data::Any = null

    try
      #
      # Right now, only two types of responses are supported:
      # answers after server request(Connection.Answer) and
      # client requests (Connection.Command).
      #
      data = deserialize(sock)
      if typeof(data) === Connection.Answer
        Event.fire(obs, EVENT_AFTER_RESPONSE, data)
      else # Connection.Command
        local ans::Connection.Answer = Connection.Answer(0, null)
        Event.fire(obs, EVENT_BEFORE_RESPONSE, data, ans)
        serialize(sock, ans)
      end
    catch e
      #
      # This yield() updates sockets states
      #
      yield()
      if isa(e, EOFError)
        close(sock)
      elseif Helper.isopen(sock)
        Helper.warn("Server._answer(): $e")
      end
    end
  end
end
