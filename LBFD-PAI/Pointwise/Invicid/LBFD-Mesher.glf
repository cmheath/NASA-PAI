#
# Copyright 2015 © Pointwise, Inc.
# All rights reserved.
#
# This sample script is not supported by Pointwise, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#

#
# =====================================================================
# GENERATE AN UNSTRUCTURED VOLUME MESH FOR A LOW-BOOM AIRCRAFT GEOMETRY
# =====================================================================
# Originally written by: Zach Davis, Pointwise, Inc.
# Extensive Modification by Christopher Heath, NASA GRC
#
# This script demonstrates the viscous meshing process for a low-boom
# flight demonstrator aircraft geometry created in ESP. The resulting 
# grid is saved to the AFLR3 directory. 
#

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

# --------------------------------------------------------
# -- USER-DEFINED PARAMETERS
# --
# -- Define a set of user-controllable settings.
# --
# --------------------------------------------------------

set fileName                 "LBFD.pw";  # Aircraft geometry filename
set cLen                          32.0;  # Characteristic length (m)
set ffSize                       100.0;  # Farfield size (cLen multiplier)
set avgDs1                         0.5;  # Initial surface triangle average edge length
set avgDs2                         0.1;  # Refined surface triangle average edge length
set avgDs3                       0.075;  # Engine IML/OML surface triangle average edge length
set teDim                            5;  # Number of points across trailing edges
set tailLayers                      10;  # Htail root connector distribution layers 
set rootLayers                      20;  # Root/Tip connector distribution layers 
set tipLayers                       10;  # Root connector distribution layers
set rtGrowthRate                   1.2;  # Tip connector distribution growth rate
set rtSpacing                   0.0015;  # Root/Tip 2D TREX spacing
set noseGrowthRate                 1.2;  # Root/Tip connector distribution growth rate
set fuseGrowthRate                 1.2;  # Root/Tip connector distribution growth rate
set fuseLayers                      10;  # Layers for the fuselage symmetry connectors
set fuseTELayers                     5;  # Layers for the fuselage symmetry connectors
set inletGrowthRate                1.2;  # Root/Tip connector distribution growth rate
set nozzleGrowthRate               1.2;  # Root/Tip connector distribution growth rate
set inletSpacing                0.0002;  # Inlet 2D TREX spacing
set nozzleSpacing                0.005;  # Nozzle 2D TREX spacing
set plumeExitSpacing             0.025;  # Plume exit plane spacing
set leteLayers                      15;  # Leading/Trailing edge connector distribution layers
set leteGrowthRate                 1.2;  # Leading/Trailing edge connector distribution layers
set domLayers                       15;  # Layers for 2D T-Rex surface meshing
set domGrowthRate                  1.2;  # Growth rate for 2D T-Rex surface meshing
set aspectRatio                   15.0;  # Aspect ratio for 2D T-Rex surface meshing
set initDs                      0.0015;  # Initial wall spacing for boundary layer extrusion
set growthRate                     1.2;  # Growth rate for boundary layer extrusion
set boundaryDecay                  0.9;  # Volumetric boundary decay
set numLayers                      100;  # Max number of layers to extrude
set fullLayers                       1;  # Full layers (0 for multi-normals, 1 for single normal)
set collisionBuffer                  2;  # Collision buffer for colliding fronts
set maxAngle                     165.0;  # Max included angle for boundary elements
set centroidSkew                   1.0;  # Max centroid skew for boundary layer elements
set LESpacing               $rtSpacing;  # Spacing for chord cons to be consistent with TREX
set TESpacing                   0.0025;  # Spacing for chord cons TEs to be consistent with TREX
set fuseTESpacing                 0.01;  # Spacing for fuselage TE connectors
set EFSpacing                     0.01;  # Spacing for engine face connectors
set fairingGrowthRate              1.2;  # Leading/trailing edge fairing growth rate
set leteFairing                  0.001;  # Leading/trailing edge fairing spacing
set tePlug                       0.001;  # Trailing edge plug spacing              
# --------------------------------------------------------
# -- PROCEDURES
# --
# -- Define procedures for frequent tasks. 
# --
# --------------------------------------------------------

# Get Domains from Underlying Quilt
proc DomFromQuilt { quilt } {
    set gridsOnQuilt [$quilt getGridEntities]

    foreach grid $gridsOnQuilt {
        if { [$grid isOfType pw::DomainUnstructured] } {
            lappend doms $grid
        }
    }

    if { ![info exists doms] } {
        puts "INFO: There are no domains on [$quilt getName]"
        return
    }

    return $doms
}

# Get All Connectors in a Domain
proc ConsFromDom { dom } {
    set numEdges [$dom getEdgeCount]

    for { set i 1 } { $i <= $numEdges } { incr i } {
        set edge [$dom getEdge $i]
        set numCons [$edge getConnectorCount]

        for { set j 1 } { $j <= $numCons } {incr j} {
            lappend cons [$edge getConnector $j]
        }
    }

    return $cons
}

# Apply a Growth Distribution to Selected Connectors
proc RedistCons { rate beginlayers endlayers begin end conList } {
    set conMode [pw::Application begin Modify $conList]
        foreach con $conList {
            $con replaceDistribution 1 [pw::DistributionGrowth create]
            set dist [$con getDistribution 1]
            puts $dist
            $dist setBeginSpacing $begin
            $dist setBeginMode    LayersandRate
            $dist setBeginRate    $rate
            $dist setBeginLayers  $beginlayers

            $dist setEndSpacing $end
            $dist setEndMode    LayersandRate
            $dist setEndRate    $rate
            $dist setEndLayers  $endlayers

            $con setDimensionFromDistribution
        }
    $conMode end
    unset conMode
}

# Computes the Set Containing the Intersection of Set1 & Set2
proc intersect { set1 set2 } {
    set set3 [list]

    foreach item $set1 {
        if { [lsearch -exact $set2 $item] >= 0 } {
            lappend set3 $item
        }
    }

    return $set3
}

# Query the System Clock
proc timestamp {} {
    puts [clock format [clock seconds] -format "%a %b %d %Y %l:%M:%S%p %Z"]
}

# Query the System Clock (ISO 8601 formatting)
proc timestamp_iso {} {
    puts [clock format [clock seconds] -format "%G-%m-%dT%T%Z"]
}

# Convert Time in Seconds to h:m:s Format
proc convSeconds { time } {
    set h [expr { int(floor($time/3600)) }]
    set m [expr { int(floor($time/60)) % 60 }]
    set s [expr { int(floor($time)) % 60 }]
    return [format  "%02d Hours %02d Minutes %02d Seconds" $h $m $s]
}

