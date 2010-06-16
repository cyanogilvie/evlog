# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

cftklib::Application subclass Main {
	variable {*}{
		w
		hull
		dominos
		usec_per_pixel
		centre_usec
		canv_width
		canv_height
		earliest_usec
		latest_usec
		start_usec
		end_usec
		repaint
		ids
	}

	constructor {args} { #<<<
		my variable source_seq source_ys

		set repaint		1
		set source_seq	0
		set source_ys	[dict create]
		set ids			[dict create]

		next {*}$args

		namespace path [concat [namespace path] {
			::tcl::mathop
		}]

		array set dominos {}
		sop::domino new dominos(redraw) -name redraw

		canvas $w.c -borderwidth 1 -relief sunken -background white \
				-xscrollcommand [list $w.hsb set]
		ttk::scrollbar $w.hsb -orient horizontal -command [list $w.c xview]
		ttk::scale $w.zoom -orient horizontal -variable [scope usec_per_pixel] \
				-command [list $dominos(redraw) tip]

		my refresh

		table $w -padx 0 -pady 0 \
				$w.c		1,1 -fill both \
				$w.hsb		2,1 -fill x \
				$w.zoom		3,1 -fill x
		table configure $w r2 r3 -resize none

		$dominos(redraw) attach_output [code _redraw]

		bind $w.c <Configure> [code _recalc_zoom %w %h]

		my configure \
				-geometry	"1280x512"
	}

	#>>>
	destructor { #<<<
		if {$::errorInfo ne ""} {
			puts $::errorInfo
		}
		if {[self next] ne ""} next
	}

	#>>>
	method refresh {} { #<<<
		db eval {
			select
				(min(evtime) + max(evtime)) / 2		as centre_usec,
				min(evtime)							as earliest_usec,
				max(evtime)							as latest_usec
			from
				events
		} {}

		if {[info exists canv_width]} {
			$dominos(redraw) tip
		}
	}

	#>>>
	method _recalc_zoom {width height} { #<<<
		set canv_width	$width
		set canv_height	$height

		set time_range_usec		[- $latest_usec $earliest_usec]
		set max_usec_per_pixel	[expr {$time_range_usec / double($width)}]
		set min_usec_per_pixel	7

		$w.zoom configure -from $max_usec_per_pixel -to $min_usec_per_pixel

		if {![info exists usec_per_pixel]} {
			set usec_per_pixel	$max_usec_per_pixel
			$dominos(redraw) tip
		} elseif {$usec_per_pixel > $max_usec_per_pixel} {
			set usec_per_pixel	$max_usec_per_pixel
			$dominos(redraw) tip
		} elseif {$usec_per_pixel < $min_usec_per_pixel} {
			set usec_per_pixel	$min_usec_per_pixel
			$dominos(redraw) tip
		}
	}

	#>>>
	method _redraw {} { #<<<
		lassign [$w.c xview] a b
		set range		[- $latest_usec $earliest_usec]
		set left_usec	[expr {$earliest_usec + $range * $a}]
		set right_usec	[expr {$earliest_usec + $range * $b}]
		set centre_usec	[/ [+ $left_usec $right_usec] 2]
		log debug "a: ($a) b: ($b)"
		log debug [format "usec_per_pixel: %.6f" $usec_per_pixel]
		set half_time	[expr {($usec_per_pixel * $canv_width) / 2}]
		log debug [format "half_time: %.6f seconds" [/ $half_time 1000000.0]]
		set start_usec	[- $centre_usec $half_time]
		set end_usec	[+ $centre_usec $half_time]

		if {$start_usec < $earliest_usec} {
			set delta		[- $earliest_usec $start_usec]
			set start_usec	[+ $start_usec $delta]
			set end_usec	[+ $end_usec $delta]
			set centre_usec	[/ [+ $start_usec $end_usec] 2]
			log debug "Correcting for underflow, delta $delta usec"
		} elseif {$end_usec > $latest_usec} {
			set delta		[- $end_usec $latest_usec]
			set start_usec	[- $start_usec $delta]
			set end_usec	[- $end_usec $delta]
			set centre_usec	[/ [+ $start_usec $end_usec] 2]
			log debug "Correcting for overflow, delta $delta usec"
		}

		if {$repaint} {
			$w.c delete all
			set ids		[dict create]
			db eval {
				select
					evtime,
					source,
					evtype,
					details
				from
					events
				where
					evtime >= $start_usec and
					evtime <= $end_usec
				order by
					evtime asc
			} {
				set x	[my _usec2x $evtime]
				lassign [my _source_ys $source] y1 y2
				lassign [my _evtype_colours $evtype] fill outline
				set id	[$w.c create rectangle $x $y1 [+ $x 6] $y2 \
						-fill $fill -width 1 -outline $outline]
				dict set ids $id $evtime
			}
			set repaint	0
		} else {
			dict for {id evtime} $ids {
				set x	[my _usec2x $evtime]
				$w.c moveto $id $x ""
			}
			set min_x	[my _usec2x $earliest_usec]
			set max_x	[my _usec2x $latest_usec]
			$w.c configure -scrollregion [list $min_x 0 $max_x $canv_height]
			set range	[- $latest_usec $earliest_usec]
			set a	[expr {($start_usec - $earliest_usec) / double($range)}]
			log debug "xview moveto $a"
			$w.c xview moveto $a
		}
	}

	#>>>
	method _usec2x {evtime} { #<<<
		/ [- $evtime $start_usec] $usec_per_pixel
	}

	#>>>
	method _source_ys {source} { #<<<
		my variable source_seq source_ys

		if {![dict exists $source_ys $source]} {
			set slot	$source_seq
			incr source_seq
			set base_y	[+ [* $slot 100] 5]
			dict set source_ys $source	[list $base_y [+ $base_y 80]]
		}

		dict get $source_ys $source
	}

	#>>>
	method _evtype_colours {evtype} { #<<<
		switch -- $evtype {
			m2.queue_msg	{list #70ff70 #00ff00}
			m2.receive_msg	{list #7070ff #0000ff}
			_connect		{list #ff3080 #ff0080}
			_disconnect		{list #ff3030 #ff0000}
			default			{list #707070 #202020}
		}
	}

	#>>>
}
