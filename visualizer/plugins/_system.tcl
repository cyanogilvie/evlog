# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

Plugin _system {
	method _evdetails {source evtime evtype} { #<<<
		db onecolumn {
			select
				details
			from
				events
			where
				source = $source and
				evtype = $evtype and
				evtime = $evtime
		}
	}

	#>>>
}
