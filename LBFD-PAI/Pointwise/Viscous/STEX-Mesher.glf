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

set fileName             "AxiSpike.pw";  # Aircraft geometry filename
set avgDs1                       0.125;  # Initial surface triangle average edge length
set avgDs2                        0.04;  # Refined surface triangle average edge length
set avgDs3                       0.065;  # Engine IML/OML surface triangle average edge length
set teDim                            6;  # Number of points across trailing edges
set tailLayers                      10;  # Htail root connector distribution layers 
set rootLayers                      20;  # Root/Tip connector distribution layers
set wingLayers                      15;  # Wing connector distribution layers 
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

set engineOMLCons   [ConsFromDom $modelDoms(engine-OML)]
set inletIMLCons    [ConsFromDom $modelDoms(inlet-IML)]
set inletIMLAftCons [ConsFromDom $modelDoms(inlet-IML-aft)]

set spinnerUpperCons    [ConsFromDom $modelDoms(spinner-upper)]
set spinnerLowerCons    [ConsFromDom $modelDoms(spinner-lower)]
set spinnerUpperAftCons [ConsFromDom $modelDoms(spinner-upper-aft)]
set spinnerLowerAftCons [ConsFromDom $modelDoms(spinner-lower-aft)]

set outflowCons [ConsFromDom $modelDoms(outflow)]

set aipCons        [ConsFromDom $modelDoms(aip)]

set symCons            [ConsFromDom $modelDoms(symmetry)]
set engineOMLSymCons   [intersect $engineOMLCons $symCons]
set inletIMLSymCons    [intersect $inletIMLCons $symCons]
set inletIMLAftSymCons [intersect $inletIMLAftCons $symCons]

## Isolate Connectors for Specific Distributions

set aipCon                  [intersect $aipCons $inletIMLAftCons]
set inletLECon              [intersect $engineOMLCons $inletIMLCons]
set inletIMLCon             [intersect $inletIMLAftCons $inletIMLCons]
set nozzleTECon             [intersect $engineOMLCons $outflowCons]

set spinnerUpperCon         [intersect $spinnerUpperCons $symCons]
set spinnerLowerCon         [intersect $spinnerLowerCons $symCons]
set spinnerSymCon           [intersect $spinnerUpperCons $spinnerLowerCons]

set aipNode0                [$aipCon getXYZ -parameter 0.0]
set aipNode1                [$aipCon getXYZ -parameter 1.0]


## Find AIP and Nozzle Exit Plane Locations
if { [lindex $aipNode0 0] > [lindex $aipNode1 0] } {
    set aipMax $aipNode0
} else {
    set aipMax $aipNode1
}


set spinnerCons [list $spinnerUpperCon       \
                      $spinnerLowerCon       \
                      $spinnerSymCon]

puts "Finished isolating connectors."

# Update Display Window to More Clearly Render the Surface Mesh
pw::Display setShowDatabase 0

set allDomsCollection [pw::Collection create]
    $allDomsCollection set [pw::Grid getAll -type pw::Domain]
    $allDomsCollection do setRenderAttribute FillMode HiddenLine
$allDomsCollection delete

pw::Display update

## Adjust Domain Solver Attributes/Update Edge Spacing on Wing & Tail Connectors

set engineConsCollection [pw::Collection create]
    $engineConsCollection set [lsort -unique [join [list $engineOMLCons       \
                                                         $inletIMLCons        \
                                                         $inletIMLAftCons     \
                                                         $spinnerUpperCons    \
                                                         $spinnerUpperAftCons \
                                                         $spinnerLowerCons    \
                                                         $spinnerLowerAftCons \
                                                         $aipCons]]]

   pw::Connector setCalculateDimensionSpacing $avgDs1
   $engineConsCollection do calculateDimension
$engineConsCollection delete


## Redistribute Internal Engine Connector Distributions
foreach con $aipCons {
    RedistCons $growthRate [expr {int(log(2.0)/log($growthRate))}] [expr {int(log(2.0)/log($growthRate))}] $EFSpacing $EFSpacing $con
}

RedistCons $growthRate [expr {int(log(2.0)/log($growthRate))}] [expr {int(log(2.0)/log($growthRate))}] $EFSpacing $EFSpacing $inletIMLCon

foreach con $spinnerCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] < [lindex $Node1 0] } {
        if {$fileName == "AxiSpike.pw"} {
            RedistCons $growthRate [expr {int(log(2.5)/log($growthRate))}] [expr {int(log(2.5)/log($growthRate))}] $tePlug $EFSpacing $con
        } else {
            RedistCons $growthRate 2 2 $EFSpacing $EFSpacing $con
        }
    } else {
        if {$fileName == "AxiSpike.pw"} {
            RedistCons $growthRate [expr {int(log(2.5)/log($growthRate))}] [expr {int(log(2.5)/log($growthRate))}] $EFSpacing $tePlug $con
        } else {
            RedistCons $growthRate 2 2 $EFSpacing $EFSpacing $con
        }
    }
}

