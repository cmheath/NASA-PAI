import numpy as np
from scipy.optimize import fsolve
from StdAtm import Atmosphere

def f(M):
	return (((gamma+1)/2)**(-(gamma+1)/(2*gamma-2))*((1+(gamma-1)/2*M**2)**((gamma+1)/(2*gamma-2)))/M - a_ratio)

gamma_inf = 1.4   # Should initialize from NPSS
gamma_p = 1.289   # Should initialize from NPSS
gamma_e = 1.322   # Should initialize from NPSS

M_inf = 1.68
alpha = 0.0       # Flight AoA

Mu = np.arcsin(1/M_inf)*180/np.pi
rotate_angle = Mu - alpha + 3 # Rotation angle for Cart3D (deg)

print rotate_angle
R = 287.05         # m^2/(s^2*K)
alt = 40000        # ft
T4_0 = 1413.61667  # K
mdot = 24.0431172  # kg/s

[rho_inf, p_inf, t_inf] = Atmosphere(alt*0.0003048)

a_inf = np.sqrt(gamma_inf*R*t_inf)
print "Altitude = ", alt, "ft"

# --- Inlet Calcs
# --- Based on std. alt
print "P_inf = ", p_inf, "Pa =", p_inf*0.0208854342, "psf" 
print "T_inf = ", t_inf, "K =", t_inf*1.8, "R"
print "D_inf = ", rho_inf, "kg/m^3 =", rho_inf*0.0624279606, "lb/ft^3" 
print "a_inf =", a_inf, "m/s =", a_inf*3.28084, "ft/s"

# Station 2 is the Engine Face Output From SUPIN
pt2_ptL = 0.83867
tt2_ttL = 1.0
M2 = 0.51396

# Station L is the Cowl Lip
ptL = 12.26968       # psi
ttL = 599.7424      # degR

pt2 = (pt2_ptL*ptL)*6894.75729 # Pa
tt2 = (tt2_ttL*ttL)*0.55555555 # K

ps2 = pt2*((1+(gamma_inf-1)/2*M2**2)**(-gamma_inf/(gamma_inf-1)))
ts2 = tt2*((1+(gamma_inf-1)/2*M2**2))**-1
a2 = np.sqrt(gamma_inf*R*ts2)
v2 = a2*M2
rho2 = ps2/(R*ts2)

NonD_P2 = ps2/(gamma_inf*p_inf)
NonD_V2 = v2/a_inf
NonD_Rho2 = rho2/rho_inf

print ""
print "Inlet Calculations:"
print ("Non-D P2    = %f" % NonD_P2)
print ("Non-D V2    = %f" % NonD_V2)
print ("Non-D Rho2  = %f" % NonD_Rho2)
print ("Non-D X-vel = %f" % (NonD_V2*np.cos(rotate_angle*np.pi/180.0)))
print ("Non-D Y-vel = %f" % (NonD_V2*np.sin(rotate_angle*np.pi/180.0)))

# --- Nozzle Calcs
x = np.array([11, 12, 13.5, 15.5])                # ft
outer_cowl = np.array([3.0, 2.9, 2.8, 2.6])       # ft
thickness = np.array([0.5, 0.4, 0.3, 0.05])       # ft
plug = np.array([1, 1, 2.0, 1.2])                 # ft

inner_cowl = outer_cowl - thickness
areas = np.pi*(inner_cowl/2)**2 - np.pi*(plug/2)**2

# Areas used by M. W. in Plume-Aircraft Interaction (SciTech 2015)
#areas = np.array([4.198, 1.623, 3.917])

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
a_ratio = ap_at
gamma = gamma_p
Mp = fsolve(f, 0.5)[0]

ae_at = ae_m/at_m
a_ratio = ae_at
gamma = gamma_e
Me = fsolve(f, 2.0)[0]

print ""
print ("Ap/A* = %f " % (ap_at))
print ("Ae/A* = %f " % (ae_at))

print ("Mp = %f " % (Mp))
print ("Me = %f " % (Me))

tp = T4_0/(1+((gamma_p-1)/2)*Mp**2)
ap = np.sqrt(gamma_p*R*tp)

pe_0 = mdot*np.sqrt(T4_0)/(ae_m*np.sqrt(gamma_e/R)*Me*(1+(gamma_e-1)/2*Me**2)**(-(gamma_e+1)/(2*gamma_e-2)))
pp_0 = mdot*np.sqrt(T4_0)/(ap_m*np.sqrt(gamma_p/R)*Mp*(1+(gamma_p-1)/2*Mp**2)**(-(gamma_p+1)/(2*gamma_p-2)))

pe = pe_0*((1+(gamma_e-1)/2*Me**2)**(-gamma_e/(gamma_e-1)))
pp = pp_0*((1+(gamma_p-1)/2*Mp**2)**(-gamma_p/(gamma_p-1)))

rhop_0 = pp_0/(R*T4_0)
rhoe_0 = pe_0/(R*T4_0)
print rhop_0

# --- Static rho at plenum
rhop = rhop_0*(1+((gamma_p-1)/2)*Mp**2)**(-1/(gamma_p-1))

# --- Static pressure at plenum
pp = pe_0*((1+(gamma_p-1)/2*Mp**2)**(-gamma_p/(gamma_p-1)))

print ""
print "Static Plenum Conditions"
print ("Tp = %f K = %f R" % (tp, tp*1.8))
print ("Pp = %f Pa = %f psi" % (pp, pp*0.000145037738))
print ("Dp = %f kg/m^3 = %f lb/ft^3" % (rhop, rhop*0.0624279606))
print ("Ap = %f m/s = %f ft/s" % (ap, ap*3.28084))

NonDrho = rhop/rho_inf
NonDVel = Mp*(ap/a_inf)
NonDP = pp/(gamma_p*p_inf)

print ""
print ("Non-D rho_p = %f " % NonDrho)
print ("Non-D Velocity (magnitude) = %f " % (NonDVel))
print ("Non-D Vel_X = %f " % (NonDVel*np.cos(rotate_angle*np.pi/180)))
print ("Non-D Vel_Y = %f " % (NonDVel*np.sin(rotate_angle*np.pi/180)))
print ("Non-D P_p   = %f " % NonDP)

