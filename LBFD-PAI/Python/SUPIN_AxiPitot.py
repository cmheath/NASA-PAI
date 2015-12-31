''' OpenMDAO SUPIN wrapper '''

# --- Inherent python/system level imports
import os
import sys

# --- External python library imports (i.e. matplotlib, numpy, scipy)
import shutil
from numpy import array
from numpy import float as numpy_float

# --- OpenMDAO imports
from openmdao.main.api import FileMetadata, VariableTree
from openmdao.lib.datatypes.api import Float, Int, Str, Array, VarTree
from openmdao.lib.components.api import ExternalCode
from openmdao.util.fileutil import find_in_path

def _2str(var):
    ''' Converts OpenMDAO integer variable to string '''
    if isinstance(var, float): 
        return str(round(var,5)).center(10)
    else: 
        return str(var).center(10)

class Freestream(VariableTree):
    DataID = 1

    Kfs = Int(2, desc = 'Flag to specify freestream conditions, 1=std. atm, 2=static P & T, 3=Total P & T, 4=Dynamic P & T')
    Mach = Float(1.6, iotype = 'in', desc = 'Freestream Mach number')
    Pres = Float(224.50793, iotype = 'in', desc = 'Freestream static pressure', units = 'psf')
    Temp = Float(389.97, iotype = 'in', desc = 'Freestream static temperature', units = 'degR')
    Alpha = Float(0.0, iotype = 'in', desc = 'Engine AoA', units = 'deg')
    Beta = Float(0.0, iotype = 'in', desc = 'Yaw angle')
    Alt = Float(51707.0, iotype = 'in', desc = 'Freestream Altitude', units = 'ft')

class Approach(VariableTree):
    DataID = 2

    Kapp = Int(3, desc = 'Flag for the approach flow, 1=No approach flow, 2=Flow defined by NsApp segments, 3=Specify Mach No, recovery, angles')
    Nsapp = Int(0, desc = 'Number of approach flow segments')
    IAlpha = Float(0.0, desc = 'Inlet angle of incidence relative to airframe (deg)')
    IBeta = Float(0.0, desc = 'Inlet sideangle relative to airframe symmery plane (deg)')
    ptL_pt0 = Float(1.0, desc = 'Total pressure rise of approach flow')
    LAlpha = Float(0.0, desc = 'Angle-of-incidence of the flow at station L [0 deg]')
    LBeta = Float(0.0, desc = 'Angle-of-sideslip of the flow at station L [0 deg]')

class Capture(VariableTree):
    DataID = 3

    FAcap = Float(0.0, desc = 'Input for theoretical capture area')
    Fhclip = Float(0.0, desc = 'Input for height of cowl lip')
    Fwclip = Float(1.0, desc = 'Width or circumferencial extent of capture cross section')
    Xinlet = Float(0.0, desc = 'X-coordinate for origin of inlet axis')
    Yinlet = Float(0.0, desc = 'Y-coordinate for origin of inlet axis')
    Thetinlet = Float(0.0, desc = 'Incidence angle of inlet axis, best to be 0 for now')
    ARtopcap = Float(1.0, desc = 'Aspect ratio of top semi-minor axis')
    ptopcap = Float(2.0, desc = 'Super-ellipse parameter for top section')
    ARbotcap = Float(1.0, desc = 'Aspect ratio of bottom semi-major axis')
    pbotcap = Float(2.0, desc = 'Super-ellipse section for bottom section')    

class CowlLip(VariableTree):
    DataID = 5

    Kclip = Int(1, desc = 'Flag indicating the nature of the cowl lip profile, 1=uniform profile, 2=3D cowl lip profile')
    Kclin = Int(3, desc = 'Flag for shape of the cowl lip interior, 1=sharp, 2=circular, 3=elliptical')
    Kclex = Int(3, desc = 'Flag for shape of the cowl lip exterior, 1=sharp, 2=circular, 3=elliptical')
    bclin = Float(0.002, desc = 'Radius of length of semi-minor axis for cowl lip interior', units = 'ft')
    ARclin = Float(4.0, desc = 'Aspect ratio (a/b) for the cowl lip interior (defaults to 1.0 for Kclin =2)')
    thclin = Float(0.0, desc = 'Angle of the cowl lip interior', units = 'deg')
    bclex = Float(0.002, desc = 'Radius of length of semi-minor axis for cowl lip exterior', units = 'ft')
    ARclex = Float(4.0, low = 2.0, desc = 'Aspect ratio (a/b) for the cowl lip interior (defaults to 1.0 for Kclex =2)')    
    thclex = Float(5.0, desc = 'Angle of cowl lip exterior', units = 'deg')