# --------------------------------------------------------
# -- MAIN ROUTINE
# --
# -- Main meshing procedure:
# --   Load Pointwise File
# --   Apply User Settings
# --   Gather Analysis Model Information
# --   Mesh Surfaces
# --   Refine Wing and Tail Surface Meshes with 2D T-Rex
# --   Refine Fuselage Surface Mesh
# --   Create Farfield
# --   Create Symmetry Plane
# --   Create Farfield Block
# --   Examine Blocks
# --   CAE Setup
# --   Save the Pointwise Project
# --------------------------------------------------------


# Start Time
set tBegin [clock seconds]
timestamp

# Load Pointwise Project File Containing Prepared OpenCSM Geometry
pw::Application load [file join $scriptDir $fileName]
pw::Display update

# Apply User Settings
pw::Connector setCalculateDimensionMethod Spacing
pw::Connector setCalculateDimensionSpacing $avgDs1

pw::DomainUnstructured setDefault BoundaryDecay $boundaryDecay
pw::DomainUnstructured setDefault Algorithm AdvancingFront

pw::Display update
pw::Application setCAESolver {NASA/FUN3D} 3

# Gather Analysis Model Information
set allDbs [pw::Database getAll]
foreach db $allDbs {
    if { [$db getDescription] == "Model"} {
        set dbModel $db

        set numQuilts [$dbModel getQuiltCount]
        for { set i 1 } { $i <= $numQuilts } { incr i } {
            lappend dbQuilts [$dbModel getQuilt $i]
        }

        # Mesh Surfaces
        if { [$dbModel isBaseForDomainUnstructured] } {
            puts "Meshing [$dbModel getName] model..."
            set surfDoms [pw::DomainUnstructured createOnDatabase -joinConnectors 80 -reject unusedSurfs $dbModel]

            if { [llength $unusedSurfs] > 0 } {
                puts "Unused surfaces exist, please check geometry."
                puts $unusedSurfs
                exit -1
            }
        } else {
            puts "Unable to mesh model."
            exit -1
        }
    }
}

# Survey Surface Mesh and Isolate Domains and Connectors
foreach qlt $dbQuilts {
    set modelDoms([$qlt getName]) [DomFromQuilt $qlt]
}

set wingLowerCons [ConsFromDom $modelDoms(wing-lower)]
set wingUpperCons [ConsFromDom $modelDoms(wing-upper)]
set wingTipCons   [ConsFromDom $modelDoms(wing-tip)]
set wingLETECons  [intersect $wingLowerCons $wingUpperCons]

set horizTailLowerCons [ConsFromDom $modelDoms(htail-lower)]
set horizTailUpperCons [ConsFromDom $modelDoms(htail-upper)]
set horizTailTipCons   [ConsFromDom $modelDoms(htail-tip)]
set horizTailLETECons  [intersect $horizTailLowerCons $horizTailUpperCons]

set vertTailCons        [ConsFromDom $modelDoms(vtail)]

set upperFairingCons [ConsFromDom $modelDoms(fairing-upper)]
set lowerFairingCons [ConsFromDom $modelDoms(fairing-lower)]

set upperNoseCons [ConsFromDom $modelDoms(nose-upper)]
set lowerNoseCons [ConsFromDom $modelDoms(nose-lower)]

set fuselageCons [ConsFromDom $modelDoms(fuselage)]
set fuseUpperTECons [ConsFromDom $modelDoms(fuse-upper-trailing-edge)]
set fuseLowerTECons [ConsFromDom $modelDoms(fuse-lower-trailing-edge)]

set pylonCons   [ConsFromDom $modelDoms(pylon)]

set engineOMLCons [ConsFromDom $modelDoms(engine-OML)]
set inletIMLCons  [ConsFromDom $modelDoms(inlet-IML)]
set nozzleIMLCons [ConsFromDom $modelDoms(nozzle-IML)]

set spinnerUpperCons [ConsFromDom $modelDoms(spinner-upper)]
set spinnerLowerCons [ConsFromDom $modelDoms(spinner-lower)]

set plugUpperCons [ConsFromDom $modelDoms(plug-upper)]
set plugLowerCons [ConsFromDom $modelDoms(plug-lower)]

set aipCons [ConsFromDom $modelDoms(aip)]
set nozzleExitCons [ConsFromDom $modelDoms(nozzle-exit)]

set plumeNearfieldCons [ConsFromDom $modelDoms(plume-nearfield)]
set plumeExitCons [ConsFromDom $modelDoms(plume-exit)]
set plumeSymCons [ConsFromDom $modelDoms(plume-symmetry)]

set symCons          [ConsFromDom $modelDoms(symmetry)]
set engineOMLSymCons [intersect $engineOMLCons $symCons]
set inletIMLSymCons  [intersect $inletIMLCons $symCons]
set nozzleIMLSymCons [intersect $nozzleIMLCons $plumeSymCons]

set fuseSymCons [intersect $symCons $fuselageCons]

## Isolate Connectors for Specific Distributions

set wingLowerRootCons [intersect $wingLowerCons $fuselageCons]
set wingLowerSymCon   [intersect $wingLowerCons $symCons]
set wingUpperRootCon  [intersect $wingUpperCons $fuselageCons]
set wingLowerTipCon   [intersect $wingLowerCons $wingTipCons]
set wingUpperTipCon   [intersect $wingUpperCons $wingTipCons]

set horizTailLowerRootCon [intersect $horizTailLowerCons $vertTailCons]
set horizTailUpperRootCon [intersect $horizTailUpperCons $vertTailCons]
set horizTailLowerTipCon  [intersect $horizTailLowerCons $horizTailTipCons]
set horizTailUpperTipCon  [intersect $horizTailUpperCons $horizTailTipCons]
set horizTailUpperSymCon  [intersect $horizTailUpperCons $symCons]
set horizTailLowerSymCon  [intersect $horizTailLowerCons $symCons]

set vertTailRootCon         [intersect $vertTailCons        $engineOMLCons]
set vertTailTipCon          [intersect $vertTailCons        $lowerFairingCons]
set vertTailLETECons        [intersect $symCons             $vertTailCons]

set pylonLETECons         [intersect $pylonCons   $symCons]   
set pylonUpperCon         [intersect $pylonCons   $engineOMLCons]
set pylonLowerForwardCon  [intersect $pylonCons   $fuselageCons]
set pylonLowerAftCon      [intersect $pylonCons   $fuseUpperTECons]

