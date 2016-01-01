# --------------------------------------------------------
# -- INITIALIZATION
# --
# -- Load Glyph package, initialize Pointwise, and
# -- define the working directory.
# --
# --------------------------------------------------------

# Load Glyph and Tcl Data Structure Libraries
package require PWI_Glyph

# Initialize Pointwise
pw::Application reset
pw::Application clearModified

# Define Working Directory
set scriptDir [file dirname [info script]]

package require PWI_Glyph 2.17.3

puts "Loading Database File: [file join $scriptDir "../Geometry/LBFD_STEX.step"]"

set _DB(mode_2) [pw::Application begin DatabaseImport]
  $_DB(mode_2) initialize -type Automatic [file join $scriptDir "../Geometry/LBFD_STEX.step"]
  $_DB(mode_2) setAttribute FileUnits Millimeters
  $_DB(mode_2) setAttribute ModelFromFreeSurface true
  $_DB(mode_2) setAttribute ModelAssembleTolerance 1E-3
  $_DB(mode_2) read
  $_DB(mode_2) convert
$_DB(mode_2) end
unset _DB(mode_2)

set _DB(1) [pw::DatabaseEntity getByName "curve-122"]
set _DB(2) [pw::DatabaseEntity getByName "curve-140"]
set _DB(3) [pw::DatabaseEntity getByName "curve-132"]
set _DB(4) [pw::DatabaseEntity getByName "curve-139"]
set _DB(5) [pw::DatabaseEntity getByName "curve-133"]
set _DB(6) [pw::DatabaseEntity getByName "curve-123"]
pw::Entity delete [list $_DB(1) $_DB(2) $_DB(3) $_DB(4) $_DB(5) $_DB(6)]
pw::Application markUndoLevel {Delete}

set _fuselage(1) [pw::DatabaseEntity getByName "quilt-52"]
set _fuselage(2) [pw::DatabaseEntity getByName "quilt-6"]
pw::Quilt assemble [list $_fuselage(1) $_fuselage(2)]

set _wing_upper(1) [pw::DatabaseEntity getByName "quilt-58"]
set _wing_upper(2) [pw::DatabaseEntity getByName "quilt-55"]
pw::Quilt assemble [list $_wing_upper(1) $_wing_upper(2)]

set _wing_lower(1) [pw::DatabaseEntity getByName "quilt-57"]
set _wing_lower(2) [pw::DatabaseEntity getByName "quilt-54"]
pw::Quilt assemble [list $_wing_lower(1) $_wing_lower(2)]

set _vtail(1) [pw::DatabaseEntity getByName "quilt-23"]
set _vtail(2) [pw::DatabaseEntity getByName "quilt-22"]
pw::Quilt assemble [list $_vtail(1) $_vtail(2)]

set _vtail_lower_trailing_edge(1) [pw::DatabaseEntity getByName "quilt-30"]
set _vtail_lower_trailing_edge(2) [pw::DatabaseEntity getByName "quilt-29"]
pw::Quilt assemble [list $_vtail_lower_trailing_edge(1) $_vtail_lower_trailing_edge(2)]

set _engine_OML(1) [pw::DatabaseEntity getByName "quilt-21"]
set _engine_OML(2) [pw::DatabaseEntity getByName "quilt-48"]
set _engine_OML(3) [pw::DatabaseEntity getByName "quilt-20"]
set _engine_OML(4) [pw::DatabaseEntity getByName "quilt-8"]
pw::Quilt assemble [list $_engine_OML(1) $_engine_OML(2) $_engine_OML(3) $_engine_OML(4)]

set _inlet_IML(1) [pw::DatabaseEntity getByName "quilt-10"]
set _inlet_IML(2) [pw::DatabaseEntity getByName "quilt-19"]
set _inlet_IML(3) [pw::DatabaseEntity getByName "quilt-9"]
set _inlet_IML(4) [pw::DatabaseEntity getByName "quilt-18"]
set _inlet_IML(5) [pw::DatabaseEntity getByName "quilt-12"]
set _inlet_IML(6) [pw::DatabaseEntity getByName "quilt-11"]
pw::Quilt assemble [list $_inlet_IML(1) $_inlet_IML(2) $_inlet_IML(3) $_inlet_IML(4) $_inlet_IML(5) $_inlet_IML(6)]

set _spinner_upper(1) [pw::DatabaseEntity getByName "quilt-16"]
set _spinner_upper(2) [pw::DatabaseEntity getByName "quilt-17"]
pw::Quilt assemble [list $_spinner_upper(1) $_spinner_upper(2)]

