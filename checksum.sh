#!/bin/bash
#  checksum.sh
#  
#  @author Leonardo Laureti <https://loltgt.ga>
#  @version 2020-06-22 r06
#  @license MIT License
#  
#  Checksum files and directories.
#  Script util to check files integrity per folders.
#  
#  When started with option [-U | --update]
#  it will create -or- update a table of contents.
#  
#  @example ./checksum.sh -U -T trivial,tpce,trv0,trv1 ./MyFolder
#  
#  It can also be used for incremental update with sub-folders.
#  
#  @example ./checksum.sh -U ./MyFolder/SubFolder
#  
#  When started with option [-C | --check]
#  it does a whole -or- incremental files integrity check.
#  
#  @example ./checksum.sh -C "./MyFolder/Yet * Another * Sub * Folder"
#  
#  Generated hash table file is CommaSeparatedValue
#  with entries relative to the base folder (eg. /drive/MyFolder/), in a format like this:
#    
#    relative path, file name, last modified time ISO-8601, MD5 hash
#    
#    ./SubFolder,file.trivial,1970-01-01T00:00:01+0000,7f138a09169b250e9dcb378140907378
#  
#  @example ./checksum.sh -H checksum_File_CSV.check -C -B MyFolder ./MyFolder/SubFolder
#  

_DEFAULT_FOLDER="."
_DEFAULT_DATATABLE="checksum.check"
_DEFAULT_FILETYPES="*"
_DEFAULT_LOGFILE="checksum.log"

_SCRIPTNAME=$(basename "$0")
_SCRIPTVERSION="2020-06-22 r06"
_CURRTIME=$(date "+%Y-%m-%dT%H:%M:%S%z")

_UPDATE=0
_CHECK=0
_FORCE=0
_LOG=0
_VERBOSE=0
_HELP=0


checksum__usage ()
{
	printf "%s"         "Usage:"
	printf "\t%s\n"     "./$_SCRIPTNAME [-U | -C] [-H [...]] [-B [...]] [-T (,[...])] [--force] [--log] [-V] [folder]"
	printf "\t%s\n\n"   "./$_SCRIPTNAME [--update | --check] [--hash-file [...]] [--base-path [...]] [--file-types (,[...])] [--force] [--log] [--verbose] [folder]"
}

checksum__version ()
{
	printf "%s\t%s\n"    "$_SCRIPTNAME" "$_SCRIPTVERSION"
}

checksum__help ()
{
	printf "\t%s\n"     ""
	printf "\t%s\n\n"   "Checksum files and directories."
	printf "\t%s\n\n\n" "bash $_SCRIPTNAME [OPTIONS]... [FOLDER]"
	printf "\t\t%s\n\n" "-U, --update       Update the hash table, entire -or- per folder."
	printf "\t\t%s\n\n" "-C, --check        Integrity check, entire -or- per folder."
	printf "\t\t%s\n\n" "-H, --hash-file    Hash table file to use. "
	printf "\t\t%s\n\n" "                   Default: checksum.check"
	printf "\t\t%s\n\n" "-B, --base-foler   Base folder. "
	printf "\t\t%s\n\n" "                   Default: ."
	printf "\t\t%s\n"   "-T, --file-types   What file types to check, by their file extension. "
	printf "\t\t%s\n\n" "                   Default: *  (accepts comma separated values)"
	printf "\t\t%s\n\n" "--force            Force update without diff -or- check using diff."
	printf "\t\t%s\n\n" "--log              Write to a log file."
	printf "\t\t%s\n\n" "-V, --verbose      Output more information."
	printf "\t\t%s\n\n" "-v, --version      Output version information."
	printf "\t\t%s\n\n" "-h, --help         Display this help and exit."
}

# @global DATATABLE
# @global DATATABLE_NAME
# @params $1 init
checksum__exists ()
{
	if [[ ! -f "$DATATABLE" ]]; then
		checksum__log "File: \"$DATATABLE_NAME\" not exists.\n"
		checksum__log "File touch: \"$DATATABLE\"" 1
		[[ -n "$1" ]] && touch "$DATATABLE"
	fi
}