set aipCon                [intersect $aipCons $inletIMLCons]
set nozzleExitCon         [intersect $nozzleExitCons $nozzleIMLCons]
set inletLECon            [intersect $engineOMLCons $inletIMLCons]
set nozzleTECon           [intersect $engineOMLCons $nozzleIMLCons]

set fuseUpperTESymCon     [intersect $fuseUpperTECons $symCons]
set fuseLowerTESymCon     [intersect $fuseLowerTECons $symCons]
set fuseUpperTECon        [intersect $fuseUpperTECons $fuselageCons]
set fuseLowerTECon        [intersect $fuseLowerTECons $fuselageCons]
set fuseCenterTECon       [intersect $fuseLowerTECons $fuseUpperTECons]
set noseUpperCon          [intersect $symCons $upperNoseCons]
set noseLowerCon          [intersect $symCons $lowerNoseCons]
set noseCenterCon         [intersect $upperNoseCons $lowerNoseCons] 

set upperFairingSymCon    [intersect $upperFairingCons $symCons]
set centerFairingCon      [intersect $upperFairingCons $lowerFairingCons]
set lowerFairingSymCons   [intersect $lowerFairingCons $symCons]

set spinnerUpperCon       [intersect $spinnerUpperCons $symCons]
set spinnerLowerCon       [intersect $spinnerLowerCons $symCons]
set spinnerSymCon         [intersect $spinnerUpperCons $spinnerLowerCons]

set plumeShearSymCons     [intersect $plumeNearfieldCons $symCons]

set plugUpperCon          [intersect $plugUpperCons $plumeSymCons]
set plugLowerCon          [intersect $plugLowerCons $plumeSymCons]
set plugSymCon            [intersect $plugUpperCons $plugLowerCons]

set aipNode0              [$aipCon getXYZ -parameter 0.0]
set aipNode1              [$aipCon getXYZ -parameter 1.0]

set nozzleNode0           [$nozzleExitCon getXYZ -parameter 0.0]
set nozzleNode1           [$nozzleExitCon getXYZ -parameter 1.0]

set noseCenterNode0       [$noseCenterCon getXYZ -parameter 0.0]
set noseCenterNode1       [$noseCenterCon getXYZ -parameter 1.0]

set fairingCenterNode0    [$centerFairingCon getXYZ -parameter 0.0]
set fairingCenterNode1    [$centerFairingCon getXYZ -parameter 1.0]

set wingLowerSymNode0     [$wingLowerSymCon getXYZ -parameter 0.0]
set wingLowerSymNode1     [$wingLowerSymCon getXYZ -parameter 1.0]

## Find AIP and Nozzle Exit Plane Locations
if { [lindex $aipNode0 0] > [lindex $aipNode1 0] } {
    set aipMax $aipNode0
} else {
    set aipMax $aipNode1
}

if { [lindex $nozzleNode0 0] < [lindex $nozzleNode1 0] } {
    set nozzleMin $nozzleNode0
} else {
    set nozzleMin $nozzleNode1
}

## Find Aft Node of Nose Centerline Connector
if { [lindex $noseCenterNode0 0] > [lindex $noseCenterNode1 0] } {
    set noseCenterMax $noseCenterNode0
} else {
    set noseCenterMax $noseCenterNode1
}

## Find Forward Node on Fairing
if { [lindex $fairingCenterNode0 0] < [lindex $fairingCenterNode1 0] } {
    set fairingCenterMin $fairingCenterNode0
} else {
    set fairingCenterMin $fairingCenterNode1
}

## Find Forward Node on Fuselage Lower Symmetry Connector
foreach con $fuseSymCons {
    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] < [lindex $Node1 0] } {  
        if { [lindex $Node0 2] < [lindex $noseCenterMax 2] } {           ## Lower Fuselage Connector
            lappend fuseLowerSymCons $con
        } else {                                                         ## Upper Fuselage Connector
            lappend fuseUpperSymCon $con
        }
    } else {
        if { [lindex $Node1 2] < [lindex $noseCenterMax 2] } {           ## Lower Fuselage Connector
            lappend fuseLowerSymCons $con
        } else {                                                         ## Upper Fuselage Connector
            lappend fuseUpperSymCon $con
        }
    }
}

set fairingCons [list $upperFairingSymCon    \
                      $centerFairingCon]

set spinnerCons [list $spinnerUpperCon       \
                   $spinnerLowerCon          \
                   $spinnerSymCon]

set plugCons [list $plugUpperCon        \
                   $plugLowerCon        \
                   $plugSymCon]

## Find Forward Node of Wing Root Symmetry Connector
if { [lindex $wingLowerSymNode0 0] < [lindex $wingLowerSymNode1 0] } {
    set wingRootSymMin $wingLowerSymNode0
} else {
    set wingRootSymMin $wingLowerSymNode1
}

## Separate Horizontal Tail Leading and Trailing Edge Connectors
set Node0 [[lindex $horizTailLETECons 0] getXYZ -parameter 0.0]
set Node1 [[lindex $horizTailLETECons 0] getXYZ -parameter 1.0]

if { [lindex $Node0 0] < [lindex $Node1 0] } {
    set Min1 $Node0
} else {
    set Min1 $Node1
}

set Node0 [[lindex $horizTailLETECons 1] getXYZ -parameter 0.0]
set Node1 [[lindex $horizTailLETECons 1] getXYZ -parameter 1.0]

if { [lindex $Node0 0] < [lindex $Node1 0] } {
    set Min2 $Node0
} else {
    set Min2 $Node1
}

if { [lindex $Min1 0] < [lindex $Min2 0] } {
    set horizTailLECon [lindex $horizTailLETECons 0]
    set horizTailTECon [lindex $horizTailLETECons 1]
} else {
    set horizTailLECon [lindex $horizTailLETECons 1]
    set horizTailTECon [lindex $horizTailLETECons 0]
}

## Separate Wing Leading and Trailing Edge Connectors
set Node0 [[lindex $wingLETECons 0] getXYZ -parameter 0.0]
set Node1 [[lindex $wingLETECons 0] getXYZ -parameter 1.0]

if { [lindex $Node0 0] < [lindex $Node1 0] } {
    set Min1 $Node0
} else {
    set Min1 $Node1
}

set Node0 [[lindex $wingLETECons 1] getXYZ -parameter 0.0]
set Node1 [[lindex $wingLETECons 1] getXYZ -parameter 1.0]

