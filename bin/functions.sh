# shellcheck shell=bash
#
# Shared by bin/list and bin/link. Sourced, never run.
#
# The repo is authoritative: a symlink into it whose skill is gone is stale.
# Agents read ~/.claude/skills (Claude Code) and ~/.agents/skills (others).
#

repo="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)" || return $?
targets=("$HOME/.claude/skills" "$HOME/.agents/skills")

#
# Prints a log message.
#
function log()
{
	echo ">>> $1"
}

#
# Prints a warning message.
#
function warn()
{
	echo "*** $1" >&2
}

#
# Prints an error message.
#
function error()
{
	echo "!!! $1" >&2
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
# Prints the skill names in the repo, one per line.
#
function skills()
{
	local dir

	for dir in "$repo"/*/; do
		dir="${dir%/}"
		[[ -f "$dir/SKILL.md" ]] && echo "${dir##*/}"
	done
	return 0
}

#
# Prints the state of <target>/<name>: ok, missing, stale, foreign or dir.
#
function status()
{
	local target="$1"
	local name="$2"
	local link="$target/$name"

	if [[ -L "$link" ]]; then
		case "$(readlink "$link")" in
			"$repo/$name")
				if   [[ -f "$repo/$name/SKILL.md" ]]; then echo ok
				else echo stale
				fi
				;;
			"$repo"/*)	echo stale ;;
			*)		echo foreign ;;
		esac
	elif [[ -e "$link" ]]; then echo dir
	else echo missing
	fi
}

#
# Prints repo skills plus any target entries that link into the repo.
#
function names()
{
	local target link

	skills
	for target in "${targets[@]}"; do
		for link in "$target"/*; do
			[[ -L "$link" ]] || continue
			case "$(readlink "$link")" in
				"$repo"/*)	echo "${link##*/}" ;;
			esac
		done
	done
}
