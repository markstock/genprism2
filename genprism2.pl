#!/usr/bin/perl
#
# Rewrite of Radiance's genprism, but will create proper-capped prisms
#
# usage:
#   genprism2.pl outfile N [x1 y1 x2 y2 .. xN yN] [-l lvec]
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
  } else {
    print "Unrecognized argument ($ARGV[$iarg]).\n";
  }
}

# Generate meshlabserver script file if it's not already there

my $meshScript = ".reorientAndDedup.mlx";
if (! -f "${meshScript}") {
  open(MLS,">${meshScript}") or die "Can't open ${meshScript}: $!";
  print MLS "<!DOCTYPE FilterScript>\n";
  print MLS "<FilterScript>\n";
  print MLS " <filter name=\"Remove Duplicated Vertex\"/>\n";
  print MLS " <filter name=\"Re-Orient all faces coherentely\"/>\n";
  print MLS " <filter name=\"Invert Faces Orientation\">\n";
  print MLS "  <Param type=\"RichBool\" value=\"true\" name=\"forceFlip\"/>\n";
  print MLS " </filter>\n";
  print MLS " <filter name=\"Remove Duplicated Vertex\"/>\n";
  print MLS "</FilterScript>\n";
  close(MLS);
}

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

$command = "meshlabserver -i ${stlFileName} -s ${meshScript} -o ${outFile}";
print "Running \"${command}\"\n";
system $command;

# Delete intermediaries

unlink $stlFileName;
unlink $gmshFileName;

print "Done.\n";
