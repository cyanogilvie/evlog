# vim: ft=tcl foldmethod=marker foldmarker=<<<,>>> ts=4 shiftwidth=4

Plugin m2 {
	variable {*}{
		conversations
		arrows
	}

	constructor {} { #<<<
		set conversations	[dict create]
		set arrows			[dict create]

		package require hash
		if {[self next] ne ""} next

		db function m2_msg_hash {apply {
			{in} {
				hash::md5 [dict get $in msg svc][dict get $in msg type][dict get $in msg seq][dict get $in msg prev_seq][dict get $in msg meta][dict get $in msg data]
			}
		}}
	}

	#>>>
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
		my variable rows
		set rows	{}
		set infowin	[next $c $source $evtime $evtype]
		set details	[my _evdetails $source $evtime $evtype]
		if {$evtype eq "queue_msg"} {
			set remote	"to [dict get $details to]"
		} elseif {$evtype eq "receive_msg"} {
			set remote	"from [dict get $details from]"
		} else {
			set remote	"unknown"
		}
		#set bg	[$infowin cget -background]
		#message $infowin.l -background $bg -text [format "%s %s %s" \
		#		$remote [dict get $details msg type] \
		#		[dict get $details msg seq]] \
		#		-justify left -width 400
		#pack $infowin.l -fill both -expand true
		set msg	[dict get $details msg]
		set i	$infowin
		$i configure -highlightthickness 1 \
				-highlightbackground #aeaeae \
				-highlightcolor #aeaeae
		canvas $i.c -background white -width 100 -height 100 \
				-highlightthickness 0 -borderwidth 0
		bind $i.c <Configure> [code _adjust_infowin_items %W %w %h]

		if {$evtype eq "receive_msg"} {
			set headingfill		#537dde
			set headingcolour	white
		} else {
			set headingfill		#9ff675
			set headingcolour	black
		}
		$i.c create rectangle 0 0 10 25 -fill $headingfill \
				-tags {fillx headingbg} -width 0
		$i.c create text 4 4 -anchor nw -justify left -tags {wrapx heading} \
				-text $remote -fill $headingcolour
		foreach attr {svc type seq prev_seq meta oob_type oob_data data} {
			set ids	{}
			lappend ids	[$i.c create text 5 0 -anchor nw -justify left \
					-width 70 -text $attr -fill black]
			if {$attr eq "data"} {
				if {[dict get $msg type] in {
					svc_avail
					svc_revoke
					nack
					neighbour_info
				} || [dict get $msg svc] in {
					sys
				} || [string length [dict get $msg data]] == 0} {
					set valtext	[dict get $msg $attr]
				} else {
					set valtext	"[binary encode base64 [hash::md5 [dict get $msg $attr]]] \[[string length [dict get $msg $attr]]\]"
				}
			} else {
				set valtext	[dict get $msg $attr]
			}
			lappend ids [$i.c create text 75 0 -anchor nw -justify left \
					-tags {wrapx2} -text $valtext -fill black]
			lappend rows $ids
		}

		lassign [$i.c bbox all] x1 - x2
		set neww	[expr {max(200, min(400, $x2 - $x1 + 8))}]
		log debug "neww: $neww"
		$i.c configure -width $neww

		pack $i.c -fill both -expand true

		set infowin
	}

	#>>>
	method _adjust_infowin_items {c w h} { #<<<
		my variable rows ignore
		if {[info exists ignore]} {
			unset ignore
			return
		}

		$c delete zebrastripes
		foreach id [$c find withtag fillx] {
			$c coords $id [lreplace [$c coords $id] 2 2 $w]
		}
		foreach id [$c find withtag wrapx] {
			lassign [$c coords $id] x y
			$c itemconfigure $id -width [- $w [* $x 2]]
		}
		foreach id [$c find withtag wrapx2] {
			lassign [$c coords $id] x y
			$c itemconfigure $id -width [- $w 4]
		}
		lassign [$c bbox heading] x1 y1 x2 y2
		$c coords headingbg [lreplace [$c coords headingbg] 3 3 [+ $y2 4]]
		set pen_y	[+ $y2 4]
		set stripes	{}
		foreach row $rows {
			foreach id $row	{
				$c moveto $id "" [+ $pen_y 2]
			}
			lappend stripes $pen_y
			set pen_y	[+ [lindex [$c bbox {*}$row] 3] 4]
			lappend stripes $pen_y
		}
		set newh	[+ [lindex [$c bbox all] 3] 3]
		set stripeseq	0
		foreach {y1 y2} $stripes {
			if {[incr stripeseq] % 2} {
				set bg_dark		#c1c2c3
				set bg_light	#e1e1e1
			} else {
				set bg_dark		#d9d9d9
				set bg_light	#f4f4f4
			}
			$c create rectangle 0 $y1 72 $y2 -fill $bg_dark -width 0 -tags zebrastripes
			$c create rectangle 72 $y1 $w $y2 -fill $bg_light -width 0 -tags zebrastripes
		}
		$c lower zebrastripes
		set ignore	1
		$c configure -height $newh
	}

	#>>>
	method draw_overlay {c start_usec usec_per_pixel} { #<<<
		set before	[clock microseconds]
		db eval {
			select
				source					as source,
				evtime					as evtime,
				evtype					as evtype,
				m2_msg_hash(details)	as hash
			from
				events
			where
				evtype = 'm2.queue_msg' or evtype = 'm2.receive_msg'
			order by
				evtime asc
		} {
			if {[dict exists $conversations $hash $evtype]} {
				log warning "Already saw a $evtype for [binary encode base64 $hash]"
				set existing	[dict get $conversations $hash $evtype]
			} else {
				set existing	[list]
			}
			lappend existing	[dict create \
					source	$source \
					evtime	$evtime \
			]
			dict set conversations $hash $evtype $existing
		}
		log debug [format "found %d conversations in %.3f ms" \
				[dict size $conversations] \
				[expr {([clock microseconds] - $before) / 1000.0}]
		]
		set map	[dict create \
			m2.queue_msg	froms \
			m2.receive_msg	tos \
		]
		dict for {hash messages} $conversations {
			set froms	{}
			set tos		{}
			dict for {evtype events} $messages {
				foreach event $events {
					lappend [dict get $map $evtype] \
							[dict get $event evtime] [dict get $event source]
				}
			}

			#if {[llength $froms] == 0 || [llength $tos] == 0} {
			#	log warning "Conversation [binary encode base64 $hash] froms\[[/ [llength $froms] 2]\], tos\[[/ [llength $tos] 2]\]"
			#} else {
			#	log debug "Conversation [binary encode base64 $hash] froms\[[/ [llength $froms] 2]\], tos\[[/ [llength $tos] 2]\]"
			#}
			foreach {u1 s1} $froms {
				set x1	[expr {double($u1 - $start_usec) / $usec_per_pixel + 6}]
				set y1	[my _source_y $s1]
				foreach {u2 s2} $tos {
					set x2	[expr {double($u2 - $start_usec) / $usec_per_pixel + 6}]
					set y2	[my _source_y $s2]
					#log debug "Drawing line from ($x1, $y1) \"$s1\" to ($x2, $y2) \"$s2\""
					set id	[$c create line $x1 $y1 $x2 $y2 \
							-width 1 -arrow last -fill black]
					dict set arrows $id [list $u1 $s1 $u2 $s2]
				}
			}
		}
	}

	#>>>
	method adjust_overlay {c start_usec usec_per_pixel} { #<<<
		dict for {id coords} $arrows {
			lassign $coords u1 s1 u2 s2
			set x1	[expr {double($u1 - $start_usec) / $usec_per_pixel + 6}]
			set y1	[my _source_y $s1]
			set x2	[expr {double($u2 - $start_usec) / $usec_per_pixel + 6}]
			set y2	[my _source_y $s2]
			$c coords $id $x1 $y1 $x2 $y2
		}
	}

	#>>>
	method _source_y {source} { #<<<
		/ [+ {*}[.main source_ys $source]] 2.0
	}

	#>>>
}