# @global HEAD
# @global FILETYPES
# @global DATATABLE
# @global RELBASE
# @global DATATABLE
# @global _DEFAULT_FILETYPES
# @param $1 init
# @return 0
checksum__head ()
{
	if [[ -z "$1" ]]; then
		if [[ -f "$DATATABLE" ]]; then
			HEAD=($(head -n 3 "$DATATABLE" | sed 's/\*/\\052/'))

			if [[ -z "$FILETYPES" || "$FILETYPES" == "$_DEFAULT_FILETYPES" ]]; then
				FILETYPES="${HEAD[1]}"
			fi
		else
			checksum__err "Empty file" 1
		fi
	else
		HEAD=("$RELBASE" "$FILETYPES" "RELDIR,FILENAME,TIME,HASH")
	fi

	checksum__log "File head RELBASE: ${HEAD[0]}" 1
	checksum__log "File head FILETYPES: ${HEAD[1]}" 1

	if [[ -n "$1" ]]; then
		return 0
	fi

	if [[ "${HEAD[2]}" != "RELDIR,FILENAME,TIME,HASH" ]]; then
		checksum__err 1 1
	fi

	if [[ "${HEAD[0]}" != "$RELBASE" ]]; then
		checksum__err "Wrong folder base. Expected: \"${HEAD[0]}\"" 1
	fi

	if [[ "${HEAD[1]}" != "$FILETYPES" ]]; then
		checksum__err "File types incoherence. Expected: \"${HEAD[1]}\"" 1
	fi
}

# @global TABLE
# @global READ_SUB
# @global DATATABLE
# @global RELFOLDER
# @param $1 update
checksum__read ()
{
	TABLE=""
	READ_SUB=-1
	local read_from=-1
	local read_to=-1
	local count=0
	local reldir
	local line ; local reline

	checksum__log "File read: \"$DATATABLE\"" 1

	reldir=$([[ "$RELFOLDER" == "." ]] && echo "./" || echo "./$RELFOLDER")

	while read -r line; do
		let count+=1

		if [[ $count -le 3 || -z "$line" ]]; then
			continue;
		fi

		reline="$line"

		if [[ "$line" == "\""* ]]; then
			reline="${reline#\"}"
			reline="${reline/\",/,}"
			reline="${reline//\"\"/\"}"
		fi
		if [[ "$reline" == "$reldir"* ]]; then
			if [[ -z "$1" ]]; then
				TABLE="$TABLE$line\n"
				read_to=$count
			elif [[ $READ_SUB -eq -1 ]]; then
				TABLE="$TABLE[[[[SUBSTRING]]]]"
				READ_SUB=$count
			fi

			[[ $read_from -eq -1 ]] && read_from=$count
		elif [[ -n "$1" ]]; then
			TABLE="$TABLE$line\n"

			[[ $read_from -eq -1 ]] && read_from=$count
		fi
	done < "$DATATABLE"

	[[ $read_to -eq -1 ]] && read_to=$count
	checksum__log "Read from line: $read_from" 1
	checksum__log "Read to line: $read_to" 1
	[[ $READ_SUB -ne -1 ]] && checksum__log "Read substring line: $READ_SUB" 1
}

# @global DATATABLE
# @global DATATABLE_NAME
# @global HEAD
# @global TABLE
# @param $1 init
checksum__write ()
{
	if [[ "$1" -eq 0 ]]; then
		checksum__log "File move: \"$DATATABLE\" to \".$DATATABLE_NAME.tmpfile\"" 1
		mv "$DATATABLE" ".$DATATABLE_NAME.tmpfile"
	fi

	checksum__log "File write: \"$DATATABLE\"" 1

	printf "%s\n" "${HEAD[@]}" "$TABLE" > "$DATATABLE"

	if [[ ! -f "$DATATABLE" ]]; then
		checksum__err 1 1
	fi

	if [[ "$1" -eq 0 ]]; then
		checksum__log "File remove: \".$DATATABLE_NAME.tmpfile\"" 1
		rm ".$DATATABLE_NAME.tmpfile"
	fi
}

