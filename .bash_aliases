alias ll='ls -lAhtr --group-directories-first'
alias histgrep='history | grep'
alias sudo='sudo '
alias apt='sudo $(which apt)'
alias reboot='sudo $(which reboot)'
alias halt='sudo $(which alias)'
alias poweroff='sudo $(which poweroff)'
alias grep='grep --color'
alias higrep='grep --color=always -e "^" -e '
#alias trashboot='sudo /home/$USER/.local/usr/bin/trashboot.sh'
alias iptables='sudo $(which iptables)'

function negrep(){
#	set -x
	files="${@:--}"
	for fileName in $files
	do 
		printf "\n    #### fileName=%s ####\n\n" ${fileName}
		grep --color=always -n -e "^" -e "^E:" -e "^W:" "${fileName}" \
			| grep --color=always -i \
			"error\|warning\|invalid\|problem\|fail\|fatal\|panic\|not found\|missing\|could not\|unrecognized\|unable\|unavailable\|doh\|not specified\|omitting\|cannot\|No such file\|unknown" 2>&1
		:
	done
#	set +x
}
export -f negrep

function qqbc(){
	echo "scale=${2:-2}; $1" | bc -l
}
export -f qqbc
