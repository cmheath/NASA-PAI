import numpy as np

xmach = 1.6
gamma = 1.4
tzm   = 216.65
reyno = 5740509.51138
R = 286.7 

area  = 1.0
symmetry  = 4.0
convert_area  = 1.0

azm = np.sqrt(gamma*R*tzm)
rhozm = 0.1729                         # freestream density [kg/m^3]
pzm   = 10749.4980                     # freestream pressure [Pa]

mach_factor   = 0.5 * xmach * xmach
area          = symmetry * convert_area
convert_flux  = area * rhozm * azm * azm
convert_pres  = area * pzm * gamma

for i in range(3):
    fn = ('rubber.data.iteration.%d' %(i+1))

    with open(fn) as f:
        line = f.readline()

        while "cx =" not in line:
            line = f.readline()
        print line

        line = f.readline()
        print line

        line = f.readline()
        print line
