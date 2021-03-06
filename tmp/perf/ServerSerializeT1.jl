#
# Calculates requests per second from client to server without response, but
# using only naked sockets.
# Results: rps: 13160.318995561785, time: 75.98600006103516
#
type T
  x::Int
end
server = listen(2000)
sock   = accept(server)
function run()
  local t::T = T(rand(1:100))
  for i=1:1000000 serialize(sock, t) end
end
