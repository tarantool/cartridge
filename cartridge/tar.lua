#!/usr/bin/env tarantool

--- Handle basic tar format.
--
-- <http://www.gnu.org/software/tar/manual/html_node/Standard.html>
--
-- While an archive may contain many files, the archive itself is a
-- single ordinary file. Physically, an archive consists of a series of
-- file entries terminated by an end-of-archive entry, which consists of
-- two 512 blocks of zero bytes. A file entry usually describes one of
-- the files in the archive (an archive member), and consists of a file
-- header and the contents of the file. File headers contain file names
-- and statistics, checksum information which tar uses to detect file
-- corruption, and information about file types.
--
-- A tar archive file contains a series of blocks. Each block contains
-- exactly 512 (`BLOCKSIZE`) bytes:
--    +---------+-------+-------+-------+---------+-------+-----
--    | header1 | file1 |  ...  |  ...  | header2 | file2 | ...
--    +---------+-------+-------+-------+---------+-------+-----
--
-- All characters in header blocks are represented by using 8-bit
-- characters in the local variant of ASCII. Each field within the
-- structure is contiguous; that is, there is no padding used within the
-- structure. Each character on the archive medium is stored
-- contiguously. Bytes representing the contents of files (after the
-- header block of each file) are not translated in any way and are not
-- constrained to represent characters in any character set. The tar
-- format does not distinguish text files from binary files, and no
-- translation of file contents is performed.
--
-- @module cartridge.tar
-- @local

local errors = require('errors')
local checks = require('checks')

local PackTarError = errors.new_class('PackTarError')
local UnpackTarError = errors.new_class('UnpackTarError')

local HEADER_CONF = {
    NAME =      { SIZE = 100, OFFSET = 0   },
    MODE =      { SIZE = 8,   OFFSET = 100 },
    UID =       { SIZE = 8,   OFFSET = 108 },
    GID =       { SIZE = 8,   OFFSET = 116 },
    SIZE =      { SIZE = 12,  OFFSET = 124 },
    MTIME =     { SIZE = 12,  OFFSET = 136 },
    CHKSUM =    { SIZE = 8,   OFFSET = 148 },
    TYPEFLAG =  { SIZE = 1,   OFFSET = 156 },
    LINKNAME =  { SIZE = 100, OFFSET = 157 },
    MAGIC =     { SIZE = 6,   OFFSET = 257 },
    VERSION =   { SIZE = 2,   OFFSET = 263 },
    UNAME =     { SIZE = 32,  OFFSET = 265 },
    GNAME =     { SIZE = 32,  OFFSET = 297 },
    DEVMAJOR =  { SIZE = 8,   OFFSET = 329 },
    DEVMINOR =  { SIZE = 8,   OFFSET = 337 },
    PREFIX =    { SIZE = 155, OFFSET = 345 },
    _ =         { SIZE = 12,  OFFSET = 500 },
}

local MAGIC = 'ustar\0'
local VERSION = ' \0'
local TYPEFLAG = '0'
local MODE = '644'

local BLOCKSIZE = 512

local function checksum_header(header)
    local block = ''
    if type(header) == 'table' then
        for _, val in pairs(header) do
            if val ~= nil then
                block = block .. val
            end
        end
    else
        block = header
    end

    local sum = 256
    for i = 1, 148 do
       sum = sum + (block:byte(i) or 0)
    end
    for i = 157, 500 do
       sum = sum + (block:byte(i) or 0)
    end

    return sum
end

local function string_header(header)
    local ret = {}

    table.insert(ret, string.ljust(header.name,     HEADER_CONF.NAME.SIZE,     '\0'))
    table.insert(ret, string.ljust(header.mode,     HEADER_CONF.MODE.SIZE,     '\0'))
    table.insert(ret, string.ljust(header.uid,      HEADER_CONF.UID.SIZE,      '\0'))
    table.insert(ret, string.ljust(header.gid,      HEADER_CONF.GID.SIZE,      '\0'))
    table.insert(ret, string.ljust(header.size,     HEADER_CONF.SIZE.SIZE,     '\0'))
    table.insert(ret, string.ljust(header.mtime,    HEADER_CONF.MTIME.SIZE,    '\0'))
    table.insert(ret, string.ljust(header.chksum,   HEADER_CONF.CHKSUM.SIZE,   '\0'))
    table.insert(ret, string.ljust(header.typeflag, HEADER_CONF.TYPEFLAG.SIZE, '\0'))
    table.insert(ret, string.ljust(header.linkname, HEADER_CONF.LINKNAME.SIZE, '\0'))
    table.insert(ret, string.ljust(header.magic,    HEADER_CONF.MAGIC.SIZE,    '\0'))
    table.insert(ret, string.ljust(header.version,  HEADER_CONF.VERSION.SIZE,  '\0'))
    table.insert(ret, string.ljust(header.uname,    HEADER_CONF.UNAME.SIZE,    '\0'))
    table.insert(ret, string.ljust(header.gname,    HEADER_CONF.GNAME.SIZE,    '\0'))
    table.insert(ret, string.ljust(header.devmajor, HEADER_CONF.DEVMAJOR.SIZE, '\0'))
    table.insert(ret, string.ljust(header.devminor, HEADER_CONF.DEVMINOR.SIZE, '\0'))
    table.insert(ret, string.ljust(header.prefix,   HEADER_CONF.PREFIX.SIZE,   '\0'))
    table.insert(ret, string.ljust(header._,        HEADER_CONF._.SIZE,        '\0'))

    return table.concat(ret)
