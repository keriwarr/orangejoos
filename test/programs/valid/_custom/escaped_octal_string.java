public class escaped_octal_string {
    public escaped_octal_string() {}

    public char a() {
        return '\77';
    }

    public char b() {
        return '\01';
    }

    public char c() {
        return '\322';
    }

    public char d() {
        return '\377';
    }
}
