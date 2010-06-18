# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

oo::class create PluginBase {
	constructor {} { #<<<
		if {[self next] ne ""} next

		my variable name
		set name	[namespace tail [self]]

		lappend ::plugins $name

		namespace path [concat [namespace path] {
			::oo::Helpers::cflib
			::tcl::mathop
		}]
	}

	#>>>
	destructor { #<<<
		if {[info exists name]} {
			set ::plugins	[lsearch -inline -all -not $::plugins $name]
		}
		if {[self next] ne ""} next
	}

	#>>>
	method evtype_colours {evtype} { #<<<
		list #707070 #202020
	}

	#>>>
	method draw_marker {source evtime evtype c x y1 y2 args} { #<<<
		$c create polygon $x $y1 $x $y2 [+ $x 8] [/ [+ $y1 $y2] 2.0] {*}$args
	}

	#>>>
	method _enter {source evtime evtype c X Y} { #<<<
		log debug "_enter ($source) ($evtime) ($evtype) ($c) ($X, $Y)"
		my show_info $source $evtime $evtype $c $X $Y
	}

	#>>>
	method _leave {source evtime evtype c} { #<<<
		log debug "_leave ($source) ($evtime) ($evtype) ($c)"
		my hide_info
	}

	#>>>
	method show_info {source evtime evtype c X Y} { #<<<
		#coroutine coro_[incr ::coro_seq] my _track_pointer $c $X $Y
		coroutine coro_track_pointer my _track_pointer $source $evtime $evtype $c $X $Y
	}

	#>>>
	method _track_pointer {source evtime evtype c X Y} { #<<<
		my variable show_coro
		set show_coro	[info coroutine]
		set infowin			[my _build_infowin $c $source $evtime $evtype]
		set screenwidth		[winfo screenwidth $infowin]
		set screenheight	[winfo screenheight $infowin]
		set reqwidth		[winfo reqwidth $infowin]
		set reqheight		[winfo reqheight $infowin]
		bind $infowin <Configure> [list [info coroutine] infowin_configure]
		# TODO: save Motion binding stack?
		bind $c <Motion> [list apply {
			{coro X Y} {$coro [list motion $X $Y]}
		} [list [info coroutine]] %X %Y]
		while {1} {
			set rest	[lassign [yield] wakeup_reason]

			set movewin	0
			switch -- $wakeup_reason {
				infowin_configure {
					set reqwidth	[winfo reqwidth $infowin]
					set reqheight	[winfo reqheight $infowin]
					set movewin	1
				}

				motion {
					lassign $rest X Y
					set movewin	1
				}

				hide {
					break
				}
			}
			if {$movewin} {
				set newX	[+ $X 20]
				set newY	[+ $Y 20]
				if {$newX + $reqwidth > $screenwidth} {
					set newX	[- $X $reqwidth 15]
				}
				if {$newY + $reqheight > $screenheight} {
					set newY	[- $Y $reqheight 15]
				}
				wm geometry $infowin +$newX+$newY
			}
		}
		bind $c <Motion> {}
		unset show_coro
		destroy $c.info
		log debug "Track pointer exiting"
	}

	#>>>
	method _build_infowin {c source evtime evtype} { #<<<
		toplevel $c.info -background #fff3a6 \
				-highlightthickness 1 \
				-highlightbackground #d9c857 \
				-highlightcolor #d9c857
		wm transient $c.info $c
		wm attributes $c.info -alpha 0.8
		wm overrideredirect $c.info true
		wm positionfrom $c.info user

		return $c.info
	}

	#>>>
	method hide_info {} { #<<<
		my variable show_coro
		if {[info exists show_coro]} {
			$show_coro hide
		}
	}

	#>>>
	method _evdetails {source evtime evtype} { #<<<
		my variable name
		set fqevtype	$name.$evtype
		db onecolumn {
			select
				details
			from
				events
			where
				source = $source and
				evtype = $fqevtype and
				evtime = $evtime
		}
	}

	#>>>
	method draw_overlay {c start_usec usec_per_pixel} { #<<<
	}

	#>>>
	method adjust_overlay {c start_usec usec_per_pixel} { #<<<
	}

	#>>>
}
