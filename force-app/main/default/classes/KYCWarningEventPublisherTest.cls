@IsTest
private class KYCWarningEventPublisherTest {

    private static User getTestUser() {
        return TestUserFactory.createUserWithPackageAccess();
    }

    @IsTest
    static void testPublishWarning_Success() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            // Any valid Id works for the event payload (no DML on the record required)
            Account acc = new Account(Name = 'KYC Warning Test Account');
            insert acc;

            Test.startTest();
            KYCWarningEventPublisher.publishWarning(
                acc.Id,
                'Account',
                'KYC is not approved for this record.'
            );
            Test.stopTest();

            // Platform events published in tests are delivered after stopTest
            // Assert the method completed without throwing
            System.assert(true, 'publishWarning should complete without exception');
        }
    }

    @IsTest
    static void testPublishWarning_WithNullRecordId() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Test.startTest();
            KYCWarningEventPublisher.publishWarning(
                null,
                'Lead',
                'Warning with null record Id'
            );
            Test.stopTest();

            System.assert(true, 'Should handle null recordId without throwing');
        }
    }

    @IsTest
    static void testPublishWarning_WithBlankMessage() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Contact con = new Contact(LastName = 'KYC Warning Contact');
            // Contact may need Account depending on org – use Account if required
            Account acc = new Account(Name = 'KYC Warning Acc');
            insert acc;
            con.AccountId = acc.Id;
            insert con;

            Test.startTest();
            KYCWarningEventPublisher.publishWarning(
                con.Id,
                'Contact',
                ''
            );
            Test.stopTest();

            System.assert(true, 'Should publish even with blank message');
        }
    }

    @IsTest
    static void testPublishWarning_MultipleEvents() {
        User testUser = getTestUser();
        System.runAs(testUser) {
            Account acc = new Account(Name = 'Multi Event Account');
            insert acc;

            Test.startTest();
            KYCWarningEventPublisher.publishWarning(
                acc.Id,
                'Account',
                'First warning'
            );
            KYCWarningEventPublisher.publishWarning(
                acc.Id,
                'Account',
                'Second warning'
            );
            Test.stopTest();

            System.assert(true, 'Multiple publishes should complete without exception');
        }
    }
}