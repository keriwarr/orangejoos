package orangejoos;

import java.lang.reflect.*;

public class Wrapper {
    // args contains the entry Class name with test() as the first
    // argument.
    public static void main(String[] args) {
        if (args.length != 1) {
            System.err.printf("expected one argument: test entry class\n");
            System.exit(-1);
        }
        try {
            Class<?> entry_class = Class.forName(args[0]);
            Method method = entry_class.getMethod("test");
            // System.err.printf("=== running test: %s\n", args[0]);
            Integer result = (Integer) method.invoke(null);
            System.exit(result);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
