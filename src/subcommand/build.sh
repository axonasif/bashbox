function subcommand::build()
{
	print_help()
	{
		println::helpgen ${_self_name^^}-${_subcommand_argv^^} \
			--short-desc "\
${SUBCOMMANDS_DESC[3]}\
" \
	\
			--usage "\
${_self_name} ${_subcommand_argv} [OPTIONAL-OPTIONS] <path>\
" \
	\
			--options-desc "\
--release<^>Build in release mode
--debug<^>Build in debug mode(default)
--run<^>Auto-run the executable after build
--<^>Pass arguments to your compiled program
-h, --help<^>Prints this help information\
" \
	\
			--examples "\
### The basic way:
# Buld the project in your current directory hierarchy in release-mode
${YELLOW}${_self_name} ${_subcommand_argv} --release${RC}

### Build project from a specified directory:
${YELLOW}${_self_name} ${_subcommand_argv} --release /home/me/awesome_project${RC}

### Pass arguments to the compiled executable and auto-run it after build
${YELLOW}${_self_name} ${_subcommand_argv} --release --release -- arg1 arg2 \"string arg\" and-so-on${RC}
"

	}
	use _clap;
		
	Resolve::Colons() {
		 awk '{$1=$1;print}' <<<"$1" \
		 	| sed "s|^use box::||; s|^use ||; s|;$||; s|::|/|g; s|/\*$||"; # Swap `::` with `/` and remove [`use `, `/*` `;`] keywords
	}

	Resolve::SymbolPath() {
		local _input="$1";
		local _parent;
		_parent="$(
			if grep "^use box::" <<<"$_input" 1>/dev/null; then
				echo "$_src_dir";
			else
				echo "$PWD";
			fi
		)"
		echo "$_parent/$(Resolve::Colons "$_input")"		
	}

	Resolve::IsMain() {
		if test "$_target_workdir/main" == "$_input"; then {
			true;
		} else {
			false;
		} fi
	}

	Resolve::UseSymbols() {
		# TODO: Implement BASHBOX_LIB_PATH
		# TODO: This is an absolute hell, needs a rewrite.
		local _input="$1";
		if Resolve::IsMain; then {
			_input="main";
		} fi
		local _parsed_input && _parsed_input="$(Resolve::Colons "$_input")";
		local _parsed_input_name="${_parsed_input##*/}" && {
			local _modname="${_parsed_input_name}";
			_parsed_input="$(sed "s|${_parsed_input_name}$|${_parsed_input_name#_}|" <<<"$_parsed_input")";
			# _parsed_input="$(readlink -f "$_parsed_input")";
			unset _parsed_input_name;
		}
		local _ref="_usemol_${_parsed_input%%/*}";
		local _src && {
			if grep 'use box::' <<<"$_input" 1>/dev/null; then {
				_src="$_target_workdir";	
			} elif test -v "$_ref"; then {
				_src="${!_ref}";
				_parsed_input="${_parsed_input#*/}";
			# } elif grep 'use std::' <<<"$_input" 1>/dev/null; then {
			# 	_src="$_bashbox_registrydir";
			} else {
				_src="$PWD";
			} fi

			_parsed_input="$_src/$_parsed_input";
		}

		if test "$_arg_verbose" == "off"; then {
			geco "   ${BGREEN}Compiling${RC} $_modname";
		} else {
			geco "---------- $_modname"; # DEBUG
		} fi
		if test "${_modname::1}" == "_" \
		|| ! grep "^${_parsed_input}.sh$" "$_used_symbols_statfile" 1>/dev/null; then {
			

				# Handle missing symbols
				# echo "Parsed_input: $_parsed_input"; # DEBUG
				if test ! -e "${_parsed_input}.sh" && test ! -e "${_parsed_input}"; then {
					# echo "$PWD"
					println::error "$_input is missing" 1;
				} fi

				# Handle wildcard symbol loading
				if grep '\*;$' <<<"$(awk '{$1=$1;print}' <<<"$_input")" 1>/dev/null; then {
					# if test -e "$_compiled_mod_bundle"; then {
					# 	rm "$_compiled_mod_bundle";
					# } fi
					for _modFile in "$_parsed_input/"*; do {
						io::file::check_newline "$_modFile";
					} done
					cat "$_parsed_input/"* > "$_compiled_mod_bundle.sh";
					_parsed_input="$_compiled_mod_bundle";
				} elif test ! -e "${_parsed_input}.sh" && test -d "$_parsed_input"; then { # Handle module directory if required
					_parsed_input="$_parsed_input/mod"; # Redirect to the module file instead
				} fi


				cd "$(dirname "$_parsed_input")";

				if test "$_arg_verbose" == "on"; then {
					geco "${RED}PWD${RC}: $PWD"; # DEBUG
					geco "${CYAN}File${RC}: ${_parsed_input}.sh"; # DEBUG
				} fi

				mapfile -t _use_symbols < <(grep -E 'use .*;$' "${_parsed_input}.sh" | grep -v '#' | awk '{$1=$1;print}' || true); # Grep might fail, which is why `|| true` is necessary

				# Cycle through main.sh symbols and so on.
				# local _last_parsed_input;
				: ${_last_parsed_input:="${_parsed_input}"};

				if test "$_arg_verbose" == "on"; then {
					geco "${PURPLE}Caller${RC}: $_last_parsed_input\n";
				} fi
				
				for _symbol in "${_use_symbols[@]}"; do
					(
						_last_parsed_input="${_parsed_input}";
						Resolve::UseSymbols "$_symbol";
					)
				done
			
				# Start merging process
				# File names come in reversed order
				if test "${_parsed_input}.sh" != "${_last_parsed_input}.sh"; then {
					io::file::check_newline "${_parsed_input}.sh";
					sed -i -e "/$(sed 's|*|\\*|g' <<<${_input})/{r ${_parsed_input}.sh" -e 'd}' "${_last_parsed_input}.sh";
					#		TARGET-TEXT		FILE-TO-INSERT		   	INPUT-FILE
					# cat "${_parsed_input}.sh" >> "${_last_parsed_input}.sh";
				} fi
				echo "${_parsed_input}.sh" >> "$_used_symbols_statfile";
				if test "$_arg_verbose" == "on"; then {
					echo "$_parsed_input.sh ++ ${_last_parsed_input}.sh($_input)";
				} fi
				
			
		} fi
	}

	# Source project build.sh
	if test -e "$_arg_path/build.sh"; then {
		source "$_arg_path/build.sh";
		if declare -f bashbox_before_build | head -n0; then { # Will fail without pipefail
			bashbox_before_build;
		} fi
	} fi

	# Define Vars
	cd "$_target_workdir";
	Resolve::UseSymbols "$_target_workdir/main";

	# Concatinate bootstrap header to main.sh
	local _bb_bootstrap;
	_bb_bootstrap=$(declare -f bb_bootstrap_header) && {
		_bb_bootstrap="${_bb_bootstrap#*{}";
		_bb_bootstrap="${_bb_bootstrap%\}}";
	}
	local _ran="$RANDOM";
	local _tmp_bbb_path="$_target_workdir/.bb_bootstrap.$_ran";
	echo '#!'"$(command -v env) bash" > "$_tmp_bbb_path"; # Place shebang
	# Add some variables
	cat << 'EOF' >> "$_tmp_bbb_path"
___self="$0";
EOF
	declare -f 'println::error'	>> "$_tmp_bbb_path"; # Concate println:error
	echo "${_bb_bootstrap}"	>> "$_tmp_bbb_path"; # Concat bootstrap
	cat "$_bashbox_meta" >> "$_tmp_bbb_path"; # Concat Bashbox.meta
	cat "$_tmp_bbb_path" "$_target_workdir/main.sh" > "$_target_workfile"; # Merge main.sh with generated script
	
	# Concat main execution call
	cat << 'EOF' >> "$_target_workfile"

main "$@";

EOF
	
	if test "$_build_variant" == "release"; then {
		local _shebang;
		local _zygote_name="main@bashbox%${_ran}";
		local _tmp_bashfmt="$_target_workdir/.bb.fmt.$_ran";
		geco "function ${_zygote_name}() {" > "$_tmp_bashfmt";
		cat "$_target_workfile" >> "$_tmp_bashfmt";
		geco "\n}" >> "$_tmp_bashfmt";
		source "$_tmp_bashfmt";

		_shebang="$(grep "#\!/.*" "$_target_workfile" | head -n1)";
		geco "$_shebang" > "$_target_workfile";
		declare -f "$_zygote_name" >> "$_target_workfile";
		geco "\n${_zygote_name} \"\$@\";" >> "$_target_workfile";
		rm "$_tmp_bashfmt";
	} fi

	rm "$_tmp_bbb_path";

	# Run build.sh after actions
	if declare -f bashbox_after_build | head -n0; then { # Will fail without pipefail
		bashbox_after_build;
	} fi

	# Make it executable by the user
	chmod +x "$_target_workfile";
	
	# Print success message
	if test "$_arg_verbose" == "off"; then {
		local _is_optimized;
		_is_optimized=$(
			if test "$_build_variant" == "release"; then {
				echo "optimized"
			} else {
				echo "unoptimized + debuginfo"
			} fi
		);

		geco "   ${BGREEN}Finished${RC} $_build_variant [${_is_optimized}] target(s) in ${SECONDS}s"

		unset _is_optimized;
	} fi

	# Run the executable if _arg_run is passed
	if test "$_arg_run" == "on"; then {
		"$_target_workfile" "${_run_target_args[@]}";
	} fi

	# set -x
	# geco '\n------'
	# _used_symbols_arr_length="${#_used_symbols_arr[@]}";
	# # _used_symbols_times=0;
	# for _arr in "${_used_symbols_arr[@]}"; do {

	# 	while test $_used_symbols_arr_length -ne 0; do {
	# 		_used_symbols_arr_length=$((_used_symbols_arr_length - 1));
	# 		_used_symbols_times=$((_used_symbols_times + 1));
	# 		_used_symbols_times_next=$((_used_symbols_times + 1));

	# 		echo "Last: ${_used_symbols_arr[-${_used_symbols_times_next}]}"

	# 		# cat "${_used_symbols_arr[-1 -${_used_symbols_times}]}" "${_used_symbols_arr[-1]}";

	# 		break;
	# 	} done

	# } done

}
