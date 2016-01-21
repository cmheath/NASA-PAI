import numpy as np

xmach = 1.6
gamma = 1.4
tzm   = 216.65
reyno = 5740509.51138
R = 286.7 
alpha = 3.275 * np.pi/180.0

N_to_lbf = 0.224809

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

IDs = ['Fuselage', 'Wing', 'HT', 'VT', 'Fairing', 'Pylon', 'Engine', 'Inlet', 'Nozzle', 'Inlet-IML', 'Nozzle-IML', 'Spinner', 'Plug']

L_net = D_net = Fx_net = Fz_net = Airframe_L_net = Airframe_D_net = 0

print ("-------------------------------")
print (" Viscous Component Forces ")
print ("-------------------------------")

with open('LBFD.forces') as f:
    for bndry in IDs:
        line = f.readline()

        # --- Find boundary by name
        while bndry not in line:
            line = f.readline()

        # --- Parse for total forces
        while "Total forces" not in line:
            line = f.readline()

        # --- Read data line
        line = f.readline()    

        Cl = float(line.split()[2])
        Cd = float(line.split()[5])        

        L = 0.5 * rhozm * (xmach*azm)**2 * Cl * symmetry * N_to_lbf
        D = 0.5 * rhozm * (xmach*azm)**2 * Cd * symmetry * N_to_lbf

        L_net += L
        D_net += D

        line = f.readline()
        line = f.readline()

        Fx = float(line.split()[2])
        Fz = float(line.split()[8])

        Airframe_IDs = ['Fuselage', 'Wing', 'HT', 'VT', 'Fairing', 'Pylon', 'Engine']

        # --- Sum engine-only force coefficients
        if bndry not in Airframe_IDs:
            Fx_net += Fx
            Fz_net += Fz
        else:
            Airframe_L_net += L
            Airframe_D_net += D

        print ("%s  L = %s, D = %s, L/D = %s, Fx = %s, Fz = %s" % (bndry.ljust(10), str(L).ljust(10), str(D).ljust(10), str(L/D).ljust(10), str(Fx).ljust(10), str(Fz).ljust(10)))

        f.seek(0,0)
print ("-------------------------------")
print (" Total Force Summary ")
print ("-------------------------------")
print ("Net Lift (incl. thrust-induced) = %.6f lbf     Net Drag (incl. lift-induced) = %.6f lbf\n" % (L_net, D_net))
print ("Net Lift (airframe only) = %.6f lbf            Net Drag (airframe only) = %.6f lbf         L/D = %.6f\n" % (Airframe_L_net, Airframe_D_net, Airframe_L_net/Airframe_D_net))

print ("Net Thrust (In-line) = %.6f lbf\n" % (0.5*rhozm * symmetry * (xmach*azm)**2 * Fx_net * N_to_lbf))
print ("Net Thrust (Installed) = %.6f lbf" % (0.5*rhozm * symmetry * (xmach*azm)**2 * (Fx_net*np.cos(alpha) + Fz_net*np.sin(alpha)) * N_to_lbf))

L_net = D_net = Fx_net = Fz_net = Airframe_L_net = Airframe_D_net = 0

print ("-------------------------------")
print (" Inviscid Component Forces ")
print ("-------------------------------")

with open('LBFD.forces') as f:
    for bndry in IDs:
        line = f.readline()

        # --- Find boundary by name
        while bndry not in line:
            line = f.readline()

        # --- Parse for total forces
        while "Pressure forces" not in line:
            line = f.readline()

        # --- Read data line
        line = f.readline()    

        Cl = float(line.split()[2])
        Cd = float(line.split()[5])        

        L = 0.5 * rhozm * (xmach*azm)**2 * Cl * symmetry * N_to_lbf
        D = 0.5 * rhozm * (xmach*azm)**2 * Cd * symmetry * N_to_lbf

        L_net += L
        D_net += D

        line = f.readline()
        line = f.readline()

        Fx = float(line.split()[2])
        Fz = float(line.split()[8])

        Airframe_IDs = ['Fuselage', 'Wing', 'HT', 'VT', 'Fairing', 'Pylon', 'Engine']

        # --- Sum engine-only force coefficients
        if bndry not in Airframe_IDs:
            Fx_net += Fx
            Fz_net += Fz
        else:
            Airframe_L_net += L
            Airframe_D_net += D

        print ("%s  L = %s, D = %s, L/D = %s, Fx = %s, Fz = %s" % (bndry.ljust(10), str(L).ljust(10), str(D).ljust(10), str(L/D).ljust(10), str(Fx).ljust(10), str(Fz).ljust(10)))

        f.seek(0,0)
print ("-------------------------------")
print (" Total Force Summary ")
print ("-------------------------------")
print ("Net Lift (incl. thrust-induced) = %.6f lbf     Net Drag (incl. lift-induced) = %.6f lbf\n" % (L_net, D_net))
print ("Net Lift (airframe only) = %.6f lbf            Net Drag (airframe only) = %.6f lbf         L/D = %.6f\n" % (Airframe_L_net, Airframe_D_net, Airframe_L_net/Airframe_D_net))

print ("Net Thrust (In-line) = %.6f lbf\n" % (0.5*rhozm * symmetry * (xmach*azm)**2 * Fx_net * N_to_lbf))
print ("Net Thrust (Installed) = %.6f lbf" % (0.5*rhozm * symmetry * (xmach*azm)**2 * (Fx_net*np.cos(alpha) + Fz_net*np.sin(alpha)) * N_to_lbf))