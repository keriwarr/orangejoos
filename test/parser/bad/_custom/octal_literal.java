public class OctalLiteral {
    public OctalLiteral() {}
    public int m() {
        // Because Joos1W does not support octal literals, this is
        // invalid. An octal literal is prefixed with a 0.
        return 00;
    }
}
