
## Activity Log Project

A running / fitness log is evolving here.

The plan is to use directories of plain-text files to track activities,
with cross references to GPS files and other media (e.g. photos, web
URLs). Storing the files in a Dropbox directory will sync the ad hoc
database between systems.

Currently two interfaces are planned, (1) a Mac application for
browsing entries, running queries and more complex data analysis, and
(2) a suite of shell commands with a consistent git-like interface for
command-line use.

### Mac UI

![Screenshot](http://unfactored.org/images/act-screen-2014-01-14-1.png)
![Screenshot](http://unfactored.org/images/act-screen-2014-01-14-2.png)

### Command Line Interface

Basic command structure:

	$ act [--dir DIR] [--gps-dir DIR] [--exec-dir DIR] COMMAND ARGS...

The --dir and --gps-dir options are used to set ACT_DIR and ACT_GPS_DIR
environment variables if given. Each command is a separate program
called act-COMMAND. Some possible commands are:

	$ act new [--edit] [CREATION-OPTIONS...]

Creates a new activity file. If no --date option, defaults to current
time. (Date: is the only required header.) If --edit option is
specified launches editor on initial file.

	$ act import [--edit] [CREATION-OPTIONS...]

Finds new Garmin files and creates activities from them. (I.e. calls
"act new" with --gps-file option.)

	$ act set [--multiple] [CREATION-OPTIONS] [ACTIVITY-RANGE ...]

Uses the options to change the specified activity. If the spec selects
more than one activity exit with an error unless --multiple option was
given.

where CREATION-OPTIONS are any of:

		--date DATE
		--activity X
		--type X
		--course X
		--keywords X
		--equipment X
		--distance X
		--duration X
		--pace X
		--speed X
		--max-pace X
		--max-speed X
		--resting-hr X
		--average-hr X
		--max-hr X
		--calories X
		--weight X
		--temperature X
		--weather X
		--quality X
		--effort X
		--gps-file X
		--field NAME:X

For identifying activities we have ACTIVITY-RANGE, which is one of these
forms:

		DATE
		DATE-ABBREV             -- "today", "this-week", "last-week", etc

given a single item spec like this we can concatenate to form a range, e.g.

		DATE0..DATE1

note that underspecified dates already form a range, e.g. "2013-07" is
the entire month of July, and "12pm" is [12:00, 13:00). Combining two
dates to form a range does the obvious thing (min/max of endpoints).
Adding two ranges preserves the hole between them. If no spec is given,
the command operates on the most recent activity.

	$ act unset [--multiple] [FIELD-OPTIONS...] [ACTIVITY-RANGE ...]

Similar to set command, but removes fields.

	$ act sed [--multiple] [CREATION-OPTIONS...] [ACTIVITY-RANGE ...]

Similar to set command, but modifies fields. Value of each field option
is taken as a list of sed comannds.

	$ act edit [ACTIVITY-RANGE ...]

Runs $EDITOR on the specified file(s).

	$ act log [LOG-OPTIONS...] [ACTIVITY-RANGE ...]

Prints activities. The options allow the range of activities, and what
is printed to be controlled:

		--grep REGEXP             -- body regexp match
		--defines FIELD           -- if field is defined
		--matches FIELD:REGEXP    -- field regexp match
		--contains FIELD:KEYWORD  -- keyword field search
		--compare FIELDxKEYWORD   -- numeric comparison
		--query QUERY-EXP         -- complex query
		--format FORMAT-EXP       -- output format
		--table TABLE-EXP         -- tabular output format
		--max-count=N
		--skip=N

The 'x' in --compare is one of: "=", "!=", "<", ">", "<=", ">=".
QUERY-EXP is currently unimplemented, but would be things like:

		${distance} > 5 miles
		${duration} < 30:00
		${weather} CONTAINS cloudy AND ${temperature} > 20 C
		${body} MATCHES "tired"
		DEFINES ${avg-hr} AND ${avg-hr} < 150

i.e. an alternative infix syntax for the existing options.

FORMAT-EXP is the name of a format method (oneline, short, medium,
full, raw, path) or a custom format method: "format:STRING" where
STRING contains % escapes such as:

		%t                      -- TAB character
		%n                      -- newline character
		%%                      -- literal percent character
		%XX                     -- hex character
		%{FIELD}                -- field value
		%{FIELD:ARGS}
		%[FIELD]                -- field "name: value"
		%[FIELD:ARGS]

special %{FIELD} strings include:

		%{date:STRFTIME-FORMAT}
		%{body}
		%{body:first-line}
		%{body:first-para}

special %[FIELD] strings include:

		%[header]               -- all header fields
		%[body]                 -- complete body string
		%[laps]                 -- tabulated laps from GPS file

TABLE-EXP is similar but inserts extra space between fields to tabulate
the output.

	$ act show [LOG-OPTIONS...] [ACTIVITY-RANGE ...]

Prints one activity, with pretty-print options.

	$ act cat [ACTIVITY-RANGE ...]

Prints unformatted activity files.

	$ act locate [ACTIVITY-RANGE ...]

Prints file names for all specified activities.

	$ act fold [FOLD-OPTIONS...] [ACTIVITY-RANGE...]

Summarizes a range of activities. E.g. prints weekly mileage for the
past year. FOLD-OPTIONS would include:

		--interval=INTERVAL
		--field=FIELD[:BUCKET-SIZE]
		--course                --field=course
		--keywords=FIELD
		--equipment             --keywords=equipment
		--format=FORMAT

and INTERVAL is one of:

		day
		week
		month
		year
		N day[s]
		N week[s]
		N month[s]
		N year[s]

Operation is identify sets of activies, either date ranges, field
string matches or histograms of numeric fields, then combine those
records (sum distance, time, etc) and log the results.

	$ act daily [FOLD-OPTIONS] [ACTIVITY-RANGE...]

Alias for "fold --interval=day ..."

	$ act weekly [FOLD-OPTIONS] [ACTIVITY-RANGE...]

Alias for "fold --interval=week ..."

	$ act monthly [FOLD-OPTIONS] [ACTIVITY-RANGE...]

Alias for "fold --interval=month ..."

	$ act yearly [FOLD-OPTIONS] [ACTIVITY-RANGE...]

Alias for "fold --interval=year ..."

	$ act rm [ACTIVITY-RANGE ...]

Deletes specified activities. Note that this is a "soft" deletion,
either by adding a "Deleted: YES" header to the file, or by moving it
to a trash directory.

	$ act unrm [ACTIVITY-RANGE ...]

Clears the deleted state.

	$ act gc

Removes any deleted activities, and does any other cleanup that might
be needed.
