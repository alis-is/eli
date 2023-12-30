local signal = require"os.signal"
signal.handle(signal.SIGINT, function ()
	os.exit(0)
end)

local counter = 0
while counter < 20 do
	counter = counter + 1
	os.sleep(1)
end

os.exit(1)
