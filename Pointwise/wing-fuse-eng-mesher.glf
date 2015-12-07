#
# Copyright 2015 © Pointwise, Inc.
# All rights reserved.
#
# This sample script is not supported by Pointwise, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#
# ============================================================================
# GENERATE AN UNSTRUCTURED VOLUME MESH FOR A GENERIC AIRCRAFT GEOMETRY
# ============================================================================
# Originally written by: Zach Davis, Pointwise, Inc.
# Extensive Modification by Christopher Heath, NASA GRC
#
# This script demonstrates the viscous meshing process using a generic 
# transport aircraft geometry created with OpenVSP. The user has control 
# over the farfield size and boundary layer resolution. The resulting grid
# is saved to the current working directory. 
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

set fileName                 "wing-fuse-eng.pw";  # Aircraft geometry filename
set cLen                          32.0;  # Characteristic length (m)
set ffSize                       100.0;  # Farfield size (cLen multiplier)
set avgDs1                         1.0;  # Initial surface triangle average edge length
set avgDs2                         0.1;  # Refined surface triangle average edge length
set avgDs3                       0.075;  # Engine IML/OML surface triangle average edge length
set teDim                            5;  # Number of points across trailing edges
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

# Gather Analysis Model Information
set allDbs [pw::Database getAll]
foreach db $allDbs {
    if { [$db getDescription] == "Model"} {
        set dbModel $db
    }
}

set numQuilts [$dbModel getQuiltCount]
for { set i 1 } { $i <= $numQuilts } { incr i } {
    lappend dbQuilts [$dbModel getQuilt $i]
}

pw::Display update
pw::Application setCAESolver {NASA/FUN3D} 3

# Mesh Surfaces
if { [$dbModel isBaseForDomainUnstructured] } {
    puts "Meshing [$dbModel getName] model..."
    set surfDoms [pw::DomainUnstructured createOnDatabase -joinConnectors 100 \
        -reject unusedSurfs $dbModel]

    if { [llength $unusedSurfs] > 0 } {
        puts "Unused surfaces exist, please check geometry."
        puts $unusedSurfs
        exit -1
    }
} else {
    puts "Unable to mesh model."
    exit -1
}

# Survey Surface Mesh and Isolate Domains and Connectors
foreach qlt $dbQuilts {
    set modelDoms([$qlt getName]) [DomFromQuilt $qlt]
}

set wingLowerCons [ConsFromDom $modelDoms(wing-lower)]
set wingUpperCons [ConsFromDom $modelDoms(wing-upper)]
set wingTipCons   [ConsFromDom $modelDoms(wing-tip)]
set wingLETECons  [intersect $wingLowerCons $wingUpperCons]

set upperNoseCons [ConsFromDom $modelDoms(nose-upper)]
set lowerNoseCons [ConsFromDom $modelDoms(nose-lower)]

set fuselageCons [ConsFromDom $modelDoms(fuselage)]
set fuseUpperTECons [ConsFromDom $modelDoms(fuse-upper-trailing-edge)]
set fuseLowerTECons [ConsFromDom $modelDoms(fuse-lower-trailing-edge)]

set engineOMLCons [ConsFromDom $modelDoms(engine-OML)]
set inletIMLCons [ConsFromDom $modelDoms(inlet-IML)]

set spinnerUpperCons [ConsFromDom $modelDoms(spinner-upper)]
set spinnerLowerCons [ConsFromDom $modelDoms(spinner-lower)]

set aipCons [ConsFromDom $modelDoms(aip)]

set symCons [ConsFromDom $modelDoms(symmetry)]
set engineOMLSymCons [intersect $engineOMLCons $symCons]

set inletIMLSymCons [intersect $inletIMLCons $symCons]

set fuseSymCons [intersect $symCons $fuselageCons]

## Isolate Connectors for 2D T-Rex

set wingLowerRootCon [intersect $wingLowerCons $fuselageCons]
set wingUpperRootCon [intersect $wingUpperCons $fuselageCons]
set wingLowerTipCon  [intersect $wingLowerCons $wingTipCons]
set wingUpperTipCon  [intersect $wingUpperCons $wingTipCons]

set aipCon                [intersect $aipCons $inletIMLCons]
set inletLECon            [intersect $engineOMLCons $inletIMLCons]

set fuseUpperTESymCon     [intersect $fuseUpperTECons $symCons]
set fuseLowerTESymCon     [intersect $fuseLowerTECons $symCons]
set fuseUpperTECon        [intersect $fuseUpperTECons $fuselageCons]
set fuseLowerTECon        [intersect $fuseLowerTECons $fuselageCons]
set fuseCenterTECon       [intersect $fuseLowerTECons $fuseUpperTECons]
set noseUpperCon          [intersect $symCons $upperNoseCons]
set noseLowerCon          [intersect $symCons $lowerNoseCons]
set noseCenterCon         [intersect $upperNoseCons $lowerNoseCons] 