if { [lindex $Node0 0] < [lindex $Node1 0] } {
    set Min2 $Node0
} else {
    set Min2 $Node1
}

if { [lindex $Min1 0] < [lindex $Min2 0] } {
    set wingLECon [lindex $wingLETECons 0]
    set wingTECon [lindex $wingLETECons 1]
} else {
    set wingLECon [lindex $wingLETECons 1]
    set wingTECon [lindex $wingLETECons 0]
}

## Separate Pylon Leading and Trailing Edge Connectors
set Node0 [[lindex $pylonLETECons 0] getXYZ -parameter 0.0]
set Node1 [[lindex $pylonLETECons 0] getXYZ -parameter 1.0]

if { [lindex $Node0 0] < [lindex $Node1 0] } {
    set Min1 $Node0
} else {
    set Min1 $Node1
}

set Node0 [[lindex $pylonLETECons 1] getXYZ -parameter 0.0]
set Node1 [[lindex $pylonLETECons 1] getXYZ -parameter 1.0]

if { [lindex $Node0 0] < [lindex $Node1 0] } {
    set Min2 $Node0
} else {
    set Min2 $Node1
}

if { [lindex $Min1 0] < [lindex $Min2 0] } {
    set pylonLECon [lindex $pylonLETECons 0]
    set pylonTECon [lindex $pylonLETECons 1]
} else {
    set pylonLECon [lindex $pylonLETECons 1]
    set pylonTECon [lindex $pylonLETECons 0]
}


foreach con $lowerFairingSymCons {
    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]
    if { [lindex $Node0 0] < [lindex $Node1 0] } {
        if { [lindex $Node0 0] == [lindex $fairingCenterMin 0] } {               ## Forward Fairing Connector
            set forwardFairingCon $con
        } else {                                                                 ## Aft Fairing Connector
            set aftFairingCon $con
        }
    } else {
        if { [lindex $Node1 0] == [lindex $fairingCenterMin 0] } {               ## Forward Fairing Connector
            set forwardFairingCon $con
        } else {                                                                 ## Aft Fairing Connector
            set aftFairingCon $con
        }
    }
}

foreach VTcon $vertTailLETECons {
    foreach con [pw::Connector getAdjacentConnectors $VTcon] {

        if { [$con getName] == [$forwardFairingCon getName] } {
            set vertTailLECon $VTcon
        }
        if { [$con getName] == [$aftFairingCon getName] } {
            set vertTailTEUpperCon $VTcon
        }   
        if { [$con getName] == [$horizTailLowerSymCon getName] } {
            set vertTailTELowerCon $VTcon
        }
    }
}

puts "Finished isolating connectors."

# Update Display Window to More Clearly Render the Surface Mesh
pw::Display setShowDatabase 0

set allDomsCollection [pw::Collection create]
    $allDomsCollection set [pw::Grid getAll -type pw::Domain]
    $allDomsCollection do setRenderAttribute FillMode HiddenLine
$allDomsCollection delete

pw::Display update

## Adjust Domain Solver Attributes/Update Edge Spacing on Wing & Tail Connectors
set wingTailDomsCollection [pw::Collection create]
    $wingTailDomsCollection set [list $modelDoms(wing-lower)  \
                                      $modelDoms(wing-upper)  \
                                      $modelDoms(htail-lower) \
                                      $modelDoms(htail-upper) \
                                      $modelDoms(vtail)       \
                                      $modelDoms(pylon)]
    $wingTailDomsCollection do setUnstructuredSolverAttribute \
        EdgeMaximumLength $avgDs2
$wingTailDomsCollection delete

set wingTailConsCollection [pw::Collection create]
    $wingTailConsCollection set [lsort -unique [join [list $wingLowerCons      \
                                                           $wingUpperCons      \
                                                           $wingTipCons        \
                                                           $horizTailLowerCons \
                                                           $horizTailUpperCons \
                                                           $horizTailTipCons   \
                                                           $vertTailCons       \
                                                           $upperFairingCons   \
                                                           $lowerFairingCons   \
                                                           $upperNoseCons      \
                                                           $lowerNoseCons      \
                                                           $fuselageCons       \
                                                           $fuseUpperTECons    \
                                                           $fuseLowerTECons    \
                                                           $pylonCons]]]

   pw::Connector setCalculateDimensionSpacing $avgDs2
   $wingTailConsCollection do calculateDimension
$wingTailConsCollection delete

set engineConsCollection [pw::Collection create]
    $engineConsCollection set [lsort -unique [join [list $engineOMLCons      \
                                                         $inletIMLCons       \
                                                         $nozzleIMLCons      \
                                                         $spinnerUpperCons   \
                                                         $spinnerLowerCons   \
                                                         $plugUpperCons      \
                                                         $plugLowerCons      \
                                                         $aipCons            \
                                                         $nozzleExitCons]]]

   pw::Connector setCalculateDimensionSpacing $avgDs3
   $engineConsCollection do calculateDimension
$engineConsCollection delete


foreach con $plumeShearSymCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] < [lindex $Node1 0] } {
        RedistCons $nozzleGrowthRate [expr {int(log(2.5)/log($nozzleGrowthRate))}] [expr {int(log(2.5)/log($nozzleGrowthRate))}] $EFSpacing $plumeExitSpacing $con
    } else {
        RedistCons $nozzleGrowthRate [expr {int(log(2.5)/log($nozzleGrowthRate))}] [expr {int(log(2.5)/log($nozzleGrowthRate))}] $plumeExitSpacing $EFSpacing $con
    }
}

pw::Entity delete [list $modelDoms(plume-exit)]

foreach con $plumeExitCons {

    RedistCons $nozzleGrowthRate [expr {int(log(2.5)/log($nozzleGrowthRate))}] [expr {int(log(2.5)/log($nozzleGrowthRate))}] $plumeExitSpacing $plumeExitSpacing $con
}
pw::Display update
puts "Redistributed plume connectors."

## Redistribute Internal Engine Connector Distributions
foreach con $aipCons {
    RedistCons $growthRate [expr {int(log(2.0)/log($growthRate))}] [expr {int(log(2.0)/log($growthRate))}] $EFSpacing $EFSpacing $con
}

foreach con $nozzleExitCons {
    RedistCons $growthRate [expr {int(log(2.0)/log($growthRate))}] [expr {int(log(2.0)/log($growthRate))}] $EFSpacing $EFSpacing $con
}

