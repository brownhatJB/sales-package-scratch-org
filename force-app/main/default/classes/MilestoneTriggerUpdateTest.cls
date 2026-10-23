/**
 * @module            : Real_Estate_Module
 * @description       : test class for PayableTriggerDefaultValuesTest
 * @author            : Nisha Tony
 * @group             : MilestoneTrigger
 * @last modified on  : 04-23-2026
 * @last modified by  : Nisha Tony
 **/
@isTest
public with sharing class MilestoneTriggerUpdateTest {

    private static User getTestUser() {
        return TestUserFactory.createUserWithPackageAccess();
    }

    @testSetup
    static void setup() {
        User u = getTestUser();
        System.runAs(u) {

            // Project
            Project__c project = new Project__c(
                Name = 'Test Project',
                Stage__c = 'Completed',
                Country__c = 'India',
                State__c = 'Kerala',
                City__c = 'Kochi',
                UOM__c = 'Sq. Meter',
                Total_Area__c = 1000.00,
                Broker_Commission__c = 3.00
            );
            insert project;

            // Property
            Properties__c properties = new Properties__c(
                Name = 'Test Property',
                Project__c = project.Id,
                Stage__c = 'Completed',
                UOM__c = 'Sq. Meter',
                Total_Area__c = 100
            );
            insert properties;

            // Milestone
            Milestone__c milestone = new Milestone__c(
                Name = 'Test Milestone',
                Project__c = project.Id,
                Properties__c = properties.Id,
                Actual_Date_of_Completion__c = Date.today().addDays(20),
                Tentative_Due_Date_of_Completion__c = Date.today().addDays(10),
                Milestone_Trigger_Flag__c = false,
                Comments__c = 'Original comment'
            );
            insert milestone;

            // Normal Payment Plan Item
            Payment_Plan_Item__c ppi = new Payment_Plan_Item__c(
                Milestone__c = milestone.Id,
                Proposed_Due_Date__c = Date.today().addDays(15),
                Actual_Due_Date__c = Date.today().addDays(5),
                Status__c = 'Not Invoiced'
            );
            insert ppi;

            // Offer (minimal required fields)
            Account acc = new Account(Name = 'Test Account for Offer');
            insert acc;

            Contact con = new Contact(LastName = 'Test Contact', AccountId = acc.Id);
            insert con;

            Offer__c offer = new Offer__c(
                Account__c = acc.Id,
                Contact__c = con.Id
                // Name is Auto-Number – leave it blank
            );
            insert offer;

            // Offer Payment Plan Item – Validation__c = true skips the NPE path
            Offer_Payment_Plan_Item__c offerPpi = new Offer_Payment_Plan_Item__c(
                Milestone__c          = milestone.Id,
                Offer__c              = offer.Id,
                Tentative_Due_Date__c = Date.today().addDays(12),
                Validation__c         = true
            );
            insert offerPpi;
        }
    }

    @isTest
    static void testActualAndTentativeDateChange() {
        User u = getTestUser();
        System.runAs(u) {
            Milestone__c milestone = [
                SELECT Id, Actual_Date_of_Completion__c, Tentative_Due_Date_of_Completion__c,
                       Comments__c, Milestone_Trigger_Flag__c
                FROM Milestone__c
                LIMIT 1
            ];

            Date newActual = Date.today().addDays(30);
            Date newTentative = Date.today().addDays(25);

            Test.startTest();
            milestone.Actual_Date_of_Completion__c = newActual;
            milestone.Tentative_Due_Date_of_Completion__c = newTentative;
            milestone.Comments__c = 'Updated comment for flag';
            milestone.Milestone_Trigger_Flag__c = true;
            update milestone;
            Test.stopTest();

            // Verify Payment Plan Items
            List<Payment_Plan_Item__c> ppis = [
                SELECT Actual_Due_Date__c
                FROM Payment_Plan_Item__c
                WHERE Milestone__c = :milestone.Id AND Status__c = 'Not Invoiced'
            ];
            System.assertEquals(1, ppis.size(), 'Should have one PPI');
            // Because both dates changed, the last update wins for Actual_Due_Date__c
            // (tentative update overwrites the actual one in current logic)
            System.assertEquals(newTentative, ppis[0].Actual_Due_Date__c,
                'PPI Actual_Due_Date should reflect the latest date change');

            // Verify Offer Payment Plan Items
            List<Offer_Payment_Plan_Item__c> offerPpis = [
                SELECT Tentative_Due_Date__c
                FROM Offer_Payment_Plan_Item__c
                WHERE Milestone__c = :milestone.Id
            ];
            System.assertEquals(1, offerPpis.size(), 'Should have one Offer PPI');
            System.assertEquals(newTentative, offerPpis[0].Tentative_Due_Date__c,
                'Offer PPI Tentative_Due_Date should be updated');

            // Verify comment flag
            Milestone__c updatedMilestone = [
                SELECT Milestone_Comment_change_flag__c, Milestone_Trigger_Flag__c
                FROM Milestone__c
                WHERE Id = :milestone.Id
            ];
            System.assertEquals(true, updatedMilestone.Milestone_Comment_change_flag__c,
                'Comment change flag should be set');
            // Flag is reset to false only in the Actual-date path
            System.assertEquals(false, updatedMilestone.Milestone_Trigger_Flag__c,
                'Trigger flag should be reset');
        }
    }

    @isTest
    static void testOnlyActualDateChange() {
        User u = getTestUser();
        System.runAs(u) {
            Milestone__c milestone = [
                SELECT Id, Actual_Date_of_Completion__c, Tentative_Due_Date_of_Completion__c
                FROM Milestone__c
                LIMIT 1
            ];

            Date newActual = Date.today().addDays(40);

            Test.startTest();
            milestone.Actual_Date_of_Completion__c = newActual;
            update milestone;
            Test.stopTest();

            Payment_Plan_Item__c ppi = [
                SELECT Actual_Due_Date__c
                FROM Payment_Plan_Item__c
                WHERE Milestone__c = :milestone.Id
                LIMIT 1
            ];
            System.assertEquals(newActual, ppi.Actual_Due_Date__c);

            Offer_Payment_Plan_Item__c offerPpi = [
                SELECT Tentative_Due_Date__c
                FROM Offer_Payment_Plan_Item__c
                WHERE Milestone__c = :milestone.Id
                LIMIT 1
            ];
            System.assertEquals(newActual, offerPpi.Tentative_Due_Date__c);
        }
    }

    @isTest
    static void testOnlyTentativeDateChange() {
        User u = getTestUser();
        System.runAs(u) {
            Milestone__c milestone = [
                SELECT Id, Tentative_Due_Date_of_Completion__c
                FROM Milestone__c
                LIMIT 1
            ];

            Date newTentative = Date.today().addDays(35);

            Test.startTest();
            milestone.Tentative_Due_Date_of_Completion__c = newTentative;
            update milestone;
            Test.stopTest();

            Payment_Plan_Item__c ppi = [
                SELECT Actual_Due_Date__c
                FROM Payment_Plan_Item__c
                WHERE Milestone__c = :milestone.Id
                LIMIT 1
            ];
            System.assertEquals(newTentative, ppi.Actual_Due_Date__c);

            Offer_Payment_Plan_Item__c offerPpi = [
                SELECT Tentative_Due_Date__c
                FROM Offer_Payment_Plan_Item__c
                WHERE Milestone__c = :milestone.Id
                LIMIT 1
            ];
            System.assertEquals(newTentative, offerPpi.Tentative_Due_Date__c);
        }
    }

    @isTest
    static void testOnlyCommentChange() {
        User u = getTestUser();
        System.runAs(u) {
            Milestone__c milestone = [
                SELECT Id, Comments__c, Milestone_Comment_change_flag__c
                FROM Milestone__c
                LIMIT 1
            ];

            Test.startTest();
            milestone.Comments__c = 'Only comment changed';
            update milestone;
            Test.stopTest();

            Milestone__c updated = [
                SELECT Milestone_Comment_change_flag__c
                FROM Milestone__c
                WHERE Id = :milestone.Id
            ];
            System.assertEquals(true, updated.Milestone_Comment_change_flag__c);
        }
    }

    @isTest
    static void testNoRelevantChange() {
        User u = getTestUser();
        System.runAs(u) {
            Milestone__c milestone = [
                SELECT Id, Name
                FROM Milestone__c
                LIMIT 1
            ];

            Test.startTest();
            milestone.Name = 'Name only change – should not fire logic';
            update milestone;
            Test.stopTest();

            // Just verify no exception and records stay intact
            System.assertEquals(1, [SELECT COUNT() FROM Payment_Plan_Item__c]);
            System.assertEquals(1, [SELECT COUNT() FROM Offer_Payment_Plan_Item__c]);
        }
    }
}