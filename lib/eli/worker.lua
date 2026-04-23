local util = require"eli.util"
local is_loaded, raw_worker = pcall(require, "eli.worker.extra")
local is_os_loaded, eli_os = pcall(require, "eli.os")

if not is_loaded then
	return {
		EWORKER = false,
	}
end

local worker = {
	EWORKER = true,
}

local WorkerTask = {}
WorkerTask.__index = WorkerTask

local function is_task(value)
	return type(value) == "table" and getmetatable(value) == WorkerTask and value.__task ~= nil
end

local function unwrap_task(task)
	if is_task(task) then
		return task.__task
	end
	return task
end

local function wrap_task(task)
	return setmetatable({
		__task = task,
	}, WorkerTask)
end

local function validate_function(fn)
	local upvalue_index = 1
	while true do
		local upvalue_name = debug.getupvalue(fn, upvalue_index)
		if upvalue_name == nil then
			return true
		end
		if upvalue_name ~= "_ENV" then
			return nil, "worker functions cannot capture upvalues"
		end
		upvalue_index = upvalue_index + 1
	end
end

local function dump_function(fn)
	local is_valid, validation_error = validate_function(fn)
	if not is_valid then
		return nil, validation_error
	end

	local dumped_ok, dumped_or_error = pcall(string.dump, fn, true)
	if not dumped_ok then
		return nil, dumped_or_error
	end

	return dumped_or_error
end

local function load_file_job(path)
	local compiled, load_error = loadfile(path)
	if compiled == nil then
		return nil, load_error
	end

	return dump_function(compiled)
end

local function normalize_job(job)
	if type(job) == "function" then
		return dump_function(job)
	end

	if type(job) == "string" then
		local file = io.open(job, "rb")
		if file ~= nil then
			file:close()
			return load_file_job(job)
		end
		return job
	end

	return nil, "worker job must be a function, file path, or dumped chunk"
end

local function sleep_wait_poll()
	if is_os_loaded and type(eli_os.sleep) == "function" then
		eli_os.sleep(1)
	end
end

function WorkerTask:join()
	return self.__task:join()
end

function WorkerTask:is_done()
	return self.__task:is_done()
end

function WorkerTask:wait()
	return worker.wait(self)
end

function worker.spawn(job, context)
	local normalized_job, normalize_error = normalize_job(job)
	if normalized_job == nil then
		return nil, normalize_error
	end

	local task, err = raw_worker.spawn(normalized_job, context)
	if task == nil then
		return nil, err
	end

	return wrap_task(task)
end

function worker.wait(task_or_tasks)
	if is_task(task_or_tasks) then
		return task_or_tasks:join()
	end

	if not util.is_array(task_or_tasks) then
		return nil, "worker.wait expects a task or an array of tasks"
	end

	if #task_or_tasks == 0 then
		return nil, "worker.wait expects at least one task"
	end

	while true do
		for index, task in ipairs(task_or_tasks) do
			local raw_task = unwrap_task(task)
			if raw_task:is_done() then
				return index, raw_task:join()
			end
		end
		sleep_wait_poll()
	end
end

function worker.run(job, context)
	local task, err = worker.spawn(job, context)
	if task == nil then
		return nil, err
	end

	return worker.wait(task)
end

function worker.channel(...)
	return raw_worker.channel(...)
end

return worker
