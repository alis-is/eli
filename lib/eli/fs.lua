local io = require 'io'
local _eliPath = require 'eli.path'
local dir = _eliPath.dir
local combine = _eliPath.combine
local _util = require 'eli.util'
local efsLoaded, efs = pcall(require, 'eli.fs.extra')

local function _check_efs_available(operation)
    if not efsLoaded then
        if operation ~= nil and operation ~= '' then
            error('Extra fs api not available! Operation ' .. operation .. ' failed!')
        else
            error('Extra fs api not available!')
        end
    end
end

local fs = {
    ---#DES 'fs.EFS'
    ---@type boolean
    EFS = efsLoaded
}

---@class AccessFileOptions
---@field binaryMode boolean

---#DES 'fs.read_file'
---
---Reads file from path
---@param path string
---@param options AccessFileOptions?
---@return string
function fs.read_file(path, options)
    ---@type AccessFileOptions
    options = _util.merge_tables({ binaryMode = true }, options, true)
    local f = assert(io.open(path, options.binaryMode and "rb" or "r"), 'No such a file or directory - ' .. path)
    local result = f:read('a*')
    f:close()
    return result
end

---#DES 'fs.write_file'
---
---Writes content into file in specified path
---@param path string
---@param content string
---@param options AccessFileOptions?
function fs.write_file(path, content, options)
    ---@type AccessFileOptions
    options = _util.merge_tables({ binaryMode = true }, options, true)
    local f = assert(io.open(path, options.binaryMode and "wb" or "w"), 'No such a file or directory - ' .. path)
    f:write(content)
    f:close()
end

---#DES 'fs.copy_file'
---
---Copies file from src to dst
---@param src string | file*
---@param dst string | file*
---@param options AccessFileOptions?
function fs.copy_file(src, dst, options)
    assert(src ~= dst, 'Identical source and destiontion path!')
    assert(type(src) == "string" or (tostring(src):find("file") == 1),
        'Invalid type of source! (Has to be string or file*)')
    assert(type(dst) == "string" or (tostring(dst):find("file") == 1),
        'Invalid type of destination! (Has to be string or file*)')

    options = _util.merge_tables({ binaryMode = true }, options, true)
    ---@type file*, file*
    local srcf, dstf
    if type(src) == "string" then
        srcf = assert(io.open(src, options.binaryMode and "rb" or "r"),
            'No such a file or directory - ' .. src)
    else
        srcf = src
    end
    if type(dst) == "string" then
        dstf = assert(io.open(dst, options.binaryMode and "wb" or "w"),
            'Failed to open file for write - ' .. dst)
    else
        dstf = dst
    end

    local size = 2 ^ 12 -- 4K
    while true do
        local block = srcf:read(size)
        if not block then
            break
        end
        dstf:write(block)
    end
    if type(src) == "string" then srcf:close() end
    if type(dst) == "string" then dstf:close() end
end

---Creates directory
---@param path string
---@param mkdir (fun(path: string))?
---@param scopeName string
local function _internal_mkdir(path, mkdir, scopeName)
    local _mkdir = type(fs.mkdir) == 'function' and mkdir
    if type(_mkdir) ~= 'function' and efsLoaded then
        _mkdir = efs.mkdir
    end
    if type(_mkdir) ~= 'function' then
        -- we do not have any mkdir avaialble
        -- we can siletntly ignore this if dir already exists
        local f = io.open(path)
        if f == nil then
            _check_efs_available(scopeName)
            return -- we error line above if efs not available
        end
        local _, _, _errorCode = f:read(0)
        if _errorCode == 21 or (f:read(0) and f:seek('end') ~= 0) then
            -- dir already exists
            return
        end
        _check_efs_available(scopeName)
        return -- we error line above if efs not available
    end
    _mkdir(path)
end

---#DES 'fs.mkdir'
---
---Creates directory
---@param path string
---@param mkdir (fun(path: string))?
function fs.mkdir(path, mkdir)
    _internal_mkdir(path, mkdir, 'mkdir')
end

---#DES 'fs.mkdirp'
---
---Creates directory recursively
---@param path string
---@param mkdir (fun(path: string))?
function fs.mkdirp(path, mkdir)
    local parent = dir(path)
    if parent ~= nil then
        fs.mkdirp(parent, mkdir)
    end
    _internal_mkdir(path, mkdir, 'mkdirp')
end

---#DES 'fs.create_dir'
---
---Creates directory (recursively if recurse set to true)
---@param path string
---@param recurse boolean
---@param mkdir fun(path: string)
function fs.create_dir(path, recurse, mkdir)
    if recurse then
        fs.mkdirp(path, mkdir)
    else
        _internal_mkdir(path, mkdir, 'create_dir')
    end
