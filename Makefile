# Super simple Makefile for ABIN

# The user-defined variables are included from file "make.vars',
# which is not under version control
# No user modification to this Makefile file should be necessary.

# Simply type "make" and you should get the binary named $BIN
# Before recompiling, it is wise to clean up by "make clean"

# WARNING: dependecies on *.mod files are not properly resolved here!
# If you change modules, you should recompile the whole thing by running
# $ make clean && make

# For compilation with static system libraries, see:
# https://gcc.gnu.org/bugzilla/show_bug.cgi?id=46539

# Some defaults, likely to be overwritten by make.vars
# By default run all tests in TESTS/
TEST=all
# ABIN binary name
BIN=abin
# Optional compilation parameters
# Some functionality will not work without them
MPI=FALSE
FFTW=FALSE
CP2K=FALSE
PLUMED=FALSE
LIBS=

# Export all vars into submake commands
export
# User-defined compilation parameters are in make.vars
# and should override defaults defined above
include make.vars

export SHELL=/bin/bash
export DATE=`date +"%X %x"`

export COMMIT=NaN
ifeq ($(shell git --version | cut -b -3),git)
  ifneq ($(shell git status 2>&1 | head -1 | cut -b -5),fatal)
    export COMMIT=`git rev-parse HEAD`
  endif
endif

F_OBJS := modules.o fortran_interfaces.o utils.o io.o random.o arrays.o qmmm.o fftw_interface.o \
          shake.o nosehoover.o gle.o transform.o potentials.o estimators.o ekin.o vinit.o plumed.o \
          remd.o force_bound.o water.o force_cp2k.o sh_integ.o surfacehop.o landau_zener.o\
          force_mm.o force_tera.o force_terash.o force_abin.o en_restraint.o analyze_ext_template.o geom_analysis.o analysis.o \
          minimizer.o mdstep.o forces.o read_cmdline.o init.o

C_OBJS := water_interface.o

ifeq ($(strip $(FFTW)),TRUE)
  DFLAGS += -DUSE_FFTW
  ifeq ($(CP2K),TRUE)
    $(info "!!!!!-------------WARNING---------------!!!!!!!")
    $(info "Using FFTW flag with CP2K may lead to troubles!")
    $(info "!!!!!-------------WARNING---------------!!!!!!!")
    $(info "")
  else
    LIBS += -lfftw3
  endif
endif

ifeq ($(strip $(CP2K)),TRUE)
  DFLAGS += -DCP2K 
  # OpenMP does not work with -fno-underscoring
  FFLAGS += -fno-underscoring -fno-openmp
  # The following variables should be the same that were used to compile CP2K.
  # Also, be carefull with FFTW clashes
  LIBS += -L${CP2K_PATH} -lcp2k ${CP2K_LIBS} 
endif

ifeq ($(strip $(PLUMED)),TRUE)
 include ${PLUMED_INC}
 DFLAGS += -DUSE_PLUMED
 LIBS += ${PLUMED_STATIC_LOAD}
endif

ifeq  ($(strip $(MPI)),TRUE) 
  DFLAGS += -DUSE_MPI
endif

LIBS += -lm -lstdc++
# The following line for statically linking GFortran libs does not seem to work
#LIBS := ${LIBS} -static-libgfortran -Wl,-Bstatic -lstdc++ -lm -Wl,-Bdynamic  

# This is the default target
# TODO: Move all source code to src/ and call $(MAKE) -C src
${BIN} : libabin.a
	$(MAKE) -C WATERMODELS all
	${FC} ${FFLAGS} abin.o -L. -labin -LWATERMODELS/ -lwater ${LIBS} -o $@

# Used for building Unit Tests
libabin.a: compile_info.o
	ar cru libabin.a ${C_OBJS} $(F_OBJS) compile_info.o && ranlib libabin.a

# compile_info.F90 must be always recompiled to get the current date/time and git commit
compile_info.o: compile_info.F90 ${C_OBJS} ${F_OBJS} abin.o
	$(FC) $(FFLAGS) $(DFLAGS) $(INC) -DCOMPILE_DATE="'${DATE}'" -DGIT_COMMIT="'${COMMIT}'" -c $<


# Build and run Unit tests
unittest: ${BIN}
	$(MAKE) -C unit_tests all
	$(MAKE) -C unit_tests test

clean:
	$(MAKE) -C WATERMODELS clean
	/bin/rm -f *.o *.mod *.gcno *gcda libabin.a $(BIN)
ifneq ($(strip $(PFUNIT_PATH)),)
	$(MAKE) -C unit_tests clean
endif

# Run the test suite
test: ${BIN}
ifneq ($(strip $(PFUNIT_PATH)),)
	$(MAKE) unittest
endif
	/bin/bash TESTS/test.sh ${BIN} $(TEST) ${MPI} ${FFTW} ${PLUMED} ${CP2K} test

# Clean all test folders.
testclean:
	/bin/bash TESTS/test.sh ${BIN} $(TEST) ${MPI} ${FFTW} $(PLUMED) ${CP2K} clean

# This will automatically generate new reference data for tests
makeref:
	/bin/bash TESTS/test.sh ${BIN} $(TEST) ${MPI} ${FFTW} $(PLUMED) ${CP2K} makeref


.PHONY: clean test testclean makeref unittest

%.o: %.F90
	$(FC) $(FFLAGS) $(DFLAGS) $(INC) -c $<

%.o: %.cpp
	$(CXX) $(CXXFLAGS) $(DFLAGS) -c $<

# TODO: Use only .F90
%.o: %.f90
	$(FC) $(FFLAGS) $(DFLAGS) $(INC) -c $<

