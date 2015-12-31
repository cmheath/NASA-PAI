import numpy as np
import matplotlib
matplotlib.use('TkAgg')
from matplotlib import pyplot as plt

class supell:

	def __init__(self, rx, rz_n, rz_s, n_n, n_s):
		self.rx = rx
		self.rz_n = rz_n
		self.rz_s = rz_s
		self.n_n = n_n
		self.n_s = n_s

		phi = np.linspace(0, np.pi, 90)
		x_n = np.abs(np.cos(phi))**(2.0/n_n)*self.rx*np.sign(np.cos(phi))
		z_n = np.abs(np.sin(phi))**(2.0/n_n)*self.rz_n*np.sign(np.sin(phi))

		phi = np.linspace(np.pi, np.pi*2, 90)
		x_s = np.abs(np.cos(phi))**(2.0/n_s)*self.rx*np.sign(np.cos(phi))
		z_s = np.abs(np.sin(phi))**(2.0/n_s)*self.rz_s*np.sign(np.sin(phi))		


		self.x = np.concatenate((x_n, x_s[1:]), axis=0) 
		self.z = np.concatenate((z_n, z_s[1:]), axis=0)

	def plot_supell(self):
		plt.plot(self.x, self.z)

		plt.show()

		#Put figure window on top of all other windows
		fig.canvas.manager.window.attributes('-topmost', 1)

		#After placing figure window on top, allow other windows to be on top of it later
		fig.canvas.manager.window.attributes('-topmost', 0)

	def write_supell(self):
  
		filename = 'xyz.txt'
		print filename

		file_handle = open(filename, 'w')
		for x,z in zip(self.x, self.z):
			file_handle.write("%f 0 %f \n" %(x,z))
		file_handle.close()

if __name__ == "__main__":
	
	f1 = supell(1, 1, 1.5, 2, 2.5)
	f1.write_supell()