// CODE_GENERATION

public class J1_CE_lazy_or {

	public J1_CE_lazy_or() {}

	public static int test() {
        int x = 0;
        int y = 123;
        if (x == 0 || (y = 1) == 1) {
            return y;
        }
        return -1;
	}
}
