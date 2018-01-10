#!bin/sh
#
# Build visual studio solution using msbuild32
#

_say() {
    echo "$@" >&2
}
 
_die() {
    say "$2"
    exit "$1"
}

function _arg_echo(){
	echo "Solution Path: $1" 
	echo "Logs Path: $2" 
}

function _file_check(){
	if [ ! -f $1 ]; 
	then
		touch $1
		echo '	No. Logs file created at '$1
	else
		echo '	Yes. Log file overwritten at '$1
	fi
}

function _select_errors() {
	tail -n 5 $1
}

function _help(){
	echo "
build_vs path_to_solution (output_path)

First argument: path to solution i.e. /C/Dev/MySolution.sln
Second argument (optional): alternative output path"
	    exit 0
}

function build-vs(){
	_arg_echo "$@"
	if [ -z "$1" ] || [ "$1" == "--help" ] || [ "$1" == "-h" ];
	then
		_help
	fi

	if [ ! -f $1 ]; then
	   _die 1 "File \"$FILE\" does not exist."
	fi
	if [ -z ${2+x} ]; then 
		msbuild32 $1
		echo "No log file path given"
		return
	else 
		echo 'Does logs file exist?'
		_file_check $2
		echo 'Building with msbuild32...'
		msbuild32 $1 > $2
		echo 'Tail of output:'
		_select_errors $2
		return
	fi
}


