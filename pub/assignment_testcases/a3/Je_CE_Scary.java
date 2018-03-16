public class Je_CE_Scary {
  public Je_CE_Scary() {}

  public void foo() {
    int x = 1;
    x = y.bar();
    // x = hah.haha.Za.length; // Parses as QualifiedName.
    // x = hah.Method().length; // Parses as FieldAccess.
    // x = hah.Method().length.lala; // Parses as FieldAccess.
    // x = hah.length; // Parses as QualifiedName.
    // x = (new String()).length; // Parses as FieldAccess.
  }
}
