# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

namespace eval ::evlog {
	namespace export *
	namespace ensemble create

	variable con
	variable tid

	proc connect {sourcename {uri uds:///tmp/evlog.socket}} { #<<<
		variable con
		package require netdgram

		if {[info exists con]} {
			$con destroy
			unset con
			proc event {args} {}
		}

		if {$uri eq ""} return

		set con	[netdgram::connect_uri $uri]
		proc [info object namespace $con]::log args {}
		$con send [encoding convertto utf-8 \
				[list init $sourcename [clock microseconds]]]

		# Redefine newevent to actually send the event now that we have a
		# connection
		proc event {type {details ""}} [format {
			%s send [encoding convertto utf-8 \
					[list ev [clock microseconds] $type [uplevel 1 [list subst $details]]]]
		} [list $con]]
	}

	#>>>
	proc connect_thread {sourcename {uri uds:///tmp/evlog.socket}} { #<<<
		variable tid
		if {[info exists tid]} {
			thread::release $tid
			unset tid
		}
		if {$uri eq ""} return
		package require Thread 2.6.6
		set tid	[thread::create -preserved [string map [list \
				%tm_path%		[tcl::tm::path list] \
				%auto_path%		[list $::auto_path] \
				%uri%			[list $uri] \
				%sourcename%	[list $sourcename] \
		] {
			tcl::tm::path add %tm_path%
			set auto_path	%auto_path%

			package require netdgram

			set con	[netdgram::connect_uri %uri%]
			proc [info object namespace $con]::log args {}
			proc send packet [format {
				%s send [encoding convertto utf-8 $packet]
			} [list $con]]
			send [list init %sourcename% [clock microseconds]]

			thread::wait
		}]]
		proc event {type {details ""}} [format {
			thread::send -async %s [list send [list ev [clock microseconds] \
					$type [uplevel 1 [list subst $details]]]]
		} [list $tid]]
	}

	#>>>

	# Defined like this it's a fairly inexpensive nop
	proc event args {}
}

