# module VoxelSpace.MagicaVoxel

using Colors: RGBA

struct Size
    x::UInt32
    y::UInt32
    z::UInt32
end

struct Voxel
    x::UInt8
    y::UInt8
    z::UInt8
    i::UInt8
end

struct Model
    size::Size
    voxels::Vector{Voxel}
end

struct Material
    id::UInt32
    properties::NamedTuple
end

struct Chunk
    main::Vector{Chunk}
    size::Size
    voxels::Vector{Voxel}
    pack::Model
    palette::Vector{UInt32}
    material::Material
    unknown::String
    invalid::Vector{UInt8}
end

struct ChunkError <: Exception
    msg
end

function toInt32(bytes::Vector{UInt8})::Int32
    @assert length(bytes) == 4
    reinterpret(Int32, bytes)[1]
end

function toUInt32(bytes::Vector{UInt8})::UInt32
    @assert length(bytes) == 4
    reinterpret(UInt32, bytes)[1]
end

function toFloat32(bytes::Vector{UInt8})::Float32
    @assert length(bytes) == 4
    reinterpret(Float32, bytes)[1]
end

function toRGBA(palette::UInt32)::RGBA
    r = (palette & 0x0000ff)
    g = (palette & 0x00ff00) >> 8
    b = (palette & 0xff0000) >> 16
    a = 0xff
    RGBA(./((r, g, b, a), 0xff)...)
end

function build_chunk(::Any, chunk_content, child_content)
    throw(ChunkError(""))
end

# 5. Chunk id 'SIZE' : model size
# 4        | int        | size x
# 4        | int        | size y
# 4        | int        | size z : gravity direction
function build_chunk(::Val{:SIZE}, chunk_content, child_content)::Size
    x = toInt32(chunk_content[1:4])
    y = toInt32(chunk_content[5:8])
    z = toInt32(chunk_content[9:12])
    Size(x, y, z)
end

# 6. Chunk id 'XYZI' : model voxels
# 4        | int        | numVoxels (N)
# 4 x N    | int        | (x, y, z, colorIndex) : 1 byte for each component
function build_chunk(::Val{:XYZI}, chunk_content, child_content)
    numVoxels = toInt32(chunk_content[1:4])
    @info :XYZI numModels
end

# 4. Chunk id 'PACK' : if it is absent, only one model in the file
# 4        | int        | numModels : num of SIZE and XYZI chunks
function build_chunk(::Val{:PACK}, chunk_content, child_content)
    numModels = toInt32(chunk_content[1:4])
    @info :PACK numModels
end

# 7. Chunk id 'RGBA' : palette
# 4 x 256  | int        | (R, G, B, A) : 1 byte for each component
function build_chunk(::Val{:RGBA}, chunk_content, child_content)::Vector{RGBA}
    palette = Vector{RGBA}(undef, 256)
    for i in 0:255
        r = chunk_content[4i+1]
        g = chunk_content[4i+2]
        b = chunk_content[4i+3]
        a = chunk_content[4i+4]
        rgba = RGBA(./((r, g, b, a), 0xff)...)
        palette[i+1] = rgba
    end
    palette
end

# 2. Chunk Structure
# 1x4      | char       | chunk id
# 4        | int        | num bytes of chunk content (N)
# 4        | int        | num bytes of children chunks (M)
# N        |            | chunk content
# M        |            | children chunks
function parse_chunk(stream::IO)
    id = read(stream, 4)
    chunk_id = Symbol(id)
    content_size = toInt32(read(stream, 4))
    children_size = toInt32(read(stream, 4))
    chunk_content = read(stream, content_size)
    child_content = read(stream, children_size)
    build_chunk(Val(chunk_id), chunk_content, child_content)
end

function parse_material(stream::IO)::Material
    id = toUInt32(read(stream, 4))
    properties = parse_properties(stream)
    Material(id, properties)
end

function parse_material_string(stream::IO)
    n = toInt32(read(stream, 4))
    String(read(stream, n))
end

function parse_properties(stream::IO)
    count = toInt32(read(stream, 4))
    keys = []
    values = []
    for i in 1:count
        key = parse_material_string(stream)
        value = parse_material_string(stream)
        push!(keys, key)
        push!(values, value)
    end
    NamedTuple{Symbol.(tuple(keys...))}(values)
end

