''' OpenCSM wrapper '''

# --- Inherent python/system level imports
import os
import sys
from string import Template

# --- External python library imports (i.e. matplotlib, numpy, scipy)
import shutil

# --- OpenMDAO imports
from openmdao.main.api import FileMetadata, VariableTree
from openmdao.lib.datatypes.api import Float, Str
from openmdao.lib.components.api import ExternalCode
from openmdao.util.fileutil import find_in_path

class OpenCSM(ExternalCode):
    ''' OpenMDAO component for executing OpenCSM '''

    # -----------------------------------------
    # --- File Wrapper/Template for OpenCSM ---
    # -----------------------------------------
    yEF = Float(0.8, iotype = 'in', desc = 'Y position of the engine face', units = 'ft')
    Rspin = Float(0.33, iotype = 'in', desc = 'Spinner radius', units = 'ft')
    ocsm_exec = 'run_servecsm'
    _filein = Str('', iotype = 'in')

    def __init__(self, *args, **kwargs):
        
        # ----------------------------------------------
        # --- Constructor for the Geometry Component ---
        # ----------------------------------------------
        super(OpenCSM, self).__init__()
        
        # --------------------------------------
        # --- External Code Public Variables ---
        # --------------------------------------
        #self.stdout = "stdout.log"
        #self.stderr = "stderr.log"

        #self.external_files = [FileMetadata(path = self.stdout), FileMetadata(path = self.stderr)]      
        self.force_execute = True
    
    def execute(self):
        
        #if not os.path.isfile(self.ocsm_exec) and find_in_path(self.ocsm_exec) is None:
        #    raise RuntimeError("OpenCSM executable '%s' not found" % self.ocsm_exec)

        # --------------------------------------
        # --- Execute file-wrapped component ---
        # --------------------------------------
        self.command = ['sh', self.ocsm_exec]

    	# --- Open template file
    	filein = open(self._filein)

        #filein = open('../ESP/LBFD-STEX.template')
        #filein = open('../ESP/LBFD-AxiSpike.template')
        #filein = open('../ESP/AxiPitot.template')
        #filein = open('../ESP/AxiSpike.template')        
        #filein = open('../ESP/STEX.template')

    	src = Template(filein.read())

    	d={ 'yEF':self.yEF, 'Rspin':self.Rspin}

    	# Perform substitutions
    	result = src.substitute(d)

    	# --- Write output
    	fh = open('../ESP/LBFD.csm', 'w')
    	fh.write(result)
    	fh.close()

    	# -------------------------------
    	# --- Execute SUPIN Component ---
    	# -------------------------------
    	super(OpenCSM, self).execute()


if __name__ == "__main__":
    
    # -------------------------
    # --- Default Test Case ---
    # ------------------------- 
    OpenCSM_Comp = OpenCSM()

    OpenCSM_Comp.run()
