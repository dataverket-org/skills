#!/usr/bin/env bash
#
# fetch-tool: downloads and unpacks a release archive. Everything that would
# normally live in share/fetch-tool/*.sh is inlined here so the shape is
# visible in one file: constants, logging, utilities, option parsing, and an
# entry point that reads as a list of steps.
#

fetch_tool_version="0.1.0"
cache_dir="${FETCH_TOOL_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/fetch-tool}"
dest_dir="${FETCH_TOOL_DEST_DIR:-$HOME/.local/opt}"

if   command -v curl >/dev/null; then downloader="curl"
elif command -v wget >/dev/null; then downloader="wget"
fi

#
# Prints a log message.
#
function log()
{
	if [[ -t 1 ]]; then
		echo -e "\x1b[1m\x1b[32m>>>\x1b[0m \x1b[1m$1\x1b[0m"
	else
		echo ">>> $1"
	fi
}

#
# Prints a warning message.
#
function warn()
{
	if [[ -t 1 ]]; then
		echo -e "\x1b[1m\x1b[33m***\x1b[0m \x1b[1m$1\x1b[0m" >&2
	else
		echo "*** $1" >&2
	fi
}

#
# Prints an error message.
#
function error()
{
	if [[ -t 1 ]]; then
		echo -e "\x1b[1m\x1b[31m!!!\x1b[0m \x1b[1m$1\x1b[0m" >&2
	else
		echo "!!! $1" >&2
	fi
}

unset enable_debug

#
# Prints a debugging message, only if enable_debug is enabled.
#
function debug()
{
	if [[ ! $enable_debug -eq 1 ]]; then
		return
	fi

	echo "[DEBUG] $1" >&2
}

#
# Runs the command and prints the full command if debugging is enabled.
#
function run()
{
	debug "$*"
	"$@"
}

#
# Prints an error message and exits.
#
function fail()
{
	error "$*"
	exit 1
}

#
# Prints usage information for fetch-tool.
#
function usage()
{
	cat <<USAGE
usage: fetch-tool [OPTIONS] URL

Options:

	-d, --dest DIR		Directory to unpack into (default: $dest_dir)
	-c, --cache DIR		Directory to keep downloads in (default: $cache_dir)
	    --no-verify		Do not verify the archive checksum
	-D, --debug		Enable debug messages
	-V, --version		Prints the version
	-h, --help		Prints this message

Examples:

	$ fetch-tool https://example.com/tool-1.2.tar.gz
	$ fetch-tool -d /opt/tool https://example.com/tool-1.2.tar.gz

USAGE
}

#
# Parses command-line options for fetch-tool.
#
function parse_options()
{
	local argv=()

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-d|--dest)
				dest_dir="$2"
				shift 2
				;;
			-c|--cache)
				cache_dir="$2"
				shift 2
				;;
			--no-verify)
				no_verify=1
				shift
				;;
			-D|--debug)
				enable_debug=1
				shift
				;;
			-V|--version)
				echo "fetch-tool: $fetch_tool_version"
				exit
				;;
			-h|--help)
				usage
				exit
				;;
			-*)
				echo "fetch-tool: unrecognized option $1" >&2
				return 1
				;;
			*)
				argv+=("$1")
				shift
				;;
		esac
	done

	case ${#argv[*]} in
		1)	url="${argv[0]}" ;;
		0)
			echo "fetch-tool: URL required" >&2
			usage 1>&2
			return 1
			;;
		*)
			echo "fetch-tool: too many arguments: ${argv[*]}" >&2
			return 1
			;;
	esac
}

#
# Downloads a URL into a destination path, unless it is already there.
#
function download()
{
	local url="$1"
	local dest="$2"

	if [[ -z "$downloader" ]]; then
		error "Could not find curl or wget"
		return 1
	fi

	[[ -f "$dest" ]] && return

	mkdir -p "${dest%/*}" || return $?

	case "$downloader" in
		curl)	run curl -f -L -o "$dest.part" "$url" || return $? ;;
		wget)	run wget -O "$dest.part" "$url"       || return $? ;;
	esac

	mv "$dest.part" "$dest" || return $?
}

#
# Verifies an archive against a checksum file beside it, if one exists.
#
function verify()
{
	local archive="$1"
	local checksums="$archive.sha256"

	if [[ ! -f "$checksums" ]]; then
		warn "No checksum for ${archive##*/}"
		return
	fi

	run sha256sum -c "$checksums" || return $?
}

#
# Extracts an archive into a directory.
#
function extract()
{
	local archive="$1"
	local dest="$2"

	mkdir -p "$dest" || return $?

	case "$archive" in
		*.tgz|*.tar.gz)	run tar -xzf "$archive" -C "$dest" || return $? ;;
		*.tar.xz)	run tar -xJf "$archive" -C "$dest" || return $? ;;
		*.zip)		run unzip "$archive" -d "$dest"    || return $? ;;
		*)
			error "Unknown archive format: $archive"
			return 1
			;;
	esac
}

#
# Initializes variables derived from the options.
#
function init()
{
	archive="$cache_dir/${url##*/}"
	unpack_dir="$dest_dir/${archive##*/}"
	unpack_dir="${unpack_dir%%.tar*}"
	unpack_dir="${unpack_dir%.tgz}"
	unpack_dir="${unpack_dir%.zip}"
}

parse_options "$@" || exit $?
init || exit $?

log "Fetching $url into $unpack_dir ..."

download "$url" "$archive" || fail "Download of $url failed!"

if [[ ! $no_verify -eq 1 ]]; then
	verify "$archive" || fail "Verification of ${archive##*/} failed!"
fi

extract "$archive" "$unpack_dir" || fail "Unpacking of ${archive##*/} failed!"

log "Successfully unpacked ${archive##*/} into $unpack_dir"
