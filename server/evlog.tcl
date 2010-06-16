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
package require logging
package require Thread 2.6.6
package require netdgram

namespace path [concat [namespace path] {
	::tcl::mathop
}]

cflib::config create cfg $argv {
	variable listen_uris	{tcp://:7200 uds:///tmp/evlog.socket}
	variable debug			0
	variable evdb			/tmp/evdb.sqlite3
	variable loglevel		notice
}

if {[cfg get debug]} {
	proc ?? {script} {uplevel 1 $script}
} else {
	proc ?? {args} {}
}

logging::logger ::log [cfg get loglevel]

# DB journaler thread <<<
set dbthread	[thread::create -preserved [format {
	set auto_path	%s
	tcl::tm::path add %s
	package require sqlite3
	package require logging
	package require cflib
	package require sop

	logging::logger ::log %s

	sqlite3 db %s
	if {[db onecolumn {
		select
			count(1) < 1
		from
			sqlite_master
		where
			type = 'table' and
			name = 'events'
	}]} {
		db eval {
			create table events (
				evtime		integer not null,
				source		text not null,
				evtype		text not null,
				details		text
			);

			create index events_evtime_idx on events(evtime);
		}
	}

	db eval begin
	sop::domino new bg_commit -name bg_commit -delay 250
	$bg_commit attach_output [list apply {
		{} {
			log debug "Commit"
			db eval commit
			db eval begin
		}
	}]

	if {0} {
		# Background committer <<<
		coroutine committer apply {
			{} {
				db eval begin
				while {1} {
					set afterid	[after 1000 [list [info coroutine] commit]]
					set op	[yield]
					after cancel $afterid; set afterid ""
					switch -- $op {
						commit {
							log debug "commit"
							db eval commit
							db eval begin
						}

						die {
							break
						}

						default {
							log error "Invalid committer wakeup reason: \"$op\""
						}
					}
				}
				db eval commit
			}
		}

		# Background committer >>>
	}

	proc newevent {evtime source evtype details} { #<<<
		global bg_commit

		db eval {
			insert into events (
				evtime,
				source,
				evtype,
				details
			) values (
				$evtime,
				$source,
				$evtype,
				$details
			)
		}

		$bg_commit tip
	}

	#>>>

	thread::wait

	try {
		$bg_commit cancel_if_pending
		db eval commit
	} on error {errmsg options} {
		log error "Error in db thread cleanup: [dict get $options -errorinfo]"
	}
} \
		[list $auto_path] \
		[tcl::tm::path list] \
		[list [cfg get loglevel]] \
		[list [cfg get evdb]] \
]]
# DB journaler thread >>>

proc newevent {evtime source evtype details} { #<<<
	global dbthread
	?? {log trivia "Logging event for \"$source\": $evtime ($evtype) ($details)"}
	thread::send -async $dbthread [list newevent $evtime $source $evtype $details]
}

#>>>

proc accept {con args} { #<<<
	oo::objdefine $con method received {msg} { #<<<
		my variable source time_adjustment

		set data	[lassign [encoding convertfrom utf-8 $msg] op]

		switch -- $op {
			init {
				lassign $data source source_time
				if {[info object class [self]] eq "::netdgram::connection::uds"} {
					# Don't adjust the times - they use the same reference
					# clock as us
					set time_adjustment	0
				} else {
					# The magic number 378 is a fudge factor based on tests on
					# my notebook for the delay from localhost
					set time_adjustment	[- [clock microseconds] $source_time 378]
				}
				newevent [clock microseconds] $source _connect ""
				?? {
					log trivia "Set source name for ([self]) to \"$source\""
					log trivia "Set time adjustment for ([self]) to \"$time_adjustment\" usec"
				}
			}

			ev {
				lassign $data source_time evtype details
				newevent [+ $source_time $time_adjustment] $source $evtype $details
			}

			default {
				log error "Invalid operation \"$op\""
			}
		}
	}

	#>>>
	oo::objdefine $con method closed {} { #<<<
		my variable source time_adjustment

		if {[info exists source]} {
			?? {log trivia "source \"$source\" disconnected"}
			newevent [clock microseconds] $source _disconnect ""
		} else {
			?? {log trivia "unidentified source disconnected"}
		}
	}

	#>>>

	$con activate
}

#>>>

set listeners	[dict create]
foreach listen_uri [cfg get listen_uris] {
	dict set listeners $listen_uri [netdgram::listen_uri $listen_uri]
	oo::objdefine [dict get $listeners $listen_uri] forward accept accept
	log notice "Ready on $listen_uri"
}

thread::wait
