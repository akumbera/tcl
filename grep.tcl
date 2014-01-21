#!/usr/bin/tcl



source ~/bin/readdir.tcl



proc grep_recognize_options {arg} {
	# Execute in the context of grep so we can modify the same variables 
	# NOTE: The arg variable is passed in as a formal argument, so we do not 
	#       rely on upvar'ing it. Doing so makes this proc infinitely recurse.
	upvar grep_flags           grep_flags
	upvar regexp_flags         regexp_flags
	upvar line_numbers         line_numbers
	upvar invert_matches       invert_matches
	upvar count_only           count_only
	upvar suppress_blank_lines suppress_blank_lines
	upvar return_list          return_list

	switch -- $arg \
		{-i} {
			set regexp_flags "$regexp_flags -nocase"
			set grep_flags "$grep_flags -i"
		} \
		{-list} {
			set return_list 1
			set grep_flags "$grep_flags -m"
		} \
		{-m} {
			set count_only 1
			set grep_flags "$grep_flags -m"
		} \
		{-n} {
			set line_numbers 1
			set grep_flags "$grep_flags -n"
		} \
		{-r} {
			set suppress_blank_lines 1
			set grep_flags "$grep_flags -s"
		} \
		{-v} {
			set invert_matches 1
			set grep_flags "$grep_flags -v"
		} \
		{-h} {
			#     |<-- 80th character here                                                   -->|
			puts "grep <OPTIONS> [REGEX] [FILE/S|DIRECTORY/IES]"
			puts "  A quick emulation of GNU grep in Tcl, with some notable changes and "
			puts "  additions."
			puts ""
			puts "USAGE EXAMPLES"
			puts "  grep vdd|vss dir/example1.txt         \# Perform a search for \"vdd\" or"
			puts "                                        \# \"vss\" in the dir/example1.txt file"
			puts "  grep -i vdd|vss dir/example2.txt      \# Perform a case-insensitive search"
			puts "                                        \# for \"vdd\" or \"vss\" in the"
			puts "                                        \# dir/example2.txt file"
			puts "  grep -vi vdd|vss dir/example3.txt     \# Perform a case-insensitive search"
			puts "                                        \# for lines that do NOT contain \"vdd\""
			puts "                                        \# or \"vss\" in the file"
			puts "  grep -v -i vdd|vss dir/example4.txt   \# Same as above."
			puts "  grep -vsm vdd dir/example5.txt        \# Perform a search for lines that do"
			puts "                                        \# NOT contain \"vdd\" in the"
			puts "                                        \# dir/example5.txt file"
			puts ""
			puts "OPTIONS"
			puts "  -h     Print this help and exit"
			puts "  -i     Turn off case sensitivity for the regex"
			puts "  -list  Return the results in the form of a Tcl list. If there is more than "
			puts "         one file to be searched or if the -n option is specified then each "
			puts "         list element is itself a list of the metadata and the matched line."
			puts "  -m     Report only the count of matching lines"
			puts "  -n     Report line numbers on each line"
			puts "  -r     Recursively scan directories (default)"
			puts "  -s     Suppress blank lines"
			puts "  -v     Invert match criteria"
			puts ""
			puts "DIFFERENCES FROM GNU GREP"  ;# Grammatically correct?
			puts "  * The -list option returns a Tcl-formatted list"
			puts "  * The regex is parsed by Tcl's regexp parser"
			puts "  * The -r option is always turned on, and directories are always recursively "
			puts "    scanned and contained files are scanned"
			puts "  * The -s option is used to suppress blank lines (because piping in Tcl is "
			puts "    nonexistent and painful if it does exist)"
			return
		} \
		default {
			# If the argument starts with a dash, has multiple characters, and 
			# isn't recognized, then pull it apart and put each character 
			# through the recognizer. If the argument has a dash or only has 
			# one character (after the dash), then report it and ignore it.
			# NOTE: This check is intended to prevent infinite recursion on 
			#       unrecognized or copmlex options.
			if {[regexp {^-[^-\s]{2,}$} $arg]} {
				# Chop off the preceding dash
				set complex_args [regsub {^-} $arg ""]
				# Loop through each character
				for {set i 0} {$i < [string length $complex_args]} {incr i} {
					# Grab the character in the argument
					set arg_char [string index $complex_args $i]
					# Add a dash to the argument character
					set complex_arg "-${arg_char}"

					#puts -nonewline "complex_arg: '"
					#puts -nonewline $complex_arg
					#puts """

					# Send the new argument through the recognizer
					# NOTE: This works because the child grep_recognize_options
					#       will execute in the context of the current (parent)
					#       grep_recognize_options, which is executing in the 
					#       same context as the original caller (grep).
					grep_recognize_options $complex_arg
				}
			} {
				puts "ERROR: Unknown option '$arg'. Ignoring."
			}
		}

	# Nothing to return because we're executing in the same context as the 
	# caller
}



