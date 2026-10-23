@IsTest
private class MilestoneCompletionActionControllerTest {

    private static User getTestUser() {
        return TestUserFactory.createUserWithPackageAccess();
    }

    // ─── Test data factory ───────────────────────────────────────────────────

    private static Milestone__c createMilestone(
        Date tentativeDate,
        Date actualDate
    ) {
        Milestone__c m = new Milestone__c(
            Name = 'Test Milestone',
            Tentative_Due_Date_of_Completion__c = tentativeDate,
            Actual_Date_of_Completion__c = actualDate
        );
        insert m;
        return m;
    }

    // ─── getMilestone tests ──────────────────────────────────────────────────

    @IsTest
    static void testGetMilestone_Success() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Milestone__c m = createMilestone(Date.today().addDays(10), null);

            Test.startTest();
            MilestoneCompletionActionController.MilestoneData result =
                MilestoneCompletionActionController.getMilestone(m.Id);
            Test.stopTest();

            System.assertEquals(m.Id, result.id, 'Id should match');
            System.assertEquals(m.Name, result.milestoneName, 'Name should match');
            System.assertEquals(
                m.Tentative_Due_Date_of_Completion__c,
                result.tentativeDate,
                'Tentative date should match'
            );
            System.assertEquals(
                null,
                result.actualDate,
                'Actual date should be null'
            );
        }
    }

    @IsTest
    static void testGetMilestone_WithBothDates() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Milestone__c m = createMilestone(
                Date.today().addDays(5),
                Date.today()
            );

            Test.startTest();
            MilestoneCompletionActionController.MilestoneData result =
                MilestoneCompletionActionController.getMilestone(m.Id);
            Test.stopTest();

            System.assertEquals(m.Id, result.id);
            System.assertEquals(
                m.Tentative_Due_Date_of_Completion__c,
                result.tentativeDate
            );
            System.assertEquals(
                m.Actual_Date_of_Completion__c,
                result.actualDate
            );
        }
    }

    @IsTest
    static void testGetMilestone_NullId() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Test.startTest();
            Boolean exceptionThrown = false;
            try {
                MilestoneCompletionActionController.getMilestone(null);
            } catch (AuraHandledException e) {
                exceptionThrown = true;
            }
            Test.stopTest();
            System.assert(exceptionThrown, 'Expected AuraHandledException for null Id');
        }
    }

    // ─── updateCompletion – Tentative ────────────────────────────────────────

    @IsTest
    static void testUpdateCompletion_Tentative_Success() {
        User testUser = getTestUser();
        Milestone__c m;
        Date newDate = Date.today().addDays(15);
        String comments = 'Updated tentative date for testing.';

        System.runAs(testUser) {
            m = createMilestone(Date.today().addDays(10), null);

            Test.startTest();
            MilestoneCompletionActionController.updateCompletion(
                m.Id,
                'TENTATIVE',
                newDate,
                comments
            );
            Test.stopTest();

            Milestone__c updated = [
                SELECT
                    Tentative_Due_Date_of_Completion__c,
                    Actual_Date_of_Completion__c,
                    Comments__c
                FROM Milestone__c
                WHERE Id = :m.Id
            ];

            System.assertEquals(
                newDate,
                updated.Tentative_Due_Date_of_Completion__c,
                'Tentative date should be updated'
            );
            System.assertEquals(
                null,
                updated.Actual_Date_of_Completion__c,
                'Actual date should remain null'
            );
            System.assertEquals(
                comments,
                updated.Comments__c,
                'Comments should be set'
            );
        }

        // FeedItem query runs outside runAs (as admin)
        List<FeedItem> posts = [
            SELECT Body
            FROM FeedItem
            WHERE ParentId = :m.Id
        ];
        System.assertEquals(1, posts.size(), 'One Chatter post expected');
        System.assert(
            posts[0].Body.contains('Tentative Completion Date'),
            'Chatter should mention Tentative'
        );
        System.assert(
            posts[0].Body.contains(comments),
            'Chatter should contain comments'
        );
    }

    @IsTest
    static void testUpdateCompletion_Tentative_WhenActualAlreadySet() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Milestone__c m = createMilestone(
                Date.today().addDays(10),
                Date.today()
            );

            Test.startTest();
            Boolean exceptionThrown = false;
            try {
                MilestoneCompletionActionController.updateCompletion(
                    m.Id,
                    'TENTATIVE',
                    Date.today().addDays(20),
                    'Should fail'
                );
            } catch (AuraHandledException e) {
                exceptionThrown = true;
            }
            Test.stopTest();
            System.assert(
                exceptionThrown,
                'Expected AuraHandledException when Actual date is already set'
            );
        }
    }

    // ─── updateCompletion – Actual ───────────────────────────────────────────

    @IsTest
    static void testUpdateCompletion_Actual_Success() {
        User testUser = getTestUser();
        Milestone__c m;
        Date newDate = Date.today();
        String comments = 'Milestone completed today.';

        System.runAs(testUser) {
            m = createMilestone(Date.today().addDays(10), null);

            Test.startTest();
            MilestoneCompletionActionController.updateCompletion(
                m.Id,
                'ACTUAL',
                newDate,
                comments
            );
            Test.stopTest();

            Milestone__c updated = [
                SELECT
                    Tentative_Due_Date_of_Completion__c,
                    Actual_Date_of_Completion__c,
                    Comments__c
                FROM Milestone__c
                WHERE Id = :m.Id
            ];

            System.assertEquals(
                newDate,
                updated.Actual_Date_of_Completion__c,
                'Actual date should be updated'
            );
            System.assertEquals(
                comments,
                updated.Comments__c,
                'Comments should be set'
            );
        }

        // FeedItem query runs outside runAs (as admin)
        List<FeedItem> posts = [
            SELECT Body
            FROM FeedItem
            WHERE ParentId = :m.Id
        ];
        System.assertEquals(1, posts.size());
        System.assert(
            posts[0].Body.contains('Actual Completion Date'),
            'Chatter should mention Actual'
        );
    }

    @IsTest
    static void testUpdateCompletion_Actual_UpdateExisting() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Milestone__c m = createMilestone(
                Date.today().addDays(10),
                Date.today().addDays(-5)
            );
            Date newDate = Date.today();
            String comments = 'Corrected actual completion date.';

            Test.startTest();
            MilestoneCompletionActionController.updateCompletion(
                m.Id,
                'ACTUAL',
                newDate,
                comments
            );
            Test.stopTest();

            Milestone__c updated = [
                SELECT Actual_Date_of_Completion__c, Comments__c
                FROM Milestone__c
                WHERE Id = :m.Id
            ];

            System.assertEquals(newDate, updated.Actual_Date_of_Completion__c);
            System.assertEquals(comments, updated.Comments__c);
        }
    }

    // ─── updateCompletion – Validation errors ────────────────────────────────

    @IsTest
    static void testUpdateCompletion_NullMilestoneId() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Test.startTest();
            Boolean exceptionThrown = false;
            try {
                MilestoneCompletionActionController.updateCompletion(
                    null,
                    'ACTUAL',
                    Date.today(),
                    'Comments'
                );
            } catch (AuraHandledException e) {
                exceptionThrown = true;
            }
            Test.stopTest();
            System.assert(exceptionThrown, 'Expected AuraHandledException for null milestone Id');
        }
    }

    @IsTest
    static void testUpdateCompletion_BlankDateType() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Milestone__c m = createMilestone(Date.today(), null);

            Test.startTest();
            Boolean exceptionThrown = false;
            try {
                MilestoneCompletionActionController.updateCompletion(
                    m.Id,
                    '',
                    Date.today(),
                    'Comments'
                );
            } catch (AuraHandledException e) {
                exceptionThrown = true;
            }
            Test.stopTest();
            System.assert(exceptionThrown, 'Expected AuraHandledException for blank dateType');
        }
    }

    @IsTest
    static void testUpdateCompletion_NullDate() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Milestone__c m = createMilestone(Date.today(), null);

            Test.startTest();
            Boolean exceptionThrown = false;
            try {
                MilestoneCompletionActionController.updateCompletion(
                    m.Id,
                    'ACTUAL',
                    null,
                    'Comments'
                );
            } catch (AuraHandledException e) {
                exceptionThrown = true;
            }
            Test.stopTest();
            System.assert(exceptionThrown, 'Expected AuraHandledException for null date');
        }
    }

    @IsTest
    static void testUpdateCompletion_BlankComments() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Milestone__c m = createMilestone(Date.today(), null);

            Test.startTest();
            Boolean exceptionThrown = false;
            try {
                MilestoneCompletionActionController.updateCompletion(
                    m.Id,
                    'ACTUAL',
                    Date.today(),
                    '   '
                );
            } catch (AuraHandledException e) {
                exceptionThrown = true;
            }
            Test.stopTest();
            System.assert(exceptionThrown, 'Expected AuraHandledException for blank comments');
        }
    }

    @IsTest
    static void testUpdateCompletion_InvalidDateType() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Milestone__c m = createMilestone(Date.today(), null);

            Test.startTest();
            Boolean exceptionThrown = false;
            try {
                MilestoneCompletionActionController.updateCompletion(
                    m.Id,
                    'INVALID',
                    Date.today(),
                    'Comments'
                );
            } catch (AuraHandledException e) {
                exceptionThrown = true;
            }
            Test.stopTest();
            System.assert(exceptionThrown, 'Expected AuraHandledException for invalid dateType');
        }
    }
}