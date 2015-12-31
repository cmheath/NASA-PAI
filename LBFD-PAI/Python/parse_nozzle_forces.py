import numpy as np
import matplotlib
matplotlib.use('TkAgg')
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D

xmach = 1.6
gamma = 1.4
tzm   = 216.65
reyno = 5740509.51138
R = 287.058

area  = 1.0
symmetry  = 1.0
convert_area  = 1.0

aviscr = 1.716E-5
tref_visc = 273.15

avisc = aviscr*((tref_visc + 110.33)/(tzm + 110.33))*((tzm/tref_visc)**1.50)   # [kg/m-sec]

azm   = np.sqrt(gamma*R*tzm)            # speed of sound [m/s]
uzm   = xmach * azm                     # freestream velocity [m/s]
rhozm = reyno * avisc  / uzm            # freestream density [kg/m^3]
pzm   = rhozm * R * tzm                 # freestream pressure [Pa]

mach_factor   = 0.5 * xmach**2
area          = symmetry * convert_area
convert_flux  = area * rhozm * azm**2
convert_pres  = area * pzm * gamma

print mach_factor * convert_pres
print mach_factor * convert_flux

fig = plt.figure()

for surf in ['Plug', 'InnerCowl']:

    cxv = []
    cxp = []
    cxt = []
    iteration = []
    
    for i in range(11):
        fn = ('noz01.forces.%d' %(i+1))

        with open(fn) as f:

            line = f.readline()

            while surf not in line:
                line = f.readline()
            print line[0:-1]

            while "Cx  = " not in line:
                line = f.readline()
            bcforce_cxp = float(line.split()[2])
            #print bcforce_cxp
            line = f.readline()

            while "Cx  = " not in line:
                line = f.readline()
            bcforce_cxv = float(line.split()[2])
            #print bcforce_cxv

            cxp.append(mach_factor * convert_pres * bcforce_cxp)
            cxv.append(mach_factor * convert_flux * bcforce_cxv)
            cxt.append((cxv[-1]+cxp[-1]))

            iteration.append(i)

    plabel = ('%s-Pressure' %surf)
    vlabel = ('%s-Viscous' %surf)
    tlabel = ('%s-Total' %surf)

    #plt.plot(iteration, cxv, linewidth=2.75, label=vlabel)
    plt.plot(iteration, cxp, linewidth=2.75, label=plabel)
    plt.plot(iteration, cxt, linewidth=2.75, label=tlabel)

plt.xlabel('Iteration #')
plt.ylabel('Drag Force (N)')
plt.title('Pressure and Viscous Drag Forces on Individual Nozzle Surfaces')
plt.grid()
plt.legend()
plt.show()

#Put figure window on top of all other windows
fig.canvas.manager.window.attributes('-topmost', 1)

#After placing figure window on top, allow other windows to be on top of it later
fig.canvas.manager.window.attributes('-topmost', 0)
