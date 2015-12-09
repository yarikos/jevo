#
# TODO:
#
push!(LOAD_PATH, pwd())

import Client
using Creature
using Config
using RpcApi

function onAnswer(ans::Connection.Answer)
  println(ans)
end

con = Client.create(ip"127.0.0.1", Config.val(CONNECTION, SERVER_PORT))
if con === false quit() end

Event.on(con.observer, Client.EVENT_ANSWER, onAnswer)
#Client.request(con, RPC_GET_REGION)