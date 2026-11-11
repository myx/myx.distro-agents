📘 syntax: DistroAgentsMonitoring.fn.sh --health [--workspace <path>]
📘 syntax: DistroAgentsMonitoring.fn.sh [--help-syntax [<op>]]
📘 syntax: DistroAgentsMonitoring.fn.sh [--help]

##  Summary:

		The monitoring of a workspace (epic S14, monitoring for magic-devops): the
		health reading over the assets S14 names, the machine, the rig daemons, the
		comms thread, Slack, the flags, the runs and their pace, the comms outbox and
		the team data. Pure tooling: an operator or a supervisor reads it with no
		member in the loop. A member reads the same with AgentMonitoringTools.fn.sh.

##  Options:

  --health [--workspace <path>]
			One reading of the workspace, this one where none is named. Tab-separated
			lines: `health <workspace> <asset> <state> <detail>`, one an asset. An
			`alarm <workspace> <asset> <detail>` line follows a dead daemon or a comms
			outbox backlog over MDAT_MONITORING_OUTBOX_ALARM (1000). While the
			planned-maintenance flag holds (`AgentDispatcherTools --override-flag
			planned-maintenance <ttl>`), an alarm prints as `muted` with the seconds
			left, never dropped. A one-off reading: it starts a handful of processes,
			which a reading asked for once may; nothing of it runs on a pass or a Wait
			round.

##  Notes:

		The trigger that spawns magic-devops on an alarm, the asset inventory of every
		instance and the dashboard panels are S14's open items, not this tool's.