set spinnerUpperCon          [intersect $spinnerUpperCons $symCons]
set spinnerLowerCon          [intersect $spinnerLowerCons $symCons]
set spinnerSymCon            [intersect $spinnerUpperCons $spinnerLowerCons]

set aipNode0              [$aipCon getXYZ -parameter 0.0]
set aipNode1              [$aipCon getXYZ -parameter 1.0]

set noseCenterNode0       [$noseCenterCon getXYZ -parameter 0.0]
set noseCenterNode1       [$noseCenterCon getXYZ -parameter 1.0]
 
foreach con $inletIMLSymCons {
    lappend engineIMLSymCons $con
}

set spinnerCons [list $spinnerUpperCon        \
                   $spinnerLowerCon        \
                   $spinnerSymCon]

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

puts "Finished isolating connectors."

# Update Display Window to More Clearly Render the Surface Mesh
pw::Display setShowDatabase 0

set allDomsCollection [pw::Collection create]
    $allDomsCollection set [pw::Grid getAll -type pw::Domain]
    $allDomsCollection do setRenderAttribute FillMode HiddenLine
$allDomsCollection delete

pw::Display update

# Refine Wing and Tail Surface Meshes with 2D T-Rex
## Adjust Domain Solver Attributes/Update Edge Spacing on Wing & Tail Connectors
set wingTailDomsCollection [pw::Collection create]
    $wingTailDomsCollection set [list $modelDoms(wing-lower)  \
                                      $modelDoms(wing-upper)]

    $wingTailDomsCollection do setUnstructuredSolverAttribute \
        EdgeMaximumLength $avgDs2
$wingTailDomsCollection delete

set wingTailConsCollection [pw::Collection create]
    $wingTailConsCollection set [lsort -unique [join [list $wingLowerCons      \
                                                           $wingUpperCons      \
                                                           $wingTipCons        \
                                                           $upperNoseCons      \
                                                           $lowerNoseCons      \
                                                           $fuselageCons       \
                                                           $fuseUpperTECons    \
                                                           $fuseLowerTECons]]]

   pw::Connector setCalculateDimensionSpacing $avgDs2
   $wingTailConsCollection do calculateDimension
$wingTailConsCollection delete

set engineConsCollection [pw::Collection create]
    $engineConsCollection set [lsort -unique [join [list $engineOMLCons      \
                                                         $inletIMLCons       \
                                                         $spinnerUpperCons   \
                                                         $spinnerLowerCons   \
                                                         $aipCons]]]

   pw::Connector setCalculateDimensionSpacing $avgDs3
   $engineConsCollection do calculateDimension
$engineConsCollection delete

## Find AIP and Nozzle Exit Plane Locations
if { [lindex $aipNode0 0] > [lindex $aipNode1 0] } {
    set aipMax $aipNode0
} else {
    set aipMax $aipNode1
}

## Find aft node of nose center connector
if { [lindex $noseCenterNode0 0] > [lindex $noseCenterNode1 0] } {
    set noseCenterMax $noseCenterNode0
} else {
    set noseCenterMax $noseCenterNode1
}

foreach con $aipCons {
    RedistCons $growthRate [expr {int(log(2.0)/log($growthRate))}] [expr {int(log(2.0)/log($growthRate))}] $EFSpacing $EFSpacing $con
}

foreach con $spinnerCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] < [lindex $Node1 0] } {
        RedistCons $growthRate [expr {int(log(2.5)/log($growthRate))}] [expr {int(log(2.5)/log($growthRate))}] $tePlug $EFSpacing $con
        ##RedistCons $growthRate [expr {int(log(2.5)/log($growthRate))}] [expr {int(log(2.5)/log($growthRate))}] $EFSpacing $EFSpacing $con
    } else {
        RedistCons $growthRate [expr {int(log(2.5)/log($growthRate))}] [expr {int(log(2.5)/log($growthRate))}] $EFSpacing $tePlug $con
        ##RedistCons $growthRate [expr {int(log(2.5)/log($growthRate))}] [expr {int(log(2.5)/log($growthRate))}] $EFSpacing $EFSpacing $con
    }
}

pw::Display update

## Differentiate Between Upper/Lower Fuselage Connectors
foreach con $fuseSymCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] < [lindex $Node1 0] } {  
        RedistCons $fuseGrowthRate [expr {int(log(1.5)/log($fuseGrowthRate))}] [expr {int(log(2.0)/log($fuseGrowthRate))}] $avgDs2 [expr {$avgDs2/$aspectRatio}] $con
    } else {                                            
        RedistCons $fuseGrowthRate [expr {int(log(2.0)/log($fuseGrowthRate))}] [expr {int(log(1.5)/log($fuseGrowthRate))}] [expr {$avgDs2/$aspectRatio}] $avgDs2  $con
    }
}

