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
    _ =         { SIZE = 12,  OFFSET = 500 }, -- padding
}
local BLOCKSIZE = 512

local function checksum(header)
    checks('string')
    -- The chksum field represents the simple sum of all bytes in the
    -- header block. Each 8-bit byte in the header is added to an
    -- unsigned integer, initialized to zero, the precision of which
    -- shall be no less than seventeen bits.

    local checksum = 256 -- I have no idea why, but tar works this way
    for i = 1, BLOCKSIZE do
        if i <= HEADER_CONF.CHKSUM.OFFSET
        or i > HEADER_CONF.CHKSUM.OFFSET + HEADER_CONF.CHKSUM.SIZE
        then
            -- When calculating the checksum, the chksum field is
            -- treated as if it were all blanks.
            checksum = checksum + (header:byte(i) or 0)
        end
    end

    return checksum
end

local function get_header(file)
    local header = {
        name =      file.name,
        mode =      '644',
        uid =       '\0',
        gid =       '\0',
        size =      string.format('%o', #file.content),
        mtime =     '\0',
        chksum =    nil,
        typeflag =  '0',
        linkname =  '\0',
        magic =     'ustar',
        version =   '00',
        uname =     '\0',
        gname =     '\0',
        devmajor =  '\0',
        devminor =  '\0',
        prefix =    '\0',
        _ =         '\0',
    }
    local checksum = 256
    for _, v in pairs(header) do
        for i = 1, #v do
            checksum = checksum + v:byte(i)
        end
    end
    header.chksum = string.format('%o', checksum)

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
        if type(filename) ~= 'string' then
            local err = "bad argument #1 to pack" ..
                " (table keys must be strings)"
            error(err, 2)
        elseif type(content) ~= 'string' then
            local err = "bad argument #1 to pack" ..
                " (table values must be strings)"
            error(err, 2)
        end

        if #filename > HEADER_CONF.NAME.SIZE then
            return nil, PackTarError:new(
                'Too long filename (max %d)',
                HEADER_CONF.NAME.SIZE
            )
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
    if tonumber(chksum, 8) ~= checksum(header) then
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
