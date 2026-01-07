local signal = require"os.signal"
signal.handle(signal.SIGTERM, function ()
	os.exit(0)
end)

if signal.SIGBREAK ~= nil then
	signal.handle(signal.SIGBREAK, function ()
		os.exit(0)
	end)
end

signal.handle(signal.SIGINT, function ()
	os.exit(0)
end)

local counter = 0
while counter < 10000 do
	counter = counter + 1
	os.sleep(1, "ms")
end

os.exit(1)
