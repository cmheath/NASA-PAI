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

class Cart3D(Component):
    ''' OpenMDAO component for executing Cart3D Simulations '''

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
        super(Cart3D, self).__init__()
        
        self.force_execute = True

    def execute(self):

        gamma_inf = 1.4   # Should initialize from NPSS
        gamma_p = 1.289   # Should initialize from NPSS
        gamma_e = 1.322   # Should initialize from NPSS
        gamma_t = 1.298

        Lstar_Lref = 1.0

        Mu = np.arcsin(1/self.M_inf)*180/np.pi
        rotate_angle = Mu - self.alpha + 3.0 # Rotation angle for Cart3D (deg)
        
        rotate_angle = 0    #FIXME

        a_inf = np.sqrt(gamma_inf*self.R*self.t_inf)

        # --- Inlet Calcs
        # --- Based on std. alt
        print ""        
        print "---------------------------------"
        print "------- Cart3D Parameters -------"
        print "---------------------------------"

        # Station 2 is the Engine Face Output From SUPIN
        ptL = self.p_inf/((1+(gamma_inf-1)/2*self.M_inf**2)**(-gamma_inf/(gamma_inf-1)))   # Pa
        ttL = self.t_inf/((1+(gamma_inf-1)/2*self.M_inf**2))**-1                           # K

        # --- Need to apply an adjustment to total pressure loss and M2 to account for inviscid assumption
        #dP = 0.01325
        dP = -0.009

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

        NonD_P2 = ps2/(gamma_inf*self.p_inf)
        NonD_V2 = v2/a_inf
        NonD_D2 = d2/self.d_inf


        #print ptL, ttL, pt2, tt2, self.p_inf, self.t_inf, ps2, M2

        print "Inlet Calculations:"    
        print ("Non-D Rho2  = %f" % NonD_D2)
        print ("Non-D V2    = %f" % NonD_V2)
        print ("Non-D Vel-X = %f" % (NonD_V2*np.cos(rotate_angle*np.pi/180.0)))
        print ("Non-D Vel-Y = %f" % (NonD_V2*np.sin(rotate_angle*np.pi/180.0)))
        print ("Non-D P2    = %f" % NonD_P2)
        print ("MFR         = %f kg/s" % mdot)

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

        print ""
        print "Nozzle Calculations:"
        print ("Plenum Diameter = %f m = %f ft" % (diameters[0]*0.3048, diameters[0]))
        print ("Throat Diameter = %f m = %f ft" % (np.min(diameters)*0.3048, np.min(diameters)))
        print ("Exit Diameter   = %f m = %f ft" % (diameters[-1]*0.3048, diameters[-1]))

        print ""
        print ("Plenum Area = %f m^2 = %f ft^2" % (ap_m, ap_ft))
        print ("Throat Area = %f m^2 = %f ft^2" % (at_m, at_ft))
        print ("Exit Area   = %f m^2 = %f ft^2" % (ae_m, ae_ft))

        # Calc area ratios
        ap_at = ap_m/at_m
        Mp = fsolve(f, 0.5, args=(gamma_p, ap_at))[0]

        ae_at = ae_m/at_m
        Me = fsolve(f, 2.0, args=(gamma_e, ae_at))[0]

        print ""
        print ("Ap/A* = %f " % (ap_at))
        print ("Ae/A* = %f " % (ae_at))

        print ("Mp = %f " % (Mp))
        print ("Me = %f " % (Me))

        tp = self.T4_0/(1+((gamma_p-1)/2)*Mp**2)
        ap = np.sqrt(gamma_p*self.R*tp)

        pe_0 = self.mdot*np.sqrt(self.T4_0)/(ae_m*np.sqrt(gamma_e/self.R)*Me*(1+(gamma_e-1)/2*Me**2)**(-(gamma_e+1)/(2*gamma_e-2)))
        pp_0 = self.mdot*np.sqrt(self.T4_0)/(ap_m*np.sqrt(gamma_p/self.R)*Mp*(1+(gamma_p-1)/2*Mp**2)**(-(gamma_p+1)/(2*gamma_p-2)))

        # --- Static pressure at plenum and exit
        pe = pe_0*((1+(gamma_e-1)/2*Me**2)**(-gamma_e/(gamma_e-1)))
        pp = pp_0*((1+(gamma_p-1)/2*Mp**2)**(-gamma_p/(gamma_p-1)))

        # --- Static rho at plenum and exit
        dp_0 = pp_0/(self.R*self.T4_0)
        de_0 = pe_0/(self.R*self.T4_0)

        # --- Static rho at plenum
        dp = dp_0*(1+((gamma_p-1)/2)*Mp**2)**(-1/(gamma_p-1))

        print ""
        print "Static Plenum Conditions"
        print ("Tp = %f K = %f R" % (tp, tp*1.8))
        print ("Pp = %f Pa = %f psi" % (pp, pp*0.000145037738))
        print ("Dp = %f kg/m^3 = %f lb/ft^3" % (dp, dp*0.0624279606))
        print ("Ap = %f m/s = %f ft/s" % (ap, ap*3.28084))

        NonDrho = dp/self.d_inf
        NonDVel = Mp*(ap/a_inf)
        NonDP = pp/(gamma_p*self.p_inf)

        print ""
        print ("Non-D Rho = %f " % NonDrho)
        print ("Non-D Velocity (magnitude) = %f " % (NonDVel))
        print ("Non-D Vel_X = %f " % (NonDVel*np.cos(rotate_angle*np.pi/180)))
        print ("Non-D Vel_Y = %f " % (NonDVel*np.sin(rotate_angle*np.pi/180)))
        print ("Non-D P_p   = %f " % NonDP)

        # --- Open template file
        filein = open( 'cart3d.template' )

        src = Template( filein.read() )

        d={ 'M_inf':self.M_inf, 'NonD_D2':NonD_D2, 'u2':(NonD_V2*np.cos(rotate_angle*np.pi/180.0)), 'v2':(NonD_V2*np.sin(rotate_angle*np.pi/180.0)), 'w2': 0.0, 'NonD_P2':NonD_P2, 'NonD_D3': NonDrho, 'u3':(NonDVel*np.cos(rotate_angle*np.pi/180)), 'v3':(NonDVel*np.sin(rotate_angle*np.pi/180)), 'w3': 0.0, 'NonD_P3':NonDP}

        # Perform substitutions
        result = src.substitute(d)

        # --- Write output
        fh = open('input.cntl', 'w')
        fh.write(result)
        fh.close()


if __name__ == "__main__":
    
    # -------------------------
    # --- Default Test Case ---
    # ------------------------- 
    Cart3D_Comp =Cart3D()
    Cart3D_Comp.run()
