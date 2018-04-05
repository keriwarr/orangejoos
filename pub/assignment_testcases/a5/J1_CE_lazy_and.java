// CODE_GENERATION

public class J1_CE_lazy_and {

	public J1_CE_lazy_and() {}

	public static int test() {
        int x = 0;
        int y = 1;
        if (x == 0 && (y = 123) == 1) {
            return y;
        }
        return -1;
	}
}
