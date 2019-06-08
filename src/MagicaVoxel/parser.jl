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

struct VoxData
    version::Int32
    models::Vector{Model}
    palette::Vector{RGBA}
    materials::Vector{Material}
end

struct Unknown
    chunk_id::Symbol
end

const AnyChunkType = Union{Size, Material, Vector{Voxel}, Vector{RGBA}, Vector{Model}, Unknown, NamedTuple{(:models, :palette, :materials)}}

struct ChunkError <: Exception
    msg
end

for typ in (Model, VoxData)
    @eval function Base.:(==)(l::T, r::T) where {T <: $typ}
        for name in fieldnames(T)
            getfield(l, name) != getfield(r, name) && return false
        end
        return true
    end
end

# toInt32, toUInt32, toFloat32
for typ in (Int32, UInt32, Float32)
    funcname = Symbol(:to, typ)
    @eval function $funcname(bytes::Vector{UInt8})::$typ
        @assert length(bytes) == 4
        reinterpret($typ, bytes)[1]
    end
end

function toRGBA(palette::UInt32)::RGBA
    r = (palette & 0x00_00_00_ff)
    g = (palette & 0x00_00_ff_00) >> 8
    b = (palette & 0x00_ff_00_00) >> 16
    a = (palette & 0xff_00_00_00) >> 24
    RGBA(./((r, g, b, a), 0xff)...)
end

#=  build_chunk =#
function build_chunk(::Any, stream::IO, content_size, children_size)
    throw(ChunkError(""))
end

# 5. Chunk id 'SIZE' : model size
# 4        | int        | size x
# 4        | int        | size y
# 4        | int        | size z : gravity direction
function build_chunk(::Val{:SIZE}, stream::IO, content_size, children_size)::Size
    x = toInt32(read(stream, 4))
    y = toInt32(read(stream, 4))
    z = toInt32(read(stream, 4))
    Size(x, y, z)
end

# 6. Chunk id 'XYZI' : model voxels
# 4        | int        | numVoxels (N)
# 4 x N    | int        | (x, y, z, colorIndex) : 1 byte for each component
function build_chunk(::Val{:XYZI}, stream::IO, content_size, children_size)::Vector{Voxel}
    map(1:parse_vox_numof(stream)) do idx
        x, y, z, i = read(stream, 4)
        Voxel(x, y, z, i-1)
    end
end

# 7. Chunk id 'RGBA' : palette
# 4 x 256  | int        | (R, G, B, A) : 1 byte for each component
function build_chunk(::Val{:RGBA}, stream::IO, content_size, children_size)::Vector{RGBA}
    palette = Vector{RGBA}(undef, 256)
    for i in 0:255
        r, g, b, a = read(stream, 4)
        rgba = RGBA(./((r, g, b, a), 0xff)...)
        palette[i+1] = rgba
    end
    palette
end

# (4) Material Chunk : "MATL"
# int32	: material id
# DICT	: material properties
# 	  (_type : str) _diffuse, _metal, _glass, _emit
# 	  (_weight : float) range 0 ~ 1
# 	  (_rough : float)
# 	  (_spec : float)
# 	  (_ior : float)
# 	  (_att : float)
# 	  (_flux : float)
# 	  (_plastic)
function build_chunk(::Val{:MATL}, stream::IO, content_size, children_size)::Material
    parse_material(stream)
end

# (1) Transform Node Chunk : "nTRN"
# int32	: node id
# DICT	: node attributes
# 	  (_name : string)
# 	  (_hidden : 0/1)
# int32 	: child node id
# int32 	: reserved id (must be -1)
# int32	: layer id
# int32	: num of frames (must be 1)
function build_chunk(::Val{:nTRN}, stream::IO, content_size, children_size)::Unknown
    node_id = parse_vox_id(stream)
    node_attributes = parse_vox_dict(stream)
    child_node_id = parse_vox_id(stream)
    reserved_id = parse_vox_id(stream) # -1
    layer_id = parse_vox_id(stream)
    for _ in 1:parse_vox_numof(stream)
        parse_vox_dict(stream)
    end
    return Unknown(:nTRN)
end

# (2) Group Node Chunk : "nGRP"
# int32	: node id
# DICT	: node attributes
# int32 	: num of children nodes
function build_chunk(::Val{:nGRP}, stream::IO, content_size, children_size)::Unknown
    node_id = parse_vox_id(stream)
    node_attributes = parse_vox_dict(stream)
    for _ in 1:parse_vox_numof(stream)
        child_node_id = parse_vox_id(stream)
    end
    return Unknown(:nGRP)
