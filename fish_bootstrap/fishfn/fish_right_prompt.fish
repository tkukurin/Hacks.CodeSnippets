function fish_right_prompt
  set_color $fish_color_autosuggestion 2> /dev/null; or set_color 555

	# if using vim mode, show the mode on RHS
	if [ $fish_key_bindings = fish_vi_key_bindings ]
		switch $fish_bind_mode
			case default
				# set_color --bold red
				echo 'N '
			case insert
				# set_color --bold green
				echo 'I '
			case replace_one
				# set_color --bold green
				echo 'R '
			case visual
				# set_color --bold brmagenta
				echo 'V '
			case '*'
				# set_color --bold red
				echo '?'
		end
		echo "| "
  end

  date "+%H:%M"
  set_color normal
end

