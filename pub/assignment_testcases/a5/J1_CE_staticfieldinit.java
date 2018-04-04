// DISAMBIGUATION,CODE_GENERATION
public class J1_CE_staticfieldinit {

    public static int foo = 123;

    public J1_CE_staticfieldinit() {}

    public static int test() {
        return J1_CE_staticfieldinit.foo;
    }

}
