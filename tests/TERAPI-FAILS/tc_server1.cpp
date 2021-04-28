#include <cstdlib>
#include <cstring>

#include "../tc_mpi_api.h"

// HERE we test how ABIN responds if we send the
// MPI_SCF_DIE (i.e. when SCF does not converge).
// ABIN should stop immediately.

int main(int argc, char* argv[])
{
  char *serverName = NULL;

  // Due to a bug in hydra_nameserver, it crashes
  // when multiple TC servers call `MPI_Unpublish_name()`
  // Hence, we want to allow invoking without this parameter,
  // in which case TC server will just print the port to stdin,
  // where it could be grepped and passed via file to ABIN,
  // and it will never call MPI_Publish_name/MPI_Unpublish_name
  // NOTE: This behaviour is different from real TC,
  // which has default serverName and will always try to publish it.
  if (argc > 2) {
    printf("Only one cmdline argument supported, <serverName>, but you provided more!");
    throw std::runtime_error("Incorrect invocation");
  }

  if (argc == 2) {
    serverName = new char[1024];
    strcpy(serverName, argv[1]);
  }

  TCServerMock tc = TCServerMock(serverName);

  if (serverName) {
    delete[] serverName;
  }

  tc.initializeCommunication();

  tc.receiveNumAtoms();
  tc.receiveAtomTypes();

  int loop_counter = 0;
  int MAX_LOOP_COUNT = 100;
  // Will go through this loop until MPI client gives an exit signal.
  while (true) {

    int status = tc.receiveBeginLoop();
    if (status == MPI_TAG_EXIT) {
      break;
    }

    tc.receiveAtomTypesAndScrdir();
    tc.receiveCoordinates();

    // Energies and gradients from qTIP4PF potential
    double energy = tc.getWaterGradients();

    // Let's simulate that SCF did not converge.
    int MPI_SCF_DIE = 1;
    tc.sendSCFEnergy(energy, MPI_SCF_DIE);
 
    tc.sendQMCharges();
 
    tc.sendQMDipoleMoment();

    // NOTE: In the real TC interface, gradients are sent
    // conditionally only if they are requested.
    // But we always request them in ABIN (see tc.receive).
    tc.sendQMGradients();
      
    // This is just a precaution, we don't want endless loop!
    loop_counter++;
    if (loop_counter > MAX_LOOP_COUNT) {
      printf("Maximum number of steps exceeded!\n");
      return(1);
    }
  }
  
  return(0);
}
