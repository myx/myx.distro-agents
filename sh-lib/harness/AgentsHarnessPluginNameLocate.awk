#!/usr/bin/env awk
# Prints the plugin root directory whose own plugin.json "name" field matches wantName.
{
	pluginFile = $0 ; pluginName = ""
	while ( ( getline jsonLine < pluginFile ) > 0 ) {
		if ( jsonLine !~ /"name"[ \t]*:/ ) continue
		pluginName = jsonLine ; sub(/^[^:]*:[ \t]*"/, "", pluginName) ; sub(/".*$/, "", pluginName) ;
		break
	}
	close(pluginFile)
	if ( pluginName == wantName ) { sub(/\/\.claude-plugin\/plugin\.json$/, "", pluginFile) ; print pluginFile ; exit ; }
}