foreach con $spinnerCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] < [lindex $Node1 0] } {
        if {$fileName == "LBFD_AxiSpike.pw"} {
            RedistCons $growthRate [expr {int(log(2.5)/log($growthRate))}] [expr {int(log(2.5)/log($growthRate))}] $tePlug $EFSpacing $con
        } else {
            RedistCons $growthRate [expr {int(log(2.5)/log($growthRate))}] [expr {int(log(2.5)/log($growthRate))}] $EFSpacing $EFSpacing $con
        }
    } else {
        if {$fileName == "LBFD_AxiSpike.pw"} {
            RedistCons $growthRate [expr {int(log(2.5)/log($growthRate))}] [expr {int(log(2.5)/log($growthRate))}] $EFSpacing $tePlug $con
        } else {
            RedistCons $growthRate [expr {int(log(2.5)/log($growthRate))}] [expr {int(log(2.5)/log($growthRate))}] $EFSpacing $EFSpacing $con
        }
    }
}

foreach con $plugCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] < [lindex $Node1 0] } {
        RedistCons $growthRate [expr {int(log(2.5)/log($growthRate))}] [expr {int(log(2.5)/log($growthRate))}] $EFSpacing $tePlug $con
    } else {
        RedistCons $growthRate [expr {int(log(2.5)/log($growthRate))}] [expr {int(log(2.5)/log($growthRate))}] $tePlug $EFSpacing $con
    }
}
pw::Display update
puts "Redistributed internal engine connectors."

foreach con $fairingCons {
    RedistCons $fairingGrowthRate [expr {int(log(15)/log($fairingGrowthRate))}] [expr {int(log(15)/log($fairingGrowthRate))}] $leteFairing $leteFairing $con
}

RedistCons $fairingGrowthRate [expr {int(log(10)/log($fairingGrowthRate))}] [expr {int(log(10)/log($fairingGrowthRate))}] $leteFairing $rtSpacing $forwardFairingCon
RedistCons $fairingGrowthRate [expr {int(log(10)/log($fairingGrowthRate))}] [expr {int(log(10)/log($fairingGrowthRate))}] $rtSpacing $leteFairing $aftFairingCon

pw::Display update
puts "Redistributed aerodynamic tail fairing connectors."

## Set Fuselage Upper Symmetry Connector Distributions
foreach con $fuseUpperSymCon {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] < [lindex $Node1 0] } {
        RedistCons $fuseGrowthRate [expr {int(log(2.0)/log($fuseGrowthRate))}] [expr {int(log(1.0)/log($fuseGrowthRate))}] $avgDs2 $LESpacing $con   
    } else {
        RedistCons $fuseGrowthRate [expr {int(log(1.0)/log($fuseGrowthRate))}] [expr {int(log(2.0)/log($fuseGrowthRate))}] $LESpacing $avgDs2 $con
    }
}

## Set Fuselage Lower Symmetry Connector Distributions
foreach con $fuseLowerSymCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] <= [lindex $wingRootSymMin 0] } {            ## Forward Lower Fuselage Symmetry Con
        if { [lindex $Node0 0] < [lindex $Node1 0] } {
            RedistCons $fuseGrowthRate [expr {int(log(1.5)/log($fuseGrowthRate))}] $rootLayers $avgDs2 $LESpacing $con
        } else {                                                       
            RedistCons $fuseGrowthRate $rootLayers [expr {int(log(1.5)/log($fuseGrowthRate))}] $LESpacing $avgDs2 $con
        }
    } else {                                                           ## Aft Lower Fuselage Symmetry Con
        if { [lindex $Node0 0] < [lindex $Node1 0] } {
            RedistCons $fuseGrowthRate $rootLayers $fuseTELayers $LESpacing [expr {$avgDs2/$aspectRatio}] $con
        } else {                                                       
            RedistCons $fuseGrowthRate $fuseTELayers $rootLayers [expr {$avgDs2/$aspectRatio}] $LESpacing $con
        }
    }
}

pw::Display update
puts "Redistributed fuselage symmetry connectors."

## Differentiate Between Inlet/Nozzle OML Connectors
foreach con $engineOMLSymCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] <= [lindex $aipMax 0] } {            ## Inlet Cons
        if { [lindex $Node0 0] < [lindex $Node1 0] } {
            RedistCons $inletGrowthRate [expr {int(log(12.5)/log($inletGrowthRate))}] [expr {int(log(5.0)/log($inletGrowthRate))}] $inletSpacing $rtSpacing $con
        } else {
            RedistCons $inletGrowthRate [expr {int(log(5.0)/log($inletGrowthRate))}] [expr {int(log(12.5)/log($inletGrowthRate))}] $rtSpacing $inletSpacing $con
        }
    } else {                                                   ## Nozzle Cons
        if { [lindex $Node0 0] < [lindex $Node1 0] } {
            RedistCons $nozzleGrowthRate [expr {int(log(2.5)/log($nozzleGrowthRate))}] [expr {int(log(2.5)/log($nozzleGrowthRate))}] $rtSpacing $nozzleSpacing $con
        } else {
            RedistCons $nozzleGrowthRate [expr {int(log(2.5)/log($nozzleGrowthRate))}] [expr {int(log(2.5)/log($nozzleGrowthRate))}] $nozzleSpacing $rtSpacing $con
        }
    }
}

## Redistribute Inlet IML Connectors
foreach con $inletIMLSymCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] < [lindex $Node1 0] } {
        RedistCons $inletGrowthRate [expr {int(log(12.5)/log($inletGrowthRate))}] [expr {int(log(5.0)/log($inletGrowthRate))}] $inletSpacing $EFSpacing $con
    } else {
            RedistCons $inletGrowthRate [expr {int(log(5.0)/log($inletGrowthRate))}] [expr {int(log(12.5)/log($inletGrowthRate))}] $EFSpacing $inletSpacing $con
    }
} 

## Redistribute Nozzle IML Connectors
foreach con $nozzleIMLSymCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] < [lindex $Node1 0] } {
        RedistCons $nozzleGrowthRate [expr {int(log(2.5)/log($nozzleGrowthRate))}] [expr {int(log(2.5)/log($nozzleGrowthRate))}] $EFSpacing $nozzleSpacing $con
    } else {
        RedistCons $nozzleGrowthRate [expr {int(log(2.5)/log($nozzleGrowthRate))}] [expr {int(log(2.5)/log($nozzleGrowthRate))}] $nozzleSpacing $EFSpacing $con
    }
} 

pw::Display update
puts "Redistributed inlet/nozzle connectors."

## Isolate Beg/End Nodes for Fuselage Tail Section & Modify
set tailCons [list $fuseLowerTESymCon      \
                   $fuseCenterTECon]