# @global DATA
# @global FILETYPES
# @global RELBASE
# @global _VERBOSE
# @global _DEFAULT_FILETYPES
checksum__traverse ()
{
	DATA=""
	local types=$(echo -e "$FILETYPES")
	local directories=$(checksum__find "$1" "d") ; local files
	local not_verb=$([[ $_VERBOSE -eq 0 ]] && 1)
	local dir ; local reldir
	local file ; local filename ; local lmtime ; local hash
	local line

	if [[ "$types" != "$_DEFAULT_FILETYPES" ]]; then
		types=$(echo "$types" | sed 's/\([a-z0-9]*\)/\\.&/g ; s/,/\\|/g ; s/\(.*\)/.*[&]$/')
	fi

	for dir in $directories; do
		reldir=$(checksum__rel "$dir" "$RELBASE")
		reldir=$([[ "$reldir" == "." ]] && echo "./" || echo "./$reldir" | checksum__escapeschars)
		line="$reldir,,,"

		DATA="$DATA$line\n"
		checksum__log "$line" $not_verb

		files=$(checksum__find "$dir" "f" "$types")

		for file in $files; do
			filename=$(basename "$file" | checksum__escapeschars)
			lmtime=$(checksum__lmodtime "$file")
			hash=$(checksum__hashing "$file")
			line="$reldir,$filename,$lmtime,$hash"

			DATA="$DATA$line\n"
			checksum__log "$line" $not_verb
		done
	done
}

# @global TABLE
# @global DATA
# @global DATATABLE
# @global DATATABLE_NAME
# @global FOLDER
# @global READ_SUB
# @global _FORCE
# @return 0
checksum__update ()
{
	local init
	local source

	checksum__exists 1

	[[ -s "$DATATABLE" ]] && init=0 || init=1

	checksum__log "File: \"$DATATABLE_NAME\"\n"

	if [[ $init -eq 0 ]]; then
		checksum__log "Reading hash table.\n"

		checksum__head
		checksum__read 1
	else
		checksum__log "Generating hash table.\n"

		checksum__head 1
	fi

	checksum__log "Updating hash table ...\n"

	checksum__traverse "$FOLDER"

	checksum__log ""

	if [[ $init -eq 1 || $READ_SUB -eq -1 ]]; then
		TABLE=$(echo -e "$DATA")
	else
		[[ _FORCE -eq 0 ]] && source=$(tail -n +4 "$DATATABLE")

		TABLE=$(echo -e "${TABLE/\[\[\[\[SUBSTRING\]\]\]\]/$DATA}")

		if [[ _FORCE -eq 0 && "$source" == "$TABLE" ]]; then
			checksum__log "Nothing to update."
			return 0
		fi
	fi

	checksum__log "Writing file ..."

	checksum__write $init
}

# @global TABLE
# @global DATA
# @global DATATABLE
# @global DATATABLE_NAME
# @global FOLDER
# @global _FORCE
# @return 0
checksum__check ()
{
	local diff
	local diff_trim
	local line
	local reline

	checksum__exists

	checksum__log "File: \"$DATATABLE_NAME\"\n"
	checksum__log "Reading hash table.\n"

	checksum__head
	checksum__read

	checksum__log "Checking ...\n"

	checksum__traverse "$FOLDER"

	checksum__log ""
	checksum__log "Diff:"

	diff=$(checksum__diff "$TABLE" "$DATA")
	checksum__log "$_DIFF" 1

	if [[ _FORCE -eq 0 && "$TABLE" == "$DATA" ]]; then
		echo "0"
		return 0
	fi

	diff=""
	reldir=$(checksum__rel "$RELFOLDER" "$RELBASE")
	[[ "$reldir" == "." ]] && reldir="./" || reldir="./$reldir"

	for line in $diff; do
		reline="$line"

		if [[ "$line" == "\""* ]]; then
			reline="${reline#\"}"
			reline="${reline/\",/,}"
			reline="${reline//\"\"/\"}"
		fi
		if [[ "$reline" == "> $reldir"* || "$reline" == "< $reldir"* || "$reline" == "---" ]]; then
			diff_trim=$(echo -e "$diff\n$line")
		fi
	done

	[[ -z "$diff_trim" ]] && echo "0" || echo "$diff_trim"
}

# @param $1 OS type
checksum__platform ()
{
	case "$1" in
		*darwin*) echo "darwin" ;;
		*bsd*) echo "*bsd" ;;
		*win*|*msys*) echo "*win" ;;
		*) echo "*ux" ;;
	esac
}

