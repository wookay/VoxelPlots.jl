module test_voxelspace_magicavoxel_parser

using Test
using VoxelSpace.MagicaVoxel: MagicaVoxel, Voxel, Size, Material, parse_chunk, parse_material, chunk_to_data
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

resource("valid_voxels.bytes") do f
    chunk = [Voxel(0, 0, 0, 225), Voxel(0, 1, 1, 215), Voxel(1, 0, 1, 235), Voxel(1, 1, 0, 5)]
    @test parse_chunk(f) == chunk

    seekstart(f)
    @test chunk_to_data(chunk) == read(f)
end

resource("valid_palette.bytes") do f
    chunk = parse_chunk(f)
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
    @test chunk_to_data(chunk) == read(f)
end

end # module test_voxelspace_magicavoxel_parser
