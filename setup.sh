#!/usr/bin/env bash

# TODO: create SSH key if none exists

function main {
	setup_dot_files
	if is_mac; then
		install_homebrew
		#configure_mac
		brew tap Homebrew/bundle
		brew bundle --no-upgrade --global
		ruby-install --no-reinstall ruby 2.1
		ruby-install --no-reinstall ruby 2.2
		ruby-install --no-reinstall ruby 2.3
		ruby-install --no-reinstall ruby 2.4
	fi
}

function setup_dot_files {
	FRESH_LOCAL_SOURCE=bjeanes/dotfiles bash -c "`curl -sL https://get.freshshell.com`"
	vim +PlugUpdate +qall
	(
	cd ~/.dotfiles
	git submodule update --init
	)
}

# Thanks @mathiasbynens (https://github.com/mathiasbynens/dotfiles/blob/master/.macos)
function sudo {
	sudo -v
	while true; do
		sudo -n true
		sleep 60
		kill -0 "$$" || exit
	done 2>/dev/null &

	function sudo {
		command sudo
	}

	sudo $*
}

function configure_mac {
	# Menu bar: hide the Time Machine, Volume, and User icons
	for domain in ~/Library/Preferences/ByHost/com.apple.systemuiserver.*; do
		defaults write "${domain}" dontAutoLoad -array \
			"/System/Library/CoreServices/Menu Extras/TimeMachine.menu" \
			"/System/Library/CoreServices/Menu Extras/Volume.menu" \
			"/System/Library/CoreServices/Menu Extras/User.menu"
	done

	# Stop iTunes from responding to media keys
	launchctl unload -w /System/Library/LaunchAgents/com.apple.rcd.plist 2>/dev/null

	# TextEdit plain text by default
	defaults write com.apple.TextEdit RichText -int 0
	# Open and save files as UTF-8 in TextEdit
	defaults write com.apple.TextEdit PlainTextEncoding -int 4
	defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4

	configure_keyboard

	# Turn off keyboard backlight when unused for 5 minutes
	defaults write com.apple.BezelServices kDimTime -int 300

	# Disable start up boot sound
	sudo nvram SystemAudioVolume=" "

	# Disable Gatekeeper
	sudo spctl --master-disable

	# Require password to leave screensaver
	defaults write com.apple.screensaver askForPassword -int 1
	defaults write com.apple.screensaver askForPasswordDelay -int 0

	# Speeding up wake from sleep to 24 hours from an hour
	# http://www.cultofmac.com/221392/quick-hack-speeds-up-retina-macbooks-wake-from-sleep-os-x-tips/
	sudo pmset -a standbydelay 86400

	# Enable AirDrop over Ethernet and on Unsupported Macs
	defaults write com.apple.NetworkBrowser BrowseAllInterfaces -bool true

	# Disable Notification Center
	launchctl unload -w /System/Library/LaunchAgents/com.apple.notificationcenterui.plist 2>/dev/null
	killall -9 NotificationCenter 2>/dev/null

	# Install latest shells and set ZSH to default
	if ! brew ls -1 bash 2>/dev/null; then
		brew install bash
		echo $(brew --prefix)/bin/bash  | sudo tee -a /etc/shells
	fi

	if ! brew ls -1 fish 2>/dev/null; then
		brew install fish
		echo $(brew --prefix)/bin/fish  | sudo tee -a /etc/shells
	fi

	if ! brew ls -1 zsh 2>/dev/null; then
		brew install zsh
		echo $(brew --prefix)/bin/zsh  | sudo tee -a /etc/shells
		sudo chsh -s $(brew --prefix)/bin/zsh $USER
	fi

	# Always show scrollbars
	defaults write NSGlobalDomain AppleShowScrollBars -string "Always"

	# Expand save panel by default
	defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
	defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

	# Expand print panel by default
	defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
	defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

	# Save to disk (not to iCloud) by default
	defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

	# Automatically quit printer app once the print jobs complete
	defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

	# Disable the “Are you sure you want to open this application?” dialog
	defaults write com.apple.LaunchServices LSQuarantine -bool false

	# Disable Resume system-wide
	defaults write com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false

	# Set Help Viewer windows to non-floating mode
	defaults write com.apple.helpviewer DevMode -bool true

	# Reveal IP address, hostname, OS version, etc. when clicking the clock
	# in the login window
	sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName

	# Increase sound quality for Bluetooth headphones/headsets
	defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 40

	# Restart automatically if the computer freezes
	sudo systemsetup -setrestartfreeze on

	# Disable the sudden motion sensor as it’s not useful for SSDs
	sudo pmset -a sms 0

	# Enable subpixel font rendering on non-Apple LCDs
	defaults write NSGlobalDomain AppleFontSmoothing -int 2

	# Enable HiDPI display modes (requires restart)
	sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true

	# Finder: disable window animations and Get Info animations
	defaults write com.apple.finder DisableAllAnimations -bool true

	# Set Desktop as the default location for new Finder windows
	# For other paths, use `PfLo` and `file:///full/path/here/`
	defaults write com.apple.finder NewWindowTarget -string "PfDe"
	defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Desktop/"

	# Show icons for hard drives, servers, and removable media on the desktop
	defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
	defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
	defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
	defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

	# Finder: show hidden files by default
	defaults write com.apple.finder AppleShowAllFiles -bool true

	# Finder: show all filename extensions
	defaults write NSGlobalDomain AppleShowAllExtensions -bool true

	# Finder: show status bar
	defaults write com.apple.finder ShowStatusBar -bool true

	# Finder: show path bar
	defaults write com.apple.finder ShowPathbar -bool true

	# Display full POSIX path as Finder window title
	defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

	# Keep folders on top when sorting by name
	defaults write com.apple.finder _FXSortFoldersFirst -bool true

	# When performing a search, search the current folder by default
	defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

	# Disable the warning when changing a file extension
	defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

	# Enable spring loading for directories
	defaults write NSGlobalDomain com.apple.springing.enabled -bool true

	# Remove the spring loading delay for directories
	defaults write NSGlobalDomain com.apple.springing.delay -float 0

	# Avoid creating .DS_Store files on network or USB volumes
	defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
	defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

	# Automatically open a new Finder window when a volume is mounted
	defaults write com.apple.frameworks.diskimages auto-open-ro-root -bool true
	defaults write com.apple.frameworks.diskimages auto-open-rw-root -bool true
	defaults write com.apple.finder OpenWindowForNewRemovableDisk -bool true

	# Show item info near icons on the desktop and in other icon views
	/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:showItemInfo true" ~/Library/Preferences/com.apple.finder.plist
	/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:showItemInfo true" ~/Library/Preferences/com.apple.finder.plist
	/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:showItemInfo true" ~/Library/Preferences/com.apple.finder.plist

	# Show item info to the right of the icons on the desktop
	/usr/libexec/PlistBuddy -c "Set DesktopViewSettings:IconViewSettings:labelOnBottom false" ~/Library/Preferences/com.apple.finder.plist

	# Enable snap-to-grid for icons on the desktop and in other icon views
	/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
	/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
	/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist

	# Increase grid spacing for icons on the desktop and in other icon views
	/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:gridSpacing 100" ~/Library/Preferences/com.apple.finder.plist
	/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:gridSpacing 100" ~/Library/Preferences/com.apple.finder.plist
	/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:gridSpacing 100" ~/Library/Preferences/com.apple.finder.plist

	# Increase the size of icons on the desktop and in other icon views
	/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:iconSize 80" ~/Library/Preferences/com.apple.finder.plist
	/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:iconSize 80" ~/Library/Preferences/com.apple.finder.plist
	/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:iconSize 80" ~/Library/Preferences/com.apple.finder.plist

	# Use list view in all Finder windows by default
	# Four-letter codes for the other view modes: `icnv`, `clmv`, `Flwv`
	defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

	# Show the ~/Library folder
	chflags nohidden ~/Library

	# Show the /Volumes folder
	sudo chflags nohidden /Volumes

	# Expand the following File Info panes:
	# “General”, “Open with”, and “Sharing & Permissions”
	defaults write com.apple.finder FXInfoPanesExpanded -dict \
		General -bool true \
		OpenWith -bool true \
		Privileges -bool true

	# Set the icon size of Dock items to 36 pixels
	defaults write com.apple.dock tilesize -int 36

	# Minimize windows into their application’s icon
	defaults write com.apple.dock minimize-to-application -bool true

	# Enable spring loading for all Dock items
	defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true

	# Show indicator lights for open applications in the Dock
	defaults write com.apple.dock show-process-indicators -bool true

	# Wipe all (default) app icons from the Dock
	defaults write com.apple.dock persistent-apps -array

	# Show only open applications in the Dock
	defaults write com.apple.dock static-only -bool true

	# Speed up Mission Control animations
	defaults write com.apple.dock expose-animation-duration -float 0.1

	# Disable Dashboard
	defaults write com.apple.dashboard mcx-disabled -bool true

	# Don’t show Dashboard as a Space
	defaults write com.apple.dock dashboard-in-overlay -bool true

	# Don’t automatically rearrange Spaces based on most recent use
	defaults write com.apple.dock mru-spaces -bool false

	# Remove the auto-hiding Dock delay
	defaults write com.apple.dock autohide-delay -float 0
	# Remove the animation when hiding/showing the Dock
	defaults write com.apple.dock autohide-time-modifier -float 0

	# Automatically hide and show the Dock
	defaults write com.apple.dock autohide -bool true

	# Make Dock icons of hidden applications translucent
	defaults write com.apple.dock showhidden -bool true

	# Disable the Launchpad gesture (pinch with thumb and three fingers)
	defaults write com.apple.dock showLaunchpadGestureEnabled -int 0

	# Privacy: don’t send search queries to Apple
	defaults write com.apple.Safari UniversalSearchEnabled -bool false
	defaults write com.apple.Safari SuppressSearchSuggestions -bool true

	# Press Tab to highlight each item on a web page
	defaults write com.apple.Safari WebKitTabToLinksPreferenceKey -bool true
	defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks -bool true

	# Prevent Safari from opening ‘safe’ files automatically after downloading
	defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

	# Show the full URL in the address bar (note: this still hides the scheme)
	defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

	# Set Safari’s home page to `about:blank` for faster loading
	defaults write com.apple.Safari HomePage -string "about:blank"

	# Hide Safari’s bookmarks bar by default
	defaults write com.apple.Safari ShowFavoritesBar -bool false

	# Hide Safari’s sidebar in Top Sites
	defaults write com.apple.Safari ShowSidebarInTopSites -bool false

	# Enable Safari’s debug menu
	defaults write com.apple.Safari IncludeInternalDebugMenu -bool true

	# Make Safari’s search banners default to Contains instead of Starts With
	defaults write com.apple.Safari FindOnPageMatchesWordStartsOnly -bool false

	# Enable the Develop menu and the Web Inspector in Safari
	defaults write com.apple.Safari IncludeDevelopMenu -bool true
	defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
	defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

	# Add a context menu item for showing the Web Inspector in web views
	defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

	# Enable continuous spellchecking
	defaults write com.apple.Safari WebContinuousSpellCheckingEnabled -bool true

	# Disable auto-correct
	defaults write com.apple.Safari WebAutomaticSpellingCorrectionEnabled -bool false

	# Disable AutoFill
	defaults write com.apple.Safari AutoFillFromAddressBook -bool false
	defaults write com.apple.Safari AutoFillPasswords -bool false
	defaults write com.apple.Safari AutoFillCreditCardData -bool false
	defaults write com.apple.Safari AutoFillMiscellaneousForms -bool false

	# Warn about fraudulent websites
	defaults write com.apple.Safari WarnAboutFraudulentWebsites -bool true

	# Update extensions automatically
	defaults write com.apple.Safari InstallExtensionUpdatesAutomatically -bool true

	# Only use UTF-8 in Terminal.app
	defaults write com.apple.terminal StringEncodings -array 4

	# Enable Secure Keyboard Entry in Terminal.app
	# See: https://security.stackexchange.com/a/47786/8918
	defaults write com.apple.terminal SecureKeyboardEntry -bool true

	# Prevent Time Machine from prompting to use new hard drives as backup volume
	defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

	# Disable local Time Machine backups
	hash tmutil &> /dev/null && sudo tmutil disablelocal

	# Enable the automatic update check
	defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

	# Check for software updates daily, not just once per week
	defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

	# Download newly available updates in background
	defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1

	# Install System data files & security updates
	defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1

	# Turn on app auto-update
	defaults write com.apple.commerce AutoUpdate -bool true

	# Prevent Photos from opening automatically when devices are plugged in
	defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

	# Disable smart quotes as it’s annoying for messages that contain code
	defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "automaticQuoteSubstitutionEnabled" -bool false

	# Disable continuous spell checking
	defaults write com.apple.messageshelper.MessageController SOInputLineSettings -dict-add "continuousSpellCheckingEnabled" -bool false

	for app in "Activity Monitor"  "cfprefsd" "Dock" "Finder" "Messages" \
		"Safari" "SystemUIServer" "Terminal"; do
		killall "${app}" &> /dev/null
	done
}

