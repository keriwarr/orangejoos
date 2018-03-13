// TYPE_CHECKING
public class Je_CE_instanceof_no_type {

    public Je_CE_instanceof_no_type () {}

    public boolean test() {
        Object x = null;
        return x instanceof NotARealClass;
    }

}