foreach con $tailCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] < [lindex $Node1 0] } {
        RedistCons $fuseGrowthRate [expr {int(log(5)/log($fuseGrowthRate))}] [expr {int(log(5)/log($fuseGrowthRate))}] [expr {$avgDs2/$aspectRatio}] 0.001 $con
    } else {
        RedistCons $fuseGrowthRate [expr {int(log(5)/log($fuseGrowthRate))}] [expr {int(log(5)/log($fuseGrowthRate))}] 0.001 [expr {$avgDs2/$aspectRatio}] $con
    }
}

set con $fuseUpperTESymCon
set Node0 [$con getXYZ -parameter 0.0]
set Node1 [$con getXYZ -parameter 1.0]

if { [lindex $Node0 0] < [lindex $Node1 0] } {
    RedistCons $fuseGrowthRate [expr {int(log(5)/log($fuseGrowthRate))}] [expr {int(log(5)/log($fuseGrowthRate))}] $rtSpacing 0.001 $con
} else {
    RedistCons $fuseGrowthRate [expr {int(log(5)/log($fuseGrowthRate))}] [expr {int(log(5)/log($fuseGrowthRate))}] 0.001 $rtSpacing $con
}                  

pw::Display update
puts "Redistributed fuselage aft connectors."

## Isolate Fuselage Tail Section Connectors & Modify
RedistCons $fuseGrowthRate $fuseTELayers $fuseTELayers [expr {$avgDs2/$aspectRatio}] [expr {$avgDs2/$aspectRatio}] $fuseUpperTECon
RedistCons $fuseGrowthRate $fuseTELayers $fuseTELayers [expr {$avgDs2/$aspectRatio}] [expr {$avgDs2/$aspectRatio}] $fuseLowerTECon
pw::Display update

## Modify Connector Distributions at the upper Wing, VTail and pylon Upper Root
set chordCons [list $wingUpperRootCon     \
                    $vertTailRootCon      \
                    $pylonUpperCon]

foreach con $chordCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] < [lindex $Node1 0] } {
        RedistCons $rtGrowthRate $rootLayers $rootLayers $LESpacing $TESpacing $con
    } else {
        RedistCons $rtGrowthRate $rootLayers $rootLayers $TESpacing $LESpacing $con
    }
}

RedistCons $rtGrowthRate $rootLayers $rootLayers $LESpacing $LESpacing $wingLowerSymCon

## Modify Connector Distributions on Wing Lower Root
foreach con $wingLowerRootCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] <= [lindex $wingRootSymMin 0] } {            ## Forward Symmetry Con
            RedistCons $rtGrowthRate $rootLayers $rootLayers $LESpacing $LESpacing $con
    } else {                                                            ## Aft Symmetry Con
        if { [lindex $Node0 0] < [lindex $Node1 0] } {
            RedistCons $rtGrowthRate $rootLayers $rootLayers $LESpacing $TESpacing $con
        } else {
            RedistCons $rtGrowthRate $rootLayers $rootLayers $TESpacing $LESpacing $con
        }
    }
}

## Modify Connector Distributions at HTail Root
set chordCons [list $horizTailLowerRootCon \
                    $horizTailUpperRootCon \
                    $horizTailUpperSymCon  \
                    $horizTailLowerSymCon]

foreach con $chordCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] < [lindex $Node1 0] } {
        RedistCons $rtGrowthRate $tailLayers $tailLayers $LESpacing $TESpacing $con
    } else {
        RedistCons $rtGrowthRate $tailLayers $tailLayers $TESpacing $LESpacing $con
    }
}

## Modify Connector Distributions of Lower Pylon Section
set con $pylonLowerForwardCon
set Node0 [$con getXYZ -parameter 0.0]
set Node1 [$con getXYZ -parameter 1.0]

if { [lindex $Node0 0] < [lindex $Node1 0] } {
    RedistCons $fuseGrowthRate $rootLayers $fuseTELayers $LESpacing $fuseTESpacing $con
} else {
    RedistCons $fuseGrowthRate $fuseTELayers $rootLayers $fuseTESpacing $LESpacing $con
}

set con $pylonLowerAftCon
set Node0 [$con getXYZ -parameter 0.0]
set Node1 [$con getXYZ -parameter 1.0]

if { [lindex $Node0 0] < [lindex $Node1 0] } {
    RedistCons $fuseGrowthRate $fuseTELayers $tipLayers $fuseTESpacing $TESpacing $con
} else {
    RedistCons $fuseGrowthRate $tipLayers $fuseTELayers $TESpacing $fuseTESpacing $con
}

pw::Display update
puts "Redistributed wing/tail/pylon root connectors."


## Modify Connector Distributions at the Wing & Tail Tip
set chordCons [list $wingLowerTipCon       \
                    $wingUpperTipCon       \
                    $horizTailLowerTipCon  \
                    $horizTailUpperTipCon  \
                    $vertTailTipCon]

foreach con $chordCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] < [lindex $Node1 0] } {
        RedistCons $rtGrowthRate $tipLayers $tipLayers $LESpacing $TESpacing $con
    } else {
        RedistCons $rtGrowthRate $tipLayers $tipLayers $TESpacing $LESpacing $con
    }
}

pw::Display update
puts "Redistributed wing/tail/pylon tip connectors."

## Initialize Wing & Tail Tip Domains
set tipDomsCollection [pw::Collection create]
    $tipDomsCollection set [list $modelDoms(wing-tip)  \
                                 $modelDoms(htail-tip)]
    $tipDomsCollection do initialize
$tipDomsCollection delete

pw::Display update

[[$wingLECon getDistribution 1] getBeginSpacing] setValue $LESpacing
[[$wingLECon getDistribution 1] getEndSpacing] setValue $LESpacing
[[$wingTECon getDistribution 1] getBeginSpacing] setValue $TESpacing
[[$wingTECon getDistribution 1] getEndSpacing] setValue $TESpacing 


[[$horizTailLECon getDistribution 1] getBeginSpacing] setValue $LESpacing
[[$horizTailLECon getDistribution 1] getEndSpacing] setValue $LESpacing
[[$horizTailTECon getDistribution 1] getBeginSpacing] setValue $TESpacing
[[$horizTailTECon getDistribution 1] getEndSpacing] setValue $TESpacing