function configure_trackpad {
	# Trackpad: enable tap to click for this user and for the login screen
	defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
	defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
	defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

	defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
	defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true
}

function configure_keyboard {
	# Don't press-and-hold for auto-correct
	defaults write -g ApplePressAndHoldEnabled -bool false

	# Make all UI tabbable
	defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

	# Disable auto-correct
	defaults write -g NSAutomaticSpellingCorrectionEnabled -bool false

	# Disable smart quotes as they’re annoying when typing code
	defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

	# Disable smart dashes as they’re annoying when typing code
	defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

	# Set language and text formats
	defaults write NSGlobalDomain AppleLanguages -array "en-AU"
	defaults write NSGlobalDomain AppleLocale -string "en-AU"
	defaults write NSGlobalDomain AppleMeasurementUnits -string "Centimeters"
	defaults write NSGlobalDomain AppleMetricUnits -bool true

}

function configure_developer_mode_in_safari {
	defaults write com.apple.Safari IncludeInternalDebugMenu -bool true && \
		defaults write com.apple.Safari IncludeDevelopMenu -bool true && \
		defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true && \
		defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true && \
		defaults write -g WebKitDeveloperExtras -bool true
}

function is_mac {
	[[ "$OSTYPE" == "darwin"* ]]
}

function install_homebrew {
	command -v brew && return
	is_mac || return

	/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
}

main
