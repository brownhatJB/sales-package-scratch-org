public without sharing class AppointmentController {

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Event>> getUserAppointments() {

        Id userId = UserInfo.getUserId();

        User u = [
            SELECT Id, ContactId
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];

        List<Lead> leads = [
            SELECT Id
            FROM Lead
            WHERE Contact__c = :u.ContactId
        ];

        Set<Id> leadIds = new Set<Id>();
        for (Lead l : leads) {
            leadIds.add(l.Id);
        }

        if (leadIds.isEmpty()) {
            return new Map<String, List<Event>>();
        }

        List<Event> events = [
            SELECT Id, Subject, StartDateTime, EndDateTime,
                   Owner.Name, Status__c, Interested_Project__c, Interested_Project__r.Name
            FROM Event
            WHERE WhoId IN :leadIds
            AND (
            Subject LIKE '%MD Realty Consultation%'
            OR Subject LIKE '%- MD Realty Consultation%'
        )
            ORDER BY StartDateTime DESC
        ];

        List<Event> upcoming = new List<Event>();
        List<Event> past     = new List<Event>();

        for (Event e : events) {
            if (e.StartDateTime >= System.now()) {
                upcoming.add(e);
            } else {
                past.add(e);
            }
        }

        return new Map<String, List<Event>>{
            'upcoming' => upcoming,
            'past'     => past
        };
    }

    @AuraEnabled
    public static void cancelAppointment(Id eventId) {

        Id userId = UserInfo.getUserId();

        User u = [
            SELECT ContactId
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];

        Event ev = [
            SELECT Id, Subject, WhoId, Status__c
            FROM Event
            WHERE Id = :eventId
            LIMIT 1
        ];

        if (ev.Subject != 'MD Realty Consultation') {
            throw new AuraHandledException('Invalid appointment');
        }

        ev.Status__c = 'Cancelled';
        update ev;
    }

    
    @AuraEnabled
    public static void createAppointment(
        Id leadId,
        String dateStr,
        Integer startHour,
        Integer endHour,
        Integer utcOffsetMinutes,
        String notes
    ) {
        Date apptDate = Date.valueOf(dateStr);

       
        DateTime startGmt = DateTime.newInstanceGmt(apptDate.year(), apptDate.month(), apptDate.day(), startHour, 0, 0);
        DateTime endGmt   = DateTime.newInstanceGmt(apptDate.year(), apptDate.month(), apptDate.day(), endHour,   0, 0);

        DateTime startDT = startGmt.addMinutes(-utcOffsetMinutes);
        DateTime endDT   = endGmt.addMinutes(-utcOffsetMinutes);

        if (startDT < System.now()) {
            throw new AuraHandledException('Please choose a future date and time.');
        }

        Id userId = UserInfo.getUserId();

        User u = [
            SELECT Id, ContactId
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];

        if (u.ContactId == null) {
            throw new AuraHandledException('No contact linked to your account.');
        }

        // Find the most recent active lead for this contact
        Lead lead = [
            SELECT Id, OwnerId, Enquiry_Number__c,
                   Interested_In_Project__c, Interested_In_Project__r.Name
            FROM Lead
            WHERE Id = :leadId
            AND Contact__c = :u.ContactId
            LIMIT 1
        ];


        Event ev       = new Event();
        ev.Subject     = 'MD Realty Consultation';
        ev.WhoId       = lead.Id;
        ev.OwnerId     = lead.OwnerId;   // assign to lead's owner (the sales agent)
        ev.StartDateTime = startDT;
        ev.EndDateTime   = endDT;
        ev.Status__c     = 'Scheduled';
        ev.Interested_Project__c = lead.Interested_In_Project__c;
        if (String.isNotBlank(notes)) {
            ev.Description = notes;
        }

        insert ev;
    }

    @AuraEnabled
    public static void createAppointmentFromModal(
        Id leadId,
        String dateStr,
        Integer startHour,
        Integer endHour,
        Integer utcOffsetMinutes,
        String notes
    ) {
        Date apptDate = Date.valueOf(dateStr);

       
        DateTime startGmt = DateTime.newInstanceGmt(apptDate.year(), apptDate.month(), apptDate.day(), startHour, 0, 0);
        DateTime endGmt   = DateTime.newInstanceGmt(apptDate.year(), apptDate.month(), apptDate.day(), endHour,   0, 0);

        DateTime startDT = startGmt.addMinutes(-utcOffsetMinutes);
        DateTime endDT   = endGmt.addMinutes(-utcOffsetMinutes);

        if (startDT < System.now()) {
            throw new AuraHandledException('Please choose a future date and time.');
        }


        Lead lead = [
            SELECT Id, OwnerId, Enquiry_Number__c,
                   Interested_In_Project__c, Interested_In_Project__r.Name
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];


        Event ev       = new Event();
        ev.Subject     = 'MD Realty Consultation';
        ev.WhoId       = lead.Id;
        ev.OwnerId     = lead.OwnerId;   // assign to lead's owner (the sales agent)
        ev.StartDateTime = startDT;
        ev.EndDateTime   = endDT;
        ev.Status__c     = 'Scheduled';
        ev.Interested_Project__c = lead.Interested_In_Project__c;
        if (String.isNotBlank(notes)) {
            ev.Description = notes;
        }

        insert ev;
    }

    @AuraEnabled
    public static void rescheduleAppointment (Id eventId, String dateStr, Integer startHour, Integer endHour, Integer utcOffsetMinutes) {
        
        Event ev = [ SELECT Id, Subject, Status__c FROM Event WHERE Id =: eventId LIMIT 1 ];

        if (ev.Subject != 'MD Realty Consultation') {
            throw new AuraHandledException('Invalid appointment');
        }
 
        if (ev.Status__c == 'Cancelled' || ev.Status__c == 'Completed') {
            throw new AuraHandledException('This appointment cannot be rescheduled.');
        }

        Date appDate = Date.valueOf(dateStr);

        DateTime startGmt = DateTime.newInstanceGmt(appDate.year(), appDate.month(), appDate.day(), startHour, 0, 0);
        DateTime endGmt = DateTime.newInstanceGmt(appDate.year(), appDate.month(), appDate.day(), endHour, 0, 0);

        DateTime startDT = startGmt.addMinutes(-utcOffsetMinutes);
        DateTime endDT = endGmt.addMinutes(-utcOffsetMinutes);

        if(startDT < system.now()) {
            throw new AuraHandledException('Please choose a future datea and time.');
        }

        ev.StartDateTime = startDT;
        ev.EndDateTime = endDT;
        ev.Status__c = 'Scheduled';

        update ev;
    }

    @AuraEnabled(cacheable=true)
    public static List<Lead> getUserEnquiries() {

        Id userId = UserInfo.getUserId();

        User u = [
            SELECT Id, ContactId
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];

        List<Lead> leads = [
            SELECT Id, Name, Enquiry_Number__c, Interested_In_Project__c, Interested_In_Project__r.Name 
            FROM Lead
            WHERE Contact__c = :u.ContactId
            AND Status NOT IN ('Closed - Converted', 'Retired')
        ];

        return leads;
    }

    @AuraEnabled(cacheable=true)
    public static List<Event> getEnquiryAppointments(String enqId) {

        if(String.isBlank(enqId)) {
            return new List<Event>();
        }

        try {
            List<Event> events = [
                SELECT Id, Subject, StartDateTime, EndDateTime, Owner.Name,
                       Status__c, Interested_Project__c, Interested_Project__r.Name
                FROM Event
                WHERE WhoId = :enqId
                AND (
                Subject LIKE '%MD Realty Consultation%'
                OR Subject LIKE '%- MD Realty Consultation%'
            )
                ORDER BY StartDateTime DESC
            ];
            return events;
        } catch(Exception e) {
            throw new AuraHandledException('Error retrieving appointments: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Lead> getEnquiriesFromContactId(Id contactId) {

        if(contactId == null) {
            return new List<Lead>();
        }

        try {
            return [
                SELECT 
                    Id, Name, Enquiry_Number__c, Interested_In_Project__c, Interested_In_Project__r.Name
                FROM Lead
                WHERE Contact__c = :contactId
                AND Status NOT IN ('Closed - Converted', 'Retired')
                ORDER BY CreatedDate DESC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error while retrieving enquiries: ' + e.getMessage());
        }
    }
}