module test_voxelspace_magicavoxel_chunktree

using Test
using VoxelSpace.MagicaVoxel
using .MagicaVoxel: VoxData, ChunkStream, ChunkTree
using AbstractTrees

vox_dir = normpath(@__DIR__, "resources")

function resource(filename)::Tuple{ChunkTree, VoxData}
    path = normpath(vox_dir, filename)
    f = open(path)
    tree = ChunkTree([], UInt8[])
    stream = ChunkStream(f, tree)
    vox = MagicaVoxel.parse_vox_file(stream)
    close(f)
    return (tree, vox)
end

function Base.show(io::IO, tree::ChunkTree)
    print(io, "ChunkTree")
end

(tree, vox) = resource("placeholder.vox")
buf = IOBuffer()
AbstractTrees.print_tree(buf, tree)
@test String(take!(buf)) == """
ChunkTree
├─ ChunkUnit(:MAIN, 1, 20 bytes)
├─ ChunkUnit(:SIZE, 1, 24 bytes)
├─ ChunkUnit(:XYZI, 1, 32 bytes)
├─ ChunkUnit(:nTRN, 1, 40 bytes)
├─ ChunkUnit(:nGRP, 1, 28 bytes)
├─ ChunkUnit(:nTRN, 1, 55 bytes)
├─ ChunkUnit(:nSHP, 1, 32 bytes)
├─ ChunkUnit(:LAYR, 8, 304 bytes)
├─ ChunkUnit(:RGBA, 1, 1036 bytes)
├─ ChunkUnit(:MATL, 256, 26880 bytes)
├─ ChunkUnit(:rLIT, 2, 176 bytes)
├─ ChunkUnit(:rAIR, 1, 93 bytes)
├─ ChunkUnit(:rLEN, 1, 99 bytes)
├─ ChunkUnit(:POST, 1, 83 bytes)
└─ ChunkUnit(:rDIS, 1, 87 bytes)
"""

end # module test_voxelspace_magicavoxel_chunktree
