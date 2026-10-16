@IsTest
private class AppointmentControllerTest {

    // ---------- Helper ----------
    private static User getTestUser() {
        return TestUserFactory.createUserWithPackageAccess();
    }

    // ---------- Test Data Factory ----------
    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName  = 'User',
            AccountId = acc.Id,
            Email     = 'testuser@example.com'
        );
        insert con;

        Id projectId = null;
        try {
            SObject project = Schema.getGlobalDescribe().get('Project__c').newSObject();
            project.put('Name', 'Test Project');
            insert project;
            projectId = (Id)project.get('Id');
        } catch (Exception e) {
            // Project__c may not exist
        }

        // Enquiry_Number__c is auto-number → do NOT set it
        List<Lead> leads = new List<Lead>{
            new Lead(
                FirstName                = 'John',
                LastName                 = 'Doe',
                Company                  = 'Test Co',
                Status                   = 'Open - Not Contacted',
                Contact__c               = con.Id,
                Interested_In_Project__c = projectId
            ),
            new Lead(
                FirstName                = 'Jane',
                LastName                 = 'Smith',
                Company                  = 'Test Co 2',
                Status                   = 'Working - Contacted',
                Contact__c               = con.Id,
                Interested_In_Project__c = projectId
            )
        };
        insert leads;

        DateTime futureStart = System.now().addDays(2).addHours(1);
        DateTime futureEnd   = futureStart.addHours(1);
        DateTime pastStart   = System.now().addDays(-3);
        DateTime pastEnd     = pastStart.addHours(1);

        List<Event> events = new List<Event>{
            new Event(
                Subject               = 'MD Realty Consultation',
                WhoId                 = leads[0].Id,
                OwnerId               = UserInfo.getUserId(),
                StartDateTime         = futureStart,
                EndDateTime           = futureEnd,
                Status__c             = 'Scheduled',
                Interested_Project__c = projectId
            ),
            new Event(
                Subject               = 'MD Realty Consultation',
                WhoId                 = leads[0].Id,
                OwnerId               = UserInfo.getUserId(),
                StartDateTime         = pastStart,
                EndDateTime           = pastEnd,
                Status__c             = 'Completed',
                Interested_Project__c = projectId
            ),
            new Event(
                Subject       = 'Some Other Meeting',
                WhoId         = leads[0].Id,
                OwnerId       = UserInfo.getUserId(),
                StartDateTime = futureStart,
                EndDateTime   = futureEnd
            )
        };
        insert events;
    }

    private static Lead getTestLead() {
        return [
            SELECT Id, OwnerId, Contact__c, Enquiry_Number__c,
                   Interested_In_Project__c, Interested_In_Project__r.Name
            FROM Lead
            WHERE FirstName = 'John' AND LastName = 'Doe'
            LIMIT 1
        ];
    }

    private static Event getScheduledEvent() {
        return [
            SELECT Id, Subject, Status__c, StartDateTime, EndDateTime, WhoId
            FROM Event
            WHERE Subject = 'MD Realty Consultation'
            AND Status__c = 'Scheduled'
            LIMIT 1
        ];
    }

    private static Contact getTestContact() {
        return [SELECT Id FROM Contact WHERE Email = 'testuser@example.com' LIMIT 1];
    }

    // ---------- getUserAppointments ----------
    // Note: Cannot set User.ContactId in this org, so success path with linked contact
    // is not testable. We verify the no-contact / empty result path instead.
    @IsTest
    static void testGetUserAppointments_NoLeads() {
        User testUser = getTestUser();

        System.runAs(testUser) {
            Test.startTest();
            Map<String, List<Event>> result = AppointmentController.getUserAppointments();
            Test.stopTest();

            // User has no ContactId → no matching leads → empty map
            System.assertEquals(0, result.size(), 'Should return empty map when no leads');
        }
    }

    // ---------- cancelAppointment ----------
    @IsTest
    static void testCancelAppointment_Success() {
        User testUser = getTestUser();
        Event ev = getScheduledEvent();

        System.runAs(testUser) {
            Test.startTest();
            AppointmentController.cancelAppointment(ev.Id);
            Test.stopTest();
        }

        Event updated = [SELECT Status__c FROM Event WHERE Id = :ev.Id];
        System.assertEquals('Cancelled', updated.Status__c);
    }

    @IsTest
    static void testCancelAppointment_InvalidSubject() {
        User testUser = getTestUser();
        Event other = [SELECT Id FROM Event WHERE Subject = 'Some Other Meeting' LIMIT 1];

        System.runAs(testUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                AppointmentController.cancelAppointment(other.Id);
            } catch (AuraHandledException e) {
                threw = true;
                // In tests getMessage() is usually "Script-thrown exception"
            }
            Test.stopTest();
            System.assert(threw, 'Should have thrown AuraHandledException for invalid subject');
        }
    }

    // ---------- createAppointment ----------
    // createAppointment requires User.ContactId. Since we cannot set it, we only
    // test the "No contact linked" path and the past-date path.

    @IsTest
    static void testCreateAppointment_PastDate() {
        User testUser = getTestUser();
        Lead lead = getTestLead();
        Date pastDate = Date.today().addDays(-2);

        System.runAs(testUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                AppointmentController.createAppointment(
                    lead.Id, String.valueOf(pastDate), 10, 11, 0, null
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw, 'Should throw AuraHandledException for past date');
        }
    }

    @IsTest
    static void testCreateAppointment_NoContact() {
        User testUser = getTestUser();
        // User has no ContactId

        Lead lead = getTestLead();
        Date futureDate = Date.today().addDays(3);

        System.runAs(testUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                AppointmentController.createAppointment(
                    lead.Id, String.valueOf(futureDate), 10, 11, 0, null
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw, 'Should throw when no Contact linked to user');
        }
    }

    // ---------- createAppointmentFromModal ----------
    // This method does NOT require User.ContactId, so success path works.

    @IsTest
    static void testCreateAppointmentFromModal_Success() {
        User testUser = getTestUser();
        Lead lead = getTestLead();
        Date futureDate = Date.today().addDays(7);
        String notes = 'Modal notes';

        System.runAs(testUser) {
            Test.startTest();
            AppointmentController.createAppointmentFromModal(
                lead.Id, String.valueOf(futureDate), 14, 15, 0, notes
            );
            Test.stopTest();
        }

        List<Event> created = [
            SELECT Id, Subject, WhoId, Status__c, Description
            FROM Event
            WHERE WhoId = :lead.Id
            AND Subject = 'MD Realty Consultation'
            AND Status__c = 'Scheduled'
            ORDER BY CreatedDate DESC
            LIMIT 5
        ];

        Boolean found = false;
        for (Event e : created) {
            if (e.Description == notes) {
                found = true;
                break;
            }
        }
        System.assert(found, 'Appointment from modal with expected notes should be created');
    }

    @IsTest
    static void testCreateAppointmentFromModal_PastDate() {
        User testUser = getTestUser();
        Lead lead = getTestLead();

        System.runAs(testUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                AppointmentController.createAppointmentFromModal(
                    lead.Id, String.valueOf(Date.today().addDays(-1)), 10, 11, 0, null
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw, 'Should throw AuraHandledException for past date');
        }
    }

    // ---------- rescheduleAppointment ----------
    @IsTest
    static void testRescheduleAppointment_Success() {
        User testUser = getTestUser();
        Event ev = getScheduledEvent();
        Date newDate = Date.today().addDays(10);

        System.runAs(testUser) {
            Test.startTest();
            AppointmentController.rescheduleAppointment(
                ev.Id, String.valueOf(newDate), 9, 10, 0
            );
            Test.stopTest();
        }

        Event updated = [
            SELECT StartDateTime, EndDateTime, Status__c
            FROM Event WHERE Id = :ev.Id
        ];
        System.assertEquals('Scheduled', updated.Status__c);
        System.assertEquals(newDate, updated.StartDateTime.date());
    }

    @IsTest
    static void testRescheduleAppointment_InvalidSubject() {
        User testUser = getTestUser();
        Event other = [SELECT Id FROM Event WHERE Subject = 'Some Other Meeting' LIMIT 1];

        System.runAs(testUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                AppointmentController.rescheduleAppointment(
                    other.Id, String.valueOf(Date.today().addDays(5)), 10, 11, 0
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw, 'Should throw AuraHandledException for invalid subject');
        }
    }

    @IsTest
    static void testRescheduleAppointment_CancelledStatus() {
        User testUser = getTestUser();

        // Use the Completed event from TestSetup – no DML needed
        Event ev = [
            SELECT Id, Subject, Status__c
            FROM Event
            WHERE Subject = 'MD Realty Consultation'
            AND Status__c = 'Completed'
            LIMIT 1
        ];

        System.runAs(testUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                AppointmentController.rescheduleAppointment(
                    ev.Id, String.valueOf(Date.today().addDays(5)), 10, 11, 0
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw, 'Should not allow reschedule of completed/cancelled appointment');
        }
    }

    @IsTest
    static void testRescheduleAppointment_PastDate() {
        User testUser = getTestUser();
        Event ev = getScheduledEvent();

        System.runAs(testUser) {
            Test.startTest();
            Boolean threw = false;
            try {
                AppointmentController.rescheduleAppointment(
                    ev.Id, String.valueOf(Date.today().addDays(-1)), 10, 11, 0
                );
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw, 'Should throw AuraHandledException for past date');
        }
    }

    // ---------- getUserEnquiries ----------
    // Cannot set ContactId → only the empty-result path is reliable
    @IsTest
    static void testGetUserEnquiries_NoContact() {
        User testUser = getTestUser();

        System.runAs(testUser) {
            Test.startTest();
            List<Lead> enquiries = AppointmentController.getUserEnquiries();
            Test.stopTest();

            // No ContactId on user → query returns empty list
            System.assertEquals(0, enquiries.size(), 'Should return empty list when user has no ContactId');
        }
    }

    // ---------- getEnquiryAppointments ----------
    @IsTest
    static void testGetEnquiryAppointments_Success() {
        User testUser = getTestUser();
        Lead lead = getTestLead();

        System.runAs(testUser) {
            Test.startTest();
            List<Event> events = AppointmentController.getEnquiryAppointments(lead.Id);
            Test.stopTest();

            System.assert(events.size() >= 2, 'Should return appointments for the lead');
            for (Event e : events) {
                System.assert(e.Subject.contains('MD Realty Consultation'));
            }
        }
    }

    @IsTest
    static void testGetEnquiryAppointments_BlankId() {
        User testUser = getTestUser();

        System.runAs(testUser) {
            Test.startTest();
            List<Event> events = AppointmentController.getEnquiryAppointments('');
            Test.stopTest();

            System.assertEquals(0, events.size());
        }
    }

    // ---------- getEnquiriesFromContactId ----------
    @IsTest
    static void testGetEnquiriesFromContactId_Success() {
        User testUser = getTestUser();
        Contact con = getTestContact();

        System.runAs(testUser) {
            Test.startTest();
            List<Lead> leads = AppointmentController.getEnquiriesFromContactId(con.Id);
            Test.stopTest();

            System.assert(leads.size() >= 2, 'Should return leads for the contact');
        }
    }

    @IsTest
    static void testGetEnquiriesFromContactId_Null() {
        User testUser = getTestUser();

        System.runAs(testUser) {
            Test.startTest();
            List<Lead> leads = AppointmentController.getEnquiriesFromContactId(null);
            Test.stopTest();

            System.assertEquals(0, leads.size());
        }
    }
}