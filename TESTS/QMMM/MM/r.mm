#!/bin/bash
cd MM
EXE=dftb+

timestep=$1
ibead=$2
input=input$ibead
geom=../geom_mm.dat.$ibead

natom=`cat $geom | wc -l`
WRKDIR=OUT$ibead.$natom
mkdir -p $WRKDIR ; cd $WRKDIR

cat > geom_in.gen << EOF
$natom C
O H

EOF

awk 'BEGIN{
id[1]=1
id[2]=2
id[3]=2
id[4]=1
id[5]=2
id[6]=2
}{print NR,id[NR],$2,$3,$4}' ../$geom >> geom_in.gen

if [ -e charges.bin ];then
   sed 's/#ReadInitialCharges/ReadInitialCharges/' ../dftb_in.hsd > dftb_in.hsd
else
   cp ../dftb_in.hsd .
fi

rm -f detailed.out

$EXE  &> $input.out
################################
cp $input.out $input.out.old

### EXTRACTING ENERGY AND FORCES
grep 'Total energy:' detailed.out | awk '{print $3}' >> ../../engrad_mm.dat.$ibead
awk -v natom=$natom '{if ($2=="Forces"){for (i=1;i<=natom;i++){getline;printf"%3.15e %3.15e %3.15e \n",-$1,-$2,-$3}}}' \
 detailed.out >> ../../engrad_mm.dat.$ibead

