#!/usr/bin/env bash
# Updated version to handle direct writing of sliced grids

ps=gspline_4.ps

# Figure 5 in Wessel, P. (2009), A general-purpose Green's function-based
#	interpolator, Computers & Geosciences, 35, 1247-1254.

R3D=5/40/-5/10/5/16
R2D=12/32/0/6
Z=5/10
dz=0.25
view=200/25
method=r
tens=0.85
echo gmt greenspline -R$R3D -I$dz -G3D_%5.2lf.grd @Table_5_23.txt -S${method}${tens} -D5
# Make a list of the grids
ls 3D_?????.grd > t.lis
gmt psbasemap -R$R2D/$Z -JX6i/3i -JZ2.5i -p$view -Bx5f1g1 -By1g1 -Bz2f1 -BWSneZ+b -P -K > $ps
# Plot a small cube at the data points
gmt psxyz -R -JX -JZ -p$view -O -K @Table_5_23.txt -Su0.05i -Gblack -Wfaint >> $ps
# Loop over the sliced grids and draw the 10 % contour only
let k=0
while read grid; do
	z=$(gmt math -Q 5 $k $dz MUL ADD =)
#	echo "Doing z = $z"
	gmt grdcontour -R$R2D $grid -JX -C10 -L9/11 -S8 -Ddump
	$AWK '{if ($1 == ">") {print $0} else {print $1, $2, '$z'}}' dump > tmp
	gmt psxyz -R$R2D/$Z -JX -JZ -p$view -O -K tmp -Gp39+r300+fgray+b- -Wthin >> $ps
	let k=k+1
done < t.lis
echo "12 6 Volume exceeding 10% UO@-2@- concentration" | gmt pstext -R$R2D/$Z -JX -JZ -p$view -F+jLT+f16p -O -K -Z10 -Dj0.1i >> $ps
gmt psxyz -R -JX -JZ -p$view -O -Wthin << EOF >> $ps
>
12 0 5
12 0 10
>
12 0 10
12 6 10
>
12 0 10
32 0 10
EOF