class CowlExt(VariableTree):
    DataID = 6

    Kcex = Int(1, desc = 'Methods for constructing the cowl exterior geometry, 0=No cowl exterior, 1=Create cowl exterior using planar curve model, 2=Create cowl exterior using horizontal line from cowl lip exterior, 3=Create cowl exterior using entities')
    Frcex = Float(1.1, desc = 'Factor for the radial placement of the cowl exterior')
    FXcext = Float(-3.0, desc = 'Factor for the axial placement of the end of the cowl exterior')
    Thswex = Float(5.0, desc = 'Angle of the sidewall chamfer', units = 'deg')

class Throat(VariableTree):
    DataID = 8

    Kthrt = Int(4, desc = 'Flag for basic shape of the throat, 1=Simple throat model, 2=Zero-length throat, 3=Straight, constant area throat, 4=Contoured cowl throat for axisymmetric pitot inlet, 5=Single-stage throat with centerbody and turning, 6=Two-stage throat with a centerbody and turning, 7=Supersonic throat for streamline-traced inlets, 8-Subsonic throat model for streamline-traced inlets')
    Kthcw = Int(1, desc = 'Flag for defining planar profile of cowl throat, 0=undefined, 1=use geometry specified by NURBS')
    dxcwTH = Float(0.75, desc = 'Axial distance from station 1 to throat', units = 'ft')   
    aTHaS1 = Float(1.01, desc = 'Ratio of area at station Throat to station A1')
    thcwTH = Float(0.0, desc = 'Slope of cowl at station throat', units = 'deg')
    machTH = Float(-0.75, desc = 'Mach number at station TH')
    dxcwSD = Float(1.5, desc = 'Axial distance from station 1 to station SD', units = 'ft')
    aSDaS1 = Float(1.1, desc = 'Ratio of cross sectional area at station SD to station 1')
    thcwSD = Float(3.0, desc = 'Slope of cowl at station SD', units = 'deg')
    machSD = Float(-0.6, desc = 'Mach number at station SD')

class SubDiff(VariableTree):
    DataID = 10

    Ksubd = Int(2, desc = 'Flag for the basic shape of the subsonic diffuser, 0=Undefined, 1=Simple subsonic diffuser model, 2=Axisymmetric cowl with no centerbody, 3=Axisymmetric cowl and centerbody, 4=Diffuser for a 2-D inlet with single duct, 5=Diffuser for a 2-D bifurcated inlet, 6=Diffuser defined by super-ellipses placed along a guiding curve, 7=Diffuser defined by curves at each circular coordinate')
    KLsubd = Int(5, desc = 'Flag indicating how the length of the subsonic diffuser is computed')
    FLsubd = Float(4.0, desc = 'Input defining length of the subsonic diffuser based on KLsubd')
    theqsd = Float(3.0, desc = 'Equivalent conical angle of the subsonic diffuser', units = 'deg')
    dptsubd = Float(-0.025, desc = 'Diffuser total pressure change, (assumption)')
    Ksdcw = Int(1, desc = 'Flag for duffuser of subsonic cowl profile, 1=geometry model based on 4-pt NURBS')
    FncwSD = Float(0.5, desc = 'Factor for NURBS interior control point at station SD')
    FncwX = Float(0.03, desc = 'Factor for NURBS interior control point at start of the straight section')
    FLcwX = Float(0.0, desc = 'Fraction of subsonic diffuser length for the straight section on the cowl')       

