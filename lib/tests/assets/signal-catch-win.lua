local signal = require"os.signal"

signal.handle(signal.SIGBREAK, function (_, crtlEvent)
	if crtlEvent then
		os.exit(0)
	end
end)

local counter = 0
while counter < 10000 do
	counter = counter + 1
	os.sleep(1, "ms")
end

os.exit(1)
