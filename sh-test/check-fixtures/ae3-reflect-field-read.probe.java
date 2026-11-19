package ru.myx.ae3.probe;

import ru.myx.ae3.Engine;
import ru.myx.ae3.base.Base;
import ru.myx.ae3.base.BaseObject;
import ru.myx.ae3.exec.ExecProcess;

/**
 * One read call and one write call over three shapes of public field. The plain field and the field
 * with a getter are the controls: both read whatever the reflection does, in either arm. The field
 * with a same-name setter and no getter is the subject, for the read and for the write.
 */
public class Ae3ReflectFieldReadProbe {

	public static class PlainShape {

		public final StringBuilder plainField = new StringBuilder("BB3");
	}

	public static class GetterShape {

		public final StringBuilder getField = new StringBuilder("BB3");

		@SuppressWarnings("unused")
		public void setGetField(final ExecProcess ctx, final int s) {

			this.getField.append(",int=").append(s);
		}

		public StringBuilder getGetField() {

			return this.getField;
		}
	}

	public static class SetterShape {

		public final StringBuilder gsField3 = new StringBuilder("BB3");

		@SuppressWarnings("unused")
		public void setGsField3(final ExecProcess ctx, final String s) {

			this.gsField3.append(",str=").append(s);
		}
	}

	private static void read(final String shape, final Object instance, final String fieldName) {

		final BaseObject read = Base.forUnknown(instance).baseGet(fieldName, BaseObject.UNDEFINED);
		System.out.println("PROBE-READ " + shape + ": " + read.baseToString());
	}

	public static void main(final String[] args) throws Exception {

		Engine.createGuid();
		System.out.println("PROBE-BOOT-OK");

		read("plain", new PlainShape(), "plainField");
		read("getter", new GetterShape(), "getField");
		final SetterShape subject = new SetterShape();
		read("setter-only", subject, "gsField3");

		final BaseObject target = Base.forUnknown(subject);
		Base.put(target, "gsField3", "123");
		read("setter-only-after-put", subject, "gsField3");

		System.out.println("PROBE-END");
		System.out.flush();
		Runtime.getRuntime().halt(0);
	}
}