end

# (3) Shape Node Chunk : "nSHP"
# int32	: node id
# DICT	: node attributes
# int32 	: num of models (must be 1)
# // for each model
# {
# int32	: model id
# DICT	: model attributes : reserved
# }xN
function build_chunk(::Val{:nSHP}, stream::IO, content_size, children_size)::Unknown
    node_id = parse_vox_id(stream)
    node_attributes = parse_vox_dict(stream)
    for _ in 1:parse_vox_numof(stream)
        model_id = parse_vox_id(stream)
        model_attributes = parse_vox_dict(stream)
    end
    return Unknown(:nSHP)
end

# (5) Layer Chunk : "LAYR"
# int32	: layer id
# DICT	: layer atrribute
# 	  (_name : string)
# 	  (_hidden : 0/1)
# int32	: reserved id, must be -1
function build_chunk(::Val{:LAYR}, stream::IO, content_size, children_size)::Unknown
    node_id = parse_vox_id(stream)
    node_attributes = parse_vox_dict(stream)
    reserved_id = parse_vox_id(stream) # -1
    return Unknown(:LAYR)
end

function build_chunk(::Val{:rLIT}, stream::IO, content_size, children_size)::Unknown
    node_id = parse_vox_id(stream)
    read(stream, content_size - 4)
    return Unknown(:rLIT)
end

function build_chunk(::Val{:rAIR}, stream::IO, content_size, children_size)::Unknown
    node_id = parse_vox_id(stream)
    read(stream, content_size - 4)
    return Unknown(:rAIR)
end

function build_chunk(::Val{:rLEN}, stream::IO, content_size, children_size)::Unknown
    node_id = parse_vox_id(stream)
    read(stream, content_size - 4)
    return Unknown(:rLEN)
end

function build_chunk(::Val{:POST}, stream::IO, content_size, children_size)::Unknown
    node_id = parse_vox_id(stream)
    read(stream, content_size - 4)
    return Unknown(:POST)
end

function build_chunk(::Val{:rDIS}, stream::IO, content_size, children_size)::Unknown
    node_id = parse_vox_id(stream)
    read(stream, content_size - 4)
    return Unknown(:rDIS)
end

# 4. Chunk id 'PACK' : if it is absent, only one model in the file
# 4        | int        | numModels : num of SIZE and XYZI chunks
function build_chunk(::Val{:PACK}, stream::IO, content_size, children_size)::Vector{Model}
    models = Vector{Model}()
    for _ in 1:parse_vox_numof(stream)
        (chunk_id, size) = parse_chunk(stream) # SIZE
        (chunk_id, voxels) = parse_chunk(stream) # XYZI
        push!(models, Model(size, voxels))
    end
    models
end

# 3. Chunk id 'MAIN' : the root chunk and parent chunk of all the other chunks
function build_chunk(::Val{:MAIN}, stream::IO, content_size, children_size)::NamedTuple{(:models, :palette, :materials)}
    models = Vector{Model}()
    palette = Vector{RGBA}()
    materials = Vector{Material}()
    pos = position(stream)
    cur = pos
    prev_size = nothing
    while cur + children_size > pos
        (chunk_id, chunk) = parse_chunk(stream)
        if :SIZE === chunk_id
            prev_size = chunk
        elseif :XYZI === chunk_id
            push!(models, Model(prev_size, chunk))
        elseif :RGBA === chunk_id
            append!(palette, chunk)
        elseif :MATL === chunk_id
            push!(materials, chunk)
        else
        end
        pos = position(stream)
    end
    (models = models, palette = palette, materials = materials)
end


# 1. File Structure : RIFF style
# 1x4      | char       | id 'VOX ' : 'V' 'O' 'X' 'space', 'V' is first
# 4        | int        | version number : 150
function parse_vox_file(stream::IO)::VoxData
    magic = read(stream, 4) # "VOX "
    version = toInt32(read(stream, 4)) # 150
    (chunk_id, chunk) = parse_chunk(stream)
    VoxData(version, chunk.models, chunk.palette, chunk.materials)
end

# 2. Chunk Structure
# 1x4      | char       | chunk id
# 4        | int        | num bytes of chunk content (N)
# 4        | int        | num bytes of children chunks (M)
# N        |            | chunk content
# M        |            | children chunks
function parse_chunk(stream::IO)::Tuple{Symbol, AnyChunkType}
    id = read(stream, 4)
    chunk_id = Symbol(id)
    content_size = parse_vox_numof(stream)
    children_size = parse_vox_numof(stream)
    chunk = build_chunk(Val(chunk_id), stream, content_size, children_size)
    (chunk_id, chunk)