end

---@class FsRemoveOptions
---@field recurse boolean
---@field contentOnly boolean
---@field followLinks boolean

---#DES 'fs.remove'
---
---Removes file or directory
---(if EFS is false dir has to be empty and options are ignored)
---@param path string
---@param options FsRemoveOptions?
function fs.remove(path, options)
    if not efsLoaded then
        -- fallback to os delete
        local _ok, _error = os.remove(path)
        assert(_ok, _error or '')
    end

    options = _util.merge_tables({}, options, true)
    local recurse = options.recurse
    local contentOnly = options.contentOnly
    options.contentOnly = false -- for recursive calls

    local _type_check = options.followLinks and efs.file_type or efs.link_type
    if _type_check(path) == nil then
        return
    end
    if _type_check(path) == 'file' then
        local _ok, _error = os.remove(path)
        assert(_ok, _error or '')
        return
    end
    if recurse then
        for o in efs.iter_dir(path) do
            local fullPath = combine(path, o)
            if o ~= '.' and o ~= '..' then
                if _type_check(fullPath) == 'file' then
                    local _ok, _error = os.remove(fullPath)
                    assert(_ok, _error or '')
                elseif _type_check(fullPath) == 'directory' then
                    fs.remove(fullPath, options)
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
function fs.move(src, dst)
    return require 'os'.rename(src, dst)
end

---#DES 'fs.exists'
---
---Returns true if specified path exists
---@param path string
function fs.exists(path)
    local _ok, _, _code = os.rename(path, path)
    return _ok or _code == 13
end