# @param $1 relative path
checksum__abs ()
{
	if [[ "$PLATFORM_PATH" == "realpath" ]]; then
		realpath "$1"
	elif [[ "$PLATFORM_PATH" == "perl" ]]; then
		perl -e "use File::Spec; print File::Spec->rel2abs( @ARGV[0], @ARGV[1] );" -- "$1" "$PWD"
	fi
}

# @global PWD
# @param $1 absolute path
# @param $2 base path [$PWD]
checksum__rel ()
{
	local dir

	[[ -z "$2" ]] && dir="$PWD" || dir="$2"

	if [[ "$PLATFORM_PATH" == "realpath" ]]; then
		realpath --relative-to "$dir" "$1"
	elif [[ "$PLATFORM_PATH" == "perl" ]]; then
		perl -e "use File::Spec; print File::Spec->abs2rel( @ARGV[0], @ARGV[1] );" -- "$1" "$dir"
	fi
}

# CSV field according RFC-4180
# percent sign % replaced double for safe printf
# @todo shilling mark \ replaced with : by find
# @var stdin
checksum__escapeschars ()
{
	local esc_stdin
	read -d "" -u 0 ecs_stdin

	if [[ "$ecs_stdin" =~ "," ]]; then
		ecs_stdin="\"${ecs_stdin//\"/\"\"}\""
	fi

	echo "${ecs_stdin//%/%%}"

	# @todo backslash removed
	# sed 's/%/%%/g ; /,/ s/"/""/g ; /,/ s/.*/"&"/'
}

# @param $1 base path
# @param $2 by type
# @param $3 file types regex
checksum__find ()
{
	if [ "$3" ]; then
		find "$1" -maxdepth 1 -type "$2" -regex "$3"
	elif [ "$2" ]; then
		find "$1" -type "$2"
	elif [ "$1" ]; then
		find "$1"
	fi
}

# @param $1 arg 1
# @param $2 arg 2
checksum__diff ()
{
	diff <(echo -e "$1") <(echo -e "$2")
}

checksum__lmodtime ()
{
	if [[ "$PLATFORM" == "*ux" ]]; then
		stat -c "%y" "$1" | date -f - "+%Y-%m-%dT%H:%M:%S%z"
	else
		stat -f "%Sm" -t "%Y-%m-%dT%H:%M:%S%z" "$1"
	fi
}

# @param $1 file
checksum__hashing ()
{
	local hash=$("${PLATFORM_HASH[0]}" "${PLATFORM_HASH[1]}" "$1")
	echo "${hash##* }"

	# echo $("${PLATFORM_HASH[0]}" "${PLATFORM_HASH[1]}" "$1" | sed 's/^.* //')
}

# @param $1 error message
# @param $2 exit status code
# @param $3 error message var
# @return error status code
checksum__err ()
{
	case $1 in
		0) break ;;
		1) checksum__log "Something went wrong" ;;
		2) checksum__log "Missing $3 command" ;;
		*) checksum__log "$1" ;;
	esac

	if [[ -n $2 ]]; then
		checksum__log "Exit status code: $2" 1
		exit $2
		return $2
	fi
}

# @param $1 log message
# @param $2 not print
checksum__log ()
{
	[[ -z $2 ]] && echo -e "$1"

	if [[ $_LOG -eq 1 ]]; then
		if [[ ! -f "$LOGFILE" ]]; then
			touch "$LOGFILE"
		fi
		if [[ -n "$1" ]]; then
			echo "${1%\\n}" >> "$LOGFILE"
		fi
	fi
}


IFS=$'\n'

for _SRG in "$@"; do
	case "$_SRG" in
		-H*|--hash-file*)
			_DATATABLE="$2"
			shift
			shift
			;;
		-B*|--base-folder*)
			_BASEFOLDER="$2"
			shift
			shift
			;;
		-T*|--file-types*)
			_FILETYPES="$2"
			shift
			shift
			;;
		-U|--update)
			_UPDATE=1
			shift
			;;
		-C|--check)
			_CHECK=1
			shift
			;;
		--force)
			_FORCE=1
			shift
			;;
		--log)
			_LOG=1
			shift
			;;
		-V|--verbose)
			_VERBOSE=1
			shift
			;;
		-v|--version)
			_VERSION=1
			shift
			;;
		-h|--help)
			_HELP=1
			shift
			;;
		-*)
			[[ "$1" == "-"* ]] && shift
			printf "%s: %s %s\n\n" "$0" "Illegal option" "$2"
			checksum__usage

			exit 1
			;;
		*)
			[[ "$1" != -* ]] && _FOLDER="$1"
			;;
	esac
