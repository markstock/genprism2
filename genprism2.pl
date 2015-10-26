#!/usr/bin/perl
#
# Rewrite of Radiance's genprism, but will create proper-capped prisms
#
# usage:
#   genprism2.pl outfile N [x1 y1 x2 y2 .. xN yN] [-l lvec] [-nodec]
#
# will create a .obj file with caps and closing polygon using the lvec 3-tuple extrusion vector
#
# requires meshlab and gmsh
#

use strict;
use warnings;
use File::Temp qw/ tempfile /;
use List::Util qw( min max );

# Check for requirements

my $gmshExists = `which gmsh`;
if (length $gmshExists < 1) {
  print "gmsh executable does not exist or is not in your PATH\n";
  print "On Red Hat/Fedora, try \"sudo yum install gmsh\"\n";
  print "Quitting.\n";
  exit(1);
}
chomp ${gmshExists};
print "Using ${gmshExists}\n";

my $meshlabExists = `which meshlabserver`;
if (length $meshlabExists < 1) {
  print "meshlab executable does not exist or is not in your PATH\n";
  print "On Red Hat/Fedora, try \"sudo yum install meshlab\"\n";
  print "Quitting.\n";
  exit(1);
}
chomp ${meshlabExists};
print "Using ${meshlabExists}\n";

# Set defaults/initialization

my @x;
my @y;
my $nPts = 0;
my $tx = 0;
my $ty = 0;
my $tz = 1;
my $outFile = "out.obj";
my $noDecimate = 0;

# Read command-line into arrays

my $nargs = @ARGV;
if ($nargs < 2) {
  print "At least two arguments are required:\n";
  print "    outfile.obj N\n";
  exit();
}

$outFile = $ARGV[0];
$nPts = $ARGV[1];
if ($nPts < 3) {
  print "Program needs more than two points to make a prism.\n";
  exit();
}
my $iarg = 1;
for (my $ipt=0; $ipt<$nPts; $ipt++) {
  if (++$iarg >= $nargs) {
    print "Not enough coordinates on command line, expecting ",$nPts*2," numbers.\n";
    exit(1);
  }
  push @x, $ARGV[$iarg];

  if (++$iarg >= $nargs) {
    print "Not enough coordinates on command line, expecting ",$nPts*2," numbers.\n";
    exit(1);
  }
  push @y, $ARGV[$iarg];
}
print "Found $nPts points.\n";
$iarg++;

# Get estimate for length scale
my $xrange = max @x - min @x;
my $yrange = max @y - min @y;
my $lengthScale = $xrange > $yrange ? $xrange : $yrange;
#print "Length scale is ${lengthScale}\n";

# Look for optional arguments

for (; $iarg<$nargs; $iarg++) {
  if ($ARGV[$iarg] eq "-t") {
    if ($iarg+3 >= $nargs) {
      print "Not enough components on command line, expecting 3 floats.\n";
      exit(1);
    }
    $tx = $ARGV[++$iarg];
    $ty = $ARGV[++$iarg];
    $tz = $ARGV[++$iarg];
    if (abs($tx) + abs($ty) + abs($tz) == 0) {
      print "Cannot use zero-length extrusion vector.\n";
      exit(1);
    } else {
      print "Read extrusion vector $tx $ty $tz\n";
      my $extLen = sqrt($tx*$tx + $ty*$ty + $tz*$tz);
      $lengthScale = $extLen > $lengthScale ? $extLen : $lengthScale;
      #print "Length scale is ${lengthScale}\n";
    }
  } elsif ($ARGV[$iarg] eq "-nodec") {
    $noDecimate = 1;
  } else {
    print "Unrecognized argument ($ARGV[$iarg]).\n";
  }
}

# Generate meshlabserver script file if it's not already there
# this one works on Meshlab 1.3.3

