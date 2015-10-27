# genprism2
Generate 3D triangulated mesh of an arbitrary prism with caps

### Requirements
`genprism2.pl` requires two pieces of external software to operate. Both are easily installable 
on popular Linux systems. On Red Hat or Fedora, install them with:

    sudo yum install gmsh meshlab

### Usage
    genprism2.pl N x1 y1 x2 y2 x3 y3 [x4 y4 .. xN yN] [-t tx ty tz] [-nodec] [-of obj|stl|dae|ply]

The default extrusion vector is `0 0 1` and default file format is `obj`.

Give the `-nodec` option if you do not want meshlabserver to try to decimate the mesh (reduce the
triangle count to something closer to the optimal minimum). Normally, `genprism2.pl` will try to 
reduce the triangle count to 8*(N-1).

Because Meshlab recognizes a variety of file formats, feel free to try different extensions
on the output file name.

The program generates several temporary intermediate files which should be automatically removed when the program exits.

### Origin
The Radiance Synthetic Imaging System contains a script called `genprism`, which can be
called from an input file and allows creation of capped, coordinate loops.
But if the 2d loop is not convex, and you apply a transparent material, the end caps
do not behave correctly.

This program is not a drop-in replacement for Radiance's `genprism`, but will need to be
run before scene generation. For example, with traditional Radiance, one would include the
following line in an input file:

    !genprism mat name 3 0 0 2 0 0 3 -l 0 0 4

But with `genprism2.pl`, one would need to run the following two command-lines first:

    genprism2.pl 3 0 0 2 0 0 3 -l 0 0 4 > out.obj
    obj2mesh out.obj > out.msh

and then use the following lines in the input file:

    mat mesh name
    1 out.msh
    0
    0

This is clearly more work, but is necessary if your prism outline is convex.

### Future work
There are many improvements that are obviously useful:

* Ability to output Radiance code directly, allowing it to be included in the input file itself.
* Support for -r -c and -e options.
* Support for holes in the 2d shape.
* Support more advanced `gmsh` features for bevels and rounding.
* If first two args are not numeric, assume they are material and name, and operate as a genprism drop-in replacement; write a temporary .obj file, convert it to msh, and write the "mat mesh name" entry to stdout.

