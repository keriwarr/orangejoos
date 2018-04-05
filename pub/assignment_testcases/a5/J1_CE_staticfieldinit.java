// DISAMBIGUATION,CODE_GENERATION
public class J1_CE_staticfieldinit {

    public static int foo = 61;
    public static int bar = foo * 2 + 1;

    public J1_CE_staticfieldinit() {}

    public static int test() {
        return J1_CE_staticfieldinit.bar;
    }

}
