# genprism2
Generate 3D triangulated mesh of an arbitrary prism with caps

### Requirements
`genprism2.pl` requires two pieces of external software to operate. Both are easily installable 
on popular Linux systems. On Red Hat or Fedora, install them with:

    sudo yum install gmsh meshlab

### Usage
    genprism2.pl outfile.obj N x1 y1 x2 y2 x3 y3 [x4 y4 .. xN yN] [-t tx ty tz]

### Origin
The Radiance Synthetic Imaging System contains a script called `genprism`, which can be
called from an input file and allows creation of capped, but only convex, coordinate loops.
If the 2d loop is not convex, the end caps are not correct.

This program is not a drop-in replacement for Radiance's `genprism`, but will need to be
run before scene generation. For example, with traditional Radiance, one would include the
following line in an input file:

    !genprism mat name 3 0 0 2 0 0 3 -l 0 0 4

But with `genprism2.pl`, one would need to run the following two command-lines first:

    genprism2.pl out.obj 3 0 0 2 0 0 3 -l 0 0 4
    obj2mesh out.obj > out.msh

and then use the following lines in the input file:

    mat mesh name
    1 out.msh
    0
    0

This is clearly more work, but is necessary if your prism outline is convex.

### Future work
There are many improvements that are obviously useful:

1) Ability to output Radiance code directly, allowing it to be included in the input file itself.
2) Support for -r -c and -e options and file or stdin inputs.
3) Support for holes in the 2d shape.
4) Support more advanced `gmsh` features for bevels and rounding.

