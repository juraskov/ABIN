#!/bin/bash
set -euo pipefail

# Parameters passed from Makefile
ABINEXE="$PWD/src/$1 -x mini.dat"

# verify that the number of parameters is correct!
if [[ $# -ne 7 ]]; then
  echo "ERROR: Incorrect number of parameters passed to $0"
  echo "Invoked as:"
  echo "$0 $@"
  exit 1
fi

TESTS="$2"
MPI="$3"
FFTW="$4"
PLUMED="$5"
CP2K="$6"
ACTION="$7"
# NOTE: For MPI tests, we rely on the fact that
# MPI_PATH is exported in Makefile!
if [[ $MPI = "TRUE" && -z ${MPI_PATH:-} ]];then
  echo "ERROR: \$MPI_PATH not set"
  echo "Make sure to set MPI_PATH in make.vars"
  exit 1
fi

if [[ $ACTION = "makeref" ]];then
  echo "ERROR: You should not call makeref on all tests at once."
  echo "Specify a concrete test which you want to modify, e.g."
  echo "make test TEST=CMD"
  exit 1
fi

cd $(dirname $0)
TESTDIR=$PWD

function dif_files {
local status=0
local cont
local files
local f
# Do comparison for all existing reference files
files=$(ls *.ref)
for f in $files   # $* 
do
   file=$(basename $f .ref)
   if [[ -e $file.ref ]];then  # this should now be always true
      error_code=0
      diff -q $file $file.ref || error_code=$?
      if [[ $error_code -eq 2 ]];then
        # This means the $file does not exist.
        # Something is seriously wrong, ABIN probably crashed prematurely.
        # No need for further checks, exit NOW.
        return $error_code

      elif [[ $error_code -ne 0 ]];then
         # The reference file is different, but maybe it's just numerical noise?
         error_code=0
         diff -y -W 500  $file $file.ref | egrep -e '|' -e '<' -e '>' > $file.diff
         ../numdiff.py $file.diff || error_code=$?
         if [[ $error_code -ne 0 ]];then
            # The changes were bigger that the thresholds specified in numdiff.py
            status=$error_code
            echo "File $file differs from the reference."
         fi
      fi
   fi
done
return $status
}

function makeref {
local files
local f
echo "Making new reference files."
files=$(ls *.ref)
for f in $files 
do
   file=$(basename $f .ref)
   if [[ -f $file.ref ]];then
      mv $file $file.ref
   fi
done
}

function clean {
rm -rf $* output
rm -f *.diff
if [[ -e "restart.xyz.0.ref" ]];then
   cp restart.xyz.0.ref restart.xyz
fi
}

err=0

files=( *-RESTART.wfn* cp2k.out bkl.dat phase.dat wfcoef.dat restart_sh.bin restart_sh.bin.old restart_sh.bin.?? nacm_all.dat minimize.dat geom.mini.xyz temper.dat temper.dat radius.dat vel.dat cv.dat cv_dcv.dat  dist.dat angles.dat dihedrals.dat geom.dat.??? geom_mm.dat.??? DYN/OUT* MM/OUT* state.dat stateall.dat stateall_grad.dat ERROR debug.nacm dotprod.dat pop.dat prob.dat PES.dat energies.dat est_energy.dat movie.xyz movie.xyz movie_mini.xyz restart.xyz.old restart.xyz.? restart.xyz.?? restart.xyz SOC.dat )

# Run all tests
if  [[ $TESTS = "all" ]];then
   #folders=( CMD SH_EULER SH_RK4 SH_BUTCHER SH_RK4_PHASE PIMD SHAKE HARMON MINI QMMM GLE PIGLE)
   # DH: Temporarily disable GLE and PIGLE tests
   folders=(CMD SH_EULER SH_RK4 SH_BUTCHER SH_RK4_PHASE LZ_SS LZ_ST LZ_ENE PIMD SHAKE HARMON MINI QMMM)

   let index=${#folders[@]}+1
   # TODO: Split this test, test OpenMP separately
   # We assume we always compile with -fopenmp
   # We should actually try to determine that somehow
   folders[index]=ABINITIO

   if [[ $MPI = "TRUE" ]];then
      let index=${#folders[@]}+1
      folders[index]=REMD
      # TODO: Test MPI interface with TC
      # TODO: Test SH-MPI interface with TC
      # folders[index]=TERAPI # does not yet work
   fi

   if [[ $CP2K = "TRUE" ]];then
      # At this point, we do not support MMWATER potential 
      # with CP2K, which is used in majority of tests
      # ABINITIO needs OpenMP, which is not compatible with CP2K interface
      folders=(SH_BUTCHER HARMON CP2K CP2K_MPI)
   fi

   if [[ $FFTW = "TRUE" ]];then
      let index=${#folders[@]}+1
      folders[index]=PIGLET
      let index++
      folders[index]=PILE
   fi

   if [[ $PLUMED = "TRUE" ]];then
      let index=${#folders[@]}+1
      folders[index]=PLUMED
   fi

else

   # Only one test selected, e.g. by running
   # make test TEST=CMD
   folders=${TESTS}

fi

echo "Running tests in directories:"
echo ${folders[@]}

for dir in ${folders[@]}
do
   if [[ ! -d $dir ]];then
      echo "Directory $dir not found. Exiting prematurely."
      exit 1
   fi
   echo "Entering directory $dir"
   cd $dir

   # Always clean test directory
   # before runnning the test
   if [[ -f "test.sh" ]];then
      ./test.sh clean
   else
      clean ${files[@]}
   fi

   # If we just want to clean the directories,
   # we skip the the actual test here
   if [[ $ACTION = "clean" ]];then
      echo "Cleaning files in directory $dir"
      cd $TESTDIR
      continue
   fi

   # Redirection to dev/null apparently needed for CP2K tests.
   # Otherwise, STDIN is screwed up. I have no idea why.
   # http://stackoverflow.com/questions/1304600/read-error-0-resource-temporarily-unavailable
   # TODO: Figure out a different solution
   if [[ -f "test.sh" ]];then

      #./test.sh $ABINEXE 2> /dev/null
      ./test.sh $ABINEXE || true

   else
      if [[ -f "velocities.in" ]];then
         $ABINEXE -v "velocities.in" > output || true
      else
         $ABINEXE > output || true
      fi

      #for testing restart
      if [[ -e input.in2 ]];then
         $ABINEXE -i input.in2 >> output || true
      fi
   fi

   if [[ $ACTION = "makeref" ]];then

      makeref ${files[@]}

   else

      # Since we're running in the -e mode,
      # we need to "hide" this possibly failing command
      # https://stackoverflow.com/a/11231970/3682277
      current_error=0
      dif_files ${files[@]} || current_error=$?
      if [[ $current_error -ne 0 ]];then
        global_error=1
        echo "$dir FAILED"
      else
        echo "PASSED"
      fi
   fi

   echo "======================="

   cd $TESTDIR
done

echo " "

if [[ ${global_error-0} -ne 0 ]];then
   echo "Some tests DID NOT PASS."
else
   echo "All tests PASSED."
fi

exit $err