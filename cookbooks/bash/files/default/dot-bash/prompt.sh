GIT_PS1_SHOWDIRTYSTATE=1
GIT_PS1_SHOWSTASHSTATE=1
GIT_PS1_SHOWUNTRACKEDFILES=1
GIT_PS1_SHOWUPSTREAM="verbose"

# __gitdir accepts 0 or 1 arguments (i.e., location)
# returns location of .git repo
__gitdir ()
{
	if [ -z "${1-}" ]; then
		if [ -n "${__git_dir-}" ]; then
			echo "$__git_dir"
		elif [ -d .git ]; then
			echo .git
		else
			git rev-parse --git-dir 2>/dev/null
		fi
	elif [ -d "$1/.git" ]; then
		echo "$1/.git"
	else
		echo "$1"
	fi
}

# stores the divergence from upstream in $p
# used by GIT_PS1_SHOWUPSTREAM
__git_ps1_show_upstream ()
{
	local key value
	local svn_remote=() svn_url_pattern count n
	local upstream=git legacy="" verbose=""

	# get some config options from git-config
	while read key value; do
		case "$key" in
		bash.showupstream)
			GIT_PS1_SHOWUPSTREAM="$value"
			if [[ -z "${GIT_PS1_SHOWUPSTREAM}" ]]; then
				p=""
				return
			fi
			;;
		svn-remote.*.url)
			svn_remote[ $((${#svn_remote[@]} + 1)) ]="$value"
			svn_url_pattern+="\\|$value"
			upstream=svn+git # default upstream is SVN if available, else git
			;;
		esac
	done < <(git config -z --get-regexp '^(svn-remote\..*\.url|bash\.showupstream)$' 2>/dev/null | tr '\0\n' '\n ')

	# parse configuration values
	for option in ${GIT_PS1_SHOWUPSTREAM}; do
		case "$option" in
		git|svn) upstream="$option" ;;
		verbose) verbose=1 ;;
		legacy)  legacy=1  ;;
		esac
	done

	# Find our upstream
	case "$upstream" in
	git)    upstream="@{upstream}" ;;
	svn*)
		# get the upstream from the "git-svn-id: ..." in a commit message
		# (git-svn uses essentially the same procedure internally)
		local svn_upstream=($(git log --first-parent -1 \
					--grep="^git-svn-id: \(${svn_url_pattern:2}\)" 2>/dev/null))
		if [[ 0 -ne ${#svn_upstream[@]} ]]; then
			svn_upstream=${svn_upstream[ ${#svn_upstream[@]} - 2 ]}
			svn_upstream=${svn_upstream%@*}
			for ((n=1; "$n" <= "${#svn_remote[@]}"; ++n)); do
				svn_upstream=${svn_upstream#${svn_remote[$n]}}
			done

			if [[ -z "$svn_upstream" ]]; then
				# default branch name for checkouts with no layout:
				upstream=${GIT_SVN_ID:-git-svn}
			else
				upstream=${svn_upstream#/}
			fi
		elif [[ "svn+git" = "$upstream" ]]; then
			upstream="@{upstream}"
		fi
		;;
	esac

	# Find how many commits we are ahead/behind our upstream
	if [[ -z "$legacy" ]]; then
		count="$(git rev-list --count --left-right \
				"$upstream"...HEAD 2>/dev/null)"
	else
		# produce equivalent output to --count for older versions of git
		local commits
		if commits="$(git rev-list --left-right "$upstream"...HEAD 2>/dev/null)"
		then
			local commit behind=0 ahead=0
			for commit in $commits
			do
				case "$commit" in
				"<"*) let ++behind
					;;
				*)    let ++ahead
					;;
				esac
			done
			count="$behind	$ahead"
		else
			count=""
		fi
	fi

	# calculate the result
	if [[ -z "$verbose" ]]; then
		case "$count" in
		"") # no upstream
			p="" ;;
		"0	0") # equal to upstream
			p="=" ;;
		"0	"*) # ahead of upstream
			p=">" ;;
		*"	0") # behind upstream
			p="<" ;;
		*)	    # diverged from upstream
			p="<>" ;;
		esac
	else
		case "$count" in
		"") # no upstream
			p="" ;;
		"0	0") # equal to upstream
			p="" ;;
		"0	"*) # ahead of upstream
			p="+${count#0	}" ;;
		*"	0") # behind upstream
			p="-${count%	0}" ;;
		*)	    # diverged from upstream
			p="+${count#*	}-${count%	*}" ;;
		esac
	fi

}


