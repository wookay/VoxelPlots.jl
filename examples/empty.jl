using VoxelSpace.MagicaVoxel
using .MagicaVoxel: VoxData

# const vox_dir = "/Applications/MagicaVoxel-0.99.4-alpha-macos/vox/"
const vox_dir = normpath(@__DIR__, "vox")

function resource(filename)::VoxData
    path = normpath(vox_dir, filename)
    f = open(path)
    vox = MagicaVoxel.parse_vox_file(f)
    close(f)
    return vox
end

using Jive
@skip begin
vox = resource("empty.vox")
@info :empty vox.models
end # @skip

using Colors: RGBA, @colorant_str

vox = resource("empty2.vox")
@info :voxels vox.models[1].voxels
@info :palette vox.palette[0xb4+1] == RGBA(colorant"cyan")
