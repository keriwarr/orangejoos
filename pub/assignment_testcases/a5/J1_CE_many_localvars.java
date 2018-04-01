// PARSER_WEEDER,CODE_GENERATION
public class J1_CE_many_localvars {

    public J1_CE_many_localvars(){}

    public static int test() {
        int correct = 0;
        correct = correct + 2;
        int also_correct = 3;
        also_correct = also_correct + 100;
        int not_correct = -10;
        // correct = 2 + 103 + 18 => 123
        correct = correct + also_correct + 18;
        not_correct = 5;
        return correct;
    }
}
