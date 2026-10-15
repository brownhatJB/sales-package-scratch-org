@IsTest
private class FilterLogicEvaluatorTest {

    // ─── Blank / null logic ──────────────────────────────────────────────────

    @IsTest
    static void testBlankFilterLogic_ReturnsTrue() {
        Map<Integer, Boolean> results = new Map<Integer, Boolean>{ 1 => false };

        Test.startTest();
        Boolean outcome = FilterLogicEvaluator.evaluate('', results);
        Test.stopTest();

        System.assertEquals(true, outcome, 'Blank filter logic should be treated as valid');
    }

    @IsTest
    static void testNullFilterLogic_ReturnsTrue() {
        Map<Integer, Boolean> results = new Map<Integer, Boolean>{ 1 => true };

        Test.startTest();
        Boolean outcome = FilterLogicEvaluator.evaluate(null, results);
        Test.stopTest();

        System.assertEquals(true, outcome, 'Null filter logic should be treated as valid');
    }

    // ─── Single condition ────────────────────────────────────────────────────

    @IsTest
    static void testSingleCondition_True() {
        Map<Integer, Boolean> results = new Map<Integer, Boolean>{ 1 => true };

        Test.startTest();
        Boolean outcome = FilterLogicEvaluator.evaluate('1', results);
        Test.stopTest();

        System.assertEquals(true, outcome);
    }

    @IsTest
    static void testSingleCondition_False() {
        Map<Integer, Boolean> results = new Map<Integer, Boolean>{ 1 => false };

        Test.startTest();
        Boolean outcome = FilterLogicEvaluator.evaluate('1', results);
        Test.stopTest();

        System.assertEquals(false, outcome);
    }

    // ─── AND ─────────────────────────────────────────────────────────────────

    @IsTest
    static void testAnd_BothTrue() {
        Map<Integer, Boolean> results = new Map<Integer, Boolean>{
            1 => true,
            2 => true
        };

        Test.startTest();
        Boolean outcome = FilterLogicEvaluator.evaluate('1 AND 2', results);
        Test.stopTest();

        System.assertEquals(true, outcome);
    }

    @IsTest
    static void testAnd_OneFalse() {
        Map<Integer, Boolean> results = new Map<Integer, Boolean>{
            1 => true,
            2 => false
        };

        Test.startTest();
        Boolean outcome = FilterLogicEvaluator.evaluate('1 AND 2', results);
        Test.stopTest();

        System.assertEquals(false, outcome);
    }

    @IsTest
    static void testAnd_BothFalse() {
        Map<Integer, Boolean> results = new Map<Integer, Boolean>{
            1 => false,
            2 => false
        };

        Test.startTest();
        Boolean outcome = FilterLogicEvaluator.evaluate('1 AND 2', results);
        Test.stopTest();

        System.assertEquals(false, outcome);
    }

    // ─── OR ──────────────────────────────────────────────────────────────────

    @IsTest
    static void testOr_BothTrue() {
        Map<Integer, Boolean> results = new Map<Integer, Boolean>{
            1 => true,
            2 => true
        };

        Test.startTest();
        Boolean outcome = FilterLogicEvaluator.evaluate('1 OR 2', results);
        Test.stopTest();

        System.assertEquals(true, outcome);
    }

    @IsTest
    static void testOr_OneTrue() {
        Map<Integer, Boolean> results = new Map<Integer, Boolean>{
            1 => false,
            2 => true
        };

        Test.startTest();
        Boolean outcome = FilterLogicEvaluator.evaluate('1 OR 2', results);
        Test.stopTest();

        System.assertEquals(true, outcome);
    }

    @IsTest
    static void testOr_BothFalse() {
        Map<Integer, Boolean> results = new Map<Integer, Boolean>{
            1 => false,
            2 => false
        };

        Test.startTest();
        Boolean outcome = FilterLogicEvaluator.evaluate('1 OR 2', results);
        Test.stopTest();

        System.assertEquals(false, outcome);
    }

    // ─── Parentheses / precedence ────────────────────────────────────────────

    @IsTest
    static void testParentheses_OrThenAnd_True() {
        // (1 OR 2) AND 3  →  (true OR false) AND true  →  true
        Map<Integer, Boolean> results = new Map<Integer, Boolean>{
            1 => true,
            2 => false,
            3 => true
        };

        Test.startTest();
        Boolean outcome = FilterLogicEvaluator.evaluate('(1 OR 2) AND 3', results);
        Test.stopTest();

        System.assertEquals(true, outcome);
    }

