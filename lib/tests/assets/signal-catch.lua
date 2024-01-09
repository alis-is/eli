local signal = require"os.signal"
signal.handle(signal.SIGTERM, function ()
	os.exit(0)
end)

signal.handle(signal.SIGBREAK, function ()
	os.exit(0)
end)

local counter = 0
while counter < 10 do
	counter = counter + 1
	os.sleep(1)
end

os.exit(1)