done


# platform related

PLATFORM=$(checksum__platform "$OSTYPE")

if [[ -n $(type -t realpath) ]]; then
	PLATFORM_PATH="realpath"
elif [[ -n $(type -t perl) ]]; then
	PLATFORM_PATH="perl"
else
	checksum__err 2 2 "path"
fi

if [[ -n $(type -t md5) ]]; then
	PLATFORM_HASH=("md5" "--")
elif [[ -n $(type -t openssl) ]]; then
	PLATFORM_HASH=("openssl" "md5")
else
	checksum__err 2 2 "hash"
fi

if [[ -n $(type -t find) ]]; then
	PLATFORM_FIND="find"
else
	checksum__err 2 2 "find"
fi

if [[ -n $(type -t diff) ]]; then
	PLATFORM_DIFF="diff"
else
	checksum__err 2 2 "diff"
fi


RELPATH=$(checksum__rel "$PWD")
LOGFILE=$(checksum__abs "$_DEFAULT_LOGFILE")

if [[ $_LOG -eq 1 && -s "$LOGFILE" ]]; then
	echo "" >> "$LOGFILE"
fi


checksum__log "$0 $_CURRTIME" 1
checksum__log "_FOLDER=$_FOLDER" 1
checksum__log "_DATATABLE=$_DATATABLE" 1
checksum__log "_BASEFOLDER=$_BASEFOLDER" 1
checksum__log "_FILETYPES=$_FILETYPES" 1
checksum__log "_UPDATE=$_UPDATE" 1
checksum__log "_CHECK=$_CHECK" 1
checksum__log "_FORCE=$_FORCE" 1
checksum__log "_VERBOSE=$_VERBOSE" 1


# paths

DEFAULT_FOLDER=$(checksum__abs "$_DEFAULT_FOLDER")
BASE=$([[ -n "$_BASEFOLDER" ]] && checksum__abs "${_BASEFOLDER/\*/\052}" || echo "$DEFAULT_FOLDER")
RELBASE=$(checksum__rel "$BASE")
FOLDER=$([[ -n "$_FOLDER" ]] && checksum__abs "${_FOLDER/\*/\052}" || echo "$BASE")
RELFOLDER=$(checksum__rel "$FOLDER" "$RELBASE")


# hash table file

DEFAULT_DATATABLE=$(checksum__abs "$_DEFAULT_DATATABLE")
DATATABLE=$([[ -n "$_DATATABLE" ]] && checksum__abs "$_DATATABLE" || checksum__abs "$DEFAULT_DATATABLE")
DATATABLE_NAME=$(basename "$DATATABLE")


# file types

FILETYPES=$([[ -n "$_FILETYPES" ]] && echo "$_FILETYPES" | tr "[:upper:]" "[:lower:]" || echo "$_DEFAULT_FILETYPES")


checksum__log "RELPATH=$RELPATH" 1
checksum__log "RELBASE=$RELBASE" 1
checksum__log "RELFOLDER=$RELFOLDER" 1
checksum__log "BASE=$BASE" 1
checksum__log "FOLDER=$FOLDER" 1
checksum__log "FILETYPES=$FILETYPES" 1
checksum__log "DATATABLE=$DATATABLE" 1
checksum__log "LOGFILE=$LOGFILE" 1
checksum__log "PLATFORM=$PLATFORM" 1
checksum__log "RELEASE=$_SCRIPTVERSION" 1


if [[ $_UPDATE -eq 1 ]]; then
	checksum__log "Perform  checksum__update ()" 1
	checksum__update
elif [[ $_CHECK -eq 1 ]]; then
	checksum__log "Perform  checksum__check ()" 1
	checksum__check
elif [[ $_HELP -eq 1 ]]; then
	checksum__log "Perform  checksum__help ()" 1
	checksum__help
elif [[ $_VERSION -eq 1 ]]; then
	checksum__version
else
	checksum__usage
fi

checksum__log "Exit status code: 0" 1
