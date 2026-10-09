/**
 * @module            : Real_Estate_Module
 * @description       : Offer Configuration Controller
 * @namespace         :
 * @author            : Jouhar C
 * @group             : Unit Search
 * @last modified on  : 10-Oct-2026
 * @last modified by  : Jouhar C
 **/

public with sharing class OfferConfigurationController {
    
    public class OfferConfigWrapper {
        @AuraEnabled public List<String> selectedUnitIds;
        @AuraEnabled public String enquiryId;
        @AuraEnabled public String opportunityId;
        @AuraEnabled public List<UnitConfigEntry> unitConfigEntries;
    }

    public class UnitConfigEntry {
        @AuraEnabled public String unitId;
        @AuraEnabled public String selectedPaymentPlanId;
    }

    // main method for creating configured offers 
    @AuraEnabled
    public static List<id> createConfiguredOffers(String dataJson) {

        OfferConfigWrapper data = (OfferConfigWrapper) JSON.deserialize(dataJson, OfferConfigWrapper.class);

        if(data == null || data.selectedUnitIds == null || data.selectedUnitIds.isEmpty()) {
            throw new AuraHandledException('No Units selected');
        }

        // rebuilding the map here 
        Map<String, UnitConfigEntry> unitConfigMap = new Map<String, UnitConfigEntry>();
        if(data.unitConfigEntries != null) {
            for(UnitConfigEntry entry : data.unitConfigEntries) {
                unitConfigMap.put(entry.unitId, entry);
            }
        }

        List<Units__c> units = getUnits(data.selectedUnitIds);

        Enquiry__c enquiry;
        Opportunity opp;

        if(data.enquiryId != null) {
            enquiry = getEnquiry(data.enquiryId);
        }

        if(data.opportunityId != null) {
            opp = getOpportunity(data.opportunityId);
        }

        List<Offer__c> offers = buildOffers(units, enquiry, opp, unitConfigMap);

        insert offers;

        List<Id> offerIds = new List<Id>();
        for(Offer__c o : offers) {
            offerIds.add(o.Id);
        }

        return offerIds;
    }

    @AuraEnabled(cacheable=true)
    public static List<Payment_Plan_template__c> getPaymentPlans(Id unitId) {

        if(unitId == null) {
            return new List<Payment_Plan_template__c>();
        }

        Units__c unit = [SELECT Id, Name, Properties__c FROM Units__c WHERE Id =: unitId];

        return [ 
            SELECT Id, Name, 
            (SELECT Id, Payment_Item_Master__r.Name, Item_Name__r.Name, Percentage__c, Payment_Based_On__c, Milestone__r.Name, Tentative_Due_Date__c 
            FROM Template_Items1__r) 
            FROM Payment_Plan_template__c 
            WHERE Properties__c =: unit.Properties__c];
    }
    
    // helper methods xD
    private static List<Units__c> getUnits(List<String> unitIds) {
        return [
            SELECT Id, Name, Tax_Code__c, Default_Payment_Plan__c
            FROM Units__c
            WHERE Id IN :unitIds
        ];
    }

    private static Enquiry__c getEnquiry(String enquiryId) {
        return [
            SELECT Id, Account__c, Contact__c, Customer_Type__c
            FROM Enquiry__c
            WHERE Id = :enquiryId
        ];
    }

    private static Opportunity getOpportunity(String oppId) {
        return [
            SELECT Id, AccountId, Customer_Type__c
            FROM Opportunity
            WHERE Id = :oppId
        ];
    }

    private static List<Offer__c> buildOffers(
        List<Units__c> units,
        Enquiry__c enquiry,
        Opportunity opp,
        Map<String, UnitConfigEntry> unitConfigMap
    ) {
        List<Offer__c> offers = new List<Offer__c>();

        Id countryId = [ SELECT Id FROM Country__c LIMIT 1 ].Id;

        for(Units__c unit : units) {
            
            Offer__c offer = new Offer__c();
            
            offer.Unit__c = unit.Id;
            offer.Country__c = countryId;
            offer.Tax_Code__c = unit.Tax_Code__c;

            String selectedPlanId = unitConfigMap.containsKey(unit.Id)
                ? unitConfigMap.get(unit.Id).selectedPaymentPlanId
                : null;
            
            offer.Payment_Plan_Template__c = selectedPlanId != null 
                ? selectedPlanId
                : unit.Default_Payment_Plan__c;

            if(enquiry != null) {
                offer.Enquiry__c = enquiry.Id;
                offer.Account__c = enquiry.Account__c;
                offer.Contact__c = enquiry.Contact__c;
                offer.Customer_Type__c = enquiry.Customer_Type__c;
            }

            if(opp != null) {
                offer.Opportunity__c = opp.Id;
                offer.Account__c = opp.AccountId;
                offer.Customer_Type__c = opp.Customer_Type__c;
            }

            offer.Valid_from__c = Date.today();
            offer.Valid_to__c = Date.today().addDays(7);

            offers.add(offer);
        }

        return offers;
    }
}