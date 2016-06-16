#
# Very similar to RemoteWorld module, but works in Real Time. In
# this case RT - means Real Time. It listens remote server and
# shows only differences in remote world, but not all plane.
# It uses canvas within a window for showing dots. This module works
# in a simple way: first, you have to create RemoteWorldRT object
# calling create() function. This object, used in all functions.
# create() doesn't start displaying world. For this, you have to
# call start() function. To stop displaying, call stop(). Speed
# of showing depends on network speed.
#
# @author DeadbraiN
# TODO: describe two clients here (slow and pooling)
module RemoteWorldRT
  import Event
  import CanvasWindow
  import Connection
  import Client
  import RpcApi
  import FastApi
  import Config
  import Helper

  using Debug

  export create
  export start
  export stop

  export RemoteDataRT
  #
  # Contains data of for remote host, from where we displaying
  # world's region and shows it on a canvas.
  #
  type RemoteDataRT
    #
    # Required fields
    #
    cmdCon::Client.ClientConnection
    poolingCon::Client.ClientConnection
    win::CanvasWindow.Window
    #
    # Lazy loading fields
    #
    poolingBeforeCb::Function
    cmdAfterCb::Function
    ts::Float64
    poolingRequests::Int
    oldRequests::Int

    RemoteDataRT(
      cmdCon    ::Client.ClientConnection,
      poolingCon::Client.ClientConnection,
      win       ::CanvasWindow.Window
    ) = new(cmdCon, poolingCon, win)
  end
  #
  # Creates connection with remote host for display pixels from remote world.
  # @param host Remote host we are connecting to
  # @param cmdPort Remote port for commands
  # @param poolingPort Remote port for pooling requests
  # @return {RemoteDataRT}
  #
  function create(host::Base.IPAddr, cmdPort::Int, poolingPort::Int)
    RemoteDataRT(
      Client.create(host, cmdPort),
      Client.create(host, poolingPort, true),
      CanvasWindow.create(Config.val(:WORLD_WIDTH), Config.val(:WORLD_HEIGHT))
    )
  end
  #
  # Start displaying remote plane. It handles requests from remote
  # server with dots diffs. Response of first request will be all dots
  # of remote plane. All other requests will be runned from remove
  # server back to this client.
  # @param rd Remote world data object. See create()
  #
  function start(rd::RemoteDataRT)
    rd.poolingBeforeCb = (sock::Base.TCPSocket, data::Array{Any, 1}, ans::Connection.Answer) -> _onDotUpdate(rd, data)
    rd.cmdAfterCb      = (ans::Connection.Answer) -> _onRegion(rd, ans)
    rd.ts              = time()
    rd.poolingRequests = 0
    rd.oldRequests     = 0
    Event.on(rd.poolingCon.observer, Connection.EVENT_BEFORE_RESPONSE, rd.poolingBeforeCb)
    Event.on(rd.cmdCon.observer, Connection.EVENT_AFTER_REQUEST, rd.cmdAfterCb)
    Client.request(rd.cmdCon, RpcApi.RPC_SET_WORLD_STREAMING)
  end
  #
  # Stops displaying organism's world. Closes the connection.
  # @param rd Remote world data object
  #
  function stop(rd::RemoteDataRT)
    Event.off(rd.poolingCon.observer, Connection.EVENT_BEFORE_RESPONSE, rd.poolingBeforeCb)
    Event.off(rd.cmdCon.observer, Connection.EVENT_AFTER_REQUEST, rd.cmdAfterCb)
    Client.stop(rd.cmdCon)
    Client.stop(rd.poolingCon)
    CanvasWindow.destroy(rd.win)
  end
  #
  # Handler of remote server pooling request. Request's data contains
  # x::Uint16, y::UInt16, color::UInt32, ips::UInt16
  # @param rd Remote Data object
  # @param data Command related data
  #
  function _onDotUpdate(rd::RemoteDataRT, data::Array{Any, 1})
    if time() - rd.ts > 1.0
      rd.ts = time()
      rd.oldRequests = rd.poolingRequests
      rd.poolingRequests = 0
    end
    rd.poolingRequests += 1

    CanvasWindow.title(rd.win, string("ips: ", data[4], ", rps: ", rd.oldRequests))
    CanvasWindow.dot(rd.win, Int(data[1]), Int(data[2]), data[3])
    CanvasWindow.update(rd.win)
  end
  #
  # Handler of RpcApi.RPC_SET_WORLD_STREAMING request
  # @param data Answer object with region data
  #
  function _onRegion(rd::RemoteDataRT, ans::Connection.Answer)
    if ans.data === false Helper.error("Only one viewer is supported"); return nothing end
    local region::Array{UInt32, 2} = ans.data.reg

    CanvasWindow.title(rd.win, string("ips: ", ans.data.ips, ", rps: 0"))
    for x::Int in 1:size(region)[2]
      for y::Int in 1:size(region)[1]
        CanvasWindow.dot(rd.win, x, y, UInt32(region[y, x]))
      end
    end
    CanvasWindow.update(rd.win)
    #
    # This command means "turn on server pooling"
    #
    Client.request(rd.poolingCon, UInt8(FastApi.API_UINT8), UInt8(0))
  end
end