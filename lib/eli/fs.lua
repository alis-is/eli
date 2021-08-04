local io = require 'io'
local _eliPath = require 'eli.path'
local dir = _eliPath.dir
local combine = _eliPath.combine
local _util = require 'eli.util'
local efsLoaded, efs = pcall(require, 'eli.fs.extra')
local hash = require 'lmbed_hash'

local function _check_efs_available(operation)
    if not efsLoaded then
        if operation ~= nil and operation ~= '' then
            error('Extra fs api not available! Operation ' .. operation .. ' failed!')
        else
            error('Extra fs api not available!')
        end
    end
end

---#DES 'fs.read_file'
---
---Reads file from path
---@param path string
---@return string
local function read_file(path)
    local f = assert(io.open(path, 'r'), 'No such a file or directory - ' .. path)
    local result = f:read('a*')
    f:close()
    return result
end

---#DES 'fs.write_file'
---
---Writes content into file in specified path
---@param path string
---@param content string
local function write_file(path, content)
    local f = assert(io.open(path, 'w'), 'No such a file or directory - ' .. path)
    f:write(content)
    f:close()
end

---#DES 'fs.copy_file'
---
---Copies file from src to dst
---@param src string
---@param dst string
local function copy_file(src, dst)
    assert(src ~= dst, 'Identical source and destiontion path!')
    local srcf = assert(io.open(src, 'r'), 'No such a file or directory - ' .. src)
    local dstf = assert(io.open(dst, 'w'), 'Failed to open file for write - ' .. dst)

    local size = 2 ^ 12 -- 4K
    while true do
        local block = srcf:read(size)
        if not block then
            break
        end
        dstf:write(block)
    end
    srcf:close()
    dstf:close()
end

---Creates directory
---@param path string
---@param mkdir fun(path: string)
---@param scopeName string
local function _internal_mkdir(path, mkdir, scopeName)
    local _mkdir = type(mkdir) == 'function' and mkdir
    if type(_mkdir) ~= 'function' and efsLoaded then
        _mkdir = efs.mkdir
    end
    if type(_mkdir) ~= 'function' then
        -- we do not have any mkdir avaialble
        -- we can siletntly ifnore this if dir already exists
        local f = io.open(path)
        if f == nil then
            _check_efs_available(scopeName)
        end
        local _, _, _errorCode = f:read(0)
        if _errorCode == 21 or (f:read(0) and f:seek('end') ~= 0) then
            -- dir already exists
            return
        end
        _check_efs_available(scopeName)
    end
    _mkdir(path)
end

---#DES 'fs.mkdir'
---
---Creates directory
---@param path string
---@param mkdir fun(path: string)
local function mkdir(path, mkdir)
    _internal_mkdir(path, mkdir, 'mkdir')
end

---#DES 'fs.mkdirp'
---
---Creates directory recursively
---@param path string
---@param mkdir fun(path: string)
local function mkdirp(path, mkdir)
    local parent = dir(path)
    if parent ~= nil then
        mkdirp(parent, mkdir)
    end
    _internal_mkdir(path, mkdir, 'mkdirp')
end

---#DES 'fs.create_dir'
---
---Creates directory (recursively if recurse set to true)
---@param path string
---@param recurse boolean
---@param mkdir fun(path: string)
local function create_dir(path, recurse, mkdir)
    if recurse then
        mkdirp(path, mkdir)
    else
        _internal_mkdir(path, mkdir, 'create_dir')
    end
end

---@class FsRemoveOptions
---@field recurse boolean
---@field contentOnly boolean

---#DES 'fs.remove'
---
---Removes file or directory
---(if EFS is false dir has to be empty and options are ignored)
---@param path string
---@param options FsRemoveOptions
local function _remove(path, options)
    if not efsLoaded then
        -- fallback to os delete
        local _ok, _error = os.remove(path)
        assert(_ok, _error or '')
    end

    if type(options) ~= 'table' then
        options = {}
    end

    local recurse = options.recurse
    local contentOnly = options.contentOnly
    options.contentOnly = false -- for recursive calls

    if efs.file_type(path) == nil then
        return
    end
    if efs.file_type(path) == 'file' then
        local _ok, _error = os.remove(path)
        assert(_ok, _error or '')
    end
    if recurse then
        for o in efs.iter_dir(path) do
            local fullPath = combine(path, o)
            if o ~= '.' and o ~= '..' then
                if efs.file_type(fullPath) == 'file' then
                    local _ok, _error = os.remove(fullPath)
                    assert(_ok, _error or '')
                elseif efs.file_type(fullPath) == 'directory' then
                    _remove(fullPath, options)
                end
            end
        end
    end
    if not contentOnly then
        efs.rmdir(path)
    end
end

---#DES 'fs.move'
---
---Renames file or directory
---@param src string
---@param dst string
local function move(src, dst)
    return require 'os'.rename(src, dst)
end

---#DES 'fs.exists'
---
---Returns true if specified path exists
---@param path string
local function exists(path)
    if io.open(path) then
        return true
    else
        return false
    end
