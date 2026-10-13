/**
* ================================================================
* Class Name      : FilterLogicEvaluator
* Author          : Shubham Gupta
* Module          : Dynamic KYC Control Framework
* Description     :
*      Utility class responsible for evaluating dynamic filter logic
*      defined in Custom Metadata (CMDT).
*
*      This class supports:
*          - AND / OR logical operators
*          - Parentheses for grouping
*          - Multiple dynamic conditions (1, 2, 3…)
*          - Safe handling of malformed logic
*
*      Example Supported Filter Logic:
*          (1 OR 2) AND 3
*          1 AND 2 AND 3 OR (4 AND 5)
*          1
*          1 OR 2
*
*      Internally:
*          1. Replaces condition numbers with true/false values.
*          2. Converts infix expression to postfix using
*             Shunting Yard Algorithm.
*          3. Evaluates postfix expression using stack logic.
*
* ================================================================
*/
public class FilterLogicEvaluator {
    
    //Evaluates filter logic string against condition results.
    //
    //@param filterLogic        String expression like "(1 OR 2) AND 3"
    //@param conditionResults   Map of sequence number → boolean result
    //@return Boolean           Final evaluated result
    public static Boolean evaluate(String filterLogic, Map<Integer, Boolean> conditionResults) {
        
        // If no filter logic provided, treat as valid
        if (String.isBlank(filterLogic)) {
            return true;
        }
        
        try {
            
            // ----------------------------------------------------
            // Replacing numeric placeholders with true/false (1 OR 2) AND 3 → (true OR false) AND true
            // ----------------------------------------------------
            for (Integer key : conditionResults.keySet()) {
                filterLogic = filterLogic.replaceAll(
                    '\\b' + String.valueOf(key) + '\\b',
                    String.valueOf(conditionResults.get(key))
                );
            }
            
            // ----------------------------------------------------
            // Normalize expression
            // Replace AND/OR with && / ||
            // Remove spaces
            // ----------------------------------------------------
            filterLogic = filterLogic.replaceAll('AND', '&&');
            filterLogic = filterLogic.replaceAll('OR', '||');
            filterLogic = filterLogic.replaceAll('\\s+', '');
            
            // Evaluate boolean expression
            return evaluateBooleanExpression(filterLogic);
            
        }
        catch (Exception e) {
            
            // Fail-safe: malformed admin logic should not break transaction
            System.debug('Invalid Filter Logic: ' + filterLogic);
            System.debug('Error: ' + e.getMessage());
            
            return false;
        }
    }
    
    //Evaluates a boolean expression already converted to
    //
    //true/false with logical operators.
    //Uses postfix evaluation with stack simulation.
    private static Boolean evaluateBooleanExpression(String expression) {
        
        // Convert infix expression to postfix (Shunting Yard)
        List<String> postfix = infixToPostfix(expression);
        
        // Acts as a stack (Apex has no native Stack class)
        List<Boolean> stack = new List<Boolean>();
        
        for (String token : postfix) {
            
            // If operand → push to stack
            if (token == 'true') {
                stack.add(true);
            }
            else if (token == 'false') {
                stack.add(false);
            }
            // If operator → pop two values and evaluate
            else if (token == '&&' || token == '||') {
                
                if (stack.size() < 2) {
                    throw new IllegalArgumentException('Malformed logic');
                }
                
                Boolean b = stack.remove(stack.size() - 1);
                Boolean a = stack.remove(stack.size() - 1);
                
                if (token == '&&') {
                    stack.add(a && b);
                } else {
                    stack.add(a || b);
                }
            }
        }
        
        // Final stack must contain exactly one result
        if (stack.size() != 1) {
            throw new IllegalArgumentException('Malformed logic');
        }
        
        return stack[0];
    }
    
    //Converts infix expression to postfix expression using the Shunting Yard algorithm.
    private static List<String> infixToPostfix(String expression) {
        
        // Operator precedence map
        Map<String, Integer> precedence = new Map<String, Integer>{ '||' => 1, '&&' => 2 };
                    
        List<String> output = new List<String>();
        List<String> operators = new List<String>();
        
        List<String> tokens = tokenize(expression);
        
        for (String token : tokens) {
            
            // If operand → add directly to output
            if (token == 'true' || token == 'false') {
                output.add(token);
            }
            // If operator → handle precedence
            else if (token == '&&' || token == '||') {
                
                while (!operators.isEmpty()
                       && operators[operators.size()-1] != '('
                       && precedence.get(operators[operators.size()-1]) >= precedence.get(token)) {
                           
                           output.add(operators.remove(operators.size()-1));
                       }
                
                operators.add(token);
            }
            // If opening parenthesis → push
            else if (token == '(') {
                operators.add(token);
            }
            // If closing parenthesis → pop until '('
            else if (token == ')') {
                
                while (!operators.isEmpty()
                       && operators[operators.size()-1] != '(') {
                           
                           output.add(operators.remove(operators.size()-1));
                       }
                
                operators.remove(operators.size()-1); // Remove '('
            }
        }
        
        // Pop remaining operators
        while (!operators.isEmpty()) {
            output.add(operators.remove(operators.size()-1));
        }
        return output;
    }

    //Tokenizes expression string into individual components: true, false, &&, ||, (, )
    //
    //Example: (true&&false)||true
    //Becomes: (, true, &&, false, ), ||, true
    private static List<String> tokenize(String expression) {
        
        List<String> tokens = new List<String>();
        Integer i = 0;
        
        while (i < expression.length()) {
            
            String currentChar = expression.substring(i, i+1);
            
            // Parentheses
            if (currentChar == '(' || currentChar == ')') {
                tokens.add(currentChar);
                i++;
            }
            // AND operator
            else if (i+1 < expression.length() &&
                     expression.substring(i, i+2) == '&&') {
                         
                         tokens.add('&&');
                         i += 2;
                     }
            // OR operator
            else if (i+1 < expression.length() &&
                     expression.substring(i, i+2) == '||') {
                         
                         tokens.add('||');
                         i += 2;
                     }
            // true literal
            else if (i+3 < expression.length() &&
                     expression.substring(i, i+4) == 'true') {
                         
                         tokens.add('true');
                         i += 4;
                     }
            // false literal
            else if (i+4 < expression.length() &&
                     expression.substring(i, i+5) == 'false') {
                         
                         tokens.add('false');
                         i += 5;
                     }
            else {
                i++;
            }
        }
        return tokens;
    }
}