// DISAMBIGUATION,TYPE_CHECKING,CODE_GENERATION
public class J1_CE_static_invoc_params {
    public J1_CE_static_invoc_params() {
    }

    public static int baz(int a, int b, int c) {
        return a * a - b * c;
    }

    public static int bar(int a, int b) {
        return J1_CE_static_invoc_params.baz(a + 2, b, b) + 43;
    }

    public static int test() {
        return J1_CE_static_invoc_params.bar(10, 8);
    }
}
