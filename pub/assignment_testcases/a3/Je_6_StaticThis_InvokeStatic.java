// JOOS1:TYPE_CHECKING,THIS_IN_STATIC_CONTEXT
// JOOS2:TYPE_CHECKING,THIS_IN_STATIC_CONTEXT
// JAVAC:UNKNOWN
//
/**
 * Typecheck:
 * - A this reference (AThisExp) must not occur, explicitly or
 * implicitly, in a static method, an initializer for a static field,
 * or an argument to a super or this constructor invocation.
 */
public class Je_6_StaticThis_InvokeStatic {

    public Je_6_StaticThis_InvokeStatic () {}

    public static int foo(){
	return 123;
    }

    public static int test() {
        return this.foo();
    }

}
