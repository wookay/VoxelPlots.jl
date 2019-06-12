module test_voxelplots_magicavoxel_parser

using Test
using VoxelPlots.MagicaVoxel
using .MagicaVoxel: Voxel, Model, Size, Material, VoxData, ChunkError, ChunkStream, ChunkTree
using .MagicaVoxel: DEFAULT_PALETTE, DEFAULT_MATERIALS
using .MagicaVoxel: parse_chunk, parse_material, parse_vox_file, chunk_to_data, placeholder
using Colors: RGBA

function resource(block, filename)
    path = normpath(@__DIR__, "resources", filename)
    f = open(path)
    tree = ChunkTree([], UInt8[])
    stream = ChunkStream(f, tree)
    block(stream)
    close(stream)
end

# https://github.com/davidedmonds/dot_vox/blob/master/src/parser.rs#L209

resource("valid_size.bytes") do f
    chunk = Size(24, 24, 24)
    @test parse_chunk(f) == (:SIZE, chunk)

    seekstart(f)
    @test chunk_to_data(chunk) == read(f)
end

resource("valid_voxels.bytes") do f
    chunk = [Voxel(0, 0, 0, 225), Voxel(0, 1, 1, 215), Voxel(1, 0, 1, 235), Voxel(1, 1, 0, 5)]
    @test parse_chunk(f) == (:XYZI, chunk)

    seekstart(f)
    @test chunk_to_data(chunk) == read(f)
end

resource("valid_palette.bytes") do f
    (chunk_id, chunk) = parse_chunk(f)
    @test chunk isa Vector{RGBA}
    @test length(chunk) == 256
    @test chunk[1] == RGBA(1, 1, 1, 1)
    @test chunk[end-1] == RGBA(17/255, 17/255, 17/255, 1)
    @test chunk[end] == RGBA(0, 0, 0, 0)

    seekstart(f)
    @test chunk_to_data(chunk) == read(f)
end

resource("valid_material.bytes") do f
    chunk = Material(0, (_type = "_diffuse", _weight = "1", _rough = "0.1", _spec = "0.5", _ior = "0.3"))
    @test parse_material(f) == chunk

    seekstart(f)
    @test chunk_to_data(chunk)[12+1:end] == read(f)
end

resource("default_palette.bytes") do f
    chunk = MagicaVoxel.build_chunk(Val{:RGBA}(), f, 0, 0)
    @test first(chunk) == first(DEFAULT_PALETTE)
    @test MagicaVoxel.toRGBA(0xff99ccff) == RGBA(1, 0.8, 0.6, 1)
end

# https://github.com/davidedmonds/dot_vox/blob/master/src/lib.rs#L162

@test_throws ChunkError("Not a valid MagicaVoxel .vox file") MagicaVoxel.load(normpath(@__DIR__, "resources", "not_a.vox"))
@test_throws ChunkError("Unable to read file")               MagicaVoxel.load(normpath(@__DIR__, "resources", "not_here.vox"))

resource("placeholder.vox") do f
    chunk = parse_vox_file(f)
    @test chunk isa VoxData
    @test chunk.version == 150
    @test chunk.models[1].voxels == [Voxel(0, 0, 0, 225), Voxel(0, 1, 1, 215), Voxel(1, 0, 1, 235), Voxel(1, 1,0, 5)]
    @test first(chunk.palette) == first(DEFAULT_PALETTE)
    @test chunk.materials[1] == Material(0, (_type = "_diffuse", _weight = "1", _rough = "0.1", _spec = "0.5", _ior = "0.3"))
    @test chunk == placeholder(collect(DEFAULT_PALETTE), collect(DEFAULT_MATERIALS))

    seekstart(f)
    data = chunk_to_data(chunk)
    modeldata = chunk_to_data(chunk.models)
    @test data[1:16] == read(f, 20)[1:16] # VOX  version MAIN content_size
    @test modeldata == data[21:20+56] == read(f, 56)
end

resource("placeholder-with-materials.vox") do f
    chunk = parse_vox_file(f)
    materials = collect(DEFAULT_MATERIALS)
    materials[216+1] = Material(216, (_type = "_metal", _weight = "0.694737", _plastic = "1", _rough = "0.389474", _spec = "0.821053", _ior = "0.3"))
    @test chunk == placeholder(collect(DEFAULT_PALETTE), materials)
end

end # module test_voxelplots_magicavoxel_parser
