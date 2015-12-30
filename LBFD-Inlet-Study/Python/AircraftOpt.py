# --- Inherent python/system level imports
import os
import sys
import logging
import numpy as np

# --- OpenMDAO main and library imports
from openmdao.main.api import Assembly, enable_console
from openmdao.lib.drivers.api import DOEdriver, SLSQPdriver, IterateUntil
from openmdao.lib.doegenerators.api import OptLatinHypercube, Uniform
from openmdao.lib.casehandlers.api import CaseDataset, caseset_query_to_csv, JSONCaseRecorder

# --- OpenMDAO component imports
from Freestream import Freestream
from SUPIN_AxiSpike import SUPIN
#from SUPIN_STEX import SUPIN
from Cart3D import Cart3D
from Fun3D import Fun3D
from OpenCSM import OpenCSM

OPT_DB = 'OPT_Output.json'
OPT_CSV = 'OPT_Output.csv'

run_opt = False
run_doe = False

class Analysis(Assembly):

    def configure(self):

        # --------------------------------------------------------------------------- #
        # --- Create Driver Instances
        # --------------------------------------------------------------------------- #       

        if run_opt:
            self.add('inlet_opt', SLSQPdriver())
        elif run_doe:
            self.add('inlet_doe', DOEdriver())
            self.inlet_doe.DOEgenerator = Uniform(num_samples = 20)

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
        # --- Instantiate Cart3D Component
        # --------------------------------------------------------------------------- #        
        self.add('cart3d',Cart3D())

        # --------------------------------------------------------------------------- #
        # --- Instantiate Cart3D Component
        # --------------------------------------------------------------------------- #        
        self.add('fun3d',Fun3D())

        # --------------------------------------------------------------------------- #
        # --- Add Parameters to Inlet Optimization Driver 
        # --------------------------------------------------------------------------- #
        if run_opt:
            self.inlet_opt.add_parameter('supin.Throat.Fstle', low=-7.0, high=-3.0)
            self.inlet_opt.add_parameter('supin.Throat.Ffstsh', low=0.25, high=4)
            self.inlet_opt.add_parameter('supin.Throat.Fsstsh', low=0.97, high=0.99)
            self.inlet_opt.add_parameter('supin.Throat.stclth', low=5, high=15)
            self.inlet_opt.add_parameter('supin.Throat.stclb', low=0.017, high=0.07)
            self.inlet_opt.add_parameter('supin.Throat.aSDa1', low=1.01, high=1.03)
            self.inlet_opt.add_parameter('supin.Throat.ySD', low=1.1, high=1.3)        
            self.inlet_opt.add_parameter('supin.Throat.xSD', low=0.5, high=0.8)  
            self.inlet_opt.add_parameter('supin.Throat.Ftstsh', low=-10.0, high=0.0)        

            self.inlet_opt.add_objective('-supin.Outputs.Precov + supin.Outputs.Cdwave')
            self.inlet_opt.itmax = 200
            self.inlet_opt.accuracy = 1.0e-6

            self.inlet_opt.gradient_options.fd_form = 'central'
            self.inlet_opt.gradient_options.fd_step = 0.0015
            self.inlet_opt.gradient_options.fd_step_type = 'relative'
            self.inlet_opt.gradient_options.gmres_tolerance = 1.0e-9
            self.inlet_opt.gradient_options.maxiter = 20
            self.inlet_opt.gradient_options.gmres_maxiter = 200
            self.inlet_opt.gradient_options.force_fd = True

        elif run_doe:
            self.inlet_doe.add_parameter('supin.Throat.Fstle', low=-7.0, high=-3.0)
            self.inlet_doe.add_parameter('supin.Throat.Ffstsh', low=0.25, high=4)
            self.inlet_doe.add_parameter('supin.Throat.Fsstsh', low=0.97, high=0.99)
            self.inlet_doe.add_parameter('supin.Throat.stclth', low=5, high=15)
            self.inlet_doe.add_parameter('supin.Throat.stclb', low=0.017, high=0.07)
            self.inlet_doe.add_parameter('supin.Throat.aSDa1', low=1.01, high=1.03)
            self.inlet_doe.add_parameter('supin.Throat.ySD', low=1.1, high=1.3)        
            self.inlet_doe.add_parameter('supin.Throat.xSD', low=0.5, high=0.8)  
            self.inlet_doe.add_parameter('supin.Throat.Ftstsh', low=-10.0, high=0.0)

        # --------------------------------------------------------------------------- #
        # --- Create Main Assembly Workflow
        # --------------------------------------------------------------------------- #        
        # --- Add component instances to top-level assembly
        #self.driver.workflow.add(['freestream', 'npss', 'supin', 'geometry', 'cart3d'])
        
        if run_opt:
            self.inlet_opt.workflow.add(['supin'])
            self.driver.workflow.add(['freestream', 'inlet_opt', 'cart3d'])
        elif run_doe:
            self.driver.workflow.add(['freestream', 'inlet_doe', 'cart3d'])
        else:
            self.driver.workflow.add(['freestream', 'supin', 'opencsm', 'fun3d'])
            #self.driver.workflow.add(['freestream', 'supin', 'fun3d'])

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

        self.recorders = [JSONCaseRecorder(out=OPT_DB)]

if __name__ == '__main__':

    if os.path.exists(OPT_DB):
        os.remove(OPT_DB)

    if os.path.exists(OPT_CSV):
        os.remove(OPT_CSV)

    OPT = Analysis()

    # --------------------------------------------------------------------------- #        
    # --- Execute OpenMDAO Analysis ---
    # --------------------------------------------------------------------------- #                      
    OPT.run()


    #----------------------------------------------------
    # Print out history of our objective for inspection
    #----------------------------------------------------
    case_dataset = CaseDataset(OPT_DB, 'json')
    data = case_dataset.data.by_case().fetch()
    caseset_query_to_csv(data, filename='doe.csv')
