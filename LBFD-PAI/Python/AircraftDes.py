# --- Inherent python/system level imports
import os
import sys
import logging
import numpy as np

# --- OpenMDAO main and library imports
from openmdao.main.api import Assembly

# --- OpenMDAO component imports
from Freestream import Freestream
from Cart3D import Cart3D
from Fun3D import Fun3D
from OpenCSM import OpenCSM
from Pointwise import Pointwise
from AFLR3 import AFLR3

from Helper import copy_files, remove_files

# -------------------------- #
# --- Specify Inlet Type
# -------------------------- #     
Inlet = "STEX"
#Inlet = "AxiSpike"

if Inlet == "STEX":
    from SUPIN_STEX import SUPIN
elif Inlet == "AxiSpike":
    from SUPIN_AxiSpike import SUPIN

class Analysis(Assembly):

    def configure(self):    

        # --------------------------------------------------------------------------- #
        # --- Instantiate Freestream Component
        # --------------------------------------------------------------------------- #        
        self.add('freestream', Freestream())

        # --------------------------------------------------------------------------- #
        # --- Instantiate Inlet Design Component
        # --------------------------------------------------------------------------- #
        self.add('supin', SUPIN())

        # --------------------------------------------------------------------------- #
        # --- Instantiate Geometry Component
        # --------------------------------------------------------------------------- #
        self.add('opencsm', OpenCSM())

        # --------------------------------------------------------------------------- #
        # --- Instantiate Pointwise Component
        # --------------------------------------------------------------------------- #        
        self.add('pointwise', Pointwise())

        # --------------------------------------------------------------------------- #
        # --- Instantiate Cart3D Component
        # --------------------------------------------------------------------------- #        
        self.add('cart3d',Cart3D())

        # --------------------------------------------------------------------------- #
        # --- Instantiate Cart3D Component
        # --------------------------------------------------------------------------- #        
        self.add('fun3d', Fun3D())

        # --------------------------------------------------------------------------- #
        # --- Create Main Assembly Workflow
        # --------------------------------------------------------------------------- #        
        # --- Add component instances to top-level assembly
        # self.driver.workflow.add(['freestream', 'npss', 'supin', 'opencsm', 'pointwise', 'aflr3', 'cart3d', 'fun3d'])

        self.driver.workflow.add(['freestream', 'supin', 'opencsm', 'pointwise', 'fun3d'])

        # --------------------------------------------------------------------------- #        
        # --- Create Data Connections 
        # --------------------------------------------------------------------------- #
        self.connect('freestream.alt', ['supin.Freestream.Alt', 'cart3d.alt', 'fun3d.alt'])      
        self.connect('freestream.M_inf', ['supin.Freestream.Mach', 'cart3d.M_inf', 'fun3d.M_inf'])           
        self.connect('freestream.p_inf', ['supin.Freestream.Pres', 'cart3d.p_inf', 'fun3d.p_inf'])
        self.connect('freestream.t_inf', ['supin.Freestream.Temp', 'cart3d.t_inf', 'fun3d.t_inf'])             
        self.connect('freestream.alpha', ['supin.Freestream.Alpha', 'cart3d.alpha', 'fun3d.alpha'])
        self.connect('freestream.d_inf', ['cart3d.d_inf', 'fun3d.d_inf'])          

        self.connect('supin.Outputs.pt2_ptL', ['cart3d.pt2_ptL', 'fun3d.pt2_ptL'])
        self.connect('supin.Outputs.tt2_ttL', ['cart3d.tt2_ttL', 'fun3d.tt2_ttL'])
        self.connect('supin.Outputs.M2', ['cart3d.M2', 'fun3d.M2'])
        self.connect('supin.Outputs.A2', ['cart3d.A2', 'fun3d.A2'])
        self.connect('supin.Outputs.mdot', ['cart3d.mdot', 'fun3d.mdot'])
        self.connect('supin.Outputs.yEF', ['opencsm.yEF'])
        self.connect('supin.Outputs.Rspin', ['opencsm.Rspin'])

        if Inlet == "STEX":
            self.opencsm._filein = '../ESP/LBFD-STEX.template'
            self.pointwise._filein = '../Pointwise/Load-STEX.glf'            
            copy_files('../ESP/STEX/*', '../ESP/')
        elif Inlet == "AxiSpike":
            self.opencsm._filein = '../ESP/LBFD-AxiSpike.template'
            self.pointwise._filein = '../Pointwise/Load-AxiSpike.glf'            
            copy_files('../ESP/AxiSpike/*', '../ESP/')

if __name__ == '__main__':

    OPT = Analysis()

    # --------------------------------------------------------------------------- #        
    # --- Execute OpenMDAO Analysis ---
    # --------------------------------------------------------------------------- #                      
    OPT.run()
