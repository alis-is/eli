local is_loaded, worker = pcall(require, "eli.worker.extra")

if not is_loaded then
	return {
		EWORKER = false,
	}
end

worker.EWORKER = true

return worker
