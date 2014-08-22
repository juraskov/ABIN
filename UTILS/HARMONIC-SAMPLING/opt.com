! Example file for geometry optimalization in MOLPRO

gprint,orbital,civector
memory, 80,m;

Angstrom;

geometry={
 O    0.00000000   0.00000000  0.00000000
 O    0.00000000   0.00000000  2.73978989
 O    0.00000000   2.51437067  0.43353898
 O    0.60516640   2.39002316  1.72520094
 H    1.47916624   2.77974929  1.57724839
 H    0.00515515   1.58231156  0.13077538
 H    0.70135910  -0.50389344 -0.42767860
 H   -0.02792413  -0.27977707  0.93904567
 H    0.18808354   0.95320884  2.65668334
 H   -0.80664979  -0.07968974  3.26195060
}

basis=6-31++g**

 hf, maxiter=1000 
 mp2;
 optg;


