import numpy as np

xmach = 1.6
gamma = 1.4
tzm   = 216.65
reyno = 5740509.51138
R = 286.7 

area  = 1.0
symmetry  = 2.0
convert_area  = 1.0

azm = np.sqrt(gamma*R*tzm)
rhozm = 0.1729                         # freestream density [kg/m^3]
pzm   = 10749.4980                     # freestream pressure [Pa]

mach_factor   = 0.5 * xmach * xmach
area          = symmetry * convert_area
convert_flux  = area * rhozm * azm * azm
convert_pres  = area * pzm * gamma


with open('LBFD.forces') as f:
    for i in range(11):
        line = f.readline()

        while "Boundary type =" not in line:
            line = f.readline()
        print line[0:-1]

        while "Cx  = " not in line:
            line = f.readline()
        bcforce_cxv = float(line.split()[2])
        #print bcforce_cxv
        line = f.readline()

        while "Cx  = " not in line:
            line = f.readline()
        bcforce_cxp = float(line.split()[2])
        #print bcforce_cxp

        cxv  = mach_factor * convert_flux * bcforce_cxv
        cxp  = mach_factor * convert_pres * bcforce_cxp

        print ("    %.2f    %.2f\n" % (cxv, cxp))
