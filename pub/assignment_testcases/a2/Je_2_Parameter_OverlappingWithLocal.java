// JOOS1:ENVIRONMENTS,DUPLICATE_VARIABLE
// JOOS2:ENVIRONMENTS,DUPLICATE_VARIABLE
// JAVAC:UNKNOWN
//
/**
 * Environments:
 * - Check that no two local variables with overlapping scope have the
 * same name.
 */
public class Je_2_Parameter_OverlappingWithLocal {

    public Je_2_Parameter_OverlappingWithLocal() {}

    public void m(Object o) {
	Object o = new Object();
    }

    public static int test() {
        return 123;
    }

}
