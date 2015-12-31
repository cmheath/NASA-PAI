''' OpenMDAO Component '''
import numpy as np
import os
import sys
from string import Template

from scipy.optimize import fsolve

from StdAtm import Atmosphere

# --- OpenMDAO imports
from openmdao.main.api import Component
from openmdao.lib.datatypes.api import Float, Int, Str
from openmdao.lib.casehandlers.api import DBCaseRecorder, case_db_to_dict

def f(M, *data):
    gamma, a_ratio = data
    return (((gamma+1)/2)**(-(gamma+1)/(2*gamma-2))*((1+(gamma-1)/2*M**2)**((gamma+1)/(2*gamma-2)))/M - a_ratio)

def g(M2, *data):

    pt2_ptL, tt2_ttL, ptL, ttL, gamma_inf, R, A2, mdot = data

    pt2 = (pt2_ptL*ptL) # Pa        
    tt2 = (tt2_ttL*ttL) # K

    ps2 = pt2*((1+(gamma_inf-1)/2*M2**2)**(-gamma_inf/(gamma_inf-1)))          # Pa
    ts2 = tt2*((1+(gamma_inf-1)/2*M2**2))**-1                                  # K

    a2 = np.sqrt(gamma_inf*R*ts2)          # m/s                               
    v2 = a2*M2                             # m/s
    d2 = ps2/(R*ts2)                       # kg/m^3

    return mdot-v2*d2*A2