class EngineFace(VariableTree):
    DataID = 11

    KxEF = Int(2, desc = 'Flag for determining xEF, 1=FxEF is input through FxEF, 2=FxEF is placed at the end of the subsonic diffuser')
    FxEF = Float(0.0, desc = 'Input for the axial position of the center of the engine face', units = 'ft')
    KyEF = Int(1, desc = 'Flag for determining FyEF, 1=FyEF is specified by FyEF, 2=FyEF is the offset from ynose by the value FyEF, 3=FyEF=ynose, 4=FyEF is computed to reduce cowl drag (Ktype=2), 5=FyEF=y_staxi (Ktype=5)')
    FyEF = Float(0.0, desc = 'Input for the vertical position of the center of the engine face', units = 'ft')
    ThetEF = Float(0.0, desc = 'Angle for the engine face within the (x,y) plane about the z-axis', units = 'deg')
    Kef = Int(2, desc = 'Flag for the cross-sectional planar shape of the engine face, 0=Undefined, 1-Circular, 2=Co-annular')
    diamEF = Float(2.2284, desc = 'Flag for determining the area of the engine face, 0=Undefined, 1=FaEF is the area of the engine face, 2=Calculate A2 from Kef, HubTip and RadEF, 3=FaEF is the area ratio A2/Acap (assumes Acap is defined)')
    Hubtip = Float(0.3, desc = 'Ratio of the hub to the tip of a co-annular engine face')
    Kspin = Int(3, desc = 'Flag for the shape of the nose of an axisymmetric spinner, 0=No spinner, 1=Sharp, 2=Circular, 3=Elliptical')
    ARspin = Float(2.0, desc = 'Aspect ratio of spinnner (elliptical)')

class GridSpacing(VariableTree):

    DataID = 13

    Fgdds = Float(1.0, desc = 'Factor to scale the grid spacings')
    Rgsmax = Float(1.15, desc = 'Maximum grid spacing ratio allowed for the grid')
    Fdswall = Float(0.0005, desc = 'Grid spacing in the grid normal to an inlet surface', units = 'ft')
    Fdssym = Float(0.02, desc = 'Grid spacing in the grid normal to a symmetry boundary', units = 'ft')
    Fdscex = Float(0.1, desc = '', units = 'ft')
    Fdsthrt = Float(0.015, desc = '', units = 'ft')
    Ddinf = Float(1.0, desc = 'Horizontal distance for inflow boundaries', units = 'ft')
    Ddfar = Float(1.5, desc = 'Vertical distance to the farfield boundary at inflow boundary', units = 'ft')
    Ddnoz = Float(1.0, desc = '', units = 'ft')
    Ddclp = Float(0.05, desc = 'Distance from the cowl lip for cowl lip grid block', units = 'deg')
    thfar = Float(35.0, desc = 'Angle of farfield boundary above cowl lip', units = 'deg')
    Fgnoz = Float(0.885, desc = 'Factor of radius of the outflow throat radius')

class Outputs(VariableTree):
    
    Cd = Float(0.0, desc = 'Inlet drag coefficient')
    pt2_ptL = Float(0.8, desc = 'Engine face to freestream total pressure ratio') 
    tt2_ttL = Float(1.0, desc = 'Engine face to freestream total temperature ratio')
    M2 = Float(0.5, desc = 'Engine face Mach number')
    Rspin = Float(0.5, desc = 'Engine face Mach number')
    diamEF = Float(0.5, desc = 'Engine face diameter')
    mdot = Float(0.0, desc = 'Engine actual flow rate', units = 'lbm/s')
    A2 = Float(0.0, desc = 'Engine face area', units = 'ft**2')
    yEF = Float(0.0, iotype = 'in', desc = 'Y position of the engine face', units = 'ft')
    Rspin = Float(0.0, iotype = 'in', desc = 'Spinner radius', units = 'ft')    

