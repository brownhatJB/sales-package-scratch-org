public without sharing class LeadKYCHelper implements TriggerAction.AfterUpdate, TriggerAction.AfterInsert {

    public void afterInsert(List<Lead> newLeads) {
        updateLeadKYCStatus(newLeads);
    }

    public void afterUpdate(List<Lead> newLeads, List<Lead> oldLeads) {
        updateLeadKYCStatus(newLeads);
    }
    
    public static void updateLeadKYCStatus(List<Lead> leads) {
        if (leads == null || leads.isEmpty()) {
            return;
        }

    Set<Id> contactIds = new Set<Id>();

    // Keep the remaining existing logic unchanged.

        for(Lead lead : leads) {
            if(lead.Contact__c != null) {
                contactIds.add(lead.Contact__c);
            }
        }

        if(contactIds.isEmpty()) {
            return;
        }

        Map<Id, String> contactKycStatusMap = new Map<Id, String>();

        for(Contact contact : [SELECT Id, KYC_Status__c FROM Contact WHERE Id IN :contactIds]) {
            contactKycStatusMap.put(contact.Id, contact.KYC_Status__c);
        }

        List<Lead> associatedLeads = [SELECT Id, KYC_Status__c, Contact__c, All_Documents_Validated__c, Stage__c FROM Lead WHERE Contact__c IN :contactIds];

        List<Lead> leadsToUpdate = new List<Lead>();
        for(Lead lead : associatedLeads) {
            String contactKycStatus = contactKycStatusMap.get(lead.Contact__c);

            if(lead.KYC_Status__c != contactKycStatus) {
                lead.KYC_Status__c = contactKycStatus;
                lead.All_Documents_Validated__c = contactKycStatus == 'Approved' ? true : false;
                lead.All_Required_Docs_Uploaded__c = contactKycStatus == 'Approved' ? true : false;
                lead.Create_Profile__c = contactKycStatus == 'Approved' ? true : false;
                lead.Stage__c = contactKycStatus == 'Approved' ? 'Site Visit' : lead.Stage__c;
                leadsToUpdate.add(lead);
            }
        }

        if(!leadsToUpdate.isEmpty()) {
            update leadsToUpdate;
        }
    }
}