[[$vertTailLECon getDistribution 1] getBeginSpacing] setValue $LESpacing
[[$vertTailLECon getDistribution 1] getEndSpacing] setValue $LESpacing
[[$vertTailTELowerCon getDistribution 1] getBeginSpacing] setValue $TESpacing
[[$vertTailTELowerCon getDistribution 1] getEndSpacing] setValue $TESpacing
[[$vertTailTEUpperCon getDistribution 1] getBeginSpacing] setValue $TESpacing
[[$vertTailTEUpperCon getDistribution 1] getEndSpacing] setValue $TESpacing

[[$pylonLECon getDistribution 1] getBeginSpacing] setValue $LESpacing
[[$pylonLECon getDistribution 1] getEndSpacing] setValue $LESpacing
[[$pylonTECon getDistribution 1] getBeginSpacing] setValue $TESpacing
[[$pylonTECon getDistribution 1] getEndSpacing] setValue $TESpacing

## Modify Connector Distributions at Wing/hTail Leading & Trailing Edges
set spanCons [list $wingLECon               \
                   $wingTECon               \
                   $horizTailLECon          \
                   $horizTailTECon]

RedistCons $leteGrowthRate [expr {int(log($aspectRatio)/log($leteGrowthRate))}] [expr {int(log($aspectRatio)/log($leteGrowthRate))}] $LESpacing  $LESpacing $spanCons

## Modify Connector Distributions at vTail Leading & Trailing Edges
set vTailCons [list $vertTailLECon           \
                   $vertTailTEUpperCon   \
                   $vertTailTELowerCon]

RedistCons $leteGrowthRate $tailLayers $tailLayers $LESpacing  $LESpacing $vTailCons

## Modify Connector Distributions at Pylon Leading & Trailing Edges
set pylonCons [list $pylonLECon              \
                    $pylonTECon]

RedistCons $leteGrowthRate [expr {int(log(2.5)/log($leteGrowthRate))}] [expr {int(log(2.5)/log($leteGrowthRate))}] $LESpacing  $LESpacing $pylonCons

pw::Display update
puts "Redistributed wing/tail/pylon leading/trailing edge symmetry connectors."

## Modify Connector Distributions at Inlet/Nozzle Leading & Trailing Edges
RedistCons $leteGrowthRate [expr {int(log(1.5)/log($leteGrowthRate))}] [expr {int(log(1.5)/log($leteGrowthRate))}] $LESpacing $LESpacing [list $inletLECon]
RedistCons $leteGrowthRate [expr {int(log(2.5)/log($leteGrowthRate))}] [expr {int(log(2.5)/log($leteGrowthRate))}] $TESpacing $TESpacing [list $nozzleTECon]

## Resolve Inlet and Nozzle Leading/Trailing Edges with Anisotropic Triangles
set engineDomsCollection [pw::Collection create]
    $engineDomsCollection set [list $modelDoms(engine-OML)      \
                                    $modelDoms(inlet-IML)       \
                                    $modelDoms(nozzle-IML)      \
                                    $modelDoms(plume-nearfield)]
    $engineDomsCollection do setUnstructuredSolverAttribute \
        TRexMaximumLayers $domLayers
    $engineDomsCollection do setUnstructuredSolverAttribute \
        TRexGrowthRate $domGrowthRate

    set leBC [pw::TRexCondition create]

    $leBC setName "inlet-leading-edge"
    $leBC setType Wall
    $leBC setSpacing $inletSpacing
    $leBC apply [list \
        [list $modelDoms(engine-OML) $inletLECon] \
        [list $modelDoms(inlet-IML) $inletLECon] \
    ]

    set teBC [pw::TRexCondition create]

    $teBC setName "nozzle-trailing-edge"
    $teBC setType Wall
    $teBC setSpacing $nozzleSpacing
    $teBC apply [list \
        [list $modelDoms(nozzle-IML) $nozzleTECon] \
        [list $modelDoms(engine-OML) $nozzleTECon] \
        [list $modelDoms(plume-nearfield) $nozzleTECon]
    ]

    $engineDomsCollection do initialize
$engineDomsCollection delete
pw::Display update

## Resolve Wing/Tail Leading & Trailing Edges with Anisotropic Triangles
set wingEmpennageDomsCollection [pw::Collection create]
    $wingEmpennageDomsCollection set [list $modelDoms(wing-lower)  \
                                           $modelDoms(wing-upper)  \
                                           $modelDoms(htail-lower) \
                                           $modelDoms(htail-upper) \
                                           $modelDoms(vtail)       \
                                           $modelDoms(pylon)]
    $wingEmpennageDomsCollection do setUnstructuredSolverAttribute \
        TRexMaximumLayers $tipLayers
    $wingEmpennageDomsCollection do setUnstructuredSolverAttribute \
        TRexGrowthRate $domGrowthRate

    set leBC [pw::TRexCondition create]

    $leBC setName "wing-tail-leading-edge"
    $leBC setType Wall
    $leBC setSpacing $LESpacing
    $leBC apply [list \
        [list $modelDoms(wing-lower) $wingLECon]       \
        [list $modelDoms(wing-upper) $wingLECon]       \
        [list $modelDoms(htail-lower) $horizTailLECon] \
        [list $modelDoms(htail-upper) $horizTailLECon] \
        [list $modelDoms(vtail) $vertTailLECon]        \
        [list $modelDoms(pylon) $pylonLECon]
    ]

    set teBC [pw::TRexCondition create]

    $teBC setName "wing-tail-trailing-edge"
    $teBC setType Wall
    $teBC setSpacing $TESpacing
    $teBC apply [list \
        [list $modelDoms(wing-lower) $wingTECon]  \
        [list $modelDoms(wing-upper) $wingTECon]  \
        [list $modelDoms(htail-lower) $horizTailTECon] \
        [list $modelDoms(htail-upper) $horizTailTECon] \
        [list $modelDoms(vtail) $vertTailTEUpperCon]   \
        [list $modelDoms(vtail) $vertTailTELowerCon]   \
        [list $modelDoms(pylon) $pylonTECon]]

    $wingEmpennageDomsCollection do initialize
$wingEmpennageDomsCollection delete
pw::Display update
puts "Resolved Curvature at Wing/Empennage Leading & Trailing Edges"

## Isolate Beg/End Nodes for Nose Section & Modify
set noseCons [list $noseUpperCon      \
                   $noseLowerCon      \
                   $noseCenterCon]

foreach con $noseCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] < [lindex $Node1 0] } {
        RedistCons $noseGrowthRate [expr {int(log(1.5)/log($noseGrowthRate))}] [expr {int(log(1.5)/log($noseGrowthRate))}] 0.0005 $avgDs2 $con
    } else {
        RedistCons $noseGrowthRate [expr {int(log(1.5)/log($noseGrowthRate))}] [expr {int(log(1.5)/log($noseGrowthRate))}] $avgDs2 0.0005 $con
    }
}

