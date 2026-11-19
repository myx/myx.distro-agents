package ru.myx.ae3.probe;

import java.io.File;

import ru.myx.ae3.Engine;
import ru.myx.ae3.vfs.s4.common.S4StoreType;
import ru.myx.ae3.vfs.s4.lcl.S4LocalDriver;

/**
 * start() then stop() on the bdbje local S4 driver. The fault is a stop that leaves the
 * environment's transactions open. The probe says what each call did and exits non-zero when stop
 * failed, so a green run is the whole probe passing.
 *
 * Arguments: the AE3 workspace root (holding acm-cvs/sys-current), and a storage folder of its own.
 */
public class Ae3BdbjStartStopProbe {

	public static void main(final String[] args) throws Exception {

		final File storage = new File(args[1]);
		new File(storage, "protected").mkdirs();
		new File(storage, "private").mkdirs();
		new File(storage, "shared").mkdirs();
		System.setProperty("ae3", "initialized");
		System.setProperty("ru.myx.ae3.properties.vfs.storage", "ramfs:storage");
		System.setProperty("ru.myx.ae3.properties.path.public", args[0] + "/acm-cvs/sys-current");
		System.setProperty("ru.myx.ae3.properties.path.protected", new File(storage, "protected").getAbsolutePath());
		System.setProperty("ru.myx.ae3.properties.path.private", new File(storage, "private").getAbsolutePath());
		System.setProperty("ru.myx.ae3.properties.path.shared", new File(storage, "shared").getAbsolutePath());
		System.setProperty("ru.myx.ae3.properties.log.level", "WARNING");
		Engine.createGuid();
		System.out.println("PROBE-BOOT-OK");

		final S4LocalDriver driver = new S4LocalDriver("ru.myx.ae3.vfs.s4.lcl.bdbj.BdbjLocalS4", S4StoreType.TEST);
		try {
			driver.start();
			System.out.println("PROBE-OK-START start-only");
		} catch (final Throwable started) {
			System.out.println("PROBE-START-FAILED start-only :: " + started);
			System.out.println("PROBE-END");
			System.out.flush();
			Runtime.getRuntime().halt(1);
		}
		try {
			driver.stop();
			System.out.println("PROBE-OK-STOP start-only");
		} catch (final Throwable stopped) {
			System.out.println("PROBE-STOP-FAILED start-only :: " + stopped);
			System.out.println("PROBE-END");
			System.out.flush();
			Runtime.getRuntime().halt(1);
		}
		System.out.println("PROBE-END");
		System.out.flush();
		Runtime.getRuntime().halt(0);
	}
}
