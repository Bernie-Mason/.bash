#
# Build scripts for epro and epro everything solutions
#

LOGS_PATH=~/logs/dev/epro/
FILE_PATH_BUILD_OUTPUT_EPRO_EVERYTHING=${LOGS_PATH}last_epro_build_all_output.txt
FILE_PATH_BUILD_OUTPUT_EPRO_SPEECH=${LOGS_PATH}last_epro_build_speech_output.txt
FILE_PATH_BUILD_OUTPUT_EPRO_METAPARSER=${LOGS_PATH}last_epro_build_metaparser_output.txt
FILE_PATH_BUILD_OUTPUT_EPRO=${LOGS_PATH}last_epro_build_output.txt

function epro-build() {
	build-vs /c/Dev/epro/Epro.sln $FILE_PATH_BUILD_OUTPUT_EPRO
}

function epro-build-all() {
	build-vs /c/Dev/epro/Everything.sln $FILE_PATH_BUILD_OUTPUT_EPRO_EVERYTHING 
}

function epro-build-metaparser() {
	build-vs /c/Dev/epro-metaparser/Bluewire.MetaParser.sln $FILE_PATH_BUILD_OUTPUT_EPRO_METAPARSER 
}

function epro-build-speech() {
	build-vs /c/Dev/epro/Bluewire.Speech.sln $FILE_PATH_BUILD_OUTPUT_EPRO_SPEECH 
}

function epro-build-logs() {
	cd LOGS_PATH
}
