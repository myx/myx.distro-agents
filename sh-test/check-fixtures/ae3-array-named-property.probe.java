package ru.myx.ae3.probe;

import ru.myx.ae3.Engine;
import ru.myx.ae3.base.Base;
import ru.myx.ae3.base.BaseObject;
import ru.myx.ae3.base.BaseNativeArray;
import ru.myx.ae3.base.BasePrimitiveNumber;

import org.w3c.dom.Element;

import ru.myx.ae3.help.Dom;
import ru.myx.ae3.xml.Xml;

/**
 * One shape of array per fixture. For each, the XML the writer writes and what reading that XML back
 * gives. A named own property is what the fault drops. An element is the control: the writer wrote
 * elements before the fix, and writes them after it.
 */
public class Ae3ArrayNamedPropertyProbe {

	private static int failures = 0;

	private static void show(final String shape, final BaseNativeArray array) {

		final Element element = Xml.toElement("data", array, true);
		final BaseObject back = Xml.toBase(element, null, null, null, null);
		final String alpha = back.baseGet("alpha", BaseObject.UNDEFINED).baseToString().toString();
		final int length = back.baseArray() == null ? -1 : back.baseArray().length();
		System.out.println("PROBE-XML " + shape + ": " + Dom.toXmlCompact(element));
		System.out.println("PROBE-BACK " + shape + ": alpha=" + alpha + " length=" + length);
	}

	public static void main(final String[] args) {

		Engine.createGuid();
		System.out.println("PROBE-BOOT-OK");

		final BaseNativeArray empty = new BaseNativeArray();
		show("empty", empty);

		final BaseNativeArray noElements = new BaseNativeArray();
		noElements.putAppend("alpha", Base.forString("A"));
		show("one-prop-no-elements", noElements);

		final BaseNativeArray withElement = new BaseNativeArray();
		withElement.putAppend("alpha", Base.forString("A"));
		withElement.baseDefaultPush(BasePrimitiveNumber.PI);
		show("one-prop-one-element", withElement);

		System.out.println("PROBE-END");
		System.out.flush();
		Runtime.getRuntime().halt(0);
	}
}