my ($mlabFH, $mlabFileName) = tempfile( SUFFIX => '.mlx');
print $mlabFH "<!DOCTYPE FilterScript>\n";
print $mlabFH "<FilterScript>\n";
print $mlabFH " <filter name=\"Remove Duplicated Vertex\"/>\n";
print $mlabFH " <filter name=\"Re-Orient all faces coherentely\"/>\n";
print $mlabFH " <filter name=\"Invert Faces Orientation\">\n";
print $mlabFH "  <Param type=\"RichBool\" value=\"true\" name=\"forceFlip\"/>\n";
print $mlabFH "  <Param type=\"RichBool\" value=\"true\" name=\"onlySelected\"/>\n";
print $mlabFH " </filter>\n";
print $mlabFH " <filter name=\"Remove Duplicated Vertex\"/>\n";
if (! $noDecimate) {
  # theoretically, we should be able to reduce to 4*(nPts-1)
  # but that doesn't always work well with QECD, so reduce to double that number
  my $nTri = 8*($nPts-1);
  print $mlabFH " <filter name=\"Quadric Edge Collapse Decimation\">\n";
  print $mlabFH "   <Param type=\"RichInt\" value=\"${nTri}\" name=\"TargetFaceNum\"/>\n";
  print $mlabFH "   <Param type=\"RichFloat\" value=\"0\" name=\"TargetPerc\"/>\n";
  print $mlabFH "   <Param type=\"RichFloat\" value=\"0.3\" name=\"QualityThr\"/>\n";
  print $mlabFH "   <Param type=\"RichBool\" value=\"false\" name=\"PreserveBoundary\"/>\n";
  print $mlabFH "   <Param type=\"RichFloat\" value=\"1\" name=\"BoundaryWeight\"/>\n";
  print $mlabFH "   <Param type=\"RichBool\" value=\"false\" name=\"PreserveNormal\"/>\n";
  print $mlabFH "   <Param type=\"RichBool\" value=\"false\" name=\"PreserveTopology\"/>\n";
  print $mlabFH "   <Param type=\"RichBool\" value=\"true\" name=\"OptimalPlacement\"/>\n";
  print $mlabFH "   <Param type=\"RichBool\" value=\"true\" name=\"PlanarQuadric\"/>\n";
  print $mlabFH "   <Param type=\"RichBool\" value=\"false\" name=\"QualityWeight\"/>\n";
  print $mlabFH "   <Param type=\"RichBool\" value=\"true\" name=\"AutoClean\"/>\n";
  print $mlabFH "   <Param type=\"RichBool\" value=\"false\" name=\"Selected\"/>\n";
  print $mlabFH " </filter>\n";
}
print $mlabFH "</FilterScript>\n";
close($mlabFH);

# Generate gmsh input file

my ($gmshFH, $gmshFileName) = tempfile( SUFFIX => '.geo');

print $gmshFH "Mesh.Format = 27;\n";
print $gmshFH "Mesh.CharacteristicLengthMax = ${lengthScale};\n";
for (my $ipt=0; $ipt<$nPts; $ipt++) {
  print $gmshFH "Point(",$ipt+1,") = {$x[$ipt], $y[$ipt], 0};\n";
}
for (my $ipt=1; $ipt<=$nPts; $ipt++) {
  my $iptp1 = $ipt+1;
  if ($ipt == $nPts) { $iptp1 = 1; }
  print $gmshFH "Line($ipt) = {$ipt, $iptp1};\n";
}
print $gmshFH "Line Loop(",$nPts+1,") = {";
for (my $ipt=1; $ipt<$nPts; $ipt++) {
  print $gmshFH "$ipt,";
}
print $gmshFH "$nPts};\n";
print $gmshFH "Plane Surface(",$nPts+2,") = {",$nPts+1,"};\n";
print $gmshFH "Extrude {$tx, $ty, $tz} {Surface{",$nPts+2,"};}\n";
close($gmshFH);

# Execute gmsh and meshlabserver

my ($stlFH, $stlFileName) = tempfile( SUFFIX => '.stl');
my $command = "gmsh ${gmshFileName} -2 -v 0 -o ${stlFileName}";
print "Running \"${command}\"\n";
system $command;

$command = "meshlabserver -i ${stlFileName} -s ${mlabFileName} -o ${outFile}";
print "Running \"${command}\"\n";
system $command;

# Delete intermediaries

unlink $stlFileName;
unlink $mlabFileName;
unlink $gmshFileName;

print "Done.\n";
