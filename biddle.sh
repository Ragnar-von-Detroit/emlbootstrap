#!/bin/bash
user_level_defaults() {
    local user="$1"
    local userpath=/Users/"$user"
    local pref_path="$userpath/Library/Preferences"

    ###############################################################################
    # UI
    ###############################################################################
    #Automatically quit printer app once the print jobs complete
    sudo defaults write "$pref_path/"com.apple.print.PrintingPrefs "Quit When Finished" -bool true

    # Set Help Viewer windows to non-floating mode
    sudo defaults write "$pref_path/"com.apple.helpviewer DevMode -bool true

    #Disable the menubar transparency
    sudo defaults write "$pref_path/"com.apple.universalaccess reduceTransparency -bool true

    # Prevent Time Machine from prompting to use new hard drives as backup volume
    sudo defaults write "$pref_path/"com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

    for domain in "$pref_path/"ByHost/com.apple.systemuiserver.*; do
      sudo defaults write "${domain}" dontAutoLoad -array \
        "/System/Library/CoreServices/Menu Extras/TimeMachine.menu" \
        "/System/Library/CoreServices/Menu Extras/Airport.menu" \
        "/System/Library/CoreServices/Menu Extras/Bluetooth.menu"
    done

    ###############################################################################
    # Finder
    ###############################################################################

    # Show icons for hard drives, servers, and removable media on the desktop
    sudo defaults write "$pref_path/"com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
    sudo defaults write "$pref_path/"com.apple.finder ShowHardDrivesOnDesktop -bool true
    sudo defaults write "$pref_path/"com.apple.finder ShowMountedServersOnDesktop -bool true
    sudo defaults write "$pref_path/"com.apple.finder ShowRemovableMediaOnDesktop -bool true

    #Show status bar in Finder by default
    sudo defaults write "$pref_path/"com.apple.finder ShowStatusBar -bool true

    #Display full POSIX path as Finder window title
    sudo defaults write "$pref_path/"com.apple.finder _FXShowPosixPathInTitle -bool true

    #Disable the warning when changing a file extension
    sudo defaults write "$pref_path/"com.apple.finder FXEnableExtensionChangeWarning -bool false

    #Use list view in all Finder windows by default
    sudo defaults write "$pref_path/"com.apple.finder FXPreferredViewStyle -string "Nlsv"

    # When performing a search, search the current folder by default
    sudo defaults write "$pref_path/"com.apple.finder FXDefaultSearchScope -string "SCcf"

    # Automatically open a new Finder window when a volume is mounted
    sudo defaults write "$pref_path/"com.apple.frameworks.diskimages auto-open-ro-root -bool true
    sudo defaults write "$pref_path/"com.apple.frameworks.diskimages auto-open-rw-root -bool true
    sudo defaults write "$pref_path/"com.apple.finder OpenWindowForNewRemovableDisk -bool true

    # Finder: disable window animations and Get Info animations
    sudo defaults write "$pref_path/"com.apple.finder DisableAllAnimations -bool true

    #Avoid creation of .DS_Store files on network volumes
    sudo defaults write "$pref_path/"com.apple.desktopservices DSDontWriteNetworkStores -bool true

    #Allow text selection in Quick Look/Preview in Finder by default
    sudo defaults write "$pref_path/"com.apple.finder QLEnableTextSelection -bool true

    # Expand the following File Info panes:
    # “General”, “Open with”, and “Sharing & Permissions”
    sudo defaults write "$pref_path/"com.apple.finder FXInfoPanesExpanded -dict \
      General -bool true \
      OpenWith -bool true \
      Privileges -bool true


    ###############################################################################
    # Dock, Dashboard,
    ###############################################################################
    #Most dock behaviour is controlled through Docktuil, which was installed by brew
    #during bootstrap

    # Enable highlight hover effect for the grid view of a stack (Dock)
    sudo defaults write "$pref_path/"com.apple.dock mouse-over-hilite-stack -bool true

    # Set the icon size of Dock items to 36 pixels
    sudo defaults write "$pref_path/"com.apple.dock tilesize -int 36

    # Change minimize/maximize window effect
    sudo defaults write "$pref_path/"com.apple.dock mineffect -string "scale"

    # Disable Dashboard
    sudo defaults write "$pref_path/"com.apple.dashboard mcx-disabled -bool true

    # Don’t show Dashboard as a Space
    sudo defaults write "$pref_path/"com.apple.dock dashboard-in-overlay -bool true

    # Disable spaces and Mission Contol
    sudo defaults write "$pref_path/"com.apple.dock mcx-expose-disabled -bool TRUE && killall Dock

    # Disable the Launchpad gesture (pinch with thumb and three fingers)
    sudo defaults write "$pref_path/"com.apple.dock showLaunchpadGestureEnabled -int 0

    # Automatically hide and show the Dock
    sudo defaults write "$pref_path/"com.apple.dock autohide -bool true

    # Hot corners
    # Possible values:
    #  0: no-op
    #  2: Mission Control
    #  3: Show application windows
    #  4: Desktop
    #  5: Start screen saver
    #  6: Disable screen saver
    #  7: Dashboard
    # 10: Put display to sleep
    # 11: Launchpad
    # 12: Notification Center
    sudo defaults write "$pref_path/"com.apple.dock wvous-tr-corner -int 3
    sudo defaults write "$pref_path/"com.apple.dock wvous-tr-modifier -int 0
    sudo defaults write "$pref_path/"com.apple.dock wvous-tl-corner -int 4
    sudo defaults write "$pref_path/"com.apple.dock wvous-tl-modifier -int 0

    sudo defaults write "$pref_path/"com.apple.dock wvous-br-corner -int 5
    sudo defaults write "$pref_path/"com.apple.dock wvous-br-modifier -int 0
    sudo defaults write "$pref_path/"com.apple.dock wvous-bl-corner -int 10
    sudo defaults write "$pref_path/"com.apple.dock wvous-bl-modifier -int 0

    ###############################################################################
    # Chrome, Safari, & WebKit
    ###############################################################################

    #Privacy: Don’t send search queries to Apple
    sudo defaults write "$pref_path/"com.apple.Safari UniversalSearchEnabled -bool false
    sudo defaults write "$pref_path/"com.apple.Safari SuppressSearchSuggestions -bool true

    #Hiding Safari's bookmarks bar by default
    sudo defaults write "$pref_path/"com.apple.Safari ShowFavoritesBar -bool false

    #Hiding Safari's sidebar in Top Sites
    sudo defaults write "$pref_path/"com.apple.Safari ShowSidebarInTopSites -bool false

    #Disabling Safari's thumbnail cache for History and Top Sites
    sudo defaults write "$pref_path/"com.apple.Safari DebugSnapshotsUpdatePolicy -int 2

    #Making Safari's search banners default to Contains instead of Starts With
    sudo defaults write "$pref_path/"com.apple.Safari FindOnPageMatchesWordStartsOnly -bool false

    #Removing useless icons from Safari's bookmarks bar
    sudo defaults write "$pref_path/"com.apple.Safari ProxiesInBookmarksBar "()"

    #Disabling the annoying backswipe in Chrome
    sudo defaults write "$pref_path/"com.google.Chrome AppleEnableSwipeNavigateWithScrolls -bool false

    #Using the system-native print preview dialog in Chrome
    sudo defaults write "$pref_path/"com.google.Chrome DisablePrintPreview -bool true

    # Expand the print dialog by default in Chrome
    sudo defaults write "$pref_path/"com.google.Chrome PMPrintingExpandedStateForPrint2 -bool true

    ###############################################################################
    # Spectacle.app                                                               #
    ###############################################################################

    sudo defaults write "$pref_path/"com.divisiblebyzero.Spectacle MakeLarger -data 62706c6973743030d40102030405061819582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708101155246e756c6cd4090a0b0c0d0e0d0f596d6f64696669657273546e616d65576b6579436f64655624636c6173731000800280035a4d616b654c6172676572d2121314155a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21617585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11a1b54726f6f74800108111a232d32373c424b555a62696b6d6f7a7f8a939c9fa8b1c3c6cb0000000000000101000000000000001c000000000000000000000000000000cd
    sudo defaults write "$pref_path/"com.divisiblebyzero.Spectacle MakeSmaller -data 62706c6973743030d40102030405061819582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708101155246e756c6cd4090a0b0c0d0e0d0f596d6f64696669657273546e616d65576b6579436f64655624636c6173731000800280035b4d616b65536d616c6c6572d2121314155a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21617585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11a1b54726f6f74800108111a232d32373c424b555a62696b6d6f7b808b949da0a9b2c4c7cc0000000000000101000000000000001c000000000000000000000000000000ce
    sudo defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToBottomHalf -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002107d80035f10104d6f7665546f426f74746f6d48616c66d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e7072858a959ea7aab3bcced1d60000000000000101000000000000001d000000000000000000000000000000d8
    sudo defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToCenter -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002100880035c4d6f7665546f43656e746572d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e70727f848f98a1a4adb6c8cbd00000000000000101000000000000001d000000000000000000000000000000d2
    sudo defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToFullscreen -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002103180035f10104d6f7665546f46756c6c73637265656ed2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e7072858a959ea7aab3bcced1d60000000000000101000000000000001d000000000000000000000000000000d8
    sudo defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToLeftHalf -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002107b80035e4d6f7665546f4c65667448616c66d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e70728186919aa3a6afb8cacdd20000000000000101000000000000001d000000000000000000000000000000d4
    sudo defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToLowerLeft -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c617373111a008002107b80035f100f4d6f7665546f4c6f7765724c656674d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e70728489949da6a9b2bbcdd0d50000000000000101000000000000001d000000000000000000000000000000d7
    sudo defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToLowerRight -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c617373111a008002107d80035f10104d6f7665546f4c6f7765725269676874d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e7072858a959ea7aab3bcced1d60000000000000101000000000000001d000000000000000000000000000000d8
    sudo defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToNextDisplay -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731111008002107c80035f10114d6f7665546f4e657874446973706c6179d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e7072868b969fa8abb4bdcfd2d70000000000000101000000000000001d000000000000000000000000000000d9
    sudo defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToNextThird -data 62706c6973743030d40102030405061819582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708101155246e756c6cd4090a0b0c0d0e0d0f596d6f64696669657273546e616d65576b6579436f64655624636c6173731000800280035f100f4d6f7665546f4e6578745468697264d2121314155a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21617585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11a1b54726f6f74800108111a232d32373c424b555a62696b6d6f8186919aa3a6afb8cacdd20000000000000101000000000000001c000000000000000000000000000000d4
    sudo defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToPreviousDisplay -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731111008002107b80035f10154d6f7665546f50726576696f7573446973706c6179d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e70728a8f9aa3acafb8c1d3d6db0000000000000101000000000000001d000000000000000000000000000000dd
    sudo defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToPreviousThird -data 62706c6973743030d40102030405061819582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708101155246e756c6cd4090a0b0c0d0e0d0f596d6f64696669657273546e616d65576b6579436f64655624636c6173731000800280035f10134d6f7665546f50726576696f75735468697264d2121314155a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21617585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11a1b54726f6f74800108111a232d32373c424b555a62696b6d6f858a959ea7aab3bcced1d60000000000000101000000000000001c000000000000000000000000000000d8
    sudo defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToRightHalf -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002107c80035f100f4d6f7665546f526967687448616c66d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e70728489949da6a9b2bbcdd0d50000000000000101000000000000001d000000000000000000000000000000d7
    sudo defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToTopHalf -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c6173731119008002107e80035d4d6f7665546f546f7048616c66d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e707280859099a2a5aeb7c9ccd10000000000000101000000000000001d000000000000000000000000000000d3
    sudo defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToUpperLeft -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c617373111a008002107e80035f100f4d6f7665546f55707065724c656674d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e70728489949da6a9b2bbcdd0d50000000000000101000000000000001d000000000000000000000000000000d7
    sudo defaults write "$pref_path/"com.divisiblebyzero.Spectacle MoveToUpperRight -data 62706c6973743030d4010203040506191a582476657273696f6e58246f626a65637473592461726368697665725424746f7012000186a0a40708111255246e756c6cd4090a0b0c0d0e0f10596d6f64696669657273546e616d65576b6579436f64655624636c617373111a008002107c80035f10104d6f7665546f55707065725269676874d2131415165a24636c6173736e616d655824636c6173736573585a4b486f744b6579a21718585a4b486f744b6579584e534f626a6563745f100f4e534b657965644172636869766572d11b1c54726f6f74800108111a232d32373c424b555a62696c6e7072858a959ea7aab3bcced1d60000000000000101000000000000001d000000000000000000000000000000d8
    #run Spectacle in the background
    sudo defaults write "$pref_path/"com.divisiblebyzero.Spectacle StatusItemEnabled -int 0

    sudo chown "$user" "$pref_path"
}