class Fun3D(Component):
    ''' OpenMDAO component for executing Fun3D Simulations '''

    # -----------------------------------
    # --- Initialize Input Parameters ---
    # -----------------------------------
    d_inf = Float(1.0, iotype ='in', desc = 'freestream static density', units = 'kg/m**3')
    p_inf = Float(1.0,  iotype ='in', desc = 'freestream static pressure', units = 'Pa')
    t_inf = Float(1.0, iotype ='in', desc = 'freestream static temperature', units = 'K')

    M_inf = Float(1.0, iotype = 'in', desc = 'freestream Mach No.')
    alpha = Float(0.0,  iotype = 'in', desc = 'vehicle AoA', units = 'deg')
    R = Float(287.053, iotype = 'in', desc = 'specific gas constant', units = 'J/kg/K')      
    alt = Float(0.0, iotype = 'in', desc = 'flight altitude', units = 'ft')          

    T4_0 = Float(1413.61667, iotype = 'in', desc = 'nozzle plenum stagnation temperature', units = 'K')      
    mdot = Float(1.0, iotype = 'in', desc = 'engine mass flow rate', units = 'kg/s')
        
    pt2_ptL = Float(1.0, iotype = 'in', desc = 'total to freestream pressure ratio at engine face') 
    tt2_ttL = Float(1.0, iotype = 'in', desc = 'total to freestream temperature ratio at engine face')

    M2 = Float(0.0, iotype = 'in', desc = 'Mach No. at engine face')
    A2 = Float(0.0, iotype = 'in', desc = 'Flow through area of the engine face', units = 'm**2')

    def __init__(self):
        super(Fun3D, self).__init__()
        
        self.force_execute = True

    def execute(self):

        gamma_inf = 1.4   # Should initialize from NPSS
        gamma_p = 1.289   # Should initialize from NPSS
        gamma_e = 1.322   # Should initialize from NPSS
        gamma_t = 1.298

        Lstar_Lref = 1.0

        a_inf = np.sqrt(gamma_inf*self.R*self.t_inf)

        # --- Inlet Calcs
        # --- Based on std. alt
   
        # Station 2 is the Engine Face Output From SUPIN
        ptL = self.p_inf/((1+(gamma_inf-1)/2*self.M_inf**2)**(-gamma_inf/(gamma_inf-1)))   # Pa
        ttL = self.t_inf/((1+(gamma_inf-1)/2*self.M_inf**2))**-1                           # K

        # --- Need to apply an adjustment to total pressure loss to account for integration effects and unaccounted viscous losses
        #dP = -0.085 super-critical
        dP = -0.0525

        # Solve for adjusted engine face Mach #, pt2 and tt2
        M2 = fsolve(g, self.M2, args=(self.pt2_ptL+dP, self.tt2_ttL, ptL, ttL, gamma_inf, self.R, self.A2, self.mdot))[0]

        pt2 = ((self.pt2_ptL+dP)*ptL) # Pa        
        tt2 = (self.tt2_ttL*ttL) # K

        ps2 = pt2*((1+(gamma_inf-1)/2*M2**2)**(-gamma_inf/(gamma_inf-1)))          # Pa
        ts2 = tt2*((1+(gamma_inf-1)/2*M2**2))**-1                                  # K

        a2 = np.sqrt(gamma_inf*self.R*ts2)          # m/s                               
        v2 = a2*M2                                  # m/s
        d2 = ps2/(self.R*ts2)                       # kg/m^3
        mdot = v2*d2*self.A2                        # kg/m^3

        # --- Nozzle Calcs
        # --- Needs to get this information from the geometry
        x = np.array([11, 12, 13.5, 15.5])                # ft
        outer_cowl = np.array([2.65, 2.6, 2.45, 2.4])     # ft
        thickness = np.array([0.3, 0.33, 0.375, 0.05])    # ft
        plug = np.array([0.45, 0.45, 1.5, 0.725])         # ft

        inner_cowl = outer_cowl - thickness
        areas = np.pi*(inner_cowl/2)**2 - np.pi*(plug/2)**2

        # Areas used by M. W. in Plume-Aircraft Interaction (SciTech 2015)
        areas = np.array([4.198, 1.623, 3.917])

        diameters = 2*np.sqrt(areas/np.pi)
        ap_ft = areas[0]      # plenum area -ft^2
        at_ft = np.min(areas) # throat area -ft^2
        ae_ft = areas[-1]     # exit area -ft^2

        ap_m = ap_ft/10.7639
        at_m = at_ft/10.7639
        ae_m = ae_ft/10.7639

        # Calc area ratios
        ap_at = ap_m/at_m
        Mp = fsolve(f, 0.5, args=(gamma_p, ap_at))[0]

        ae_at = ae_m/at_m
        Me = fsolve(f, 2.0, args=(gamma_e, ae_at))[0]

        tp = self.T4_0/(1+((gamma_p-1)/2)*Mp**2)
        ap = np.sqrt(gamma_p*self.R*tp)

        # --- Stagnation pressure at plenum and exit
        pp_0 = self.mdot*np.sqrt(self.T4_0)/(ap_m*np.sqrt(gamma_p/self.R)*Mp*(1+(gamma_p-1)/2*Mp**2)**(-(gamma_p+1)/(2*gamma_p-2)))        
        pe_0 = self.mdot*np.sqrt(self.T4_0)/(ae_m*np.sqrt(gamma_e/self.R)*Me*(1+(gamma_e-1)/2*Me**2)**(-(gamma_e+1)/(2*gamma_e-2)))

        # --- Static pressure at plenum and exit
        pp = pp_0*((1+(gamma_p-1)/2*Mp**2)**(-gamma_p/(gamma_p-1)))        
        pe = pe_0*((1+(gamma_e-1)/2*Me**2)**(-gamma_e/(gamma_e-1)))

        # --- Stagnation density at plenum and exit
        dp_0 = pp_0/(self.R*self.T4_0)
        de_0 = pe_0/(self.R*self.T4_0)

        # --- Static rho at plenum
        dp = dp_0*(1+((gamma_p-1)/2)*Mp**2)**(-1/(gamma_p-1))

        Cf = np.sqrt((2*gamma_p**2/(gamma_p-1))*(2/(gamma_p+1))**((gamma_p+1)/(gamma_p-1))*(1-(pe/pp)**((gamma_p-1)/gamma_p)))+ae_at*((pe-p_inf)/pp)
        F = Cf*pp*at_m

        print "Thrust = %f" % (F)

        print ""        
        print "---------------------------------"
        print "------- FUN3D Parameters -------"
        print "---------------------------------"
        astar = np.sqrt(gamma_inf*self.R*self.t_inf)
        ustar = astar*self.M_inf
        dstar = gamma_inf*self.p_inf/astar**2
        mustar = 0.00001716*(self.t_inf/273.15)**1.5*(273.15+110.4)/(self.t_inf+110.4) # --- Sutherlands Law
        Re = dstar*ustar/mustar*Lstar_Lref
        
        print "Non-Dimensional Variables:"
        print ("SPR(1)     = %f    " % (ps2/self.p_inf))  
        print ""        
        print ("TPR(2)     = %f    " % (pp_0/ptL)) 
        print ("TTR(2)     = %f    " % (self.T4_0/ttL)) 
        print ""          
        print ("c(1)     = %f    " % (a2/astar))        
        print ("u(1)     = %f    " % (v2/ustar))
        print ("rho(1)   = %f    " % (d2/dstar))
        print ""       
        print ("c(2)     = %f    " % (ap/astar))        
        print ("u(2)     = %f    " % (Mp*ap/ustar))
        print ("rho(2)   = %f    " % (dp/dstar))
        print ""         
        print ("L*/Lref = %f " % Lstar_Lref)                
        print ("Re/grid = %f " % Re)   
        print ""             
        print "Dimensional Variables:"
        print ("a*    = %f    m/s" % astar)
        print ("u*    = %f    m/s" % ustar)
        print ("rho*  = %f    kg/m^3" % dstar)
        print ("mu*     = %f  kg/(m-s)" % mustar)        

        # --- Open template file
        filein = open( 'fun3d.template' )

        src = Template( filein.read() )

        d = { 'Re':Re, 'M_inf':self.M_inf, 'SPR':(ps2/self.p_inf), 'TPR':(pp_0/ptL), 'TTR':(self.T4_0/ttL), 'c1':(a2/astar), 'u1':(v2/ustar), 'rho1':(d2/dstar), 'c2':(ap/astar), 'u2':(Mp*ap/ustar), 'rho2':(dp/dstar)}

        # Perform substitutions
        result = src.substitute(d)

        # --- Write output
        fh = open('fun3d.nml', 'w')
        fh.write(result)
        fh.close()

if __name__ == "__main__":
    
    # -------------------------
    # --- Default Test Case ---
    # ------------------------- 
    Fun3D_Comp =Fun3D()
    Fun3D_Comp.run()

