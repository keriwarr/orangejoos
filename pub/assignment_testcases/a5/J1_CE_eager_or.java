// CODE_GENERATION

public class J1_CE_eager_or {

	public J1_CE_eager_or() {}

	public static int test() {
        int x = 0;
        int y = 1;
        if (x == 0 | (y = 123) == 1) {
            return y;
        }
        return -1;
	}
}
