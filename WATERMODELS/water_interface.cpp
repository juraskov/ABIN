// Copyright 2013 Volodymyr Babin <vb27606@gmail.com>
//
// This is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your
// option) any later version.
//
// The code is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
// more details.
//
// You can find a copy of the GNU General Public License at
// http://www.gnu.org/licenses/.

#include <cmath>
#include <cassert>
#include <cstdlib>

#include <fstream>
#include <iomanip>
#include <iostream>
#include <stdexcept>

#include "ttm2f.h"
#include "ttm3f.h"
#include "ttm4f.h"

#include "qtip4pf.h"

////////////////////////////////////////////////////////////////////////////////
extern"C" {
void force_water_(const double *x,const double  *y,const double *z, double *fx,double *fy,double *fz, double *eclas,const int *natom,const int* nwalk, const int *watpot)
{
   const int nwater = *natom/3;
   double E;
   double grd[9*nwater];
   double crd[9*nwater];

   // conversion constants
   const double ANG=1.889726132873;
   const double AUTOKCAL=627.50946943;
   const double FAC=1/ANG/AUTOKCAL;


   h2o::qtip4pf pot1;
   h2o::ttm2f pot2;
   h2o::ttm3f pot3;
   h2o::ttm4f pot4;

   for (int iw=0;iw < *nwalk;iw++) {

      for (int iat=0; iat < *natom;iat++) {
         crd[3*iat]=x[iw*(*natom)+iat]/ANG;
         crd[3*iat+1]=y[iw*(*natom)+iat]/ANG;
         crd[3*iat+2]=z[iw*(*natom)+iat]/ANG;
      }
/*      
      std::cout <<  "Coordinates" << std::endl;
      for (int iat=0; iat < *natom;iat++) {
         std::cout << crd[iat*3] <<"\t"<< crd[iat*3+1] <<"\t"<< crd[iat*3+2] << std::endl;
      }
*/

      switch ( *watpot) {
      case 1:
         E = pot1(nwater, crd, grd);
         break;
      case 2:
         E = pot2(nwater, crd, grd);
         break;
      case 3:
         E = pot3(nwater, crd, grd);
         break;
      case 4:
         E = pot4(nwater, crd, grd);
         break;
      default:
         //TODO: move this check to check_water subroutine
         std::cerr << "Error: Parameter watpot out of range." << std::endl;
         //return 1;
        break;
      }
//      std::cout << "Energy is:" << E << std::endl;
      *eclas += E;

/*      
      std::cout <<  "Gradients" << std::endl;
      for (int iat=0; iat < *natom;iat++) {
         std::cout << grd[iat*3]*FAC <<"\t"<< grd[iat*3+1]*FAC <<"\t"<< grd[iat*3+2]*FAC << std::endl;
      }
*/    

      for (int iat=0; iat < *natom;iat++) {
         fx[iw*(*natom)+iat]=-grd[3*iat]*FAC;
         fy[iw*(*natom)+iat]=-grd[1+3*iat]*FAC;
         fz[iw*(*natom)+iat]=-grd[2+3*iat]*FAC;
      }

   }

   *eclas /= AUTOKCAL;

//   return 0;

}

// externC
}

////////////////////////////////////////////////////////////////////////////////