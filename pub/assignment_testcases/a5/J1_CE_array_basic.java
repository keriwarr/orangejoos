// PARSER_WEEDER,CODE_GENERATION
public class J1_CE_array_basic {
    public J1_CE_array_basic(){}

    public static int test() {
        int[] a = null;
        a = new int[4];
        a[3] = 5;
        a[2] = 118 + a[3];
        return a[2]; // Return 123.
    }
}
