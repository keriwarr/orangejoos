public class Je_CE_while_check_assn {
    public Je_CE_while_check_assn() {}

    public void fn() {
        boolean x = true;
        while (x = 1) {
            // Check that no error is thrown here.
        }
    }
}