end

function parse_material(stream::IO)::Material
    id = toUInt32(read(stream, 4))
    properties = parse_vox_dict(stream)
    Material(id, properties)
end

function parse_vox_id(stream::IO)::Int32
    toInt32(read(stream, 4))
end

function parse_vox_numof(stream::IO)::Int32
    toInt32(read(stream, 4))
end

function parse_vox_string(stream::IO)::String
    n = toInt32(read(stream, 4))
    String(read(stream, n))
end

function parse_vox_dict(stream::IO)::NamedTuple
    keys = []
    values = []
    for _ in 1:parse_vox_numof(stream)
        key = parse_vox_string(stream)
        value = parse_vox_string(stream)
        push!(keys, key)
        push!(values, value)
    end
    NamedTuple{Symbol.(tuple(keys...))}(values)
end

function chunk_to_data(size::Size)::Vector{UInt8}
    bytes = reinterpret(UInt8, [size.x, size.y, size.z])
    content_size = Int32(length(bytes))
    children_size = Int32(0)
    UInt8["SIZE"..., reinterpret(UInt8, [content_size, children_size])..., bytes...]
end

function chunk_to_data(palette::Vector{RGBA})::Vector{UInt8}
    bytes = mapfoldl(vcat, palette) do rgba
        round.(UInt8, .*(0xff, [rgba.r, rgba.g, rgba.b, rgba.alpha]))
    end
    content_size = Int32(length(bytes))
    children_size = Int32(0)
    UInt8["RGBA"..., reinterpret(UInt8, [content_size, children_size])..., bytes...]
end

function chunk_to_data(voxels::Vector{Voxel})::Vector{UInt8}
    numVoxels = Int32(length(voxels))
    bytes = mapfoldl(vcat, voxels) do voxel
        [voxel.x, voxel.y, voxel.z, UInt8(voxel.i + 1)]
    end
    content_size = Int32(sizeof(numVoxels) + length(bytes))
    children_size = Int32(0)
    UInt8["XYZI"..., reinterpret(UInt8, [content_size, children_size, numVoxels])..., bytes...]
end

function encode_material_property_string(str::String)::Vector{UInt8}
    bytes = Vector{UInt8}(str)
    count = Int32(length(bytes))
    UInt8[reinterpret(UInt8, [count])..., bytes...]
end

function chunk_to_data(material::Material)::Vector{UInt8}
    count = Int32(length(material.properties))
    bytes = mapfoldl(vcat, pairs(material.properties)) do (key, value)
        vcat(encode_material_property_string(String(key)),
             encode_material_property_string(value))
    end
    UInt8[reinterpret(UInt8, [material.id, count])..., bytes...]
end

function placeholder(palette::Vector{<:RGBA}, materials::Vector{Material})::VoxData
    VoxData(
        VOX_VERSION_NUMBER,
        [Model(Size(2, 2, 2), [Voxel(0, 0, 0, 225), Voxel(0, 1, 1, 215), Voxel(1, 0, 1, 235), Voxel(1, 1,0, 5)])],
        palette,
        materials
    )
end

