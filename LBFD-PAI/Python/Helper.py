import shutil
import os

from glob import iglob

def remove_files(filepath):
    for fname in iglob(filepath):
        os.remove(fname)

def copy_files(src_glob, dst_folder):
    for fname in iglob(src_glob):
    	if not os.path.isdir(fname):
        	shutil.copy2(fname, dst_folder)

def _2str(var):
    ''' Converts OpenMDAO integer variable to string '''
    if isinstance(var, float): 
        return str(round(var,5)).center(10)
    else: 
        return str(var).center(10)
