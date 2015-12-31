import numpy as np
import matplotlib
matplotlib.use('TkAgg')
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D

cx_plenum = []
cx_plug = []
cx_cowl = []
iteration = []
for i in range(32):
    fn = ('rubber.data.iteration.%d' %(i+2))

    with open(fn) as f:
        line = f.readline()

        while " cx " not in line:
            line = f.readline()
        cx_plenum.append(float(line.split()[2]))

        line = f.readline()
        cx_cowl.append(float(line.split()[2]))

        line = f.readline()
        cx_plug.append(float(line.split()[2]))

        iteration.append(i+2)

fig = plt.figure()

#plt.plot(iteration, cx_plenum, c = 'b', linewidth = 2.75)
plt.plot(iteration, cx_cowl, c = 'r', linewidth = 2.75)
plt.plot(iteration, cx_plug, c = 'g', linewidth = 2.75)

plt.show()

#Put figure window on top of all other windows
fig.canvas.manager.window.attributes('-topmost', 1)

#After placing figure window on top, allow other windows to be on top of it later
fig.canvas.manager.window.attributes('-topmost', 0)
