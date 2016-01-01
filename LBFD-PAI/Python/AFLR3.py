''' OpenCSM wrapper '''

# --- Inherent python/system level imports
import os
import sys

# --- OpenMDAO imports
from openmdao.main.api import FileMetadata
from openmdao.lib.components.api import ExternalCode
from openmdao.lib.datatypes.api import Str

class AFLR3(ExternalCode):
    ''' OpenMDAO component for executing AFLR3 '''

    aflr3_exec = Str('aflr3.script', iotype='in', desc='Requires AFLR3 executable to be in path')

    # -------------------------------------------
    # --- File Wrapper/Template for Pointwise ---
    # -------------------------------------------

    def __init__(self, *args, **kwargs):
        
        # -------------------------------------------------
        # --- Constructor for Surface Meshing Component ---
        # -------------------------------------------------
        super(AFLR3, self).__init__()
        
        # --------------------------------------
        # --- External Code Public Variables ---
        # --------------------------------------     
        self.force_execute = True

    def execute(self):

        # --------------------------------------
        # --- Execute file-wrapped component ---
        # --------------------------------------
        self.command = ['sh', self.aflr3_exec]

    	# -------------------------------
    	# --- Execute AFLR3 Component ---
    	# -------------------------------
    	super(AFLR3, self).execute()

if __name__ == "__main__":
    
    # -------------------------
    # --- Default Test Case ---
    # ------------------------- 
    AFLR3_Comp = AFLR3()
    AFLR3_Comp.run()
