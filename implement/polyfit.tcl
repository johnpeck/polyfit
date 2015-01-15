

# --------------------- Global configuration --------------------------

# The script name.  This will be used to name various configuration
# and log files.
set scriptname "polyfit"

# By default, the software will look for the configuration file in the
# directory from which it was launched.  If the configuration file is
# not found, one will be created.
set configfile "${scriptname}.cfg"

set logfile "${scriptname}.log"

# This software's version.  Anything set here will be clobbered by the
# makefile when starpacks are built.
set revcode 1.0


# Set the log level.  Known values are:
# debug
# info
# notice
# warn
# error
# critical
# alert
# emergency
set loglevel debug


# -------------------------- Root window ------------------------------

menu .menubar
menu .menubar.help -tearoff 0
.menubar add cascade -label Help -menu .menubar.help -underline 0
. configure -menu .menubar -width 200 -height 150
.menubar.help add command -label "About ${scriptname}..." \
    -underline 0 -command help.about

# Create window icon
set wmiconfile ./icons/calc_16x16.png
set wmicon [image create photo -format png -file $wmiconfile]
wm iconphoto . $wmicon

proc help.about {} {
    # What to execute when Help-->About is selected
    #
    # Arguments:
    #   None
    global log
    global revcode
    global scriptname
    tk_messageBox -message "${scriptname}\nVersion $revcode" \
	-title "About $scriptname"
}



# -------------------------- Set up fonts -----------------------------

# This has to come before the logger setup, since the logger needs
# fonts for the console logger.
font create FixedFont -family TkFixedFont -size 12
font create LogFont -family TkFixedFont -size 8; # Font for console log

proc modinfo {modname} {
    set modver [package require $modname]
    set modlist [package ifneeded $modname $modver]
    set modpath [lindex $modlist end]
    return "Loaded $modname module version $modver from ${modpath}."
}


#----------------------------- Set up logger --------------------------

# The logging system will use the console text widget for visual
# logging.

package require logger
source loggerconf.tcl

${log}::info [modinfo logger]

# Testing the logger

.console_text insert end "Current loglevel is: [${log}::currentloglevel] \n"
${log}::info "Trying to log to [file normalize $logfile]"
${log}::info "Known log levels: [logger::levels]"
${log}::info "Known services: [logger::services]"
${log}::debug "Debug message"
${log}::info "Info message"
${log}::warn "Warn message"
${log}::error "Error message"



# ------------------- Set up configuration file -----------------------

package require inifile
${log}::info [modinfo inifile]
source config.tcl

proc config.init {} {
    # Write an initial configuration file.  This will be
    # project-dependent, so it can't go in the config.tcl library.
    #
    # Arguments:
    #   None
    global log
    global revcode
    global configfile
    set fcon [ini::open $configfile w]
    # ---------------------- Private section --------------------------
    ini::set $fcon private version $revcode
    ini::comment $fcon private "" "Internal use -- do not edit."
    ini::commit $fcon
    ini::close $fcon
}


	
if {[file exists $configfile] == 0} {
    # The config file does not exist
    ${log}::info "Creating new configuration file [file normalize $configfile]"
    set fcon [ini::open $configfile w]
    ini::close $fcon
    config.init
} else {
    ${log}::info "Reading configuration file [file normalize $configfile]"
    set fcon [ini::open $configfile r]
    ${log}::info "Configuration file version is\
                  [ini::value $fcon private version]"
    ini::close $fcon
}



# -------------------- Datafile selection boxes -----------------------

set fileiconfile ./icons/calc_16x16.png
set fileicon [image create photo -format png -file $fileiconfile]


proc getfile {platform} {
    # Sets a global variable to a filename chosen via a dialog box.
    #
    # Arguments:
    #   platform -- Either freefield or tester
    global log
    global plotdata
    set fopen [tk_getOpenFile]
    ${log}::debug "Opening $fopen"
    .${platform}_enty delete 0 end
    .${platform}_enty insert 0 [file tail $fopen]
    set fp [open $fopen r]
    set rawdata [read $fp]
    dict set plotdata $platform $rawdata
    plotall
    close $fp
}

proc calculate {} {
    global anecfilename
    global testfilename
    global log
    set fp [open $anecfilename r]
    set rawdata [read $fp]
    foreach line [split $rawdata "\n"] {
	${log}::debug $line
    }
    plotdata
}

# Free field filename entry
ttk::labelframe .freefield_frme -text "Free-field data"\
    -labelanchor n\
    -borderwidth 1\
    -relief sunken
button .freefield_butt -image $fileicon \
    -command "getfile freefield"
ttk::entry .freefield_enty \
    -width 20

# Tester filename entry
ttk::labelframe .tester_frme -text "Tester data"\
    -labelanchor n\
    -borderwidth 1\
    -relief sunken
button .tester_butt -image $fileicon \
    -command "getfile tester"
ttk::entry .tester_enty \
    -width 20

# Calculate button
button .calc_butt -text "Calculate" \
    -command calculate

#----------------------------- Plot -----------------------------------
package require Plotchart
${log}::info [modinfo inifile]

canvas .plot_cnvs -background white -width 600 -height 200

# Create a dictionary to hold plot data
# freefield: free field data
# tester: tester data
# corrected: corrected tester data
set plotdata [dict create]

set curveplot [::Plotchart::createLogXYPlot .plot_cnvs {10 30000} {-1 10 2}]
$curveplot dataconfig freefield -color "blue"
$curveplot dataconfig tester -color "red"
$curveplot dataconfig corrected -color "green"
$curveplot xtext "Frequency (Hz)"
$curveplot xconfig -format "%0.0f"
$curveplot ytext "Response (dB)"

proc plotall {} {
    # Plots frequency response data
    #
    # Arguments:
    #   none
    global plotdata
    global curveplot
    foreach entry [dict keys $plotdata] {
	foreach line [split [dict get $plotdata $entry] "\n"] {
	    if {[string index $line 0] == {#}} {
		# Skip commented lines
		continue
	    }
	    set xdatum [lindex [split $line] 0]
	    set ydatum [lindex [split $line] 1]
	    $curveplot plot $entry $xdatum $ydatum
	}
    }
}



#------------------------- Pack widgets -------------------------------



pack .freefield_frme

pack .freefield_butt -in .freefield_frme \
    -side left \
    -padx {5 0}

pack .freefield_enty -in .freefield_frme \
    -side right \
    -padx {0 5}

pack .tester_frme

pack .tester_butt -in .tester_frme \
    -side left \
    -padx {5 0}

pack .tester_enty -in .tester_frme \
    -side right \
    -padx {0 5}

pack .calc_butt

pack .plot_cnvs


# The main window log box
pack .console_frme -side bottom\
    -padx 10 \
    -pady 10
pack .console_scrl -fill y -side right -in .console_frme
pack .console_text -fill x -side bottom\
    -in .console_frme


