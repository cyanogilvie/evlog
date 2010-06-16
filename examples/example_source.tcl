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

set here	[file dirname [file normalize [info script]]]
set base	[file dirname $here]
tcl::tm::path add [file join $base tm tcl]

package require evlog

evlog event foo		;# does nothing

evlog connect [file tail [info script]]

apply {
	{} {
		set localvar	"hello local"

		evlog event bar {Details for bar: [info cmdcount] $localvar}
		evlog event baz {Details for baz: [info cmdcount] $localvar}
	}
}