class SUPIN(ExternalCode):
    ''' OpenMDAO component for executing SUPIN '''

    supin_exec = Str('supin', iotype='in', desc='Requires SUPIN executable to be in path')

    # ---------------------------------------------------------
    # --- File Wrapper for SUPIN (Streamline Traced Inlet)  ---
    # ---------------------------------------------------------
    # ---------------------
    # --- Main Control  ---
    # ---------------------   
    DataID = 0
    Kmode = Int(2, desc = 'Design and Analysis Mode')
    Ktype = Int(1, desc = 'Type of inlet geometry being designed, 1=2D Axi Pitot, 5=STEX, 6=3D Pitot')
    Kcomp = Int(1, desc = '1=External Compression, 2=Internal Compression')
    Ksurf = Int(1, desc = '0=Do not generate surface grids, 1=Calculate inlet surface grids and output in Plot3D format, 2=Calculate inlet surface grids and output in STL format, 3=Calculate inlet surface grids and output in PLot3D and STL formats')
    KgCFD = Int(0, desc = '0=Do not generate CFD grids, 1=Generate both 2-D and 3-D CFD grids, 2=Generate the 2-D grid, 3=Generate the 3D grid')

    KWinp = Int(1, desc = 'Flag indicating nature of flow rate input [0]')
    #FWinp = Float(51.199, desc = 'Input flow rate', units = 'lbm/s')
    FWinp = Float(52.735, desc = 'Input flow rate', units = 'lbm/s')
    
    if FWinp.units == 'lbm/s':
        KWunit = 2 # --- 0 = Non-dimensional, 1 = slug/s, 2 = lbm/s
    elif FWinp.units == 'slug/s':
        KWunit = 1 # --- 0 = Non-dimensional, 1 = slug/s, 2 = lbm/s
    else:
        KWunit = 0
    
    Flapeng  = Float(1.0, desc = 'Input for engine lapse rate')
    WRspill = Float(0.0, desc = 'Flow ratio for spillage')
    WRbleed = Float(0.0, desc = 'Flow ratio for bleed')
    WRbypass = Float(0.0, desc = 'Flow ratio for bypass flow')
    WRother = Float(0.0, desc = 'Flow ratio for other flows (i.e. leakage, cooling')

    Freestream = VarTree(Freestream(), iotype = 'in')
    Approach = VarTree(Approach(), iotype = 'in')
    Capture = VarTree(Capture(), iotype = 'in')
    Throat = VarTree(Throat(), iotype = 'in')
    SubDiff = VarTree(SubDiff(), iotype = 'in')
    CowlLip = VarTree(CowlLip(), iotype = 'in')
    CowlExt = VarTree(CowlExt(), iotype = 'in')
    EngineFace = VarTree(EngineFace(), iotype = 'in')
    GridSpacing = VarTree(GridSpacing(), iotype = 'in')
    Outputs = VarTree(Outputs(), iotype = 'out')
    
    def __init__(self, *args, **kwargs):
        
        # ----------------------------------------------
        # --- Constructor for the Geometry Component ---
        # ----------------------------------------------
        super(SUPIN, self).__init__()
        
        # --------------------------------------
        # --- External Code Public Variables ---
        # --------------------------------------
        self.stdout = "stdout.log"
        self.stderr = "stderr.log"

        self.external_files = [FileMetadata(path = self.stdout), FileMetadata(path = self.stderr)]      
        self.force_execute = True
    
    def execute(self):
        
        if not os.path.isfile(self.supin_exec) and find_in_path(self.supin_exec) is None:
            raise RuntimeError("SUPIN executable '%s' not found" % self.supin_exec)

        # --------------------------------------
        # --- Execute file-wrapped component --- 
        # --------------------------------------
        self.command = [self.supin_exec]

        split = '\n---------------------------------------------------------------------------\n'

        # --------------------
        # --- Header Input ---
        # --------------------       
        header_input = ['SUPIN Input File']
        header_input.append(' '.join(['2D Axisymnmetric Pitot inlet.']))
        header_input.append(' '.join(['GE F404 Conditions.']))                                                                                     
        header_input.append(split)

        # ------------------
        # --- Main Input ---
        # ------------------
        main_input = [_2str('DataID')] 
        main_input.append(' '.join([_2str(self.DataID)]))
        main_input.append(' '.join([_2str(x) for x in ['Kmode', 'Ktype', 'Kcomp', 'Ksurf', 'KgCFD']]))
        main_input.append(' '.join([_2str(x) for x in [self.Kmode, self.Ktype, self.Kcomp, self.Ksurf, self.KgCFD]]))
        main_input.append(' '.join([_2str(x) for x in ['KWinp', 'FWinp', 'KWunit', 'Flapeng']]))
        main_input.append(' '.join([_2str(x) for x in [self.KWinp, self.FWinp, self.KWunit, self.Flapeng]]))
        main_input.append(' '.join([_2str(x) for x in ['WRspill', 'WRbleed', 'WRbypass', 'WRother']]))
        main_input.append(' '.join([_2str(x) for x in [self.WRspill, self.WRbleed, self.WRbypass, self.WRother]]))
        main_input.append(split)

        # ------------------------
        # --- Freestream Input --- 
        # ------------------------   
        freestream_input = [_2str('DataID')] 
        freestream_input.append(' '.join([_2str(self.Freestream.DataID)]))
        freestream_input.append(' '.join([_2str(x) for x in ['Kfs', 'Mach', 'Pres (psf)', 'Temp (R)', 'Alpha (deg)', 'Beta (deg)', 'Alt (ft)']]))
        freestream_input.append(' '.join([_2str(x) for x in [self.Freestream.Kfs, self.Freestream.Mach, self.Freestream.Pres, self.Freestream.Temp, self.Freestream.Alpha, self.Freestream.Beta, self.Freestream.Alt]]))               
        freestream_input.append(split)    

        # ---------------------------
        # --- Approach Flow Input ---
        # ---------------------------    
        approach_input = [_2str('DataID')] 
        approach_input.append(' '.join([_2str(self.Approach.DataID)]))
        approach_input.append(' '.join([_2str(x) for x in ['Kapp', 'Nsapp', 'Alpha_Inlet (deg)', 'Beta_Inlet (deg)']]))
        approach_input.append(' '.join([_2str(x) for x in [self.Approach.Kapp, self.Approach.Nsapp, self.Approach.IAlpha, self.Approach.IBeta]]))
        approach_input.append(' '.join([_2str(x) for x in ['Mach_L', 'pt_L/pt_0', 'Alpha_L (deg)', 'Beta_L (deg)']]))
        approach_input.append(' '.join([_2str(x) for x in [self.Freestream.Mach*1.01, self.Approach.ptL_pt0, self.Approach.LAlpha, self.Approach.LBeta]]))                
        approach_input.append(split)                     

        # -------------------------------
        # --- Capture X-Section Input ---
        # ------------------------------- 
        capture_input = [_2str('DataID')] 
        capture_input.append(' '.join([_2str(self.Capture.DataID)]))
        capture_input.append(' '.join([_2str(x) for x in ['FAcap', 'Fhclip', 'Fwclip']]))
        capture_input.append(' '.join([_2str(x) for x in [self.Capture.FAcap, self.Capture.Fhclip, self.Capture.Fwclip]]))
        capture_input.append(' '.join([_2str(x) for x in ['Xinlet', 'Yinlet', 'ThetaInlet']]))
        capture_input.append(' '.join([_2str(x) for x in [self.Capture.Xinlet, self.Capture.Yinlet, self.Capture.Thetinlet]]))
        capture_input.append(' '.join([_2str(x) for x in ['ARtopcap', 'ptopcap', 'ARbotcap', 'pbotcap']]))
        capture_input.append(' '.join([_2str(x) for x in [self.Capture.ARtopcap, self.Capture.ptopcap, self.Capture.ARbotcap, self.Capture.pbotcap]]))
        capture_input.append(split)

        # ----------------------
        # --- Cowl Lip Input ---
        # ----------------------   
        cowllip_input = [_2str('DataID')] 
        cowllip_input.append(' '.join([_2str(self.CowlLip.DataID)]))
        cowllip_input.append(' '.join([_2str(x) for x in ['Kclip', 'Kclin', 'Kclex']]))
        cowllip_input.append(' '.join([_2str(x) for x in [self.CowlLip.Kclip, self.CowlLip.Kclin, self.CowlLip.Kclex]]))
        cowllip_input.append(' '.join([_2str(x) for x in ['bclin', 'ARclin', 'thclin']]))
        cowllip_input.append(' '.join([_2str(x) for x in [self.CowlLip.bclin, self.CowlLip.ARclin, self.CowlLip.thclin]]))
        cowllip_input.append(' '.join([_2str(x) for x in ['bclex', 'ARclex', 'thclex']]))
        cowllip_input.append(' '.join([_2str(x) for x in [self.CowlLip.bclex, self.CowlLip.ARclex, self.CowlLip.thclex]]))
        cowllip_input.append(split)

        # ---------------------------
        # --- Cowl Exterior Input ---
        # ---------------------------   
        cowlext_input = [_2str('DataID')] 
        cowlext_input.append(' '.join([_2str(self.CowlExt.DataID)]))
        cowlext_input.append(' '.join([_2str(x) for x in ['Kcex', 'Frcex', 'FXcext', 'Thswex']]))
        cowlext_input.append(' '.join([_2str(x) for x in [self.CowlExt.Kcex, self.CowlExt.Frcex, self.CowlExt.FXcext, self.CowlExt.Thswex]]))
        cowlext_input.append(split)

        # --------------------
        # --- Throat Input ---
        # --------------------
        throat_input = [_2str('DataID')] 
        throat_input.append(' '.join([_2str(self.Throat.DataID)]))
        throat_input.append(' '.join([_2str(x) for x in ['Kthrt']]))
        throat_input.append(' '.join([_2str(x) for x in [self.Throat.Kthrt]]))
        throat_input.append(' '.join([_2str(x) for x in ['Kthcw']]))
        throat_input.append(' '.join([_2str(x) for x in [self.Throat.Kthcw]]))
        throat_input.append(' '.join([_2str(x) for x in ['dxcwTH', 'aTHaS1', 'thcwTH', 'machTH']]))
        throat_input.append(' '.join([_2str(x) for x in [self.Throat.dxcwTH, self.Throat.aTHaS1, self.Throat.thcwTH, self.Throat.machTH]]))
        throat_input.append(' '.join([_2str(x) for x in ['dxcwSD', 'aSDaS1', 'thcwSD', 'machSD']]))
        throat_input.append(' '.join([_2str(x) for x in [self.Throat.dxcwSD, self.Throat.aSDaS1, self.Throat.thcwSD, self.Throat.machSD]]))
        throat_input.append(split)

        # -------------------------------
        # --- Subsonic Diffuser Input ---
        # -------------------------------
        subdiff_input = [_2str('DataID')] 
        subdiff_input.append(' '.join([_2str(self.SubDiff.DataID)]))
        subdiff_input.append(' '.join([_2str(x) for x in ['Ksubd', 'KLsubd', 'FLsubd', 'theqsd', 'dptsubd']]))
        subdiff_input.append(' '.join([_2str(x) for x in [self.SubDiff.Ksubd, self.SubDiff.KLsubd, self.SubDiff.FLsubd, self.SubDiff.theqsd, self.SubDiff.dptsubd]]))
        subdiff_input.append(' '.join([_2str(x) for x in ['Ksdcw']]))
        subdiff_input.append(' '.join([_2str(x) for x in [self.SubDiff.Ksdcw]]))        
        subdiff_input.append(' '.join([_2str(x) for x in ['FncwSD', 'FncwX', 'FLcwX']]))
        subdiff_input.append(' '.join([_2str(x) for x in [self.SubDiff.FncwSD, self.SubDiff.FncwX, self.SubDiff.FLcwX]]))
        subdiff_input.append(split)

        # -------------------------
        # --- Engine Face Input ---
        # -------------------------
        engineface_input = [_2str('DataID')] 
        engineface_input.append(' '.join([_2str(self.EngineFace.DataID)]))
        engineface_input.append(' '.join([_2str(x) for x in ['KxEF', 'FxEF', 'KyEF', 'FyEF', 'ThetEF']]))
        engineface_input.append(' '.join([_2str(x) for x in [self.EngineFace.KxEF, self.EngineFace.FxEF, self.EngineFace.KyEF, self.EngineFace.FyEF, self.EngineFace.ThetEF]]))
        engineface_input.append(' '.join([_2str(x) for x in ['Kef']]))        
        engineface_input.append(' '.join([_2str(x) for x in [self.EngineFace.Kef]]))        
        engineface_input.append(' '.join([_2str(x) for x in ['diamEF', 'Hubtip']]))
        engineface_input.append(' '.join([_2str(x) for x in [self.EngineFace.diamEF, self.EngineFace.Hubtip]]))
        engineface_input.append(' '.join([_2str(x) for x in ['Kspin']]))        
        engineface_input.append(' '.join([_2str(x) for x in [self.EngineFace.Kspin]]))        
        engineface_input.append(' '.join([_2str(x) for x in ['ARspin']]))        
        engineface_input.append(' '.join([_2str(x) for x in [self.EngineFace.ARspin]]))        
        engineface_input.append(split)

        # --------------------------
        # --- Grid Spacing Input ---
        # --------------------------
        gridspacing_input = [_2str('DataID')]
        gridspacing_input.append(' '.join([_2str(self.GridSpacing.DataID)]))
        gridspacing_input.append(' '.join([_2str(x) for x in ['Fgdds', 'Rgsmax', 'Fdswall', 'Fdssym', 'Fdscex', 'Fdsthrt']]))
        gridspacing_input.append(' '.join([_2str(x) for x in [self.GridSpacing.Fgdds, self.GridSpacing.Rgsmax, self.GridSpacing.Fdswall, self.GridSpacing.Fdssym, self.GridSpacing.Fdscex, self.GridSpacing.Fdsthrt]]))
        gridspacing_input.append(' '.join([_2str(x) for x in ['Ddinf', 'Ddfar', 'Ddnoz', 'Ddclp', 'thfar', 'Fgnoz']]))
        gridspacing_input.append(' '.join([_2str(x) for x in [self.GridSpacing.Ddinf, self.GridSpacing.Ddfar, self.GridSpacing.Ddnoz, self.GridSpacing.Ddclp, self.GridSpacing.thfar, self.GridSpacing.Fgnoz]]))
        gridspacing_input.append(split)

        # ---------------------------------------
        # --- Write Header Output to SUPIN.in ---
        # ---------------------------------------         
        filename = 'SUPIN.in'    
        file_handle = open(filename, 'w')
        file_handle.write("\n".join(header_input))

        # ------------------------------------
        # --- Write Input to SUPIN.in ---
        # ------------------------------------             
        file_handle.write("\n".join(main_input))           
        file_handle.write("\n".join(freestream_input))           
        file_handle.write("\n".join(approach_input))        
        file_handle.write("\n".join(capture_input))                        
        file_handle.write("\n".join(cowllip_input))           
        file_handle.write("\n".join(cowlext_input))             
        file_handle.write("\n".join(throat_input))          
        file_handle.write("\n".join(subdiff_input))            
        file_handle.write("\n".join(engineface_input))            
        file_handle.write("\n".join(gridspacing_input))
        file_handle.close()

        # -------------------------------
        # --- Execute SUPIN Component ---
        # -------------------------------
        super(SUPIN, self).execute()

        # -------------------------
        # --- Parse Output File ---
        # -------------------------       
        with open('SUPIN.out') as f:
            lines = f.readlines()
       
        for line in lines:
            if "pt_2 / pt_L    =" in line:
                self.Outputs.pt2_ptL = float(line.split("=")[-1])
            elif "Tt2 / TtL  =" in line:
                self.Outputs.tt2_ttL = float(line.split("=")[-1])                
            elif "Mach_2         =" in line:
                self.Outputs.M2 = float(line.split("=")[-1])
            elif "rhub   (ft)  =" in line:
                self.Outputs.Rspin = float(line.split("=")[-1])      
            elif "diamEF (ft)  =" in line:
                self.Outputs.diamEF = float(line.split("=")[-1])
            elif "Inlet Drag Coefficient, cdrag" in line:
                self.Outputs.Cd = float(line.split("=")[-1])   
            elif "Wa2 (actual)                       =" in line: 
                self.Outputs.mdot = float(line.split("=")[-1])  
            elif "A_2  (ft)      =" in line: 
                self.Outputs.A2 = float(line.split("=")[-1])
            elif "y_EF (ft)      =" in line: 
                self.Outputs.yEF = float(line.split("=")[-1])
            elif "rhub   (ft)  =" in line: 
                self.Outputs.Rspin = float(line.split("=")[-1])                                
            else:
                pass

        if not self.Outputs.pt2_ptL: self.Outputs.pt2_ptL = 0.8
        if not self.Outputs.Cd: self.Outputs.Cd = 1.0

        try:
            src_file = 'Solid.p3d'
            dst_folder = os.path.join(os.getcwd(), str(self.exec_count))
            shutil.copy2(src_file, dst_folder)
        except:
            pass

        print "---------------------------------"
        print "------- SUPIN Parameters --------"
        print "---------------------------------"           
        
        print '---Outputs---'
        print 'Precov: ', self.Outputs.pt2_ptL
        print 'CdWave: ', self.Outputs.Cd
        print 'Obj: ', -1.0*self.Outputs.pt2_ptL + 0.5*self.Outputs.Cd

if __name__ == "__main__":
    
    # -------------------------
    # --- Default Test Case ---
    # ------------------------- 
    Supin_Comp = SUPIN()
    Supin_Comp.run()