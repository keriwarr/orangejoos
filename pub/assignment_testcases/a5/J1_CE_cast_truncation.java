public class J1_CE_cast_truncation {
    public J1_CE_cast_truncation() {}
    public static int test() {
        if (1 == ((int) ((byte) 257))) return 1;
        return 0;
    }
}