end

local function get_header(file)
    local header = {
        name =      file.name,
        mode =      MODE,
        uid =       '\0',
        gid =       '\0',
        size =      string.format('%o', #file.content),
        mtime =     '\0',
        chksum =    nil,
        typeflag =  TYPEFLAG,
        linkname =  '\0',
        magic =     MAGIC,
        version =   VERSION,
        uname =     '\0',
        gname =     '\0',
        devmajor =  '\0',
        devminor =  '\0',
        prefix =    '\0',
        _ =         '\0',
    }
    header.chksum = string.format('%o', checksum_header(header))

    return string_header(header)
end

--- Create TAR archive.
--
-- @function pack
-- @tparam {string=string} files
-- @treturn string The archive
-- @treturn[2] nil
-- @treturn[2] table Error description
local function pack(config)
    checks('table')

    local ret = {}
    for filename, content in pairs(config) do
        if type(content) ~= 'string' then
            return nil, PackTarError:new('Type of content file should be a string')
        end
        if #filename > HEADER_CONF.NAME.SIZE then
            return nil, PackTarError:new(
                string.format('Filename size is more then %d', HEADER_CONF.NAME.SIZE))
        end

        table.insert(ret, get_header({
            name = filename,
            content = content,
        }))
        table.insert(ret, string.ljust(
            content,
            math.ceil(#content / BLOCKSIZE) * BLOCKSIZE,
            '\0'
        ))
    end
    table.insert(ret, string.rep('\0', 2 * BLOCKSIZE))

    return table.concat(ret)
end

local function read_header_block(header, conf)
    local block = string.sub(header,
        conf.OFFSET + 1,
        conf.OFFSET + conf.SIZE
    )
    return string.gsub(block, '%z+$', '')
end

local function header_format_validation(header)
    if #header ~= BLOCKSIZE then
        return nil, UnpackTarError:new('Truncated file')
    end

    local magic = read_header_block(header, HEADER_CONF.MAGIC)
    -- Version should be 'ustar\0' or 'ustar '
    if magic ~= 'ustar' and magic ~= 'ustar ' then
        return nil, UnpackTarError:new('Bad format (invalid magic)')
    end

    local version = read_header_block(header, HEADER_CONF.VERSION)
    -- Version should be '00' or ' \0'
    if version ~= '00' and version ~= ' ' then
        return nil, UnpackTarError:new('Bad format (invalid version)')
    end

    local chksum = read_header_block(header, HEADER_CONF.CHKSUM)
    if tonumber(chksum, 8) ~= checksum_header(header) then
        return nil, UnpackTarError:new('Checksum mismatch')
    end

    return true, nil
end

local function read_header(tar, offset)
    local block = string.sub(tar, offset + 1, offset + BLOCKSIZE)
    if string.startswith(block, '\0') then
        return {}
    end
    local ok, err = header_format_validation(block)
    if not ok then
        return nil, err
    end

    local header = {}
    header.name = read_header_block(block, HEADER_CONF.NAME)
    header.size = read_header_block(block, HEADER_CONF.SIZE)
    header.type = read_header_block(block, HEADER_CONF.TYPEFLAG)

    return header
end

--- Parse TAR archive.
--
-- Only regular files are extracted, directories are ommitted.
--
-- @function unpack
-- @tparam string tar
-- @treturn {string=string} Extracted files (their names and content)
-- @treturn[2] nil
-- @treturn[2] table Error description
local function unpack(tar)
    checks('string')
    if #tar < BLOCKSIZE then
        return nil, UnpackTarError:new('Truncated file')
    end

    local ret = {}
    local offset = 0
    while offset < #tar do
        local header, err = read_header(tar, offset)
        if header == nil then
            return nil, err
        end

        if header.name == nil then
            break
        end

        offset = offset + BLOCKSIZE

        local content_size = tonumber(header.size, 8)
        local blocked_size = math.ceil(content_size / BLOCKSIZE) * BLOCKSIZE
        if #tar < offset + blocked_size then
            return nil, UnpackTarError:new('Truncated file')
        end

        if header.type == '0' or header.type == '' then
            ret[header.name] = string.sub(tar,
                offset + 1,
                offset + content_size
            )
        end

        offset = offset + blocked_size
    end

    return ret
end

return {
    pack = pack,
    unpack = unpack,
}
