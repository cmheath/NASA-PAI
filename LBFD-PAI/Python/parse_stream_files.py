import numpy as np

print ("-------------------------------")
print (" Viscous Component Forces ")
print ("-------------------------------")

for i in range(2):

    with open('LBFD_sampling_info_geom1.%s.dat' % i) as f:
        for bndry in IDs:
            line = f.readline()

            # --- Find boundary by name
            while "mass flow                 =" not in line:
                line = f.readline()
            print line
            #Cl = float(line.split()[2])

            # --- Parse for total forces
            while "Total pressure recovery" not in line:
                line = f.readline()
            print line
            #Cd = float(line.split()[5]) 

exit()
print ("-------------------------------")
print (" Total Force Summary ")
print ("-------------------------------")
print ("Net Lift (incl. thrust-induced) = %.6f lbf     Net Drag (incl. lift-induced) = %.6f lbf\n" % (L_net, D_net))
print ("Net Lift (airframe only) = %.6f lbf            Net Drag (airframe only) = %.6f lbf         L/D = %.6f\n" % (Airframe_L_net, Airframe_D_net, Airframe_L_net/Airframe_D_net))

print ("Net Thrust (In-line) = %.6f lbf\n" % (0.5*rhozm * area * (xmach*azm)**2 * Fx_net * N_to_lbf))
print ("Net Thrust (Installed) = %.6f lbf" % (0.5*rhozm * area * (xmach*azm)**2 * (Fx_net*np.cos(alpha) + Fz_net*np.sin(alpha)) * N_to_lbf))

L_net = D_net = Fx_net = Fz_net = Airframe_L_net = Airframe_D_net = 0