pw::Display update
puts "Redistributed fuselage symmetry connectors."

## Differentiate Between Inlet/Nozzle Connectors
foreach con $engineOMLSymCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] < [lindex $Node1 0] } {
        RedistCons $inletGrowthRate [expr {int(log(12.5)/log($inletGrowthRate))}] [expr {int(log(30.0)/log($inletGrowthRate))}] $inletSpacing $rtSpacing $con
    } else {
        RedistCons $inletGrowthRate [expr {int(log(30.0)/log($inletGrowthRate))}] [expr {int(log(12.5)/log($inletGrowthRate))}] $rtSpacing $inletSpacing $con
    }
}

## Differentiate Between Inlet/Nozzle Connectors
foreach con $engineIMLSymCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] <= [lindex $aipMax 0] } {            ## Inlet Cons
        if { [lindex $Node0 0] < [lindex $Node1 0] } {
            RedistCons $inletGrowthRate [expr {int(log(12.5)/log($inletGrowthRate))}] [expr {int(log(5.0)/log($inletGrowthRate))}] $inletSpacing $EFSpacing $con
        } else {
            RedistCons $inletGrowthRate [expr {int(log(5.0)/log($inletGrowthRate))}] [expr {int(log(12.5)/log($inletGrowthRate))}] $EFSpacing $inletSpacing $con
        }
    }
}

pw::Display update
puts "Redistributed inlet/nozzle connectors."

## Isolate Beg/End Nodes for Fuselage Tail Section & Modify

set tailCons [list $fuseUpperTESymCon      \
                   $fuseLowerTESymCon      \
                   $fuseCenterTECon]

foreach con $tailCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] < [lindex $Node1 0] } {
        RedistCons $fuseGrowthRate [expr {int(log(3.5)/log($fuseGrowthRate))}] [expr {int(log(5)/log($fuseGrowthRate))}] [expr {$avgDs2/$aspectRatio}] 0.001 $con
    } else {
        RedistCons $fuseGrowthRate [expr {int(log(5)/log($fuseGrowthRate))}] [expr {int(log(3.5)/log($fuseGrowthRate))}] 0.001 [expr {$avgDs2/$aspectRatio}] $con
    }
}           

pw::Display update
puts "Redistributed fuselage aft connectors."

## Isolate Fuselage Tail Section Connectors & Modify
RedistCons $fuseGrowthRate $fuseTELayers $fuseTELayers [expr {$avgDs2/$aspectRatio}] [expr {$avgDs2/$aspectRatio}] $fuseUpperTECon
RedistCons $fuseGrowthRate $fuseTELayers $fuseTELayers [expr {$avgDs2/$aspectRatio}] [expr {$avgDs2/$aspectRatio}] $fuseLowerTECon
pw::Display update

## Modify Connector Distributions at the Wing & Tail Root
set chordCons [list $wingLowerRootCon      \
                    $wingUpperRootCon]

foreach con $chordCons {

    set Node0 [$con getXYZ -parameter 0.0]
    set Node1 [$con getXYZ -parameter 1.0]

    if { [lindex $Node0 0] < [lindex $Node1 0] } {
        RedistCons $rtGrowthRate $rootLayers $rootLayers $LESpacing $TESpacing $con
    } else {
        RedistCons $rtGrowthRate $rootLayers $rootLayers $TESpacing $LESpacing $con
    }
}

## Modify Connector Distributions at the Wing & Tail Tip
set chordCons [list $wingLowerTipCon       \
                    $wingUpperTipCon]

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
    $tipDomsCollection set [list $modelDoms(wing-tip)]

    $tipDomsCollection do initialize
$tipDomsCollection delete

pw::Display update

## Modify Connector Distributions at Wing/Tail Leading & Trailing Edges
set spanCons [list $wingLECon               \
                   $wingTECon]

[[$wingLECon getDistribution 1] getBeginSpacing] setValue $LESpacing
[[$wingLECon getDistribution 1] getEndSpacing] setValue $LESpacing
[[$wingTECon getDistribution 1] getBeginSpacing] setValue $TESpacing
[[$wingTECon getDistribution 1] getEndSpacing] setValue $TESpacing 

RedistCons $leteGrowthRate [expr {int(log($aspectRatio)/log($leteGrowthRate))}] [expr {int(log($aspectRatio)/log($leteGrowthRate))}] $LESpacing  $LESpacing $spanCons

pw::Display update
puts "Redistributed wing/tail/pylon leading/trailing edge symmetry connectors."

## Modify Connector Distributions at Inlet/Nozzle Leading & Trailing Edges
RedistCons $leteGrowthRate [expr {int(log(1.5)/log($leteGrowthRate))}] [expr {int(log(1.5)/log($leteGrowthRate))}] $LESpacing $LESpacing [list $inletLECon]


