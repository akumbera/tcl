#!/usr/bin/tcl



proc readdir {{name .}} {
	set dirs [list]
	foreach subdir [glob -nocomplain -directory $name -type d *] {
		concat $dirs [readdir $subdir]
	}

	# Can do in at least Tcl 8.5. See aricb's post at http://wiki.tcl.tk/10390
	return $dirs
}