set _spinner_lower(1) [pw::DatabaseEntity getByName "quilt-15"]
set _spinner_lower(2) [pw::DatabaseEntity getByName "quilt-14"]
pw::Quilt assemble [list $_spinner_lower(1) $_spinner_lower(2)]

set _nozzle_IML(1) [pw::DatabaseEntity getByName "quilt-32"]
set _nozzle_IML(2) [pw::DatabaseEntity getByName "quilt-31"]
set _nozzle_IML(3) [pw::DatabaseEntity getByName "quilt-47"]
set _nozzle_IML(4) [pw::DatabaseEntity getByName "quilt-46"]
set _nozzle_IML(5) [pw::DatabaseEntity getByName "quilt-45"]
set _nozzle_IML(6) [pw::DatabaseEntity getByName "quilt-33"]
pw::Quilt assemble [list $_nozzle_IML(1) $_nozzle_IML(2) $_nozzle_IML(3) $_nozzle_IML(4) $_nozzle_IML(5) $_nozzle_IML(6)]

set _plug_upper(1) [pw::DatabaseEntity getByName "quilt-37"]
set _plug_upper(2) [pw::DatabaseEntity getByName "quilt-36"]
set _plug_upper(3) [pw::DatabaseEntity getByName "quilt-35"]
set _plug_upper(4) [pw::DatabaseEntity getByName "quilt-39"]
set _plug_upper(5) [pw::DatabaseEntity getByName "quilt-38"]
pw::Quilt assemble [list $_plug_upper(1) $_plug_upper(2) $_plug_upper(3) $_plug_upper(4) $_plug_upper(5)]

set _plug_lower(1) [pw::DatabaseEntity getByName "quilt-42"]
set _plug_lower(2) [pw::DatabaseEntity getByName "quilt-41"]
set _plug_lower(3) [pw::DatabaseEntity getByName "quilt-40"]
set _plug_lower(4) [pw::DatabaseEntity getByName "quilt-44"]
set _plug_lower(5) [pw::DatabaseEntity getByName "quilt-43"]
pw::Quilt assemble [list $_plug_lower(1) $_plug_lower(2) $_plug_lower(3) $_plug_lower(4) $_plug_lower(5)]

[pw::DatabaseEntity getByName "quilt-1"] setName "nearfield"
[pw::DatabaseEntity getByName "quilt-2"] setName "freestream"
[pw::DatabaseEntity getByName "quilt-3"] setName "symmetry"
[pw::DatabaseEntity getByName "quilt-4"] setName "outflow"
[pw::DatabaseEntity getByName "quilt-5"] setName "nose-upper"
[pw::DatabaseEntity getByName "quilt-7"] setName "pylon"
[pw::DatabaseEntity getByName "quilt-13"] setName "aip"
[pw::DatabaseEntity getByName "quilt-24"] setName "fairing-lower"
[pw::DatabaseEntity getByName "quilt-25"] setName "fairing-upper"
[pw::DatabaseEntity getByName "quilt-26"] setName "vtail-upper-trailing-edge"
[pw::DatabaseEntity getByName "quilt-27"] setName "htail-upper"
[pw::DatabaseEntity getByName "quilt-28"] setName "htail-lower"
[pw::DatabaseEntity getByName "quilt-34"] setName "nozzle-exit"
[pw::DatabaseEntity getByName "quilt-49"] setName "pylon-trailing-edge"
[pw::DatabaseEntity getByName "quilt-50"] setName "fuse-upper-trailing-edge"
[pw::DatabaseEntity getByName "quilt-51"] setName "fuse-lower-trailing-edge"
[pw::DatabaseEntity getByName "quilt-53"] setName "nose-lower"
[pw::DatabaseEntity getByName "quilt-56"] setName "htail-tip"
[pw::DatabaseEntity getByName "quilt-59"] setName "wing-tip"
[pw::DatabaseEntity getByName "Open CASCADE STEP translator 6.8 1"] setName "model"

$_fuselage(2) setName "fuselage"
$_wing_upper(2) setName "wing-upper"
$_wing_lower(2) setName "wing-lower"
$_vtail(2) setName "vtail"
$_vtail_lower_trailing_edge(2) setName "vtail-lower-trailing-edge"
$_engine_OML(4) setName "engine-OML"
$_inlet_IML(6) setName "inlet-IML"
$_spinner_upper(2) setName "spinner-upper"
$_spinner_lower(2) setName "spinner-lower"
$_nozzle_IML(6) setName "nozzle-IML"
$_plug_upper(5) setName "plug-upper"
$_plug_lower(5) setName "plug-lower"

# Save the Pointwise Project
set fileExport "LBFD.pw"

puts ""
puts "Writing $fileExport file..."
puts ""

pw::Application save [file join $scriptDir $fileExport]