# __git_ps1 accepts 0 or 1 arguments (i.e., format string)
# returns text to add to bash PS1 prompt (includes branch name)
__ps1_git() {
	local g="$(__gitdir)"
	if [ -n "$g" ]; then
		if [ -e "$g/../.promptignore" ]; then
			return
		fi
		local r=""
		local b=""
		if [ -f "$g/rebase-merge/interactive" ]; then
			r="|REBASE-i"
			b="$(cat "$g/rebase-merge/head-name")"
		elif [ -d "$g/rebase-merge" ]; then
			r="|REBASE-m"
			b="$(cat "$g/rebase-merge/head-name")"
		else
			if [ -d "$g/rebase-apply" ]; then
				if [ -f "$g/rebase-apply/rebasing" ]; then
					r="|REBASE"
				elif [ -f "$g/rebase-apply/applying" ]; then
					r="|AM"
				else
					r="|AM/REBASE"
				fi
			elif [ -f "$g/MERGE_HEAD" ]; then
				r="|MERGING"
			elif [ -f "$g/BISECT_LOG" ]; then
				r="|BISECTING"
			fi

			b="$(git symbolic-ref HEAD 2>/dev/null)" || {

				b="$(
				case "${GIT_PS1_DESCRIBE_STYLE-}" in
				(contains)
					git describe --contains HEAD ;;
				(branch)
					git describe --contains --all HEAD ;;
				(describe)
					git describe HEAD ;;
				(* | default)
					git describe --tags --exact-match HEAD ;;
				esac 2>/dev/null)" ||

				b="$(cut -c1-7 "$g/HEAD" 2>/dev/null)..." ||
				b="unknown"
				b="($b)"
			}
		fi

		local w=""
		local i=""
		local s=""
		local u=""
		local c=""
		local p=""

		if [ "true" = "$(git rev-parse --is-inside-git-dir 2>/dev/null)" ]; then
			if [ "true" = "$(git rev-parse --is-bare-repository 2>/dev/null)" ]; then
				c="BARE:"
			else
				b="GIT_DIR!"
			fi
		elif [ "true" = "$(git rev-parse --is-inside-work-tree 2>/dev/null)" ]; then
			if [ -n "${GIT_PS1_SHOWDIRTYSTATE-}" ]; then
				if [ "$(git config --bool bash.showDirtyState)" != "false" ]; then
					git diff --no-ext-diff --quiet --exit-code || w="*"
					if git rev-parse --quiet --verify HEAD >/dev/null; then
						git diff-index --cached --quiet HEAD -- || i="+"
					else
						i="#"
					fi
				fi
			fi
			if [ -n "${GIT_PS1_SHOWSTASHSTATE-}" ]; then
				git rev-parse --verify refs/stash >/dev/null 2>&1 && s="$"
			fi

			if [ -n "${GIT_PS1_SHOWUNTRACKEDFILES-}" ]; then
				if [ -n "$(git ls-files --others --exclude-standard)" ]; then
					u="?"
				fi
			fi

			if [ -n "${GIT_PS1_SHOWUPSTREAM-}" ]; then
				__git_ps1_show_upstream
			fi
		fi

		local f="$w$i$s$u"
		echo -e " ${SOLAR_RED}${c}${SOLAR_YELLOW}${b##refs/heads/}${SOLAR_ORANGE}${p:+(${p})}${SOLAR_RED}${f}${SOLAR_GREEN}${r}${RESET}"
	fi
}

__ps1_rc() {
	if [[ ${1:-0} -eq 0 ]]; then
		echo -en "${SOLAR_GREEN}0${RESET}"
	else
		echo -en "${SOLAR_RED}${1}${RESET}"
	fi
}

if [[ $(id -u) -eq 0 ]]; then
	USER_COLOR=${SOLAR_RED}
else
	USER_COLOR=${BOLD}${SOLAR_RED}
fi

PS1="\r\[${RESET}${USER_COLOR}\]\u"
PS1+="\[${RESET}\]@"
PS1+="\[${RESET}${SOLAR_YELLOW}\]${_NODENAME}\[${RESET}\].${_DOMAINNAME}"
PS1+=" \[${RESET}\][${COL_none}\$(__ps1_rc \$?)\[${RESET}]\]"
PS1+=" \[${RESET}${SOLAR_YELLOW}\]\t"
PS1+=" \[${RESET}${SOLAR_GREEN}\]\w"
PS1+="\$(__ps1_git)"
PS1+="\n\[${RESET}${USER_COLOR}\]\$ \[${RESET}\]"

# screen/tmux title magic
set_screen_title() {
	if [[ -z ${BASHRC_NO_SCREEN_MAGIC} ]]; then
		echo -ne "\ek${USER}@${HOSTNAME}:${BASH_COMMAND/ *}\e\\"
	fi
}

reset_screen_title() {
	if [[ -z ${BASHRC_NO_SCREEN_MAGIC} ]]; then
		echo -ne "\ek${USER}@${HOSTNAME}\e\\"
	fi
}

if [[ "${TERM/-256color}" == "screen" ]]; then
	PROMPT_COMMAND=reset_screen_title
	trap set_screen_title DEBUG
fi