---#DES 'fs.exists'
---
---Returns true if specified path exists
---@param path string
function fs.dir_exists(path)
    path = path:sub(#path, #path) == "/" and path or path .. "/"
    return fs.exists(path)
end

---@class FsHashFileOptions: AccessFileOptions
---@field type '"sha256"'| '"sha512"'
---@field hex boolean?

---#DES 'fs.hash_file'
---
---Hashes file in specified path
---@param pathOrFile string | file*
---@param options? FsHashFileOptions
---@return string
function fs.hash_file(pathOrFile, options)
    local _hash = require 'lmbed_hash'
    options = _util.merge_tables({ type = "sha256", binaryMode = true }, options, true)
    local srcf
    if type(pathOrFile) == "string" then
        srcf = assert(io.open(pathOrFile, options.binaryMode and "rb" or "r"), 'No such a file or directory - ' .. path)
    else
        assert(tostring(pathOrFile):find("file") == 1, "Not a file* - (" .. tostring(pathOrFile) .. ")")
        srcf = pathOrFile
    end
    local size = 2 ^ 12 -- 4K

    if options.type == 'sha256' then
        local ctx = _hash.sha256_init()
        while true do
            local block = srcf:read(size)
            if not block then
                break
            end
            _hash.sha256_update(ctx, block)
        end
        return _hash.sha256_finish(ctx, options.hex)
    else
        local ctx = _hash.sha512_init()
        while true do
            local block = srcf:read(size)
            if not block then
                break
            end
            _hash.sha512_update(ctx, block)
        end
        return _hash.sha512_finish(ctx, options.hex)
    end
end

local function _direntry_type(entry)
    if type(entry) == 'string' then
        return efs.file_type(entry)
    elseif type(entry) == 'ELI_DIRENTRY' or (type(entry) == 'userdata' and entry.__type == 'ELI_DIRENTRY') then
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
---@field name fun(self: DirEntry): string
---@field type fun(self: DirEntry): string
---@field fullpath fun(self: DirEntry): string
---@field __type '"ELI_DIRENTRY"'

---#DES 'fs.read_dir'
---
---Reads directory and returns dir entire or paths based on options
---@param path string
---@param options FsReadDirOptions?
---@return string[]|DirEntry[]
function fs.read_dir(path, options)
    _check_efs_available('read_dir')
    options = _util.merge_tables({}, options, true)

    if options.recurse then
        local _lenOfPathToRemove = path:match('.*/$') and #path or #path + 1
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
---@param options FsChownOptions?
---@return boolean, string?, number?
function fs.chown(path, uid, gid, options)
    _check_efs_available('chown')
    options = _util.merge_tables({ recurseIgnoreErrors = true }, options, true)
    if not options.recurse or efs.file_type(path) ~= 'directory' then
        return efs.chown(path, uid, gid)
    end

    local _ok, _error, _errno = efs.chown(path, uid, gid)
    if not _ok and not options.recurseIgnoreErrors then
        return _ok, _error, _errno
    end

    local _paths = fs.read_dir(path, { recurse = true, returnFullPaths = true })
    for _, _path in ipairs(_paths) do
        _ok, _error, _errno = efs.chown(_path, uid, gid)
        if not _ok and not options.recurseIgnoreErrors then
            return _ok, _error, _errno
        end
    end
    return true
end

---@class FsChmodOptions
---@field recurse boolean
---@field recurseIgnoreErrors boolean

---#DES 'fs.chmod'
---
---Sets file flags in the path
---@param path string
---@param mode integer|string
---@param options FsChmodOptions?
---@return boolean, string?, number?
function fs.chmod(path, mode, options)
    _check_efs_available('chmod')
    options = _util.merge_tables({}, options, true)

    if type(mode) == "string" then
        mode = mode .. string.rep("-", 9 - #mode)
    end
    if not options.recurse or efs.file_type(path) ~= 'directory' then
        return efs.chmod(path, mode)
    end

    if type(options.recurseIgnoreErrors) ~= 'boolean' then
        options.recurseIgnoreErrors = true
    end

    local _ok, _error, _errno = efs.chmod(path, mode)
    if not _ok and not options.recurseIgnoreErrors then
        return _ok, _error, _errno
    end

    local _paths = fs.read_dir(path, { recurse = true, returnFullPaths = true })
    for _, _path in ipairs(_paths) do
        _ok, _error, _errno = efs.chmod(_path, mode)
        if not _ok and not options.recurseIgnoreErrors then
            return _ok, _error, _errno
        end
    end
    return true
end

---#DES fs.EliFileLock'
---
---@class EliFileLock
---@field free fun(eliFileLock: EliFileLock):nil
---@field unlock fun(eliFileLock: EliFileLock):nil
---@field is_active fun(eliFileLock: EliFileLock): boolean
---@field __type '"ELI_FILE_LOCK"'

local ELI_FILE_LOCK_ID = "ELI_FILE_LOCK"

---#DES 'fs.lock_file'
---
---Locks access to file
---@param pathOrFile string|file*
---@param mode '"rb"'|'"wb"'
---@param start integer?
---@param len integer?
---@return EliFileLock?, string?, integer?
function fs.lock_file(pathOrFile, mode, start, len)
    _check_efs_available('lock_file')
    return efs.lock_file(pathOrFile, mode, start, len)
end

---#DES 'fs.unlock_file'
---
---Unlocks access to file
---@param fsLock EliFileLock
---@return boolean?, string?
function fs.unlock_file(fsLock)
    _check_efs_available('unlock_file')

    if type(fsLock) == ELI_FILE_LOCK_ID or (type(fsLock) == "userdata" and fsLock.__type == ELI_FILE_LOCK_ID) then
        return fsLock:unlock()
    else
        return false,
            "Invalid " .. ELI_FILE_LOCK_ID .. " type! '" .. ELI_FILE_LOCK_ID ..
            "' expected, got: " .. type(fsLock) .. "!"
    end
end

---#DES fs.EliDirLock'
---
---@class EliDirLock
---@field free fun(eliDirLock: EliDirLock):nil
---@field unlock fun(eliDirLock: EliDirLock):nil
---@field is_active fun(eliDirLock: EliDirLock): boolean
---@field __type '"ELI_DIR_LOCK"'

local ELI_DIR_LOCK_ID = "ELI_DIR_LOCK"

---#DES 'fs.lock_directory'
---
---Locks access to directory
---@param path string
---@param lockFileName string?
---@return EliDirLock|nil, string?
function fs.lock_directory(path, lockFileName)
    _check_efs_available('lock_dir')
    return efs.lock_dir(path, lockFileName)
end

---#DES 'fs.unlock_directory'
---
---Unlocks access to directory
---@param fsLock EliDirLock
---@return boolean|nil, string?
function fs.unlock_directory(fsLock)
    if type(fsLock) == ELI_DIR_LOCK_ID or (type(fsLock) == "userdata" and fsLock.__type == ELI_DIR_LOCK_ID) then
        return fsLock:unlock()
    else
        return false,
            "Invalid " .. ELI_DIR_LOCK_ID .. " type! '" .. ELI_DIR_LOCK_ID .. "' expected, got: " .. type(fsLock) .. "!"
    end
end

---#DES 'fs.file_type'
---
---returns type of file
---@param path string
---@return boolean|nil, string
function fs.file_type(path)
    local _last = path:sub(#path, #path)
    if _last == "/" or _last == "\\" then
        path = path:sub(1, #path - 1)
    end
    return efs.file_type(path)
end

if efsLoaded then
    local result = _util.generate_safe_functions(_util.merge_tables(fs, efs))
    result.safe_iter_dir = nil -- not supported
    return result
else
    return _util.generate_safe_functions(fs)
end