const DEFAULT_PALETTE = [
    0x000000, 0xffffff, 0xccffff, 0x99ffff, 0x66ffff, 0x33ffff, 0x00ffff, 0xffccff, 0xccccff, 0x99ccff, 0x66ccff, 0x33ccff, 0x00ccff, 0xff99ff, 0xcc99ff, 0x9999ff,
    0x6699ff, 0x3399ff, 0x0099ff, 0xff66ff, 0xcc66ff, 0x9966ff, 0x6666ff, 0x3366ff, 0x0066ff, 0xff33ff, 0xcc33ff, 0x9933ff, 0x6633ff, 0x3333ff, 0x0033ff, 0xff00ff,
    0xcc00ff, 0x9900ff, 0x6600ff, 0x3300ff, 0x0000ff, 0xffffcc, 0xccffcc, 0x99ffcc, 0x66ffcc, 0x33ffcc, 0x00ffcc, 0xffcccc, 0xcccccc, 0x99cccc, 0x66cccc, 0x33cccc,
    0x00cccc, 0xff99cc, 0xcc99cc, 0x9999cc, 0x6699cc, 0x3399cc, 0x0099cc, 0xff66cc, 0xcc66cc, 0x9966cc, 0x6666cc, 0x3366cc, 0x0066cc, 0xff33cc, 0xcc33cc, 0x9933cc,
    0x6633cc, 0x3333cc, 0x0033cc, 0xff00cc, 0xcc00cc, 0x9900cc, 0x6600cc, 0x3300cc, 0x0000cc, 0xffff99, 0xccff99, 0x99ff99, 0x66ff99, 0x33ff99, 0x00ff99, 0xffcc99,
    0xcccc99, 0x99cc99, 0x66cc99, 0x33cc99, 0x00cc99, 0xff9999, 0xcc9999, 0x999999, 0x669999, 0x339999, 0x009999, 0xff6699, 0xcc6699, 0x996699, 0x666699, 0x336699,
    0x006699, 0xff3399, 0xcc3399, 0x993399, 0x663399, 0x333399, 0x003399, 0xff0099, 0xcc0099, 0x990099, 0x660099, 0x330099, 0x000099, 0xffff66, 0xccff66, 0x99ff66,
    0x66ff66, 0x33ff66, 0x00ff66, 0xffcc66, 0xcccc66, 0x99cc66, 0x66cc66, 0x33cc66, 0x00cc66, 0xff9966, 0xcc9966, 0x999966, 0x669966, 0x339966, 0x009966, 0xff6666,
    0xcc6666, 0x996666, 0x666666, 0x336666, 0x006666, 0xff3366, 0xcc3366, 0x993366, 0x663366, 0x333366, 0x003366, 0xff0066, 0xcc0066, 0x990066, 0x660066, 0x330066,
    0x000066, 0xffff33, 0xccff33, 0x99ff33, 0x66ff33, 0x33ff33, 0x00ff33, 0xffcc33, 0xcccc33, 0x99cc33, 0x66cc33, 0x33cc33, 0x00cc33, 0xff9933, 0xcc9933, 0x999933,
    0x669933, 0x339933, 0x009933, 0xff6633, 0xcc6633, 0x996633, 0x666633, 0x336633, 0x006633, 0xff3333, 0xcc3333, 0x993333, 0x663333, 0x333333, 0x003333, 0xff0033,
    0xcc0033, 0x990033, 0x660033, 0x330033, 0x000033, 0xffff00, 0xccff00, 0x99ff00, 0x66ff00, 0x33ff00, 0x00ff00, 0xffcc00, 0xcccc00, 0x99cc00, 0x66cc00, 0x33cc00,
    0x00cc00, 0xff9900, 0xcc9900, 0x999900, 0x669900, 0x339900, 0x009900, 0xff6600, 0xcc6600, 0x996600, 0x666600, 0x336600, 0x006600, 0xff3300, 0xcc3300, 0x993300,
    0x663300, 0x333300, 0x003300, 0xff0000, 0xcc0000, 0x990000, 0x660000, 0x330000, 0x0000ee, 0x0000dd, 0x0000bb, 0x0000aa, 0x000088, 0x000077, 0x000055, 0x000044,
    0x000022, 0x000011, 0x00ee00, 0x00dd00, 0x00bb00, 0x00aa00, 0x008800, 0x007700, 0x005500, 0x004400, 0x002200, 0x001100, 0xee0000, 0xdd0000, 0xbb0000, 0xaa0000,
    0x880000, 0x770000, 0x550000, 0x440000, 0x220000, 0x110000, 0xeeeeee, 0xdddddd, 0xbbbbbb, 0xaaaaaa, 0x888888, 0x777777, 0x555555, 0x444444, 0x222222, 0x111111]

# module VoxelSpace.MagicaVoxel
