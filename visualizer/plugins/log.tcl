# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

Plugin log {
	method evtype_colours {evtype} { #<<<
		switch -- $evtype {
			trivia -
			debug	{list #fffdd0 #ecd98f}
			error	{list #fd1e00 #d22d17}
			warn*	{list #f929d9 #ae1196}
			default	{list #fbf795 #e1c75e}
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
		set bg	[$infowin cget -background]
		message $infowin.l -text [my _evdetails $source $evtime $evtype] \
				-justify left -width 400 -background $bg
		pack $infowin.l -fill both -expand true
		set infowin
	}

	#>>>
}
