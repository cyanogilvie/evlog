# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

Plugin m2 {
	method evtype_colours {evtype} { #<<<
		switch -- $evtype {
			queue_msg	{list #70ff70 #00ff00}
			receive_msg	{list #7070ff #0000ff}
			default		{next $evtype}
		}
	}

	#>>>
	method draw_marker {source evtime evtype c x y1 y2 args} { #<<<
		set id	[next $source $evtime $evtype $c $x $y1 $y2 {*}$args]
		$c bind $id <Enter> [code _enter $source $evtime $evtype %W %X %Y]
		$c bind $id <Leave> [code _leave $source $evtime $evtype %W]
		set id
	}

	#>>>
	method _build_infowin {c source evtime evtype} { #<<<
		set infowin	[next $c $source $evtime $evtype]
		set details	[my _evdetails $source $evtime $evtype]
		if {$evtype eq "queue_msg"} {
			set remote	"to [dict get $details to]"
		} elseif {$evtype eq "receive_msg"} {
			set remote	"from [dict get $details from]"
		} else {
			set remote	"unknown"
		}
		set bg	[$infowin cget -background]
		message $infowin.l -background $bg -text [format "%s %s %s" \
				$remote [dict get $details msg type] \
				[dict get $details msg seq]] \
				-justify left -width 400
		pack $infowin.l -fill both -expand true
		set infowin
	}

	#>>>
}