proc grep {args} {
	# NOTE: If you add or remove any of these variables for option processing, 
	#       make sure you add or remove them to the grep_recognize_options proc
	#       as well, as it uses upvar to reference these variables directly!
	set grep_flags ""
	set regexp_flags ""
	set line_numbers 0
	set invert_matches 0
	set count_only 0
	set suppress_blank_lines 0
	set return_list 0

	set match_count 0
	set files ""
	set matching_lines ""

	# Process the arguments
	foreach arg $args {
		# If an argument doesn't start with a dash then it is the regex we need
		if [regexp -- "^\[^-\]" $arg] {
			if {![info exists re]} {
				set re $arg
			} {
				set files "$files $arg"
			}
		} {
			grep_recognize_options $arg
		}
	}

	foreach file $files {
		set line_num 0
		# If the file is a directory, then read the directory and rerun grep on
		# the returned results
		if [file isdirectory $file] {
			array set newfiles [readdir $file]
			#foreach newfile $newfiles {
			#	concat $matching_lines [grep $grep_flags $newfile]
			#}
			if {$count_only == 1} {
				set match_count [expr $match_count + [grep $grep_flags $newfiles]]
			} {
				concat $matching_lines [grep $grep_flags $newfiles]
			}
		} {
			# NOTE: Putting this check here makes the code slightly faster, but
			#       also makes the two regexp kernels of the script further 
			#       apart, so consider this when editing either fork of the if 
			#       statement.
			if {$invert_matches == 1} {
				set fp [open $file]
				while {[gets $fp line] >= 0} {
					set line_num [expr $line_num + 1]
					# Skip reporting blank lines if we're supposed to suppress them
					if {$suppress_blank_lines == 1 && [eval regexp {^\s*$} {$line}]} {
						continue
					}
					# WARNING: Be __EXTREMELY__ careful if/when you edit the
					#          regexp line, as it breaks very easily because
					#          Tcl seems to have a vendetta against standard
					#          libraries and general usefulness.
					# NOTE: Consider if the changes to the regexp lines will
					#       need to be reflected in the regexp line for the 
					#       non-inverted match case
					# EXPLANATION:
					#  * The surrounding {} prevents the if statement from
					#    evaluating the contained expression directly.
					#  * The expr command properly evalutes the boolean 
					#    inversion of the contained logic.
					#  * The eval command interpolates $regexp_flags for 
					#    consumption for the regexp command.
					#  * The {} around the $re and the $line prevent the eval
					#    command from interpolating those variables before they
					#    are consumed by the regexp command. We do not want Tcl
					#    to interpret the *value* of $line before running the 
					#    regexp command.
					if {[expr ![eval regexp $regexp_flags {$re} {$line}]]} {
						#if {[llength $files] > 1} {puts -nonewline $file:}
						#if {$line_numbers == 1} {puts -nonewline $line_num:}
						#puts $line
						if {$return_list} {
							if {[llength $files] > 1 || $line_numbers == 1} {
								set match_line [list]
								if {[llength $files] > 1} {lappend match_line $file}
								if {$line_numbers == 1} {lappend match_line $line_num}
								lappend match_line $line
							} {
								set match_line $line
							}
							set match_count [expr $match_count + 1]
							lappend matching_lines $match_line
						} {
							set match_line ""
							if {[llength $files] > 1} {set match_line "${match_line}${file}:"}
							if {$line_numbers == 1} {set match_line "${match_line}${line_num}:"}
							set match_line "${match_line}${line}\n"
							#puts -nonewline "match_line: "
							#puts $match_line
							set match_count [expr $match_count + 1]
							set matching_lines "${matching_lines}${match_line}"
						}
					}
				}
				close $fp
			} {
				set fp [open $file]
				while {[gets $fp line] >= 0} {
					set line_num [expr $line_num + 1]
					# Skip reporting blank lines if we're supposed to suppress them
					if {$suppress_blank_lines == 1 && [eval regexp {^\s*$} {$line}]} {
						continue
					}
					# WARNING: Be __EXTREMELY__ careful if/when you edit the
					#          regexp line, as it breaks very easily because
					#          Tcl seems to have a vendetta against standard
					#          libraries and general usefulness.
					# NOTE: Consider if the changes to the regexp_line will 
					#       need to be reflected in the regexp line for the 
					#       non-inverted match case.
					# EXPLANATION:
					#  * The surrounding {} prevents the if statement from
					#    evaluating the contained expression directly.
					#  * The eval command interpolates $regexp_flags for 
					#    consumption for the regexp command.
					#  * The {} around the $re and the $line prevent the eval 
					#    command from interpolating those variables before they
					#    are consumed by the regexp command. We do not want Tcl
					#    to interpret the *value* of $line before running the
					#    regexp command.
					if {[eval regexp $regexp_flags {$re} {$line}]} {
						#if {[llength $files] > 1} {puts -nonewline $file:}
						#if {$line_numbers == 1} {puts -nonewline $line_num:}
						#puts $line
						if {$return_list} {
							{[llength $files] > 1 || $line_numbers == 1} {
								set match_line [list]
								if {[llength $files] > 1} {lappend match_line $file}
								if {$line_numbers == 1} {lappend match_line $line_num}
								lappend match_line $line
							} {
								set match_line $line
							}
							set match_count [expr $match_count + 1]
							lappend matching_lines $match_line
						} {
							set match_line ""
							if {[llength $files] > 1} {set match_line "${match_line}${file}:"}
							if {$line_numbers == 1} {set match_line "${match_line}${line_num}:"}
							set match_line "${match_line}${line}\n"
							#puts -nonewline "match_line: "
							#puts $match_line
							set match_count [expr $match_count + 1]
							set matching_lines "${matching_lines}${match_line}"
						}
					}
				}
				close $fp
			}
		}
	}

	if {$count_only == 1} {
		return $match_count
	} {
		return $matching_lines
	}
}