pw::Display update
puts "Redistributed fuselage nose connectors."

## Re-Initialize Domains
set DomsCollection [pw::Collection create]
    $DomsCollection set [list $modelDoms(nose-upper)     \
                              $modelDoms(nose-lower)     \
                              $modelDoms(fairing-lower)  \
                              $modelDoms(fairing-upper)  \
                              $modelDoms(fuselage)       \
                              $modelDoms(symmetry)]
    $DomsCollection do initialize
$DomsCollection delete

puts "Surface Meshing Complete"

## Block Assembly

set allDoms [pw::Grid getAll -type pw::Domain]
set doms {}
foreach dom $allDoms {
    lappend doms $dom
}

# Assemble Block From All Model Domains
set blk [pw::BlockUnstructured createFromDomains $doms]

set blk_1 [pw::GridEntity getByName "blk-1"]

set isoMode [pw::Application begin Modify -notopology [list $blk_1]]
  set PW_2 [subst {$blk_1}]
  set face_1 [$PW_2 getFace 1]
  set face_2 [pw::FaceUnstructured create]
  $face_2 addDomain $modelDoms(plume-nearfield)
  $face_2 setBaffle true
  $PW_2 addFace $face_2
$isoMode end

set isoMode [pw::Application begin UnstructuredSolver [list $blk_1]]
$isoMode run Initialize
$isoMode end

set wingDoms [list $modelDoms(wing-lower)          \
                   $modelDoms(wing-upper)          \
                   $modelDoms(wing-tip)]

set htDoms [list $modelDoms(htail-lower)         \
                 $modelDoms(htail-upper)         \
                 $modelDoms(htail-tip)]
                   
set vtDoms [list $modelDoms(vtail)]

set fuseDoms [list $modelDoms(nose-upper)                \
                   $modelDoms(nose-lower)                \
                   $modelDoms(fuselage)                  \
                   $modelDoms(fuse-upper-trailing-edge)  \
                   $modelDoms(fuse-lower-trailing-edge)]

set fairDoms [list $modelDoms(fairing-upper)            \
                   $modelDoms(fairing-lower)]
                   
set pylonDoms [list $modelDoms(pylon)]   

set spinnerDoms [list $modelDoms(spinner-upper) \
                    $modelDoms(spinner-lower)]

set plugDoms [list $modelDoms(plug-upper) \
                   $modelDoms(plug-lower)]

# Define boundary conditions
set fuseBC [pw::BoundaryCondition create]
    $fuseBC setName "bc-01"
    foreach dom $fuseDoms {$fuseBC apply [list $blk_1 $dom]}

set freestreamBC [pw::BoundaryCondition create]
    $freestreamBC setName "bc-02"
    $freestreamBC apply [list $blk_1 $modelDoms(freestream)]

set nearfieldBC [pw::BoundaryCondition create]
    $nearfieldBC setName "bc-03"
    $nearfieldBC apply [list $blk_1 $modelDoms(nearfield)]

set symmetryBC [pw::BoundaryCondition create]
    $symmetryBC setName "bc-04"
    $symmetryBC apply [list $blk_1 $modelDoms(symmetry)]

set outflowBC [pw::BoundaryCondition create]
    $outflowBC setName "bc-05"
    $outflowBC apply [list $blk_1 $modelDoms(outflow)]

set aipBC [pw::BoundaryCondition create]
    $aipBC setName "bc-06"
    $aipBC apply [list $blk_1 $modelDoms(aip)]

set nozzleBC [pw::BoundaryCondition create]
    $nozzleBC setName "bc-07"
    $nozzleBC apply [list $blk_1 $modelDoms(nozzle-exit)]

set inletBC [pw::BoundaryCondition create]
    $inletBC setName "bc-08"
    $inletBC apply [list $blk_1 $modelDoms(inlet-IML)]

set nozzleBC [pw::BoundaryCondition create]
    $nozzleBC setName "bc-09"
    $nozzleBC apply [list $blk_1 $modelDoms(nozzle-IML)]

set spinnerBC [pw::BoundaryCondition create]
    $spinnerBC setName "bc-10"
    foreach dom $spinnerDoms {$spinnerBC apply [list $blk_1 $dom]}

set plugBC [pw::BoundaryCondition create]
    $plugBC setName "bc-11"
    foreach dom $plugDoms {$plugBC apply [list $blk_1 $dom]}

set wingBC [pw::BoundaryCondition create]
    $wingBC setName "bc-12"
    foreach dom $wingDoms {$wingBC apply [list $blk_1 $dom]} 
    
set htBC [pw::BoundaryCondition create]
    $htBC setName "bc-13"
    foreach dom $htDoms {$htBC apply [list $blk_1 $dom]}     

set vtBC [pw::BoundaryCondition create]
    $vtBC setName "bc-14"
    foreach dom $vtDoms {$vtBC apply [list $blk_1 $dom]} 
    
set fairBC [pw::BoundaryCondition create]
    $fairBC setName "bc-15"
    foreach dom $fairDoms {$fairBC apply [list $blk_1 $dom]} 
    
set pyBC [pw::BoundaryCondition create]
    $pyBC setName "bc-16"
    foreach dom $pylonDoms {$pyBC apply [list $blk_1 $dom]}
    
set engineBC [pw::BoundaryCondition create]
    $engineBC setName "bc-17"
    $engineBC apply [list $blk_1 $modelDoms(engine-OML)]

set symmetryBC [pw::BoundaryCondition create]
    $symmetryBC setName "bc-18"
    $symmetryBC apply [list $blk_1 $modelDoms(plume-symmetry)]

timestamp
puts "Run Time: [convSeconds [pwu::Time elapsed $tBegin]]"

# Save the Pointwise Project
set fileRoot [file rootname $fileName]
set fileExport "$fileRoot-Grid.pw"

puts ""
puts "Writing $fileExport file..."
puts ""

pw::Application save [file join $scriptDir $fileExport]

set ioMode [pw::Application begin CaeExport [pw::Entity sort [list $blk_1]]]
  $ioMode initialize -type CAE [file join $scriptDir "../../AFLR3/Inviscid/LBFD_PW"]

  if {![$ioMode verify]} {
    error "Data verification failed."
  }
  $ioMode write
$ioMode end
unset ioMode

pw::Display update
exit

#