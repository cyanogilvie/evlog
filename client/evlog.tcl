# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

namespace eval evlog {
	namespace export *
	namespace ensemble create

	variable con

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

	# Defined like this it's a fairly inexpensive nop
	proc event {args} {}
}

