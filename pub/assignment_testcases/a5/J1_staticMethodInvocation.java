// DISAMBIGUATION,TYPE_CHECKING,CODE_GENERATION
public class J1_staticMethodInvocation {
    public J1_staticMethodInvocation() {
    }

    public static int baz(int a, int b, int c) {
        return a * a - b * c;
    }

    public static int bar(int a, int b) {
        return J1_staticMethodInvocation.baz(a + 2, b, b) + 43;
    }

    public static int test() {
        return J1_staticMethodInvocation.bar(10, 8);
    }
}
