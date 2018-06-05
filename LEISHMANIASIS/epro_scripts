#
# Build scripts for epro and epro everything solutions
#

LOGS_PATH=~/logs/dev/epro/
FILE_PATH_BUILD_OUTPUT_EPRO_EVERYTHING=${LOGS_PATH}last_epro_build_all_output.txt
FILE_PATH_BUILD_OUTPUT_EPRO_SPEECH=${LOGS_PATH}last_epro_build_speech_output.txt
FILE_PATH_BUILD_OUTPUT_EPRO_DICTATION=${LOGS_PATH}last_epro_build_dictation_output.txt
FILE_PATH_BUILD_OUTPUT_EPRO_METAPARSER=${LOGS_PATH}last_epro_build_metaparser_output.txt
FILE_PATH_BUILD_OUTPUT_EPRO_FILEDROP=${LOGS_PATH}last_epro_build_filedrop_output.txt
FILE_PATH_BUILD_OUTPUT_EPRO=${LOGS_PATH}last_epro_build_output.txt

function epro-trans() {
	epro-build-dictation
	epro-build-speech
	epro-dictation
	epro-speech
}

function epro-full() {
	epropat reset
	epro-build
	epro-build-dictation
	epro-build-speech
	epro-dictation
	epro-speech
	vs
}

function epro-build() {
	build-vs /c/Dev/epro/Epro.sln $FILE_PATH_BUILD_OUTPUT_EPRO
}

function epro-build-everything() {
	build-vs /c/Dev/epro/Everything.sln $FILE_PATH_BUILD_OUTPUT_EPRO_EVERYTHING 
}

function epro-build-dictation() {
	build-vs /c/Dev/epro/Bluewire.Dictation.sln $FILE_PATH_BUILD_OUTPUT_EPRO_DICTATION 
}

function epro-build-metaparser() {
	build-vs /c/Dev/epro-metaparser/Bluewire.MetaParser.sln $FILE_PATH_BUILD_OUTPUT_EPRO_METAPARSER 
}

function epro-build-speech() {
	build-vs /c/Dev/epro/Bluewire.Speech.sln $FILE_PATH_BUILD_OUTPUT_EPRO_SPEECH 
}

function epro-build-filedrop() {
	build-vs /c/Dev/epro-filedrop/Bluewire.FileDrop.sln $FILE_PATH_BUILD_OUTPUT_EPRO_METAPARSER 
}

function epro-build-logs() {
	cd LOGS_PATH
}

function epro-servers(){
	CURRENT_WD=$(PWD)
	cd '/C/Dev/epro'
	## ./ used to run via cmd.exe
	./RUN_EPRO_SERVERS.bat

	cd $CURRENT_WD
}