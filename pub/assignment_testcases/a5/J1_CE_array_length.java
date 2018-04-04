// PARSER_WEEDER,CODE_GENERATION
public class J1_CE_array_length {
    public J1_CE_array_length(){}

    public static int test() {
        int[] a = null;
        int b = 120;
        b = b + 3;
        a = new int[b];
        return a.length; // Return 123.
    }
}
