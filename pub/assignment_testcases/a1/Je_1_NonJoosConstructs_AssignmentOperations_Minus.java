// JOOS1:PARSER_WEEDER,PARSER_EXCEPTION
// JOOS2:PARSER_WEEDER,PARSER_EXCEPTION
// JAVAC:
//
/**
 * Parser/weeder:
 * - Assignment operations not allowed
 */
public class Je_1_NonJoosConstructs_AssignmentOperations_Minus {

    public Je_1_NonJoosConstructs_AssignmentOperations_Minus() {}

    public static int test() {
	int x = 165;
	x-=42;
	return x;
    }
}
