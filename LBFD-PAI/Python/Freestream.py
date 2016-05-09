''' Freestream component '''

# --- OpenMDAO imports
from openmdao.main.api import Component
from openmdao.lib.datatypes.api import Float, Int, Str
from openmdao.lib.casehandlers.api import DBCaseRecorder, case_db_to_dict

# --- Local Python imports
from StdAtm import Atmosphere

class Freestream(Component):
    ''' OpenMDAO component for calculating freestream properties '''

    # -----------------------------------
    # --- Initialize Input Parameters ---
    # -----------------------------------
    M_inf = Float(1.6, iotype = 'out', desc = 'freestream Mach No.')
    alpha = Float(3.23328690178692, iotype = 'out', desc = 'vehicle AoA', units = 'deg')
    R = Float(287.05, iotype = 'out', desc = 'specific gas constant', units = 'J/kg/K')      
    alt = Float(51707, iotype = 'out', desc = 'flight altitude', units = 'ft')

    # -----------------------------------
    # --- Initialize Output Parameters ---
    # -----------------------------------
    d_inf = Float(1.0, iotype = 'out', desc = 'freestream static density', units = 'kg/m**3')
    p_inf = Float(1.0,  iotype = 'out', desc = 'freestream static pressure', units = 'Pa')
    t_inf = Float(1.0, iotype = 'out', desc = 'freestream static temperature', units = 'K')      

    def __init__(self):
        super(Freestream, self).__init__()
        
        self.force_execute = True
    
    def execute(self):
    
        [self.d_inf, self.p_inf, self.t_inf] = Atmosphere(self.alt*0.0003048)
        print "-------------------------------------"
        print " --- Freestream Static Conditions ---"       
        print "-------------------------------------"
        print ("Altitude = %d ft" % self.alt)
        print ("P_inf = %.6f Pa = %.2f psf" % (self.p_inf, self.p_inf*0.0208854342)) 
        print ("T_inf = %.6f K = %.2f R" % (self.t_inf, self.t_inf*1.8))
        print ("D_inf = %.6f kg/m^3 = %.2f lb/ft^3" % (self.d_inf, self.d_inf*0.0624279606)) 
        print "-------------------------------------"
        print " --- Freestream Total Conditions ---"       
        print "-------------------------------------"
        print ("P_inf = %.6f Pa = %.2f psf" % (self.p_inf, self.p_inf*0.0208854342)) 
        print ("T_inf = %.6f K = %.2f R" % (self.t_inf, self.t_inf*1.8))
        print ("D_inf = %.6f kg/m^3 = %.2f lb/ft^3" % (self.d_inf, self.d_inf*0.0624279606)) 

if __name__ == "__main__":
    
    # -------------------------
    # --- Default Test Case ---
    # ------------------------- 
    Freestream_Comp = Freestream()
    Freestream_Comp.run()
