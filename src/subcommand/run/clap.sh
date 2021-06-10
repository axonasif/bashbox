# Created by argbash-init v2.10.0
# ARG_OPTIONAL_BOOLEAN([debug])
# ARG_OPTIONAL_BOOLEAN([release])
# ARG_POSITIONAL_SINGLE([path])
# ARG_DEFAULTS_POS()
# ARG_HELP([<The general help message of my script>])
# ARGBASH_GO()
# needed because of Argbash --> m4_ignore([
### START OF CODE GENERATED BY Argbash v2.10.0 one line above ###
# Argbash is a bash code generator used to get arguments parsing right.
# Argbash is FREE SOFTWARE, see https://argbash.io for more info

begins_with_short_option()
{
	local first_option all_short_options='h'
	first_option="${1:0:1}"
	test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

# THE DEFAULTS INITIALIZATION - POSITIONALS
_positionals=()
_arg_path=
# THE DEFAULTS INITIALIZATION - OPTIONALS
_arg_debug="off"
_arg_release="off"


print_help()
{
	printf '%s\n' "<The general help message of my script>"
	printf 'Usage: %s [--(no-)debug] [--(no-)release] [-h|--help] <path>\n' "$0"
	printf '\t%s\n' "-h, --help: Prints help"
}


parse_commandline()
{
	_positionals_count=0
	while test $# -gt 0
	do
		_key="$1"
		case "$_key" in
			--no-debug|--debug)
				_arg_debug="on"
				test "${1:0:5}" = "--no-" && _arg_debug="off"
				;;
			--no-release|--release)
				_arg_release="on"
				test "${1:0:5}" = "--no-" && _arg_release="off"
				;;
			-h|--help)
				print_help
				exit 0
				;;
			-h*)
				print_help
				exit 0
				;;
			*)
				_last_positional="$1"
				_positionals+=("$_last_positional")
				_positionals_count=$((_positionals_count + 1))
				;;
		esac
		shift
	done
}


handle_passed_args_count()
{
	local _required_args_string="'path'"
	test "${_positionals_count}" -ge 1 || _PRINT_HELP=yes println::error "FATAL ERROR: Not enough positional arguments - we require exactly 1 (namely: $_required_args_string), but got only ${_positionals_count}." 1
	test "${_positionals_count}" -le 1 || _PRINT_HELP=yes println::error "FATAL ERROR: There were spurious positional arguments --- we expect exactly 1 (namely: $_required_args_string), but got ${_positionals_count} (the last one was: '${_last_positional}')." 1
}


assign_positional_args()
{
	local _positional_name _shift_for=$1
	_positional_names="_arg_path "

	shift "$_shift_for"
	for _positional_name in ${_positional_names}
	do
		test $# -gt 0 || break
		eval "$_positional_name=\${1}" || println::error "Error during argument parsing, possibly an Argbash bug." 1
		shift
		_final_args=("$@");
	done
}

parse_commandline "$@"
# handle_passed_args_count
assign_positional_args 1 "${_positionals[@]}"
set -- "${_final_args[@]}" && unset _final_args; # Reset arguments without the pos arg

: "${_arg_path:="$PWD"}";
_arg_path="$(readlink -f "$_arg_path")"; # Pull full path
readonly _arg_path;
readonly _src_dir="$_arg_path/src";
readonly _target_dir="$_arg_path/target";
readonly _target_debug_dir="$_target_dir/debug";
readonly _target_release_dir="$_target_dir/release";

# Start with creating the placeholder target dirs
for _dir in "$_target_debug_dir" "$_target_release_dir"; do
	mkdir -p "$_dir";
done

# Now lets detect the run variant
_build_variant="$(
	if test "$_arg_release" == "on"; then {
		echo "${_target_release_dir##*/}";
	} else {
		echo "${_target_debug_dir##*/}"
	} fi
)"; # TODO: Need to add more cases depending on args.
readonly _build_variant;
readonly _target_workdir="$_target_dir/$_build_variant";

# Now lets escape self arguments and assign run target argument in a variable.
_times=0;
for i in $(
	a=$#;
	until test $a -eq 0; do {
		echo $a;
		((a--));
	} done
); do {
		test $_times -eq 2 && break;
		eval "echo \$$i" | grep -E "\-\-debug|\-\-release" 1>/dev/null && {
			set -- "${@:1:$i-1}" "${@:$i+1}";
			_times=$((_times + 1))
		}
} done

_run_target_args=("$@");
readonly _run_target_args;

# OTHER STUFF GENERATED BY Argbash

### END OF CODE GENERATED BY Argbash (sortof) ### ])
