''' Pointwise wrapper '''

# --- Python/system level imports
from subprocess import call
from string import Template

# --- OpenMDAO main and library imports
from openmdao.lib.components.api import ExternalCode
from openmdao.lib.datatypes.api import Str

class Pointwise(ExternalCode):
    ''' OpenMDAO component for executing Pointwise '''

    # -------------------------------------------
    # --- File Wrapper/Template for Pointwise ---
    # -------------------------------------------
    _filein = Str('../Pointwise/Load-STEX.glf', iotype = 'in')

    def __init__(self, *args, **kwargs):
        
        # -------------------------------------------------
        # --- Constructor for Surface Meshing Component ---
        # -------------------------------------------------
        super(Pointwise, self).__init__()
        
        # --------------------------------------
        # --- External Code Public Variables ---
        # --------------------------------------     
        self.force_execute = True

    def execute(self):

        call(['/Applications/Pointwise/PointwiseV17.3R4/macosx/Pointwise.app/Contents/MacOS/tclsh8.5', self._filein])

        # --------------------------------------
        # --- Execute file-wrapped component ---
        # --------------------------------------
        self.command = ['/Applications/Pointwise/PointwiseV17.3R4/macosx/Pointwise.app/Contents/MacOS/tclsh8.5', '../Pointwise/LBFD-Mesher.glf']

    	# -----------------------------------
    	# --- Execute Pointwise Component ---
    	# -----------------------------------
    	super(Pointwise, self).execute()

if __name__ == "__main__":
    
    # -------------------------
    # --- Default Test Case ---
    # ------------------------- 
    Pointwise_Comp = Pointwise()
    Pointwise_Comp.run()