end

---@class FsHashFileOptions
---@field type '"sha256"'| '"sha512"'
---@field hex boolean

---#DES 'fs.hash_file'
---
---Hashes file in specified path
---@param path string
---@param options FsHashFileOptions
local function hash_file(path, options)
    if type(options) ~= 'table' then
        options = {}
    end
    if options.type ~= 'sha512' then
        options.type = 'sha256'
    end
    local srcf = assert(io.open(path, 'r'), 'No such a file or directory - ' .. path)
    local size = 2 ^ 12 -- 4K

    if options.type == 'sha256' then
        local ctx = hash.sha256_init()
        while true do
            local block = srcf:read(size)
            if not block then
                break
            end
            hash.sha256_update(ctx, block)
        end
        return hash.sha256_finish(ctx, options.hex)
    else
        local ctx = hash.sha512_init()
        while true do
            local block = srcf:read(size)
            if not block then
                break
            end
            hash.sha512_update(ctx, block)
        end
        return hash.sha512_finish(ctx, options.hex)
    end
end

local function _direntry_type(entry)
    if type(entry) == 'string' then
        return efs.file_type(entry)
    elseif type(entry) == 'userdata' and entry.__type == 'ELI_DIRENTRY' then
        return entry:type()
    end
    return nil
end

local function _read_dir_recurse(path, asDirEntries, lenOfPathToRemove)
    if type(lenOfPathToRemove) ~= 'number' then
        lenOfPathToRemove = 0
    end
    local _entries = efs.read_dir(path, asDirEntries)
    local result = {}
    for _, entry in ipairs(_entries) do
        local _path = asDirEntries and entry:fullpath() or combine(path, entry)
        if _direntry_type(asDirEntries and entry or _path) == 'directory' then
            local _subEntries = _read_dir_recurse(_path, asDirEntries, lenOfPathToRemove)
            for _, subEntry in ipairs(_subEntries) do
                table.insert(result, subEntry)
            end
        end
        table.insert(result, asDirEntries and entry or _path:sub(lenOfPathToRemove + 1))
    end
    return result
end

---@class FsReadDirOptions
---@field recurse boolean
---@field returnFullPaths boolean
---@field asDirEntries boolean

---@class DirEntry
---@field name string
---@field type string
---@field fullpath string
---@field __type '"ELI_DIRENTRY"'

---#DES 'fs.read_dir'
---
---Reads directory and returns dir entire or paths based on options
---@param path string
---@param options FsReadDirOptions
---@return string[]|DirEntry[]
local function _read_dir(path, options)
    _check_efs_available('read_dir')
    if type(options) ~= 'table' then
        options = {}
    end
    if options.recurse then
        local _lenOfPathToRemove = path:match('.*/') and #path or #path + 1
        if options.returnFullPaths then
            _lenOfPathToRemove = 0
        end
        return _read_dir_recurse(path, options.asDirEntries, _lenOfPathToRemove)
    end
    local _result = efs.read_dir(path, options.asDirEntries)
    if not options.asDirEntries and options.returnFullPaths then
        for i, v in ipairs(_result) do
            _result[i] = combine(path, v)
        end
    end
    return _result
end

---@class FsChownOptions
---@field recurse boolean
---@field recurseIgnoreErrors boolean

---#DES 'fs.chown'
---
---Sets ownership of file in the path
---@param path string
---@param uid integer
---@param gid integer
---@param options FsChownOptions
---@return boolean, string, number
local function _chown(path, uid, gid, options)
    _check_efs_available('chown')
    if type(options) ~= 'table' then
        options = {}
    end

    if not options.recurse or efs.file_type(path) ~= 'directory' then
        return efs.chown(path, uid, gid)
    end

    if type(options.recurseIgnoreErrors) ~= 'boolean' then
        options.recurseIgnoreErrors = true
    end

    local _ok, _error, _errno = efs.chown(path, uid, gid)
    if not _ok and not options.recurseIgnoreErrors then
        return _ok, _error, _errno
    end

    local _paths = _read_dir(path, {recurse = true, returnFullPaths = true})
    for _, _path in ipairs(_paths) do
		_ok, _error, _errno = efs.chown(_path, uid, gid)
		if not _ok and not options.recurseIgnoreErrors then
			return _ok, _error, _errno
		end
    end
	return true
end

local fs = {
    write_file = write_file,
    read_file = read_file,
    copy_file = copy_file,
    mkdir = mkdir,
    mkdirp = mkdirp,
    create_dir = create_dir,
    remove = _remove,
    exists = exists,
    move = move,
    ---#DES 'fs.EFS'
    ---@type boolean
    EFS = efsLoaded,
    hash_file = hash_file,
    read_dir = _read_dir,
    chown = _chown
}

if efsLoaded then
    local result = _util.generate_safe_functions(_util.merge_tables(fs, efs))
    result.safe_iter_dir = nil -- not supported
    return result
else
    return _util.generate_safe_functions(fs)
end
