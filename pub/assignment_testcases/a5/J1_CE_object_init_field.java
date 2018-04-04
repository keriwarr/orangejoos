// PARSER_WEEDER,CODE_GENERATION
public class J1_CE_object_init_field {

    public int x = 1337;
    public int y = 1;

    public J1_CE_object_init_field(){
        x = 2;
        y = 123;
    }

    public static int test() {
        J1_CE_object_init_field a = new J1_CE_object_init_field();
        return a.y;
    }
}
