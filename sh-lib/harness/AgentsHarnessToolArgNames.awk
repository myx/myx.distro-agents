#!/usr/bin/env awk

# Run AFTER the field reader, on the wire adapter as AgentsHarnessTaskArgsFill.awk leaves it:
#   LC_ALL=C awk -f AgentsHarnessTaskArgsFill.awk <wire> | LC_ALL=C awk -f AgentsHarnessJsonField.awk -f AgentsHarnessToolArgNames.awk
# Prints one line a declared tool, its name, a TAB and its parameters, space-separated: the keys of its parameters.properties.
# rc 1, nothing printed, when the harnessToolsJson literal is absent or does not parse.
# The reader takes an object, so the array is read as the value of one key. LC_ALL=C IS REQUIRED: its offsets are bytes.

BEGIN {
	jfLibrary = 1 ;
	namesQuote = "'" ;
}

index($0, "harnessToolsJson=" namesQuote) == 1 {
	jfDocReset() ;
	jfDocLine("{\"tools\":" substr($0, length("harnessToolsJson=" namesQuote) + 1)) ;
	namesOn = 1 ;
	next ;
}

namesOn && $0 == "]" namesQuote {
	jfDocLine("]}") ;
	namesOn = 0 ;
	namesEnded = 1 ;
	next ;
}

namesOn {
	jfDocLine($0) ;
}

function jfNodeHook(hookPath, hookType, hookValue, hookFrom, hookTo,   hookPart, hookParts) {
	hookParts = split(hookPath, hookPart, ".") ;
	if (hookParts == 4 && hookPart[3] == "function" && hookPart[4] == "name") {
		namesTool[hookPart[2]] = hookValue ;
	} else if (hookParts == 6 && hookPart[3] == "function" && hookPart[4] == "parameters" && hookPart[5] == "properties") {
		namesArgs[hookPart[2]] = (hookPart[2] in namesArgs) ? namesArgs[hookPart[2]] " " hookPart[6] : hookPart[6] ;
	}
}

END {
	if (!namesEnded || jfDocConsume() != 0) exit 1 ;
	for (namesAt in namesTool) {
		printf "%s\t%s\n", namesTool[namesAt], namesArgs[namesAt] ;
	}
}
