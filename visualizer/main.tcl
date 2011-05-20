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
		strips
	}

	constructor {args} { #<<<
		set repaint		1
		set ids			[dict create]

		next {*}$args

		namespace path [concat [namespace path] {
			::tcl::mathop
		}]

		array set dominos {}
		sop::domino new dominos(redraw) -name redraw

		canvas $w.l -borderwidth 1 -relief sunken -background #b1b1b1 \
				-width 100p -highlightthickness 0
		$w.l xview moveto 0
		$w.l yview moveto 0
		canvas $w.c -borderwidth 1 -relief sunken -background #d0d0d0 \
				-xscrollcommand [list $w.hsb set] -highlightthickness 0
		$w.c xview moveto 0
		$w.c yview moveto 0
		ttk::scrollbar $w.hsb -orient horizontal -command [list $w.c xview]
		ttk::scale $w.zoom -orient horizontal -variable [scope usec_per_pixel] \
				-command [list $dominos(redraw) tip]

		ttk::label $w.status

		my refresh

		table $w -padx 0 -pady 0 \
				$w.l		1,1 -fill both \
				$w.c		1,2 -fill both \
				$w.hsb		2,2 -fill x \
				$w.zoom		3,2 -fill x \
				$w.status	4,1 -cspan 2 -fill x
		table configure $w c1 r2 r3 r4 -resize none

		$dominos(redraw) attach_output [code _redraw]

		bind $w.c <Configure>		[code _recalc_zoom %w %h]
		bind $w.c <ButtonPress-4>	[code _zoom_in %x]
		bind $w.c <ButtonPress-5>	[code _zoom_out %x]
		bind $w.c <ButtonPress-3>	[list coroutine ::coro_drag {*}[code _start_drag] %x]
		bind $w.c <ButtonPress-1>	[list coroutine ::coro_drag {*}[code _start_left_drag] %x %y]

		set screenwidth	[winfo screenwidth $w]
		my configure \
				-geometry	"[- $screenwidth 5]x512"
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

		set strips	[dict create]
		set source_seq	0
		db eval {
			select
				source			as source,
				min(evtime)		as source_start_usec,
				max(evtime)		as source_end_usec
			from
				events
			group by
				source
			order by
				min(evtime) asc
		} {
			set slot	$source_seq
			incr source_seq
			set base_y	[+ [* $slot 90] 5]
			dict set strips $source [dict create \
					start_usec	$source_start_usec \
					end_usec	$source_end_usec \
					ys			[list $base_y [+ $base_y 80]]
			]
			log debug "Set strip ($source) ys: [dict get $strips $source ys]"
		}

		if {[info exists canv_width]} {
			$dominos(redraw) tip
		}
	}

	#>>>
	method _start_drag {x} { #<<<
		set last_x	$x
		bind $w.c <Motion> [list apply {
			{coro x} {
				$coro [list motion $x]
			}
		} [info coroutine] %x]
		bind $w.c <ButtonRelease-3> [list [info coroutine] dragstop]

		while {1} {
			set rest	[lassign [yield] wakeup_reason]
			switch -- $wakeup_reason {
				motion {
					lassign $rest new_x
					set delta	[- $last_x $new_x]
					set last_x	$new_x
					set delta_usec	[* $delta $usec_per_pixel]
					lassign [$w.c xview] a b
					set range			[- $latest_usec $earliest_usec]
					set left_usec		[expr {$earliest_usec + $range * $a}]
					set new_left_usec	[+ $left_usec $delta_usec]
					$w.c xview moveto	[/ [- $new_left_usec $earliest_usec] $range]
				}

				dragstop {
					break
				}

				default {
					log error "Unexpected wakeup reason: \"$wakeup_reason\""
				}
			}
		}

		bind $w.c <Motion> {}
		bind $w.c <ButtonRelease-3> {}
	}

	#>>>
	method _start_left_drag {x y} { #<<<
		set last_x	$x
		bind $w.c <Motion> [list apply {
			{coro x y} {
				$coro [list motion $x $y]
			}
		} [info coroutine] %x %y]
		bind $w.c <ButtonRelease-1> [list [info coroutine] dragstop]

		set draghandler	[my _get_draghandler]
		{*}$draghandler start_drag $x $y

		while {1} {
			set rest	[lassign [yield] wakeup_reason]
			switch -- $wakeup_reason {
				motion {
					lassign $rest new_x new_y
					#set delta	[- $last_x $new_x]
					#set last_x	$new_x
					#set delta_usec	[* $delta $usec_per_pixel]
					#lassign [$w.c xview] a b
					#set range			[- $latest_usec $earliest_usec]
					#set left_usec		[expr {$earliest_usec + $range * $a}]
					#set new_left_usec	[+ $left_usec $delta_usec]
					#$w.c xview moveto	[/ [- $new_left_usec $earliest_usec] $range]
					set x	$new_x
					set y	$new_y
					{*}$draghandler update_drag $x $y
				}

				dragstop {
					{*}$draghandler stop_drag $x $y
					break
				}

				default {
					log error "Unexpected wakeup reason: \"$wakeup_reason\""
				}
			}
		}

		bind $w.c <Motion> {}
		bind $w.c <ButtonRelease-1> {}
	}

	#>>>
	method _get_draghandler {} { #<<<
		# Debug
		list apply {
			{coro op x y} {$coro [list $op $x $y]}
		} [coroutine coro_drag_[incr ::coro_seq] apply {
			{w height} {
				while {1} {
					lassign [yield [info coroutine]] op x y
					switch -- $op {
						start_drag {
							set x1 $x
							set id	[$w.c create rectangle $x1 0 $x1 $height \
									-fill #ffecec -width 1 -outline #f9b1b1]
							$w.c raise $id strip_bg
						}

						update_drag {
							set x2 $x
							$w.c coords $id $x1 0 $x2 $height
							lassign [lsort -integer [list $x1 $x2]] from_x to_x
							set from_usec	[.main x2usec $from_x]
							set to_usec		[.main x2usec $to_x]
							$w.status configure -text [format "Range: %.2f usec: %.5f ms - %.5f ms" [expr {$to_usec - $from_usec}] [expr {$from_usec/1000.0}] [expr {$to_usec/1000.0}]]
						}

						stop_drag {
							set x2 $x
							$w.c delete $id
							$w.status configure -text ""
							break
						}

						default {
							log error "Unexpected drag update: \"$op\""
						}
					}
				}
			}
		} $w [my canvas_height]]
	}

	#>>>
	method _zoom_in {{x ""}} { #<<<
		my _zoom_fact $x 1.1
	}

	#>>>
	method _zoom_out {{x ""}} { #<<<
		my _zoom_fact $x 0.9
	}

	#>>>
	method _zoom_fact {x fact} { #<<<
		if {$x eq ""} {
			set x	[/ $canv_width 2]
		}
		if {![info exists usec_per_pixel]} {
			set old		0
		} else {
			set old		$usec_per_pixel
		}
		set old_window_range 	[* $canv_width $usec_per_pixel]
		set usec_per_pixel	[expr {$usec_per_pixel * (1.0 / $fact)}]

		set time_range_usec		[- $latest_usec $earliest_usec]
		set max_usec_per_pixel	[expr {$time_range_usec / double($canv_width)}]
		set min_usec_per_pixel	[cfg get min_usec_per_pixel]

		if {![info exists usec_per_pixel]} {
			set usec_per_pixel	$max_usec_per_pixel
		} elseif {$usec_per_pixel > $max_usec_per_pixel} {
			set usec_per_pixel	$max_usec_per_pixel
		} elseif {$usec_per_pixel < $min_usec_per_pixel} {
			set usec_per_pixel	$min_usec_per_pixel
		}

		if {$usec_per_pixel == $old} return

		set xf		[expr {$x / double($canv_width)}]
		lassign [$w.c xview] a b
		set range		[- $latest_usec $earliest_usec]
		set left_usec	[expr {$earliest_usec + $range * $a}]
		set right_usec	[expr {$earliest_usec + $range * $b}]
		set fixed_usec	[expr {$left_usec + $old_window_range * $xf}]

		set new_window_usec_range	[* $canv_width $usec_per_pixel]
		set new_left_usec	[expr {$fixed_usec - $new_window_usec_range * $xf}]
		set new_right_usec	[expr {$fixed_usec + $new_window_usec_range * (1.0 - $xf)}]
		set centre_usec		[expr {($new_left_usec + $new_right_usec) / 2}]

		$dominos(redraw) tip
	}

	#>>>
	method _recalc_zoom {width height} { #<<<
		# -2 for the window relief border
		set canv_width	[- $width 2]
		set canv_height	[- $height 2]

		set time_range_usec		[- $latest_usec $earliest_usec]
		set max_usec_per_pixel	[expr {$time_range_usec / double($width)}]
		set min_usec_per_pixel	[cfg get min_usec_per_pixel]

		$w.zoom configure -from $max_usec_per_pixel -to $min_usec_per_pixel

		if {![info exists usec_per_pixel]} {
			set usec_per_pixel	$max_usec_per_pixel
		} elseif {$usec_per_pixel > $max_usec_per_pixel} {
			set usec_per_pixel	$max_usec_per_pixel
		} elseif {$usec_per_pixel < $min_usec_per_pixel} {
			set usec_per_pixel	$min_usec_per_pixel
		}
		lassign [$w.c xview] a b
		set range		[- $latest_usec $earliest_usec]
		set left_usec	[expr {$earliest_usec + $range * $a}]
		set right_usec	[expr {$earliest_usec + $range * $b}]
		set centre_usec	[/ [+ $left_usec $right_usec] 2]
		log debug "a: ($a) b: ($b)"
		$dominos(redraw) tip
	}

	#>>>
	method _redraw {} { #<<<
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
			$w.l delete all
			$w.c delete all
			# -2 for the window relief border
			set legend_width	[- [winfo reqwidth $w.l] 2]
			dict for {source info} $strips {
				set x1	[- [my _usec2x [dict get $info start_usec]] 2]
				set x2	[+ [my _usec2x [dict get $info end_usec]] 8]
				lassign [dict get $info ys] y1 y2
				set id	[$w.c create rectangle \
						[- [my _usec2x $earliest_usec] 1] $y1 \
						[+ [my _usec2x $latest_usec] 1] $y2 \
						-fill "" -outline #acacac -width 1 \
						-tags [list source $source]]
				dict set strips $source strip_track $id

				set id	[$w.c create rectangle $x1 $y1 $x2 $y2 \
						-fill white -outline black -width 1 \
						-tags [list source_$source strip_bg]]
				dict set strips $source strip_bg $id

				set id	[$w.l create rectangle 4 $y1 [- $legend_width 4] $y2 \
						-outline #7993ac -fill #cadbec \
						-tags [list source_$source]]
				dict set strips $source legend_bg $id

				set label_left	[+ 4 5]
				$w.l create text $label_left [+ $y1 3] -anchor nw \
						-text $source -justify left \
						-width [- $legend_width $label_left 4 5] \
						-fill black -tags [list source_$source]
			}

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
				lassign [my fqname_split $evtype] t1 t2
				set x	[my _usec2x $evtime]
				lassign [dict get $strips $source ys] y1 y2
				lassign [plugin $t1 evtype_colours $t2] fill outline
				dict set ids [plugin $t1 draw_marker $source $evtime $t2 $w.c \
						$x [+ $y1 4] [- $y2 4] \
						-fill $fill -width 1 -outline $outline \
						-tags [list $source]] $evtime
				dict set ids $id $evtime
			}
			foreach plugin $::plugins {
				plugin $plugin draw_overlay $w.c $start_usec $usec_per_pixel
			}
			set repaint	0
		} else {
			dict for {id evtime} $ids {
				set x	[my _usec2x $evtime]
				$w.c moveto $id $x ""
			}
			set min_x	[my _usec2x $earliest_usec]
			set max_x	[my _usec2x $latest_usec]
			dict for {source info} $strips {
				set x1	[- [my _usec2x [dict get $info start_usec]] 2]
				set x2	[+ [my _usec2x [dict get $info end_usec]] 8]
				lassign [dict get $info ys] y1 y2
				$w.c coords [dict get $info strip_track] \
						[- $min_x 1] $y1 [+ $max_x 1] $y2
				$w.c coords [dict get $info strip_bg] $x1 $y1 $x2 $y2
			}
			foreach plugin $::plugins {
				plugin $plugin adjust_overlay $w.c $start_usec $usec_per_pixel
			}
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
	method x2usec {x} { #<<<
		- [+ $start_usec [* $x $usec_per_pixel]] $earliest_usec
	}

	#>>>
	method fqname_split {name} { #<<<
		set idx	[string first . $name]
		if {$idx == -1} {
			if {[string index $name 0] eq "_"} {
				list _system $name
			} else {
				list $name $name
			}
		} else {
			list [string range $name 0 [- $idx 1]] [string range $name [+ $idx 1] end]
		}
	}

	#>>>
	method source_ys {source} { #<<<
		dict get $strips $source ys
	}

	#>>>
	method canvas_height {} { #<<<
		#winfo reqheight $w.c
		set canv_height
	}

	#>>>
}
