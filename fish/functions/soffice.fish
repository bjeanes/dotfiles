function soffice --description 'Start soffice in headless mode on port 2002'
	cd /Applications/OpenOffice.org.app/Contents/program
	killall soffice >/dev/null ^/dev/null
	screen -dm ./soffice -accept="socket,host=localhost,port=2002;urp" -nofirststartwizard $argv
	cd -
end