RedistCons $growthRate 2 2 $EFSpacing $EFSpacing $spinnerUpperAftCons
RedistCons $growthRate 2 2 $EFSpacing $EFSpacing $spinnerLowerAftCons

puts "Redistributed internal engine connectors."

## Differentiate Between Inlet/Nozzle OML Connectors
foreach con $engineOMLSymCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] < [lindex $Node1 0] } {
        RedistCons $inletGrowthRate [expr {int(log(12.5)/log($inletGrowthRate))}] 1 $inletSpacing $avgDs1 $con
    } else {
        RedistCons $inletGrowthRate 1 [expr {int(log(12.5)/log($inletGrowthRate))}] $avgDs1 $inletSpacing $con
    }
}

## Redistribute Inlet IML Connectors
foreach con $inletIMLSymCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] < [lindex $Node1 0] } {
        RedistCons $inletGrowthRate [expr {int(log(12.5)/log($inletGrowthRate))}] 4 $inletSpacing $EFSpacing $con
    } else {
        RedistCons $inletGrowthRate 4 [expr {int(log(12.5)/log($inletGrowthRate))}] $EFSpacing $inletSpacing $con
    }
} 

RedistCons $inletGrowthRate 5 5 $EFSpacing $EFSpacing $inletIMLAftSymCons

pw::Display update
puts "Redistributed inlet/nozzle connectors."

## Modify Connector Distributions at Inlet/Nozzle Leading & Trailing Edges
RedistCons $leteGrowthRate [expr {int(log(1.5)/log($leteGrowthRate))}] [expr {int(log(1.5)/log($leteGrowthRate))}] $LESpacing $LESpacing [list $inletLECon]

## Resolve Inlet and Nozzle Leading/Trailing Edges with Anisotropic Triangles
set engineDomsCollection [pw::Collection create]
    $engineDomsCollection set [list $modelDoms(engine-OML)      \
                                    $modelDoms(inlet-IML)]
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
        [list $modelDoms(inlet-IML) $inletLECon]  \
    ]

    $engineDomsCollection do initialize
$engineDomsCollection delete
pw::Display update

## Re-Initialize Domains
set DomsCollection [pw::Collection create]
    $DomsCollection set [list $modelDoms(symmetry)]
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

set isoMode [pw::Application begin UnstructuredSolver [list $blk_1]]
$isoMode run Initialize
$isoMode end

set spinnerDoms [list $modelDoms(spinner-upper) \
                      $modelDoms(spinner-lower)]

set spinnerAftDoms [list $modelDoms(spinner-upper-aft) \
                         $modelDoms(spinner-lower-aft)]


# Define boundary conditions

set freestreamBC [pw::BoundaryCondition create]
    $freestreamBC setName "bc-01"
    $freestreamBC apply [list $blk_1 $modelDoms(freestream)]

set nearfieldBC [pw::BoundaryCondition create]
    $nearfieldBC setName "bc-02"
    $nearfieldBC apply [list $blk_1 $modelDoms(nearfield)]

set symmetryBC [pw::BoundaryCondition create]
    $symmetryBC setName "bc-03"
    $symmetryBC apply [list $blk_1 $modelDoms(symmetry)]

set outflowBC [pw::BoundaryCondition create]
    $outflowBC setName "bc-04"
    $outflowBC apply [list $blk_1 $modelDoms(outflow)]

set aipBC [pw::BoundaryCondition create]
    $aipBC setName "bc-05"
    $aipBC apply [list $blk_1 $modelDoms(aip)]

set inletBC [pw::BoundaryCondition create]
    $inletBC setName "bc-06"
    $inletBC apply [list $blk_1 $modelDoms(inlet-IML)]

set spinnerBC [pw::BoundaryCondition create]
    $spinnerBC setName "bc-07"
    foreach dom $spinnerDoms {$spinnerBC apply [list $blk_1 $dom]}
    
set engineBC [pw::BoundaryCondition create]
    $engineBC setName "bc-08"
    $engineBC apply [list $blk_1 $modelDoms(engine-OML)]

set inletaftBC [pw::BoundaryCondition create]
    $inletaftBC setName "bc-09"
    $inletaftBC apply [list $blk_1 $modelDoms(inlet-IML-aft)]

set spinneraftBC [pw::BoundaryCondition create]
    $spinneraftBC setName "bc-10"
    foreach dom $spinnerAftDoms {$spinneraftBC apply [list $blk_1 $dom]}

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
  $ioMode initialize -type CAE [file join $scriptDir "../../AFLR3/Viscous/LBFD_PW"]

  if {![$ioMode verify]} {
    error "Data verification failed."
  }
  $ioMode write
$ioMode end
unset ioMode

pw::Display update
exit

#