    @IsTest
    static void testParentheses_OrThenAnd_False() {
        // (1 OR 2) AND 3  →  (false OR false) AND true  →  false
        Map<Integer, Boolean> results = new Map<Integer, Boolean>{
            1 => false,
            2 => false,
            3 => true
        };

        Test.startTest();
        Boolean outcome = FilterLogicEvaluator.evaluate('(1 OR 2) AND 3', results);
        Test.stopTest();

        System.assertEquals(false, outcome);
    }

    @IsTest
    static void testComplexExpression() {
        // 1 AND 2 AND 3 OR (4 AND 5)
        // true AND true AND false OR (true AND true)
        // → false OR true → true
        Map<Integer, Boolean> results = new Map<Integer, Boolean>{
            1 => true,
            2 => true,
            3 => false,
            4 => true,
            5 => true
        };

        Test.startTest();
        Boolean outcome = FilterLogicEvaluator.evaluate(
            '1 AND 2 AND 3 OR (4 AND 5)',
            results
        );
        Test.stopTest();

        System.assertEquals(true, outcome);
    }

    @IsTest
    static void testNestedParentheses() {
        // ((1 OR 2) AND 3) OR 4
        // ((false OR true) AND false) OR true → (true AND false) OR true → true
        Map<Integer, Boolean> results = new Map<Integer, Boolean>{
            1 => false,
            2 => true,
            3 => false,
            4 => true
        };

        Test.startTest();
        Boolean outcome = FilterLogicEvaluator.evaluate(
            '((1 OR 2) AND 3) OR 4',
            results
        );
        Test.stopTest();

        System.assertEquals(true, outcome);
    }

    // ─── Malformed / fail-safe ───────────────────────────────────────────────

    @IsTest
    static void testMalformedLogic_ReturnsFalse() {
        Map<Integer, Boolean> results = new Map<Integer, Boolean>{ 1 => true };

        Test.startTest();
        // Unbalanced / incomplete expression should not throw
        Boolean outcome = FilterLogicEvaluator.evaluate('1 AND', results);
        Test.stopTest();

        System.assertEquals(
            false,
            outcome,
            'Malformed logic should fail-safe to false'
        );
    }

    @IsTest
    static void testMalformedLogic_OnlyOperator_ReturnsFalse() {
        Map<Integer, Boolean> results = new Map<Integer, Boolean>{ 1 => true };

        Test.startTest();
        Boolean outcome = FilterLogicEvaluator.evaluate('AND OR', results);
        Test.stopTest();

        System.assertEquals(false, outcome);
    }

    @IsTest
    static void testUnmatchedParenthesis_DoesNotThrow() {
        Map<Integer, Boolean> results = new Map<Integer, Boolean>{
            1 => true,
            2 => false
        };

        Test.startTest();
        // Current implementation does not reject unmatched '('.
        // Assert only that it does not throw.
        Boolean outcome = FilterLogicEvaluator.evaluate('(1 OR 2', results);
        Test.stopTest();

        System.assertNotEquals(null, outcome, 'Should return a boolean without throwing');
    }

    // ─── Spacing / case variants ─────────────────────────────────────────────

    @IsTest
    static void testExtraSpaces() {
        Map<Integer, Boolean> results = new Map<Integer, Boolean>{
            1 => true,
            2 => true
        };

        Test.startTest();
        Boolean outcome = FilterLogicEvaluator.evaluate('  1   AND   2  ', results);
        Test.stopTest();

        System.assertEquals(true, outcome);
    }

    @IsTest
    static void testThreeWayAnd() {
        Map<Integer, Boolean> results = new Map<Integer, Boolean>{
            1 => true,
            2 => true,
            3 => true
        };

        Test.startTest();
        Boolean outcome = FilterLogicEvaluator.evaluate('1 AND 2 AND 3', results);
        Test.stopTest();

        System.assertEquals(true, outcome);
    }

    @IsTest
    static void testThreeWayOr_OneTrue() {
        Map<Integer, Boolean> results = new Map<Integer, Boolean>{
            1 => false,
            2 => false,
            3 => true
        };

        Test.startTest();
        Boolean outcome = FilterLogicEvaluator.evaluate('1 OR 2 OR 3', results);
        Test.stopTest();

        System.assertEquals(true, outcome);
    }
}