const VOX_VERSION_NUMBER = 150
const _default_palette = [
                0xffffffff, 0xffccffff, 0xff99ffff, 0xff66ffff, 0xff33ffff, 0xff00ffff, 0xffffccff, 0xffccccff, 0xff99ccff, 0xff66ccff, 0xff33ccff, 0xff00ccff, 0xffff99ff, 0xffcc99ff, 0xff9999ff,
    0xff6699ff, 0xff3399ff, 0xff0099ff, 0xffff66ff, 0xffcc66ff, 0xff9966ff, 0xff6666ff, 0xff3366ff, 0xff0066ff, 0xffff33ff, 0xffcc33ff, 0xff9933ff, 0xff6633ff, 0xff3333ff, 0xff0033ff, 0xffff00ff,
    0xffcc00ff, 0xff9900ff, 0xff6600ff, 0xff3300ff, 0xff0000ff, 0xffffffcc, 0xffccffcc, 0xff99ffcc, 0xff66ffcc, 0xff33ffcc, 0xff00ffcc, 0xffffcccc, 0xffcccccc, 0xff99cccc, 0xff66cccc, 0xff33cccc,
    0xff00cccc, 0xffff99cc, 0xffcc99cc, 0xff9999cc, 0xff6699cc, 0xff3399cc, 0xff0099cc, 0xffff66cc, 0xffcc66cc, 0xff9966cc, 0xff6666cc, 0xff3366cc, 0xff0066cc, 0xffff33cc, 0xffcc33cc, 0xff9933cc,
    0xff6633cc, 0xff3333cc, 0xff0033cc, 0xffff00cc, 0xffcc00cc, 0xff9900cc, 0xff6600cc, 0xff3300cc, 0xff0000cc, 0xffffff99, 0xffccff99, 0xff99ff99, 0xff66ff99, 0xff33ff99, 0xff00ff99, 0xffffcc99,
    0xffcccc99, 0xff99cc99, 0xff66cc99, 0xff33cc99, 0xff00cc99, 0xffff9999, 0xffcc9999, 0xff999999, 0xff669999, 0xff339999, 0xff009999, 0xffff6699, 0xffcc6699, 0xff996699, 0xff666699, 0xff336699,
    0xff006699, 0xffff3399, 0xffcc3399, 0xff993399, 0xff663399, 0xff333399, 0xff003399, 0xffff0099, 0xffcc0099, 0xff990099, 0xff660099, 0xff330099, 0xff000099, 0xffffff66, 0xffccff66, 0xff99ff66,
    0xff66ff66, 0xff33ff66, 0xff00ff66, 0xffffcc66, 0xffcccc66, 0xff99cc66, 0xff66cc66, 0xff33cc66, 0xff00cc66, 0xffff9966, 0xffcc9966, 0xff999966, 0xff669966, 0xff339966, 0xff009966, 0xffff6666,
    0xffcc6666, 0xff996666, 0xff666666, 0xff336666, 0xff006666, 0xffff3366, 0xffcc3366, 0xff993366, 0xff663366, 0xff333366, 0xff003366, 0xffff0066, 0xffcc0066, 0xff990066, 0xff660066, 0xff330066,
    0xff000066, 0xffffff33, 0xffccff33, 0xff99ff33, 0xff66ff33, 0xff33ff33, 0xff00ff33, 0xffffcc33, 0xffcccc33, 0xff99cc33, 0xff66cc33, 0xff33cc33, 0xff00cc33, 0xffff9933, 0xffcc9933, 0xff999933,
    0xff669933, 0xff339933, 0xff009933, 0xffff6633, 0xffcc6633, 0xff996633, 0xff666633, 0xff336633, 0xff006633, 0xffff3333, 0xffcc3333, 0xff993333, 0xff663333, 0xff333333, 0xff003333, 0xffff0033,
    0xffcc0033, 0xff990033, 0xff660033, 0xff330033, 0xff000033, 0xffffff00, 0xffccff00, 0xff99ff00, 0xff66ff00, 0xff33ff00, 0xff00ff00, 0xffffcc00, 0xffcccc00, 0xff99cc00, 0xff66cc00, 0xff33cc00,
    0xff00cc00, 0xffff9900, 0xffcc9900, 0xff999900, 0xff669900, 0xff339900, 0xff009900, 0xffff6600, 0xffcc6600, 0xff996600, 0xff666600, 0xff336600, 0xff006600, 0xffff3300, 0xffcc3300, 0xff993300,
    0xff663300, 0xff333300, 0xff003300, 0xffff0000, 0xffcc0000, 0xff990000, 0xff660000, 0xff330000, 0xff0000ee, 0xff0000dd, 0xff0000bb, 0xff0000aa, 0xff000088, 0xff000077, 0xff000055, 0xff000044,
    0xff000022, 0xff000011, 0xff00ee00, 0xff00dd00, 0xff00bb00, 0xff00aa00, 0xff008800, 0xff007700, 0xff005500, 0xff004400, 0xff002200, 0xff001100, 0xffee0000, 0xffdd0000, 0xffbb0000, 0xffaa0000,
    0xff880000, 0xff770000, 0xff550000, 0xff440000, 0xff220000, 0xff110000, 0xffeeeeee, 0xffdddddd, 0xffbbbbbb, 0xffaaaaaa, 0xff888888, 0xff777777, 0xff555555, 0xff444444, 0xff222222, 0xff111111,
    0x00000000]
const DEFAULT_PALETTE = (toRGBA(hex) for hex in _default_palette)
const DEFAULT_MATERIALS = (Material(i, (_type = "_diffuse", _weight = "1", _rough = "0.1", _spec = "0.5", _ior = "0.3")) for i in 0:255)

# module VoxelSpace.MagicaVoxel
