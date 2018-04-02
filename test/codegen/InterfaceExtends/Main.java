import pkg.*;

public class Main {
  public Main() {}

  public static int test() {
    A a = new A(3);
    Foo f = (Foo)a;
    return f.foo();
  }
}
