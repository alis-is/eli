local test = TEST or require"u-test"
local ok, eli_zip = pcall(require, "eli.zip")
local ok2, eli_fs = pcall(require, "eli.fs")
local ok2, eli_hash = pcall(require, "eli.hash")

if not ok then
    test["eli.zip available"] = function ()
        test.assert(false, "eli.zip not available")
    end
    if not TEST then
        test.summary()
        os.exit()
    else
        return
    end
end

test["eli.zip available"] = function ()
    test.assert(true)
end

test["extract"] = function ()
    eli_fs.remove"tmp/test.file"
    local ok, err = eli_zip.extract("assets/test.zip", "tmp")
    test.assert(ok, err)
    local file_hash, err = eli_fs.hash_file("tmp/test.file", { hex = true })
    test.assert(ok, file_hash)
    local file_hash2, err = eli_fs.hash_file("assets/test.file", { hex = true })
    test.assert(ok, file_hash2)
    test.assert(eli_hash.equals(file_hash, file_hash2, true),
        "hashes dont match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
end

test["extract_file"] = function ()
    eli_fs.remove"tmp/test.file.unzipped"
    local ok, err = eli_zip.extract_file("assets/test.zip", "test.file", "tmp/test.file.unzipped")
    test.assert(ok, err)
    local file_hash, _ = eli_fs.hash_file("tmp/test.file.unzipped", { hex = true })
    local file_hash2, err = eli_fs.hash_file("assets/test.file", { hex = true })
    test.assert(file_hash2, err)
    test.assert(eli_hash.equals(file_hash, file_hash2, true),
        "hashes dont match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
end

test["extract_string"] = function ()
    local file, err = eli_zip.extract_string("assets/test.zip", "test.file")
    test.assert(file, err)
    local file_hash, err = eli_hash.sha256_sum(file, true)
    test.assert(file_hash, err)
    local file_hash2, err = eli_fs.hash_file("assets/test.file", { hex = true })
    test.assert(file_hash2, err)
    test.assert(eli_hash.equals(file_hash, file_hash2, true),
        "hashes dont match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
end

test["compress"] = function ()
    eli_fs.remove"tmp/test.file.zip"
    local ok, file = eli_zip.compress("assets/test.file", "tmp/test.file.zip")
    test.assert(ok, file)
    local ok, err = eli_zip.extract_file("tmp/test.file.zip", "test.file", "tmp/test.file.unzipped")
    test.assert(ok, err)
    local file_hash, _ = eli_fs.hash_file("tmp/test.file.unzipped", { hex = true })
    local file_hash2, err = eli_fs.hash_file("assets/test.file", { hex = true })
    test.assert(file_hash2, err)
    test.assert(eli_hash.equals(file_hash, file_hash2, true),
        "hashes dont match (" .. tostring(file_hash) .. "<>" .. tostring(file_hash2) .. ")")
end

test["compress (filter)"] = function ()
    eli_fs.remove"tmp/test.file.zip"
    local ok, file = eli_zip.compress("assets", "tmp/test.file.zip", {
        filter = function (path, info)
            return path == "test.file"
        end,
        content_only = true,
    })
    test.assert(ok, file)
    local ok, error = eli_zip.extract_file("tmp/test.file.zip", "test.file", "tmp/test.file.unzipped")
    test.assert(ok, error)
    local hash, err = eli_fs.hash_file("tmp/test.file.unzipped", { hex = true })
    local hash2, err = eli_fs.hash_file("assets/test.file", { hex = true })
    test.assert(ok, hash2)
    test.assert(eli_hash.equals(hash, hash2, true),
        "hashes dont match (" .. tostring(hash) .. "<>" .. tostring(hash2) .. ")")
    local files = eli_zip.get_files"tmp/test.file.zip"
    test.assert(#files == 1, "files count mismatch")
end

test["compress and extract POSIX modes"] = function ()
    if package.config:sub(1, 1) ~= "/" then return end

    local root = os.tmpname()
    assert(os.remove(root))
    local source = root .. "/locked"
    local destination = root .. "/out"
    local archive = root .. "/archive.zip"
    local cleanup <close> = setmetatable({}, { __close = function ()
        eli_fs.chmod(source, "rwx------")
        eli_fs.chmod(destination .. "/locked", "rwx------")
        assert(eli_fs.remove(root, { recurse = true }))
    end })
    local entries = {
        { name = "locked/", mode = "40500", permissions = "r-x------" },
        { name = "locked/private.txt", mode = "100600", permissions = "rw-------", content = "private\n" },
        { name = "locked/run.sh", mode = "100750", permissions = "rwxr-x---", content = "#!/bin/sh\n" },
        { name = "locked/empty/", mode = "40700", permissions = "rwx------" },
    }

    assert(eli_fs.mkdirp(source .. "/empty"))
    assert(eli_fs.mkdirp(destination))
    for _, entry in ipairs(entries) do
        if entry.content then
            assert(eli_fs.write_file(root .. "/" .. entry.name, entry.content))
        end
    end
    for _, entry in ipairs(entries) do
        assert(eli_fs.chmod(root .. "/" .. entry.name, entry.permissions))
    end
    assert(eli_zip.compress(source, archive, { recurse = true }))

    -- Read the central directory of this small ZIP directly to check the on-disk attributes.
    local data = assert(eli_fs.read_file(archive))
    local end_record = #data - 21
    assert(data:sub(end_record, end_record + 3) == "PK\5\6", "missing ZIP end record")
    local count, size, directory_offset = string.unpack("<I2I4I4", data, end_record + 10)
    assert(count == #entries, "unexpected ZIP entry count: " .. count)
    assert(directory_offset + size + 1 == end_record, "invalid ZIP central directory size")
    local records = {}
    local offset = directory_offset + 1
    for _ = 1, count do
        assert(data:sub(offset, offset + 3) == "PK\1\2", "missing ZIP central directory record")
        local name_size, extra_size, comment_size = string.unpack("<I2I2I2", data, offset + 28)
        local name = data:sub(offset + 46, offset + 45 + name_size)
        local next_offset = offset + 46 + name_size + extra_size + comment_size
        records[name] = data:sub(offset, next_offset - 1)
        offset = next_offset
    end

    -- Put the read-only parent first while leaving the local file headers and contents intact.
    local ordered = {}
    for i, entry in ipairs(entries) do
        local record = assert(records[entry.name], "missing ZIP entry " .. entry.name)
        assert(record:byte(6) == 3, "missing Unix creator for " .. entry.name)
        local mode = string.unpack("<I2", record, 41)
        assert(mode == tonumber(entry.mode, 8), ("incorrect ZIP mode for %s: %o"):format(entry.name, mode))
        ordered[i] = record
    end
    local local_entries, end_of_directory = data:sub(1, directory_offset), data:sub(end_record)
    assert(eli_fs.write_file(archive, local_entries .. table.concat(ordered) .. end_of_directory))

    assert(eli_zip.extract(archive, destination, {
        open_file = function (target, mode)
            local permissions = assert(eli_fs.file_info(destination .. "/locked")).permissions
            assert(permissions:sub(2, 2) == "w", "directory permissions applied before extracting children")
            return io.open(target, mode)
        end,
    }))
    for _, entry in ipairs(entries) do
        local target = destination .. "/" .. entry.name
        local permissions = assert(eli_fs.file_info(target)).permissions
        assert(permissions == entry.permissions, "incorrect extracted permissions for " .. entry.name .. ": " .. permissions)
        if entry.content then
            test.equal(eli_fs.read_file(target), entry.content)
        end
    end
    test.equal(#assert(eli_fs.read_dir(destination .. "/locked/empty")), 0)

    local restored = {}
    local ok, err = eli_zip.extract(archive, destination, {
        filter = function (name) return name:sub(-1) == "/" end,
        chmod = function (_, attributes)
            table.insert(restored, attributes >> 16)
            if #restored == 2 then return false, "injected chmod failure" end
        end,
    })
    test.equal(restored[1], tonumber("40700", 8))
    test.equal(restored[2], tonumber("40500", 8))
    test.assert(not ok and err and err:find("injected chmod failure", 1, true), err)

    -- Simulate a DOS creator with nonzero attribute bits and a Unix entry with no mode.
    ordered[4] = ordered[4]:sub(1, 5) .. "\0" .. ordered[4]:sub(7)
    ordered[3] = ordered[3]:sub(1, 40) .. "\0\0" .. ordered[3]:sub(43)
    assert(eli_fs.write_file(archive, local_entries .. table.concat(ordered) .. end_of_directory))
    local empty_dir = destination .. "/locked/empty"
    local executable = destination .. "/locked/run.sh"
    assert(eli_fs.chmod(empty_dir, "rwxr-x---"))
    assert(eli_fs.chmod(executable, "rw-r-----"))
    assert(eli_zip.extract(archive, destination))
    test.equal(assert(eli_fs.file_info(empty_dir)).permissions, "rwxr-x---")
    test.equal(assert(eli_fs.file_info(executable)).permissions, "rw-r-----")
end

if not TEST then
    test.summary()
end
