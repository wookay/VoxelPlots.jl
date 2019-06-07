module test_voxelspace_magicavoxel_parser

using Test
using VoxelSpace.MagicaVoxel: MagicaVoxel, Chunk, Size, Material, parse_chunk, parse_material, chunk_to_data
using Colors: RGBA

@test MagicaVoxel.DEFAULT_PALETTE[10] == 0x99ccff
@test MagicaVoxel.toRGBA(0x99ccff) == RGBA(1, 0.8, 0.6, 1)

function resource(block, filename)
    path = normpath(@__DIR__, "resources", filename)
    f = open(path)
    block(f)
    close(f)
end

resource("valid_size.bytes") do f
    chunk = Size(24, 24, 24)
    @test parse_chunk(f) == chunk

    seekstart(f)
    @test chunk_to_data(chunk) == read(f)
end

resource("valid_palette.bytes") do f
    palette = parse_chunk(f)
    @test length(palette) == 256
    @test palette[1] == RGBA(1, 1, 1, 1)
    @test palette[end-1] == RGBA(17/255, 17/255, 17/255, 1)
    @test palette[end] == RGBA(0, 0, 0, 0)

    seekstart(f)
    @test chunk_to_data(palette) == read(f)
end

resource("valid_material.bytes") do f
    m = parse_material(f)
    @test m.id == 0
    @test m.properties == (_type = "_diffuse", _weight = "1", _rough = "0.1", _spec = "0.5", _ior = "0.3")

    seekstart(f)
    @test chunk_to_data(m) == read(f)
end

end # module test_voxelspace_magicavoxel_parser
