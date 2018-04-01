package pkg;

import pkg.stuff.*;

public class Foo extends Bar implements Fooer {
  public int x;
  public int y;

  public Foo(int mx, int my) {
    x = mx;
    y = my;
  }

  public static void chidori() {}

  public int foo() {
    return x + y;
  }

  public void foobar() {}
}
