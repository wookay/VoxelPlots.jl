using VoxelPlots.MagicaVoxel
using .MagicaVoxel: VoxData, ChunkStream, ChunkTree, chunk_to_data
using AbstractTrees
using Test

# const vox_dir = "/Applications/MagicaVoxel-0.99.4-alpha-macos/vox/"
const vox_dir = normpath(@__DIR__, "vox")

function resource(filename)::Tuple{ChunkTree, VoxData}
    path = normpath(vox_dir, filename)
    f = open(path)
    tree = ChunkTree([], UInt8[])
    stream = ChunkStream(f, tree)
    vox = MagicaVoxel.parse_vox_file(stream)
    close(stream)
    return (tree, vox)
end

(tree, vox) = resource("empty.vox")
using Colors: RGBA, @colorant_str

(tree2, vox2) = resource("empty2.vox")
# @info :voxels vox2.models[1].voxels
# @info :palette vox2.palette[0xb4+1] == RGBA(colorant"cyan")

@test chunk_to_data(tree, vox2) == chunk_to_data(tree2, vox2)
@test vox.materials == vox2.materials
@test vox.palette == vox2.palette
append!(vox.models[1].voxels, vox2.models[1].voxels)
@test vox == vox2