## Resolve Inlet and Nozzle Leading/Trailing Edges with Anisotropic Triangles
set engineDomsCollection [pw::Collection create]
    $engineDomsCollection set [list $modelDoms(engine-OML)  \
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
        [list $modelDoms(inlet-IML) $inletLECon] \
    ]

    $engineDomsCollection do initialize
$engineDomsCollection delete
pw::Display update

## Resolve Wing/Tail Leading & Trailing Edges with Anisotropic Triangles
set wingEmpennageDomsCollection [pw::Collection create]
    $wingEmpennageDomsCollection set [list $modelDoms(wing-lower)  \
                                           $modelDoms(wing-upper)]

    $wingEmpennageDomsCollection do setUnstructuredSolverAttribute \
        TRexMaximumLayers $tipLayers
    $wingEmpennageDomsCollection do setUnstructuredSolverAttribute \
        TRexGrowthRate $domGrowthRate

    set leBC [pw::TRexCondition create]

    $leBC setName "wing-tail-leading-edge"
    $leBC setType Wall
    $leBC setSpacing $LESpacing
    $leBC apply [list \
        [list $modelDoms(wing-lower) $wingLECon] \
        [list $modelDoms(wing-upper) $wingLECon]
    ]

    set teBC [pw::TRexCondition create]

    $teBC setName "wing-tail-trailing-edge"
    $teBC setType Wall
    $teBC setSpacing $TESpacing
    $teBC apply [list \
        [list $modelDoms(wing-lower) $wingTECon] \
        [list $modelDoms(wing-upper) $wingTECon]
    ]

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
    $DomsCollection set [list $modelDoms(nose-upper)  \
                              $modelDoms(nose-lower)  \
                              $modelDoms(symmetry)    \
                              $modelDoms(fuselage)]
    $DomsCollection do initialize
$DomsCollection delete

pw::Display update
puts "Surface Meshing Complete"

set allDoms [pw::Grid getAll -type pw::Domain]
set doms {}
foreach dom $allDoms {
    lappend doms $dom
}

# Assemble blocks from these domains
set blks [pw::BlockUnstructured createFromDomains $doms]

set blk1 [pw::GridEntity getByName "blk-1"]
set isoMode [pw::Application begin UnstructuredSolver [list $blk1]]
$isoMode run Initialize
$isoMode end

set surfDoms [list $modelDoms(wing-lower)                \
                   $modelDoms(wing-upper)                \
                   $modelDoms(wing-tip)                  \
                   $modelDoms(nose-upper)                \
                   $modelDoms(nose-lower)                \
                   $modelDoms(fuselage)                  \
                   $modelDoms(fuse-upper-trailing-edge)  \
                   $modelDoms(fuse-lower-trailing-edge)  \
                   $modelDoms(engine-OML)                \
                   $modelDoms(inlet-IML)                 \
                   $modelDoms(spinner-upper)             \
                   $modelDoms(spinner-lower)]

# Define boundary conditions
set aircraftBC [pw::BoundaryCondition create]
    $aircraftBC setName "bc-1"
    foreach dom $surfDoms {$aircraftBC apply [list $blk1 $dom]}

set freestreamBC [pw::BoundaryCondition create]
    $freestreamBC setName "bc-2"
    $freestreamBC apply [list $blk1 $modelDoms(freestream)]

set nearfieldBC [pw::BoundaryCondition create]
    $nearfieldBC setName "bc-3"
    $nearfieldBC apply [list $blk1 $modelDoms(nearfield)]

set symmetryBC [pw::BoundaryCondition create]
    $symmetryBC setName "bc-4"
    $symmetryBC apply [list $blk1 $modelDoms(symmetry)]

set outflowBC [pw::BoundaryCondition create]
    $outflowBC setName "bc-5"
    $outflowBC apply [list $blk1 $modelDoms(outflow)]

set aipBC [pw::BoundaryCondition create]
    $aipBC setName "bc-6"
    $aipBC apply [list $blk1 $modelDoms(aip)]

timestamp
puts "Run Time: [convSeconds [pwu::Time elapsed $tBegin]]"

# Save the Pointwise Project
set fileRoot [file rootname $fileName]
set fileExport "$fileRoot-Grid.pw"

puts ""
puts "Writing $fileExport file..."
puts ""

pw::Application save [file join $scriptDir $fileExport]

set ioMode [pw::Application begin CaeExport [pw::Entity sort [list $blk1]]]
  $ioMode initialize -type CAE [file join $scriptDir "../AFLR3/LBFD_PW"]

  if {![$ioMode verify]} {
    error "Data verification failed."
  }
  $ioMode write
$ioMode end
unset ioMode

pw::Display update
exit

#