#!/usr/bin/env tclsh8.6
# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

if {![info exists ::tcl::basekit]} {
	package require platform

	foreach platform [platform::patterns [platform::identify]] {
		set tm_path		[file join $env(HOME) .tbuild repo tm $platform]
		set pkg_path	[file join $env(HOME) .tbuild repo pkg $platform]
		if {[file exists $tm_path]} {
			tcl::tm::path add $tm_path
		}
		if {[file exists $pkg_path]} {
			lappend auto_path $pkg_path
		}
	}
}

package require cflib
package require sop
package require blttable
package require cftklib
package require megawidget
package require logging
package require sqlite3

ttk::style theme use clam

set here	[file dirname [file normalize [info script]]]
cflib::config create cfg $argv {
	variable debug				0
	variable evdb				/tmp/evdb.sqlite3
	variable loglevel			notice
	variable min_usec_per_pixel	7
}

if {[cfg get debug]} {
	proc ?? {script} {uplevel 1 $script}
} else {
	proc ?? {args} {}
}

logging::logger ::log [cfg get loglevel]

if {![file readable [cfg get evdb]]} {
	log fatal "Cannot open event log file: \"[cfg get evdb]\""
	exit 1
}
sqlite3 db [cfg get evdb]
if {[db onecolumn {
	select
		count(1) < 1
	from
		sqlite_master
	where
		type = 'table' and
		name = 'events'
}]} {
	log fatal "Event log doesn't contain events table"
	exit 1
}

source [file join $here main.tcl]

try {
	Main .main -title "Evlog Visualizer"
} on error {errmsg options} {
	puts stderr [dict get $options -errorinfo]
}

.main show
