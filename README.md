# Testaustime Scripts for Great Good!

## Destroyer aka Data destroyer (Ruby)

Born from the realization I was faced with curling enormous amount of trash data after tinkering with a browser addon. Despite it's name, it is very well behaved and user friendly. Have a look, it won't destroy your data without asking first. It also has a feature to view raw data sent to Testaustime, handy when doing scripts. You can search for certain projects, even with multiple search words (comma separated). Search is OR by default but there are comments if you want to change it to AND search. 

## Selopticon (Bash)

Selectively seeing eye to track your coding activity even when using very light weight editors like Xed, Mousepad, Geany, Gedit.. Actually you can track any app that has a window and a title. This script needs also `xdotool` and `xprintidle` but they are most likely found in your repository, and it works only on X11. Modify settings to your liking; list apps and languages you are likely to use and also add Testaustime auth token, to actually send data. (It works just fine also without auth token and _does not_ say it, until it's too late). Polling interval is just how often you like information of current state, it's advisable to keep max in 30 seconds to allow the heartbeats to be sent in a timely manner.
