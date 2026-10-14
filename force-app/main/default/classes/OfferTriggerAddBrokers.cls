/**
 * @module            : Real_Estate_Module
 * @description       :
 * @namespace         :
 * @author            : SREERAM.R
 * @group             :
 * @last modified on  : 08-22-2024
 * @last modified by  : SREERAM.R
 **/
public with sharing class OfferTriggerAddBrokers implements TriggerAction.AfterInsert {
  public void afterInsert(List<Offer__c> newOffers) {
    List<String> newOfferIds = new List<String>();
    try {
      //     List<Offer__c> newOffers = new List<Offer__c>();
      Id enquiryId = newOffers[0].Enquiry__c;
      Enquiry__c enquiry = [
        SELECT
          Id,
          Account__c,
          Stage__c,
          Contact__c,
          Contact__r.Email,
          Customer_Type__c
        FROM Enquiry__c
        WHERE Id = :enquiryId
      ];
      //  String decodedEnquiry = EncodingUtil.urlDecode(formData.enquiry, 'UTF-8');

      // Bulkify DML operations
      List<Broker_Accounts__c> brokerAccountsToInsert = new List<Broker_Accounts__c>();
      List<Broker_Contact__c> brokerContactsToInsert = new List<Broker_Contact__c>();

      for (Offer__c offerCreated : newOffers) {
        String offerId = offerCreated.Id;
        newOfferIds.add(offerId);
      }
      brokerAccountsToInsert.addAll(getBrokerAccountsForEnquiry(enquiry));
      brokerContactsToInsert.addAll(getBrokerContactsForEnquiry(enquiry));

      List<Broker_Accounts__c> brokerAccountsNew = new List<Broker_Accounts__c>();
      List<Broker_Contact__c> brokerContactsNew = new List<Broker_Contact__c>();

      // Create a set to store unique offer IDs for each offer
      Set<Id> offerIds = new Set<Id>();

      for (Offer__c insertedOffer : newOffers) {
        Id offerId = insertedOffer.Id;
        offerIds.add(offerId);
        System.debug('new offerId :' + offerId);
      }

      // Bulk update broker accounts with offerIds for each offer
      for (Id offerid : offerIds) {
        if (!brokerAccountsToInsert.isEmpty()) {
          for (Broker_Accounts__c brokerAccountlist : brokerAccountsToInsert) {
            System.debug('Offer Id: ' + offerId);
            System.debug('Enquiry Account Id: ' + enquiry.Account__c);
            // Create a new instance for each record
            Broker_Accounts__c newBrokerAccount = new Broker_Accounts__c(
              Offer__c = offerid,
              Account__c = brokerAccountlist.Account__c
            );
            brokerAccountsNew.add(newBrokerAccount);
          }
          updateOfferSaleThroughField(offerIds);
        }

        // Bulk update broker contacts with offerIds for each offer
      }
      for (Id offerid : offerIds) {
        if (!brokerContactsToInsert.isEmpty()) {
          for (Broker_Contact__c brokerContactlist : brokerContactsToInsert) {
            System.debug('Offer Id: ' + offerId);
            System.debug('Enquiry Contact Id: ' + enquiry.Contact__c);
            Broker_Contact__c newBrokerContact = new Broker_Contact__c(
              Offer__c = offerid,
              Contact__c = brokerContactlist.Contact__c
            );
            brokerContactsNew.add(newBrokerContact);
          }
          updateOfferSaleThroughField(offerIds);
        }
      }
      insert brokerAccountsNew;
      insert brokerContactsNew;
    } catch (DmlException e) {
      System.debug(
        'An error occurred while updating the record: ' + e.getMessage()
      );
    } catch (QueryException e) {
      System.debug('Query Exception: ' + e.getMessage());
    } catch (Exception e) {
      System.debug('Exception: ' + e.getMessage());
    }
  }

  private static void updateOfferSaleThroughField(Set<Id> offerIds) {
    try {
      // Query the offers that need to be updated
      List<Offer__c> offersToUpdate = [
        SELECT Id, Sale_through__c
        FROM Offer__c
        WHERE Id IN :offerIds
        WITH SECURITY_ENFORCED
      ];

      // Update the Sale Through field to 'Agent' for each offer
      for (Offer__c offerToUpdate : offersToUpdate) {
        offerToUpdate.Sale_through__c = 'Agent';
      }

      // Bulk update the modified offer records
      update offersToUpdate;
    } catch (DmlException e) {
      System.debug(
        'An error occurred while updating the record: ' + e.getMessage()
      );
    } catch (QueryException e) {
      System.debug('Query Exception: ' + e.getMessage());
    } catch (Exception e) {
      System.debug('Exception: ' + e.getMessage());
    }
  }

  private static List<Broker_Accounts__c> getBrokerAccountsForEnquiry(
    Enquiry__c enquiry
  ) {
    List<Broker_Accounts__c> brokerAccounts = new List<Broker_Accounts__c>();
    try {
      // Query Broker_Accounts__c related to the given Enquiry__c Id
      brokerAccounts = [
        SELECT Id, Name, Account__c
        FROM Broker_Accounts__c
        WHERE Enquiry__c = :enquiry.Id
        WITH SECURITY_ENFORCED
      ];
    } catch (QueryException e) {
      System.debug('Query Exception: ' + e.getMessage());
    } catch (Exception e) {
      System.debug('Exception: ' + e.getMessage());
    }
    return brokerAccounts;
  }

  private static List<Broker_Contact__c> getBrokerContactsForEnquiry(
    Enquiry__c enquiry
  ) {
    List<Broker_Contact__c> brokerContacts = new List<Broker_Contact__c>();
    try {
      // Query Broker_Contact__c related to the given Enquiry__c Id
      brokerContacts = [
        SELECT Id, Name, Contact__c, Broker_Contact__c
        FROM Broker_Contact__c
        WHERE Enquiry__c = :enquiry.Id
        WITH SECURITY_ENFORCED
      ];
    } catch (QueryException e) {
      System.debug('Query Exception: ' + e.getMessage());
    } catch (Exception e) {
      System.debug('Exception: ' + e.getMessage());
    }
    return brokerContacts;
  }
}