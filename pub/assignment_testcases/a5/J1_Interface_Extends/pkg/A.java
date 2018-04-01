package pkg;

public class A implements Foo {
  public int a;

  public A(int ma) {
    a = ma;
  }

  public int foo() {
    return a;
  }

  public int bar() {
    return 2 * a;
  }
}
